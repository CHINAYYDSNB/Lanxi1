import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/exceptions.dart';

void main() {
  group('PanelFallbackException', () {
    test('constructor sets message', () {
      const ex = PanelFallbackException('API Error 403');
      expect(ex.message, 'API Error 403');
    });

    test('constructor sets statusCode when provided', () {
      const ex = PanelFallbackException(
        'Not found',
        statusCode: 404,
      );
      expect(ex.statusCode, 404);
    });

    test('constructor sets originalError when provided', () {
      final original = Exception('connection reset');
      final ex = PanelFallbackException(
        'Dio error',
        originalError: original,
      );
      expect(ex.originalError, same(original));
    });

    test('toString includes message and statusCode', () {
      const ex = PanelFallbackException(
        'timeout',
        statusCode: 408,
      );
      final str = ex.toString();
      expect(str, contains('timeout'));
      expect(str, contains('408'));
    });

    test('toString works without statusCode', () {
      const ex = PanelFallbackException('generic error');
      final str = ex.toString();
      expect(str, contains('generic error'));
    });
  });

  group('SshConnectionException', () {
    test('constructor sets message and host', () {
      const ex = SshConnectionException('Connection refused', host: '10.0.0.1');
      expect(ex.message, 'Connection refused');
      expect(ex.host, '10.0.0.1');
    });

    test('toString includes host', () {
      const ex = SshConnectionException('timeout', host: 'example.com');
      final str = ex.toString();
      expect(str, contains('example.com'));
    });
  });
}
