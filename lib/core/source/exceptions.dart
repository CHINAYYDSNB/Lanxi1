/// Base class for all Lanxi domain exceptions.
abstract class LanxiException implements Exception {
  final String message;
  final Object? original;

  const LanxiException(this.message, {this.original});

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown by OnePanelAdapter when API fails → triggers SSH fallback.
class PanelFallbackException extends LanxiException {
  const PanelFallbackException(super.message, {super.original, this.statusCode});

  final int? statusCode;
}

/// Thrown when SSH session not yet established.
class SshNotConnectedException extends LanxiException {
  const SshNotConnectedException()
      : super(
          'SSH connection not yet established. Use SshSessionPool.connect() first.',
        );
}

/// Thrown on SSH permission/port errors (errno=1 etc.).
class SshPermissionException extends LanxiException {
  const SshPermissionException(super.message, {super.original});
}

/// Thrown when operation not supported on current platform (e.g. Web SSH).
class PlatformNotSupportedException extends LanxiException {
  const PlatformNotSupportedException(super.message);
}

/// Thrown when SSH connection fails and no fallback is available.
class SshConnectionException extends LanxiException {
  final String? host;

  const SshConnectionException(super.message, {this.host, super.original});

  @override
  String toString() => 'SshConnectionException($host): $message';
}
