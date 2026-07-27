// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/settings/theme_store.dart';
import 'package:lanxi/features/connection/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppState theme', () {
    test('setThemeMode updates mode, notifies, and persists', () async {
      final prefs = await SharedPreferences.getInstance();
      final app = AppState();
      app.attachThemeStore(ThemeStore(prefs));

      var notifications = 0;
      app.addListener(() => notifications++);

      app.setThemeMode(ThemeMode.light);

      expect(app.themeMode, ThemeMode.light);
      expect(notifications, 1);
      // Persisted to storage: a freshly built store reads it back.
      expect(ThemeStore(prefs).load(), ThemeMode.light);
    });

    test('setThemeMode is a no-op when mode is unchanged', () async {
      final prefs = await SharedPreferences.getInstance();
      final app = AppState();
      app.attachThemeStore(ThemeStore(prefs));

      var notifications = 0;
      app.addListener(() => notifications++);

      app.setThemeMode(ThemeMode.dark); // already the default

      expect(notifications, 0);
    });

    test('attachThemeStore loads saved mode and notifies when different',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lanxi_theme_mode', 'light');

      final app = AppState(); // defaults to dark
      var notifications = 0;
      app.addListener(() => notifications++);

      app.attachThemeStore(ThemeStore(prefs));

      expect(app.themeMode, ThemeMode.light);
      expect(notifications, 1);
    });
  });
}
