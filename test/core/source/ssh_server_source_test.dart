// ignore_for_file: require_trailing_commas

import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/ssh_server_source.dart';
import 'package:lanxi/core/ssh/ssh_connection.dart';

class _FakeSshConnection implements SshConnection {
  String _output = '';
  bool _connected = true;

  void setOutput(String out) => _output = out;

  @override
  Future<void> connect() async {}

  @override
  Future<String> exec(String command) async => _output;

  @override
  Stream<String> execStream(String command) => Stream.value(_output);

  @override
  Future<SshExecResult> execWithStderr(String command) async =>
      SshExecResult(stdout: _output, stderr: '', exitCode: 0);

  @override
  Future<void> disconnect() async => _connected = false;

  @override
  bool get isConnected => _connected;
}

void main() {
  late _FakeSshConnection fakeSsh;
  late SshServerSource source;

  setUp(() {
    fakeSsh = _FakeSshConnection();
    source = SshServerSource(fakeSsh);
  });

  group('getSystemInfo', () {
    test('parses CPU, memory, and disk output', () async {
      fakeSsh.setOutput([
        '%Cpu(s):  45.2 us,  10.0 sy,  0.0 ni, 44.8 id,  0.0 wa',
        'Mem:   1986  512  1023    0  450  923',
        'Swap:  2048    0 2048',
        'Filesystem      Size  Used Avail Use% Mounted on',
        '/dev/sda1        50G   30G   20G  60% /',
      ].join('\n'));

      final result = await source.getSystemInfo();

      expect(
        result.cpuPercent,
        closeTo(45.2, 0.01),
      );
      expect(result.memoryTotal, 1986);
      expect(result.memoryUsed, 512);
      expect(result.diskTotal, 50 * 1024);
      expect(result.diskUsed, 30 * 1024);
      expect(result.timestamp, isA<DateTime>());
    });

    test('returns defaults for empty output', () async {
      fakeSsh.setOutput('');

      final result = await source.getSystemInfo();

      expect(result.cpuPercent, 0.0);
      expect(result.memoryTotal, 0);
      expect(result.memoryUsed, 0);
      expect(result.diskTotal, 0);
      expect(result.diskUsed, 0);
    });
  });

  group('setNtp', () {
    test('executes without throwing', () async {
      fakeSsh.setOutput('');
      await expectLater(source.setNtp('Asia/Shanghai'), completes);
    });
  });

  group('changeRootPassword', () {
    test('executes without throwing', () async {
      fakeSsh.setOutput('');
      await expectLater(
        source.changeRootPassword('Str0ng!Pass'),
        completes,
      );
    });
  });

  group('compress', () {
    test('executes tar command', () async {
      fakeSsh.setOutput('');
      final result = await source.compress(
        ['/var/log/syslog', '/var/log/auth.log'],
        '/tmp/logs.tar.gz',
      );

      expect(result.success, true);
      expect(result.destPath, '/tmp/logs.tar.gz');
    });
  });

  group('listDir', () {
    test('parses ls -la output', () async {
      fakeSsh.setOutput([
        'total 24',
        'drwxr-xr-x 2 root root 4096 Jan 1 12:00 .',
        'drwxr-xr-x 3 root root 4096 Jan 1 12:00 ..',
        '-rw-r--r-- 1 root root  512 Jan 1 12:01 readme.txt',
        'drwx------ 2 root root 4096 Jan 1 12:02 secret',
      ].join('\n'));

      final items = await source.listDir('/tmp');

      expect(items.length, 2);
      expect(items[0].name, 'readme.txt');
      expect(items[0].isDir, false);
      expect(items[0].size, 512);
      expect(items[1].name, 'secret');
      expect(items[1].isDir, true);
    });

    test('handles empty directory', () async {
      fakeSsh.setOutput('total 0');
      final items = await source.listDir('/empty');
      expect(items, isEmpty);
    });
  });
}
