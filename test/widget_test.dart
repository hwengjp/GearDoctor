import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gear_doctor/data/app_database.dart';
import 'package:gear_doctor/domain/dates.dart';
import 'package:gear_doctor/screens/home_screen.dart';
import 'package:gear_doctor/screens/part_detail_screen.dart';
import 'package:gear_doctor/screens/settings_screen.dart';
import 'package:gear_doctor/state/app_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('geardoctor_widget');
  });

  tearDown(() async {
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  testWidgets('home shows grouped tires and the sync button', (tester) async {
    final store = AppStore(
      database: AppDatabase(overridePath: '${dir.path}/app.db'),
      now: parseDate('2026-08-23'),
    );
    await tester.runAsync(store.load);

    await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));

    expect(find.text('GearDoctor'), findsOneWidget);
    expect(
      find.textContaining('デモを解除するには Strava を同期します'),
      findsOneWidget,
    );
    expect(find.text('タイヤ'), findsOneWidget);
    expect(find.text('チェーン'), findsOneWidget);
    expect(find.text('Strava同期'), findsOneWidget);
    expect(find.textContaining('ギア: Aeroad（デモ）'), findsOneWidget);
    expect(
      find.textContaining('最終同期 2025-07-17〜2026-07-15（デモ）'),
      findsOneWidget,
    );

    await tester.tap(find.text('Strava同期'));
    await tester.pumpAndSettle();
    expect(find.textContaining('開始日  2025-07-17（デモ）'), findsOneWidget);
    expect(find.textContaining('何日まで  2026-07-15（デモ）'), findsOneWidget);

    await tester.tap(find.text('開始日を変更'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('part detail shows replacement history under the replace button', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore(
      database: AppDatabase(overridePath: '${dir.path}/app.db'),
      now: parseDate('2026-08-23'),
    );
    await tester.runAsync(store.load);

    await tester.pumpWidget(
      MaterialApp(home: PartDetailScreen(store: store, partId: 'p_chain')),
    );
    await tester.pumpAndSettle();
    expect(find.text('交換した'), findsOneWidget);
    expect(find.text('過去の交換記録'), findsOneWidget);
    expect(find.text('ギアの走行距離'), findsOneWidget);
    expect(find.text('交換日'), findsOneWidget);
    expect(find.text('コメント'), findsOneWidget);
    expect(find.text('2025-11-12'), findsOneWidget);
    expect(find.text('960km（デモ）'), findsOneWidget);
    expect(find.text('3,840km（デモ）（今日）'), findsOneWidget);
  });

  testWidgets('settings reset shows a confirmation dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore(
      database: AppDatabase(overridePath: '${dir.path}/app.db'),
      now: parseDate('2026-08-23'),
    );
    await tester.runAsync(store.load);

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('初期状態に戻す'));
    await tester.pumpAndSettle();
    expect(find.text('初期状態に戻しますか？'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(store.parts.length, 18);
  });

  testWidgets('settings opens a dedicated Strava connect screen', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore(
      database: AppDatabase(overridePath: '${dir.path}/app.db'),
      now: parseDate('2026-08-23'),
    );
    await tester.runAsync(store.load);

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strava 連携'));
    await tester.pumpAndSettle();
    expect(find.text('連携を解除'), findsOneWidget);
    expect(find.text('連携方法'), findsOneWidget);
    expect(find.textContaining('Authorization Callback Domain は 127.0.0.1'), findsOneWidget);
    expect(find.textContaining('このアプリでは Access Token は使いません'), findsOneWidget);
    expect(find.textContaining('「連携する」を押したあとに出る欄'), findsOneWidget);
  });
}
