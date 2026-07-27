// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/server_source_factory.dart';
import 'package:lanxi/core/store/secret_store.dart';
import 'package:lanxi/core/store/server_store.dart';
import 'package:lanxi/features/connection/app_state.dart';
import 'package:lanxi/features/connection/server_list_page.dart';
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

Future<ServerStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ServerStore(prefs: prefs, secret: _MemorySecretStore());
}

void main() {
  group('ServerListPage', () {
    testWidgets('shows empty state when no servers', (tester) async {
      final store = await _store();
      await tester.pumpWidget(
        MaterialApp(home: ServerListPage(appState: AppState(), store: store)),
      );
      await tester.pumpAndSettle();
      expect(find.text('还没有服务器'), findsOneWidget);
    });

    testWidgets('renders a saved server and deletes it', (tester) async {
      final store = await _store();
      await store.save(
        const ServerProfile(
          id: 'a',
          name: 'srv',
          type: ServerSourceType.ssh,
          host: '1.2.3.4',
          username: 'root',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ServerListPage(appState: AppState(), store: store),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('srv'), findsWidgets);
      expect(find.text('1.2.3.4:22'), findsOneWidget);

      await tester.tap(find.byTooltip('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      expect(await store.list(), isEmpty);
    });
  });
}
