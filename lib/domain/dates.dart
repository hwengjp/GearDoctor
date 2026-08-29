DateTime dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

DateTime parseDate(String ymd) {
  final parts = ymd.split('-');
  return DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String formatDate(DateTime value) {
  final d = dateOnly(value);
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$month-$day';
}

int monthsBetween(DateTime from, DateTime to) {
  final start = dateOnly(from);
  final end = dateOnly(to);
  return (end.year - start.year) * 12 + (end.month - start.month);
}

DateTime addCalendarMonths(DateTime date, int months) {
  final d = dateOnly(date);
  return DateTime.utc(d.year, d.month + months, d.day);
}

DateTime dayAfter(DateTime date) {
  final d = dateOnly(date);
  return DateTime.utc(d.year, d.month, d.day + 1);
}

class SyncWindow {
  const SyncWindow({required this.fromInclusive, required this.toInclusive});

  final DateTime fromInclusive;
  final DateTime toInclusive;
}

/// 次に取る範囲。Strava開始日（または前回取り終えた日）から [months] か月、今日まで。
SyncWindow nextSyncWindow({
  required DateTime startDate,
  required DateTime? fetchedThrough,
  required int months,
  required DateTime today,
}) {
  final from = dateOnly(fetchedThrough ?? startDate);
  final cap = dateOnly(today);
  var to = addCalendarMonths(from, months);
  if (to.isAfter(cap)) {
    to = cap;
  }
  if (to.isBefore(from)) {
    to = from;
  }
  return SyncWindow(fromInclusive: from, toInclusive: to);
}

/// Strava の after。Strava開始日 0:00 UTC の走行を含めるため 1 秒引く。
int stravaAfterEpoch(DateTime fromInclusive) {
  return dateOnly(fromInclusive).millisecondsSinceEpoch ~/ 1000 - 1;
}

/// Strava の before。終了日を含めるため翌日 0:00 UTC。
int stravaBeforeEpoch(DateTime toInclusive) {
  final d = dateOnly(toInclusive);
  return DateTime.utc(d.year, d.month, d.day + 1).millisecondsSinceEpoch ~/
      1000;
}
