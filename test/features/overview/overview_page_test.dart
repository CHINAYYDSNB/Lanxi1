// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/server_source.dart';
import 'package:lanxi/features/overview/overview_page.dart';
import 'package:lanxi/models/domain/system_stats.dart';
import 'package:lanxi/services/server_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSource extends Mock implements ServerSource {}

SystemStats _snapshot() => SystemStats(
      cpuPercent: 42.0,
      memTotalMb: 8192,
      memUsedMb: 4096,
      disks: const [
        DiskInfo(path: '/', totalMb: 100000, usedMb: 50000),
      ],
      diskTotalMb: 100000,
      diskUsedMb: 50000,
      loadAvg: 1.5,
      source: SystemStatsSource.ssh,
    );

void main() {
  late _MockSource mockSource;
  late ServerService service;

  setUp(() {
    mockSource = _MockSource();
    service = ServerService(mockSource);
    when(() => mockSource.watchHostStats())
        .thenAnswer((_) => Stream.value(_snapshot()));
    when(() => mockSource.getSystemInfo())
        .thenAnswer((_) async => _snapshot());
  });

  testWidgets('renders live CPU/memory/disk from the stream', (tester) async {
    await tester.pumpWidget(MaterialApp(home: OverviewPage(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('内存'), findsOneWidget);
    expect(find.text('磁盘'), findsOneWidget);
    expect(find.text('42.0%'), findsOneWidget);
    verify(() => mockSource.watchHostStats()).called(1);
  });

  testWidgets('shows error UI when the stream fails with no snapshot',
      (tester) async {
    when(() => mockSource.watchHostStats())
        .thenAnswer((_) => Stream.error(Exception('boom')));
    when(() => mockSource.getSystemInfo()).thenThrow(Exception('boom'));

    await tester.pumpWidget(MaterialApp(home: OverviewPage(service: service)));
    await tester.pumpAndSettle();

    expect(find.textContaining('获取系统信息失败'), findsOneWidget);
  });
}
