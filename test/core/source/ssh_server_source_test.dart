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

  group('watchHostStats', () {
    test('streams parsed stats from combined monitor command', () async {
      const combined = '''
%Cpu(s):  45.2 us,  10.0 sy,  0.0 ni, 44.8 id
Mem:   1986  512  1023    0  450  923
load average: 1.23
__LANXI_DISK__
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/sda1      51200000  25600000  25600000      50% /
tmpfs            2048000       100   2047900       1% /dev/shm
overlay         51200000  25600000  25600000      50% /
''';
      when(() => mockPool.watch(any(), any()))
          .thenAnswer((_) => Stream.value(combined));

      final stats = await source.watchHostStats().first;

      expect(stats.cpuPercent, closeTo(45.2, 0.01));
      expect(stats.memTotalMb, 1986);
      expect(stats.memUsedMb, 512);
      expect(stats.loadAvg, closeTo(1.23, 0.001));
      // tmpfs excluded; /dev/sda1 and overlay kept
      expect(stats.disks.length, 2);
      expect(stats.source, SystemStatsSource.ssh);
      final captured =
          verify(() => mockPool.watch(captureAny(), captureAny())).captured;
      final cmd = captured[1] as String;
      expect(cmd, contains('__LANXI_DISK__'));
      expect(cmd, contains('sleep 2'));
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

  group('file operations', () {
    test('readFile returns remote stdout', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning('file content'));

      final content = await source.readFile('/etc/hosts');

      expect(content, 'file content');
      verify(() => mockClient.execute(any())).called(1);
    });

    test('writeFile runs without throwing', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(''));

      await source.writeFile('/tmp/a', 'hello');

      verify(() => mockClient.execute(any())).called(1);
    });

    test('deleteFile runs rm without throwing', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(''));

      await source.deleteFile('/tmp/a', isDir: false);

      verify(() => mockClient.execute(any())).called(1);
    });

    test('renameFile runs mv without throwing', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(''));

      await source.renameFile('/a', '/b');

      verify(() => mockClient.execute(any())).called(1);
    });

    test('createFile runs mkdir for a directory', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(''));

      await source.createFile('/tmp/dir', isDir: true);

      verify(() => mockClient.execute(any())).called(1);
    });
  });

  group('docker operations', () {
    test('listContainers parses docker ps JSONL', () async {
      const output = '''
{"ID":"abc","Names":"web","Image":"nginx","Status":"Up 2 hours","State":"running","CreatedAt":"2026-07-27"}
{"ID":"def","Names":"db","Image":"postgres","Status":"Exited (0) 1 hour ago","State":"exited","CreatedAt":"2026-07-26"}
''';
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(output));

      final containers = await source.listContainers();

      expect(containers.length, 2);
      expect(containers[0].name, 'web');
      expect(containers[0].isRunning, true);
      expect(containers[1].name, 'db');
      expect(containers[1].isStopped, true);
      verify(() => mockClient.execute(any())).called(1);
    });

    test('startContainer runs docker start', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(''));

      await source.startContainer('web');

      final cmd = verify(() => mockClient.execute(captureAny())).captured.single
          as String;
      expect(cmd, "docker start 'web'");
    });

    test('stopContainer runs docker stop', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(''));

      await source.stopContainer('web');

      final cmd = verify(() => mockClient.execute(captureAny())).captured.single
          as String;
      expect(cmd, "docker stop 'web'");
    });

    test('removeContainer runs docker rm -f', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(''));

      await source.removeContainer('web');

      final cmd = verify(() => mockClient.execute(captureAny())).captured.single
          as String;
      expect(cmd, "docker rm -f 'web'");
    });

    test('inspectContainer parses docker inspect array', () async {
      const output = '[{"Id":"abc","Name":"/web","Config":{"Image":"nginx"}}]';
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning(output));

      final inspect = await source.inspectContainer('web');

      expect(inspect.id, 'abc');
      expect(inspect.name, 'web');
      expect(inspect.image, 'nginx');
    });

    test('containerLogs streams via execStream', () async {
      when(() => mockClient.execute(any()))
          .thenAnswer((_) => _sessionReturning('log line 1\nlog line 2\n'));

      final lines = await source.containerLogs('web', tail: 50).toList();

      expect(lines.join(''), contains('log line 1'));
      verify(() => mockClient.execute(any())).called(1);
    });
  });
}
