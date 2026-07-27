import 'package:lanxi/models/domain/system_stats.dart';

/// Maps 1Panel `/api/v2/dashboard/base/0/0` response.
class HostStatusDto {
  final double cpuUsedPercent;
  final int memoryTotal;
  final int memoryUsed;
  final List<DiskDataDto> diskData;
  final String hostName;
  final String osInfo;
  final double loadAvg;

  const HostStatusDto({
    required this.cpuUsedPercent,
    required this.memoryTotal,
    required this.memoryUsed,
    required this.diskData,
    required this.hostName,
    required this.osInfo,
    this.loadAvg = 0.0,
  });

  factory HostStatusDto.fromJson(Map<String, dynamic> json) {
    // Handle both nested (currentInfo) and flat structures
    final data = json['currentInfo'] as Map<String, dynamic>? ?? json;

    // Memory values may be in bytes → store raw, convert on toDomain
    final rawMemTotal = data['memoryTotal'];
    final rawMemUsed = data['memoryUsed'];

    return HostStatusDto(
      cpuUsedPercent: (data['cpuUsedPercent'] as num?)?.toDouble() ?? 0.0,
      memoryTotal: rawMemTotal is int ? rawMemTotal : _tryParseInt(rawMemTotal),
      memoryUsed: rawMemUsed is int ? rawMemUsed : _tryParseInt(rawMemUsed),
      diskData: (data['diskData'] as List<dynamic>?)
              ?.map((d) => DiskDataDto.fromJson(d as Map<String, dynamic>))
              .toList() ??
          const [],
      hostName: data['hostName'] as String? ?? '',
      osInfo: data['osInfo'] as String? ?? '',
      loadAvg: (data['loadAvg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert DTO to domain model used by UI.
  SystemStats toDomain() {
    return SystemStats(
      cpuPercent: cpuUsedPercent,
      memTotalMb: memoryTotal > 0 && memoryTotal < 1e6
          ? memoryTotal
          : (memoryTotal / (1024 * 1024)).round(),
      memUsedMb: memoryUsed > 0 && memoryUsed < 1e6
          ? memoryUsed
          : (memoryUsed / (1024 * 1024)).round(),
      disks: diskData.map((d) => d.toDomain()).toList(),
      diskTotalMb: diskData.fold<int>(0, (sum, d) => sum + d.toDomain().totalMb),
      diskUsedMb: diskData.fold<int>(0, (sum, d) => sum + d.toDomain().usedMb),
      hostName: hostName,
      osInfo: osInfo,
      loadAvg: loadAvg,
      source: SystemStatsSource.api,
    );
  }

  static int _tryParseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

/// Disk partition data from 1Panel API.
class DiskDataDto {
  final String path;
  final int total;
  final int used;

  const DiskDataDto({
    required this.path,
    required this.total,
    required this.used,
  });

  factory DiskDataDto.fromJson(Map<String, dynamic> json) {
    return DiskDataDto(
      path: json['path'] as String? ?? '/',
      total: (json['total'] as num?)?.toInt() ?? 0,
      used: (json['used'] as num?)?.toInt() ?? 0,
    );
  }

  DiskInfo toDomain() => DiskInfo(
        path: path,
        totalMb: total > 0 && total < 1e6 ? total : (total / (1024 * 1024)).round(),
        usedMb: used > 0 && used < 1e6 ? used : (used / (1024 * 1024)).round(),
      );
}
