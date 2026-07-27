/// SSH-backed implementation of [ServerSource].
///
/// Lifecycle:
///   1. [SshSessionPool.connect] establishes the TCP/SSH session.
///   2. [SSHClient.execute] runs each command and returns [SSHSession].
///   3. Each command reads [SSHSession.stdout] to completion.
///   4. [SshSessionPool.releaseAll] or idle timeout closes the connection.
library;

import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';

import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/ssh/ssh_connection.dart';
import 'package:lanxi/core/ssh/ssh_session_pool.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';

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
    const cmd = 'top -bn1 | head -5; free -m; df -h';
    final output = await _exec(cmd);
    return _parseSystemInfo(output);
  }

  @override
  Future<List<FileItem>> listDir(String path) async {
    final cmd = "ls -la '$path'";
    final output = await _exec(cmd);
    return _parseFileListing(output, path);
  }

  @override
  Future<CompressResult> compress(List<String> src, String dest) async {
    final srcJoined = src.map((s) => '"$s"').join(' ');
    final cmd = "tar -czf '$dest' $srcJoined";
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
  Future<void> setNtp(String server) async {
    // ignore: prefer_single_quotes
    final cmd = "timedatectl set-ntp true && timedatectl set-timezone $server";
    await _exec(cmd);
    appLogger.i('NTP set to $server');
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

  // ── Parsing helpers ──

  SystemStats _parseSystemInfo(String raw) {
    double cpu = 0.0;
    int memTotal = 0, memUsed = 0;
    int diskTotal = 0, diskUsed = 0;
    double loadAvg = 0.0;

    for (final line in raw.split('\n')) {
      final cpuMatch = RegExp(r'%Cpu\(s\):\s+(\d+\.?\d*)').firstMatch(line);
      if (cpuMatch != null) cpu = double.parse(cpuMatch[1]!);

      final memMatch = RegExp(r'(?:Mem|MiB Mem)[\s:]+(\d+\.?\d*)\s+(\d+\.?\d*)')
          .firstMatch(line);
      if (memMatch != null) {
        memTotal = double.parse(memMatch[1]!).round();
        memUsed = double.parse(memMatch[2]!).round();
      }

      final diskMatch = RegExp(r'(\d+)G\s+(\d+)G').firstMatch(line);
      if (diskMatch != null) {
        diskTotal = int.parse(diskMatch[1]!) * 1024;
        diskUsed = int.parse(diskMatch[2]!) * 1024;
      }

      final loadMatch = RegExp(r'load average:\s+(\d+\.?\d*)').firstMatch(line);
      if (loadMatch != null) loadAvg = double.parse(loadMatch[1]!);
    }

    return SystemStats(
      cpuPercent: cpu,
      memTotalMb: memTotal,
      memUsedMb: memUsed,
      disks: const [],
      diskTotalMb: diskTotal,
      diskUsedMb: diskUsed,
      loadAvg: loadAvg,
      source: SystemStatsSource.ssh,
    );
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
          path: '$basePath/$name',
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
