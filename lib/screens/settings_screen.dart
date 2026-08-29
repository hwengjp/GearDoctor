import 'package:flutter/material.dart';

import '../app_version.dart';
import '../state/app_store.dart';
import 'gear_screen.dart';
import 'strava_connect_screen.dart';
import 'sync_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _message;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final connected = widget.store.settings.stravaConnected;
        final athlete = widget.store.settings.stravaAthleteName;
        return Scaffold(
          appBar: AppBar(title: const Text('設定')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Strava', style: Theme.of(context).textTheme.bodySmall),
              Text(
                connected ? '連携済み' : '未連携',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (athlete != null && athlete.isNotEmpty)
                Text(athlete, style: Theme.of(context).textTheme.bodySmall),
              Text(
                '連携すると走行を取れます。手順は次の画面。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StravaConnectScreen(store: widget.store),
                    ),
                  );
                },
                child: const Text('Strava 連携'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SyncScreen(store: widget.store),
                    ),
                  );
                },
                child: const Text('Strava同期'),
              ),
              const SizedBox(height: 16),
              Text('ギア', style: Theme.of(context).textTheme.bodySmall),
              Text(
                '距離を足す自転車と、そのギアの交換記録です。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GearScreen(store: widget.store),
                    ),
                  );
                },
                child: const Text('ギア'),
              ),
              const SizedBox(height: 16),
              Text('初期化', style: Theme.of(context).textTheme.bodySmall),
              Text(
                'Strava の連携と走行、部品の設定と交換記録を消し、初回と同じデモ状態に戻します。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _confirmResetToDemo,
                child: const Text('初期状態に戻す'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!),
              ],
              const SizedBox(height: 24),
              Text(
                appVersionLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmResetToDemo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('初期状態に戻しますか？'),
          content: const Text(
            'Strava の連携と走行、部品の設定と交換記録をすべて消します。\n\n'
            '初回起動と同じデモ状態に戻ります。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('消して戻す'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    await widget.store.resetToDemo();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _message = '初期状態に戻しました。';
    });
  }
}
