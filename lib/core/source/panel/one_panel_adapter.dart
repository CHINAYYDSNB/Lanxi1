/// Adapter that maps 1Panel V2 API responses into Lanxi domain models.
///
/// Uses [ApiResponse<T>] wrappers and typed DTOs with [toDomain()] conversion.
/// Compatible with both nested (currentInfo) and flat JSON structures.
library;

import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/models/compress_result.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/models/dto/api_response.dart';
import 'package:lanxi/models/dto/file_item_dto.dart';
import 'package:lanxi/models/dto/host_status_dto.dart';

import 'dio_panel_api_client.dart';

class OnePanelAdapter {
  final DioPanelApiClient _client;

  OnePanelAdapter(this._client);

  /// Fetch system info from 1Panel dashboard endpoint.
  ///
  /// POST /api/v2/dashboard/base/0/0
  /// Uses for initial load only — real-time monitoring uses SSH streams.
  Future<SystemStats> getHostInfo() async {
    try {
      final response = await _client.post('/api/v2/dashboard/base/0/0');
      final apiResp = ApiResponse<HostStatusDto>.fromJson(
        response,
        (json) => HostStatusDto.fromJson(json),
      );
      if (!apiResp.isSuccess || apiResp.data == null) {
        throw PanelFallbackException(
          'Failed to fetch host status',
          statusCode: apiResp.code,
        );
      }
      return apiResp.data!.toDomain();
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', originalError: e);
    }
  }

  /// List directory contents.
  ///
  /// GET /api/v2/files?path=...
  Future<List<FileItem>> listDir(String path) async {
    try {
      final response = await _client.get(
        '/api/v2/files',
        queryParameters: {'path': path},
      );
      final apiResp = ApiResponse<List<FileItemDto>>.fromJsonList(
        response,
        (list) => list
            .map((e) => FileItemDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      if (!apiResp.isSuccess) {
        throw PanelFallbackException(
          'Failed to list directory',
          statusCode: apiResp.code,
        );
      }
      final items = apiResp.data ?? [];
      return items.map((dto) => dto.toDomain(path)).toList();
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', originalError: e);
    }
  }

  /// Compress files on the server.
  ///
  /// POST /api/v2/files/compress
  Future<CompressResult> compress(List<String> src, String dest) async {
    try {
      final start = DateTime.now();
      final response = await _client.post(
        '/api/v2/files/compress',
        data: {'src': src, 'dest': dest},
      );
      final duration = DateTime.now().difference(start);
      final apiResp = ApiResponse.fromJson(
        response,
        (_) => null, // compress response has no structured data body
      );
      if (!apiResp.isSuccess) {
        throw PanelFallbackException(
          'Compression failed',
          statusCode: apiResp.code,
        );
      }
      return CompressResult(
        destPath: dest,
        size: 0,
        durationMs: duration.inMilliseconds,
        success: true,
      );
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', originalError: e);
    }
  }
}
