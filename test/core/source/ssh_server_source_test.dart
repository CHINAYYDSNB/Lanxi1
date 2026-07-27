// ignore_for_file: require_trailing_commas

import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/ssh_server_source.dart';
import 'package:lanxi/core/ssh/ssh_connection.dart';
import 'package:lanxi/models/domain/system_stats.dart';

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

      expect(result.cpuPercent, closeTo(45.2, 0.01));
      expect(result.memTotalMb, 1986);
      expect(result.memUsedMb, 512);
      expect(result.diskTotalMb, 50 * 1024);
      expect(result.diskUsedMb, 30 * 1024);
      expect(result.timestamp, isA<DateTime>());
      expect(result.source, SystemStatsSource.ssh);
    });

    test('returns defaults for empty output', () async {
      fakeSsh.setOutput('');
      final result = await source.getSystemInfo();
      expect(result.cpuPercent, 0.0);
      expect(result.memTotalMb, 0);
      expect(result.memUsedMb, 0);
    });
  });
}
