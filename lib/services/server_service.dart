/// Facade that UI layers talk to.
///
/// Zero branching — no `if (isPanel)` checks.
/// Every method delegates directly to the injected [ServerSource].
library;

import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';

class ServerService {
  final ServerSource _source;

  ServerService(this._source);

  // ── Monitoring ──

  Future<SystemStats> getSystemInfo() => _source.getSystemInfo();

  // ── File Operations ──

  Future<List<FileItem>> listDir(String path) => _source.listDir(path);

  Future<CompressResult> compress(List<String> src, String dest) =>
      _source.compress(src, dest);

  // ── System Configuration ──

  Future<void> setNtp(String server) => _source.setNtp(server);

  Future<void> changeRootPassword(String newPass) =>
      _source.changeRootPassword(newPass);

  // ── Streaming / Detection ──

  /// Stream a command's stdout (e.g. for the live 1Panel install terminal).
  Stream<String> streamCommand(String cmd) => _source.streamCommand(cmd);

  /// Probe the host for a control panel (1Panel / 宝塔).
  Future<PanelStatus> detectPanel() => _source.detectPanel();
}
