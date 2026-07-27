/// Thrown when 1Panel API fails, indicating fallback to SSH is needed.
class PanelFallbackException implements Exception {
  final String message;
  final int? statusCode;
  final Object? originalError;

  const PanelFallbackException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'PanelFallbackException($statusCode): $message';
}

/// Thrown when SSH connection fails and no fallback is available.
class SshConnectionException implements Exception {
  final String message;
  final String? host;

  const SshConnectionException(this.message, {this.host});

  @override
  String toString() => 'SshConnectionException($host): $message';
}
