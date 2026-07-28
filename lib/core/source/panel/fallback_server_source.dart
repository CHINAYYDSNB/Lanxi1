/// Router implementation that tries the 1Panel API first,
/// then falls back to SSH on [PanelFallbackException].
///
/// This is the default source when an API key is configured.
library;

import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/interactive_session.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/models/dto/container_dto.dart';

import 'one_panel_server_source.dart';

class FallbackServerSource implements ServerSource {
  final OnePanelServerSource panel;
  final ServerSource ssh;

  FallbackServerSource({
    required this.panel,
    required this.ssh,
  });

  @override
  Future<SystemStats> getSystemInfo() async {
    try {
      return await panel.getSystemInfo();
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API getSystemInfo failed — using SSH ($e)');
      return await ssh.getSystemInfo();
    }
  }

  @override
  Stream<SystemStats> watchHostStats() {
    try {
      return panel.watchHostStats();
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API watchHostStats failed — using SSH ($e)');
      return ssh.watchHostStats();
    }
  }

  @override
  Future<List<FileItem>> listDir(String path) async {
    try {
      return await panel.listDir(path);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API listDir failed — using SSH ($e)');
      return await ssh.listDir(path);
    }
  }

  @override
  Future<CompressResult> compress(List<String> src, String dest) async {
    try {
      return await panel.compress(src, dest);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API compress failed — using SSH ($e)');
      return await ssh.compress(src, dest);
    }
  }

  @override
  Future<String> readFile(String path) async {
    try {
      return await panel.readFile(path);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API readFile failed — using SSH ($e)');
      return await ssh.readFile(path);
    }
  }

  @override
  Future<void> writeFile(String path, String content) async {
    try {
      await panel.writeFile(path, content);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API writeFile failed — using SSH ($e)');
      await ssh.writeFile(path, content);
    }
  }

  @override
  Future<void> deleteFile(String path, {required bool isDir}) async {
    try {
      await panel.deleteFile(path, isDir: isDir);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API deleteFile failed — using SSH ($e)');
      await ssh.deleteFile(path, isDir: isDir);
    }
  }

  @override
  Future<void> renameFile(String oldPath, String newPath) async {
    try {
      await panel.renameFile(oldPath, newPath);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API renameFile failed — using SSH ($e)');
      await ssh.renameFile(oldPath, newPath);
    }
  }

  @override
  Future<void> createFile(String path, {required bool isDir, String? content}) async {
    try {
      await panel.createFile(path, isDir: isDir, content: content);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API createFile failed — using SSH ($e)');
      await ssh.createFile(path, isDir: isDir, content: content);
    }
  }

  @override
  Future<List<ContainerDomain>> listContainers() async {
    try {
      return await panel.listContainers();
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API listContainers failed — using SSH ($e)');
      return await ssh.listContainers();
    }
  }

  @override
  Future<void> startContainer(String name) async {
    try {
      await panel.startContainer(name);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API startContainer failed — using SSH ($e)');
      await ssh.startContainer(name);
    }
  }

  @override
  Future<void> stopContainer(String name) async {
    try {
      await panel.stopContainer(name);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API stopContainer failed — using SSH ($e)');
      await ssh.stopContainer(name);
    }
  }

  @override
  Future<void> restartContainer(String name) async {
    try {
      await panel.restartContainer(name);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API restartContainer failed — using SSH ($e)');
      await ssh.restartContainer(name);
    }
  }

  @override
  Future<void> pauseContainer(String name) async {
    try {
      await panel.pauseContainer(name);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API pauseContainer failed — using SSH ($e)');
      await ssh.pauseContainer(name);
    }
  }

  @override
  Future<void> unpauseContainer(String name) async {
    try {
      await panel.unpauseContainer(name);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API unpauseContainer failed — using SSH ($e)');
      await ssh.unpauseContainer(name);
    }
  }

  @override
  Future<void> removeContainer(String name, {bool force = true}) async {
    try {
      await panel.removeContainer(name, force: force);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API removeContainer failed — using SSH ($e)');
      await ssh.removeContainer(name, force: force);
    }
  }

  @override
  Future<ContainerInspect> inspectContainer(String name) async {
    try {
      return await panel.inspectContainer(name);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API inspectContainer failed — using SSH ($e)');
      return await ssh.inspectContainer(name);
    }
  }

  @override
  Stream<String> containerLogs(String name, {int tail = 200, bool follow = false}) {
    try {
      return panel.containerLogs(name, tail: tail, follow: follow);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API containerLogs failed — using SSH ($e)');
      return ssh.containerLogs(name, tail: tail, follow: follow);
    }
  }

  @override
  Future<void> setNtp(String server) async {
    try {
      await panel.setNtp(server);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API setNtp failed — using SSH ($e)');
      await ssh.setNtp(server);
    }
  }

  @override
  Future<void> changeRootPassword(String newPass) async {
    try {
      await panel.changeRootPassword(newPass);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API changeRootPassword failed — using SSH ($e)');
      await ssh.changeRootPassword(newPass);
    }
  }

  @override
  Stream<String> streamCommand(String cmd) {
    try {
      return panel.streamCommand(cmd);
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API streamCommand failed — using SSH ($e)');
      return ssh.streamCommand(cmd);
    }
  }

  @override
  Future<PanelStatus> detectPanel() async {
    try {
      return await panel.detectPanel();
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API detectPanel failed — using SSH ($e)');
      return ssh.detectPanel();
    }
  }

  @override
  Future<InteractiveSession> openShell() async {
    try {
      return await panel.openShell();
    } on PanelFallbackException catch (e) {
      appLogger.w('Fallback: API openShell failed — using SSH ($e)');
      return await ssh.openShell();
    }
  }
}
