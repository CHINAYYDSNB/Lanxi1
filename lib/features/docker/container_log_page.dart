// ignore_for_file: require_trailing_commas
// CI rule: strings containing $var MUST stay double-quoted. Mirrors
// ssh_server_source.dart. Keep this file's interpolated strings double-quoted.
// ignore_for_file: prefer_single_quotes

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/services/server_service.dart';

/// Live (or one-shot) container log viewer.
class ContainerLogPage extends StatefulWidget {
  final ServerService service;
  final String containerName;

  const ContainerLogPage({
    super.key,
    required this.service,
    required this.containerName,
  });

  @override
  State<ContainerLogPage> createState() => _ContainerLogPageState();
}

class _ContainerLogPageState extends State<ContainerLogPage> {
  final List<String> _lines = [];
  StreamSubscription<String>? _sub;
  bool _follow = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    setState(() {
      _lines.clear();
      _loading = true;
      _error = null;
    });
    try {
      final stream =
          widget.service.containerLogs(widget.containerName, follow: _follow);
      _sub = stream.listen(
        (chunk) {
          if (!mounted) return;
          setState(() {
            _lines.addAll(chunk.split('\n'));
            _loading = false;
          });
        },
        onError: (e) {
          appLogger.e('container logs error', e);
          if (!mounted) return;
          setState(() {
            _error = "日志读取失败：$e";
            _loading = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _loading = false);
        },
      );
    } catch (e) {
      appLogger.e('container logs failed to start', e);
      if (!mounted) return;
      setState(() {
        _error = "日志读取失败：$e";
        _loading = false;
      });
    }
  }

  void _toggleFollow() {
    setState(() => _follow = !_follow);
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("日志 · ${widget.containerName}"),
        actions: [
          IconButton(
            icon: Icon(_follow ? Icons.pause : Icons.play_arrow),
            tooltip: _follow ? '暂停跟随' : '跟随最新',
            onPressed: _toggleFollow,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
            ],
          ),
        ),
      );
    }
    if (_loading && _lines.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lines.isEmpty) {
      return const Center(child: Text('暂无日志'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _lines.length,
      itemBuilder: (ctx, i) => SelectableText(
        _lines[i],
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
