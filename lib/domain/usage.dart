import '../models/models.dart';
import 'dates.dart';

int usagePercent(double used, int limit) {
  if (limit <= 0) {
    return 0;
  }
  return ((used / limit) * 100).round();
}

WearStatus wearStatus(double used, int limit, int thresholdPct) {
  final percent = usagePercent(used, limit);
  if (percent >= 100) {
    return WearStatus.overdue;
  }
  if (percent >= thresholdPct) {
    return WearStatus.soon;
  }
  return WearStatus.ok;
}

String statusLabel(WearStatus status) {
  return switch (status) {
    WearStatus.overdue => '交換',
    WearStatus.soon => 'そろそろ',
    WearStatus.ok => '余裕',
  };
}

double rideKm({
  required List<Ride> rides,
  required String? gearId,
  required DateTime fromInclusive,
  DateTime? toExclusive,
}) {
  if (gearId == null) {
    return 0;
  }
  final start = dateOnly(fromInclusive);
  final end = toExclusive == null ? null : dateOnly(toExclusive);
  var total = 0.0;
  for (final ride in rides) {
    if (ride.gearId != gearId) {
      continue;
    }
    final day = dateOnly(ride.startedOn);
    if (day.isBefore(start)) {
      continue;
    }
    if (end != null && !day.isBefore(end)) {
      continue;
    }
    total += ride.distanceKm;
  }
  return total;
}

double rideKmThrough({
  required List<Ride> rides,
  required String? gearId,
  DateTime? fromInclusive,
  required DateTime throughInclusive,
}) {
  final through = dateOnly(throughInclusive);
  if (fromInclusive != null && through.isBefore(dateOnly(fromInclusive))) {
    return 0;
  }
  return rideKm(
    rides: rides,
    gearId: gearId,
    fromInclusive: fromInclusive ?? DateTime.utc(1970, 1, 1),
    toExclusive: dayAfter(through),
  );
}

DateTime? newestRideOn({
  required List<Ride> rides,
  DateTime? fromInclusive,
}) {
  final start = fromInclusive == null ? null : dateOnly(fromInclusive);
  DateTime? newest;
  for (final ride in rides) {
    final day = dateOnly(ride.startedOn);
    if (start != null && day.isBefore(start)) {
      continue;
    }
    if (newest == null || day.isAfter(newest)) {
      newest = day;
    }
  }
  return newest;
}

DateTime? oldestRideOn({
  required List<Ride> rides,
  required String? gearId,
}) {
  if (gearId == null) {
    return null;
  }
  DateTime? oldest;
  for (final ride in rides) {
    if (ride.gearId != gearId) {
      continue;
    }
    final day = dateOnly(ride.startedOn);
    if (oldest == null || day.isBefore(oldest)) {
      oldest = day;
    }
  }
  return oldest;
}

double currentUsed({
  required Part part,
  required List<Replacement> replacements,
  required List<Ride> rides,
  required String? gearId,
  required DateTime now,
}) {
  final latest = latestReplacement(replacements);
  if (latest == null) {
    return 0;
  }
  if (part.cycle == CycleKind.months) {
    return monthsBetween(latest.replacedOn, now).toDouble();
  }
  return rideKm(
    rides: rides,
    gearId: gearId,
    fromInclusive: latest.replacedOn,
  );
}

Replacement? latestReplacement(List<Replacement> replacements) {
  if (replacements.isEmpty) {
    return null;
  }
  final sorted = [...replacements]
    ..sort((a, b) => b.replacedOn.compareTo(a.replacedOn));
  return sorted.first;
}

List<HistoryRow> historyRows({
  required List<Replacement> replacements,
  required List<Ride> rides,
  required String? gearId,
  DateTime? trackingFrom,
}) {
  final sorted = [...replacements]
    ..sort((a, b) => a.replacedOn.compareTo(b.replacedOn));
  return [
    for (final replacement in sorted)
      HistoryRow(
        replacement: replacement,
        used: rideKmThrough(
          rides: rides,
          gearId: gearId,
          fromInclusive: trackingFrom,
          throughInclusive: replacement.replacedOn,
        ),
      ),
  ];
}

int? previousCycleUsed({
  required Part part,
  required List<Replacement> replacements,
  required List<Ride> rides,
  required String? gearId,
  DateTime? trackingFrom,
}) {
  if (replacements.isEmpty) {
    return null;
  }
  final sorted = [...replacements]
    ..sort((a, b) => b.replacedOn.compareTo(a.replacedOn));
  final latest = dateOnly(sorted.first.replacedOn);
  DateTime from;
  if (sorted.length == 1) {
    if (trackingFrom == null) {
      return null;
    }
    from = dateOnly(trackingFrom);
  } else {
    from = dateOnly(sorted[1].replacedOn);
  }
  if (!from.isBefore(latest)) {
    return null;
  }
  final used = part.cycle == CycleKind.months
      ? monthsBetween(from, latest)
      : rideKm(
          rides: rides,
          gearId: gearId,
          fromInclusive: from,
          toExclusive: latest,
        ).round();
  if (used < 1) {
    return null;
  }
  return used;
}

int resolveLimit(Part part, {int? previousCycle}) {
  switch (part.limitMode) {
    case LimitMode.recommended:
      return part.recommendedLimit;
    case LimitMode.custom:
      return part.customLimit;
    case LimitMode.previousCycle:
      if (previousCycle != null && previousCycle >= 1) {
        return previousCycle;
      }
      return part.recommendedLimit;
  }
}

class DisplayCard {
  const DisplayCard.single(this.part)
      : group = null,
        front = null,
        rear = null;

  const DisplayCard.group({
    required DisplayGroup this.group,
    required Part this.front,
    required Part this.rear,
  }) : part = null;

  final Part? part;
  final DisplayGroup? group;
  final Part? front;
  final Part? rear;

  bool get isGroup => group != null;

  String get title => group?.displayName ?? part!.registeredName;

  int get sortOrder {
    if (isGroup) {
      return front!.sortOrder < rear!.sortOrder
          ? front!.sortOrder
          : rear!.sortOrder;
    }
    return part!.sortOrder;
  }
}

List<DisplayCard> buildDisplayCards({
  required List<Part> parts,
  required List<DisplayGroup> groups,
}) {
  final byId = {for (final part in parts) part.id: part};
  final groupedIds = <String>{};
  final cards = <DisplayCard>[];
  for (final group in groups) {
    final front = byId[group.frontPartId];
    final rear = byId[group.rearPartId];
    if (front == null || rear == null) {
      continue;
    }
    groupedIds.add(front.id);
    groupedIds.add(rear.id);
    cards.add(DisplayCard.group(group: group, front: front, rear: rear));
  }
  for (final part in parts) {
    if (!groupedIds.contains(part.id)) {
      cards.add(DisplayCard.single(part));
    }
  }
  cards.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return cards;
}

DisplayGroup? groupForPart(List<DisplayGroup> groups, String partId) {
  for (final group in groups) {
    if (group.contains(partId)) {
      return group;
    }
  }
  return null;
}

String displayTitle({
  required Part part,
  required List<DisplayGroup> groups,
}) {
  final group = groupForPart(groups, part.id);
  if (group == null) {
    return part.registeredName;
  }
  final side = group.frontPartId == part.id ? 'F' : 'R';
  return '${group.displayName} · $side';
}

String alertLabel({
  required Part part,
  required List<DisplayGroup> groups,
}) {
  final group = groupForPart(groups, part.id);
  if (group == null) {
    return part.registeredName;
  }
  final side = group.frontPartId == part.id ? 'F' : 'R';
  return '${group.displayName} $side';
}

List<AlertItem> collectAlerts({
  required List<Part> parts,
  required List<DisplayGroup> groups,
  required Map<String, double> usedByPartId,
  required Map<String, int> limitByPartId,
}) {
  final alerts = <AlertItem>[];
  for (final part in parts) {
    final used = usedByPartId[part.id] ?? 0;
    final limit = limitByPartId[part.id] ?? part.recommendedLimit;
    if (wearStatus(used, limit, part.thresholdPct) == WearStatus.ok) {
      continue;
    }
    alerts.add(
      AlertItem(
        partId: part.id,
        label: alertLabel(part: part, groups: groups),
      ),
    );
  }
  return alerts;
}
