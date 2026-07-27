import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/core/source/server_source_factory.dart';
import 'package:lanxi/services/server_service.dart';

import 'app_state.dart';

/// Connection form for SSH credentials.
///
/// On successful connect, creates a [ServerService] and passes it to [AppState].
class ConnectionScreen extends StatefulWidget {
  final AppState appState;

  const ConnectionScreen({super.key, required this.appState});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  bool _connecting = false;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _keyCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _connecting = true);

    try {
      final profile = ServerProfile(
        host: _hostCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text.trim()) ?? 22,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text.isNotEmpty ? _passCtrl.text : null,
        sshKey: _keyCtrl.text.isNotEmpty ? _keyCtrl.text : null,
        apiKey: _apiKeyCtrl.text.isNotEmpty ? _apiKeyCtrl.text : null,
      );

      final source = ServerSourceFactory.buildSsh(profile);
      final service = ServerService(source);

      // Quick test: try fetching system info to verify connectivity
      try {
        await service.getSystemInfo();
      } catch (e) {
        if (!mounted) return;
        _showError('Connected but failed to reach server: $e');
        setState(() => _connecting = false);
        return;
      }

      widget.appState.connect(service);
      appLogger.i('SSH connection established to ${profile.host}');
    } catch (e) {
      _showError('Connection failed: $e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Server'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.dns, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                'Lanxi',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'SSH Server Management',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Host
              TextFormField(
                controller: _hostCtrl,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  hintText: '192.168.1.100',
                  prefixIcon: Icon(Icons.computer),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Host is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Port
              TextFormField(
                controller: _portCtrl,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '22',
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Username
              TextFormField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'root',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Username is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password (optional)',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              // SSH Key
              TextFormField(
                controller: _keyCtrl,
                decoration: const InputDecoration(
                  labelText: 'SSH Private Key (optional)',
                  hintText: 'Paste PEM key here...',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // API Key
              TextFormField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: '1Panel API Key (optional)',
                  prefixIcon: Icon(Icons.api),
                ),
              ),
              const SizedBox(height: 24),

              // Connect button
              FilledButton.icon(
                onPressed: _connecting ? null : _connect,
                icon: _connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.power_settings_new),
                label: Text(_connecting ? 'Connecting...' : 'Connect'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
