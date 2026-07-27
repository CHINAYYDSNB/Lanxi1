import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/file_item.dart';
import 'package:lanxi/models/system_snapshot.dart';

/// Abstract interface for all server operations.
///
/// Every operation is backed by either SSH (primary) or
/// the 1Panel API (fallback). Consumers of [ServerSource]
/// never know which transport is used.
abstract class ServerSource {
  // ── File Operations ──

  /// List entries in [path].
  Future<List<FileItem>> listDir(String path);

  /// Compress [src] items into [dest] archive.
  Future<CompressResult> compress(List<String> src, String dest);

  // ── Monitoring ──

  /// Read current CPU, memory, and disk stats.
  Future<SystemSnapshot> getSystemInfo();

  // ── System Configuration ──

  /// Set NTP server and enable NTP sync.
  Future<void> setNtp(String server);

  /// Change the root password.
  Future<void> changeRootPassword(String newPass);
}
