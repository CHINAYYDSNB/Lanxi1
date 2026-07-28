/// [ServerSource] implementation backed by the 1Panel API.
///
/// System-level operations (setNtp, changeRootPassword) are unavailable
/// through the panel API and throw [PanelFallbackException] so the
/// [FallbackServerSource] can retry them via SSH.
library;

import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/interactive_session.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';

import 'one_panel_adapter.dart';

class OnePanelServerSource implements ServerSource {
  final OnePanelAdapter _adapter;

  OnePanelServerSource(this._adapter);

  @override
  Future<SystemStats> getSystemInfo() => _adapter.getHostInfo();

  @override
  Future<List<FileItem>> listDir(String path) => _adapter.listDir(path);

  @override
  Future<CompressResult> compress(List<String> src, String dest) =>
      _adapter.compress(src, dest);

  @override
  Future<String> readFile(String path) => _adapter.readFile(path);

  @override
  Future<void> writeFile(String path, String content) =>
      _adapter.writeFile(path, content);

  @override
  Future<void> deleteFile(String path, {required bool isDir}) =>
      _adapter.deleteFile(path, isDir: isDir);

  @override
  Future<void> renameFile(String oldPath, String newPath) =>
      _adapter.renameFile(oldPath, newPath);

  @override
  Future<void> createFile(String path, {required bool isDir, String? content}) =>
      _adapter.createFile(path, isDir: isDir, content: content);

  @override
  Future<void> setNtp(String server) {
    throw const PanelFallbackException(
      'setNtp not available through 1Panel API',
    );
  }

  @override
  Future<void> changeRootPassword(String newPass) {
    throw const PanelFallbackException(
      'changeRootPassword not available through 1Panel API',
    );
  }

  @override
  Stream<String> streamCommand(String cmd) {
    // Panel API has no shell stream — signal the fallback layer to use SSH.
    throw const PanelFallbackException(
      'streamCommand not available through 1Panel API',
    );
  }

  @override
  Future<PanelStatus> detectPanel() async => PanelStatus.onePanel;

  @override
  Future<InteractiveSession> openShell() {
    // The 1Panel API has no shell — signal the fallback layer to use SSH.
    throw const PanelFallbackException('openShell not available through 1Panel API');
  }
}
