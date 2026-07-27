import 'dart:async';

import 'package:lanxi/core/source/interactive_session.dart';

/// Controllable [InteractiveSession] for widget/integration tests.
///
/// Tests drive it via [emit] / inspect [written] / [resizes] / [closed].
class FakeInteractiveSession implements InteractiveSession {
  final StreamController<String> _out = StreamController<String>.broadcast();
  final List<String> written = [];
  final List<List<int>> resizes = [];
  bool closed = false;

  @override
  Stream<String> get output => _out.stream;

  @override
  void write(String data) => written.add(data);

  @override
  Future<void> resize({required int width, required int height}) async {
    resizes.add([width, height]);
  }

  @override
  Future<void> close() async => closed = true;

  /// Push a chunk into the output stream.
  void emit(String chunk) => _out.add(chunk);
}
