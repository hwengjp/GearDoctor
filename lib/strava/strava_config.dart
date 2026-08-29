import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// PC 上の認可で使う固定の戻り先。Strava の Callback Domain は `127.0.0.1`。
const stravaRedirectUri = 'http://127.0.0.1:8742/callback';
const stravaListenPort = 8742;
const stravaAuthScope = 'read,activity:read_all,profile:read_all';

class StravaAppCredentials {
  const StravaAppCredentials({required this.clientId, required this.clientSecret});

  final String clientId;
  final String clientSecret;

  bool get isComplete => clientId.isNotEmpty && clientSecret.isNotEmpty;
}

StravaAppCredentials? credentialsFromDefines() {
  const id = String.fromEnvironment('STRAVA_CLIENT_ID');
  const secret = String.fromEnvironment('STRAVA_CLIENT_SECRET');
  if (id.isEmpty || secret.isEmpty) {
    return null;
  }
  return const StravaAppCredentials(clientId: id, clientSecret: secret);
}

Future<StravaAppCredentials?> loadStravaSecretsFile() async {
  final envId = Platform.environment['STRAVA_CLIENT_ID'];
  final envSecret = Platform.environment['STRAVA_CLIENT_SECRET'];
  if (envId != null &&
      envId.isNotEmpty &&
      envSecret != null &&
      envSecret.isNotEmpty) {
    return StravaAppCredentials(clientId: envId, clientSecret: envSecret);
  }

  final candidates = <String>[
    p.join(Directory.current.path, 'strava_secrets.json'),
    p.join(p.dirname(Platform.resolvedExecutable), 'strava_secrets.json'),
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final id = '${json['clientId'] ?? ''}';
    final secret = '${json['clientSecret'] ?? ''}';
    if (id.isNotEmpty && secret.isNotEmpty) {
      return StravaAppCredentials(clientId: id, clientSecret: secret);
    }
  }
  return null;
}

Future<StravaAppCredentials?> resolveStravaCredentials({
  String? storedClientId,
  String? storedClientSecret,
}) async {
  if (storedClientId != null &&
      storedClientId.isNotEmpty &&
      storedClientSecret != null &&
      storedClientSecret.isNotEmpty) {
    return StravaAppCredentials(
      clientId: storedClientId,
      clientSecret: storedClientSecret,
    );
  }
  return credentialsFromDefines() ?? await loadStravaSecretsFile();
}
