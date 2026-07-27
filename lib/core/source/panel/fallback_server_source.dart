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
