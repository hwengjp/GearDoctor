import 'package:sqflite/sqflite.dart';

import '../domain/dates.dart';
import '../domain/usage.dart';
import '../models/models.dart';
import 'app_repository.dart';

const demoGearIds = {'g_aeroad', 'g_endurace', 'g_grail'};

bool isDemoGearId(String id) => demoGearIds.contains(id);

bool isDemoRideId(String id) => id.startsWith('ride_');

class DemoRequiresSyncException implements Exception {
  const DemoRequiresSyncException();

  static const title = '先に Strava を同期してください';
  static const message = 'デモのあいだは部品の追加と記録の CSV は使えません。';

  @override
  String toString() => '$title。$message';
}

String partIdOnGear(String catalogId, String gearId) => '$catalogId@$gearId';

String groupIdOnGear(String catalogId, String gearId) => '$catalogId@$gearId';

bool matchesCatalogPart(String partId, String catalogId, String gearId) {
  return partId == catalogId || partId == partIdOnGear(catalogId, gearId);
}

List<Part> defaultParts() {
  return [
    _part('p_front_tire', '前タイヤ', CycleKind.distance, 6000, 5000, 0),
    _part('p_rear_tire', '後タイヤ', CycleKind.distance, 6000, 5000, 1),
    _part('p_chain', 'チェーン', CycleKind.distance, 4000, 4000, 2),
    _part('p_front_pad', '前ブレーキパッド', CycleKind.distance, 1500, 1500, 3),
    _part('p_rear_pad', '後ブレーキパッド', CycleKind.distance, 1500, 1500, 4),
    _part('p_front_cable', '前ワイヤー', CycleKind.distance, 5000, 5000, 5),
    _part('p_rear_cable', '後ワイヤー', CycleKind.distance, 5000, 5000, 6),
    _part('p_front_oil', '前ブレーキオイル', CycleKind.distance, 10000, 10000, 7),
    _part('p_rear_oil', '後ブレーキオイル', CycleKind.distance, 10000, 10000, 8),
    _part('p_front_disc', '前ディスク', CycleKind.distance, 8000, 8000, 9),
    _part('p_rear_disc', '後ディスク', CycleKind.distance, 8000, 8000, 10),
    _part('p_bar_tape', 'バーテープ', CycleKind.distance, 5000, 5000, 11),
    _part('p_speed_batt', 'スピードセンサ電池', CycleKind.months, 12, 12, 12),
    _part('p_power_batt', 'パワーセンサ電池', CycleKind.months, 12, 12, 13),
    _part('p_remote_batt', 'リモコン電池', CycleKind.months, 12, 12, 14),
    _part('p_hr_batt', '心拍計電池', CycleKind.months, 12, 12, 15),
    _part('p_rear_light_batt', 'リヤライト電池', CycleKind.months, 12, 12, 16),
    _part('p_pulley', 'プーリー', CycleKind.distance, 5000, 5000, 17),
  ];
}

List<DisplayGroup> defaultGroups() {
  return const [
    DisplayGroup(
      id: 'grp_tire',
      gearId: '',
      displayName: 'タイヤ',
      frontPartId: 'p_front_tire',
      rearPartId: 'p_rear_tire',
    ),
    DisplayGroup(
      id: 'grp_pad',
      gearId: '',
      displayName: 'ブレーキパッド',
      frontPartId: 'p_front_pad',
      rearPartId: 'p_rear_pad',
    ),
    DisplayGroup(
      id: 'grp_cable',
      gearId: '',
      displayName: 'ワイヤー',
      frontPartId: 'p_front_cable',
      rearPartId: 'p_rear_cable',
    ),
    DisplayGroup(
      id: 'grp_oil',
      gearId: '',
      displayName: 'ブレーキオイル',
      frontPartId: 'p_front_oil',
      rearPartId: 'p_rear_oil',
    ),
    DisplayGroup(
      id: 'grp_disc',
      gearId: '',
      displayName: 'ディスク',
      frontPartId: 'p_front_disc',
      rearPartId: 'p_rear_disc',
    ),
  ];
}

Part partForGear(Part catalog, String gearId) {
  return catalog.copyWith(
    id: partIdOnGear(catalog.id, gearId),
    gearId: gearId,
  );
}

DisplayGroup groupForGear(DisplayGroup catalog, String gearId) {
  return DisplayGroup(
    id: groupIdOnGear(catalog.id, gearId),
    gearId: gearId,
    displayName: catalog.displayName,
    frontPartId: partIdOnGear(catalog.frontPartId, gearId),
    rearPartId: partIdOnGear(catalog.rearPartId, gearId),
  );
}

Future<void> seedDemoData(AppRepository repo) async {
  const aeroad = Gear(id: 'g_aeroad', name: 'Aeroad');
  const endurace = Gear(id: 'g_endurace', name: 'Endurace');
  const grail = Gear(id: 'g_grail', name: 'Grail');
  await repo.upsertGear(aeroad);
  await repo.upsertGear(endurace);
  await repo.upsertGear(grail);

  final origin = parseDate('2023-04-15');
  await seedDefaultCatalogForGear(repo, aeroad.id, startDate: origin);
  await seedDefaultCatalogForGear(repo, endurace.id, startDate: origin);
  await seedDefaultCatalogForGear(repo, grail.id, startDate: origin);

  final replacements = <Replacement>[
    _rep('r_ft1', 'p_front_tire', '2023-04-02', ''),
    _rep('r_ft2', 'p_front_tire', '2024-01-15', 'パンク後に交換'),
    _rep('r_ft3', 'p_front_tire', '2025-03-01', 'GP5000'),
    _rep('r_rt1', 'p_rear_tire', '2024-06-20', ''),
    _rep('r_rt2', 'p_rear_tire', '2025-08-01', 'サイドカット'),
    _rep('r_ch1', 'p_chain', '2025-11-12', ''),
    _rep('r_fp1', 'p_front_pad', '2026-01-20', ''),
    _rep('r_rp1', 'p_rear_pad', '2026-01-20', ''),
    _rep('r_fc1', 'p_front_cable', '2025-06-10', ''),
    _rep('r_rc1', 'p_rear_cable', '2025-06-10', ''),
    _rep('r_fo1', 'p_front_oil', '2026-01-20', ''),
    _rep('r_ro1', 'p_rear_oil', '2026-01-20', ''),
    _rep('r_fd1', 'p_front_disc', '2025-03-01', ''),
    _rep('r_rd1', 'p_rear_disc', '2025-03-01', ''),
    _rep('r_tape1', 'p_bar_tape', '2026-01-20', ''),
    _rep('r_spb1', 'p_speed_batt', '2026-01-20', ''),
    _rep('r_pwb1', 'p_power_batt', '2026-01-20', ''),
    _rep('r_rmb1', 'p_remote_batt', '2026-01-20', ''),
    _rep('r_hrb1', 'p_hr_batt', '2026-01-20', ''),
    _rep('r_rlb1', 'p_rear_light_batt', '2026-01-20', ''),
    _rep('r_pul1', 'p_pulley', '2025-11-12', ''),
  ];
  final demoPartIds = {for (final replacement in replacements) replacement.partId};
  for (final partId in demoPartIds) {
    await repo.deleteReplacementsForPart(partId);
  }
  for (final replacement in replacements) {
    await repo.upsertReplacement(replacement);
  }

  var rideIndex = 0;
  var month = DateTime.utc(2023, 4, 15);
  final lastRide = DateTime.utc(2026, 7, 15);
  while (!month.isAfter(lastRide)) {
    await repo.upsertRide(
      Ride(
        id: 'ride_$rideIndex',
        gearId: aeroad.id,
        startedOn: month,
        distanceKm: 320,
      ),
    );
    rideIndex += 1;
    month = DateTime.utc(month.year, month.month + 1, 15);
  }

  await repo.saveSettings(
    AppSettings(
      selectedGearId: aeroad.id,
      lastSyncFrom: parseDate('2025-07-17'),
    ),
  );
}

const retiredDefaultPartIds = {'p_battery'};

Future<void> seedDefaultCatalogForGear(
  AppRepository repo,
  String gearId, {
  required DateTime startDate,
}) async {
  for (final retired in retiredDefaultPartIds) {
    await repo.deletePart(retired);
    await repo.deletePart(partIdOnGear(retired, gearId));
  }
  for (final catalog in defaultParts()) {
    final existing = (await repo.loadParts(gearId: gearId)).where((part) {
      return matchesCatalogPart(part.id, catalog.id, gearId);
    }).toList();
    if (existing.isNotEmpty) {
      final part = existing.first;
      if (part.cycle != catalog.cycle ||
          part.recommendedLimit != catalog.recommendedLimit) {
        await repo.upsertPart(
          part.copyWith(
            cycle: catalog.cycle,
            recommendedLimit: catalog.recommendedLimit,
            customLimit: catalog.customLimit,
          ),
        );
      }
      continue;
    }
    final id = partIdOnGear(catalog.id, gearId);
    final created = partForGear(catalog, gearId);
    await repo.upsertPart(created.copyWith(id: id));
    await repo.upsertReplacement(
      Replacement(
        id: 'r_${id}_init',
        partId: id,
        gearId: gearId,
        replacedOn: dateOnly(startDate),
        memo: '',
      ),
    );
  }

  final parts = await repo.loadParts(gearId: gearId);
  final partIds = {for (final part in parts) part.id};
  final existingGroups = await repo.loadGroups(gearId: gearId);
  final groupedPartIds = <String>{};
  for (final group in existingGroups) {
    groupedPartIds.add(group.frontPartId);
    groupedPartIds.add(group.rearPartId);
  }
  for (final catalog in defaultGroups()) {
    final group = groupForGear(catalog, gearId);
    if (existingGroups.any((item) => item.id == group.id)) {
      continue;
    }
    if (!partIds.contains(group.frontPartId) ||
        !partIds.contains(group.rearPartId)) {
      continue;
    }
    if (groupedPartIds.contains(group.frontPartId) ||
        groupedPartIds.contains(group.rearPartId)) {
      continue;
    }
    await repo.insertGroup(group);
    groupedPartIds.add(group.frontPartId);
    groupedPartIds.add(group.rearPartId);
  }
}

/// すでに部品がある端末でも、初期カタログに合わせる。
Future<void> ensureMissingDefaultParts(
  AppRepository repo, {
  required DateTime now,
  DateTime? startDate,
  String? gearId,
}) async {
  final gears = await repo.loadGears();
  final rides = await repo.loadRides();
  final targets = <String>{
    if (gearId != null && gearId.isNotEmpty) gearId,
    for (final gear in gears) gear.id,
  };
  for (final id in targets) {
    await seedDefaultCatalogForGear(
      repo,
      id,
      startDate: oldestRideOn(rides: rides, gearId: id) ?? startDate ?? now,
    );
  }
}

Future<void> migrateToPerGearParts(Database db) async {
  await db.execute(
    "ALTER TABLE parts ADD COLUMN gear_id TEXT NOT NULL DEFAULT ''",
  );
  await db.execute(
    "ALTER TABLE display_groups ADD COLUMN gear_id TEXT NOT NULL DEFAULT ''",
  );

  final selected = await db.query(
    'settings',
    where: 'key = ?',
    whereArgs: ['selected_gear_id'],
  );
  var sourceGearId = selected.isEmpty ? '' : '${selected.first['value'] ?? ''}';
  final gears = await db.query('gears');
  if (sourceGearId.isEmpty && gears.isNotEmpty) {
    sourceGearId = '${gears.first['id']}';
  }
  if (sourceGearId.isEmpty) {
    return;
  }

  await db.update(
    'parts',
    {'gear_id': sourceGearId},
    where: "gear_id = ''",
  );
  await db.update(
    'display_groups',
    {'gear_id': sourceGearId},
    where: "gear_id = ''",
  );

  final repo = AppRepository(db);
  final rides = await repo.loadRides();
  for (final row in gears) {
    final id = '${row['id']}';
    if (id == sourceGearId) {
      continue;
    }
    await seedDefaultCatalogForGear(
      repo,
      id,
      startDate: oldestRideOn(rides: rides, gearId: id) ?? DateTime.now(),
    );
  }
}

Part _part(
  String id,
  String name,
  CycleKind cycle,
  int recommended,
  int custom,
  int order,
) {
  return Part(
    id: id,
    gearId: '',
    registeredName: name,
    cycle: cycle,
    limitMode: LimitMode.recommended,
    recommendedLimit: recommended,
    customLimit: custom,
    thresholdPct: 80,
    sortOrder: order,
  );
}

Replacement _rep(String id, String partId, String date, String memo) {
  const gearId = 'g_aeroad';
  return Replacement(
    id: id,
    partId: partIdOnGear(partId, gearId),
    gearId: gearId,
    replacedOn: parseDate(date),
    memo: memo,
  );
}
