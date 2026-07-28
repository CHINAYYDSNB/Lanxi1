// ignore_for_file: require_trailing_commas
// CI rule: strings containing $var MUST stay double-quoted (single quotes
// silently skip interpolation). Mirrors ssh_server_source.dart.
// ignore_for_file: prefer_single_quotes

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:lanxi/widgets/app_card.dart';

import 'file_editor_page.dart';

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
      appLogger.e("Failed to list directory $path", e);
      if (!mounted) return;
      setState(() {
        _error = "加载失败：$e";
        _loading = false;
      });
    }
  }

  void _openItem(FileItem item) {
    if (item.isDir) {
      unawaited(_navigateTo(item.path));
    } else {
      unawaited(_openEditor(item));
    }
  }

  Future<void> _openEditor(FileItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileEditorPage(
          service: widget.service,
          filePath: item.path,
          fileName: item.name,
        ),
      ),
    );
  }

  /// Long-press menu: rename / delete / properties.
  Future<void> _showItemMenu(FileItem item) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('属性'),
              onTap: () => Navigator.pop(ctx, 'info'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              textColor: Theme.of(ctx).colorScheme.error,
              iconColor: Theme.of(ctx).colorScheme.error,
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'rename') {
      await _renameItem(item);
    } else if (choice == 'info') {
      _showFileInfo(item);
    } else if (choice == 'delete') {
      await _deleteItem(item);
    }
  }

  Future<void> _renameItem(FileItem item) async {
    final ctrl = TextEditingController(text: item.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '新名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == item.name) return;
    final parent = _parentPath(item.path);
    final newPath = parent == '/' ? "/$newName" : "$parent/$newName";
    try {
      await widget.service.renameFile(item.path, newPath);
      if (!mounted) return;
      unawaited(_navigateTo(_currentPath));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("重命名失败：$e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteItem(FileItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除'),
        content: Text('确定删除「${item.name}」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.service.deleteFile(item.path, isDir: item.isDir);
      if (!mounted) return;
      unawaited(_navigateTo(_currentPath));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("删除失败：$e"), backgroundColor: Colors.red),
      );
    }
  }

  /// FAB: create a new file or directory under the current path.
  Future<void> _createItem({required bool isDir}) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDir ? '新建文件夹' : '新建文件'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final parent = _currentPath;
    final path = parent == '/' ? "/$name" : "$parent/$name";
    try {
      await widget.service.createFile(path, isDir: isDir);
      if (!mounted) return;
      unawaited(_navigateTo(_currentPath));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("创建失败：$e"), backgroundColor: Colors.red),
      );
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
    return Scaffold(
      body: Column(
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateMenu,
        tooltip: '新建',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// FAB menu: choose to create a file or a directory.
  Future<void> _showCreateMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: const Text('新建文件'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('新建文件夹'),
              onTap: () => Navigator.pop(ctx, 'dir'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'file') {
      unawaited(_createItem(isDir: false));
    } else if (choice == 'dir') {
      unawaited(_createItem(isDir: true));
    }
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
              onLongPress: () => _showItemMenu(item),
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
