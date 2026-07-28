// ignore_for_file: require_trailing_commas

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/interactive_session.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/models/dto/container_dto.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_interactive_session.dart';

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

  setUpAll(() {
    registerFallbackValue(CompressFormat.tarGz);
  });

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

  group('watchHostStats', () {
    test('delegates to source stream', () {
      when(() => mockSource.watchHostStats())
          .thenAnswer((_) => Stream.value(_snapshot()));

      final stream = service.watchHostStats();

      expect(stream, isA<Stream<SystemStats>>());
      verify(() => mockSource.watchHostStats()).called(1);
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
      when(() => mockSource.compress(any(), any(),
          format: any(named: 'format'))).thenAnswer(
        (_) async => const CompressResult(
          destPath: '/tmp/out.tar.gz',
          size: 5000,
          durationMs: 2000,
          success: true,
        ),
      );

      final result = await service.compress(
        ['/tmp/a'],
        '/tmp/out.tar.gz',
        format: CompressFormat.zip,
      );

      expect(result.success, true);
      expect(result.destPath, '/tmp/out.tar.gz');
      verify(() => mockSource.compress(
            ['/tmp/a'],
            '/tmp/out.tar.gz',
            format: CompressFormat.zip,
          )).called(1);
    });
  });

  group('readFileBytes & setFilePermission', () {
    test('readFileBytes delegates to source', () async {
      when(() => mockSource.readFileBytes(any()))
          .thenAnswer((_) async => Uint8List.fromList([7]));

      final bytes = await service.readFileBytes('/x.png');

      expect(bytes, [7]);
      verify(() => mockSource.readFileBytes('/x.png')).called(1);
    });

    test('setFilePermission delegates to source', () async {
      when(() => mockSource.setFilePermission(
            any(),
            mode: any(named: 'mode'),
            owner: any(named: 'owner'),
            group: any(named: 'group'),
          )).thenAnswer((_) async {});

      await service.setFilePermission(
        '/x',
        mode: 493,
        owner: 'www',
        group: 'www',
      );

      verify(() => mockSource.setFilePermission(
            '/x',
            mode: 493,
            owner: 'www',
            group: 'www',
          )).called(1);
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

  group('openShell', () {
    test('delegates to source', () async {
      when(() => mockSource.openShell())
          .thenAnswer((_) async => FakeInteractiveSession());

      final session = await service.openShell();

      expect(session, isA<InteractiveSession>());
      verify(() => mockSource.openShell()).called(1);
    });
  });

  group('file operations', () {
    test('readFile delegates to source', () async {
      when(() => mockSource.readFile(any())).thenAnswer((_) async => 'c');

      expect(await service.readFile('/x'), 'c');
      verify(() => mockSource.readFile('/x')).called(1);
    });

    test('writeFile delegates to source', () async {
      when(() => mockSource.writeFile(any(), any())).thenAnswer((_) async {});

      await service.writeFile('/x', 'c');

      verify(() => mockSource.writeFile('/x', 'c')).called(1);
    });

    test('deleteFile delegates to source', () async {
      when(() => mockSource.deleteFile(any(), isDir: any(named: 'isDir')))
          .thenAnswer((_) async {});

      await service.deleteFile('/x', isDir: true);

      verify(() => mockSource.deleteFile('/x', isDir: true)).called(1);
    });

    test('renameFile delegates to source', () async {
      when(() => mockSource.renameFile(any(), any())).thenAnswer((_) async {});

      await service.renameFile('/a', '/b');

      verify(() => mockSource.renameFile('/a', '/b')).called(1);
    });

    test('createFile delegates to source', () async {
      when(() => mockSource.createFile(
            any(),
            isDir: any(named: 'isDir'),
            content: any(named: 'content'),
          )).thenAnswer((_) async {});

      await service.createFile('/x', isDir: false, content: 'c');

      verify(() => mockSource.createFile(
            '/x',
            isDir: false,
            content: 'c',
          )).called(1);
    });
  });

  group('docker operations', () {
    final container = ContainerDomain(
      id: 'abc',
      name: 'web',
      image: 'nginx',
      status: 'Up',
      state: 'running',
    );

    test('listContainers delegates to source', () async {
      when(() => mockSource.listContainers()).thenAnswer((_) async => [container]);

      final items = await service.listContainers();

      expect(items.single.name, 'web');
      verify(() => mockSource.listContainers()).called(1);
    });

    test('startContainer delegates to source', () async {
      when(() => mockSource.startContainer(any())).thenAnswer((_) async {});

      await service.startContainer('web');

      verify(() => mockSource.startContainer('web')).called(1);
    });

    test('stopContainer delegates to source', () async {
      when(() => mockSource.stopContainer(any())).thenAnswer((_) async {});

      await service.stopContainer('web');

      verify(() => mockSource.stopContainer('web')).called(1);
    });

    test('restartContainer delegates to source', () async {
      when(() => mockSource.restartContainer(any())).thenAnswer((_) async {});

      await service.restartContainer('web');

      verify(() => mockSource.restartContainer('web')).called(1);
    });

    test('pauseContainer delegates to source', () async {
      when(() => mockSource.pauseContainer(any())).thenAnswer((_) async {});

      await service.pauseContainer('web');

      verify(() => mockSource.pauseContainer('web')).called(1);
    });

    test('unpauseContainer delegates to source', () async {
      when(() => mockSource.unpauseContainer(any())).thenAnswer((_) async {});

      await service.unpauseContainer('web');

      verify(() => mockSource.unpauseContainer('web')).called(1);
    });

    test('removeContainer delegates to source', () async {
      when(() => mockSource.removeContainer(any(), force: any(named: 'force')))
          .thenAnswer((_) async {});

      await service.removeContainer('web');

      verify(() => mockSource.removeContainer('web', force: true)).called(1);
    });

    test('inspectContainer delegates to source', () async {
      when(() => mockSource.inspectContainer(any()))
          .thenAnswer((_) async => ContainerInspect({}));

      await service.inspectContainer('web');

      verify(() => mockSource.inspectContainer('web')).called(1);
    });

    test('containerLogs delegates to source', () {
      when(() => mockSource.containerLogs(any(),
              tail: any(named: 'tail'), follow: any(named: 'follow')))
          .thenAnswer((_) => Stream.value('line'));

      final stream = service.containerLogs('web');

      expect(stream, isA<Stream<String>>());
      verify(() => mockSource.containerLogs('web')).called(1);
    });
  });
}
