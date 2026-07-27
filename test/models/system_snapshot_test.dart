import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/models/system_snapshot.dart';

void main() {
  group('SystemSnapshot', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'cpuPercent': 45.2,
        'memoryTotal': 8192,
        'memoryUsed': 4096,
        'diskTotal': 102400,
        'diskUsed': 51200,
        'loadAvg': 1.5,
        'timestamp': '2026-07-27T12:00:00.000Z',
      };

      final snapshot = SystemSnapshot.fromJson(json);

      expect(snapshot.cpuPercent, 45.2);
      expect(snapshot.memoryTotal, 8192);
      expect(snapshot.memoryUsed, 4096);
      expect(snapshot.diskTotal, 102400);
      expect(snapshot.diskUsed, 51200);
      expect(snapshot.loadAvg, 1.5);
      expect(
        snapshot.timestamp.toIso8601String(),
        '2026-07-27T12:00:00.000Z',
      );
    });

    test('fromJson defaults to zero/now for null fields', () {
      final json = <String, dynamic>{};

      final snapshot = SystemSnapshot.fromJson(json);

      expect(snapshot.cpuPercent, 0.0);
      expect(snapshot.memoryTotal, 0);
      expect(snapshot.memoryUsed, 0);
      expect(snapshot.diskTotal, 0);
      expect(snapshot.diskUsed, 0);
      expect(snapshot.loadAvg, 0.0);
      // timestamp defaults to now — just verify it's a valid DateTime
      expect(snapshot.timestamp, isA<DateTime>());
    });

    test('toJson round-trips correctly', () {
      final original = SystemSnapshot(
        cpuPercent: 72.1,
        memoryTotal: 16384,
        memoryUsed: 8192,
        diskTotal: 512000,
        diskUsed: 204800,
        loadAvg: 2.1,
        timestamp: DateTime(2026, 7, 27, 12, 0, 0),
      );

      final json = original.toJson();
      final restored = SystemSnapshot.fromJson(json);

      expect(restored.cpuPercent, original.cpuPercent);
      expect(restored.memoryTotal, original.memoryTotal);
      expect(restored.memoryUsed, original.memoryUsed);
      expect(restored.diskTotal, original.diskTotal);
      expect(restored.diskUsed, original.diskUsed);
      expect(restored.loadAvg, original.loadAvg);
    });

    test('memoryPercent computes correctly', () {
      final snapshot = SystemSnapshot(
        cpuPercent: 0,
        memoryTotal: 1000,
        memoryUsed: 250,
        diskTotal: 0,
        diskUsed: 0,
        loadAvg: 0,
        timestamp: DateTime.now(),
      );

      expect(snapshot.memoryPercent, 25.0);
    });

    test('memoryPercent returns 0 when total is 0', () {
      final snapshot = SystemSnapshot(
        cpuPercent: 0,
        memoryTotal: 0,
        memoryUsed: 100,
        diskTotal: 0,
        diskUsed: 0,
        loadAvg: 0,
        timestamp: DateTime.now(),
      );

      expect(snapshot.memoryPercent, 0.0);
    });

    test('diskPercent computes correctly', () {
      final snapshot = SystemSnapshot(
        cpuPercent: 0,
        memoryTotal: 0,
        memoryUsed: 0,
        diskTotal: 1000,
        diskUsed: 750,
        loadAvg: 0,
        timestamp: DateTime.now(),
      );

      expect(snapshot.diskPercent, 75.0);
    });
  });
}
