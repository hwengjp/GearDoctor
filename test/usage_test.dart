import 'package:flutter_test/flutter_test.dart';
import 'package:gear_doctor/domain/dates.dart';
import 'package:gear_doctor/domain/recommendations.dart';
import 'package:gear_doctor/domain/usage.dart';
import 'package:gear_doctor/models/models.dart';
import 'package:gear_doctor/widgets/widgets.dart';

void main() {
  test('monthsBetween counts calendar months', () {
    expect(monthsBetween(parseDate('2024-12-23'), parseDate('2026-08-23')), 20);
  });

  test('addCalendarMonths steps by calendar month', () {
    expect(
      formatDate(addCalendarMonths(parseDate('2026-08-23'), -1)),
      '2026-07-23',
    );
    expect(
      formatDate(addCalendarMonths(parseDate('2026-08-23'), -12)),
      '2025-08-23',
    );
  });

  test('rideKm sums selected gear in the date window', () {
    const gear = 'g1';
    final rides = [
      Ride(
        id: '1',
        gearId: gear,
        startedOn: parseDate('2025-03-01'),
        distanceKm: 100,
      ),
      Ride(
        id: '2',
        gearId: gear,
        startedOn: parseDate('2025-08-01'),
        distanceKm: 50,
      ),
      Ride(
        id: '3',
        gearId: 'other',
        startedOn: parseDate('2025-08-01'),
        distanceKm: 999,
      ),
    ];
    expect(
      rideKm(
        rides: rides,
        gearId: gear,
        fromInclusive: parseDate('2025-03-01'),
      ),
      150,
    );
    expect(
      rideKm(
        rides: rides,
        gearId: gear,
        fromInclusive: parseDate('2025-03-01'),
        toExclusive: parseDate('2025-08-01'),
      ),
      100,
    );
  });

  test('history distance is cumulative from the start date through each day', () {
    final rides = [
      Ride(
        id: '1',
        gearId: 'g',
        startedOn: parseDate('2025-02-01'),
        distanceKm: 1000,
      ),
      Ride(
        id: '2',
        gearId: 'g',
        startedOn: parseDate('2025-06-01'),
        distanceKm: 500,
      ),
      Ride(
        id: '3',
        gearId: 'g',
        startedOn: parseDate('2025-08-01'),
        distanceKm: 200,
      ),
    ];
    final start = parseDate('2025-01-01');
    expect(
      rideKmThrough(
        rides: rides,
        gearId: 'g',
        fromInclusive: start,
        throughInclusive: parseDate('2025-03-15'),
      ),
      1000,
    );
    expect(
      rideKmThrough(
        rides: rides,
        gearId: 'g',
        fromInclusive: start,
        throughInclusive: parseDate('2025-07-01'),
      ),
      1500,
    );
    final rows = historyRows(
      replacements: [
        Replacement(
          id: 'a',
          partId: 'p',
          gearId: 'g',
          replacedOn: parseDate('2024-12-01'),
          memo: '',
        ),
        Replacement(
          id: 'b',
          partId: 'p',
          gearId: 'g',
          replacedOn: parseDate('2025-03-15'),
          memo: '',
        ),
        Replacement(
          id: 'c',
          partId: 'p',
          gearId: 'g',
          replacedOn: parseDate('2025-07-01'),
          memo: '',
        ),
      ],
      rides: rides,
      gearId: 'g',
      trackingFrom: start,
    );
    expect(rows.map((row) => row.used.round()).toList(), [0, 1000, 1500]);
  });

  test('newestRideOn is the latest ride on or after the start', () {
    final rides = [
      Ride(
        id: '1',
        gearId: 'g1',
        startedOn: parseDate('2025-03-01'),
        distanceKm: 10,
      ),
      Ride(
        id: '2',
        gearId: 'g1',
        startedOn: parseDate('2026-07-15'),
        distanceKm: 20,
      ),
      Ride(
        id: '3',
        gearId: 'g1',
        startedOn: parseDate('2025-07-15'),
        distanceKm: 5,
      ),
    ];
    expect(
      formatDate(newestRideOn(rides: rides, fromInclusive: parseDate('2025-07-17'))!),
      '2026-07-15',
    );
    expect(newestRideOn(rides: rides, fromInclusive: parseDate('2026-08-01')), isNull);
  });

  test('oldestRideOn is the first ride of the selected gear', () {
    final rides = [
      Ride(
        id: '1',
        gearId: 'g1',
        startedOn: parseDate('2025-06-01'),
        distanceKm: 10,
      ),
      Ride(
        id: '2',
        gearId: 'g1',
        startedOn: parseDate('2024-04-15'),
        distanceKm: 20,
      ),
      Ride(
        id: '3',
        gearId: 'g2',
        startedOn: parseDate('2020-01-01'),
        distanceKm: 5,
      ),
    ];
    expect(formatDate(oldestRideOn(rides: rides, gearId: 'g1')!), '2024-04-15');
    expect(oldestRideOn(rides: rides, gearId: 'g3'), isNull);
    expect(oldestRideOn(rides: rides, gearId: null), isNull);
  });

  test('display cards keep groups as one row and ungrouped as registered names', () {
    const front = Part(
      id: 'f',
      gearId: 'g',
      registeredName: '前タイヤ',
      cycle: CycleKind.distance,
      limitMode: LimitMode.recommended,
      recommendedLimit: 6000,
      customLimit: 6000,
      thresholdPct: 80,
      sortOrder: 0,
    );
    const rear = Part(
      id: 'r',
      gearId: 'g',
      registeredName: '後タイヤ',
      cycle: CycleKind.distance,
      limitMode: LimitMode.recommended,
      recommendedLimit: 6000,
      customLimit: 6000,
      thresholdPct: 80,
      sortOrder: 1,
    );
    const chain = Part(
      id: 'c',
      gearId: 'g',
      registeredName: 'チェーン',
      cycle: CycleKind.distance,
      limitMode: LimitMode.recommended,
      recommendedLimit: 4000,
      customLimit: 4000,
      thresholdPct: 80,
      sortOrder: 2,
    );
    const group = DisplayGroup(
      id: 'g',
      gearId: 'g',
      displayName: 'タイヤ',
      frontPartId: 'f',
      rearPartId: 'r',
    );
    final cards = buildDisplayCards(
      parts: [front, rear, chain],
      groups: [group],
    );
    expect(cards.length, 2);
    expect(cards.first.title, 'タイヤ');
    expect(cards.last.title, 'チェーン');
    expect(displayTitle(part: front, groups: [group]), 'タイヤ · F');
    expect(alertLabel(part: front, groups: [group]), 'タイヤ F');
    expect(displayTitle(part: chain, groups: [group]), 'チェーン');
  });

  test('recommended limits follow the registered name', () {
    expect(recommendedLimitFor('前タイヤ', CycleKind.distance), 6000);
    expect(recommendedLimitFor('チェーン', CycleKind.distance), 4000);
    expect(recommendedLimitFor('前ブレーキパッド', CycleKind.distance), 1500);
    expect(recommendedLimitFor('後ワイヤー', CycleKind.distance), 5000);
    expect(recommendedLimitFor('バッテリー', CycleKind.months), 24);
    expect(recommendedLimitFor('前ブレーキオイル', CycleKind.distance), 10000);
    expect(recommendedLimitFor('スピードセンサ電池', CycleKind.months), 12);
    expect(recommendedLimitFor('前ディスク', CycleKind.distance), 8000);
    expect(recommendedLimitFor('バーテープ', CycleKind.distance), 5000);
    expect(recommendedLimitFor('プーリー', CycleKind.distance), 5000);
  });

  test('previous cycle is the last completed interval, or start date if only one replacement', () {
    const part = Part(
      id: 'p',
      gearId: 'g',
      registeredName: 'チェーン',
      cycle: CycleKind.distance,
      limitMode: LimitMode.previousCycle,
      recommendedLimit: 4000,
      customLimit: 1000,
      thresholdPct: 80,
      sortOrder: 0,
    );
    final first = Replacement(
      id: 'first',
      partId: 'p',
      gearId: 'g',
      replacedOn: parseDate('2026-06-12'),
      memo: '',
    );
    final second = Replacement(
      id: 'second',
      partId: 'p',
      gearId: 'g',
      replacedOn: parseDate('2027-01-01'),
      memo: '',
    );
    final twoReplacements = [
      Replacement(
        id: 'older',
        partId: 'p',
        gearId: 'g',
        replacedOn: parseDate('2025-04-07'),
        memo: '',
      ),
      first,
    ];
    final rides = [
      Ride(
        id: 'after-start',
        gearId: 'g',
        startedOn: parseDate('2024-06-01'),
        distanceKm: 1200,
      ),
      Ride(
        id: 'between-two',
        gearId: 'g',
        startedOn: parseDate('2025-12-01'),
        distanceKm: 3918,
      ),
      Ride(
        id: 'before-first',
        gearId: 'g',
        startedOn: parseDate('2026-03-01'),
        distanceKm: 1869,
      ),
      Ride(
        id: 'completed-cycle',
        gearId: 'g',
        startedOn: parseDate('2026-09-01'),
        distanceKm: 2500,
      ),
    ];
    final start = parseDate('2023-08-01');
    expect(
      previousCycleUsed(
        part: part,
        replacements: twoReplacements,
        rides: rides,
        gearId: 'g',
        trackingFrom: start,
      ),
      5787,
    );
    expect(
      previousCycleUsed(
        part: part,
        replacements: [first],
        rides: rides,
        gearId: 'g',
        trackingFrom: start,
      ),
      6987,
    );
    expect(
      previousCycleUsed(
        part: part,
        replacements: [first, second],
        rides: rides,
        gearId: 'g',
        trackingFrom: start,
      ),
      2500,
    );
    expect(resolveLimit(part, previousCycle: 3918), 3918);
    expect(resolveLimit(part, previousCycle: null), 4000);
    expect(
      resolveLimit(
        part.copyWith(limitMode: LimitMode.custom),
        previousCycle: 2500,
      ),
      1000,
    );
  });

  test('wearStatus uses threshold percent', () {
    expect(wearStatus(4800, 6000, 80), WearStatus.soon);
    expect(wearStatus(2700, 6000, 80), WearStatus.ok);
    expect(wearStatus(6000, 6000, 80), WearStatus.overdue);
  });

  test('demo marks attach to fake gear, sync, and distance', () {
    expect(formatUsed(4800, CycleKind.distance, demo: true), '4,800km（デモ）');
    expect(
      formatElapsedAndDue(
        4800,
        6000,
        CycleKind.distance,
        modeLabel: '推奨',
        demo: true,
      ),
      '4,800 / 6,000 km 推奨（デモ）',
    );
    expect(
      formatElapsedAndDue(7, 12, CycleKind.months, modeLabel: '自動'),
      '7 / 12 か月 自動',
    );
    expect(formatTodayUsed(3000, CycleKind.distance), '3,000km（今日）');
    expect(formatUsed(7, CycleKind.months, demo: true), '7か月');
    expect(markDemo('最終同期 2025-07-17〜2026-07-15', demo: true),
        '最終同期 2025-07-17〜2026-07-15（デモ）');
    expect(
      demoGearLabel('Aeroad', demo: true, selected: true),
      'Aeroad（デモ・選択中）',
    );
  });
}
