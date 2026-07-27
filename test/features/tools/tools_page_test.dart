// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/features/tools/tools_page.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockService extends Mock implements ServerService {}

void main() {
  group('ToolsPage', () {
    late _MockService service;

    setUp(() => service = _MockService());

    testWidgets('NTP apply calls service.setNtp', (tester) async {
      when(() => service.setNtp(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ToolsPage(service: service))),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'NTP 服务器'),
        'time.example.com',
      );
      await tester.tap(find.widgetWithText(FilledButton, '应用'));
      await tester.pumpAndSettle();

      verify(() => service.setNtp('time.example.com')).called(1);
    });

    testWidgets('password change calls service.changeRootPassword',
        (tester) async {
      when(() => service.changeRootPassword(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ToolsPage(service: service))),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '新密码'),
        'new-secret',
      );
      await tester.tap(find.widgetWithText(FilledButton, '修改'));
      await tester.pumpAndSettle();

      verify(() => service.changeRootPassword('new-secret')).called(1);
    });
  });
}
