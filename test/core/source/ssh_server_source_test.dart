// ignore_for_file: require_trailing_commas

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/ssh/ssh_connection.dart';
import 'package:lanxi/core/ssh/ssh_session_pool.dart';
import 'package:lanxi/core/source/ssh_server_source.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:mocktail/mocktail.dart';

class _MockPool extends Mock implements SshSessionPool {}

class _MockSSHClient extends Mock implements SSHClient {}

class _MockSSHSession extends Mock implements SSHSession {}

/// Produces a [Stream<Uint8List>] from a plain string (simulates SSH stdout).
Stream<Uint8List> _streamOf(String text) =>
    Stream.value(Uint8List.fromList(utf8.encode(text)));

void main() {
  late _MockPool mockPool;
  late _MockSSHClient mockClient;
  late SshServerSource source;

  setUpAll(() {
    registerFallbackValue(const SshCredentials(
      host: 'default',
      username: 'default',
    ));
  });

  setUp(() {
    mockPool = _MockPool();
    mockClient = _MockSSHClient();
    source = SshServerSource(
      pool: mockPool,
      credentials: const SshCredentials(
        host: 'test.host',
        port: 22,
        username: 'root',
      ),
    );
  });

  group('getSystemInfo', () {
    test('connects, executes command, and parses output', () async {
      final session = _MockSSHSession();
      when(() => session.stdout).thenAnswer(
        (_) => _streamOf([
          '%Cpu(s):  45.2 us,  10.0 sy,  0.0 ni, 44.8 id,  0.0 wa',
          'Mem:   1986  512  1023    0  450  923',
          'Swap:  2048    0 2048',
          'Filesystem      Size  Used Avail Use% Mounted on',
          '/dev/sda1        50G   30G   20G  60% /',
        ].join('\n')),
      );
      when(() => session.exitCode).thenReturn(0);
when(() => session.done).thenAnswer((_) async {});
      when(() => mockClient.execute(any()))
          .thenAnswer((_) async => session);
      when(() => mockPool.connect(any()))
          .thenAnswer((_) async => mockClient);

      final result = await source.getSystemInfo();

      expect(result.cpuPercent, closeTo(45.2, 0.01));
      expect(result.memTotalMb, 1986);
      expect(result.memUsedMb, 512);
      expect(result.diskTotalMb, 50 * 1024);
      expect(result.diskUsedMb, 30 * 1024);
      expect(result.source, SystemStatsSource.ssh);
      verify(() => mockPool.connect(any())).called(1);
      verify(() => mockClient.execute(any())).called(1);
    });

    test('reuses client on second call (cached)', () async {
      final session = _MockSSHSession();
      when(() => session.stdout).thenAnswer((_) => _streamOf(''));
      when(() => session.exitCode).thenReturn(0);
when(() => session.done).thenAnswer((_) async {});
      when(() => mockClient.execute(any()))
          .thenAnswer((_) async => session);
      when(() => mockPool.connect(any()))
          .thenAnswer((_) async => mockClient);

      await source.getSystemInfo();
      await source.getSystemInfo();

      // connect should only be called once (client is cached)
      verify(() => mockPool.connect(any())).called(1);
      verify(() => mockClient.execute(any())).called(2);
    });

    test('returns defaults for empty output', () async {
      final session = _MockSSHSession();
      when(() => session.stdout).thenAnswer((_) => _streamOf(''));
      when(() => session.exitCode).thenReturn(0);
when(() => session.done).thenAnswer((_) async {});
      when(() => mockClient.execute(any()))
          .thenAnswer((_) async => session);
      when(() => mockPool.connect(any()))
          .thenAnswer((_) async => mockClient);

      final result = await source.getSystemInfo();

      expect(result.cpuPercent, 0.0);
      expect(result.memTotalMb, 0);
      expect(result.memUsedMb, 0);
      expect(result.diskTotalMb, 0);
    });
  });
}
