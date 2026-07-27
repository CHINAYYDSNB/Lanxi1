/// SSH-backed implementation of [ServerSource].
///
/// Every method executes a POSIX shell command via [SshConnection]
/// and parses the output into the appropriate model.
library;

import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/ssh/ssh_connection.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/file_item.dart';
import 'package:lanxi/models/system_snapshot.dart';

class SshServerSource implements ServerSource {
  final SshConnection _ssh;

  SshServerSource(this._ssh);

  // ── Monitoring ──

  @override
  Future<SystemSnapshot> getSystemInfo() async {
    const cmd = 'top -bn1 | head -5; free -m; df -h';
    final output = await _ssh.exec(cmd);
    return _parseSystemInfo(output);
  }

  @override
  Future<List<FileItem>> listDir(String path) async {
    final cmd = "ls -la '$path'";
    final output = await _ssh.exec(cmd);
    return _parseFileListing(output, path);
  }

  @override
  Future<CompressResult> compress(List<String> src, String dest) async {
    final srcJoined = src.map((s) => '"$s"').join(' ');
    final cmd = "tar -czf '$dest' $srcJoined";
    final start = DateTime.now();
    final output = await _ssh.exec(cmd);
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
    await _ssh.exec(cmd);
    appLogger.i('NTP set to $server');
  }

  @override
  Future<void> changeRootPassword(String newPass) async {
    final cmd = "echo 'root:$newPass' | chpasswd";
    await _ssh.exec(cmd);
    appLogger.i('Root password changed');
  }

  // ── Parsing helpers ──

  SystemSnapshot _parseSystemInfo(String raw) {
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

    return SystemSnapshot(
      cpuPercent: cpu,
      memoryTotal: memTotal,
      memoryUsed: memUsed,
      diskTotal: diskTotal,
      diskUsed: diskUsed,
      loadAvg: loadAvg,
      timestamp: DateTime.now(),
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
