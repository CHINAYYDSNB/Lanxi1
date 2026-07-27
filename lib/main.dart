import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/settings/theme_store.dart';
import 'package:lanxi/core/store/secret_store.dart';
import 'package:lanxi/core/store/server_store.dart';
import 'package:lanxi/features/connection/app_state.dart';
import 'package:lanxi/features/connection/connect_helper.dart';
import 'package:lanxi/features/connection/server_list_page.dart';
import 'package:lanxi/features/home_page.dart';
import 'package:lanxi/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  ServerStore? _store;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChanged);
    _initStoreAndAutoConnect();
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    _appState.dispose();
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  Future<void> _initStoreAndAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final store = ServerStore(prefs: prefs, secret: SecureStorageSecretStore());
    if (!mounted) return;
    _appState.attachThemeStore(ThemeStore(prefs));
    setState(() => _store = store);

    // Try auto-connect to the first available candidate.
    try {
      final candidates = await store.autoConnectCandidates();
      for (final profile in candidates) {
        try {
          final service = await connectProfile(profile, store);
          if (!mounted) return;
          _appState.connect(service);
          appLogger.i('Auto-connected to ${profile.name}');
          return;
        } catch (e) {
          appLogger.w('Auto-connect failed for ${profile.name}', e);
        }
      }
    } catch (e) {
      appLogger.e('Auto-connect sequence error', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_store == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Lanxi',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _appState.themeMode,
      home: _appState.isConnected
          ? HomePage(appState: _appState)
          : ServerListPage(appState: _appState, store: _store!),
    );
  }
}
