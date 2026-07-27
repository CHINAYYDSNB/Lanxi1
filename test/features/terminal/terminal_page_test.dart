// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/features/terminal/terminal_page.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockService extends Mock implements ServerService {}

void main() {
  group('TerminalPage', () {
    late _MockService service;

    setUp(() => service = _MockService());

    testWidgets('streams output and shows completion', (tester) async {
      when(() => service.streamCommand(any())).thenAnswer(
        (_) => Stream.fromIterable(['line1\n', 'line2\n']),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalPage(
            service: service,
            command: 'echo hi',
            title: '安装 1Panel',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('line1\n'), findsOneWidget);
      expect(find.text('line2\n'), findsOneWidget);
      expect(find.text('执行完成'), findsOneWidget);
      verify(() => service.streamCommand('echo hi')).called(1);
    });
  });
}
