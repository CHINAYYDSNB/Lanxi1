/// The ONLY place where the transport channel is decided.
///
/// Build rule:
///   - Has `apiKey` → use [ServerSourceType.panel] (FallbackServerSource)
///   - No `apiKey`  → use [ServerSourceType.ssh] (SshServerSource)
library;

import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/ssh/ssh_connection.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/core/source/ssh_server_source.dart';

/// Which transport to use.
enum ServerSourceType { ssh, panel }

/// Profile describing a target server.
class ServerProfile {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? sshKey;
  final String? apiKey;

  const ServerProfile({
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.sshKey,
    this.apiKey,
  });
}

/// Builds the correct [ServerSource] for a given [ServerProfile].
abstract final class ServerSourceFactory {
  static ServerSource build(ServerProfile profile) {
    if (profile.apiKey != null && profile.apiKey!.isNotEmpty) {
      appLogger.i('ServerSourceFactory: building panel-fallback source');
      // Panel + SSH fallback — requires Panel classes (Phase 1 placeholder).
      throw UnimplementedError(
        'FallbackServerSource requires the panel layer. '
        'Use ServerSourceFactory.buildSsh() for now.',
      );
    }

    appLogger.i('ServerSourceFactory: building SSH-only source');
    return buildSsh(profile);
  }

  /// Build an SSH-only source (bypasses the panel layer).
  static SshServerSource buildSsh(ServerProfile profile) {
    final creds = SshCredentials(
      host: profile.host,
      port: profile.port,
      username: profile.username,
      password: profile.password,
      privateKey: profile.sshKey,
    );
    // In a real app the connection is established lazily or
    // injected. Here we just wrap it.
    final conn = _DeferredSshConnection(creds);
    return SshServerSource(conn);
  }
}

/// Thin wrapper that defers socket creation until first use.
class _DeferredSshConnection implements SshConnection {
  final SshCredentials credentials;
  SshConnection? _inner;

  _DeferredSshConnection(this.credentials);

  Future<SshConnection> _ensure() async {
    if (_inner == null || !_inner!.isConnected) {
      // Inline import to avoid circular dependency.
      // Real implementation connects via dartssh2.
      throw UnimplementedError(
        'SSH connection not yet established. Use SshSessionPool.connect().',
      );
    }
    return _inner!;
  }

  @override
  Future<void> connect() async {
    // This would create a real dartssh2 SSHClient.
    throw UnimplementedError('connect() deferred — use SshSessionPool');
  }

  @override
  Future<String> exec(String command) async {
    final conn = await _ensure();
    return conn.exec(command);
  }

  @override
  Stream<String> execStream(String command) =>
      throw UnimplementedError('execStream deferred');

  @override
  Future<SshExecResult> execWithStderr(String command) =>
      throw UnimplementedError('execWithStderr deferred');

  @override
  Future<void> disconnect() async {
    await _inner?.disconnect();
    _inner = null;
  }

  @override
  bool get isConnected => _inner?.isConnected ?? false;
}
