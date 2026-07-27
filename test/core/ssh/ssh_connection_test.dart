import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/ssh/ssh_connection.dart';

void main() {
  group('SshCredentials', () {
    test('poolKey uses host:port:username format', () {
      const creds = SshCredentials(
        host: '192.168.1.100',
        port: 2222,
        username: 'root',
      );
      expect(creds.poolKey, '192.168.1.100:2222:root');
    });

    test('poolKey defaults port to 22', () {
      const creds = SshCredentials(
        host: 'server.example.com',
        username: 'admin',
      );
      expect(creds.poolKey, 'server.example.com:22:admin');
    });

    test('poolKey does not include password', () {
      const creds = SshCredentials(
        host: '10.0.0.1',
        username: 'user',
        password: 'secret123',
      );
      expect(creds.poolKey, contains('10.0.0.1'));
      expect(creds.poolKey, isNot(contains('secret123')));
    });

    test('poolKey does not include privateKey', () {
      const creds = SshCredentials(
        host: '10.0.0.2',
        username: 'user',
        privateKey:
            '-----BEGIN RSA PRIVATE KEY-----\nABCD\n-----END RSA PRIVATE KEY-----',
      );
      expect(creds.poolKey, isNot(contains('PRIVATE KEY')));
      expect(creds.poolKey, '10.0.0.2:22:user');
    });
  });

  group('SshExecResult', () {
    test('stores stdout, stderr, and exitCode', () {
      const result = SshExecResult(
        stdout: 'hello',
        stderr: '',
        exitCode: 0,
      );
      expect(result.stdout, 'hello');
      expect(result.stderr, '');
      expect(result.exitCode, 0);
    });

    test('stores non-zero exit code', () {
      const result = SshExecResult(
        stdout: '',
        stderr: 'command not found',
        exitCode: 127,
      );
      expect(result.exitCode, 127);
      expect(result.stderr, 'command not found');
    });
  });
}
