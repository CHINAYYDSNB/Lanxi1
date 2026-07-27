/// Source of the system stats data.
enum SystemStatsSource { api, ssh }

/// A point-in-time snapshot of system resource usage.
class SystemStats {
  final double cpuPercent;
  final int memTotalMb;
  final int memUsedMb;
  final List<DiskInfo> disks;
  final int diskTotalMb;
  final int diskUsedMb;
  final String hostName;
  final String osInfo;
  final double loadAvg;
  final DateTime timestamp;
  final SystemStatsSource source;

  SystemStats({
    required this.cpuPercent,
    required this.memTotalMb,
    required this.memUsedMb,
    required this.disks,
    required this.diskTotalMb,
    required this.diskUsedMb,
    this.hostName = '',
    this.osInfo = '',
    this.loadAvg = 0.0,
    DateTime? timestamp,
    this.source = SystemStatsSource.api,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Reconstitute from JSON (e.g. cached state).
  factory SystemStats.fromJson(Map<String, dynamic> json) {
    return SystemStats(
      cpuPercent: (json['cpuPercent'] as num?)?.toDouble() ?? 0.0,
      memTotalMb: (json['memTotalMb'] as num?)?.toInt() ?? 0,
      memUsedMb: (json['memUsedMb'] as num?)?.toInt() ?? 0,
      disks: (json['disks'] as List<dynamic>?)
              ?.map((d) => DiskInfo.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      diskTotalMb: (json['diskTotalMb'] as num?)?.toInt() ?? 0,
      diskUsedMb: (json['diskUsedMb'] as num?)?.toInt() ?? 0,
      hostName: json['hostName'] as String? ?? '',
      osInfo: json['osInfo'] as String? ?? '',
      loadAvg: (json['loadAvg'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      source: json['source'] == 'ssh'
          ? SystemStatsSource.ssh
          : SystemStatsSource.api,
    );
  }

  Map<String, dynamic> toJson() => {
        'cpuPercent': cpuPercent,
        'memTotalMb': memTotalMb,
        'memUsedMb': memUsedMb,
        'disks': disks.map((d) => d.toJson()).toList(),
        'diskTotalMb': diskTotalMb,
        'diskUsedMb': diskUsedMb,
        'hostName': hostName,
        'osInfo': osInfo,
        'loadAvg': loadAvg,
        'timestamp': timestamp.toIso8601String(),
        'source': source.name,
      };

  double get memPercent => memTotalMb > 0 ? (memUsedMb / memTotalMb) * 100 : 0.0;
  double get diskPercent => diskTotalMb > 0 ? (diskUsedMb / diskTotalMb) * 100 : 0.0;
}

/// Disk partition information.
class DiskInfo {
  final String path;
  final int totalMb;
  final int usedMb;

  const DiskInfo({
    required this.path,
    required this.totalMb,
    required this.usedMb,
  });

  factory DiskInfo.fromJson(Map<String, dynamic> json) {
    return DiskInfo(
      path: json['path'] as String? ?? '/',
      totalMb: (json['totalMb'] as num?)?.toInt() ?? 0,
      usedMb: (json['usedMb'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'totalMb': totalMb,
        'usedMb': usedMb,
      };

  int get freeMb => totalMb - usedMb;
  double get percent => totalMb > 0 ? (usedMb / totalMb) * 100 : 0.0;
}
