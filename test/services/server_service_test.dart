// ignore_for_file: require_trailing_commas

import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSource extends Mock implements ServerSource {}

SystemStats _snapshot() => SystemStats(
      cpuPercent: 75.0,
      memTotalMb: 8192,
      memUsedMb: 4096,
      disks: [],
      diskTotalMb: 102400,
      diskUsedMb: 51200,
      loadAvg: 2.5,
    );

void main() {
  late _MockSource mockSource;
  late ServerService service;

  setUp(() {
    mockSource = _MockSource();
    service = ServerService(mockSource);
  });

  group('getSystemInfo', () {
    test('delegates to source', () async {
      when(() => mockSource.getSystemInfo()).thenAnswer(
        (_) async => _snapshot(),
      );

      final result = await service.getSystemInfo();

      expect(result.cpuPercent, 75.0);
      verify(() => mockSource.getSystemInfo()).called(1);
    });
  });

  group('listDir', () {
    test('delegates to source', () async {
      when(() => mockSource.listDir(any())).thenAnswer((_) async => [
            FileItem(
              name: 'f1',
              path: '/home/f1',
              size: 100,
              isDir: false,
              permissions: '644',
              modifiedTime: DateTime.now(),
            ),
          ]);

      final items = await service.listDir('/home');

      expect(items.length, 1);
      expect(items[0].name, 'f1');
      verify(() => mockSource.listDir('/home')).called(1);
    });
  });

  group('compress', () {
    test('delegates to source', () async {
      when(() => mockSource.compress(any(), any())).thenAnswer(
        (_) async => const CompressResult(
          destPath: '/tmp/out.tar.gz',
          size: 5000,
          durationMs: 2000,
          success: true,
        ),
      );

      final result = await service.compress(['/tmp/a'], '/tmp/out.tar.gz');

      expect(result.success, true);
      expect(result.destPath, '/tmp/out.tar.gz');
      verify(() => mockSource.compress(['/tmp/a'], '/tmp/out.tar.gz')).called(1);
    });
  });

  group('setNtp', () {
    test('delegates to source', () async {
      when(() => mockSource.setNtp(any())).thenAnswer((_) async => {});

      await service.setNtp('pool.ntp.org');

      verify(() => mockSource.setNtp('pool.ntp.org')).called(1);
    });
  });

  group('changeRootPassword', () {
    test('delegates to source', () async {
      when(() => mockSource.changeRootPassword(any()))
          .thenAnswer((_) async => {});

      await service.changeRootPassword('newPass!');

      verify(() => mockSource.changeRootPassword('newPass!')).called(1);
    });
  });

  group('streamCommand', () {
    test('delegates to source', () {
      when(() => mockSource.streamCommand(any()))
          .thenAnswer((_) => Stream.value('line'));

      final stream = service.streamCommand('echo hi');

      expect(stream, isA<Stream<String>>());
      verify(() => mockSource.streamCommand('echo hi')).called(1);
    });
  });

  group('detectPanel', () {
    test('delegates to source', () async {
      when(() => mockSource.detectPanel())
          .thenAnswer((_) async => PanelStatus.none);

      expect(await service.detectPanel(), PanelStatus.none);
      verify(() => mockSource.detectPanel()).called(1);
    });
  });
}
