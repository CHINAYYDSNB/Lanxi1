import 'package:lanxi/models/domain/file_item.dart';

/// Maps 1Panel `/api/v2/files` response entries.
class FileItemDto {
  final String name;
  final int size;
  final bool isDir;
  final String permissions;
  final String? modified;

  const FileItemDto({
    required this.name,
    required this.size,
    required this.isDir,
    required this.permissions,
    this.modified,
  });

  factory FileItemDto.fromJson(Map<String, dynamic> json) {
    return FileItemDto(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      isDir: json['isDir'] as bool? ?? false,
      permissions: json['permissions'] as String? ?? '',
      modified: json['modified'] as String?,
    );
  }

  /// Convert DTO to domain model.
  FileItem toDomain(String parentPath) {
    return FileItem(
      name: name,
      path: '$parentPath/$name',
      size: size,
      isDir: isDir,
      permissions: permissions,
      modifiedTime: modified != null
          ? DateTime.tryParse(modified!) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// File permission information.
class FilePermissionDto {
  final String mode;
  final String owner;
  final String group;

  const FilePermissionDto({
    required this.mode,
    required this.owner,
    required this.group,
  });

  factory FilePermissionDto.fromJson(Map<String, dynamic> json) {
    return FilePermissionDto(
      mode: json['mode'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      group: json['group'] as String? ?? '',
    );
  }
}
