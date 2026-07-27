/// Singleton pool that manages persistent SSH connections.
///
/// Principles:
///   - Connections are keyed by [SshCredentials.poolKey] (host:port:username).
///   - A paused connection keeps TCP alive but cancels its stream subscriptions.
///   - Idle connections (>5 min no activity) are released by [releaseIdle].
library;

import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';

import '../logger.dart';
import 'ssh_connection.dart';

/// State of a pooled SSH connection.
enum PoolEntryState { connected, paused, idle }

/// Internal pool entry wrapping a dartssh2 client.
class _PoolEntry {
  final String poolKey;
  final SSHClient client;
  PoolEntryState state;
  DateTime lastActivity;
  StreamSubscription? _subscription;
  final StreamController<String> _broadcastController =
      StreamController<String>.broadcast();

  _PoolEntry({
    required this.poolKey,
    required this.client,
    DateTime? lastActivity,
  })  : state = PoolEntryState.connected,
        lastActivity = lastActivity ?? DateTime.now();

  void recordActivity() => lastActivity = DateTime.now();

  /// Internal: pipes shell output into the broadcast stream.
  void attachStream(Stream<String> source) {
    _subscription?.cancel();
    _subscription = source.listen(
      _broadcastController.add,
      onError: _broadcastController.addError,
      onDone: () {/* stream ended — caller reconnects */},
    );
    state = PoolEntryState.connected;
    recordActivity();
  }

  Stream<String> get broadcastStream => _broadcastController.stream;

  Future<void> close() async {
    await _subscription?.cancel();
    await _broadcastController.close();
    client.close();
  }
}

/// Singleton managing reusable SSH connections.
class SshSessionPool {
  SshSessionPool._();
  static final SshSessionPool _instance = SshSessionPool._();
  factory SshSessionPool() => _instance;

  final Map<String, _PoolEntry> _entries = {};
  Timer? _idleTimer;

  static const Duration _idleTimeout = Duration(minutes: 5);

  /// Connect (or reuse) an SSH connection identified by [credentials].
  ///
  /// If a connection with the same [SshCredentials.poolKey] already exists
  /// and is still connected, returns it without creating a new TCP socket.
  Future<SSHClient> connect(SshCredentials credentials) async {
    final key = credentials.poolKey;
    final existing = _entries[key];
    if (existing != null && existing.state != PoolEntryState.idle) {
      existing.recordActivity();
      appLogger.i('SshSessionPool: reusing connection $key');
      return existing.client;
    }

    appLogger.i('SshSessionPool: opening new connection $key');
    final socket = await SSHSocket.connect(
      credentials.host,
      credentials.port,
    );
    final client = SSHClient(
      socket,
      username: credentials.username,
      onPasswordRequest: () => credentials.password ?? '',
    );

    final entry = _PoolEntry(poolKey: key, client: client);
    _entries[key] = entry;
    _ensureIdleTimer();
    return client;
  }

  /// Execute a command repeatedly, streaming results.
  ///
  /// The connection is auto-created via [connect] and kept alive.
  /// The stream stays open until [pause] is called or the connection drops.
  Stream<String> watch(String sshKey, String cmd) async* {
    final entry = _entries[sshKey];
    if (entry == null) {
      appLogger.w('SshSessionPool: no connection for $sshKey, cannot watch');
      return;
    }

    // Subscribe to the broadcast if not already streaming
    if (entry.state == PoolEntryState.connected &&
        entry._subscription == null) {
      final stream = _executeRepeatedly(entry.client, cmd);
      entry.attachStream(stream);
    }

    yield* entry.broadcastStream;
  }

  /// Pause all watch streams for [sshKey] without closing TCP.
  void pause(String sshKey) {
    final entry = _entries[sshKey];
    if (entry == null) return;
    entry._subscription?.cancel();
    entry._subscription = null;
    entry.state = PoolEntryState.paused;
    appLogger.i('SshSessionPool: paused $sshKey');
  }

  /// Resume watch streams for [sshKey].
  void resume(String sshKey, String cmd) {
    final entry = _entries[sshKey];
    if (entry == null) return;
    if (entry.state == PoolEntryState.paused ||
        entry._subscription == null) {
      final stream = _executeRepeatedly(entry.client, cmd);
      entry.attachStream(stream);
    }
    entry.state = PoolEntryState.connected;
    appLogger.i('SshSessionPool: resumed $sshKey');
  }

  /// Release connections idle for more than 5 minutes.
  void releaseIdle() {
    final now = DateTime.now();
    final toRemove = <String>[];
    for (final entry in _entries.values) {
      if (now.difference(entry.lastActivity) > _idleTimeout) {
        entry.state = PoolEntryState.idle;
        entry.client.close();
        toRemove.add(entry.poolKey);
      }
    }
    for (final key in toRemove) {
      _entries.remove(key);
      appLogger.i('SshSessionPool: released idle connection $key');
    }
    if (_entries.isEmpty) _cancelIdleTimer();
  }

  /// Release all connections (app shutdown).
  Future<void> releaseAll() async {
    for (final entry in _entries.values) {
      await entry.close();
    }
    _entries.clear();
    _cancelIdleTimer();
    appLogger.i('SshSessionPool: all connections released');
  }

  // ---- internal helpers ----

  Stream<String> _executeRepeatedly(SSHClient client, String cmd) async* {
    while (true) {
      try {
        final session = await client.execute(cmd);
        await for (final chunk in session.stdout) {
          final decoded = utf8.decode(chunk.toList());
          yield decoded;
        }
      } catch (e) {
        appLogger.e('SshSessionPool: watch error', e);
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  void _ensureIdleTimer() {
    _idleTimer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => releaseIdle(),
    );
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }
}
