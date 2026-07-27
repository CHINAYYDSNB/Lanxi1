// ignore_for_file: require_trailing_commas

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/server_source_factory.dart';
import 'package:lanxi/core/store/secret_store.dart';
import 'package:lanxi/core/store/server_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [SecretStore] for tests — no OS keyring needed.
class _MemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({required String key}) async => _data[key];

  @override
  Future<void> write({required String key, required String value}) async =>
      _data[key] = value;

  @override
  Future<void> delete({required String key}) async => _data.remove(key);
}

ServerProfile _profile({
  String id = 's1',
  String name = 'web',
  ServerSourceType type = ServerSourceType.ssh,
  String host = '10.0.0.5',
  int port = 22,
  String username = 'root',
  bool autoConnect = false,
}) =>
    ServerProfile(
      id: id,
      name: name,
      type: type,
      host: host,
      port: port,
      username: username,
      autoConnect: autoConnect,
    );

void main() {
  late _MemorySecretStore secret;
  late ServerStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    secret = _MemorySecretStore();
    store = ServerStore(prefs: prefs, secret: secret);
  });

  group('save / list', () {
    test('persists metadata and excludes secrets from SharedPreferences',
        () async {
      await store.save(
        _profile(),
        password: 'secret123',
        sshKey: 'PEM',
      );

      final all = await store.list();
      expect(all.length, 1);
      expect(all.first.id, 's1');
      expect(all.first.name, 'web');
      expect(all.first.host, '10.0.0.5');
      expect(all.first.autoConnect, false);
      // secrets are NOT in the meta JSON
      final raw = (await SharedPreferences.getInstance()).getString('lanxi_servers');
      expect(raw, isNotNull);
      expect(raw, isNot(contains('secret123')));
      expect(raw, isNot(contains('PEM')));
    });

    test('upserts: saving same id replaces, not duplicates', () async {
      await store.save(_profile(name: 'first'));
      await store.save(_profile(name: 'second'));

      final all = await store.list();
      expect(all.length, 1);
      expect(all.first.name, 'second');
    });
  });

  group('get', () {
    test('returns profile by id or null', () async {
      await store.save(_profile(id: 'a'));
      await store.save(_profile(id: 'b'));

      expect((await store.get('a'))?.id, 'a');
      expect(await store.get('missing'), isNull);
    });
  });

  group('delete', () {
    test('removes both metadata and secrets', () async {
      await store.save(_profile(id: 'x'), password: 'p');
      expect(await store.get('x'), isNotNull);

      await store.delete('x');

      expect(await store.get('x'), isNull);
      expect(await secret.read(key: 'server_x_secret'), isNull);
      expect(await store.list(), isEmpty);
    });
  });

  group('autoConnectCandidates', () {
    test('returns only profiles with autoConnect', () async {
      await store.save(_profile(id: 'auto', autoConnect: true));
      await store.save(_profile(id: 'manual', autoConnect: false));

      final cands = await store.autoConnectCandidates();
      expect(cands.map((p) => p.id), ['auto']);
    });
  });

  group('loadSecrets', () {
    test('merges stored secrets into the profile', () async {
      await store.save(
        _profile(id: 's'),
        password: 'pw',
        sshKey: 'key',
        apiKey: 'ak',
      );

      final meta = (await store.list()).first;
      expect(meta.password, isNull);

      final withSecrets = await store.loadSecrets(meta);
      expect(withSecrets.password, 'pw');
      expect(withSecrets.sshKey, 'key');
      expect(withSecrets.apiKey, 'ak');
    });

    test('returns profile unchanged when no secrets stored', () async {
      await store.save(_profile(id: 'n'));
      final meta = (await store.list()).first;
      final result = await store.loadSecrets(meta);
      expect(result.password, isNull);
    });
  });

  group('ServerProfile JSON round-trip', () {
    test('toMetaJson omits secrets; fromMetaJson restores metadata',
        () async {
      final p = _profile(id: 'r', name: 'rt', autoConnect: true)
          .copyWith(password: 'x');
      final json = p.toMetaJson();
      expect(json, isNot(containsValue('x')));
      expect(json['autoConnect'], true);

      final restored = ServerProfile.fromMetaJson(json);
      expect(restored.id, 'r');
      expect(restored.name, 'rt');
      expect(restored.autoConnect, true);
      expect(restored.type, ServerSourceType.ssh);
    });

    test('fromMetaJson defaults missing fields', () {
      final restored = ServerProfile.fromMetaJson(
        jsonDecode('{"id":"d","name":"n","host":"h","username":"u"}')
            as Map<String, dynamic>,
      );
      expect(restored.port, 22);
      expect(restored.autoConnect, false);
      expect(restored.type, ServerSourceType.ssh);
    });
  });
}
