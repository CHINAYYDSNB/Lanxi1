import 'package:flutter/material.dart';

/// Light and dark themes for Lanxi.
///
/// Both share the indigo seed and Material 3; the only difference is the
/// brightness, toggled at runtime via [ThemeMode] in [MaterialApp].
final lightTheme = ThemeData(
  colorSchemeSeed: Colors.indigo,
  useMaterial3: true,
  brightness: Brightness.light,
);

final darkTheme = ThemeData(
  colorSchemeSeed: Colors.indigo,
  useMaterial3: true,
  brightness: Brightness.dark,
);
