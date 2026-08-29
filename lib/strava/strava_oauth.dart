import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'strava_config.dart';

class StravaAuthResult {
  const StravaAuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.athleteId,
    required this.athleteName,
    this.bikes = const [],
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String athleteId;
  final String athleteName;
  final List<Gear> bikes;
}

class StravaAuthException implements Exception {
  StravaAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

Uri stravaAuthorizeUrl({
  required String clientId,
  required String state,
  String redirectUri = stravaRedirectUri,
  String scope = stravaAuthScope,
}) {
  return Uri.https('www.strava.com', '/oauth/authorize', {
    'client_id': clientId,
    'response_type': 'code',
    'redirect_uri': redirectUri,
    'approval_prompt': 'auto',
    'scope': scope,
    'state': state,
  });
}

String newOAuthState() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes);
}

String extractAuthorizationCode(
  Uri redirected, {
  required String expectedState,
}) {
  final error = redirected.queryParameters['error'];
  if (error != null && error.isNotEmpty) {
    throw StravaAuthException(
      error == 'access_denied' ? '認可が取り消されました' : '認可に失敗しました（$error）',
    );
  }
  final state = redirected.queryParameters['state'];
  if (state != expectedState) {
    throw StravaAuthException('認可の戻り値が一致しません。もう一度連携してください。');
  }
  final code = redirected.queryParameters['code'];
  if (code == null || code.isEmpty) {
    throw StravaAuthException('認可コードがありません。アドレス欄の code= を確認してください。');
  }
  return code;
}

/// ブラウザが WSL に戻ってこないとき用。URL 全体でも code だけでも受け付ける。
String extractAuthorizationCodeFromPaste(String pasted, {String? expectedState}) {
  final trimmed = pasted.trim();
  if (trimmed.isEmpty) {
    throw StravaAuthException('コードを貼ってください');
  }
  if (trimmed.contains('://') || trimmed.contains('code=')) {
    final uri = Uri.parse(trimmed.contains('://') ? trimmed : 'http://local/?$trimmed');
    if (expectedState != null && uri.queryParameters.containsKey('state')) {
      return extractAuthorizationCode(uri, expectedState: expectedState);
    }
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StravaAuthException('貼った内容から code を読めませんでした');
    }
    return code;
  }
  return trimmed;
}

Future<StravaAuthResult> exchangeAuthorizationCode({
  required http.Client client,
  required String clientId,
  required String clientSecret,
  required String code,
}) async {
  final response = await client.post(
    Uri.parse('https://www.strava.com/oauth/token'),
    body: {
      'client_id': clientId,
      'client_secret': clientSecret,
      'code': code,
      'grant_type': 'authorization_code',
    },
  );
  return parseTokenResponse(response);
}

StravaAuthResult parseTokenResponse(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StravaAuthException('トークンの取得に失敗しました（${response.statusCode}）');
  }
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final access = json['access_token'] as String?;
  final refresh = json['refresh_token'] as String?;
  final expires = json['expires_at'];
  if (access == null || refresh == null || expires == null) {
    throw StravaAuthException('トークンの応答が不完全です');
  }
  final athlete = json['athlete'] as Map<String, dynamic>? ?? {};
  final first = '${athlete['firstname'] ?? ''}'.trim();
  final last = '${athlete['lastname'] ?? ''}'.trim();
  final name = '$first $last'.trim();
  return StravaAuthResult(
    accessToken: access,
    refreshToken: refresh,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      (expires as num).toInt() * 1000,
      isUtc: true,
    ),
    athleteId: '${athlete['id'] ?? ''}',
    athleteName: name.isEmpty ? 'Strava ユーザー' : name,
    bikes: parseStravaBikes(athlete['bikes']),
  );
}

List<Gear> parseStravaBikes(Object? rawBikes) {
  final bikes = <Gear>[];
  if (rawBikes is! List) {
    return bikes;
  }
  for (final item in rawBikes) {
    if (item is! Map) {
      continue;
    }
    final id = '${item['id'] ?? ''}';
    final bikeName = '${item['name'] ?? ''}';
    if (id.isNotEmpty && bikeName.isNotEmpty) {
      bikes.add(Gear(id: id, name: bikeName));
    }
  }
  return bikes;
}

Future<StravaAuthResult> refreshAccessToken({
  required http.Client client,
  required String clientId,
  required String clientSecret,
  required String refreshToken,
}) async {
  final response = await client.post(
    Uri.parse('https://www.strava.com/oauth/token'),
    body: {
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'grant_type': 'refresh_token',
    },
  );
  return parseTokenResponse(response);
}

Future<void> deauthorizeStrava({
  required http.Client client,
  required String accessToken,
}) async {
  await client.post(
    Uri.parse('https://www.strava.com/oauth/deauthorize'),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
}

/// PC 上で localhost に戻りを受ける。
class StravaLoopbackListener {
  StravaLoopbackListener({
    this.port = stravaListenPort,
    this.redirectUri = stravaRedirectUri,
  });

  final int port;
  final String redirectUri;
  HttpServer? _server;
  Completer<Uri>? _completer;

  Future<void> start() async {
    await cancel();
    _completer = Completer<Uri>();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen((request) async {
      final incoming = request.uri;
      final uri = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: port,
        path: incoming.path,
        query: incoming.query,
      );
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><meta charset="utf-8"><title>GearDoctor</title>'
          '<p>GearDoctor に連携しました。このタブを閉じてアプリに戻ってください。</p>',
        );
      await request.response.close();
      if (!(_completer?.isCompleted ?? true)) {
        _completer!.complete(uri);
      }
    });
  }

  Future<Uri> waitForRedirect({
    Duration timeout = const Duration(minutes: 5),
  }) {
    final completer = _completer;
    if (completer == null) {
      throw StravaAuthException('待ち受けを開始していません');
    }
    return completer.future.timeout(
      timeout,
      onTimeout: () => throw StravaAuthException(
        'ブラウザからの戻りを待ちきれませんでした。アドレス欄を貼ってください。',
      ),
    );
  }

  Future<void> cancel() async {
    await _server?.close(force: true);
    _server = null;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(StravaAuthException('連携を中止しました'));
    }
    _completer = null;
  }
}
