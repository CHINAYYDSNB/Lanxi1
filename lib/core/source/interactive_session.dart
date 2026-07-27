/// Transport-agnostic interactive terminal session.
///
/// Decouples the UI from any specific transport (SSH/dartssh2). The SSH
/// implementation lives in [SshInteractiveSession]; panel sources have no
/// shell and throw [PanelFallbackException] so callers can fall back to SSH.
abstract class InteractiveSession {
  /// Decoded remote output stream (UTF-8).
  Stream<String> get output;

  /// Write raw data to the remote process's stdin.
  ///
  /// Callers are responsible for appending a newline (`\n`) when needed.
  void write(String data);

  /// Notify the remote pty of the current window size.
  Future<void> resize({required int width, required int height});

  /// Close the session and release resources.
  Future<void> close();
}
