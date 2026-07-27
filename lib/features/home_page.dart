import 'package:flutter/material.dart';
import 'package:lanxi/features/connection/app_state.dart';
import 'package:lanxi/features/overview/overview_page.dart';
import 'package:lanxi/features/files/files_page.dart';
import 'package:lanxi/features/tools/tools_page.dart';

/// Main app shell with bottom navigation.
class HomePage extends StatefulWidget {
  final AppState appState;

  const HomePage({super.key, required this.appState});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final service = widget.appState.service;
    if (service == null) {
      return const Scaffold(
        body: Center(child: Text('未连接')),
      );
    }

    final pages = <Widget>[
      OverviewPage(service: service),
      FilesPage(service: service),
      ToolsPage(service: service),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_currentIndex)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: '断开连接',
            onPressed: () {
              widget.appState.disconnect();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '概览',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '文件',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: '工具',
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return '概览';
      case 1:
        return '文件';
      case 2:
        return '工具';
      default:
        return 'Lanxi';
    }
  }
}
