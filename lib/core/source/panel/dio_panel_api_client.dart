/// Dio-based HTTP client with 1Panel V2 authentication.
///
/// Auth scheme:
///   1. Generate `timestamp` (Unix seconds)
///   2. Compute `md5('1panel' + apiKey + timestamp)`
///   3. Send headers `1Panel-Token` and `1Panel-Timestamp`
library;

import 'dart:convert';
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
          ..options.receiveTimeout = timeout;

  /// Add 1Panel V2 auth headers to every request.
  Map<String, String> _authHeaders() {
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch / 1000).floor().toString();
    final token =
        md5.convert(utf8.encode('1panel$_apiKey$timestamp')).toString();
    return {
      '1Panel-Token': token,
      '1Panel-Timestamp': timestamp,
    };
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
        options: Options(headers: _authHeaders()),
      );
      _validateResponse(response, path);
      return response.data!;
    } on DioException catch (e) {
      throw PanelFallbackException(
        'Dio error on GET $path',
        original: e,
        endpoint: path,
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
        options: Options(headers: _authHeaders()),
      );
      _validateResponse(response, path);
      return response.data!;
    } on DioException catch (e) {
      throw PanelFallbackException(
        'Dio error on POST $path',
        original: e,
        endpoint: path,
      );
    }
  }

  /// Throw [PanelFallbackException] for non-200 or API-level errors.
  void _validateResponse(Response<Map<String, dynamic>> resp, String path) {
    if (resp.statusCode == null ||
        resp.statusCode! < 200 ||
        resp.statusCode! >= 300) {
      throw PanelFallbackException(
        'HTTP ${resp.statusCode}',
        endpoint: path,
        original: resp,
      );
    }
    final code = resp.data?['code'];
    if (code != null && code != 200) {
      throw PanelFallbackException(
        'API code=$code: ${resp.data?['message']}',
        endpoint: path,
        original: resp,
      );
    }
  }
}
