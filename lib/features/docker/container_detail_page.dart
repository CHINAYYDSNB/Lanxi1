// ignore_for_file: require_trailing_commas
// CI rule: strings containing $var MUST stay double-quoted. Mirrors
// ssh_server_source.dart. Keep this file's interpolated strings double-quoted.
// ignore_for_file: prefer_single_quotes

import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/models/dto/container_dto.dart';
import 'package:lanxi/services/server_service.dart';

/// Shows detailed inspection data for a single container.
class ContainerDetailPage extends StatefulWidget {
  final ServerService service;
  final ContainerDomain container;

  const ContainerDetailPage({
    super.key,
    required this.service,
    required this.container,
  });

  @override
  State<ContainerDetailPage> createState() => _ContainerDetailPageState();
}

class _ContainerDetailPageState extends State<ContainerDetailPage> {
  ContainerInspect? _inspect;
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
      final inspect = await widget.service.inspectContainer(widget.container.name);
      if (!mounted) return;
      setState(() {
        _inspect = inspect;
        _loading = false;
      });
    } catch (e) {
      appLogger.e('Failed to inspect container', e);
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
      appBar: AppBar(
        title: Text(widget.container.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
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
    final inspect = _inspect;
    if (inspect == null) {
      return const Center(child: Text('无详情'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _row('ID', inspect.id),
        _row('名称', inspect.name),
        _row('镜像', inspect.image),
        _row('状态', inspect.status),
        _row('创建时间', inspect.created),
        _row('重启策略', inspect.restartPolicy),
        _row('网络模式', inspect.networkMode),
        _row('启动命令', inspect.cmd),
        _section('端口映射', inspect.ports),
        _section('挂载', inspect.mounts),
        _section('环境变量', inspect.env),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            const Text('—', style: TextStyle(fontSize: 14))
          else
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: SelectableText(e, style: const TextStyle(fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}
