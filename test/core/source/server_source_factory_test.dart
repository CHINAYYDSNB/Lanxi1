import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/server_source_factory.dart';
import 'package:lanxi/core/source/ssh_server_source.dart';

void main() {
  group('ServerSourceFactory', () {
    group('buildSsh', () {
      test('returns SshServerSource for SSH profile', () {
        final profile = ServerProfile(
          host: '192.168.1.1',
          username: 'root',
        );

        final source = ServerSourceFactory.buildSsh(profile);

        expect(source, isA<SshServerSource>());
      });
    });

    group('build', () {
      test('builds SSH source when no apiKey', () {
        final profile = ServerProfile(
          host: '10.0.0.1',
          username: 'admin',
        );

        final source = ServerSourceFactory.build(profile);

        expect(source, isA<SshServerSource>());
      });

      test('throws UnimplementedError when apiKey is present', () {
        final profile = ServerProfile(
          host: '10.0.0.1',
          username: 'admin',
          apiKey: 'some-api-key',
        );

        expect(
          () => ServerSourceFactory.build(profile),
          throwsUnimplementedError,
        );
      });
    });

    group('ServerProfile', () {
      test('defaults port to 22', () {
        final profile = ServerProfile(host: 'x.com', username: 'u');
        expect(profile.port, 22);
      });

      test('stores all fields', () {
        final profile = ServerProfile(
          host: 'x.com',
          port: 2222,
          username: 'u',
          password: 'p',
          sshKey: 'key',
          apiKey: 'api',
        );
        expect(profile.host, 'x.com');
        expect(profile.port, 2222);
        expect(profile.username, 'u');
        expect(profile.password, 'p');
        expect(profile.sshKey, 'key');
        expect(profile.apiKey, 'api');
      });
    });
  });
}
