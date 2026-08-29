import 'package:flutter/material.dart';

import '../domain/dates.dart';
import '../domain/usage.dart';
import '../models/models.dart';
import '../state/app_store.dart';
import '../widgets/widgets.dart';
import 'edit_part_screen.dart';
import 'edit_record_screen.dart';
import 'replace_screen.dart';

class PartDetailScreen extends StatelessWidget {
  const PartDetailScreen({
    super.key,
    required this.store,
    required this.partId,
  });

  final AppStore store;
  final String partId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final part = store.partById(partId);
        if (part == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('部品の詳細')),
            body: const Center(child: Text('部品が見つかりません')),
          );
        }
        final used = store.usedOf(part);
        final limit = store.limitOf(part);
        final last = latestReplacement(store.replacementsFor(part.id));
        final percent = usagePercent(used, limit);
        final status = wearStatus(used, limit, part.thresholdPct);
        final modeLabel = store.limitModeLabelOf(part);
        final heading = part.cycle == CycleKind.months
            ? '交換後の経過'
            : '交換後の走行距離';
        return Scaffold(
          appBar: AppBar(title: Text(store.titleOf(part))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(heading, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                formatElapsedAndDue(
                  used,
                  limit,
                  part.cycle,
                  modeLabel: modeLabel,
                  demo: store.usingDemoRides,
                ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              UsageBar(
                used: used,
                limit: limit,
                status: status,
                topLeft: '$percent% · ${statusLabel(status)}',
                topRight: 'しきい値 ${part.thresholdPct}%',
              ),
              const SizedBox(height: 12),
              Text(
                last == null ? '最終交換 未記録' : '最終交換 ${formatDate(last.replacedOn)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: store.canManageRecords
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ReplaceScreen(
                                    store: store,
                                    partId: part.id,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: const Text('交換した'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                EditPartScreen(store: store, partId: part.id),
                          ),
                        );
                      },
                      child: const Text('編集'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ReplacementHistoryTable(
                part: part,
                rows: store.historyOf(part),
                todayUsed: store.gearKmThrough(store.now),
                demoDistance: store.usingDemoRides,
                onRowTap: (row) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditRecordScreen(
                        store: store,
                        partId: part.id,
                        replacementId: row.replacement.id,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
