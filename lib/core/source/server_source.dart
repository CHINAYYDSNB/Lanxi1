import 'package:lanxi/core/source/interactive_session.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';

/// Abstract interface for all server operations.
///
/// Every operation is backed by either SSH (primary) or
/// the 1Panel API (fallback). Consumers of [ServerSource]
/// never know which transport is used.
abstract class ServerSource {
  // ── File Operations ──

  /// List entries in [path].
  Future<List<FileItem>> listDir(String path);

  /// Read a file's text content (for the editor).
  Future<String> readFile(String path);

  /// Write [content] to [path] (editor save).
  Future<void> writeFile(String path, String content);

  /// Delete [path]; [isDir] selects recursive removal of directories.
  Future<void> deleteFile(String path, {required bool isDir});

  /// Rename / move [oldPath] to [newPath].
  Future<void> renameFile(String oldPath, String newPath);

  /// Create a new file or directory at [path].
  Future<void> createFile(String path, {required bool isDir, String? content});

  /// Compress [src] items into [dest] archive.
  Future<CompressResult> compress(List<String> src, String dest);

  // ── Monitoring ──

  /// Read current CPU, memory, and disk stats.
  Future<SystemStats> getSystemInfo();

  // ── System Configuration ──

  /// Set NTP server and enable NTP sync.
  Future<void> setNtp(String server);

  /// Change the root password.
  Future<void> changeRootPassword(String newPass);

  // ── Streaming / Detection ──

  /// Stream a command's stdout as it arrives (used for live terminal output,
  /// e.g. the 1Panel installer). SSH-only; panel throws [PanelFallbackException].
  Stream<String> streamCommand(String cmd);

  /// Open an interactive PTY shell. SSH-only; panel sources throw
  /// [PanelFallbackException] so callers can fall back to SSH.
  Future<InteractiveSession> openShell();

  /// Probe the host for a known control panel (1Panel / 宝塔).
  Future<PanelStatus> detectPanel();
}
