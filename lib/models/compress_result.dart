/// Result of a compression operation on the remote server.
class CompressResult {
  final String destPath;
  final int size; // bytes
  final int durationMs;
  final bool success;
  final String? errorMessage;

  const CompressResult({
    required this.destPath,
    required this.size,
    required this.durationMs,
    required this.success,
    this.errorMessage,
  });

  factory CompressResult.fromJson(Map<String, dynamic> json) {
    return CompressResult(
      destPath: json['destPath'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      success: json['success'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'destPath': destPath,
        'size': size,
        'durationMs': durationMs,
        'success': success,
        'errorMessage': errorMessage,
      };
}

/// Supported archive formats for [ServerSource.compress].
///
/// `apiType` matches the 1Panel V2 `type` field.
enum CompressFormat {
  zip('zip'),
  tarGz('tar.gz');

  final String apiType;
  const CompressFormat(this.apiType);
}
