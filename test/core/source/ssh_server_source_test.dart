// ignore_for_file: require_trailing_commas

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/interactive_session.dart';
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

/// Builds a mock session whose stdout yields [text].
Future<SSHSession> _sessionReturning(String text) async {
  final session = _MockSSHSession();
  when(() => session.stdout).thenAnswer((_) => _streamOf(text));
  when(() => session.exitCode).thenReturn(0);
  when(() => session.done).thenAnswer((_) async {});
  return session;
}

void main() {
  late _MockPool mockPool;
  late _MockSSHClient mockClient;
  late SshServerSource source;

  setUpAll(() {
    registerFallbackValue(const SshCredentials(
      host: 'default',
      username: 'default',
    ));
    registerFallbackValue(const SSHPtyConfig());
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
    when(() => mockPool.connect(any()))
        .thenAnswer((_) async => mockClient);
  });

  group('getSystemInfo', () {
    test('parses cpu/mem/load and df -Pk disks', () async {
      when(() => mockClient.execute(any())).thenAnswer((inv) {
        final cmd = inv.positionalArguments[0] as String;
        final isDisk = cmd.contains('df -Pk');
        final text = isDisk
            ? [
                'Filesystem     1024-blocks      Used Available Capacity Mounted on',
                '/dev/sda1      51200000  25600000  25600000      50% /',
                'tmpfs            2048000       100   2047900       1% /dev/shm',
                'overlay         51200000  25600000  25600000      50% /',
              ].join('\n')
            : [
                '%Cpu(s):  45.2 us,  10.0 sy,  0.0 ni, 44.8 id',
                'Mem:   1986  512  1023    0  450  923',
                'load average: 1.23',
              ].join('\n');
        return _sessionReturning(text);
      });

      final result = await source.getSystemInfo();

      expect(result.cpuPercent, closeTo(45.2, 0.01));
      expect(result.memTotalMb, 1986);
      expect(result.memUsedMb, 512);
      expect(result.loadAvg, closeTo(1.23, 0.001));
      // tmpfs excluded; /dev/sda1 and overlay kept
      expect(result.disks.length, 2);
      expect(result.disks[0].totalMb, 50000);
      expect(result.disks[0].usedMb, 25000);
      expect(result.diskTotalMb, 100000);
      expect(result.diskUsedMb, 50000);
      expect(result.source, SystemStatsSource.ssh);
      verify(() => mockPool.connect(any())).called(1);
      // info command + disk command
      verify(() => mockClient.execute(any())).called(2);
    });

    test('reuses client on second call (cached)', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(''));

      await source.getSystemInfo();
      await source.getSystemInfo();

      verify(() => mockPool.connect(any())).called(1);
      // two commands (info + disk) per getSystemInfo, called twice
      verify(() => mockClient.execute(any())).called(4);
    });

    test('returns defaults for empty output', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(''));

      final result = await source.getSystemInfo();

      expect(result.cpuPercent, 0.0);
      expect(result.memTotalMb, 0);
      expect(result.memUsedMb, 0);
      expect(result.diskTotalMb, 0);
      expect(result.disks, isEmpty);
    });
  });

  group('openShell', () {
    test('opens a PTY shell through the client', () async {
      when(() => mockClient.shell(pty: any(named: 'pty')))
          .thenAnswer((_) async => _MockSSHSession());

      final session = await source.openShell();

      expect(session, isA<InteractiveSession>());
      verify(() => mockClient.shell(pty: any(named: 'pty'))).called(1);
    });
  });
}
