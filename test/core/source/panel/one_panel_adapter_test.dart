// ignore_for_file: require_trailing_commas

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/panel/dio_panel_api_client.dart';
import 'package:lanxi/core/source/panel/one_panel_adapter.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements DioPanelApiClient {}

void main() {
  late _MockClient mockClient;
  late OnePanelAdapter adapter;

  setUp(() {
    mockClient = _MockClient();
    adapter = OnePanelAdapter(mockClient);
  });

  group('getHostInfo', () {
    test('parses nested currentInfo structure via DTO', () async {
      when(() => mockClient.post('/api/v2/dashboard/base/0/0'))
          .thenAnswer((_) async => <String, dynamic>{
                'code': 200,
                'message': 'success',
                'data': <String, dynamic>{
                  'currentInfo': <String, dynamic>{
                    'cpuUsedPercent': 35.2,
                    'memoryTotal': 8589934592,
                    'memoryUsed': 4294967296,
                    'diskData': <dynamic>[
                      <String, dynamic>{
                        'path': '/',
                        'total': 107374182400,
                        'used': 53687091200,
                      },
                    ],
                    'hostName': 'test-server',
                    'osInfo': 'Debian 13',
                    'loadAvg': 1.2,
                  },
                },
              });

      final result = await adapter.getHostInfo();

      expect(result.cpuPercent, 35.2);
      expect(result.memTotalMb, 8192);
      expect(result.memUsedMb, 4096);
      expect(result.disks.length, 1);
      expect(result.disks.first.path, '/');
      expect(result.hostName, 'test-server');
      expect(result.osInfo, 'Debian 13');
      expect(result.loadAvg, closeTo(1.2, 0.01));
      expect(result.source, SystemStatsSource.api);
    });

    test('parses flat structure when currentInfo is absent', () async {
      when(() => mockClient.post('/api/v2/dashboard/base/0/0'))
          .thenAnswer((_) async => <String, dynamic>{
                'code': 200,
                'message': 'success',
                'data': <String, dynamic>{
                  'cpuUsedPercent': 50.0,
                  'memoryTotal': 4194304,
                  'memoryUsed': 2097152,
                  'diskData': <dynamic>[
                    <String, dynamic>{
                      'path': '/',
                      'total': 53687091200,
                      'used': 26843545600,
                    },
                  ],
                  'hostName': 'mini',
                  'osInfo': 'Ubuntu 24',
                  'loadAvg': 2.5,
                },
              });

      final result = await adapter.getHostInfo();

      expect(result.cpuPercent, 50.0);
      expect(result.memTotalMb, 4);
      expect(result.hostName, 'mini');
    });

    test('throws PanelFallbackException on API error code', () async {
      when(() => mockClient.post('/api/v2/dashboard/base/0/0'))
          .thenAnswer((_) async => <String, dynamic>{
                'code': 403,
                'message': 'forbidden',
                'data': null,
              });

      expect(
        () => adapter.getHostInfo(),
        throwsA(isA<PanelFallbackException>()),
      );
    });

    test('wraps unexpected errors in PanelFallbackException', () async {
      when(() => mockClient.post('/api/v2/dashboard/base/0/0'))
          .thenThrow(Exception('connection lost'));

      expect(
        () => adapter.getHostInfo(),
        throwsA(isA<PanelFallbackException>()),
      );
    });
  });

  group('listDir', () {
    test('parses file list response via DTO', () async {
      when(() => mockClient.get(
            '/api/v2/files',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => <String, dynamic>{
            'code': 200,
            'message': 'success',
            'data': <dynamic>[
              <String, dynamic>{
                'name': 'test.txt',
                'size': 1024,
                'isDir': false,
                'permissions': '644',
                'modified': '2026-07-27T10:00:00Z',
              },
              <String, dynamic>{
                'name': 'subdir',
                'size': 4096,
                'isDir': true,
                'permissions': '755',
                'modified': '2026-07-26T08:00:00Z',
              },
            ],
          });

      final items = await adapter.listDir('/home');

      expect(items.length, 2);
      expect(items[0].name, 'test.txt');
      expect(items[0].isDir, false);
      expect(items[1].name, 'subdir');
      expect(items[1].isDir, true);
      expect(items[1].path, '/home/subdir');
    });

    test('returns empty list when data is null', () async {
      when(() => mockClient.get(
            '/api/v2/files',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => <String, dynamic>{'code': 200, 'message': 'ok'});

      final items = await adapter.listDir('/empty');

      expect(items, isEmpty);
    });
  });

  group('compress', () {
    test('posts paths/destination/type and returns CompressResult', () async {
      when(() => mockClient.post(
            '/api/v2/files/compress',
            data: any(named: 'data'),
          )).thenAnswer((_) async => <String, dynamic>{
            'code': 200,
            'message': 'success',
          });

      final result = await adapter.compress(
        ['/tmp/a.log'],
        '/tmp/a.zip',
        format: CompressFormat.zip,
      );

      expect(result.success, true);
      expect(result.destPath, '/tmp/a.zip');
      verify(() => mockClient.post(
            '/api/v2/files/compress',
            data: {
              'paths': ['/tmp/a.log'],
              'destination': '/tmp/a.zip',
              'type': 'zip',
            },
          )).called(1);
    });
  });

  group('readFileBytes', () {
    test('GET /files/download returns raw bytes', () async {
      when(() => mockClient.getBytes(
            '/api/v2/files/download',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final bytes = await adapter.readFileBytes('/tmp/a.png');

      expect(bytes, [1, 2, 3]);
      verify(() => mockClient.getBytes(
            '/api/v2/files/download',
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('wraps errors in PanelFallbackException', () {
      when(() => mockClient.getBytes(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(Exception('boom'));

      expect(
        () => adapter.readFileBytes('/tmp/a.png'),
        throwsA(isA<PanelFallbackException>()),
      );
    });
  });

  group('setFilePermission', () {
    test('posts /files/mode with mode + user + userGroup', () async {
      when(() => mockClient.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => {
                'code': 200,
                'message': 'success',
                'data': null,
              });

      await adapter.setFilePermission(
        '/tmp/a',
        mode: 493,
        owner: 'www-data',
        group: 'www-data',
      );

      verify(() => mockClient.post(
            '/api/v2/files/mode',
            data: {
              'path': '/tmp/a',
              'mode': 493,
              'user': 'www-data',
              'userGroup': 'www-data',
            },
          )).called(1);
    });

    test('omits user/userGroup when not provided', () async {
      when(() => mockClient.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => {
                'code': 200,
                'message': 'success',
                'data': null,
              });

      await adapter.setFilePermission('/tmp/a', mode: 420);

      verify(() => mockClient.post(
            '/api/v2/files/mode',
            data: {
              'path': '/tmp/a',
              'mode': 420,
            },
          )).called(1);
    });
  });

  group('file ops', () {
    test('readFile returns data.content', () async {
      when(() => mockClient.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => {
          'code': 200,
          'message': 'success',
          'data': {'content': 'hello\nworld'},
        },
      );

      expect(await adapter.readFile('/etc/hosts'), 'hello\nworld');
    });

    test('readFile throws PanelFallbackException on API error', () async {
      when(() => mockClient.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => {'code': 500, 'message': 'boom'});

      expect(
        () => adapter.readFile('/etc/hosts'),
        throwsA(isA<PanelFallbackException>()),
      );
    });

    test('writeFile posts path + content', () async {
      when(() => mockClient.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => {'code': 200, 'message': 'success', 'data': null});

      await adapter.writeFile('/tmp/a.txt', 'data');

      verify(() => mockClient.post(
            '/api/v2/files/save',
            data: {'path': '/tmp/a.txt', 'content': 'data'},
          )).called(1);
    });

    test('deleteFile posts path + isDir', () async {
      when(() => mockClient.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => {'code': 200, 'message': 'success', 'data': null});

      await adapter.deleteFile('/tmp/dir', isDir: true);

      verify(() => mockClient.post(
            '/api/v2/files/del',
            data: {'path': '/tmp/dir', 'isDir': true},
          )).called(1);
    });

    test('renameFile posts oldName + newName', () async {
      when(() => mockClient.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => {'code': 200, 'message': 'success', 'data': null});

      await adapter.renameFile('/a', '/b');

      verify(() => mockClient.post(
            '/api/v2/files/rename',
            data: {'oldName': '/a', 'newName': '/b'},
          )).called(1);
    });

    test('createFile posts path + isDir (+ content)', () async {
      when(() => mockClient.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => {'code': 200, 'message': 'success', 'data': null});

      await adapter.createFile('/tmp/new', isDir: false, content: 'x');

      verify(() => mockClient.post(
            '/api/v2/files',
            data: {'path': '/tmp/new', 'isDir': false, 'content': 'x'},
          )).called(1);
    });
  });

  group('listContainers', () {
    test('parses data.items into domain containers', () async {
      when(() => mockClient.post(
            '/api/v2/containers/search',
            data: any(named: 'data'),
          )).thenAnswer((_) async => <String, dynamic>{
            'code': 200,
            'message': 'success',
            'data': <String, dynamic>{
              'items': <dynamic>[
                <String, dynamic>{
                  'containerID': 'abc123',
                  'name': 'web',
                  'image': 'nginx:latest',
                  'state': 'running',
                  'status': 'Up 2 hours',
                  'createdAt': '2026-07-27',
                  'ports': <dynamic>['0.0.0.0:8080->80/tcp'],
                },
              ],
            },
          });

      final containers = await adapter.listContainers();

      expect(containers.length, 1);
      expect(containers.first.name, 'web');
      expect(containers.first.state, 'running');
      expect(containers.first.ports, ['0.0.0.0:8080->80/tcp']);
      expect(containers.first.isRunning, true);
    });

    test('throws PanelFallbackException on API error', () async {
      when(() => mockClient.post(
            '/api/v2/containers/search',
            data: any(named: 'data'),
          )).thenAnswer((_) async => {'code': 500, 'message': 'boom'});

      expect(
        () => adapter.listContainers(),
        throwsA(isA<PanelFallbackException>()),
      );
    });
  });

  group('container operations', () {
    test('operate posts name + operation', () async {
      when(() => mockClient.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => {'code': 200, 'message': 'success'});

      await adapter.startContainer('web');

      verify(() => mockClient.post(
            '/api/v2/containers/operate',
            data: {'name': 'web', 'operation': 'start'},
          )).called(1);
    });

    test('removeContainer posts names array + force', () async {
      when(() => mockClient.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => {'code': 200, 'message': 'success'});

      await adapter.removeContainer('web', force: true);

      verify(() => mockClient.post(
            '/api/v2/containers/delete',
            data: {
              'names': ['web'],
              'force': true,
            },
          )).called(1);
    });

    test('inspectContainer returns ContainerInspect', () async {
      when(() => mockClient.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => <String, dynamic>{
            'code': 200,
            'message': 'success',
            'data': <String, dynamic>{
              'Id': 'abc',
              'Name': '/web',
              'Config': <String, dynamic>{'Image': 'nginx'},
            },
          });

      final inspect = await adapter.inspectContainer('web');

      expect(inspect.id, 'abc');
      expect(inspect.name, 'web');
    });

    test('containerLogs throws PanelFallbackException (SSE not wired)', () {
      expect(
        () => adapter.containerLogs('web'),
        throwsA(isA<PanelFallbackException>()),
      );
    });
  });
}
