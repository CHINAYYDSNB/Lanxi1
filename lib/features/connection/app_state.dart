import 'package:flutter/material.dart';
import 'package:lanxi/core/settings/theme_store.dart';
import 'package:lanxi/services/server_service.dart';

/// Holds the current [ServerService] connection state and the selected
/// [ThemeMode].
///
/// Passed down the widget tree. Pages read [service] to call server operations
/// and read [themeMode] to reflect (or toggle) the active theme.
class AppState extends ChangeNotifier {
  ServerService? _service;
  ThemeMode _themeMode;
  ThemeStore? _themeStore;

  AppState({ThemeMode themeMode = ThemeMode.dark}) : _themeMode = themeMode;

  ServerService? get service => _service;

  bool get isConnected => _service != null;

  ThemeMode get themeMode => _themeMode;

  /// Bind the persistent [ThemeStore] and load any saved preference.
  void attachThemeStore(ThemeStore store) {
    _themeStore = store;
    final loaded = store.load();
    if (loaded != _themeMode) {
      _themeMode = loaded;
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _themeStore?.save(mode);
  }

  void connect(ServerService service) {
    _service = service;
    notifyListeners();
  }

  void disconnect() {
    _service = null;
    notifyListeners();
  }
}
