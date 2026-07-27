/// Represents a file or directory entry on the remote server.
class FileItem {
  final String name;
  final String path;
  final int size; // bytes
  final bool isDir;
  final String permissions; // e.g. "rwxr-xr-x"
  final DateTime modifiedTime;

  const FileItem({
    required this.name,
    required this.path,
    required this.size,
    required this.isDir,
    required this.permissions,
    required this.modifiedTime,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      isDir: json['isDir'] as bool? ?? false,
      permissions: json['permissions'] as String? ?? '',
      modifiedTime: json['modifiedTime'] != null
          ? DateTime.parse(json['modifiedTime'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'size': size,
        'isDir': isDir,
        'permissions': permissions,
        'modifiedTime': modifiedTime.toIso8601String(),
      };

  /// Human-readable file size.
  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Common file magic number constants.
abstract final class MagicNumbers {
  static const List<int> png = [0x89, 0x50, 0x4E, 0x47];
  static const List<int> jpeg = [0xFF, 0xD8, 0xFF];
  static const List<int> pdf = [0x25, 0x50, 0x44, 0x46];
  static const List<int> zip = [0x50, 0x4B, 0x03, 0x04];
  static const List<int> gzip = [0x1F, 0x8B];
  static const List<int> tar = [0x75, 0x73, 0x74, 0x61, 0x72]; // "ustar"
}
