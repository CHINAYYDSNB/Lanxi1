import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/panel/one_panel_adapter.dart';
import 'package:lanxi/core/source/panel/one_panel_server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements OnePanelAdapter {}

SystemStats _fakeSnapshot() => SystemStats(
      cpuPercent: 10.0,
      memTotalMb: 1024,
      memUsedMb: 512,
      disks: const [],
      diskTotalMb: 50000,
      diskUsedMb: 25000,
      loadAvg: 0.5,
    );

CompressResult _fakeCompressResult() => const CompressResult(
      destPath: '/tmp/a.zip',
      size: 1000,
      durationMs: 500,
      success: true,
    );

void main() {
  late _MockAdapter mockAdapter;
  late OnePanelServerSource source;

  setUp(() {
    mockAdapter = _MockAdapter();
    source = OnePanelServerSource(mockAdapter);
  });

  test('getSystemInfo delegates to adapter', () async {
    when(() => mockAdapter.getHostInfo())
        .thenAnswer((_) async => _fakeSnapshot());

    final result = await source.getSystemInfo();

    expect(result.cpuPercent, 10.0);
    verify(() => mockAdapter.getHostInfo()).called(1);
  });

  test('listDir delegates to adapter', () async {
    when(() => mockAdapter.listDir(any())).thenAnswer((_) async => []);

    final items = await source.listDir('/tmp');

    expect(items, isEmpty);
    verify(() => mockAdapter.listDir('/tmp')).called(1);
  });

  test('compress delegates to adapter', () async {
    when(() => mockAdapter.compress(any(), any()))
        .thenAnswer((_) async => _fakeCompressResult());

    final result = await source.compress(['/tmp/a'], '/tmp/a.zip');

    expect(result.success, true);
    verify(() => mockAdapter.compress(['/tmp/a'], '/tmp/a.zip')).called(1);
  });

  test('setNtp throws PanelFallbackException', () async {
    expect(
      () => source.setNtp('pool.ntp.org'),
      throwsA(isA<PanelFallbackException>()),
    );
  });

  test('changeRootPassword throws PanelFallbackException', () async {
    expect(
      () => source.changeRootPassword('newPass123'),
      throwsA(isA<PanelFallbackException>()),
    );
  });

  test('openShell throws PanelFallbackException (no shell on panel)', () {
    expect(
      () => source.openShell(),
      throwsA(isA<PanelFallbackException>()),
    );
  });
}
