import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/models/domain/system_stats.dart';

void main() {
  group('SystemStats', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'cpuPercent': 45.2,
        'memTotalMb': 8192,
        'memUsedMb': 4096,
        'disks': <dynamic>[],
        'diskTotalMb': 102400,
        'diskUsedMb': 51200,
        'loadAvg': 1.5,
        'timestamp': '2026-07-27T12:00:00.000Z',
        'source': 'api',
      };

      final snapshot = SystemStats.fromJson(json);

      expect(snapshot.cpuPercent, 45.2);
      expect(snapshot.memTotalMb, 8192);
      expect(snapshot.memUsedMb, 4096);
      expect(snapshot.diskTotalMb, 102400);
      expect(snapshot.diskUsedMb, 51200);
      expect(snapshot.loadAvg, 1.5);
      expect(snapshot.timestamp.toIso8601String(), '2026-07-27T12:00:00.000Z');
    });

    test('fromJson defaults to zero/now for null fields', () {
      final json = <String, dynamic>{};

      final snapshot = SystemStats.fromJson(json);

      expect(snapshot.cpuPercent, 0.0);
      expect(snapshot.memTotalMb, 0);
      expect(snapshot.memUsedMb, 0);
      expect(snapshot.diskTotalMb, 0);
      expect(snapshot.diskUsedMb, 0);
      expect(snapshot.loadAvg, 0.0);
      expect(snapshot.timestamp, isA<DateTime>());
    });

    test('toJson round-trips correctly', () {
      final original = SystemStats(
        cpuPercent: 72.1,
        memTotalMb: 16384,
        memUsedMb: 8192,
        disks: const [],
        diskTotalMb: 512000,
        diskUsedMb: 204800,
        loadAvg: 2.1,
        timestamp: DateTime(2026, 7, 27, 12, 0, 0),
      );

      final json = original.toJson();
      final restored = SystemStats.fromJson(json);

      expect(restored.cpuPercent, original.cpuPercent);
      expect(restored.memTotalMb, original.memTotalMb);
      expect(restored.memUsedMb, original.memUsedMb);
      expect(restored.diskTotalMb, original.diskTotalMb);
      expect(restored.diskUsedMb, original.diskUsedMb);
      expect(restored.loadAvg, original.loadAvg);
    });

    test('memPercent computes correctly', () {
      final stats = SystemStats(
        cpuPercent: 0,
        memTotalMb: 1000,
        memUsedMb: 250,
        disks: const [],
        diskTotalMb: 0,
        diskUsedMb: 0,
        loadAvg: 0,
      );

      expect(stats.memPercent, 25.0);
    });

    test('memPercent returns 0 when total is 0', () {
      final stats = SystemStats(
        cpuPercent: 0,
        memTotalMb: 0,
        memUsedMb: 100,
        disks: const [],
        diskTotalMb: 0,
        diskUsedMb: 0,
        loadAvg: 0,
      );

      expect(stats.memPercent, 0.0);
    });

    test('diskPercent computes correctly', () {
      final stats = SystemStats(
        cpuPercent: 0,
        memTotalMb: 0,
        memUsedMb: 0,
        disks: const [],
        diskTotalMb: 1000,
        diskUsedMb: 750,
        loadAvg: 0,
      );

      expect(stats.diskPercent, 75.0);
    });
  });

  group('DiskInfo', () {
    test('fromJson and toJson round-trip', () {
      final json = <String, dynamic>{'path': '/', 'totalMb': 1000, 'usedMb': 500};
      final info = DiskInfo.fromJson(json);
      expect(info.path, '/');
      expect(info.totalMb, 1000);
      expect(info.usedMb, 500);
    });

    test('freeMb computes correctly', () {
      const info = DiskInfo(path: '/', totalMb: 1000, usedMb: 300);
      expect(info.freeMb, 700);
    });

    test('percent computes correctly', () {
      const info = DiskInfo(path: '/', totalMb: 2000, usedMb: 500);
      expect(info.percent, 25.0);
    });
  });
}
