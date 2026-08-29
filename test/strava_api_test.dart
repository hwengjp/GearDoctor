import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gear_doctor/domain/dates.dart';
import 'package:gear_doctor/strava/strava_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('rideFromActivity keeps bike rides and skips runs', () {
    final ride = rideFromActivity({
      'id': 99,
      'sport_type': 'Ride',
      'distance': 12345,
      'start_date': '2025-08-01T08:30:00Z',
      'gear_id': 'b1',
    });
    expect(ride, isNotNull);
    expect(ride!.id, '99');
    expect(ride.gearId, 'b1');
    expect(ride.distanceKm, 12.345);
    expect(formatDate(ride.startedOn), '2025-08-01');

    expect(
      rideFromActivity({
        'id': 100,
        'sport_type': 'Run',
        'distance': 5000,
        'start_date': '2025-08-01T08:30:00Z',
      }),
      isNull,
    );
  });

  test('nextSyncWindow starts from fetched-through and caps at today', () {
    final window = nextSyncWindow(
      startDate: parseDate('2025-07-17'),
      fetchedThrough: null,
      months: 1,
      today: parseDate('2026-08-23'),
    );
    expect(formatDate(window.fromInclusive), '2025-07-17');
    expect(formatDate(window.toInclusive), '2025-08-17');

    final next = nextSyncWindow(
      startDate: parseDate('2025-07-17'),
      fetchedThrough: parseDate('2025-08-17'),
      months: 1,
      today: parseDate('2026-08-23'),
    );
    expect(formatDate(next.fromInclusive), '2025-08-17');
    expect(formatDate(next.toInclusive), '2025-09-17');

    final capped = nextSyncWindow(
      startDate: parseDate('2026-08-01'),
      fetchedThrough: parseDate('2026-08-01'),
      months: 12,
      today: parseDate('2026-08-23'),
    );
    expect(formatDate(capped.toInclusive), '2026-08-23');
  });

  test('fetchBikeRides paginates and ignores non-bike sports', () async {
    var pages = 0;
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v3/athlete/activities');
      expect(request.headers['Authorization'], 'Bearer tok');
      pages += 1;
      if (request.url.queryParameters['page'] == '1') {
        final items = List.generate(
          200,
          (index) => {
            'id': index + 1,
            'sport_type': 'Ride',
            'distance': 1000,
            'start_date': '2025-08-01T00:00:00Z',
            'gear_id': 'b1',
          },
        );
        return http.Response(
          jsonEncode(items),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode([
          {
            'id': 201,
            'sport_type': 'Ride',
            'distance': 2000,
            'start_date': '2025-08-02T00:00:00Z',
            'gear_id': 'b1',
          },
          {
            'id': 202,
            'sport_type': 'Run',
            'distance': 5000,
            'start_date': '2025-08-02T00:00:00Z',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final rides = await fetchBikeRides(
      client: client,
      accessToken: 'tok',
      fromInclusive: parseDate('2025-07-17'),
      toInclusive: parseDate('2025-08-17'),
    );
    expect(pages, 2);
    expect(rides.length, 201);
    expect(rides.last.id, '201');
  });
}
