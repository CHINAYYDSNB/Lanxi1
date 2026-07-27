import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/models/compress_result.dart';

void main() {
  group('CompressResult', () {
    test('fromJson parses all fields', () {
      final json = {
        'destPath': '/tmp/backup.tar.gz',
        'size': 1048576,
        'durationMs': 3000,
        'success': true,
        'errorMessage': null,
      };

      final result = CompressResult.fromJson(json);

      expect(result.destPath, '/tmp/backup.tar.gz');
      expect(result.size, 1048576);
      expect(result.durationMs, 3000);
      expect(result.success, true);
      expect(result.errorMessage, isNull);
    });

    test('fromJson handles error case', () {
      final json = {
        'destPath': '/tmp/fail.tar.gz',
        'size': 0,
        'durationMs': 500,
        'success': false,
        'errorMessage': 'Disk full',
      };

      final result = CompressResult.fromJson(json);

      expect(result.success, false);
      expect(result.errorMessage, 'Disk full');
    });

    test('toJson round-trips correctly', () {
      final original = CompressResult(
        destPath: '/tmp/test.tar.gz',
        size: 512000,
        durationMs: 1500,
        success: true,
      );

      final json = original.toJson();
      final restored = CompressResult.fromJson(json);

      expect(restored.destPath, original.destPath);
      expect(restored.size, original.size);
      expect(restored.durationMs, original.durationMs);
      expect(restored.success, original.success);
    });
  });
}
