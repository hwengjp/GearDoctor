import 'package:flutter/material.dart';

import '../domain/dates.dart';
import '../state/app_store.dart';
import '../widgets/widgets.dart';
import 'edit_record_screen.dart';

class ReplaceScreen extends StatefulWidget {
  const ReplaceScreen({super.key, required this.store, required this.partId});

  final AppStore store;
  final String partId;

  @override
  State<ReplaceScreen> createState() => _ReplaceScreenState();
}

class _ReplaceScreenState extends State<ReplaceScreen> {
  late DateTime _date;
  final _memo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = widget.store.now;
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final part = widget.store.partById(widget.partId);
        if (part == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('交換を記録')),
            body: const Center(child: Text('部品が見つかりません')),
          );
        }
        final name = widget.store.titleOf(part).replaceAll(' · ', '（') +
            (widget.store.groupOf(part.id) == null ? '' : '）');
        final history = widget.store.historyOf(part);
        return Scaffold(
          appBar: AppBar(title: const Text('交換を記録')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '$nameを交換した日付を記録すると、この位置の${part.cycle.usageNoun}だけゼロから始まります。',
              ),
              const SizedBox(height: 16),
              Text('交換日', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              OutlinedButton(
                onPressed: () => _pickDate(context),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(formatDate(_date)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '初期値は今日。記録し忘れのときは、実際に交換した日に直す',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('メモ', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              TextField(
                controller: _memo,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '製品名、交換理由など（空でも可）',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: widget.store.canManageRecords
                    ? () async {
                        await widget.store.addReplacement(
                          partId: part.id,
                          replacedOn: _date,
                          memo: _memo.text,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    : null,
                child: const Text('記録する'),
              ),
              const SizedBox(height: 20),
              ReplacementHistoryTable(
                part: part,
                rows: history,
                todayUsed: widget.store.gearKmThrough(widget.store.now),
                demoDistance: widget.store.usingDemoRides,
                onRowTap: (row) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditRecordScreen(
                        store: widget.store,
                        partId: widget.partId,
                        replacementId: row.replacement.id,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
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

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      lastDate: widget.store.now,
      currentDate: widget.store.now,
    );
    if (picked != null) {
      setState(() => _date = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }
}
