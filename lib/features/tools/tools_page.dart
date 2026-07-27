import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/features/terminal/terminal_page.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:lanxi/widgets/app_card.dart';

/// Fixed 1Panel installer command (double-quoted; runs via SSH only).
// CI constitution: SSH command strings MUST use double quotes. The `$(...)`
// is shell syntax, not Dart interpolation, so double quotes are required.
// ignore: prefer_single_quotes
const String _k1PanelInstallCommand = "bash -c \"\$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)\"";

/// System tools: NTP sync and root password change.
///
/// Both actions call [ServerService] (no [dartssh2]/[dio] here). On a 1Panel
/// connection the API layer throws [PanelFallbackException] and the SSH
/// fallback runs automatically; if even SSH cannot do it, the error is shown.
class ToolsPage extends StatelessWidget {
  final ServerService service;

  const ToolsPage({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InstallPanelCard(service: service),
        const SizedBox(height: 12),
        _NtpCard(service: service),
        const SizedBox(height: 12),
        _PasswordCard(service: service),
      ],
    );
  }
}

/// Detects an existing control panel and offers to install 1Panel over SSH
/// when none is found.
class _InstallPanelCard extends StatefulWidget {
  final ServerService service;

  const _InstallPanelCard({required this.service});

  @override
  State<_InstallPanelCard> createState() => _InstallPanelCardState();
}

class _InstallPanelCardState extends State<_InstallPanelCard> {
  bool _checking = true;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<void> _detect() async {
    try {
      final status = await widget.service.detectPanel();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _statusText = switch (status) {
          PanelStatus.onePanel => '已检测到 1Panel',
          PanelStatus.baota => '已检测到 宝塔（Baota）',
          PanelStatus.none => null,
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _statusText = '检测失败：$e';
      });
    }
  }

  void _install() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TerminalPage(
          service: widget.service,
          command: _k1PanelInstallCommand,
          title: '安装 1Panel',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      icon: Icons.cloud_download_outlined,
      title: '1Panel 面板',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_checking)
            const Text('正在检测服务器面板...')
          else if (_statusText != null)
            Text(_statusText!)
          else ...[
            const Text('未检测到 1Panel 或宝塔，可在 SSH 连接上安装 1Panel。'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _install,
                icon: const Icon(Icons.download),
                label: const Text('安装 1Panel'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NtpCard extends StatefulWidget {
  final ServerService service;

  const _NtpCard({required this.service});

  @override
  State<_NtpCard> createState() => _NtpCardState();
}

class _NtpCardState extends State<_NtpCard> {
  final _ctrl = TextEditingController(text: 'pool.ntp.org');
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final server = _ctrl.text.trim();
    if (server.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.service.setNtp(server);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NTP 已设置为 $server')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置失败：$e'), backgroundColor: Colors.red.shade700),
      );
      appLogger.e('setNtp failed', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      icon: Icons.schedule,
      title: 'NTP 时间同步',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设置 NTP 服务器并开启时间同步。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    labelText: 'NTP 服务器',
                    prefixIcon: Icon(Icons.public),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _apply,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: const Text('应用'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordCard extends StatefulWidget {
  final ServerService service;

  const _PasswordCard({required this.service});

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final pw = _ctrl.text;
    if (pw.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.service.changeRootPassword(pw);
      if (!mounted) return;
      _ctrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('root 密码已修改')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('修改失败：$e'), backgroundColor: Colors.red.shade700),
      );
      appLogger.e('changeRootPassword failed', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      icon: Icons.lock_reset,
      title: '修改 root 密码',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '通过 SSH 修改服务器 root 账户密码。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ctrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '新密码',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _apply,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('修改'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
