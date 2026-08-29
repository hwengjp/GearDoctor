enum CycleKind {
  distance,
  months;

  String get unitLabel => this == CycleKind.months ? 'か月' : 'km';

  String get usageNoun => this == CycleKind.months ? '経過月' : '走行距離';
}

enum LimitMode {
  recommended,
  previousCycle,
  custom;

  String get label => switch (this) {
        LimitMode.recommended => '推奨',
        LimitMode.previousCycle => '自動',
        LimitMode.custom => '設定',
      };
}

enum WearStatus { ok, soon, overdue }

class Part {
  const Part({
    required this.id,
    required this.gearId,
    required this.registeredName,
    required this.cycle,
    required this.limitMode,
    required this.recommendedLimit,
    required this.customLimit,
    required this.thresholdPct,
    required this.sortOrder,
  });

  final String id;
  final String gearId;
  final String registeredName;
  final CycleKind cycle;
  final LimitMode limitMode;
  final int recommendedLimit;
  final int customLimit;
  final int thresholdPct;
  final int sortOrder;

  int get activeLimit =>
      limitMode == LimitMode.custom ? customLimit : recommendedLimit;

  Part copyWith({
    String? id,
    String? gearId,
    String? registeredName,
    CycleKind? cycle,
    LimitMode? limitMode,
    int? recommendedLimit,
    int? customLimit,
    int? thresholdPct,
    int? sortOrder,
  }) {
    return Part(
      id: id ?? this.id,
      gearId: gearId ?? this.gearId,
      registeredName: registeredName ?? this.registeredName,
      cycle: cycle ?? this.cycle,
      limitMode: limitMode ?? this.limitMode,
      recommendedLimit: recommendedLimit ?? this.recommendedLimit,
      customLimit: customLimit ?? this.customLimit,
      thresholdPct: thresholdPct ?? this.thresholdPct,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class Replacement {
  const Replacement({
    required this.id,
    required this.partId,
    required this.gearId,
    required this.replacedOn,
    required this.memo,
  });

  final String id;
  final String partId;
  final String gearId;
  final DateTime replacedOn;
  final String memo;

  Replacement copyWith({
    String? gearId,
    DateTime? replacedOn,
    String? memo,
  }) {
    return Replacement(
      id: id,
      partId: partId,
      gearId: gearId ?? this.gearId,
      replacedOn: replacedOn ?? this.replacedOn,
      memo: memo ?? this.memo,
    );
  }
}

class DisplayGroup {
  const DisplayGroup({
    required this.id,
    required this.gearId,
    required this.displayName,
    required this.frontPartId,
    required this.rearPartId,
  });

  final String id;
  final String gearId;
  final String displayName;
  final String frontPartId;
  final String rearPartId;

  bool contains(String partId) =>
      frontPartId == partId || rearPartId == partId;
}

class Gear {
  const Gear({required this.id, required this.name});

  final String id;
  final String name;
}

class Ride {
  const Ride({
    required this.id,
    required this.gearId,
    required this.startedOn,
    required this.distanceKm,
  });

  final String id;
  final String gearId;
  final DateTime startedOn;
  final double distanceKm;
}

class AppSettings {
  const AppSettings({
    this.selectedGearId,
    this.lastSyncAt,
    this.lastSyncFrom,
    this.stravaClientId,
    this.stravaClientSecret,
    this.stravaAccessToken,
    this.stravaRefreshToken,
    this.stravaExpiresAt,
    this.stravaAthleteId,
    this.stravaAthleteName,
  });

  final String? selectedGearId;
  final DateTime? lastSyncAt;
  final DateTime? lastSyncFrom;
  final String? stravaClientId;
  final String? stravaClientSecret;
  final String? stravaAccessToken;
  final String? stravaRefreshToken;
  final DateTime? stravaExpiresAt;
  final String? stravaAthleteId;
  final String? stravaAthleteName;

  bool get stravaConnected =>
      stravaAccessToken != null && stravaAccessToken!.isNotEmpty;

  AppSettings copyWith({
    String? selectedGearId,
    DateTime? lastSyncAt,
    DateTime? lastSyncFrom,
    String? stravaClientId,
    String? stravaClientSecret,
    String? stravaAccessToken,
    String? stravaRefreshToken,
    DateTime? stravaExpiresAt,
    String? stravaAthleteId,
    String? stravaAthleteName,
    bool clearGear = false,
    bool clearSync = false,
    bool clearTokens = false,
    bool clearClient = false,
  }) {
    return AppSettings(
      selectedGearId: clearGear ? null : (selectedGearId ?? this.selectedGearId),
      lastSyncAt: clearSync ? null : (lastSyncAt ?? this.lastSyncAt),
      lastSyncFrom: clearSync ? null : (lastSyncFrom ?? this.lastSyncFrom),
      stravaClientId: clearClient
          ? null
          : (stravaClientId ?? this.stravaClientId),
      stravaClientSecret: clearClient
          ? null
          : (stravaClientSecret ?? this.stravaClientSecret),
      stravaAccessToken: clearTokens
          ? null
          : (stravaAccessToken ?? this.stravaAccessToken),
      stravaRefreshToken: clearTokens
          ? null
          : (stravaRefreshToken ?? this.stravaRefreshToken),
      stravaExpiresAt: clearTokens
          ? null
          : (stravaExpiresAt ?? this.stravaExpiresAt),
      stravaAthleteId: clearTokens
          ? null
          : (stravaAthleteId ?? this.stravaAthleteId),
      stravaAthleteName: clearTokens
          ? null
          : (stravaAthleteName ?? this.stravaAthleteName),
    );
  }
}

class HistoryRow {
  const HistoryRow({
    required this.replacement,
    required this.used,
  });

  final Replacement replacement;
  final double used;
}

class AlertItem {
  const AlertItem({
    required this.partId,
    required this.label,
  });

  final String partId;
  final String label;
}
