import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/dates.dart';
import '../models/models.dart';
import 'strava_oauth.dart';

const bikeSportTypes = {
  'Ride',
  'VirtualRide',
  'EBikeRide',
  'EMountainBikeRide',
  'GravelRide',
  'MountainBikeRide',
  'Velomobile',
  'Handcycle',
};

const stravaActivitiesPerPage = 200;
const stravaMaxActivityPages = 20;

class StravaTokens {
  const StravaTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}

bool isBikeActivity(Map<String, dynamic> json) {
  final sport = '${json['sport_type'] ?? ''}';
  if (sport.isNotEmpty) {
    return bikeSportTypes.contains(sport);
  }
  return '${json['type'] ?? ''}' == 'Ride';
}

Ride? rideFromActivity(Map<String, dynamic> json) {
  if (!isBikeActivity(json)) {
    return null;
  }
  final id = '${json['id'] ?? ''}';
  if (id.isEmpty) {
    return null;
  }
  final startRaw = json['start_date'] as String?;
  if (startRaw == null || startRaw.isEmpty) {
    return null;
  }
  final started = DateTime.parse(startRaw).toUtc();
  final meters = (json['distance'] as num?)?.toDouble() ?? 0;
  final gear = '${json['gear_id'] ?? ''}';
  return Ride(
    id: id,
    gearId: gear,
    startedOn: dateOnly(started),
    distanceKm: meters / 1000,
  );
}

void throwIfStravaFailed(http.Response response) {
  if (response.statusCode == 429) {
    throw StravaAuthException('Strava の回数制限に当たりました。しばらくしてからやり直してください。');
  }
  if (response.statusCode == 401) {
    throw StravaAuthException('Strava の認可が無効です。Strava 連携の画面から再連携してください。');
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StravaAuthException('Strava からの取得に失敗しました（${response.statusCode}）');
  }
}

Future<StravaTokens> ensureAccessToken({
  required http.Client client,
  required String clientId,
  required String clientSecret,
  required String accessToken,
  required String refreshToken,
  required DateTime? expiresAt,
  DateTime? now,
}) async {
  final current = now ?? DateTime.now().toUtc();
  if (expiresAt != null &&
      expiresAt.isAfter(current.add(const Duration(minutes: 5)))) {
    return StravaTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }
  if (clientId.isEmpty || clientSecret.isEmpty) {
    throw StravaAuthException(
      'トークンの更新に Client ID と Secret が必要です。Strava 連携の画面を確認してください。',
    );
  }
  final refreshed = await refreshAccessToken(
    client: client,
    clientId: clientId,
    clientSecret: clientSecret,
    refreshToken: refreshToken,
  );
  return StravaTokens(
    accessToken: refreshed.accessToken,
    refreshToken: refreshed.refreshToken,
    expiresAt: refreshed.expiresAt,
  );
}

Future<List<Gear>> fetchAthleteBikes({
  required http.Client client,
  required String accessToken,
}) async {
  final response = await client.get(
    Uri.https('www.strava.com', '/api/v3/athlete'),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  throwIfStravaFailed(response);
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return parseStravaBikes(json['bikes']);
}

Future<List<Ride>> fetchBikeRides({
  required http.Client client,
  required String accessToken,
  required DateTime fromInclusive,
  required DateTime toInclusive,
}) async {
  final after = stravaAfterEpoch(fromInclusive);
  final before = stravaBeforeEpoch(toInclusive);
  final rides = <Ride>[];
  for (var page = 1; page <= stravaMaxActivityPages; page++) {
    final response = await client.get(
      Uri.https('www.strava.com', '/api/v3/athlete/activities', {
        'after': '$after',
        'before': '$before',
        'page': '$page',
        'per_page': '$stravaActivitiesPerPage',
      }),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    throwIfStravaFailed(response);
    final json = jsonDecode(response.body);
    if (json is! List) {
      throw StravaAuthException('走行一覧の応答が読み取れませんでした');
    }
    for (final item in json) {
      if (item is! Map) {
        continue;
      }
      final ride = rideFromActivity(Map<String, dynamic>.from(item));
      if (ride != null) {
        rides.add(ride);
      }
    }
    if (json.length < stravaActivitiesPerPage) {
      break;
    }
    if (page == stravaMaxActivityPages) {
      throw StravaAuthException(
        '一度に取れる量を超えました。期間を短くしてやり直してください。',
      );
    }
  }
  return rides;
}

class StravaSyncSummary {
  const StravaSyncSummary({
    required this.from,
    required this.to,
    required this.savedCount,
    this.newestRideOn,
  });

  final DateTime from;
  final DateTime to;
  final int savedCount;
  final DateTime? newestRideOn;
}
