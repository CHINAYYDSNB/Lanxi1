/// SSH-backed [InteractiveSession] backed by dartssh2's PTY shell.
///
/// Only this file (in `lib/core`) is allowed to import [dartssh2]; the UI
/// layer never sees [SSHSession] directly.
library;

import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:lanxi/core/source/interactive_session.dart';

/// Wraps an opened [SSHSession] as an [InteractiveSession].
///
/// Construct via [SshInteractiveSession.open] (which negotiates the PTY) rather
/// than directly, so the caller does not deal with [SSHClient].
class SshInteractiveSession implements InteractiveSession {
  final SSHSession _session;

  SshInteractiveSession(this._session);

  /// Open a PTY shell on [client] with the given initial window size.
  static Future<SshInteractiveSession> open(
    SSHClient client, {
    int width = 80,
    int height = 24,
  }) async {
    final shell = await client.shell(
      pty: SSHPtyConfig(width: width, height: height),
    );
    return SshInteractiveSession(shell);
  }

  @override
  Stream<String> get output =>
      _session.stdout.map((chunk) => utf8.decode(chunk.toList()));

  @override
  void write(String data) {
    _session.stdin.add(utf8.encode(data));
  }

  @override
  Future<void> resize({required int width, required int height}) async {
    _session.resizeTerminal(width, height);
  }

  @override
  Future<void> close() async {
    _session.close();
  }
}
