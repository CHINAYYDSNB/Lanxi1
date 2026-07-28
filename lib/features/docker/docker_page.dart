// ignore_for_file: require_trailing_commas
// CI rule: strings containing $var MUST stay double-quoted (single quotes
// silently skip interpolation). Mirrors ssh_server_source.dart.
// ignore_for_file: prefer_single_quotes

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/models/dto/container_dto.dart';
import 'package:lanxi/services/server_service.dart';

import 'container_detail_page.dart';
import 'container_log_page.dart';

/// Docker container management screen.
class DockerPage extends StatefulWidget {
  final ServerService service;

  const DockerPage({super.key, required this.service});

  @override
  State<DockerPage> createState() => _DockerPageState();
}

class _DockerPageState extends State<DockerPage> {
  List<ContainerDomain>? _containers;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.service.listContainers();
      if (!mounted) return;
      setState(() {
        _containers = items;
        _loading = false;
      });
    } catch (e) {
      appLogger.e('Failed to list containers', e);
      if (!mounted) return;
      setState(() {
        _error = "加载失败：$e";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('容器')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        tooltip: '刷新',
        onPressed: _load,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _containers == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final list = _containers ?? [];
    if (list.isEmpty) {
      return const Center(child: Text('暂无容器'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _ContainerTile(
          container: list[i],
          onAction: _handleAction,
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action,
      ContainerDomain container) async {
    if (action == 'detail') {
      if (!mounted) return;
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContainerDetailPage(
              service: widget.service,
              container: container,
            ),
          ),
        ),
      );
      return;
    }
    if (action == 'log') {
      if (!mounted) return;
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContainerLogPage(
              service: widget.service,
              containerName: container.name,
            ),
          ),
        ),
      );
      return;
    }
    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('删除容器'),
          content: Text('确定要删除容器 ${container.name} 吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final label = _actionLabel(action);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("正在$label ${container.name}...")));
    try {
      switch (action) {
        case 'start':
          await widget.service.startContainer(container.name);
        case 'stop':
          await widget.service.stopContainer(container.name);
        case 'restart':
          await widget.service.restartContainer(container.name);
        case 'pause':
          await widget.service.pauseContainer(container.name);
        case 'unpause':
          await widget.service.unpauseContainer(container.name);
        case 'delete':
          await widget.service.removeContainer(container.name);
      }
      await _load();
    } catch (e) {
      appLogger.e("docker operate $action failed", e);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("操作失败：$e")));
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'start':
        return '启动';
      case 'stop':
        return '停止';
      case 'restart':
        return '重启';
      case 'pause':
        return '暂停';
      case 'unpause':
        return '恢复';
      case 'delete':
        return '删除';
      default:
        return action;
    }
  }
}

class _ContainerTile extends StatelessWidget {
  final ContainerDomain container;
  final Future<void> Function(BuildContext, String, ContainerDomain) onAction;

  const _ContainerTile({required this.container, required this.onAction});

  Color _statusColor(String state) {
    switch (state) {
      case 'running':
        return Colors.green;
      case 'exited':
      case 'stopped':
        return Colors.red;
      case 'paused':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _statusColor(container.state);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onAction(context, 'detail', container),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      container.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (container.image.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        container.image,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (container.ports.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        container.ports.join('  '),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  container.stateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) => onAction(context, action, container),
                itemBuilder: (_) => [
                  if (container.isRunning) ...[
                    const PopupMenuItem(value: 'stop', child: Text('停止')),
                    const PopupMenuItem(value: 'restart', child: Text('重启')),
                    const PopupMenuItem(value: 'pause', child: Text('暂停')),
                  ],
                  if (container.isStopped)
                    const PopupMenuItem(value: 'start', child: Text('启动')),
                  if (container.isPaused)
                    const PopupMenuItem(value: 'unpause', child: Text('恢复')),
                  const PopupMenuItem(value: 'log', child: Text('日志')),
                  const PopupMenuItem(value: 'detail', child: Text('详情')),
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
