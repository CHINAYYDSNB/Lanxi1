/// [ServerSource] implementation backed by the 1Panel API.
///
/// System-level operations (setNtp, changeRootPassword) are unavailable
/// through the panel API and throw [PanelFallbackException] so the
/// [FallbackServerSource] can retry them via SSH.
library;

import 'dart:typed_data';

import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/interactive_session.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/models/dto/container_dto.dart';

import 'one_panel_adapter.dart';

class OnePanelServerSource implements ServerSource {
  final OnePanelAdapter _adapter;

  OnePanelServerSource(this._adapter);

  @override
  Future<SystemStats> getSystemInfo() => _adapter.getHostInfo();

  @override
  Stream<SystemStats> watchHostStats() async* {
    // 1Panel has no push channel, so poll the dashboard API on a fixed
    // interval. The UI binds to this stream and never polls itself.
    yield await _adapter.getHostInfo();
    await for (final stats in Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => _adapter.getHostInfo())) {
      yield stats;
    }
  }

  @override
  Future<List<FileItem>> listDir(String path) => _adapter.listDir(path);

  @override
  Future<CompressResult> compress(
    List<String> src,
    String dest, {
    CompressFormat format = CompressFormat.tarGz,
  }) =>
      _adapter.compress(src, dest, format: format);

  @override
  Future<Uint8List> readFileBytes(String path) => _adapter.readFileBytes(path);

  @override
  Future<void> setFilePermission(
    String path, {
    required int mode,
    String? owner,
    String? group,
  }) =>
      _adapter.setFilePermission(path, mode: mode, owner: owner, group: group);

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
  Future<List<ContainerDomain>> listContainers() => _adapter.listContainers();

  @override
  Future<void> startContainer(String name) => _adapter.startContainer(name);

  @override
  Future<void> stopContainer(String name) => _adapter.stopContainer(name);

  @override
  Future<void> restartContainer(String name) => _adapter.restartContainer(name);

  @override
  Future<void> pauseContainer(String name) => _adapter.pauseContainer(name);

  @override
  Future<void> unpauseContainer(String name) => _adapter.unpauseContainer(name);

  @override
  Future<void> removeContainer(String name, {bool force = true}) =>
      _adapter.removeContainer(name, force: force);

  @override
  Future<ContainerInspect> inspectContainer(String name) =>
      _adapter.inspectContainer(name);

  @override
  Stream<String> containerLogs(String name, {int tail = 200, bool follow = false}) {
    // 1Panel SSE logs are not wired through the API adapter — signal the
    // fallback layer to stream logs over SSH.
    throw const PanelFallbackException(
      'containerLogs not available through 1Panel API',
    );
  }

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
