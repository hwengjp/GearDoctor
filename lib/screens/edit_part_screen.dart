import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/dates.dart';
import '../domain/recommendations.dart';
import '../models/models.dart';
import '../state/app_store.dart';
import '../widgets/widgets.dart';

class EditPartScreen extends StatefulWidget {
  const EditPartScreen({super.key, required this.store, this.partId});

  final AppStore store;
  final String? partId;

  @override
  State<EditPartScreen> createState() => _EditPartScreenState();
}

class _EditPartScreenState extends State<EditPartScreen> {
  late final TextEditingController _name;
  late final TextEditingController _custom;
  late final TextEditingController _threshold;
  late CycleKind _cycle;
  late LimitMode _mode;
  late int _recommended;
  String? _error;

  bool get _isNew => widget.partId == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.partId == null
        ? null
        : widget.store.partById(widget.partId!);
    _name = TextEditingController(text: existing?.registeredName ?? '');
    _cycle = existing?.cycle ?? CycleKind.distance;
    _mode = existing?.limitMode ?? LimitMode.recommended;
    _recommended =
        existing?.recommendedLimit ??
        recommendedLimitFor(_name.text, _cycle);
    _custom = TextEditingController(
      text: (existing?.customLimit ?? _recommended).toString(),
    );
    _threshold = TextEditingController(
      text: (existing?.thresholdPct ?? 80).toString(),
    );
    _name.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _custom.dispose();
    _threshold.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (!_isNew) {
      return;
    }
    setState(() {
      _recommended = recommendedLimitFor(_name.text, _cycle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unit = _cycle.unitLabel;
    final existing = widget.partId == null
        ? null
        : widget.store.partById(widget.partId!);
    final previous = existing == null
        ? null
        : widget.store.previousCycleOf(
            existing.copyWith(cycle: _cycle),
          );
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? '部品を追加' : '部品を編集')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('登録名', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '登録名（前タイヤ、心拍計電池など）',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ホームに出す名前。前と後ろは別々に登録します。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_isNew) ...[
            const SizedBox(height: 4),
            Text(
              widget.store.settings.lastSyncFrom == null
                  ? '最初の交換日は開始日です。まだ開始日が無いときは今日になります。'
                  : '最初の交換日は開始日（${formatDate(widget.store.settings.lastSyncFrom!)}）です。入力しません。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          Text('交換周期', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '距離か月のどちらか。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectTile(
                  selected: _cycle == CycleKind.distance,
                  title: '距離',
                  onTap: () => _setCycle(CycleKind.distance),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectTile(
                  selected: _cycle == CycleKind.months,
                  title: '月',
                  onTap: () => _setCycle(CycleKind.months),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('交換目安', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          SelectTile(
            selected: _mode == LimitMode.recommended,
            title: '推奨  ${formatAmount(_recommended)} $unit',
            subtitle: '名前から自動で決まります。',
            onTap: () => setState(() => _mode = LimitMode.recommended),
          ),
          const SizedBox(height: 8),
          SelectTile(
            selected: _mode == LimitMode.previousCycle,
            title: previous == null
                ? '前回交換周期から計算  —'
                : '前回交換周期から計算  ${formatAmount(previous)} $unit',
            subtitle: '直近の2回の間隔。毎回計算',
            onTap: () => setState(() => _mode = LimitMode.previousCycle),
          ),
          const SizedBox(height: 8),
          SelectTile(
            selected: _mode == LimitMode.custom,
            title: '設定  ${_custom.text.isEmpty ? '—' : _custom.text} $unit',
            subtitle: '自分で入力します。',
            onTap: () => setState(() => _mode = LimitMode.custom),
          ),
          if (_mode == LimitMode.custom) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _custom,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixText: unit,
                labelText: '設定値',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),
          Text('通知しきい値', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          TextField(
            controller: _threshold,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixText: '%',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }

  void _setCycle(CycleKind cycle) {
    setState(() {
      _cycle = cycle;
      _recommended = _isNew
          ? recommendedLimitFor(_name.text, cycle)
          : _recommendedForExisting(cycle);
      if (_custom.text.isEmpty) {
        _custom.text = _recommended.toString();
      }
    });
  }

  int _recommendedForExisting(CycleKind cycle) {
    final existing = widget.store.partById(widget.partId!);
    if (existing != null && existing.cycle == cycle) {
      return existing.recommendedLimit;
    }
    return recommendedLimitFor(_name.text, cycle);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    var custom = int.tryParse(_custom.text);
    final threshold = int.tryParse(_threshold.text);
    if (name.isEmpty) {
      setState(() => _error = '登録名を入力してください');
      return;
    }
    if (_mode == LimitMode.custom && (custom == null || custom <= 0)) {
      setState(() => _error = '設定の目安は 1 以上の数値にしてください');
      return;
    }
    custom ??= _recommended;
    if (custom <= 0) {
      custom = _recommended;
    }
    if (threshold == null || threshold < 1 || threshold > 100) {
      setState(() => _error = 'しきい値は 1 から 100 の整数です');
      return;
    }
    final existing = widget.partId == null
        ? null
        : widget.store.partById(widget.partId!);
    final part = Part(
      id: existing?.id ?? widget.store.newId('p'),
      registeredName: name,
      cycle: _cycle,
      limitMode: _mode,
      recommendedLimit: _recommended,
      customLimit: custom,
      thresholdPct: threshold,
      sortOrder: existing?.sortOrder ?? widget.store.nextSortOrder(),
    );
    await widget.store.savePart(part, isNew: _isNew);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
