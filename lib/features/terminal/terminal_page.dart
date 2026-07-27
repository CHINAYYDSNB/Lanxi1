import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/services/server_service.dart';

/// Live terminal view that streams a command's stdout.
///
/// Used for the 1Panel installer: [service.streamCommand] yields chunks as
/// they arrive and this page appends them to a scrolling, monospace log.
class TerminalPage extends StatelessWidget {
  final ServerService service;
  final String command;
  final String title;

  const TerminalPage({
    super.key,
    required this.service,
    required this.command,
    this.title = '终端',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: _TerminalView(service: service, command: command),
    );
  }
}

class _TerminalView extends StatefulWidget {
  final ServerService service;
  final String command;

  const _TerminalView({required this.service, required this.command});

  @override
  State<_TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<_TerminalView> {
  final List<String> _lines = [];
  final ScrollController _scroll = ScrollController();
  bool _done = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final stream = widget.service.streamCommand(widget.command);
    stream.listen(
      (chunk) {
        if (!mounted) return;
        setState(() => _lines.add(chunk));
        _scrollToEnd();
      },
      onError: (e) {
        appLogger.e('Terminal stream error', e);
        if (!mounted) return;
        setState(() {
          _error = true;
          _done = true;
          _lines.add('\n错误：$e');
        });
        _scrollToEnd();
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _done = true);
        _scrollToEnd();
      },
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (_done)
          Container(
            width: double.infinity,
            color: _error
                ? Colors.red.shade900
                : Colors.green.shade900,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              _error ? '执行失败' : '执行完成',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(12),
            child: ListView.builder(
              controller: _scroll,
              itemCount: _lines.length,
              itemBuilder: (_, i) => Text(
                _lines[i],
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Colors.green.shade300,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
