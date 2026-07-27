// ignore_for_file: require_trailing_commas

import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/panel/dio_panel_api_client.dart';
import 'package:lanxi/core/source/panel/one_panel_adapter.dart';
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
    test('parses nested currentInfo structure', () async {
      when(() => mockClient.post('/api/v2/dashboard/base/0/0'))
          .thenAnswer((_) async => <String, dynamic>{
                'code': 200,
                'data': <String, dynamic>{
                  'currentInfo': <String, dynamic>{
                    'cpuUsedPercent': 35.2,
                    'memoryTotal': 8589934592,
                    'memoryUsed': 4294967296,
                    'diskData': <dynamic>[
                      <String, dynamic>{
                        'total': 107374182400,
                        'used': 53687091200,
                      },
                    ],
                    'loadAvg': 1.2,
                  },
                },
              });

      final result = await adapter.getHostInfo();

      expect(result.cpuPercent, 35.2);
      expect(result.memoryTotal, 8192);
      expect(result.memoryUsed, 4096);
      expect(result.diskTotal, 102400);
      expect(result.diskUsed, 51200);
      expect(result.loadAvg, closeTo(1.2, 0.01));
    });

    test('parses flat structure when currentInfo is absent', () async {
      when(() => mockClient.post('/api/v2/dashboard/base/0/0'))
          .thenAnswer((_) async => <String, dynamic>{
                'code': 200,
                'data': <String, dynamic>{
                  'cpuUsedPercent': 50.0,
                  'memoryTotal': 4194304,
                  'memoryUsed': 2097152,
                  'diskTotal': 53687091200,
                  'diskUsed': 26843545600,
                  'loadAvg': 2.5,
                },
              });

      final result = await adapter.getHostInfo();

      expect(result.cpuPercent, 50.0);
      expect(result.memoryTotal, 4);
      expect(result.diskTotal, 51200);
    });

    test('returns defaults when API returns empty data', () async {
      when(() => mockClient.post('/api/v2/dashboard/base/0/0'))
          .thenAnswer((_) async => <String, dynamic>{
                'code': 200,
                'data': <String, dynamic>{},
              });

      final result = await adapter.getHostInfo();

      expect(result.cpuPercent, 0.0);
      expect(result.memoryTotal, 0);
      expect(result.diskTotal, 0);
      expect(result.loadAvg, 0.0);
    });
  });

  group('listDir', () {
    test('parses file list response', () async {
      when(() => mockClient.get(
            '/api/v2/files',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => <String, dynamic>{
            'code': 200,
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
          )).thenAnswer((_) async => <String, dynamic>{'code': 200});

      final items = await adapter.listDir('/empty');

      expect(items, isEmpty);
    });
  });

  group('compress', () {
    test('returns CompressResult on success', () async {
      when(() => mockClient.post(
            '/api/v2/files/compress',
            data: any(named: 'data'),
          )).thenAnswer((_) async => <String, dynamic>{
            'code': 200,
            'data': <String, dynamic>{'size': 1048576},
          });

      final result = await adapter.compress(
        ['/tmp/a.log'],
        '/tmp/a.zip',
      );

      expect(result.success, true);
      expect(result.destPath, '/tmp/a.zip');
      expect(result.size, 1048576);
    });
  });
}
