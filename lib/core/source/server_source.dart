import 'package:lanxi/core/source/interactive_session.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/models/dto/container_dto.dart';

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

  /// Read current CPU, memory, and disk stats (one-shot).
  Future<SystemStats> getSystemInfo();

  /// Stream live CPU, memory, and disk stats.
  ///
  /// SSH sources push updates via [SshSessionPool.watch]; panel sources poll
  /// the dashboard API on a fixed interval. Either way the UI only binds to
  /// this stream — it never polls the API itself.
  Stream<SystemStats> watchHostStats();

  // ── System Configuration ──

  /// Set NTP server and enable NTP sync.
  Future<void> setNtp(String server);

  /// Change the root password.
  Future<void> changeRootPassword(String newPass);

  // ── Docker ──

  /// List all containers (running + stopped).
  Future<List<ContainerDomain>> listContainers();

  /// Start a stopped container by [name].
  Future<void> startContainer(String name);

  /// Stop a running container by [name].
  Future<void> stopContainer(String name);

  /// Restart a container by [name].
  Future<void> restartContainer(String name);

  /// Pause a running container by [name].
  Future<void> pauseContainer(String name);

  /// Unpause a paused container by [name].
  Future<void> unpauseContainer(String name);

  /// Remove a container by [name].
  Future<void> removeContainer(String name, {bool force = true});

  /// Return detailed inspection data for [name].
  Future<ContainerInspect> inspectContainer(String name);

  /// Stream a container's logs.
  Stream<String> containerLogs(String name, {int tail = 200, bool follow = false});

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
