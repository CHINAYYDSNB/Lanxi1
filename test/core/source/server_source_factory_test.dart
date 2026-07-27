import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/exceptions.dart';
import 'package:lanxi/core/source/server_source_factory.dart';
import 'package:lanxi/core/source/ssh_server_source.dart';

void main() {
  group('ServerSourceFactory', () {
    group('buildSsh', () {
      test('returns SshServerSource for SSH profile', () {
        const profile = ServerProfile(
          id: 'p1',
          name: 'srv',
          type: ServerSourceType.ssh,
          host: '192.168.1.1',
          username: 'root',
        );

        final source = ServerSourceFactory.buildSsh(profile);

        expect(source, isA<SshServerSource>());
      });
    });

    group('build', () {
      test('builds SSH source when no apiKey', () {
        const profile = ServerProfile(
          id: 'p2',
          name: 'srv',
          type: ServerSourceType.ssh,
          host: '10.0.0.1',
          username: 'admin',
        );

        final source = ServerSourceFactory.build(profile);

        expect(source, isA<SshServerSource>());
      });

      test('throws PlatformNotSupportedException when apiKey is present', () {
        const profile = ServerProfile(
          id: 'p3',
          name: 'srv',
          type: ServerSourceType.panel,
          host: '10.0.0.1',
          username: 'admin',
          apiKey: 'some-api-key',
        );

        expect(
          () => ServerSourceFactory.build(profile),
          throwsA(isA<PlatformNotSupportedException>()),
        );
      });
    });

    group('ServerProfile', () {
      test('defaults port to 22', () {
        const profile = ServerProfile(
          id: 'p4',
          name: 'srv',
          type: ServerSourceType.ssh,
          host: 'x.com',
          username: 'u',
        );
        expect(profile.port, 22);
      });

      test('stores all fields', () {
        const profile = ServerProfile(
          id: 'p5',
          name: 'srv',
          type: ServerSourceType.ssh,
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
