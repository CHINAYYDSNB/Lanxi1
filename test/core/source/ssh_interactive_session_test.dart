// ignore_for_file: require_trailing_commas

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/ssh_interactive_session.dart';

/// Captures everything written to the remote stdin.
class _CaptureSink implements StreamSink<Uint8List> {
  final List<Uint8List> written;
  _CaptureSink(this.written);

  @override
  void add(Uint8List data) => written.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<Uint8List> stream) async {
    await for (final c in stream) {
      written.add(c);
    }
  }

  @override
  Future close() async {}

  @override
  Future get done => Future.value();
}

class _FakeSSHSession extends Fake implements SSHSession {
  final StreamController<Uint8List> _out = StreamController<Uint8List>.broadcast();
  final List<Uint8List> written = [];
  final List<List<int>> resizes = [];
  bool closed = false;

  @override
  Stream<Uint8List> get stdout => _out.stream;

  @override
  StreamSink<Uint8List> get stdin => _CaptureSink(written);

  @override
  void resizeTerminal(int width, int height, [int pixelWidth = 0, int pixelHeight = 0]) =>
      resizes.add([width, height]);

  @override
  void close() => closed = true;
}

void main() {
  group('SshInteractiveSession', () {
    late _FakeSSHSession fake;
    late SshInteractiveSession session;

    setUp(() {
      fake = _FakeSSHSession();
      session = SshInteractiveSession(fake);
    });

    test('output decodes remote stdout', () async {
      final received = <String>[];
      final sub = session.output.listen(received.add);
      fake._out.add(Uint8List.fromList(utf8.encode('hello\n')));
      await Future<void>.delayed(Duration.zero);
      expect(received, ['hello\n']);
      await sub.cancel();
    });

    test('write forwards bytes to stdin', () {
      session.write('ls\n');
      expect(fake.written, [Uint8List.fromList(utf8.encode('ls\n'))]);
    });

    test('resize forwards to resizeTerminal', () {
      session.resize(width: 120, height: 40);
      expect(fake.resizes, [
        [120, 40],
      ]);
    });

    test('close closes the underlying session', () {
      session.close();
      expect(fake.closed, isTrue);
    });
  });
}
