/// Shared mock classes for all tests.
library;

import 'package:dartssh2/dartssh2.dart' show SSHClient;
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

// ── dartssh2 mocks ──

class MockSSHClient extends Mock implements SSHClient {}

// ── dio mocks ──

class MockDio extends Mock implements Dio {}

class MockResponse extends Mock implements Response<Map<String, dynamic>> {}

// ── test utilities ──

/// Creates a mock [Response] with the given status code and data.
Map<String, dynamic> makeResponseData({
  int code = 200,
  String message = 'success',
  Map<String, dynamic>? data,
}) {
  return {
    'code': code,
    'message': message,
    'data': data ?? <String, dynamic>{},
  };
}
