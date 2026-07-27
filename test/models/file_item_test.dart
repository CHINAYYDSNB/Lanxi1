import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/models/domain/file_item.dart';

void main() {
  group('FileItem', () {
    test('fromJson parses all fields', () {
      final json = {
        'name': 'test.txt',
        'path': '/home/test.txt',
        'size': 1024,
        'isDir': false,
        'permissions': 'rwxr-xr-x',
        'modifiedTime': '2026-07-27T10:00:00.000Z',
      };

      final item = FileItem.fromJson(json);

      expect(item.name, 'test.txt');
      expect(item.path, '/home/test.txt');
      expect(item.size, 1024);
      expect(item.isDir, false);
      expect(item.permissions, 'rwxr-xr-x');
      expect(
        item.modifiedTime.toIso8601String(),
        '2026-07-27T10:00:00.000Z',
      );
    });

    test('fromJson defaults empty/null without crashing', () {
      final item = FileItem.fromJson(<String, dynamic>{});

      expect(item.name, '');
      expect(item.path, '');
      expect(item.size, 0);
      expect(item.isDir, false);
      expect(item.permissions, '');
      expect(item.modifiedTime, isA<DateTime>());
    });

    test('toJson round-trips correctly', () {
      final original = FileItem(
        name: 'config.yaml',
        path: '/etc/config.yaml',
        size: 2048,
        isDir: false,
        permissions: 'rw-r--r--',
        modifiedTime: DateTime(2026, 7, 26, 15, 30),
      );

      final json = original.toJson();
      final restored = FileItem.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.path, original.path);
      expect(restored.size, original.size);
      expect(restored.isDir, original.isDir);
      expect(restored.permissions, original.permissions);
    });

    group('sizeFormatted', () {
      test('formats bytes', () {
        final item = FileItem(
          name: 'small.txt',
          path: '/small.txt',
          size: 512,
          isDir: false,
          permissions: '',
          modifiedTime: DateTime.now(),
        );
        expect(item.sizeFormatted, '512 B');
      });

      test('formats KB', () {
        final item = FileItem(
          name: 'medium.txt',
          path: '/medium.txt',
          size: 2048,
          isDir: false,
          permissions: '',
          modifiedTime: DateTime.now(),
        );
        expect(item.sizeFormatted, '2.0 KB');
      });

      test('formats MB', () {
        final item = FileItem(
          name: 'large.txt',
          path: '/large.txt',
          size: 5 * 1024 * 1024,
          isDir: false,
          permissions: '',
          modifiedTime: DateTime.now(),
        );
        expect(item.sizeFormatted, '5.0 MB');
      });

      test('formats GB', () {
        final item = FileItem(
          name: 'huge.txt',
          path: '/huge.txt',
          size: 3 * 1024 * 1024 * 1024,
          isDir: false,
          permissions: '',
          modifiedTime: DateTime.now(),
        );
        expect(item.sizeFormatted, '3.0 GB');
      });
    });
  });

  group('MagicNumbers', () {
    test('PNG header is correct', () {
      expect(MagicNumbers.png, [0x89, 0x50, 0x4E, 0x47]);
    });

    test('JPEG header is correct', () {
      expect(MagicNumbers.jpeg, [0xFF, 0xD8, 0xFF]);
    });

    test('PDF header is correct', () {
      expect(MagicNumbers.pdf, [0x25, 0x50, 0x44, 0x46]);
    });

    test('ZIP header is correct', () {
      expect(MagicNumbers.zip, [0x50, 0x4B, 0x03, 0x04]);
    });

    test('GZip header is correct', () {
      expect(MagicNumbers.gzip, [0x1F, 0x8B]);
    });
  });
}
