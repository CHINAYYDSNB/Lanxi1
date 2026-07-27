// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:lanxi/widgets/app_card.dart';

/// File browser with breadcrumb navigation.
class FilesPage extends StatefulWidget {
  final ServerService service;

  const FilesPage({super.key, required this.service});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  String _currentPath = '/root';
  List<FileItem>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _navigateTo(_currentPath);
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _currentPath = path;
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.service.listDir(path);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      appLogger.e('Failed to list directory $path', e);
      if (!mounted) return;
      setState(() {
        _error = '加载失败：$e';
        _loading = false;
      });
    }
  }

  void _openItem(FileItem item) {
    if (item.isDir) {
      _navigateTo(item.path);
    } else {
      _showFileInfo(item);
    }
  }

  void _showFileInfo(FileItem item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: Theme.of(ctx).textTheme.titleMedium),
            const Divider(),
            _attr(ctx, '路径', item.path),
            _attr(ctx, '大小', item.sizeFormatted),
            _attr(ctx, '类型', item.isDir ? '目录' : '文件'),
            _attr(ctx, '权限', item.permissions),
            _attr(ctx, '修改时间', item.modifiedTime.toString()),
          ],
        ),
      ),
    );
  }

  Widget _attr(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  )),
          Text(value, style: Theme.of(ctx).textTheme.bodyMedium),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Breadcrumb
        _BreadcrumbBar(
          path: _currentPath,
          onSegmentTap: (segPath) => _navigateTo(segPath),
          onBack: _currentPath != '/'
              ? () {
                  final parent = _parentPath(_currentPath);
                  _navigateTo(parent);
                }
              : null,
        ),

        // Content
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => _navigateTo(_currentPath),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('空目录',
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _navigateTo(_currentPath),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final item = items[i];
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Icon(
                item.isDir ? Icons.folder : _fileIcon(item.name),
                color: item.isDir
                    ? Colors.amber.shade300
                    : Theme.of(ctx).colorScheme.primary,
              ),
              title: Text(item.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        item.isDir ? FontWeight.w500 : FontWeight.normal,
                  )),
              subtitle: Text(
                '${item.sizeFormatted}  ·  ${_formatModified(item.modifiedTime)}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              trailing: item.isDir
                  ? const Icon(Icons.chevron_right, size: 18)
                  : null,
              onTap: () => _openItem(item),
            ),
          );
        },
      ),
    );
  }

  IconData _fileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.code;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.settings;
    if (name.endsWith('.md')) return Icons.description;
    if (name.endsWith('.json')) return Icons.data_object;
    if (name.endsWith('.sh')) return Icons.terminal;
    if (name.endsWith('.log')) return Icons.article;
    if (name.endsWith('.gz') ||
        name.endsWith('.zip') ||
        name.endsWith('.tar')) {
      return Icons.archive;
    }
    return Icons.insert_drive_file;
  }

  String _formatModified(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _parentPath(String path) {
    if (path == '/') return '/';
    final trimmed =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final lastSlash = trimmed.lastIndexOf('/');
    return lastSlash == 0 ? '/' : trimmed.substring(0, lastSlash);
  }
}

/// Breadcrumb bar showing current directory path.
class _BreadcrumbBar extends StatelessWidget {
  final String path;
  final void Function(String segmentPath) onSegmentTap;
  final VoidCallback? onBack;

  const _BreadcrumbBar({
    required this.path,
    required this.onSegmentTap,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
              tooltip: '上级目录',
              visualDensity: VisualDensity.compact,
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Root "/"
                  _BreadcrumbChip(
                    label: '/',
                    onTap: () => onSegmentTap('/'),
                    isLast: segments.isEmpty,
                  ),
                  // Segments
                  for (int i = 0; i < segments.length; i++) ...[
                    Icon(Icons.chevron_right,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    _BreadcrumbChip(
                      label: segments[i],
                      onTap: () {
                        final segPath = '/${segments.take(i + 1).join('/')}';
                        onSegmentTap(segPath);
                      },
                      isLast: i == segments.length - 1,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  const _BreadcrumbChip({
    required this.label,
    required this.onTap,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: isLast
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.primary,
      ),
      child: Text(label),
    );
  }
}
