// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/panel_detector.dart';
import 'package:lanxi/features/terminal/terminal_page.dart';
import 'package:lanxi/features/tools/tools_page.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockService extends Mock implements ServerService {}

void main() {
  group('Install 1Panel card', () {
    late _MockService service;

    setUp(() => service = _MockService());

    testWidgets('offers install when no panel detected', (tester) async {
      when(() => service.detectPanel())
          .thenAnswer((_) async => PanelStatus.none);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ToolsPage(service: service))),
      );
      await tester.pumpAndSettle();

      expect(find.text('安装 1Panel'), findsOneWidget);
    });

    testWidgets('shows detected panel status', (tester) async {
      when(() => service.detectPanel())
          .thenAnswer((_) async => PanelStatus.onePanel);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ToolsPage(service: service))),
      );
      await tester.pumpAndSettle();

      expect(find.text('已检测到 1Panel'), findsOneWidget);
    });

    testWidgets('tapping install opens the terminal page', (tester) async {
      when(() => service.detectPanel())
          .thenAnswer((_) async => PanelStatus.none);
      when(() => service.streamCommand(any()))
          .thenAnswer((_) => Stream.value(''));

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ToolsPage(service: service))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('安装 1Panel'));
      await tester.pumpAndSettle();

      expect(find.byType(TerminalPage), findsOneWidget);
    });
  });
}
