/// Lanxi logger — logs to developer console, never stdout.
///
/// Supports four levels: [d] (debug), [i] (info), [w] (warning), [e] (error).
///
/// Auto-redacts sensitive fields:
///   - IP addresses: replaces middle octets with `*`
///   - Passwords/tokens: replaces entire value with `[REDACTED]`
library;

import 'dart:developer' as developer;

final AppLogger appLogger = AppLogger._();

/// Log levels ordered by severity.
enum LogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger._();

  void d(String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.debug, message, error, stack);

  void i(String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.info, message, error, stack);

  void w(String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.warning, message, error, stack);

  void e(String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.error, message, error, stack);

  void _log(LogLevel level, String message, Object? error, StackTrace? stack) {
    final sanitized = _sanitize(message);
    final prefix = _prefix(level);
    final full = '$prefix $sanitized';
    if (error != null || stack != null) {
      developer.log(
        full,
        error: error,
        stackTrace: stack,
      );
    } else {
      developer.log(full);
    }
  }

  String _prefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '[D]';
      case LogLevel.info:
        return '[I]';
      case LogLevel.warning:
        return '[W]';
      case LogLevel.error:
        return '[E]';
    }
  }

  /// Redacts IP addresses and credential fields.
  static String _sanitize(String raw) {
    // Redact password-like fields: `password=abc123` → `password=[REDACTED]`
    var result = raw.replaceAllMapped(
      RegExp(r'(?<=password[\s]*[=:][\s]*)\S+', caseSensitive: false),
      (_) => '[REDACTED]',
    );
    result = result.replaceAllMapped(
      RegExp(r'(?<=token[\s]*[=:][\s]*)\S+', caseSensitive: false),
      (_) => '[REDACTED]',
    );
    result = result.replaceAllMapped(
      RegExp(r'(?<=secret[\s]*[=:][\s]*)\S+', caseSensitive: false),
      (_) => '[REDACTED]',
    );
    result = result.replaceAllMapped(
      RegExp(r'(?<=passwd[\s]*[=:][\s]*)\S+', caseSensitive: false),
      (_) => '[REDACTED]',
    );

    // Redact IP middle octets: 192.168.1.100 → 192.*.*.100
    result = result.replaceAllMapped(
      RegExp(
        r'\b(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\b',
      ),
      (m) => '${m[1]}.*.*.${m[4]}',
    );

    return result;
  }
}
