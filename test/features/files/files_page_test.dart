// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/features/files/file_editor_page.dart';
import 'package:lanxi/features/files/files_page.dart';
import 'package:lanxi/models/domain/file_item.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSource extends Mock implements ServerSource {}

FileItem _file(String name, {bool isDir = false}) => FileItem(
      name: name,
      path: '/$name',
      size: 1,
      isDir: isDir,
      permissions: '644',
      modifiedTime: DateTime.now(),
    );

void main() {
  late _MockSource mockSource;
  late ServerService service;

  setUp(() {
    mockSource = _MockSource();
    service = ServerService(mockSource);
    when(() => mockSource.listDir(any())).thenAnswer(
      (_) async => [_file('a.txt'), _file('docs', isDir: true)],
    );
    when(() => mockSource.readFile(any())).thenAnswer((_) async => 'hello');
    when(() => mockSource.writeFile(any(), any())).thenAnswer((_) async {});
    when(() => mockSource.deleteFile(any(), isDir: any(named: 'isDir')))
        .thenAnswer((_) async {});
    when(() => mockSource.renameFile(any(), any())).thenAnswer((_) async {});
    when(() => mockSource.createFile(
          any(),
          isDir: any(named: 'isDir'),
          content: any(named: 'content'),
        )).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: FilesPage(service: service)));
    await tester.pumpAndSettle();
  }

  testWidgets('lists directory entries', (tester) async {
    await pumpPage(tester);

    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('docs'), findsOneWidget);
  });

  testWidgets('shows error when listDir fails', (tester) async {
    when(() => mockSource.listDir(any())).thenThrow(Exception('no'));
    await tester.pumpWidget(MaterialApp(home: FilesPage(service: service)));
    await tester.pumpAndSettle();

    expect(find.textContaining('加载失败'), findsOneWidget);
  });

  testWidgets('tapping a file opens the editor and loads content',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();

    expect(find.byType(FileEditorPage), findsOneWidget);
    verify(() => mockSource.readFile('/a.txt')).called(1);
  });

  testWidgets('editor saves modified content', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'updated');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    verify(() => mockSource.writeFile('/a.txt', 'updated')).called(1);
  });

  testWidgets('editor shows error when read fails', (tester) async {
    when(() => mockSource.readFile(any())).thenThrow(Exception('boom'));
    await pumpPage(tester);
    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
  });

  testWidgets('long-press shows the action sheet', (tester) async {
    await pumpPage(tester);

    await tester.longPress(find.text('a.txt'));
    await tester.pumpAndSettle();

    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('属性'), findsOneWidget);
  });

  testWidgets('properties sheet shows file info', (tester) async {
    await pumpPage(tester);
    await tester.longPress(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('属性'));
    await tester.pumpAndSettle();

    expect(find.text('路径'), findsOneWidget);
    expect(find.text('权限'), findsOneWidget);
  });

  testWidgets('rename via long-press', (tester) async {
    await pumpPage(tester);
    await tester.longPress(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'b.txt');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    verify(() => mockSource.renameFile('/a.txt', '/b.txt')).called(1);
  });

  testWidgets('delete via long-press', (tester) async {
    await pumpPage(tester);
    await tester.longPress(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    verify(() => mockSource.deleteFile('/a.txt', isDir: false)).called(1);
  });

  testWidgets('FAB opens the create menu', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('新建文件'), findsOneWidget);
    expect(find.text('新建文件夹'), findsOneWidget);
  });

  testWidgets('create file via FAB', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建文件'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'new.txt');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    verify(() => mockSource.createFile(
          '/root/new.txt',
          isDir: false,
          content: any(named: 'content'),
        )).called(1);
  });
}
