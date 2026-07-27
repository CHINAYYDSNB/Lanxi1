/// The ONLY place where the transport channel is decided.
///
/// Build rule:
///   - Has `apiKey` → use [ServerSourceType.panel] (FallbackServerSource)
///   - No `apiKey`  → use [ServerSourceType.ssh] (SshServerSource)
library;

import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/ssh/ssh_connection.dart';
import 'package:lanxi/core/ssh/ssh_session_pool.dart';
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
    return SshServerSource(
      pool: SshSessionPool(),
      credentials: creds,
    );
  }
}
