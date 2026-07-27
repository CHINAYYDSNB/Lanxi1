// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/settings/theme_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ThemeStore', () {
    test('defaults to dark when nothing stored', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ThemeStore(prefs).load(), ThemeMode.dark);
    });

    test('save then load round-trips the persisted mode', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = ThemeStore(prefs);

      await store.save(ThemeMode.light);

      // A fresh store reading the same prefs sees the saved value.
      expect(ThemeStore(prefs).load(), ThemeMode.light);
    });

    test('unknown stored value falls back to dark', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lanxi_theme_mode', 'bogus');
      expect(ThemeStore(prefs).load(), ThemeMode.dark);
    });
  });
}
