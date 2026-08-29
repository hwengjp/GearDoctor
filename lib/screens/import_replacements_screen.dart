import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/seed.dart';
import '../domain/dates.dart';
import '../domain/replacement_csv.dart';
import '../state/app_store.dart';
import '../widgets/widgets.dart';

class ImportReplacementsScreen extends StatefulWidget {
  const ImportReplacementsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ImportReplacementsScreen> createState() =>
      _ImportReplacementsScreenState();
}

class _ImportReplacementsScreenState extends State<ImportReplacementsScreen> {
  final _csv = TextEditingController();
  ReplacementCsvParseResult? _parsed;
  ReplacementImportPlan? _plan;
  String? _message;

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final names = widget.store.parts
            .map((part) => part.registeredName)
            .toList();
        final selected = widget.store.selectedGear;
        final canManage = widget.store.canManageRecords;
        final gearLabel = selected == null
            ? '未選択'
            : demoGearLabel(selected.name, demo: isDemoGearId(selected.id));
        return Scaffold(
          appBar: AppBar(title: const Text('記録の CSV')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                gearLabel,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                canManage
                    ? 'このギアの交換記録だけを出し入れします。他のギアの記録はそのままです。'
                    : 'Strava から自転車を取って選ぶと、この画面が使えます。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('いまの登録名', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                names.isEmpty ? '先に部品を追加してください。' : names.join('、'),
              ),
              const SizedBox(height: 16),
              const Text('入力欄に出してコピーします。'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: canManage ? _export : null,
                child: const Text('いまの記録を書き出す'),
              ),
              const SizedBox(height: 16),
              Text('CSV', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              TextField(
                controller: _csv,
                enabled: canManage,
                minLines: 8,
                maxLines: 16,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '登録名,交換日,メモ',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: canManage
                    ? () async {
                        if (await _blockIfDemo()) {
                          return;
                        }
                        setState(() {
                          _csv.text = replacementCsvExample(
                            defaultParts()
                                .map((part) => part.registeredName)
                                .toList(),
                            startDate: widget.store.partOriginOn,
                          );
                          _parsed = null;
                          _plan = null;
                          _message = null;
                        });
                      }
                    : null,
                child: const Text('例を入れる'),
              ),
              const SizedBox(height: 8),
              const Text(
                '部品は増えません。登録名（前タイヤ）で結びます。CSV に出た部品の、このギアの記録は差し替えます。',
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: canManage ? _preview : null,
                child: const Text('CSVを取り込み'),
              ),
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('直せること', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final error in _errors) Text(error),
              ],
              if (_plan != null && _errors.isEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '差し替え ${_plan!.toAdd.length} 件'
                  '${_plan!.duplicates.isEmpty ? '' : '、CSV 内の重複 ${_plan!.duplicates.length} 件は飛ばす'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final row in _plan!.toAdd)
                  Text(
                    '${row.registeredName}  ${formatDate(row.replacedOn)}'
                    '${row.memo.isEmpty ? '' : '  ${row.memo}'}',
                  ),
                if (_plan!.canImport) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _import,
                    child: const Text('取り込む'),
                  ),
                ],
                if (_plan!.toAdd.isEmpty && _plan!.duplicates.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('新しい行はありません。'),
                  ),
              ],
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

  List<String> get _errors {
    return [
      ...?_parsed?.errors,
      ...?_plan?.errors,
    ];
  }

  Future<void> _export() async {
    final gearId = widget.store.settings.selectedGearId;
    final csv = exportReplacementCsv(
      parts: widget.store.parts,
      replacements: widget.store.replacements,
      gearId: gearId,
    );
    final count = widget.store.replacements.where((item) {
      return item.gearId == gearId && widget.store.partById(item.partId) != null;
    }).length;
    setState(() {
      _csv.text = csv;
      _parsed = null;
      _plan = null;
      _message = count == 0
          ? '交換記録がありません。見出しだけ書き出しました。'
          : '$count 件を入力欄に出し、コピーしました。';
    });
    await Clipboard.setData(ClipboardData(text: csv));
  }

  Future<bool> _blockIfDemo() async {
    if (!widget.store.usingDemoRides) {
      return false;
    }
    setState(() {
      _parsed = null;
      _plan = null;
      _message = DemoRequiresSyncException.message;
    });
    if (mounted) {
      await showDemoRequiresSyncDialog(context);
    }
    return true;
  }

  void _preview() {
    if (widget.store.usingDemoRides) {
      _blockIfDemo();
      return;
    }
    final parsed = parseReplacementCsv(
      _csv.text,
      startDate: widget.store.partOriginOn,
    );
    ReplacementImportPlan? plan;
    if (parsed.errors.isEmpty) {
      plan = planReplacementImport(
        rows: parsed.rows,
        parts: widget.store.parts,
      );
    }
    setState(() {
      _parsed = parsed;
      _plan = plan;
      _message = null;
    });
  }

  Future<void> _import() async {
    if (await _blockIfDemo()) {
      return;
    }
    final plan = _plan;
    if (plan == null || !plan.canImport) {
      return;
    }
    final result = await widget.store.importReplacementPlan(plan);
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = planReplacementImport(
        rows: _parsed?.rows ?? const [],
        parts: widget.store.parts,
      );
      _message =
          '${result.added} 件取り込みました。このギアの、CSV に出てきた登録名の以前の記録は置き換えました。'
          '${result.skippedDuplicates == 0 ? '' : ' ${result.skippedDuplicates} 件は CSV 内の重複なので飛ばしました。'}';
    });
  }
}
