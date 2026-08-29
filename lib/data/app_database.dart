import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'seed.dart';

class AppDatabase {
  AppDatabase({this.overridePath});

  final String? overridePath;

  Database? _db;

  Future<Database> get instance async {
    final existing = _db;
    if (existing != null) {
      return existing;
    }
    _db = await _open();
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    _ensureDesktopFactory();
    final path = overridePath ?? await _defaultPath();
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE parts (
  id TEXT PRIMARY KEY,
  gear_id TEXT NOT NULL,
  registered_name TEXT NOT NULL,
  cycle TEXT NOT NULL,
  limit_mode TEXT NOT NULL,
  recommended_limit INTEGER NOT NULL,
  custom_limit INTEGER NOT NULL,
  threshold_pct INTEGER NOT NULL,
  sort_order INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE replacements (
  id TEXT PRIMARY KEY,
  part_id TEXT NOT NULL,
  gear_id TEXT NOT NULL,
  replaced_on TEXT NOT NULL,
  memo TEXT NOT NULL
)
''');
        await db.execute('''
CREATE TABLE display_groups (
  id TEXT PRIMARY KEY,
  gear_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  front_part_id TEXT NOT NULL UNIQUE,
  rear_part_id TEXT NOT NULL UNIQUE
)
''');
        await db.execute('''
CREATE TABLE gears (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
)
''');
        await db.execute('''
CREATE TABLE rides (
  id TEXT PRIMARY KEY,
  gear_id TEXT NOT NULL,
  started_on TEXT NOT NULL,
  distance_km REAL NOT NULL
)
''');
        await db.execute('''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE replacements ADD COLUMN gear_id TEXT NOT NULL DEFAULT ''",
          );
          final selected = await db.query(
            'settings',
            where: 'key = ?',
            whereArgs: ['selected_gear_id'],
          );
          var gearId = selected.isEmpty
              ? ''
              : '${selected.first['value'] ?? ''}';
          if (gearId.isEmpty) {
            final gears = await db.query('gears', limit: 1);
            if (gears.isNotEmpty) {
              gearId = '${gears.first['id']}';
            }
          }
          if (gearId.isNotEmpty) {
            await db.update(
              'replacements',
              {'gear_id': gearId},
              where: "gear_id = ''",
            );
          }
        }
        if (oldVersion < 3) {
          await migrateToPerGearParts(db);
        }
      },
    );
  }

  Future<String> _defaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'geardoctor.db');
  }

  static bool _desktopReady = false;

  static void _ensureDesktopFactory() {
    if (_desktopReady) {
      return;
    }
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
    _desktopReady = true;
  }
}
