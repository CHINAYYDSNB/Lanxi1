// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/server_source_factory.dart';
import 'package:lanxi/core/store/secret_store.dart';
import 'package:lanxi/core/store/server_store.dart';
import 'package:lanxi/features/connection/server_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  group('ServerEditPage', () {
    testWidgets('saves an SSH profile with secrets', (tester) async {
      final store = await _sharedPrefsStore();

      await tester.pumpWidget(
        MaterialApp(home: ServerEditPage(store: store)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '服务器名称'),
        'web1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '主机地址'),
        '10.0.0.9',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '用户名'),
        'root',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '密码（可选）'),
        'pw123',
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final all = await store.list();
      expect(all.length, 1);
      expect(all.first.name, 'web1');
      expect(all.first.type, ServerSourceType.ssh);

      final withSecrets = await store.loadSecrets(all.first);
      expect(withSecrets.password, 'pw123');
    });

    testWidgets('switches to 1Panel and saves apiKey', (tester) async {
      final store = await _sharedPrefsStore();

      await tester.pumpWidget(
        MaterialApp(home: ServerEditPage(store: store)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('1Panel'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '服务器名称'),
        'panel1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '主机地址'),
        '10.0.0.10',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '1Panel API 密钥'),
        'api-xyz',
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final all = await store.list();
      expect(all.length, 1);
      expect(all.first.type, ServerSourceType.panel);
      expect(all.first.port, 9999); // panel default port

      final withSecrets = await store.loadSecrets(all.first);
      expect(withSecrets.apiKey, 'api-xyz');
    });
  });
}

Future<ServerStore> _sharedPrefsStore() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ServerStore(prefs: prefs, secret: _MemorySecretStore());
}
