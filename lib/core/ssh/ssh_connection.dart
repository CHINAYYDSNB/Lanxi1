/// SSH connection abstraction over dartssh2.
library;

/// Credentials for an SSH connection.
class SshCredentials {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey; // PEM-encoded private key string
  final String? privateKeyPath; // path to private key file

  const SshCredentials({
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
    this.privateKeyPath,
  });

  /// Unique key for connection pooling (host:port:username).
  /// Does NOT include the credential secret so the pool can match
  /// pre-warmed connections without comparing passwords.
  String get poolKey => '$host:$port:$username';
}

/// Low-level SSH operations.
abstract class SshConnection {
  /// Connect to the remote host.
  Future<void> connect();

  /// Execute a command and return stdout as a string.
  Future<String> exec(String command);

  /// Execute a command and stream stdout line by line.
  Stream<String> execStream(String command);

  /// Execute a command capturing both stdout and stderr.
  Future<SshExecResult> execWithStderr(String command);

  /// Close the underlying SSH session and socket.
  Future<void> disconnect();

  /// Whether the underlying socket is connected.
  bool get isConnected;
}

/// Result of an SSH command execution.
class SshExecResult {
  final String stdout;
  final String stderr;
  final int exitCode;

  const SshExecResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
}
