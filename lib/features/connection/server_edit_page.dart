import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/source/server_source_factory.dart';
import 'package:lanxi/core/store/server_store.dart';
import 'package:lanxi/widgets/app_card.dart';

/// Add / edit a server profile.
///
/// Supports an SSH connection or a 1Panel API connection. Secrets (password /
/// private key / API key) are saved through [ServerStore] (secure storage),
/// never in plain [SharedPreferences].
class ServerEditPage extends StatefulWidget {
  final ServerStore store;
  final ServerProfile? existing;

  const ServerEditPage({super.key, required this.store, this.existing});

  @override
  State<ServerEditPage> createState() => _ServerEditPageState();
}

class _ServerEditPageState extends State<ServerEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _apiKeyCtrl;
  late ServerSourceType _type;
  late bool _autoConnect;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? ServerSourceType.ssh;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _hostCtrl = TextEditingController(text: e?.host ?? '');
    _portCtrl = TextEditingController(text: (e?.port ?? _defaultPort(_type)).toString());
    _userCtrl = TextEditingController(text: e?.username ?? '');
    _passCtrl = TextEditingController();
    _keyCtrl = TextEditingController();
    _apiKeyCtrl = TextEditingController();
    _autoConnect = e?.autoConnect ?? false;
  }

  static int _defaultPort(ServerSourceType type) =>
      type == ServerSourceType.panel ? 9999 : 22;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _keyCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(ServerSourceType? type) {
    if (type == null || type == _type) return;
    setState(() {
      _type = type;
      // Reset port to the new type's default only if untouched.
      _portCtrl.text = _defaultPort(type).toString();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = widget.existing?.id ?? ServerProfile.newId();
      final profile = ServerProfile(
        id: id,
        name: _nameCtrl.text.trim(),
        type: _type,
        host: _hostCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text.trim()) ?? _defaultPort(_type),
        username: _userCtrl.text.trim(),
        autoConnect: _autoConnect,
      );

      await widget.store.save(
        profile,
        password: _type == ServerSourceType.ssh && _passCtrl.text.isNotEmpty
            ? _passCtrl.text
            : null,
        sshKey: _type == ServerSourceType.ssh && _keyCtrl.text.isNotEmpty
            ? _keyCtrl.text
            : null,
        apiKey: _type == ServerSourceType.panel && _apiKeyCtrl.text.isNotEmpty
            ? _apiKeyCtrl.text
            : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      appLogger.e('Failed to save server profile', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败：$e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '添加服务器' : '编辑服务器'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Connection type
              AppCard(
                icon: Icons.cable,
                title: '连接类型',
                child: SegmentedButton<ServerSourceType>(
                  segments: const [
                    ButtonSegment(
                      value: ServerSourceType.ssh,
                      label: Text('SSH'),
                      icon: Icon(Icons.terminal),
                    ),
                    ButtonSegment(
                      value: ServerSourceType.panel,
                      label: Text('1Panel'),
                      icon: Icon(Icons.dashboard),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (set) => _onTypeChanged(set.first),
                ),
              ),
              const SizedBox(height: 12),

              // Common fields
              _textField(
                controller: _nameCtrl,
                label: '服务器名称',
                hint: '我的服务器',
                icon: Icons.label,
                validator: (v) => v == null || v.trim().isEmpty ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _hostCtrl,
                label: '主机地址',
                hint: '192.168.1.100',
                icon: Icons.computer,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '请输入主机地址' : null,
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _portCtrl,
                label: '端口',
                hint: _defaultPort(_type).toString(),
                icon: Icons.settings_ethernet,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              if (_type == ServerSourceType.ssh) ...[
                _textField(
                  controller: _userCtrl,
                  label: '用户名',
                  hint: 'root',
                  icon: Icons.person,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入用户名' : null,
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _passCtrl,
                  label: '密码（可选）',
                  icon: Icons.lock,
                  obscure: true,
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _keyCtrl,
                  label: 'SSH 私钥（可选）',
                  hint: '在此粘贴 PEM 私钥...',
                  icon: Icons.vpn_key,
                  maxLines: 3,
                ),
              ] else ...[
                _textField(
                  controller: _apiKeyCtrl,
                  label: '1Panel API 密钥',
                  hint: '粘贴 1Panel 的 API Key',
                  icon: Icons.api,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入 API 密钥' : null,
                ),
              ],

              const SizedBox(height: 12),
              AppCard(
                icon: Icons.power_settings_new,
                title: '启动设置',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('开机自动连接'),
                  subtitle: const Text('应用启动时自动连接此服务器'),
                  value: _autoConnect,
                  onChanged: (v) => setState(() => _autoConnect = v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    bool obscure = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLines: maxLines,
      validator: validator,
    );
  }
}
