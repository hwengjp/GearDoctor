import 'package:sqflite/sqflite.dart';

import '../domain/dates.dart';
import '../models/models.dart';

class AppRepository {
  AppRepository(this._db);

  final Database _db;

  Future<bool> hasParts() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM parts');
    return (rows.first['c'] as num).toInt() > 0;
  }

  Future<List<Part>> loadParts({String? gearId}) async {
    final rows = gearId == null
        ? await _db.query('parts', orderBy: 'sort_order ASC')
        : await _db.query(
            'parts',
            where: 'gear_id = ?',
            whereArgs: [gearId],
            orderBy: 'sort_order ASC',
          );
    return rows.map(_partFromRow).toList();
  }

  Future<void> upsertPart(Part part) async {
    await _db.insert(
      'parts',
      {
        'id': part.id,
        'gear_id': part.gearId,
        'registered_name': part.registeredName,
        'cycle': part.cycle.name,
        'limit_mode': part.limitMode.name,
        'recommended_limit': part.recommendedLimit,
        'custom_limit': part.customLimit,
        'threshold_pct': part.thresholdPct,
        'sort_order': part.sortOrder,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Replacement>> loadReplacements() async {
    final rows = await _db.query('replacements', orderBy: 'replaced_on DESC');
    return rows
        .map(
          (row) => Replacement(
            id: row['id'] as String,
            partId: row['part_id'] as String,
            gearId: row['gear_id'] as String,
            replacedOn: parseDate(row['replaced_on'] as String),
            memo: row['memo'] as String,
          ),
        )
        .toList();
  }

  Future<void> upsertReplacement(Replacement replacement) async {
    await _db.insert(
      'replacements',
      {
        'id': replacement.id,
        'part_id': replacement.partId,
        'gear_id': replacement.gearId,
        'replaced_on': formatDate(replacement.replacedOn),
        'memo': replacement.memo,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteReplacement(String id) async {
    await _db.delete('replacements', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteReplacementsForPart(String partId) async {
    await _db.delete('replacements', where: 'part_id = ?', whereArgs: [partId]);
  }

  Future<void> deleteReplacementsForPartGear(String partId, String gearId) async {
    await _db.delete(
      'replacements',
      where: 'part_id = ? AND gear_id = ?',
      whereArgs: [partId, gearId],
    );
  }

  Future<void> deletePart(String id) async {
    await deleteReplacementsForPart(id);
    await _db.delete(
      'display_groups',
      where: 'front_part_id = ? OR rear_part_id = ?',
      whereArgs: [id, id],
    );
    await _db.delete('parts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DisplayGroup>> loadGroups({String? gearId}) async {
    final rows = gearId == null
        ? await _db.query('display_groups')
        : await _db.query(
            'display_groups',
            where: 'gear_id = ?',
            whereArgs: [gearId],
          );
    return rows
        .map(
          (row) => DisplayGroup(
            id: row['id'] as String,
            gearId: '${row['gear_id'] ?? ''}',
            displayName: row['display_name'] as String,
            frontPartId: row['front_part_id'] as String,
            rearPartId: row['rear_part_id'] as String,
          ),
        )
        .toList();
  }

  Future<void> insertGroup(DisplayGroup group) async {
    await _db.insert('display_groups', {
      'id': group.id,
      'gear_id': group.gearId,
      'display_name': group.displayName,
      'front_part_id': group.frontPartId,
      'rear_part_id': group.rearPartId,
    });
  }

  Future<void> deleteGroup(String id) async {
    await _db.delete('display_groups', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Gear>> loadGears() async {
    final rows = await _db.query('gears', orderBy: 'name ASC');
    return rows
        .map((row) => Gear(id: row['id'] as String, name: row['name'] as String))
        .toList();
  }

  Future<void> deleteGear(String id) async {
    await _db.delete('replacements', where: 'gear_id = ?', whereArgs: [id]);
    await _db.delete('display_groups', where: 'gear_id = ?', whereArgs: [id]);
    await _db.delete('parts', where: 'gear_id = ?', whereArgs: [id]);
    await _db.delete('gears', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertGear(Gear gear) async {
    await _db.insert(
      'gears',
      {'id': gear.id, 'name': gear.name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Ride>> loadRides() async {
    final rows = await _db.query('rides', orderBy: 'started_on ASC');
    return rows
        .map(
          (row) => Ride(
            id: row['id'] as String,
            gearId: row['gear_id'] as String,
            startedOn: parseDate(row['started_on'] as String),
            distanceKm: (row['distance_km'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<void> deleteAllRides() async {
    await _db.delete('rides');
  }

  Future<void> clearAllTables() async {
    await _db.delete('replacements');
    await _db.delete('display_groups');
    await _db.delete('parts');
    await _db.delete('rides');
    await _db.delete('gears');
    await _db.delete('settings');
  }

  Future<void> upsertRide(Ride ride) async {
    await _db.insert(
      'rides',
      {
        'id': ride.id,
        'gear_id': ride.gearId,
        'started_on': formatDate(ride.startedOn),
        'distance_km': ride.distanceKm,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppSettings> loadSettings() async {
    final rows = await _db.query('settings');
    final map = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    DateTime? expiresAt;
    final expiresRaw = map['strava_expires_at'];
    if (expiresRaw != null && expiresRaw.isNotEmpty) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(
        int.parse(expiresRaw) * 1000,
        isUtc: true,
      );
    }
    return AppSettings(
      selectedGearId: map['selected_gear_id'],
      lastSyncAt: map['last_sync_at'] == null
          ? null
          : parseDate(map['last_sync_at']!),
      lastSyncFrom: map['last_sync_from'] == null
          ? null
          : parseDate(map['last_sync_from']!),
      stravaClientId: map['strava_client_id'],
      stravaClientSecret: map['strava_client_secret'],
      stravaAccessToken: map['strava_access_token'],
      stravaRefreshToken: map['strava_refresh_token'],
      stravaExpiresAt: expiresAt,
      stravaAthleteId: map['strava_athlete_id'],
      stravaAthleteName: map['strava_athlete_name'],
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    Future<void> put(String key, String? value) async {
      if (value == null) {
        await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
        return;
      }
      await _db.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await put('selected_gear_id', settings.selectedGearId);
    await put(
      'last_sync_at',
      settings.lastSyncAt == null ? null : formatDate(settings.lastSyncAt!),
    );
    await put(
      'last_sync_from',
      settings.lastSyncFrom == null ? null : formatDate(settings.lastSyncFrom!),
    );
    await put('strava_client_id', settings.stravaClientId);
    await put('strava_client_secret', settings.stravaClientSecret);
    await put('strava_access_token', settings.stravaAccessToken);
    await put('strava_refresh_token', settings.stravaRefreshToken);
    await put(
      'strava_expires_at',
      settings.stravaExpiresAt == null
          ? null
          : (settings.stravaExpiresAt!.millisecondsSinceEpoch ~/ 1000).toString(),
    );
    await put('strava_athlete_id', settings.stravaAthleteId);
    await put('strava_athlete_name', settings.stravaAthleteName);
    await put('strava_connected', settings.stravaConnected ? '1' : '0');
  }

  Part _partFromRow(Map<String, Object?> row) {
    return Part(
      id: row['id'] as String,
      gearId: '${row['gear_id'] ?? ''}',
      registeredName: row['registered_name'] as String,
      cycle: CycleKind.values.byName(row['cycle'] as String),
      limitMode: LimitMode.values.byName(row['limit_mode'] as String),
      recommendedLimit: row['recommended_limit'] as int,
      customLimit: row['custom_limit'] as int,
      thresholdPct: row['threshold_pct'] as int,
      sortOrder: row['sort_order'] as int,
    );
  }
}
