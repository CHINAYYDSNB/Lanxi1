// ignore_for_file: require_trailing_commas

import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/interactive_session.dart';
import 'package:lanxi/core/source/panel/fallback_server_source.dart';
import 'package:lanxi/core/source/panel/one_panel_server_source.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/models/dto/container_dto.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_interactive_session.dart';

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

  group('watchHostStats', () {
    test('delegates to panel stream when panel succeeds', () async {
      when(() => mockPanel.watchHostStats())
          .thenAnswer((_) => Stream.value(_snapshot()));

      final result = await source.watchHostStats().first;

      expect(result.cpuPercent, 10);
      verify(() => mockPanel.watchHostStats()).called(1);
      verifyNever(() => mockSsh.watchHostStats());
    });

    test('falls back to SSH stream when panel throws', () async {
      when(() => mockPanel.watchHostStats())
          .thenThrow(const PanelFallbackException('API error'));
      when(() => mockSsh.watchHostStats())
          .thenAnswer((_) => Stream.value(_snapshot()));

      final result = await source.watchHostStats().first;

      expect(result.cpuPercent, 10);
      verify(() => mockSsh.watchHostStats()).called(1);
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

  group('openShell', () {
    test('falls back to SSH when panel throws', () async {
      when(() => mockPanel.openShell())
          .thenThrow(const PanelFallbackException('no shell'));
      when(() => mockSsh.openShell())
          .thenAnswer((_) async => FakeInteractiveSession());

      final session = await source.openShell();

      expect(session, isA<InteractiveSession>());
      verify(() => mockSsh.openShell()).called(1);
    });
  });

  group('file operations', () {
    test('readFile delegates to panel', () async {
      when(() => mockPanel.readFile(any())).thenAnswer((_) async => 'c');

      expect(await source.readFile('/x'), 'c');

      verify(() => mockPanel.readFile('/x')).called(1);
      verifyNever(() => mockSsh.readFile(any()));
    });

    test('readFile falls back to SSH', () async {
      when(() => mockPanel.readFile(any()))
          .thenThrow(const PanelFallbackException('no'));
      when(() => mockSsh.readFile(any())).thenAnswer((_) async => 's');

      expect(await source.readFile('/x'), 's');

      verify(() => mockSsh.readFile('/x')).called(1);
    });

    test('writeFile delegates to panel', () async {
      when(() => mockPanel.writeFile(any(), any())).thenAnswer((_) async {});

      await source.writeFile('/x', 'c');

      verify(() => mockPanel.writeFile('/x', 'c')).called(1);
      verifyNever(() => mockSsh.writeFile(any(), any()));
    });

    test('writeFile falls back to SSH', () async {
      when(() => mockPanel.writeFile(any(), any()))
          .thenThrow(const PanelFallbackException('no'));
      when(() => mockSsh.writeFile(any(), any())).thenAnswer((_) async {});

      await source.writeFile('/x', 'c');

      verify(() => mockSsh.writeFile('/x', 'c')).called(1);
    });

    test('deleteFile delegates to panel', () async {
      when(() => mockPanel.deleteFile(any(), isDir: any(named: 'isDir')))
          .thenAnswer((_) async {});

      await source.deleteFile('/x', isDir: true);

      verify(() => mockPanel.deleteFile('/x', isDir: true)).called(1);
      verifyNever(
        () => mockSsh.deleteFile(any(), isDir: any(named: 'isDir')),
      );
    });

    test('deleteFile falls back to SSH', () async {
      when(() => mockPanel.deleteFile(any(), isDir: any(named: 'isDir')))
          .thenThrow(const PanelFallbackException('no'));
      when(() => mockSsh.deleteFile(any(), isDir: any(named: 'isDir')))
          .thenAnswer((_) async {});

      await source.deleteFile('/x', isDir: false);

      verify(() => mockSsh.deleteFile('/x', isDir: false)).called(1);
    });

    test('renameFile delegates to panel', () async {
      when(() => mockPanel.renameFile(any(), any())).thenAnswer((_) async {});

      await source.renameFile('/a', '/b');

      verify(() => mockPanel.renameFile('/a', '/b')).called(1);
      verifyNever(() => mockSsh.renameFile(any(), any()));
    });

    test('renameFile falls back to SSH', () async {
      when(() => mockPanel.renameFile(any(), any()))
          .thenThrow(const PanelFallbackException('no'));
      when(() => mockSsh.renameFile(any(), any())).thenAnswer((_) async {});

      await source.renameFile('/a', '/b');

      verify(() => mockSsh.renameFile('/a', '/b')).called(1);
    });

    test('createFile delegates to panel', () async {
      when(() => mockPanel.createFile(
            any(),
            isDir: any(named: 'isDir'),
            content: any(named: 'content'),
          )).thenAnswer((_) async {});

      await source.createFile('/x', isDir: true);

      verify(() => mockPanel.createFile(
            '/x',
            isDir: true,
            content: any(named: 'content'),
          )).called(1);
      verifyNever(() => mockSsh.createFile(
            any(),
            isDir: any(named: 'isDir'),
            content: any(named: 'content'),
          ));
    });

    test('createFile falls back to SSH', () async {
      when(() => mockPanel.createFile(
            any(),
            isDir: any(named: 'isDir'),
            content: any(named: 'content'),
          )).thenThrow(const PanelFallbackException('no'));
      when(() => mockSsh.createFile(
            any(),
            isDir: any(named: 'isDir'),
            content: any(named: 'content'),
          )).thenAnswer((_) async {});

      await source.createFile('/x', isDir: false, content: 'c');

      verify(() => mockSsh.createFile(
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

    test('listContainers delegates to panel', () async {
      when(() => mockPanel.listContainers())
          .thenAnswer((_) async => [container]);

      final items = await source.listContainers();

      expect(items.single.name, 'web');
      verify(() => mockPanel.listContainers()).called(1);
      verifyNever(() => mockSsh.listContainers());
    });

    test('listContainers falls back to SSH', () async {
      when(() => mockPanel.listContainers())
          .thenThrow(const PanelFallbackException('no'));
      when(() => mockSsh.listContainers()).thenAnswer((_) async => [container]);

      final items = await source.listContainers();

      expect(items.single.name, 'web');
      verify(() => mockSsh.listContainers()).called(1);
    });

    test('startContainer delegates to panel', () async {
      when(() => mockPanel.startContainer(any())).thenAnswer((_) async {});

      await source.startContainer('web');

      verify(() => mockPanel.startContainer('web')).called(1);
      verifyNever(() => mockSsh.startContainer(any()));
    });

    test('stopContainer falls back to SSH', () async {
      when(() => mockPanel.stopContainer(any()))
          .thenThrow(const PanelFallbackException('no'));
      when(() => mockSsh.stopContainer(any())).thenAnswer((_) async {});

      await source.stopContainer('web');

      verify(() => mockSsh.stopContainer('web')).called(1);
    });

    test('restartContainer delegates to panel', () async {
      when(() => mockPanel.restartContainer(any())).thenAnswer((_) async {});

      await source.restartContainer('web');

      verify(() => mockPanel.restartContainer('web')).called(1);
    });

    test('pauseContainer falls back to SSH', () async {
      when(() => mockPanel.pauseContainer(any()))
          .thenThrow(const PanelFallbackException('no'));
      when(() => mockSsh.pauseContainer(any())).thenAnswer((_) async {});

      await source.pauseContainer('web');

      verify(() => mockSsh.pauseContainer('web')).called(1);
    });

    test('unpauseContainer delegates to panel', () async {
      when(() => mockPanel.unpauseContainer(any())).thenAnswer((_) async {});

      await source.unpauseContainer('web');

      verify(() => mockPanel.unpauseContainer('web')).called(1);
    });

    test('removeContainer falls back to SSH', () async {
      when(() => mockPanel.removeContainer(any(), force: any(named: 'force')))
          .thenThrow(const PanelFallbackException('no'));
      when(() => mockSsh.removeContainer(any(), force: any(named: 'force')))
          .thenAnswer((_) async {});

      await source.removeContainer('web');

      verify(() => mockSsh.removeContainer('web', force: true)).called(1);
    });

    test('inspectContainer delegates to panel', () async {
      when(() => mockPanel.inspectContainer(any()))
          .thenAnswer((_) async => ContainerInspect({}));

      await source.inspectContainer('web');

      verify(() => mockPanel.inspectContainer('web')).called(1);
    });

    test('containerLogs falls back to SSH (panel throws)', () async {
      when(() => mockPanel.containerLogs(any(),
              tail: any(named: 'tail'), follow: any(named: 'follow')))
          .thenThrow(const PanelFallbackException('no SSE'));
      when(() => mockSsh.containerLogs(any(),
              tail: any(named: 'tail'), follow: any(named: 'follow')))
          .thenAnswer((_) => Stream.value('line'));

      final lines = await source.containerLogs('web').toList();

      expect(lines, ['line']);
      verify(() => mockSsh.containerLogs('web')).called(1);
    });
  });
}
