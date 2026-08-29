import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_store.dart';
import '../widgets/widgets.dart';

class DisplayGroupScreen extends StatefulWidget {
  const DisplayGroupScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<DisplayGroupScreen> createState() => _DisplayGroupScreenState();
}

class _DisplayGroupScreenState extends State<DisplayGroupScreen> {
  bool _combine = true;
  final List<String> _picked = [];
  String? _frontId;
  final _name = TextEditingController();
  String? _dissolveId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('表示のまとめ')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'ホームでは1行にまとめます。部品そのものは分かれています。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SelectTile(
                      selected: _combine,
                      title: 'まとめて表示',
                      onTap: () => setState(() => _combine = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectTile(
                      selected: !_combine,
                      title: '分けて表示',
                      onTap: () => setState(() => _combine = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_combine) _combineForm() else _separateForm(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _combineForm() {
    final candidates = widget.store.ungroupedParts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('1. 2つの部品を選ぶ', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        if (candidates.length < 2)
          const Text('まとめられる部品が足りません。先に登録名で2件追加してください。'),
        for (final part in candidates) ...[
          SelectTile(
            selected: _picked.contains(part.id),
            title: _picked.contains(part.id)
                ? '${part.registeredName}（選択）'
                : part.registeredName,
            onTap: () => _toggle(part.id),
          ),
          const SizedBox(height: 8),
        ],
        Text('2. どちらが F か', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final id in _picked) ...[
              Expanded(
                child: SelectTile(
                  selected: _frontId == id,
                  title: '${_nameOf(id)} が F',
                  onTap: () => setState(() => _frontId = id),
                ),
              ),
              if (id != _picked.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text('3. まとめた名前', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'タイヤ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        Text(
          'ホームは「${_name.text.isEmpty ? '（名前）' : _name.text}」。左が R、右が F',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saveCombine,
          child: const Text('まとめて表示'),
        ),
      ],
    );
  }

  Widget _separateForm() {
    final groups = widget.store.groups;
    if (groups.isEmpty) {
      return const Text('まとめ表示はありません。');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('解除するまとめ', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        for (final group in groups) ...[
          SelectTile(
            selected: _dissolveId == group.id,
            title: group.displayName,
            subtitle:
                '${_nameOf(group.rearPartId)} / ${_nameOf(group.frontPartId)}',
            onTap: () => setState(() => _dissolveId = group.id),
          ),
          const SizedBox(height: 8),
        ],
        if (_selectedGroup != null) ...[
          Text(
            '「${_selectedGroup!.displayName}」のまとめ表示をやめます。各カードは登録名で出します。',
          ),
          const SizedBox(height: 8),
          Text('分かれたあとの表示（登録名）', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            _nameOf(_selectedGroup!.rearPartId),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            _nameOf(_selectedGroup!.frontPartId),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '登録名は変えない。末尾に F/R を付ける合わせこみはしない',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _saveSeparate,
          child: const Text('分けて表示'),
        ),
      ],
    );
  }

  DisplayGroup? get _selectedGroup {
    for (final group in widget.store.groups) {
      if (group.id == _dissolveId) {
        return group;
      }
    }
    return null;
  }

  String _nameOf(String partId) {
    return widget.store.partById(partId)?.registeredName ?? partId;
  }

  void _toggle(String id) {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
      } else if (_picked.length >= 2) {
        _picked
          ..removeAt(0)
          ..add(id);
      } else {
        _picked.add(id);
      }
      if (_frontId != null && !_picked.contains(_frontId)) {
        _frontId = _picked.isEmpty ? null : _picked.first;
      }
      if (_frontId == null && _picked.isNotEmpty) {
        _frontId = _picked.first;
      }
    });
  }

  Future<void> _saveCombine() async {
    if (_picked.length != 2 || _frontId == null) {
      setState(() => _error = '2つの部品と、どちらが F かを選んでください');
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'まとめた名前を入力してください');
      return;
    }
    final rearId = _picked.firstWhere((id) => id != _frontId);
    final front = widget.store.partById(_frontId!);
    final rear = widget.store.partById(rearId);
    if (front == null || rear == null) {
      setState(() => _error = '部品が見つかりません');
      return;
    }
    if (front.cycle != rear.cycle) {
      setState(() => _error = '同じ交換周期の部品だけをまとめられます');
      return;
    }
    await widget.store.combineDisplay(
      frontPartId: front.id,
      rearPartId: rear.id,
      displayName: name,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveSeparate() async {
    final group = _selectedGroup;
    if (group == null) {
      setState(() => _error = '解除するまとめを選んでください');
      return;
    }
    await widget.store.dissolveGroup(group.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
