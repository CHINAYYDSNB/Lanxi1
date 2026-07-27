import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/interactive_session.dart';
import 'package:lanxi/services/server_service.dart';

/// Interactive PTY terminal (JuiceSSH-style).
///
/// Opens a real shell through [ServerService.openShell] and streams its output.
/// When [command] is provided (e.g. the 1Panel installer) it is auto-executed
/// on connect, but the user can keep typing afterwards.
class TerminalPage extends StatelessWidget {
  final ServerService service;
  final String? command;
  final String title;

  const TerminalPage({
    super.key,
    required this.service,
    this.command,
    this.title = '终端',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '断开连接',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _TerminalView(service: service, command: command),
    );
  }
}

class _TerminalView extends StatefulWidget {
  final ServerService service;
  final String? command;

  const _TerminalView({required this.service, required this.command});

  @override
  State<_TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<_TerminalView> {
  InteractiveSession? _session;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();

  final List<String> _lines = [];
  bool _connecting = true;
  bool _unsupported = false;
  String? _error;

  int _cols = 80;
  int _rows = 24;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final session = await widget.service.openShell();
      if (!mounted) return;
      _session = session;
      session.output.listen(
        _onOutput,
        onError: (e) {
          appLogger.e('Terminal output error', e);
          if (!mounted) return;
          setState(() {
            _error = '连接中断：$e';
            _connecting = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _connecting = false);
        },
      );
      if (widget.command != null && widget.command!.isNotEmpty) {
        session.write('${widget.command!}\n');
      }
      setState(() => _connecting = false);
    } on PlatformNotSupportedException catch (e) {
      if (!mounted) return;
      setState(() {
        _unsupported = true;
        _connecting = false;
        _error = e.message;
      });
    } catch (e) {
      appLogger.e('Failed to open shell', e);
      if (!mounted) return;
      setState(() {
        _error = '无法打开终端：$e';
        _connecting = false;
      });
    }
  }

  void _onOutput(String chunk) {
    if (!mounted) return;
    setState(() => _lines.add(chunk));
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _send() {
    final text = _inputCtrl.text;
    if (text.isEmpty) return;
    _session?.write('$text\n');
    _inputCtrl.clear();
  }

  void _scheduleResize(BoxConstraints c) {
    final cols = (c.maxWidth / 8).clamp(20, 400).toInt();
    final rows = (c.maxHeight / 16).clamp(10, 200).toInt();
    if (cols == _cols && rows == _rows) return;
    _cols = cols;
    _rows = rows;
    if (_session == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _session?.resize(width: _cols, height: _rows);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _inputCtrl.dispose();
    _session?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unsupported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error ?? '网页版不支持交互式终端，请使用 Android / 桌面客户端。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    if (_connecting) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final output = _lines.join();

    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            color: Colors.red.shade900,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, c) {
              _scheduleResize(c);
              return Container(
                color: Colors.black,
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                height: double.infinity,
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: SelectableText(
                    output,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Colors.green.shade300,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _InputBar(
          controller: _inputCtrl,
          onSend: _send,
          enabled: _session != null,
        ),
      ],
    );
  }
}

/// Single-line command entry at the bottom of the terminal.
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  const _InputBar({
    required this.controller,
    required this.onSend,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '输入命令，回车发送',
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            tooltip: '发送',
            onPressed: enabled ? onSend : null,
          ),
        ],
      ),
    );
  }
}
