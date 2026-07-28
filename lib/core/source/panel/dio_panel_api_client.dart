/// Dio-based HTTP client with 1Panel V2 authentication via interceptor.
///
/// Auth scheme (applied by [_AuthInterceptor]):
///   1. Generate `timestamp` (Unix seconds)
///   2. Compute `md5('1panel' + apiKey + timestamp)`
///   3. Send headers `1Panel-Token` and `1Panel-Timestamp`
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../exceptions.dart';

/// Pre-configured Dio client for communicating with a 1Panel API server.
class DioPanelApiClient {
  final Dio _dio;
  final String _apiKey;

  DioPanelApiClient({
    required String baseUrl,
    required String apiKey,
    Duration timeout = const Duration(seconds: 10),
    Dio? dio,
  })  : _apiKey = apiKey,
        _dio = (dio ?? Dio())
          ..options.baseUrl = baseUrl
          ..options.connectTimeout = timeout
          ..options.receiveTimeout = timeout {
    _dio.interceptors.add(_AuthInterceptor(apiKey: _apiKey));
  }

  /// Perform a GET request.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      _validateResponse(response, path);
      return response.data!;
    } on DioException catch (e) {
      throw PanelFallbackException(
        'Dio error on GET $path',
        original: e,
      );
    }
  }

  /// Perform a POST request.
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      _validateResponse(response, path);
      return response.data!;
    } on DioException catch (e) {
      throw PanelFallbackException(
        'Dio error on POST $path',
        original: e,
      );
    }
  }

  /// Perform a GET request and return raw response bytes (file download).
  Future<Uint8List> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw PanelFallbackException(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return Uint8List.fromList(response.data ?? const <int>[]);
    } on DioException catch (e) {
      throw PanelFallbackException('Dio error on GET $path', original: e);
    }
  }

  /// Throw [PanelFallbackException] for non-200 or API-level errors.
  void _validateResponse(Response<Map<String, dynamic>> resp, String path) {
    if (resp.statusCode == null ||
        resp.statusCode! < 200 ||
        resp.statusCode! >= 300) {
      throw PanelFallbackException(
        'HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
      );
    }
    final code = resp.data?['code'];
    if (code != null && code != 200) {
      throw PanelFallbackException('API code=$code');
    }
  }
}

/// Interceptor that adds 1Panel V2 auth headers to every request.
class _AuthInterceptor extends Interceptor {
  final String _apiKey;

  _AuthInterceptor({required String apiKey}) : _apiKey = apiKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final token = md5
        .convert(utf8.encode('1panel$_apiKey$timestamp'))
        .toString();
    options.headers['1Panel-Token'] = token;
    options.headers['1Panel-Timestamp'] = timestamp.toString();
    handler.next(options);
  }
}
