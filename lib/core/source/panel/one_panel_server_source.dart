/// [ServerSource] implementation backed by the 1Panel API.
///
/// System-level operations (setNtp, changeRootPassword) are unavailable
/// through the panel API and throw [PanelFallbackException] so the
/// [FallbackServerSource] can retry them via SSH.
library;

import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/file_item.dart';
import 'package:lanxi/models/system_snapshot.dart';

import 'one_panel_adapter.dart';

class OnePanelServerSource implements ServerSource {
  final OnePanelAdapter _adapter;

  OnePanelServerSource(this._adapter);

  @override
  Future<SystemSnapshot> getSystemInfo() => _adapter.getHostInfo();

  @override
  Future<List<FileItem>> listDir(String path) => _adapter.listDir(path);

  @override
  Future<CompressResult> compress(List<String> src, String dest) =>
      _adapter.compress(src, dest);

  @override
  Future<void> setNtp(String server) {
    throw const PanelFallbackException(
      'setNtp not available through 1Panel API',
      endpoint: 'setNtp',
    );
  }

  @override
  Future<void> changeRootPassword(String newPass) {
    throw const PanelFallbackException(
      'changeRootPassword not available through 1Panel API',
      endpoint: 'changeRootPassword',
    );
  }
}
