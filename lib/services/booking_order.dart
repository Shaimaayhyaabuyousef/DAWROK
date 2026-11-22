import 'package:cloud_firestore/cloud_firestore.dart';

/// Slot precedes reward priority; creation time and ticket id break ties.
int compareBookingRows(
  Map<String, dynamic> a,
  String aid,
  Map<String, dynamic> b,
  String bid, {
  Set<String> cancelled = const {},
}) {
  int time(Map<String, dynamic> row, String key) =>
      (row[key] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
  final postponed = ((a['postponements'] as num?) ?? 0).compareTo(
    (b['postponements'] as num?) ?? 0,
  );
  if (postponed != 0) return postponed;
  final slot = time(a, 'slotStart').compareTo(time(b, 'slotStart'));
  if (slot != 0) return slot;
  final priority =
      (b['reward'] == 'priority' && b['priorityTarget'] == null ? 1 : 0)
          .compareTo(
            a['reward'] == 'priority' && a['priorityTarget'] == null ? 1 : 0,
          );
  if (priority != 0) return priority;
  num? position(Map<String, dynamic> row) {
    final counterpart = row['priorityBuyer'] ?? row['priorityTarget'];
    return (cancelled.contains(counterpart)
            ? row['queuePosition']
            : row['dispatchPosition'] ?? row['queuePosition'])
        as num?;
  }

  final ap = position(a);
  final bp = position(b);
  if (ap is num && bp is num && ap != bp) return ap.compareTo(bp);
  final created = time(a, 'createdAt').compareTo(time(b, 'createdAt'));
  return created == 0 ? aid.compareTo(bid) : created;
}

Set<String> cancelledTicketIds(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) => docs
    .where((d) => d.data()['status'] == 'cancelled')
    .map((d) => d.id)
    .toSet();
