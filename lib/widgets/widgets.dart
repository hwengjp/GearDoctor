import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../domain/dates.dart';
import '../domain/usage.dart';
import '../models/models.dart';

String formatAmount(num value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return value.round() < 0 ? '-$buffer' : buffer.toString();
}

String formatUsed(num value, CycleKind cycle, {bool demo = false}) {
  final text = '${formatAmount(value)}${cycle.unitLabel}';
  if (demo && cycle == CycleKind.distance) {
    return '$text（デモ）';
  }
  return text;
}

String formatElapsedAndDue(
  num used,
  int limit,
  CycleKind cycle, {
  String? modeLabel,
  bool demo = false,
}) {
  final buffer = StringBuffer(
    '${formatAmount(used)} / ${formatAmount(limit)} ${cycle.unitLabel}',
  );
  if (modeLabel != null && modeLabel.isNotEmpty) {
    buffer.write(' $modeLabel');
  }
  if (demo && cycle == CycleKind.distance) {
    buffer.write('（デモ）');
  }
  return buffer.toString();
}

String formatTodayUsed(num value, CycleKind cycle, {bool demo = false}) {
  return '${formatUsed(value, cycle, demo: demo)}（今日）';
}

String markDemo(String text, {required bool demo}) {
  if (!demo) {
    return text;
  }
  return '$text（デモ）';
}

String demoGearLabel(
  String name, {
  required bool demo,
  bool selected = false,
}) {
  if (demo && selected) {
    return '$name（デモ・選択中）';
  }
  if (demo) {
    return '$name（デモ）';
  }
  if (selected) {
    return '$name（選択中）';
  }
  return name;
}

Future<void> showDemoRequiresSyncDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text(DemoRequiresSyncException.title),
        content: const Text(DemoRequiresSyncException.message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

/// Material の年グリッドは、年の数が 18 未満だと先頭（2010 など）から表示される。
DateTime appDatePickerFirstDate(DateTime lastDate) {
  const floorYear = 2000;
  const minYears = 18;
  var firstYear = floorYear;
  if (lastDate.year - firstYear + 1 < minYears) {
    firstYear = lastDate.year - minYears + 1;
  }
  return DateTime(firstYear);
}

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime lastDate,
  DateTime? currentDate,
}) {
  final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
  final first = appDatePickerFirstDate(last);
  var initial = DateTime(initialDate.year, initialDate.month, initialDate.day);
  if (initial.isAfter(last)) {
    initial = last;
  }
  if (initial.isBefore(first)) {
    initial = first;
  }
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    currentDate: currentDate ?? last,
  );
}

Color statusColor(WearStatus status, ColorScheme scheme) {
  return switch (status) {
    WearStatus.overdue => scheme.error,
    WearStatus.soon => const Color(0xFFC56B1A),
    WearStatus.ok => const Color(0xFF2F7D4A),
  };
}

class SelectTile extends StatelessWidget {
  const SelectTile({
    super.key,
    required this.selected,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? scheme.outline : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class UsageBar extends StatelessWidget {
  const UsageBar({
    super.key,
    required this.used,
    required this.limit,
    required this.status,
    this.topLeft,
    this.topRight,
  });

  final double used;
  final int limit;
  final WearStatus status;
  final String? topLeft;
  final String? topRight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topLeft != null || topRight != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    topLeft ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  topRight ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  heightFactor: 1,
                  child: ColoredBox(color: statusColor(status, scheme)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SideUsage extends StatelessWidget {
  const SideUsage({
    super.key,
    required this.part,
    required this.used,
    required this.limit,
    this.positionLabel,
    this.modeLabel,
    this.demoDistance = false,
    required this.onTap,
  });

  final Part part;
  final double used;
  final int limit;
  final String? positionLabel;
  final String? modeLabel;
  final bool demoDistance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = usagePercent(used, limit);
    final status = wearStatus(used, limit, part.thresholdPct);
    final statusLine = positionLabel == null
        ? '${statusLabel(status)}・$percent％'
        : '$positionLabel：${statusLabel(status)}・$percent％';
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusLine,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            formatElapsedAndDue(
              used,
              limit,
              part.cycle,
              modeLabel: modeLabel,
              demo: demoDistance,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          UsageBar(used: used, limit: limit, status: status),
        ],
      ),
    );
  }
}

class ReplacementHistoryTable extends StatelessWidget {
  const ReplacementHistoryTable({
    super.key,
    required this.part,
    required this.rows,
    required this.todayUsed,
    this.demoDistance = false,
    this.onRowTap,
  });

  final Part part;
  final List<HistoryRow> rows;
  final double todayUsed;
  final bool demoDistance;
  final ValueChanged<HistoryRow>? onRowTap;

  String get _usageHeader => 'ギアの走行距離';

  @override
  Widget build(BuildContext context) {
    final past = [...rows]
      ..sort(
        (a, b) => a.replacement.replacedOn.compareTo(b.replacement.replacedOn),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('過去の交換記録', style: Theme.of(context).textTheme.bodySmall),
        if (onRowTap != null)
          Text(
            '行をタップして日付・コメントの修正や削除',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.0),
            2: FlexColumnWidth(1.3),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              children: [
                _cell(context, _usageHeader, header: true),
                _cell(context, '交換日', header: true),
                _cell(context, 'コメント', header: true),
              ],
            ),
            for (final row in past)
              TableRow(
                children: [
                  _cell(
                    context,
                    formatUsed(
                      row.used,
                      CycleKind.distance,
                      demo: demoDistance,
                    ),
                    onTap: onRowTap == null ? null : () => onRowTap!(row),
                  ),
                  _cell(
                    context,
                    formatDate(row.replacement.replacedOn),
                    onTap: onRowTap == null ? null : () => onRowTap!(row),
                  ),
                  _cell(
                    context,
                    row.replacement.memo.isEmpty
                        ? '—'
                        : row.replacement.memo,
                    muted: row.replacement.memo.isEmpty,
                    onTap: onRowTap == null ? null : () => onRowTap!(row),
                  ),
                ],
              ),
            TableRow(
              children: [
                _cell(
                  context,
                  formatTodayUsed(
                    todayUsed,
                    CycleKind.distance,
                    demo: demoDistance,
                  ),
                ),
                _cell(context, ''),
                _cell(context, ''),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    String text, {
    bool header = false,
    bool muted = false,
    VoidCallback? onTap,
  }) {
    final style = header
        ? Theme.of(context).textTheme.bodySmall
        : Theme.of(context).textTheme.bodySmall?.copyWith(
            color: muted
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          );
    final child = Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: style),
    );
    if (onTap == null) {
      return child;
    }
    return TableRowInkWell(onTap: onTap, child: child);
  }
}
