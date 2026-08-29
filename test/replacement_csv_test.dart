import 'package:flutter_test/flutter_test.dart';
import 'package:gear_doctor/data/seed.dart';
import 'package:gear_doctor/domain/dates.dart';
import 'package:gear_doctor/domain/replacement_csv.dart';
import 'package:gear_doctor/models/models.dart';

void main() {
  const chain = Part(
    id: 'p_chain',
    registeredName: 'チェーン',
    cycle: CycleKind.distance,
    limitMode: LimitMode.recommended,
    recommendedLimit: 4000,
    customLimit: 4000,
    thresholdPct: 80,
    sortOrder: 2,
  );

  test('parses header, memo with comma, and rejects bad dates', () {
    final parsed = parseReplacementCsv('''
登録名,交換日,メモ
チェーン,2024-01-01,"旧,注油"
チェーン,2025-13-01,無効
''');
    expect(parsed.errors, contains('3 行目: 交換日は YYYY-MM-DD にしてください。'));
    expect(parsed.rows, hasLength(1));
    expect(parsed.rows.single.memo, '旧,注油');
  });

  test('plan skips unknown names and duplicate dates in the CSV', () {
    final parsed = parseReplacementCsv('''
登録名,交換日,メモ
チェーン,2024-01-01,旧
チェーン,2024-01-01,重複
チェーン,2025-11-12,デモ日も取り込む
タイヤ,2025-03-01,まとめ名
''');
    expect(parsed.errors, isEmpty);
    final plan = planReplacementImport(
      rows: parsed.rows,
      parts: const [chain],
    );
    expect(plan.errors.single, contains('タイヤ'));
    expect(plan.toAdd, hasLength(2));
    expect(formatDate(plan.toAdd.first.replacedOn), '2024-01-01');
    expect(formatDate(plan.toAdd.last.replacedOn), '2025-11-12');
    expect(plan.duplicates, hasLength(1));
    expect(plan.canImport, isFalse);
  });

  test('plan can import when names already exist', () {
    final parsed = parseReplacementCsv('''
登録名,交換日,メモ
チェーン,2024-06-01,CSV
''');
    final plan = planReplacementImport(
      rows: parsed.rows,
      parts: const [chain],
    );
    expect(plan.errors, isEmpty);
    expect(plan.canImport, isTrue);
    expect(plan.toAdd.single.memo, 'CSV');
  });

  test('example lists every default registered name', () {
    final names = defaultParts().map((part) => part.registeredName).toList();
    final csv = replacementCsvExample(
      names,
      startDate: parseDate('2025-07-17'),
    );
    expect(csv, startsWith('登録名,交換日,メモ\n'));
    expect(names.length, 18);
    for (final name in names) {
      expect(csv, contains('$name,2025-07-17,\n'));
    }
  });

  test('empty replacement date uses the start date', () {
    final parsed = parseReplacementCsv(
      '''
登録名,交換日,メモ
チェーン,,最初
''',
      startDate: parseDate('2025-07-17'),
    );
    expect(parsed.errors, isEmpty);
    expect(formatDate(parsed.rows.single.replacedOn), '2025-07-17');
    expect(parsed.rows.single.memo, '最初');
  });

  test('export quotes memos with commas and round-trips', () {
    const front = Part(
      id: 'p_front_tire',
      registeredName: '前タイヤ',
      cycle: CycleKind.distance,
      limitMode: LimitMode.recommended,
      recommendedLimit: 6000,
      customLimit: 6000,
      thresholdPct: 80,
      sortOrder: 0,
    );
    final csv = exportReplacementCsv(
      parts: const [front, chain],
      replacements: [
        Replacement(
          id: 'r2',
          partId: 'p_chain',
          replacedOn: parseDate('2025-11-12'),
          memo: '',
        ),
        Replacement(
          id: 'r1',
          partId: 'p_front_tire',
          replacedOn: parseDate('2025-03-01'),
          memo: 'GP5000,黒',
        ),
      ],
    );
    expect(
      csv,
      '登録名,交換日,メモ\n'
      '前タイヤ,2025-03-01,"GP5000,黒"\n'
      'チェーン,2025-11-12,\n',
    );
    final parsed = parseReplacementCsv(csv);
    expect(parsed.errors, isEmpty);
    expect(parsed.rows, hasLength(2));
    expect(parsed.rows.first.memo, 'GP5000,黒');
  });
}
