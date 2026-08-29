import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../state/app_store.dart';
import '../strava/open_browser.dart';
import '../strava/strava_config.dart';
import '../strava/strava_oauth.dart';

class StravaConnectScreen extends StatefulWidget {
  const StravaConnectScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<StravaConnectScreen> createState() => _StravaConnectScreenState();
}

class _StravaConnectScreenState extends State<StravaConnectScreen> {
  late final TextEditingController _clientId;
  late final TextEditingController _clientSecret;
  late final TextEditingController _codePaste;
  final _http = http.Client();
  StravaLoopbackListener? _listener;
  String? _state;
  Uri? _authorizeUrl;
  String? _message;
  bool _busy = false;
  bool _waitingBrowser = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.store.settings;
    _clientId = TextEditingController(text: settings.stravaClientId ?? '');
    _clientSecret = TextEditingController(text: settings.stravaClientSecret ?? '');
    _codePaste = TextEditingController();
    _fillFromFile();
  }

  Future<void> _fillFromFile() async {
    if (_clientId.text.isNotEmpty && _clientSecret.text.isNotEmpty) {
      return;
    }
    final loaded = await resolveStravaCredentials(
      storedClientId: widget.store.settings.stravaClientId,
      storedClientSecret: widget.store.settings.stravaClientSecret,
    );
    if (!mounted || loaded == null) {
      return;
    }
    setState(() {
      if (_clientId.text.isEmpty) {
        _clientId.text = loaded.clientId;
      }
      if (_clientSecret.text.isEmpty) {
        _clientSecret.text = loaded.clientSecret;
      }
    });
  }

  @override
  void dispose() {
    _listener?.cancel();
    _http.close();
    _clientId.dispose();
    _clientSecret.dispose();
    _codePaste.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final connected = widget.store.settings.stravaConnected;
        final athlete = widget.store.settings.stravaAthleteName;
        return Scaffold(
          appBar: AppBar(title: const Text('Strava 連携')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                connected ? '連携済み' : '未連携',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (athlete != null && athlete.isNotEmpty)
                Text(athlete, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Text('Client ID', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              TextField(
                controller: _clientId,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Strava のアプリ登録で発行される番号',
                ),
              ),
              const SizedBox(height: 12),
              Text('Client Secret', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              TextField(
                controller: _clientSecret,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Strava のアプリ登録で Show すると出る値',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _connect,
                child: Text(connected ? '再連携' : '連携する'),
              ),
              if (_waitingBrowser) ...[
                const SizedBox(height: 12),
                const Text(
                  'ブラウザで許可したあと、アプリに戻ります。'
                  '戻らないときは、このあとに出る欄へブラウザのアドレス欄を貼ってください。',
                ),
                if (_authorizeUrl != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    _authorizeUrl.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _authorizeUrl.toString()),
                      );
                      if (mounted) {
                        setState(
                          () => _message =
                              '許可用の URL をコピーしました。スマホのブラウザで開いてください。',
                        );
                      }
                    },
                    child: const Text('許可用 URL をコピー'),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _codePaste,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'http://127.0.0.1:8742/callback?code=... または code',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _submitPastedCode,
                  child: const Text('貼ったコードで続ける'),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy || !connected ? null : _disconnect,
                child: const Text('連携を解除'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!),
              ],
              const SizedBox(height: 24),
              Text('連携方法', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '1. Strava の API 設定でアプリを作る',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SelectableText('https://www.strava.com/settings/api'),
              Text(
                'Standard Tier の API は、Strava の有料サブスクが必要です。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                '2. Authorization Callback Domain は 127.0.0.1',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'http もポートもパスも付けない。戻り先は次で固定です。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SelectableText(stravaRedirectUri),
              const SizedBox(height: 12),
              Text(
                '3. Client ID と Client Secret を上に入れる',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'このアプリでは Access Token は使いません。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                '4. 「連携する」を押し、ブラウザで許可する',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '成功すると「連携済み」と自分の名前が出ます。走行の取得はホームの「Strava同期」から。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                '5. ブラウザからアプリに戻らないとき',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '「連携する」を押したあとに出る欄へ、スマホのブラウザのアドレス欄（code= を含む）を貼り、「貼ったコードで続ける」。'
                'ブラウザが開かないときは「許可用 URL をコピー」して、スマホのブラウザで開く。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _connect() async {
    final clientId = _clientId.text.trim();
    final clientSecret = _clientSecret.text.trim();
    if (clientId.isEmpty || clientSecret.isEmpty) {
      setState(() => _message = 'Client ID と Client Secret を入力してください。');
      return;
    }
    setState(() {
      _busy = true;
      _message = 'ブラウザで Strava の許可を待っています…';
      _waitingBrowser = true;
    });
    await widget.store.saveStravaCredentials(
      clientId: clientId,
      clientSecret: clientSecret,
    );
    _state = newOAuthState();
    final url = stravaAuthorizeUrl(clientId: clientId, state: _state!);
    _authorizeUrl = url;
    _listener = StravaLoopbackListener();
    try {
      await _listener!.start();
    } on SocketException {
      setState(() {
        _busy = false;
        _message =
            'ポート $stravaListenPort を開けませんでした。他のプロセスを終了するか、アドレス欄を貼ってください。';
      });
      return;
    }
    final opened = await openInBrowser(url);
    if (mounted) {
      setState(() {
        _message = opened
            ? 'ブラウザで Strava の許可を待っています…'
            : 'ブラウザを自動では開けませんでした。下の「許可用 URL をコピー」をスマホのブラウザで開いてください。';
      });
    }
    try {
      final redirected = await _listener!.waitForRedirect();
      final code = extractAuthorizationCode(redirected, expectedState: _state!);
      await _finishWithCode(code, clientId, clientSecret);
    } on StravaAuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _message = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _message = '$e';
      });
    }
  }

  Future<void> _submitPastedCode() async {
    final clientId = _clientId.text.trim();
    final clientSecret = _clientSecret.text.trim();
    try {
      setState(() => _busy = true);
      final code = extractAuthorizationCodeFromPaste(
        _codePaste.text,
        expectedState: _state,
      );
      await _finishWithCode(code, clientId, clientSecret);
    } on StravaAuthException catch (e) {
      setState(() {
        _busy = false;
        _message = e.message;
      });
    }
  }

  Future<void> _finishWithCode(
    String code,
    String clientId,
    String clientSecret,
  ) async {
    final result = await exchangeAuthorizationCode(
      client: _http,
      clientId: clientId,
      clientSecret: clientSecret,
      code: code,
    );
    await widget.store.saveStravaAuth(result);
    await _listener?.cancel();
    _listener = null;
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _waitingBrowser = false;
      _message = 'トークンを端末に保存しました（${result.athleteName}）。';
    });
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    final token = widget.store.settings.stravaAccessToken;
    if (token != null) {
      try {
        await deauthorizeStrava(client: _http, accessToken: token);
      } catch (_) {}
    }
    await widget.store.disconnectStrava();
    await _listener?.cancel();
    _listener = null;
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _waitingBrowser = false;
      _message = '連携を解除し、トークンを消しました。';
    });
  }
}
