import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gear_doctor/data/app_database.dart';
import 'package:gear_doctor/data/app_repository.dart';
import 'package:gear_doctor/data/seed.dart';
import 'package:gear_doctor/domain/dates.dart';
import 'package:gear_doctor/domain/replacement_csv.dart';
import 'package:gear_doctor/models/models.dart';
import 'package:gear_doctor/state/app_store.dart';
import 'package:gear_doctor/strava/strava_oauth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('geardoctor_test');
  });

  tearDown(() async {
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  Future<AppStore> openStore() async {
    final store = AppStore(
      database: AppDatabase(overridePath: '${dir.path}/app.db'),
      now: parseDate('2026-08-23'),
    );
    await store.load();
    return store;
  }

  test('first launch seeds demo parts and display groups', () async {
    final store = await openStore();
    expect(store.parts.length, 18);
    expect(store.groups.length, 5);
    expect(store.cards.map((card) => card.title).toList(), [
      'タイヤ',
      'チェーン',
      'ブレーキパッド',
      'ワイヤー',
      'ブレーキオイル',
      'ディスク',
      'バーテープ',
      'スピードセンサ電池',
      'パワーセンサ電池',
      'リモコン電池',
      '心拍計電池',
      'リヤライト電池',
      'プーリー',
    ]);
    expect(store.selectedGear?.name, 'Aeroad');
    expect(store.usingDemoRides, isTrue);
    expect(store.partById('p_battery'), isNull);
    expect(store.partById('p_front_oil')!.cycle, CycleKind.distance);
    expect(store.usedOf(store.partById('p_speed_batt')!), 7);
  });

  test('existing installs drop battery and convert oil to distance', () async {
    final repo = AppRepository(
      await AppDatabase(overridePath: '${dir.path}/migrate.db').instance,
    );
    await seedDemoData(repo);
    await repo.upsertPart(
      const Part(
        id: 'p_battery',
        registeredName: 'バッテリー',
        cycle: CycleKind.months,
        limitMode: LimitMode.recommended,
        recommendedLimit: 24,
        customLimit: 24,
        thresholdPct: 80,
        sortOrder: 99,
      ),
    );
    final oil = (await repo.loadParts()).firstWhere((part) => part.id == 'p_front_oil');
    await repo.upsertPart(
      oil.copyWith(
        cycle: CycleKind.months,
        recommendedLimit: 24,
        customLimit: 24,
      ),
    );

    await ensureMissingDefaultParts(repo, now: parseDate('2026-08-23'));
    final parts = await repo.loadParts();
    expect(parts.any((part) => part.id == 'p_battery'), isFalse);
    final updatedOil = parts.firstWhere((part) => part.id == 'p_front_oil');
    expect(updatedOil.cycle, CycleKind.distance);
    expect(updatedOil.recommendedLimit, 10000);
  });

  test('combine and dissolve only change display', () async {
    final store = await openStore();
    await store.dissolveGroup('grp_tire');
    expect(store.cards.any((card) => card.title == '前タイヤ'), isTrue);
    expect(store.cards.any((card) => card.title == '後タイヤ'), isTrue);
    expect(store.partById('p_front_tire')!.registeredName, '前タイヤ');

    await store.combineDisplay(
      frontPartId: 'p_front_tire',
      rearPartId: 'p_rear_tire',
      displayName: 'タイヤ',
    );
    expect(store.cards.any((card) => card.title == 'タイヤ'), isTrue);
    expect(store.partById('p_front_tire')!.registeredName, '前タイヤ');
  });

  test('replacement date change recalculates usage', () async {
    final store = await openStore();
    final part = store.partById('p_chain')!;
    final before = store.usedOf(part);
    expect(before, greaterThan(0));

    await store.addReplacement(
      partId: part.id,
      replacedOn: parseDate('2026-08-23'),
      memo: '新品',
    );
    expect(store.usedOf(part), 0);
  });

  test('new part first replacement is the sync start date', () async {
    final store = await openStore();
    await store.savePart(
      Part(
        id: 'p_new',
        registeredName: '新品',
        cycle: CycleKind.distance,
        limitMode: LimitMode.recommended,
        recommendedLimit: 3000,
        customLimit: 3000,
        thresholdPct: 80,
        sortOrder: store.nextSortOrder(),
      ),
      isNew: true,
    );
    final first = store.replacementsFor('p_new').single;
    expect(formatDate(first.replacedOn), '2025-07-17');
  });

  test('Strava tokens persist on the device and survive reload', () async {
    final store = await openStore();
    expect(store.settings.stravaConnected, isFalse);
    await store.saveStravaAuth(
      StravaAuthResult(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresAt: DateTime.utc(2030, 1, 1),
        athleteId: '42',
        athleteName: 'Ken Rider',
        bikes: const [Gear(id: 'b1', name: 'Tarmac')],
      ),
    );
    expect(store.settings.stravaConnected, isTrue);
    expect(store.settings.stravaAthleteName, 'Ken Rider');
    expect(store.gears.any((gear) => gear.name == 'Tarmac'), isTrue);
    expect(store.gears.any((gear) => gear.id == 'g_aeroad'), isFalse);
    expect(store.settings.selectedGearId, 'b1');

    final again = await openStore();
    expect(again.settings.stravaAccessToken, 'access-1');
    expect(again.settings.stravaConnected, isTrue);
    await again.disconnectStrava();
    expect(again.settings.stravaConnected, isFalse);
  });

  test('resetToDemo restores seed parts, rides, and clears Strava', () async {
    final store = await openStore();
    await store.savePart(
      Part(
        id: 'p_custom',
        registeredName: 'カスタム部品',
        cycle: CycleKind.distance,
        limitMode: LimitMode.recommended,
        recommendedLimit: 3000,
        customLimit: 3000,
        thresholdPct: 80,
        sortOrder: store.nextSortOrder(),
      ),
      isNew: true,
    );
    await store.saveStravaCredentials(clientId: '123', clientSecret: 'secret');
    await store.saveStravaAuth(
      StravaAuthResult(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresAt: DateTime.utc(2030, 1, 1),
        athleteId: '42',
        athleteName: 'Ken Rider',
        bikes: const [Gear(id: 'b1', name: 'Tarmac')],
      ),
    );
    expect(store.partById('p_custom'), isNotNull);
    expect(store.settings.stravaConnected, isTrue);
    expect(store.gears.any((gear) => gear.id == 'b1'), isTrue);

    await store.resetToDemo();
    expect(store.partById('p_custom'), isNull);
    expect(store.parts.length, 18);
    expect(store.usingDemoRides, isTrue);
    expect(store.selectedGear?.name, 'Aeroad');
    expect(store.settings.stravaConnected, isFalse);
    expect(store.settings.stravaAccessToken, isNull);
    expect(store.settings.stravaClientId, isNull);
    expect(store.gears.any((gear) => gear.id == 'g_aeroad'), isTrue);
    expect(store.gears.any((gear) => gear.id == 'b1'), isFalse);
  });

  test('changing sync start deletes rides so coverage can restart', () async {
    final store = await openStore();
    expect(store.rides, isNotEmpty);
    expect(formatDate(store.newestSyncedOn!), '2026-07-15');

    await store.changeSyncStart(parseDate('2024-01-01'));
    expect(store.rides, isEmpty);
    expect(store.newestSyncedOn, isNull);
    expect(formatDate(store.settings.lastSyncFrom!), '2024-01-01');

    final again = await openStore();
    expect(again.rides, isEmpty);
    expect(formatDate(again.settings.lastSyncFrom!), '2024-01-01');
    expect(again.newestSyncedOn, isNull);
  });

  test('same start date does not delete rides', () async {
    final store = await openStore();
    final count = store.rides.length;
    await store.changeSyncStart(parseDate('2025-07-17'));
    expect(store.rides.length, count);
    expect(formatDate(store.newestSyncedOn!), '2026-07-15');
  });

  test('CSV import replaces history for parts in the file', () async {
    final store = await openStore();
    expect(
      store.replacementsFor('p_chain').map((item) => formatDate(item.replacedOn)),
      ['2025-11-12'],
    );
    final parsed = parseReplacementCsv('''
登録名,交換日,メモ
チェーン,2026-06-12,CSV
''');
    final plan = planReplacementImport(
      rows: parsed.rows,
      parts: store.parts,
    );
    expect(plan.errors, isEmpty);
    final result = await store.importReplacementPlan(plan);
    expect(result.added, 1);
    expect(result.skippedDuplicates, 0);
    expect(
      store.replacementsFor('p_chain').map((item) => formatDate(item.replacedOn)).toList(),
      ['2026-06-12'],
    );
    expect(
      store.replacementsFor('p_front_tire').any(
            (item) => formatDate(item.replacedOn) == '2023-04-02',
          ),
      isTrue,
    );
  });

  test('syncForward stores bike rides and advances fetched-through', () async {
    final store = await openStore();
    await store.saveStravaAuth(
      StravaAuthResult(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        expiresAt: DateTime.utc(2030, 1, 1),
        athleteId: '42',
        athleteName: 'Ken Rider',
        bikes: const [Gear(id: 'b1', name: 'Tarmac')],
      ),
    );

    var activityCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v3/athlete') {
        return http.Response(
          '{"id":42,"bikes":[{"id":"b1","name":"Tarmac"}]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v3/athlete/activities') {
        activityCalls += 1;
        expect(request.headers['Authorization'], 'Bearer access-1');
        if (activityCalls == 1) {
          return http.Response(
            jsonEncode([
              {
                'id': 99,
                'sport_type': 'Ride',
                'distance': 15000,
                'start_date': '2025-08-01T08:00:00Z',
                'gear_id': 'b1',
              },
              {
                'id': 100,
                'sport_type': 'Run',
                'distance': 5000,
                'start_date': '2025-08-02T08:00:00Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      fail('unexpected ${request.method} ${request.url}');
    });

    final first = await store.syncForward(months: 1, client: client);
    expect(formatDate(first.from), '2025-07-17');
    expect(formatDate(first.to), '2025-08-17');
    expect(first.savedCount, 1);
    expect(formatDate(first.newestRideOn!), '2025-08-01');
    expect(store.rides.single.id, '99');
    expect(store.rides.single.distanceKm, 15);
    expect(formatDate(store.settings.lastSyncAt!), '2025-08-17');
    expect(store.rides.any((ride) => ride.id.startsWith('ride_')), isFalse);
    expect(store.usingDemoRides, isFalse);

    final second = await store.syncForward(months: 1, client: client);
    expect(formatDate(second.from), '2025-08-17');
    expect(formatDate(second.to), '2025-09-17');
    expect(second.savedCount, 0);
    expect(formatDate(store.settings.lastSyncAt!), '2025-09-17');
    expect(formatDate(store.newestSyncedOn!), '2025-08-01');
  });
}
