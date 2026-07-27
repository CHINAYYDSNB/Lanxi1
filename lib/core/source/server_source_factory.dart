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

import 'exceptions.dart';

/// Which transport to use.
enum ServerSourceType { ssh, panel }

/// Profile describing a target server.
///
/// Secrets ([password]/[sshKey]/[apiKey]) are in-memory only. They are never
/// written to [SharedPreferences]; [ServerStore] persists them via secure
/// storage. [toMetaJson]/[fromMetaJson] serialize only non-secret metadata.
class ServerProfile {
  final String id;
  final String name;
  final ServerSourceType type;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? sshKey;
  final String? apiKey;
  final bool autoConnect;

  const ServerProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.sshKey,
    this.apiKey,
    this.autoConnect = false,
  });

  ServerProfile copyWith({
    String? id,
    String? name,
    ServerSourceType? type,
    String? host,
    int? port,
    String? username,
    String? password,
    String? sshKey,
    String? apiKey,
    bool? autoConnect,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      sshKey: sshKey ?? this.sshKey,
      apiKey: apiKey ?? this.apiKey,
      autoConnect: autoConnect ?? this.autoConnect,
    );
  }

  Map<String, dynamic> toMetaJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'host': host,
        'port': port,
        'username': username,
        'autoConnect': autoConnect,
      };

  factory ServerProfile.fromMetaJson(Map<String, dynamic> json) {
    final typeName = (json['type'] as String?) ?? 'ssh';
    return ServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ServerSourceType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => ServerSourceType.ssh,
      ),
      host: json['host'] as String,
      port: (json['port'] as int?) ?? 22,
      username: json['username'] as String,
      autoConnect: (json['autoConnect'] as bool?) ?? false,
    );
  }

  /// Generates a time-based unique id for unsaved / temporary profiles.
  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}

/// Builds the correct [ServerSource] for a given [ServerProfile].
abstract final class ServerSourceFactory {
  static ServerSource build(ServerProfile profile) {
    if (profile.apiKey != null && profile.apiKey!.isNotEmpty) {
      appLogger.i('ServerSourceFactory: building panel-fallback source');
      throw const PlatformNotSupportedException(
        'FallbackServerSource (Panel+SSH) not yet wired — '
        'use ServerSourceFactory.buildSsh() for SSH-only.',
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
