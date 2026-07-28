// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/features/docker/container_detail_page.dart';
import 'package:lanxi/features/docker/container_log_page.dart';
import 'package:lanxi/features/docker/docker_page.dart';
import 'package:lanxi/models/dto/container_dto.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSource extends Mock implements ServerSource {}

ContainerDomain _container(String state) => ContainerDomain(
      id: 'abc',
      name: 'web',
      image: 'nginx:latest',
      status: 'Up',
      state: state,
      ports: const ['0.0.0.0:8080->80/tcp'],
    );

void main() {
  late _MockSource mockSource;
  late ServerService service;

  setUp(() {
    mockSource = _MockSource();
    service = ServerService(mockSource);
    when(() => mockSource.listContainers())
        .thenAnswer((_) async => [_container('running')]);
    when(() => mockSource.startContainer(any())).thenAnswer((_) async {});
    when(() => mockSource.stopContainer(any())).thenAnswer((_) async {});
    when(() => mockSource.restartContainer(any())).thenAnswer((_) async {});
    when(() => mockSource.pauseContainer(any())).thenAnswer((_) async {});
    when(() => mockSource.unpauseContainer(any())).thenAnswer((_) async {});
    when(() => mockSource.removeContainer(any(), force: any(named: 'force')))
        .thenAnswer((_) async {});
    when(() => mockSource.inspectContainer(any()))
        .thenAnswer((_) async => ContainerInspect({}));
    when(() => mockSource.containerLogs(any(),
            tail: any(named: 'tail'), follow: any(named: 'follow')))
        .thenAnswer((_) => Stream.value('line1\nline2\n'));
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: DockerPage(service: service)));
    await tester.pumpAndSettle();
  }

  testWidgets('lists containers with name and state label', (tester) async {
    await pumpPage(tester);

    expect(find.text('web'), findsWidgets);
    expect(find.text('运行中'), findsOneWidget);
    expect(find.text('0.0.0.0:8080->80/tcp'), findsOneWidget);
  });

  testWidgets('shows error when listContainers fails', (tester) async {
    when(() => mockSource.listContainers()).thenThrow(Exception('no'));
    await tester.pumpWidget(MaterialApp(home: DockerPage(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
  });

  testWidgets('stop action calls stopContainer and reloads', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停止'));
    await tester.pumpAndSettle();

    verify(() => mockSource.stopContainer('web')).called(1);
    verify(() => mockSource.listContainers()).called(2);
  });

  testWidgets('tapping a container opens the detail page', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('web').first);
    await tester.pumpAndSettle();

    expect(find.byType(ContainerDetailPage), findsOneWidget);
    verify(() => mockSource.inspectContainer('web')).called(1);
  });

  testWidgets('log action opens the log page and streams lines',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日志'));
    await tester.pumpAndSettle();

    expect(find.byType(ContainerLogPage), findsOneWidget);
    expect(find.text('line1'), findsOneWidget);
    verify(() => mockSource.containerLogs(
          'web',
          tail: any(named: 'tail'),
          follow: any(named: 'follow'),
        )).called(1);
  });
}
