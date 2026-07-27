import 'dart:convert';

import 'package:lanxi/core/source/server_source_factory.dart';
import 'package:lanxi/core/store/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent store for server profiles.
///
/// - Metadata (id / name / type / host / port / username / autoConnect) is kept
///   in [SharedPreferences] as a single JSON list.
/// - Secrets (password / sshKey / apiKey) are kept in [SecretStore] under a
///   per-server key, never in plain [SharedPreferences].
///
/// No network, no [dartssh2]/[dio] — pure persistence. UI talks to this only
/// through the Service layer.
class ServerStore {
  static const String _metaKey = 'lanxi_servers';

  final SharedPreferences _prefs;
  final SecretStore _secret;

  ServerStore({required SharedPreferences prefs, required SecretStore secret})
      : _prefs = prefs,
        _secret = secret;

  /// All stored profiles (metadata only — secrets must be loaded separately).
  Future<List<ServerProfile>> list() async {
    final raw = _prefs.getString(_metaKey);
    if (raw == null) return <ServerProfile>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ServerProfile.fromMetaJson)
        .toList();
  }

  Future<ServerProfile?> get(String id) async {
    final found = (await list()).where((p) => p.id == id);
    return found.isEmpty ? null : found.first;
  }

  /// Profiles flagged for auto-connect on launch.
  Future<List<ServerProfile>> autoConnectCandidates() async =>
      (await list()).where((p) => p.autoConnect).toList();

  /// Persist metadata + secrets. Missing secret fields are stored as null.
  Future<void> save(
    ServerProfile profile, {
    String? password,
    String? sshKey,
    String? apiKey,
  }) async {
    final all = await list();
    all.removeWhere((p) => p.id == profile.id);
    all.add(profile);
    await _prefs.setString(
      _metaKey,
      jsonEncode(all.map((p) => p.toMetaJson()).toList()),
    );

    final bundle = jsonEncode({
      'password': password,
      'sshKey': sshKey,
      'apiKey': apiKey,
    });
    await _secret.write(key: _secretKey(profile.id), value: bundle);
  }

  /// Delete a profile and its secrets.
  Future<void> delete(String id) async {
    final all = await list();
    all.removeWhere((p) => p.id == id);
    await _prefs.setString(
      _metaKey,
      jsonEncode(all.map((p) => p.toMetaJson()).toList()),
    );
    await _secret.delete(key: _secretKey(id));
  }

  /// Returns a copy of [profile] with secrets loaded from secure storage.
  Future<ServerProfile> loadSecrets(ServerProfile profile) async {
    final raw = await _secret.read(key: _secretKey(profile.id));
    if (raw == null) return profile;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return profile;
    return profile.copyWith(
      password: decoded['password'] as String?,
      sshKey: decoded['sshKey'] as String?,
      apiKey: decoded['apiKey'] as String?,
    );
  }

  String _secretKey(String id) => 'server_${id}_secret';
}
