import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../domain/dates.dart';
import '../state/app_store.dart';
import '../strava/strava_oauth.dart';
import '../widgets/widgets.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  String? _message;
  bool _busy = false;
  final _http = http.Client();

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final from = widget.store.settings.lastSyncFrom;
        final to = widget.store.newestSyncedOn;
        final hasStart = from != null;
        return Scaffold(
          appBar: AppBar(title: const Text('Strava 同期')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RangeSummary(
                from: from,
                to: to,
                demo: widget.store.usingDemoRides,
              ),
              const SizedBox(height: 8),
              Text(
                '何日までは、Strava開始日以降で入っているいちばん新しい走行の日です。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              const Text('期間を選んで取得します。自動では取りに行きません。'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : () => _syncForward(months: 3),
                child: const Text('前回から 3 か月'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _syncForward(months: 6),
                child: const Text('前回から 6 か月'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _syncForward(months: 12),
                child: const Text('前回から 1 年'),
              ),
              const SizedBox(height: 32),
              Text(
                'Strava開始日を変えると、取り込んだ走行は消えて初期化されます。新しい日から取り直します。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _changeStartDate,
                child: Text(hasStart ? 'Strava開始日を変更' : 'Strava開始日を指定'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _syncForward({required int months}) async {
    if (widget.store.settings.lastSyncFrom == null) {
      setState(() => _message = '先にStrava開始日を指定してください。');
      return;
    }
    if (!widget.store.settings.stravaConnected) {
      setState(() => _message = '先に Strava 連携の画面から連携してください。');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final summary = await widget.store.syncForward(
        months: months,
        client: _http,
      );
      if (!mounted) {
        return;
      }
      final newest = summary.newestRideOn;
      setState(() {
        _busy = false;
        _message = newest == null
            ? '${formatDate(summary.from)} から ${formatDate(summary.to)} まで取得しました。この期間に自転車の走行はありませんでした。'
            : '${formatDate(summary.from)} から ${formatDate(summary.to)} まで取得しました。自転車の走行 ${summary.savedCount} 件。いちばん新しい走行は ${formatDate(newest)} です。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _message = error is StravaAuthException ? error.message : '$error';
      });
    }
  }

  Future<void> _changeStartDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate:
          widget.store.settings.lastSyncFrom ?? widget.store.now,
      lastDate: widget.store.now,
      currentDate: widget.store.now,
    );
    if (picked == null || !mounted) {
      return;
    }
    final next = DateTime.utc(picked.year, picked.month, picked.day);
    final current = widget.store.settings.lastSyncFrom;
    if (current != null && dateOnly(current) == next) {
      setState(() => _message = 'Strava開始日は同じです。');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Strava開始日を変えますか？'),
          content: Text(
            'Strava開始日を ${formatDate(next)} にします。\n\n'
            'Strava開始日から、入っているいちばん新しい走行まで、抜けなく取れている必要があります。'
            '途中でStrava開始日だけ変えると、取得に抜けが出ることがあります。\n\n'
            'いま入っている走行データをすべて消してから、新しいStrava開始日から取り直します。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('消して続ける'),
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
    await widget.store.changeSyncStart(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _message = 'Strava開始日を ${formatDate(next)} にしました。走行データは消してあります。ここから取り直してください。';
    });
  }
}

class _RangeSummary extends StatelessWidget {
  const _RangeSummary({required this.from, required this.to, required this.demo});

  final DateTime? from;
  final DateTime? to;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    if (from == null && to == null) {
      return Text('未同期', style: Theme.of(context).textTheme.titleMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('データの範囲', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(
          markDemo(
            'Strava開始日  ${from == null ? '—' : formatDate(from!)}',
            demo: demo,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          markDemo(
            '何日まで  ${to == null ? '—' : formatDate(to!)}',
            demo: demo,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
