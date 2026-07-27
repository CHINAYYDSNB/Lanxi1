/// Adapter that maps 1Panel V2 API responses into Lanxi models.
///
/// Compatible with both nested (`currentInfo`) and flat JSON structures.
library;

import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/file_item.dart';
import 'package:lanxi/models/system_snapshot.dart';

import 'dio_panel_api_client.dart';

class OnePanelAdapter {
  final DioPanelApiClient _client;

  OnePanelAdapter(this._client);

  /// Fetch system info from 1Panel dashboard endpoint.
  ///
  /// POST /api/v2/dashboard/base/0/0
  Future<SystemSnapshot> getHostInfo() async {
    final data = await _client.post('/api/v2/dashboard/base/0/0');
    final body = data['data'] as Map<String, dynamic>? ?? {};

    // Try nested (currentInfo) first, then flat.
    final info = body['currentInfo'] as Map<String, dynamic>? ?? body;

    final cpuPercent = (info['cpuUsedPercent'] as num?)?.toDouble() ?? 0.0;

    // Memory in bytes → MB
    final memTotal = _bytesToMb(info['memoryTotal']);
    final memUsed = _bytesToMb(info['memoryUsed']);

    // Disk: first partition or aggregate
    final diskData = info['diskData'] as List<dynamic>?;
    int diskTotal = 0, diskUsed = 0;
    if (diskData != null && diskData.isNotEmpty) {
      final first = diskData.first as Map<String, dynamic>;
      diskTotal = _bytesToMb(first['total']);
      diskUsed = _bytesToMb(first['used']);
    } else {
      diskTotal = _bytesToMb(info['diskTotal']);
      diskUsed = _bytesToMb(info['diskUsed']);
    }

    final loadAvg = (info['loadAvg'] as num?)?.toDouble() ?? 0.0;

    return SystemSnapshot(
      cpuPercent: cpuPercent,
      memoryTotal: memTotal,
      memoryUsed: memUsed,
      diskTotal: diskTotal,
      diskUsed: diskUsed,
      loadAvg: loadAvg,
      timestamp: DateTime.now(),
    );
  }

  /// List directory contents.
  ///
  /// GET /api/v2/files?path=...
  Future<List<FileItem>> listDir(String path) async {
    final data = await _client.get(
      '/api/v2/files',
      queryParameters: {'path': path},
    );
    final items = data['data'] as List<dynamic>? ?? [];
    return items.map((e) {
      final entry = e as Map<String, dynamic>;
      return FileItem(
        name: entry['name'] as String? ?? '',
        path: '$path/${entry['name'] ?? ''}',
        size: (entry['size'] as num?)?.toInt() ?? 0,
        isDir: entry['isDir'] as bool? ?? false,
        permissions: entry['permissions'] as String? ?? '',
        modifiedTime: entry['modified'] != null
            ? DateTime.tryParse(entry['modified'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
    }).toList();
  }

  /// Compress files on the server.
  ///
  /// POST /api/v2/files/compress
  Future<CompressResult> compress(List<String> src, String dest) async {
    final start = DateTime.now();
    final data = await _client.post(
      '/api/v2/files/compress',
      data: {
        'src': src,
        'dest': dest,
      },
    );
    final duration = DateTime.now().difference(start);
    final body = data['data'] as Map<String, dynamic>? ?? {};
    return CompressResult(
      destPath: dest,
      size: (body['size'] as num?)?.toInt() ?? 0,
      durationMs: duration.inMilliseconds,
      success: true,
    );
  }

  /// Convert raw byte value to MB. Accepts [num] or [String].
  int _bytesToMb(dynamic value) {
    if (value == null) return 0;
    if (value is num) return (value / (1024 * 1024)).round();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return (parsed / (1024 * 1024)).round();
    }
    return 0;
  }
}
