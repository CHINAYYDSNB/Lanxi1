import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/source/server_source_factory.dart';
import 'package:lanxi/core/store/server_store.dart';
import 'package:lanxi/features/connection/app_state.dart';
import 'package:lanxi/features/connection/connect_helper.dart';
import 'package:lanxi/features/connection/server_edit_page.dart';
import 'package:lanxi/widgets/app_card.dart';

/// Lists saved server profiles and lets the user connect / edit / add.
///
/// Connects through [connectProfile] (which picks the transport via the
/// factory) and hands the resulting [ServerService] to [AppState].
class ServerListPage extends StatefulWidget {
  final AppState appState;
  final ServerStore store;

  const ServerListPage({
    super.key,
    required this.appState,
    required this.store,
  });

  @override
  State<ServerListPage> createState() => _ServerListPageState();
}

class _ServerListPageState extends State<ServerListPage> {
  List<ServerProfile> _servers = [];
  bool _loading = true;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final list = await widget.store.list();
      if (!mounted) return;
      setState(() {
        _servers = list;
        _loading = false;
      });
    } catch (e) {
      appLogger.e('Failed to load server list', e);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _connect(ServerProfile profile) async {
    setState(() => _connectingId = profile.id);
    try {
      final service = await connectProfile(profile, widget.store);
      if (!mounted) return;
      widget.appState.connect(service);
    } catch (e) {
      appLogger.e('Connection failed for ${profile.name}', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('连接失败：$e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      setState(() => _connectingId = null);
    }
  }

  Future<void> _delete(ServerProfile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定删除「${profile.name}」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.store.delete(profile.id);
    await _refresh();
  }

  Future<void> _openEditor([ServerProfile? existing]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ServerEditPage(
          store: widget.store,
          existing: existing,
        ),
      ),
    );
    if (result == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('添加服务器'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _servers.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _servers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _serverCard(_servers[i]),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dns,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '还没有服务器',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮添加一台 SSH 或 1Panel 服务器。',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serverCard(ServerProfile profile) {
    final isConnecting = _connectingId == profile.id;
    final typeLabel =
        profile.type == ServerSourceType.panel ? '1Panel' : 'SSH';
    final typeColor = profile.type == ServerSourceType.panel
        ? Colors.green
        : Colors.indigo;

    return AppCard(
      icon: Icons.dns,
      title: profile.name,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
            onPressed: () => _openEditor(profile),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: () => _delete(profile),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.computer, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${profile.host}:${profile.port}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(color: typeColor, fontSize: 12),
                ),
              ),
            ],
          ),
          if (profile.autoConnect)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.power_settings_new,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '开机自动连接',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isConnecting ? null : () => _connect(profile),
              icon: isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(isConnecting ? '连接中...' : '连接'),
            ),
          ),
        ],
      ),
    );
  }
}
