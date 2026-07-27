import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LanxiApp());
}

class LanxiApp extends StatelessWidget {
  const LanxiApp({super.key});

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
      home: const Scaffold(
        body: Center(
          child: Text('Lanxi - Phase 1 Skeleton'),
        ),
      ),
    );
  }
}
