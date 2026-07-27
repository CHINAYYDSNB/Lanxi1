import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/panel/fallback_server_source.dart';
import 'package:lanxi/core/source/panel/one_panel_server_source.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:mocktail/mocktail.dart';

class _MockPanel extends Mock implements OnePanelServerSource {}

class _MockSsh extends Mock implements ServerSource {}

SystemStats _snapshot() => SystemStats(
      cpuPercent: 10,
      memTotalMb: 1024,
      memUsedMb: 512,
      disks: const [],
      diskTotalMb: 50000,
      diskUsedMb: 25000,
      loadAvg: 0.5,
    );

CompressResult _compressResult() => const CompressResult(
      destPath: '/tmp/out.tar.gz',
      size: 1000,
      durationMs: 500,
      success: true,
    );

void main() {
  late _MockPanel mockPanel;
  late _MockSsh mockSsh;
  late FallbackServerSource source;

  setUp(() {
    mockPanel = _MockPanel();
    mockSsh = _MockSsh();
    source = FallbackServerSource(panel: mockPanel, ssh: mockSsh);
  });

  group('getSystemInfo', () {
    test('returns panel result when panel succeeds', () async {
      when(() => mockPanel.getSystemInfo())
          .thenAnswer((_) async => _snapshot());

      final result = await source.getSystemInfo();

      expect(result.cpuPercent, 10);
      verify(() => mockPanel.getSystemInfo()).called(1);
      verifyNever(() => mockSsh.getSystemInfo());
    });

    test('falls back to SSH when panel throws', () async {
      when(() => mockPanel.getSystemInfo()).thenThrow(
        const PanelFallbackException('API error'),
      );
      when(() => mockSsh.getSystemInfo()).thenAnswer((_) async => _snapshot());

      final result = await source.getSystemInfo();

      expect(result.cpuPercent, 10);
      verify(() => mockSsh.getSystemInfo()).called(1);
    });
  });

  group('listDir', () {
    test('returns panel result when panel succeeds', () async {
      when(() => mockPanel.listDir(any())).thenAnswer(
        (_) async => [
          FileItem(
            name: 'a.txt',
            path: '/tmp/a.txt',
            size: 10,
            isDir: false,
            permissions: '644',
            modifiedTime: DateTime.now(),
          ),
        ],
      );

      final items = await source.listDir('/tmp');

      expect(items.length, 1);
      verify(() => mockPanel.listDir('/tmp')).called(1);
      verifyNever(() => mockSsh.listDir(any()));
    });

    test('falls back to SSH on PanelFallbackException', () async {
      when(() => mockPanel.listDir(any())).thenThrow(
        const PanelFallbackException('timeout'),
      );
      when(() => mockSsh.listDir(any())).thenAnswer((_) async => []);

      final items = await source.listDir('/data');

      expect(items, isEmpty);
      verify(() => mockSsh.listDir('/data')).called(1);
    });
  });

  group('compress', () {
    test('returns panel result when panel succeeds', () async {
      when(() => mockPanel.compress(any(), any()))
          .thenAnswer((_) async => _compressResult());

      final result = await source.compress(['/tmp/a'], '/tmp/a.zip');

      expect(result.success, true);
      verify(() => mockPanel.compress(['/tmp/a'], '/tmp/a.zip')).called(1);
    });

    test('falls back to SSH on error', () async {
      when(() => mockPanel.compress(any(), any())).thenThrow(
        const PanelFallbackException('error'),
      );
      when(() => mockSsh.compress(any(), any()))
          .thenAnswer((_) async => _compressResult());

      final result = await source.compress(['/tmp/b'], '/tmp/b.zip');

      expect(result.success, true);
      verify(() => mockSsh.compress(['/tmp/b'], '/tmp/b.zip')).called(1);
    });
  });

  group('setNtp', () {
    test('calls panel first, falls back to SSH', () async {
      when(() => mockPanel.setNtp(any())).thenThrow(
        const PanelFallbackException('not supported'),
      );
      when(() => mockSsh.setNtp(any())).thenAnswer((_) async => {});

      await source.setNtp('pool.ntp.org');

      verify(() => mockPanel.setNtp('pool.ntp.org')).called(1);
      verify(() => mockSsh.setNtp('pool.ntp.org')).called(1);
    });
  });

  group('changeRootPassword', () {
    test('calls panel first, falls back to SSH', () async {
      when(() => mockPanel.changeRootPassword(any())).thenThrow(
        const PanelFallbackException('not supported'),
      );
      when(() => mockSsh.changeRootPassword(any())).thenAnswer((_) async => {});

      await source.changeRootPassword('newPass123');

      verify(() => mockPanel.changeRootPassword('newPass123')).called(1);
      verify(() => mockSsh.changeRootPassword('newPass123')).called(1);
    });
  });
}
