// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/features/terminal/terminal_page.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_interactive_session.dart';

class _MockService extends Mock implements ServerService {}

void main() {
  group('TerminalPage', () {
    late _MockService service;

    setUp(() => service = _MockService());

    testWidgets('opens shell, shows output, and sends input', (tester) async {
      final fake = FakeInteractiveSession();
      when(() => service.openShell()).thenAnswer((_) async => fake);

      await tester.pumpWidget(
        MaterialApp(home: TerminalPage(service: service, title: '终端')),
      );
      await tester.pumpAndSettle();

      // Remote output is rendered in the terminal view.
      fake.emit('hello');
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);

      // Typing + send forwards the command to the session.
      await tester.enterText(find.byType(TextField), 'ls');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(fake.written, contains('ls\n'));

      verify(() => service.openShell()).called(1);
    });

    testWidgets('writes preset command on open', (tester) async {
      final fake = FakeInteractiveSession();
      when(() => service.openShell()).thenAnswer((_) async => fake);

      await tester.pumpWidget(
        MaterialApp(
          home: TerminalPage(
            service: service,
            command: 'bash installer.sh',
            title: '安装 1Panel',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fake.written, contains('bash installer.sh\n'));
    });

    testWidgets('unmounting closes the session', (tester) async {
      final fake = FakeInteractiveSession();
      when(() => service.openShell()).thenAnswer((_) async => fake);

      await tester.pumpWidget(
        MaterialApp(home: TerminalPage(service: service, title: '终端')),
      );
      await tester.pumpAndSettle();

      // Replacing the widget tree disposes TerminalPage → session.close().
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      expect(fake.closed, isTrue);
    });
  });
}
