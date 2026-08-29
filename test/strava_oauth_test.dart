import 'package:flutter_test/flutter_test.dart';
import 'package:gear_doctor/strava/strava_config.dart';
import 'package:gear_doctor/strava/strava_oauth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('authorize URL uses localhost callback and state', () {
    final url = stravaAuthorizeUrl(clientId: '99', state: 'abc');
    expect(url.host, 'www.strava.com');
    expect(url.queryParameters['client_id'], '99');
    expect(url.queryParameters['redirect_uri'], stravaRedirectUri);
    expect(url.queryParameters['state'], 'abc');
    expect(url.queryParameters['scope'], contains('activity:read_all'));
  });

  test('extracts code from redirect and rejects mismatch', () {
    final uri = Uri.parse(
      '$stravaRedirectUri?state=s1&code=CODE123&scope=read,activity:read_all',
    );
    expect(extractAuthorizationCode(uri, expectedState: 's1'), 'CODE123');
    expect(
      () => extractAuthorizationCode(uri, expectedState: 'other'),
      throwsA(isA<StravaAuthException>()),
    );
  });

  test('paste accepts full URL or raw code', () {
    expect(
      extractAuthorizationCodeFromPaste(
        '$stravaRedirectUri?code=XYZ&state=s1',
        expectedState: 's1',
      ),
      'XYZ',
    );
    expect(extractAuthorizationCodeFromPaste('XYZ'), 'XYZ');
  });

  test('token exchange parses athlete and bikes', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'www.strava.com');
      expect(request.url.path, '/oauth/token');
      expect(request.body, contains('grant_type=authorization_code'));
      expect(request.body, contains('code=CODE123'));
      return http.Response(
        '''
{
  "token_type": "Bearer",
  "expires_at": 1893456000,
  "expires_in": 21600,
  "refresh_token": "refresh-1",
  "access_token": "access-1",
  "athlete": {
    "id": 42,
    "firstname": "Ken",
    "lastname": "Rider",
    "bikes": [{"id": "b1", "name": "Aeroad"}]
  }
}
''',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await exchangeAuthorizationCode(
      client: client,
      clientId: '99',
      clientSecret: 'secret',
      code: 'CODE123',
    );
    expect(result.accessToken, 'access-1');
    expect(result.refreshToken, 'refresh-1');
    expect(result.athleteName, 'Ken Rider');
    expect(result.bikes.single.name, 'Aeroad');
  });
}
