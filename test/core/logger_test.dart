import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/logger.dart';

void main() {
  group('AppLogger', () {
    test('can log debug without throwing', () {
      expect(() => appLogger.d('debug message'), returnsNormally);
    });

    test('can log info without throwing', () {
      expect(() => appLogger.i('info message'), returnsNormally);
    });

    test('can log warning without throwing', () {
      expect(() => appLogger.w('warning message'), returnsNormally);
    });

    test('can log error without throwing', () {
      expect(
        () => appLogger.e('error message'),
        returnsNormally,
      );
    });

    test('can log error with error and stacktrace', () {
      expect(
        () => appLogger.e('error', Exception('test'), StackTrace.current),
        returnsNormally,
      );
    });

    test('should never throw on any input', () {
      expect(
        () => appLogger.d(''),
        returnsNormally,
      );
      expect(
        () => appLogger.i('some long message ' * 100),
        returnsNormally,
      );
      expect(
        () => appLogger.w('special chars: \$@!#'),
        returnsNormally,
      );
    });
  });
}
