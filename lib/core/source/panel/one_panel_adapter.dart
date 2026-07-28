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
import 'package:lanxi/models/dto/container_dto.dart';
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
      throw PanelFallbackException('API unreachable', original: e);
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
      throw PanelFallbackException('API unreachable', original: e);
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
      throw PanelFallbackException('API unreachable', original: e);
    }
  }

  /// Read a file's text content.
  ///
  /// POST /api/v2/files/content  ->  data.content
  Future<String> readFile(String path) async {
    try {
      final response = await _client.post(
        '/api/v2/files/content',
        data: {'path': path},
      );
      final apiResp = ApiResponse<Map<String, dynamic>>.fromJson(
        response,
        (json) => json,
      );
      if (!apiResp.isSuccess || apiResp.data == null) {
        throw PanelFallbackException(
          'Failed to read file',
          statusCode: apiResp.code,
        );
      }
      return apiResp.data!['content'] as String? ?? '';
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', original: e);
    }
  }

  /// Save file content.
  ///
  /// POST /api/v2/files/save  ->  {path, content}
  Future<void> writeFile(String path, String content) async {
    try {
      final response = await _client.post(
        '/api/v2/files/save',
        data: {'path': path, 'content': content},
      );
      final apiResp = ApiResponse.fromJson(response, (_) => null);
      if (!apiResp.isSuccess) {
        throw PanelFallbackException(
          'Failed to save file',
          statusCode: apiResp.code,
        );
      }
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', original: e);
    }
  }

  /// Delete a file or directory.
  ///
  /// POST /api/v2/files/del  ->  {path, isDir}
  Future<void> deleteFile(String path, {required bool isDir}) async {
    try {
      final response = await _client.post(
        '/api/v2/files/del',
        data: {'path': path, 'isDir': isDir},
      );
      final apiResp = ApiResponse.fromJson(response, (_) => null);
      if (!apiResp.isSuccess) {
        throw PanelFallbackException(
          'Failed to delete',
          statusCode: apiResp.code,
        );
      }
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', original: e);
    }
  }

  /// Rename / move a file or directory.
  ///
  /// POST /api/v2/files/rename  ->  {oldName, newName}
  Future<void> renameFile(String oldPath, String newPath) async {
    try {
      final response = await _client.post(
        '/api/v2/files/rename',
        data: {'oldName': oldPath, 'newName': newPath},
      );
      final apiResp = ApiResponse.fromJson(response, (_) => null);
      if (!apiResp.isSuccess) {
        throw PanelFallbackException(
          'Failed to rename',
          statusCode: apiResp.code,
        );
      }
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', original: e);
    }
  }

  /// Create a new file or directory.
  ///
  /// POST /api/v2/files  ->  {path, isDir, content?}
  Future<void> createFile(String path, {required bool isDir, String? content}) async {
    try {
      final data = <String, dynamic>{'path': path, 'isDir': isDir};
      if (content != null) data['content'] = content;
      final response = await _client.post('/api/v2/files', data: data);
      final apiResp = ApiResponse.fromJson(response, (_) => null);
      if (!apiResp.isSuccess) {
        throw PanelFallbackException(
          'Failed to create',
          statusCode: apiResp.code,
        );
      }
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', original: e);
    }
  }

  // ── Docker ──

  /// List containers.
  ///
  /// POST /api/v2/containers/search
  /// 1Panel returns `data` either as a bare list or as an object
  /// `{items: [...], total: N}` — both shapes are accepted.
  Future<List<ContainerDomain>> listContainers() async {
    try {
      final response = await _client.post(
        '/api/v2/containers/search',
        data: const <String, dynamic>{},
      );
      final apiResp = ApiResponse<Map<String, dynamic>>.fromJson(
        response,
        (json) => json,
      );
      if (!apiResp.isSuccess || apiResp.data == null) {
        throw PanelFallbackException(
          'Failed to list containers',
          statusCode: apiResp.code,
        );
      }
      final Object? raw = apiResp.data;
      final List<dynamic> rawList;
      if (raw is List) {
        rawList = raw;
      } else if (raw is Map && raw['items'] is List) {
        rawList = raw['items'] as List<dynamic>;
      } else {
        rawList = <dynamic>[];
      }
      final dtos = rawList
          .map((e) => ContainerDto.fromJson(e as Map<String, dynamic>))
          .toList();
      return dtos.map((dto) => dto.toDomain()).toList();
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', original: e);
    }
  }

  /// Start / stop / restart / pause / unpause a container.
  ///
  /// POST /api/v2/containers/operate  ->  {name, operation}
  Future<void> operateContainer(String name, String operation) async {
    try {
      final response = await _client.post(
        '/api/v2/containers/operate',
        data: {'name': name, 'operation': operation},
      );
      final apiResp = ApiResponse.fromJson(response, (_) => null);
      if (!apiResp.isSuccess) {
        throw PanelFallbackException(
          'Failed to $operation $name',
          statusCode: apiResp.code,
        );
      }
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', original: e);
    }
  }

  Future<void> startContainer(String name) => operateContainer(name, 'start');

  Future<void> stopContainer(String name) => operateContainer(name, 'stop');

  Future<void> restartContainer(String name) =>
      operateContainer(name, 'restart');

  Future<void> pauseContainer(String name) => operateContainer(name, 'pause');

  Future<void> unpauseContainer(String name) =>
      operateContainer(name, 'unpause');

  /// Remove a container.
  ///
  /// POST /api/v2/containers/delete  ->  {names: [name], force}
  Future<void> removeContainer(String name, {bool force = true}) async {
    try {
      final response = await _client.post(
        '/api/v2/containers/delete',
        data: {
          'names': [name],
          'force': force,
        },
      );
      final apiResp = ApiResponse.fromJson(response, (_) => null);
      if (!apiResp.isSuccess) {
        throw PanelFallbackException(
          'Failed to remove $name',
          statusCode: apiResp.code,
        );
      }
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', original: e);
    }
  }

  /// Inspect a container.
  ///
  /// POST /api/v2/containers/inspect  ->  data (raw inspect object)
  Future<ContainerInspect> inspectContainer(String name) async {
    try {
      final response = await _client.post(
        '/api/v2/containers/inspect',
        data: {'name': name},
      );
      final apiResp = ApiResponse<Map<String, dynamic>>.fromJson(
        response,
        (json) => json,
      );
      if (!apiResp.isSuccess || apiResp.data == null) {
        throw PanelFallbackException(
          'Failed to inspect $name',
          statusCode: apiResp.code,
        );
      }
      return ContainerInspect(apiResp.data!);
    } on PanelFallbackException {
      rethrow;
    } catch (e) {
      throw PanelFallbackException('API unreachable', original: e);
    }
  }

  /// Container logs.
  ///
  /// 1Panel exposes logs via SSE (`/api/v2/containers/search/log`). That path
  /// is not wired through this Dio adapter, so we signal the fallback layer to
  /// stream logs over SSH instead.
  Stream<String> containerLogs(String name, {int tail = 200, bool follow = false}) {
    throw const PanelFallbackException(
      'containerLogs not available through 1Panel API',
    );
  }
}
