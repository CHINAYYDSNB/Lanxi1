import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/ssh/ssh_session_pool.dart';

void main() {
  late SshSessionPool pool;

  setUp(() {
    pool = SshSessionPool();
  });

  tearDown(() async {
    await pool.releaseAll();
  });

  group('SshSessionPool singleton', () {
    test('returns the same instance', () {
      final pool2 = SshSessionPool();
      expect(pool, same(pool2));
    });
  });

  group('connect/releaseIdle', () {
    test('releaseIdle does nothing when pool is empty', () {
      expect(() => pool.releaseIdle(), returnsNormally);
    });

    test('releaseAll does nothing when pool is empty', () async {
      await expectLater(pool.releaseAll(), completes);
    });
  });

  group('pause/resume', () {
    test('pause does nothing for unknown key', () {
      expect(() => pool.pause('unknown'), returnsNormally);
    });

    test('resume does nothing for unknown key', () {
      expect(() => pool.resume('unknown', 'uptime'), returnsNormally);
    });
  });

  group('watch', () {
    test('watch yields no events for unknown key', () async {
      final stream = pool.watch('nobody', 'uptime');
      // Just verify the stream completes without emitting
      await expectLater(stream, emitsDone);
    });
  });
}
