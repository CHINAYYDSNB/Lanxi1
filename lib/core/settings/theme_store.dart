import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's [ThemeMode] preference.
///
/// Defaults to [ThemeMode.dark] (the app's original look) when nothing is
/// stored yet.
class ThemeStore {
  static const _key = 'lanxi_theme_mode';

  final SharedPreferences _prefs;

  ThemeStore(this._prefs);

  ThemeMode load() {
    final value = _prefs.getString(_key);
    if (value == null) return ThemeMode.dark;
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.dark,
    );
  }

  Future<void> save(ThemeMode mode) => _prefs.setString(_key, mode.name);
}
