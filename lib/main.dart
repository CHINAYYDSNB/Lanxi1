import 'package:flutter/material.dart';
import 'package:lanxi/features/connection/app_state.dart';
import 'package:lanxi/features/connection/connection_screen.dart';
import 'package:lanxi/features/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LanxiApp());
}

class LanxiApp extends StatefulWidget {
  const LanxiApp({super.key});

  @override
  State<LanxiApp> createState() => _LanxiAppState();
}

class _LanxiAppState extends State<LanxiApp> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    _appState.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lanxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: _appState.isConnected
          ? HomePage(appState: _appState)
          : ConnectionScreen(appState: _appState),
    );
  }
}
