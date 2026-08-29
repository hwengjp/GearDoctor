import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/app_database.dart';
import '../data/app_repository.dart';
import '../data/seed.dart';
import '../domain/dates.dart';
import '../domain/replacement_csv.dart';
import '../domain/usage.dart';
import '../models/models.dart';
import '../strava/strava_api.dart';
import '../strava/strava_config.dart';
import '../strava/strava_oauth.dart';

class AppStore extends ChangeNotifier {
  AppStore({AppDatabase? database, DateTime? now})
      : _database = database ?? AppDatabase(),
        _nowOverride = now;

  final AppDatabase _database;
  final DateTime? _nowOverride;

  AppRepository? _repo;
  bool loading = true;
  String? error;

  List<Part> parts = [];
  List<Replacement> replacements = [];
  List<DisplayGroup> groups = [];
  List<Gear> gears = [];
  List<Ride> rides = [];
  AppSettings settings = const AppSettings();

  DateTime get now => dateOnly(_nowOverride ?? DateTime.now());

  bool get usingDemoRides => rides.any((ride) => isDemoRideId(ride.id));

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final db = await _database.instance;
      _repo = AppRepository(db);
      if (!await _repo!.hasParts()) {
        await seedDemoData(_repo!);
      } else {
        final existingSettings = await _repo!.loadSettings();
        await ensureMissingDefaultParts(
          _repo!,
          now: now,
          startDate: existingSettings.lastSyncFrom,
        );
      }
      await refresh();
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final repo = _requireRepo();
    parts = await repo.loadParts();
    replacements = await repo.loadReplacements();
    groups = await repo.loadGroups();
    gears = await repo.loadGears();
    rides = await repo.loadRides();
    settings = await repo.loadSettings();
    loading = false;
    notifyListeners();
  }

  DateTime? get newestSyncedOn => newestRideOn(
        rides: rides,
        fromInclusive: settings.lastSyncFrom,
      );

  Gear? get selectedGear {
    final id = settings.selectedGearId;
    if (id == null) {
      return null;
    }
    for (final gear in gears) {
      if (gear.id == id) {
        return gear;
      }
    }
    return null;
  }

  List<Replacement> replacementsFor(String partId) {
    return replacements.where((item) => item.partId == partId).toList();
  }

  double usedOf(Part part) {
    return currentUsed(
      part: part,
      replacements: replacementsFor(part.id),
      rides: rides,
      gearId: settings.selectedGearId,
      now: now,
    );
  }

  int? previousCycleOf(Part part) {
    return previousCycleUsed(
      part: part,
      replacements: replacementsFor(part.id),
      rides: rides,
      gearId: settings.selectedGearId,
      trackingFrom: settings.lastSyncFrom,
    );
  }

  int limitOf(Part part) {
    return resolveLimit(part, previousCycle: previousCycleOf(part));
  }

  String limitModeLabelOf(Part part) {
    if (part.limitMode == LimitMode.previousCycle &&
        previousCycleOf(part) == null) {
      return '前回周期（推奨）';
    }
    return part.limitMode.label;
  }

  List<HistoryRow> historyOf(Part part) {
    return historyRows(
      replacements: replacementsFor(part.id),
      rides: rides,
      gearId: settings.selectedGearId,
      trackingFrom: settings.lastSyncFrom,
    );
  }

  double gearKmThrough(DateTime throughInclusive) {
    return rideKmThrough(
      rides: rides,
      gearId: settings.selectedGearId,
      fromInclusive: settings.lastSyncFrom,
      throughInclusive: throughInclusive,
    );
  }

  List<DisplayCard> get cards =>
      buildDisplayCards(parts: parts, groups: groups);

  List<AlertItem> get alerts {
    final used = {for (final part in parts) part.id: usedOf(part)};
    final limits = {for (final part in parts) part.id: limitOf(part)};
    return collectAlerts(
      parts: parts,
      groups: groups,
      usedByPartId: used,
      limitByPartId: limits,
    );
  }

  Part? partById(String id) {
    for (final part in parts) {
      if (part.id == id) {
        return part;
      }
    }
    return null;
  }

  DisplayGroup? groupOf(String partId) => groupForPart(groups, partId);

  String titleOf(Part part) => displayTitle(part: part, groups: groups);

  Future<void> savePart(Part part, {required bool isNew}) async {
    final repo = _requireRepo();
    await repo.upsertPart(part);
    if (isNew) {
      await repo.upsertReplacement(
        Replacement(
          id: newId('r'),
          partId: part.id,
          replacedOn: dateOnly(settings.lastSyncFrom ?? now),
          memo: '',
        ),
      );
    }
    await refresh();
  }

  Future<void> addReplacement({
    required String partId,
    required DateTime replacedOn,
    required String memo,
  }) async {
    await _requireRepo().upsertReplacement(
      Replacement(
        id: newId('r'),
        partId: partId,
        replacedOn: dateOnly(replacedOn),
        memo: memo.trim(),
      ),
    );
    await refresh();
  }

  Future<void> updateReplacement(Replacement replacement) async {
    await _requireRepo().upsertReplacement(
      Replacement(
        id: replacement.id,
        partId: replacement.partId,
        replacedOn: dateOnly(replacement.replacedOn),
        memo: replacement.memo.trim(),
      ),
    );
    await refresh();
  }

  Future<void> deleteReplacement(String id) async {
    await _requireRepo().deleteReplacement(id);
    await refresh();
  }

  Future<ReplacementImportResult> importReplacementPlan(
    ReplacementImportPlan plan,
  ) async {
    if (!plan.canImport) {
      return ReplacementImportResult(
        added: 0,
        skippedDuplicates: plan.duplicates.length,
      );
    }
    final repo = _requireRepo();
    final partIds = <String>{};
    for (final row in plan.toAdd) {
      final part = partForCsvRow(row, parts);
      if (part != null) {
        partIds.add(part.id);
      }
    }
    for (final partId in partIds) {
      await repo.deleteReplacementsForPart(partId);
    }
    for (final row in plan.toAdd) {
      final part = partForCsvRow(row, parts);
      if (part == null) {
        continue;
      }
      await repo.upsertReplacement(
        Replacement(
          id: newId('r'),
          partId: part.id,
          replacedOn: dateOnly(row.replacedOn),
          memo: row.memo,
        ),
      );
    }
    await refresh();
    return ReplacementImportResult(
      added: plan.toAdd.length,
      skippedDuplicates: plan.duplicates.length,
    );
  }

  Future<void> combineDisplay({
    required String frontPartId,
    required String rearPartId,
    required String displayName,
  }) async {
    await _requireRepo().insertGroup(
      DisplayGroup(
        id: newId('grp'),
        displayName: displayName.trim(),
        frontPartId: frontPartId,
        rearPartId: rearPartId,
      ),
    );
    await refresh();
  }

  Future<void> dissolveGroup(String id) async {
    await _requireRepo().deleteGroup(id);
    await refresh();
  }

  Future<void> selectGear(String gearId) async {
    settings = settings.copyWith(selectedGearId: gearId);
    await _requireRepo().saveSettings(settings);
    notifyListeners();
  }

  Future<void> saveStravaCredentials({
    required String clientId,
    required String clientSecret,
  }) async {
    settings = settings.copyWith(
      stravaClientId: clientId.trim(),
      stravaClientSecret: clientSecret.trim(),
    );
    await _requireRepo().saveSettings(settings);
    notifyListeners();
  }

  Future<void> saveStravaAuth(StravaAuthResult result) async {
    settings = settings.copyWith(
      stravaAccessToken: result.accessToken,
      stravaRefreshToken: result.refreshToken,
      stravaExpiresAt: result.expiresAt,
      stravaAthleteId: result.athleteId,
      stravaAthleteName: result.athleteName,
    );
    await _requireRepo().saveSettings(settings);
    await _adoptStravaBikes(result.bikes);
    await refresh();
  }

  Future<void> disconnectStrava({void Function(String token)? remoteRevoke}) async {
    final token = settings.stravaAccessToken;
    if (token != null && remoteRevoke != null) {
      remoteRevoke(token);
    }
    settings = settings.copyWith(clearTokens: true);
    await _requireRepo().saveSettings(settings);
    notifyListeners();
  }

  Future<void> resetToDemo() async {
    final repo = _requireRepo();
    await repo.clearAllTables();
    await seedDemoData(repo);
    await refresh();
  }

  Future<void> changeSyncStart(DateTime from) async {
    final next = dateOnly(from);
    final current = settings.lastSyncFrom == null
        ? null
        : dateOnly(settings.lastSyncFrom!);
    if (current != null && current == next) {
      return;
    }
    final repo = _requireRepo();
    await repo.deleteAllRides();
    settings = settings.copyWith(clearSync: true).copyWith(lastSyncFrom: next);
    await repo.saveSettings(settings);
    await refresh();
  }

  Future<StravaSyncSummary> syncForward({
    required int months,
    http.Client? client,
  }) async {
    final start = settings.lastSyncFrom;
    if (start == null) {
      throw StravaAuthException('先に開始日を指定してください。');
    }
    if (!settings.stravaConnected) {
      throw StravaAuthException('先に Strava 連携の画面から連携してください。');
    }
    final owned = client == null;
    final httpClient = client ?? http.Client();
    try {
      var tokens = await _ensureTokens(httpClient);
      Future<T> run<T>(Future<T> Function(String token) action) async {
        try {
          return await action(tokens.accessToken);
        } on StravaAuthException catch (error) {
          if (!error.message.contains('認可が無効')) {
            rethrow;
          }
          tokens = await _ensureTokens(httpClient, forceRefresh: true);
          return action(tokens.accessToken);
        }
      }

      final bikes = await run(
        (token) => fetchAthleteBikes(client: httpClient, accessToken: token),
      );
      await _adoptStravaBikes(bikes);

      final repo = _requireRepo();
      if (rides.any((ride) => isDemoRideId(ride.id))) {
        await repo.deleteAllRides();
        rides = [];
      }

      final window = nextSyncWindow(
        startDate: start,
        fetchedThrough: settings.lastSyncAt,
        months: months,
        today: now,
      );
      final fetched = await run(
        (token) => fetchBikeRides(
          client: httpClient,
          accessToken: token,
          fromInclusive: window.fromInclusive,
          toInclusive: window.toInclusive,
        ),
      );
      for (final ride in fetched) {
        await repo.upsertRide(ride);
      }
      settings = settings.copyWith(lastSyncAt: window.toInclusive);
      await repo.saveSettings(settings);
      await refresh();
      return StravaSyncSummary(
        from: window.fromInclusive,
        to: window.toInclusive,
        savedCount: fetched.length,
        newestRideOn: newestSyncedOn,
      );
    } finally {
      if (owned) {
        httpClient.close();
      }
    }
  }

  Future<StravaTokens> _ensureTokens(
    http.Client client, {
    bool forceRefresh = false,
  }) async {
    var clientId = settings.stravaClientId ?? '';
    var clientSecret = settings.stravaClientSecret ?? '';
    if (clientId.isEmpty || clientSecret.isEmpty) {
      final loaded = await resolveStravaCredentials(
        storedClientId: settings.stravaClientId,
        storedClientSecret: settings.stravaClientSecret,
      );
      clientId = loaded?.clientId ?? '';
      clientSecret = loaded?.clientSecret ?? '';
    }
    final tokens = await ensureAccessToken(
      client: client,
      clientId: clientId,
      clientSecret: clientSecret,
      accessToken: settings.stravaAccessToken ?? '',
      refreshToken: settings.stravaRefreshToken ?? '',
      expiresAt: forceRefresh ? DateTime.utc(2000) : settings.stravaExpiresAt,
    );
    settings = settings.copyWith(
      stravaAccessToken: tokens.accessToken,
      stravaRefreshToken: tokens.refreshToken,
      stravaExpiresAt: tokens.expiresAt,
    );
    await _requireRepo().saveSettings(settings);
    return tokens;
  }

  Future<void> _adoptStravaBikes(List<Gear> bikes) async {
    final repo = _requireRepo();
    for (final bike in bikes) {
      await repo.upsertGear(bike);
    }
    if (bikes.isEmpty) {
      return;
    }
    for (final id in demoGearIds) {
      await repo.deleteGear(id);
    }
    final selected = settings.selectedGearId;
    final known = bikes.any((bike) => bike.id == selected);
    if (!known) {
      settings = settings.copyWith(selectedGearId: bikes.first.id);
      await repo.saveSettings(settings);
    }
  }

  int nextSortOrder() {
    var maxOrder = -1;
    for (final part in parts) {
      if (part.sortOrder > maxOrder) {
        maxOrder = part.sortOrder;
      }
    }
    return maxOrder + 1;
  }

  List<Part> get ungroupedParts {
    final grouped = <String>{};
    for (final group in groups) {
      grouped.add(group.frontPartId);
      grouped.add(group.rearPartId);
    }
    return parts.where((part) => !grouped.contains(part.id)).toList();
  }

  String newId(String prefix) {
    final random = Random();
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1 << 32)}';
  }

  AppRepository _requireRepo() {
    final repo = _repo;
    if (repo == null) {
      throw StateError('データベースがまだ開いていません');
    }
    return repo;
  }
}
