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
        body: Center(child: Text('No connection')),
      );
    }

    final pages = <Widget>[
      OverviewPage(service: service),
      FilesPage(service: service),
      const ToolsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_currentIndex)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: 'Disconnect',
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
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Files',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Tools',
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Overview';
      case 1:
        return 'Files';
      case 2:
        return 'Tools';
      default:
        return 'Lanxi';
    }
  }
}
