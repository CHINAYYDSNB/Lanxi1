/// Exceptions used throughout the server-source layer.
library;

/// Thrown when a 1Panel API call fails and the caller should fall back to SSH.
class PanelFallbackException implements Exception {
  final String message;
  final Object? original;
  final String endpoint;

  const PanelFallbackException(
    this.message, {
    this.original,
    this.endpoint = '',
  });

  @override
  String toString() => 'PanelFallbackException: $message (endpoint: $endpoint)';
}
