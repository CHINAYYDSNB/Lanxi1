import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/exceptions.dart';

void main() {
  group('PanelFallbackException', () {
    test('constructor sets message', () {
      const ex = PanelFallbackException('API Error 403');
      expect(ex.message, 'API Error 403');
    });

    test('constructor sets endpoint when provided', () {
      const ex = PanelFallbackException(
        'Not found',
        endpoint: '/api/v2/files',
      );
      expect(ex.endpoint, '/api/v2/files');
    });

    test('constructor sets original error when provided', () {
      final original = Exception('connection reset');
      final ex = PanelFallbackException(
        'Dio error',
        original: original,
      );
      expect(ex.original, same(original));
    });

    test('toString includes message and endpoint', () {
      const ex = PanelFallbackException(
        'timeout',
        endpoint: '/api/v2/dashboard',
      );
      final str = ex.toString();
      expect(str, contains('timeout'));
      expect(str, contains('/api/v2/dashboard'));
    });

    test('toString works when endpoint is empty', () {
      const ex = PanelFallbackException('generic error');
      final str = ex.toString();
      expect(str, contains('generic error'));
    });
  });
}
