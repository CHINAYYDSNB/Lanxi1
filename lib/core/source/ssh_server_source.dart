/// SSH-backed implementation of [ServerSource].
///
/// Lifecycle:
///   1. [SshSessionPool.connect] establishes the TCP/SSH session.
///   2. [SSHClient.execute] runs each command and returns [SSHSession].
///   3. Each command reads [SSHSession.stdout] to completion.
///   4. [SshSessionPool.releaseAll] or idle timeout closes the connection.
library;

// CI constitution: SSH command strings MUST use double quotes (prevents
// `$var` interpolation bugs), even when a linter would prefer single quotes.
// ignore_for_file: prefer_single_quotes

import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/ssh/ssh_connection.dart';
import 'package:lanxi/core/ssh/ssh_session_pool.dart';
import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/interactive_session.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/core/source/ssh_interactive_session.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/models/dto/container_dto.dart';

class SshServerSource implements ServerSource {
  final SshSessionPool _pool;
  final SshCredentials _credentials;
  SSHClient? _client;

  SshServerSource({
    required SshSessionPool pool,
    required SshCredentials credentials,
  })  : _pool = pool,
        _credentials = credentials;

  /// Lazily establish (or reuse) the SSH connection.
  Future<SSHClient> _getClient() async {
    if (_client == null) {
      appLogger.i('SshServerSource: connecting to ${_credentials.poolKey}');
      _client = await _pool.connect(_credentials);
    }
    return _client!;
  }

  /// Execute a single command and return stdout as a string.
  Future<String> _exec(String cmd) async {
    final client = await _getClient();
    final session = await client.execute(cmd);
    final lines = await session.stdout
        .map((chunk) => utf8.decode(chunk.toList()))
        .join();
    // Wait for channel close, then check exit code
    await session.done;
    if (session.exitCode != null && session.exitCode != 0) {
      appLogger.w('Command exited with code ${session.exitCode}: $cmd');
    }
    return lines.trim();
  }

  /// Public command runner — used by [PanelDetector] and callers that need raw
  /// stdout without streaming.
  Future<String> exec(String cmd) => _exec(cmd);

  /// Execute [cmd] and stream stdout chunks as they arrive.
  ///
  /// Each chunk is decoded as UTF-8. The stream completes when the remote
  /// command finishes. Command strings MUST be double-quoted (see CI rules).
  Stream<String> execStream(String cmd) async* {
    final client = await _getClient();
    final session = await client.execute(cmd);
    await for (final chunk in session.stdout) {
      yield utf8.decode(chunk.toList());
    }
    await session.done;
  }

  @override
  Stream<String> streamCommand(String cmd) => execStream(cmd);

  @override
  Future<PanelStatus> detectPanel() => PanelDetector(exec).detect();

  // ── ServerSource implementation ──

  @override
  Future<SystemStats> getSystemInfo() async {
    // CPU / memory / load and disk usage are fetched separately so the disk
    // parser only sees clean `df -Pk` output (no interleaved top/free text).
    final infoOut = await _exec("top -bn1 | head -5; free -m");
    final diskOut = await _exec("df -Pk");
    return _parseSystemInfo(infoOut, diskOut);
  }

  @override
  Stream<SystemStats> watchHostStats() async* {
    // Ensure a pooled connection exists so SshSessionPool.watch can stream.
    await _getClient();
    const delimiter = '__LANXI_DISK__';
    // A single combined command keeps the stream cheap: the trailing `sleep 2`
    // throttles SshSessionPool's re-execute loop to ~2s instead of a busy loop.
    const cmd =
        "top -bn1 | head -5; free -m; echo '$delimiter'; df -Pk; sleep 2";
    await for (final raw in _pool.watch(_credentials.poolKey, cmd)) {
      final parts = raw.split(delimiter);
      final infoRaw = parts.isNotEmpty ? parts[0] : raw;
      final diskRaw = parts.length > 1 ? parts[1] : '';
      try {
        yield _parseSystemInfo(infoRaw, diskRaw);
      } on Object catch (e) {
        appLogger.w('watchHostStats parse failed: $e');
      }
    }
  }

  @override
  Future<InteractiveSession> openShell() async {
    if (kIsWeb) {
      throw const PlatformNotSupportedException(
        '网页版不支持交互式 SSH 终端（浏览器无原始 TCP）。',
      );
    }
    final client = await _getClient();
    return SshInteractiveSession.open(client);
  }

  @override
  Future<List<FileItem>> listDir(String path) async {
    final cmd = "ls -la '$path'";
    final output = await _exec(cmd);
    return _parseFileListing(output, path);
  }

  @override
  Future<CompressResult> compress(
    List<String> src,
    String dest, {
    CompressFormat format = CompressFormat.tarGz,
  }) async {
    final srcJoined = src.map((s) => '"$s"').join(' ');
    final cmd = format == CompressFormat.zip
        ? "zip -r '$dest' $srcJoined"
        : "tar -czf '$dest' $srcJoined";
    final start = DateTime.now();
    final output = await _exec(cmd);
    final duration = DateTime.now().difference(start);
    return CompressResult(
      destPath: dest,
      size: 0,
      durationMs: duration.inMilliseconds,
      success: output.isEmpty,
    );
  }

  @override
  Future<Uint8List> readFileBytes(String path) async {
    // base64-encode on the host so binary content survives the text channel,
    // then decode locally.
    final b64 = await _exec("base64 -w0 -- '$path'");
    return base64.decode(b64.trim());
  }

  @override
  Future<void> setFilePermission(
    String path, {
    required int mode,
    String? owner,
    String? group,
  }) async {
    // 1Panel exposes [mode] as a decimal int (e.g. 493 == 0o755); chmod needs
    // the octal representation, so convert before emitting the command.
    final modeStr = mode.toRadixString(8);
    await _exec("chmod $modeStr '$path'");
    if (owner != null && owner.isNotEmpty) {
      final own =
          group != null && group.isNotEmpty ? "$owner:$group" : owner;
      await _exec("chown '$own' '$path'");
    }
  }

  @override
  Future<String> readFile(String path) async {
    // Text-only read for the editor. Binary content would be garbled, which
    // is acceptable for a quick-edit workflow.
    return _exec("cat -- '$path'");
  }

  @override
  Future<void> writeFile(String path, String content) async {
    // Pipe base64-encoded content through `base64 -d` to avoid issues with
    // shell-significant characters or a colliding heredoc delimiter.
    final b64 = base64.encode(utf8.encode(content));
    await _exec("base64 -d > '$path' <<'LANXI_EOF'\n$b64\nLANXI_EOF");
  }

  @override
  Future<void> deleteFile(String path, {required bool isDir}) async {
    await _exec("rm -rf '$path'");
  }

  @override
  Future<void> renameFile(String oldPath, String newPath) async {
    await _exec("mv -- '$oldPath' '$newPath'");
  }

  @override
  Future<void> createFile(String path, {required bool isDir, String? content}) async {
    if (isDir) {
      await _exec("mkdir -p '$path'");
      return;
    }
    if (content != null) {
      final b64 = base64.encode(utf8.encode(content));
      await _exec("base64 -d > '$path' <<'LANXI_EOF'\n$b64\nLANXI_EOF");
    } else {
      await _exec("touch '$path'");
    }
  }

  @override
  Future<void> setNtp(String server) async {
    final cmd = "timedatectl set-ntp true && timedatectl set-timezone $server";
    await _exec(cmd);
    appLogger.i("NTP set to $server");
  }

  @override
  Future<void> changeRootPassword(String newPass) async {
    final cmd = "echo 'root:$newPass' | chpasswd";
    await _exec(cmd);
    appLogger.i('Root password changed');
  }

  /// Release the underlying SSH connection back to the pool.
  Future<void> disconnect() async {
    if (_client != null) {
      appLogger.i('SshServerSource: releasing ${_credentials.poolKey}');
      _pool.releaseIdle();
      _client = null;
    }
  }

  // ── Docker ──

  @override
  Future<List<ContainerDomain>> listContainers() async {
    final out = await _exec("docker ps --all --format '{{json .}}'");
    return _parseContainers(out);
  }

  @override
  Future<void> startContainer(String name) async {
    await _exec("docker start '$name'");
  }

  @override
  Future<void> stopContainer(String name) async {
    await _exec("docker stop '$name'");
  }

  @override
  Future<void> restartContainer(String name) async {
    await _exec("docker restart '$name'");
  }

  @override
  Future<void> pauseContainer(String name) async {
    await _exec("docker pause '$name'");
  }

  @override
  Future<void> unpauseContainer(String name) async {
    await _exec("docker unpause '$name'");
  }

  @override
  Future<void> removeContainer(String name, {bool force = true}) async {
    final f = force ? '-f' : '';
    await _exec("docker rm $f '$name'");
  }

  @override
  Future<ContainerInspect> inspectContainer(String name) async {
    final out = await _exec("docker inspect '$name'");
    if (out.trim().isEmpty) return ContainerInspect(<String, dynamic>{});
    try {
      final decoded = jsonDecode(out) as List<dynamic>;
      final first = decoded.isNotEmpty ? decoded.first : <String, dynamic>{};
      return ContainerInspect(first as Map<String, dynamic>);
    } catch (e) {
      appLogger.w('Failed to parse docker inspect for $name: $e');
      return ContainerInspect(<String, dynamic>{});
    }
  }

  @override
  Stream<String> containerLogs(String name, {int tail = 200, bool follow = false}) {
    final f = follow ? '-f' : '';
    return execStream("docker logs $f --tail $tail '$name'");
  }

  List<ContainerDomain> _parseContainers(String jsonl) {
    if (jsonl.trim().isEmpty) return const [];
    final out = <ContainerDomain>[];
    for (final line in jsonl.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final j = jsonDecode(trimmed) as Map<String, dynamic>;
        out.add(ContainerDomain.fromCliJson(j));
      } catch (e) {
        appLogger.w('Skipping unparseable docker ps line: $e');
      }
    }
    return out;
  }

  // ── Parsing helpers ──

  SystemStats _parseSystemInfo(String infoRaw, String diskRaw) {
    double cpu = 0.0;
    int memTotal = 0, memUsed = 0;
    double loadAvg = 0.0;

    for (final line in infoRaw.split('\n')) {
      final cpuMatch = RegExp(r'%Cpu\(s\):\s+(\d+\.?\d*)').firstMatch(line);
      if (cpuMatch != null) cpu = double.parse(cpuMatch[1]!);

      final memMatch = RegExp(r'(?:Mem|MiB Mem)[\s:]+(\d+\.?\d*)\s+(\d+\.?\d*)')
          .firstMatch(line);
      if (memMatch != null) {
        memTotal = double.parse(memMatch[1]!).round();
        memUsed = double.parse(memMatch[2]!).round();
      }

      final loadMatch = RegExp(r'load average:\s+(\d+\.?\d*)').firstMatch(line);
      if (loadMatch != null) loadAvg = double.parse(loadMatch[1]!);
    }

    final disks = _parseDisks(diskRaw);
    final diskTotalMb = disks.fold<int>(0, (s, d) => s + d.totalMb);
    final diskUsedMb = disks.fold<int>(0, (s, d) => s + d.usedMb);

    return SystemStats(
      cpuPercent: cpu,
      memTotalMb: memTotal,
      memUsedMb: memUsed,
      disks: disks,
      diskTotalMb: diskTotalMb,
      diskUsedMb: diskUsedMb,
      loadAvg: loadAvg,
      source: SystemStatsSource.ssh,
    );
  }

  /// Parse `df -Pk` output into per-mount [DiskInfo] entries.
  ///
  /// Each data line is: `Filesystem 1024-blocks Used Available Capacity Mounted-on`.
  /// Pseudo filesystems (tmpfs, proc, cgroup, …) are skipped, but real disks
  /// such as `overlay` (common as a container's root) are kept.
  List<DiskInfo> _parseDisks(String raw) {
    final disks = <DiskInfo>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('Filesystem')) continue; // df header
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 6) continue;
      if (_isPseudoFs(parts[0])) continue;
      final blocks1k = int.tryParse(parts[1]) ?? 0;
      final used1k = int.tryParse(parts[2]) ?? 0;
      final mount = parts[5];
      disks.add(
        DiskInfo(
          path: mount,
          totalMb: (blocks1k / 1024).round(),
          usedMb: (used1k / 1024).round(),
        ),
      );
    }
    return disks;
  }

  bool _isPseudoFs(String fs) {
    const pseudo = {
      'tmpfs',
      'devtmpfs',
      'proc',
      'sysfs',
      'cgroup',
      'cgroup2',
      'devpts',
      'mqueue',
      'autofs',
      'udev',
      'debugfs',
      'tracefs',
      'securityfs',
      'hugetlbfs',
      'binfmt_misc',
      'configfs',
      'efivarfs',
      'fusectl',
      'pstore',
      'rpc_pipefs',
      'nsfs',
      'ramfs',
    };
    return pseudo.contains(fs);
  }

  List<FileItem> _parseFileListing(String raw, String basePath) {
    final items = <FileItem>[];
    final lines = raw.split('\n');
    for (final line in lines) {
      final match = RegExp(
        r'^([\-d])([rwx\-]{9})\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\w+\s+\d+\s+[\d:]+\s+)(.+)$',
      ).firstMatch(line);
      if (match == null) continue;
      final isDir = match[1] == 'd';
      final perms = match[2]!;
      final size = int.parse(match[3]!);
      final name = match[5]!.trim();
      if (name == '.' || name == '..') continue;
      items.add(
        FileItem(
          name: name,
          path: "$basePath/$name",
          size: size,
          isDir: isDir,
          permissions: perms,
          modifiedTime: DateTime.now(),
        ),
      );
    }
    return items;
  }
}
