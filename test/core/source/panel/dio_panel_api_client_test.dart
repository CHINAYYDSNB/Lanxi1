import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/panel/dio_panel_api_client.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _MockResponse extends Mock implements Response<Map<String, dynamic>> {}

Map<String, dynamic> _makeData({
  int code = 200,
  String message = 'success',
  Map<String, dynamic>? data,
}) {
  return <String, dynamic>{
    'code': code,
    'message': message,
    'data': data ?? <String, dynamic>{},
  };
}

void main() {
  late _MockDio mockDio;

  setUp(() {
    mockDio = _MockDio();
    when(() => mockDio.options).thenReturn(
      BaseOptions(baseUrl: 'http://localhost'),
    );
  });

  DioPanelApiClient _createClient() {
    return DioPanelApiClient(
      baseUrl: 'http://192.168.1.100:9999',
      apiKey: 'test-api-key',
      dio: mockDio,
    );
  }

  _MockResponse _successResponse({Map<String, dynamic>? data}) {
    final resp = _MockResponse();
    when(() => resp.statusCode).thenReturn(200);
    when(() => resp.data).thenReturn(_makeData(data: data));
    return resp;
  }

  group('GET requests', () {
    test('returns data on successful response', () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _successResponse(data: {'info': 'ok'}));

      final client = _createClient();
      final result = await client.get('/api/v2/files', queryParameters: {
        'path': '/home',
      });

      expect(result['data']['info'], 'ok');
    });

    test('throws PanelFallbackException on HTTP error', () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v2/files'),
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: '/api/v2/files'),
          ),
        ),
      );

      final client = _createClient();
      expect(
        () => client.get('/api/v2/files'),
        throwsA(isA<PanelFallbackException>()),
      );
    });
  });

  group('POST requests', () {
    test('returns data on successful response', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _successResponse(data: {'task': 'started'}));

      final client = _createClient();
      final result = await client.post('/api/v2/files/compress', data: {
        'src': ['/tmp/a'],
        'dest': '/tmp/a.zip',
      });

      expect(result['data']['task'], 'started');
    });

    test('throws PanelFallbackException on non-200 API code', () async {
      final resp = _MockResponse();
      when(() => resp.statusCode).thenReturn(200);
      when(() => resp.data).thenReturn(_makeData(code: 500, message: 'error'));
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => resp);

      final client = _createClient();
      expect(
        () => client.post('/api/v2/files/compress'),
        throwsA(isA<PanelFallbackException>()),
      );
    });

    test('throws PanelFallbackException on DioException (timeout)', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v2/dashboard'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final client = _createClient();
      expect(
        () => client.post('/api/v2/dashboard/base/0/0'),
        throwsA(isA<PanelFallbackException>()),
      );
    });

    test('sets 1Panel auth headers', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        final opts = invocation.namedArguments[#options] as Options;
        final headers = opts.headers!;
        expect(headers, containsPair('1Panel-Timestamp', isA<String>()));
        expect(headers, containsPair('1Panel-Token', isA<String>()));
        return _successResponse();
      });

      final client = _createClient();
      await client.post('/api/v2/dashboard/base/0/0');
    });
  });
}
