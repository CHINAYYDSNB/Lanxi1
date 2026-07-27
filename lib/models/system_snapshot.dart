/// A point-in-time snapshot of system resource usage.
class SystemSnapshot {
  final double cpuPercent;
  final int memoryTotal; // MB
  final int memoryUsed; // MB
  final int diskTotal; // MB
  final int diskUsed; // MB
  final double loadAvg;
  final DateTime timestamp;

  const SystemSnapshot({
    required this.cpuPercent,
    required this.memoryTotal,
    required this.memoryUsed,
    required this.diskTotal,
    required this.diskUsed,
    required this.loadAvg,
    required this.timestamp,
  });

  factory SystemSnapshot.fromJson(Map<String, dynamic> json) {
    return SystemSnapshot(
      cpuPercent: (json['cpuPercent'] as num?)?.toDouble() ?? 0.0,
      memoryTotal: (json['memoryTotal'] as num?)?.toInt() ?? 0,
      memoryUsed: (json['memoryUsed'] as num?)?.toInt() ?? 0,
      diskTotal: (json['diskTotal'] as num?)?.toInt() ?? 0,
      diskUsed: (json['diskUsed'] as num?)?.toInt() ?? 0,
      loadAvg: (json['loadAvg'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'cpuPercent': cpuPercent,
        'memoryTotal': memoryTotal,
        'memoryUsed': memoryUsed,
        'diskTotal': diskTotal,
        'diskUsed': diskUsed,
        'loadAvg': loadAvg,
        'timestamp': timestamp.toIso8601String(),
      };

  double get memoryPercent =>
      memoryTotal > 0 ? (memoryUsed / memoryTotal) * 100 : 0.0;

  double get diskPercent =>
      diskTotal > 0 ? (diskUsed / diskTotal) * 100 : 0.0;
}
