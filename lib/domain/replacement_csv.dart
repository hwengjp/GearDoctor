import '../models/models.dart';
import 'dates.dart';

class ReplacementCsvRow {
  const ReplacementCsvRow({
    required this.lineNumber,
    required this.registeredName,
    required this.replacedOn,
    required this.memo,
  });

  final int lineNumber;
  final String registeredName;
  final DateTime replacedOn;
  final String memo;
}

class ReplacementCsvParseResult {
  const ReplacementCsvParseResult({required this.rows, required this.errors});

  final List<ReplacementCsvRow> rows;
  final List<String> errors;

  bool get ok => errors.isEmpty && rows.isNotEmpty;
}

class ReplacementImportPlan {
  const ReplacementImportPlan({
    required this.toAdd,
    required this.duplicates,
    required this.errors,
  });

  final List<ReplacementCsvRow> toAdd;
  final List<ReplacementCsvRow> duplicates;
  final List<String> errors;

  bool get canImport => errors.isEmpty && toAdd.isNotEmpty;
}

class ReplacementImportResult {
  const ReplacementImportResult({
    required this.added,
    required this.skippedDuplicates,
  });

  final int added;
  final int skippedDuplicates;
}

ReplacementCsvParseResult parseReplacementCsv(
  String raw, {
  DateTime? startDate,
}) {
  final text = raw.replaceFirst('\uFEFF', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = text.split('\n');
  final errors = <String>[];
  final rows = <ReplacementCsvRow>[];
  var sawHeader = false;

  for (var i = 0; i < lines.length; i++) {
    final lineNumber = i + 1;
    final line = lines[i].trim();
    if (line.isEmpty) {
      continue;
    }
    final fields = parseCsvLine(line);
    if (!sawHeader) {
      if (!_isHeader(fields)) {
        errors.add('1行目は 登録名,交換日,メモ にしてください。');
        return ReplacementCsvParseResult(rows: const [], errors: errors);
      }
      sawHeader = true;
      continue;
    }
    if (fields.isEmpty || fields.every((field) => field.trim().isEmpty)) {
      continue;
    }
    if (fields.length < 2) {
      errors.add('$lineNumber 行目: 登録名と交換日が必要です。');
      continue;
    }
    final name = fields[0].trim();
    var dateRaw = fields[1].trim();
    final memo = fields.length <= 2
        ? ''
        : fields.sublist(2).join(',').trim();
    if (name.isEmpty) {
      errors.add('$lineNumber 行目: 登録名が空です。');
      continue;
    }
    if (dateRaw.isEmpty) {
      if (startDate == null) {
        errors.add('$lineNumber 行目: 交換日が空です。開始日を指定するか、YYYY-MM-DD を入れてください。');
        continue;
      }
      dateRaw = formatDate(startDate);
    }
    if (!_isYmd(dateRaw)) {
      errors.add('$lineNumber 行目: 交換日は YYYY-MM-DD にしてください。');
      continue;
    }
    rows.add(
      ReplacementCsvRow(
        lineNumber: lineNumber,
        registeredName: name,
        replacedOn: parseDate(dateRaw),
        memo: memo,
      ),
    );
  }

  if (!sawHeader) {
    errors.add('CSV が空です。');
  } else if (rows.isEmpty && errors.isEmpty) {
    errors.add('データ行がありません。');
  }
  return ReplacementCsvParseResult(rows: rows, errors: errors);
}

ReplacementImportPlan planReplacementImport({
  required List<ReplacementCsvRow> rows,
  required List<Part> parts,
}) {
  final byName = <String, List<Part>>{};
  for (final part in parts) {
    byName.putIfAbsent(part.registeredName, () => []).add(part);
  }
  final errors = <String>[];
  final toAdd = <ReplacementCsvRow>[];
  final duplicates = <ReplacementCsvRow>[];
  final seen = <String>{};

  for (final row in rows) {
    final matches = byName[row.registeredName] ?? const <Part>[];
    if (matches.isEmpty) {
      errors.add(
        '${row.lineNumber} 行目: 登録名「${row.registeredName}」の部品がありません。先に部品を追加してください。',
      );
      continue;
    }
    if (matches.length > 1) {
      errors.add(
        '${row.lineNumber} 行目: 登録名「${row.registeredName}」が複数あります。',
      );
      continue;
    }
    final part = matches.single;
    final key = '${part.id}|${formatDate(row.replacedOn)}';
    if (seen.contains(key)) {
      duplicates.add(row);
      continue;
    }
    seen.add(key);
    toAdd.add(row);
  }

  return ReplacementImportPlan(
    toAdd: toAdd,
    duplicates: duplicates,
    errors: errors,
  );
}

Part? partForCsvRow(ReplacementCsvRow row, List<Part> parts) {
  for (final part in parts) {
    if (part.registeredName == row.registeredName) {
      return part;
    }
  }
  return null;
}

List<String> parseCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(char);
      }
    } else if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  fields.add(buffer.toString());
  return fields;
}

bool _isHeader(List<String> fields) {
  if (fields.isEmpty) {
    return false;
  }
  return fields.first.trim() == '登録名';
}

bool _isYmd(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return false;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

const replacementCsvHeader = '登録名,交換日,メモ';

String replacementCsvExample(
  List<String> registeredNames, {
  DateTime? startDate,
}) {
  final date = startDate == null ? '' : formatDate(startDate);
  final buffer = StringBuffer('$replacementCsvHeader\n');
  for (final name in registeredNames) {
    buffer.write(csvEscape(name));
    buffer.writeln(',$date,');
  }
  return buffer.toString();
}

String csvEscape(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String exportReplacementCsv({
  required List<Part> parts,
  required List<Replacement> replacements,
}) {
  final byId = {for (final part in parts) part.id: part};
  final rows = [...replacements];
  rows.sort((a, b) {
    final partA = byId[a.partId];
    final partB = byId[b.partId];
    final orderA = partA?.sortOrder ?? 1 << 30;
    final orderB = partB?.sortOrder ?? 1 << 30;
    if (orderA != orderB) {
      return orderA.compareTo(orderB);
    }
    return a.replacedOn.compareTo(b.replacedOn);
  });
  final buffer = StringBuffer('登録名,交換日,メモ\n');
  for (final replacement in rows) {
    final part = byId[replacement.partId];
    if (part == null) {
      continue;
    }
    buffer.write(csvEscape(part.registeredName));
    buffer.write(',');
    buffer.write(formatDate(replacement.replacedOn));
    buffer.write(',');
    buffer.writeln(csvEscape(replacement.memo));
  }
  return buffer.toString();
}
