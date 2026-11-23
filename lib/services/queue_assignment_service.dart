import 'package:cloud_firestore/cloud_firestore.dart';

/// A zero-window queue has one direct-service position (0).
List<int> serviceWindows(int count) =>
    count == 0 ? [0] : List.generate(count, (i) => i + 1);

Set<int> assignedServiceWindows(Map<String,dynamic>? document, String queueId) {
  final assignments = document?['assignments'] as Map? ?? {};
  return assignments.values.whereType<Map>().where((a) => a['queueId'] == queueId)
      .map((a) => a['windowNumber']).whereType<int>().toSet();
}

// Reading this document inside the write transaction also catches a staff
// reassignment that races an owner's action on an already-open screen.
Future<void> checkOwnerWindow(Transaction tx, String fid, String qid, int window) async {
  final ref = FirebaseFirestore.instance.collection('facilities').doc(fid)
      .collection('operations').doc('assignments');
  if (assignedServiceWindows((await tx.get(ref)).data(), qid).contains(window)) {
    throw StateError('This position has been assigned to a staff member. Reopen the queue.');
  }
}

Map<String, dynamic> allocateStaff(
  Map<String, int> queues,
  List<String> staff,
  Map<String, dynamic> previous,
) {
  final slots = <String, Map<String, dynamic>>{};
  for (final q in queues.keys.toList()..sort()) {
    for (final w in serviceWindows(queues[q]!)) {
      slots['$q/$w'] = {'queueId': q, 'windowNumber': w};
    }
  }
  final result = <String, dynamic>{};
  final employees = staff.toSet().toList()..sort();
  for (final uid in employees) {
    final old = previous[uid];
    if (old is Map) {
      final key = '${old['queueId']}/${old['windowNumber']}';
      final slot = slots.remove(key);
      if (slot != null) result[uid] = slot;
    }
  }
  for (final uid in employees) {
    if (result.containsKey(uid) || slots.isEmpty) continue;
    final key = slots.keys.first;
    result[uid] = slots.remove(key)!;
  }
  return result;
}

class QueueAssignmentService {
  QueueAssignmentService._();
  static final instance = QueueAssignmentService._();
  final db = FirebaseFirestore.instance;

  Future<void> rebalance(String fid) async {
    final fac = db.collection('facilities').doc(fid);
    final ref = fac.collection('operations').doc('assignments');
    await db.runTransaction((tx) async {
      final old = (await tx.get(ref)).data()?['assignments'] as Map? ?? {};
      // Read the shared assignment version before discovering candidates. A
      // competing rebalance retries this callback and rediscovers the roster.
      final queueDocs = await fac.collection('queues').get();
      final staffDocs = await fac.collection('staff').get();
      final queues = <String, int>{};
      final staff = <String>[];
      for (final doc in queueDocs.docs) {
        final q = (await tx.get(doc.reference)).data();
        if (q != null && q['archived'] != true) {
          queues[doc.id] = (q['windowCount'] as num?)?.toInt() ?? 1;
        }
      }
      for (final doc in staffDocs.docs) {
        final m = (await tx.get(doc.reference)).data();
        if (m != null &&
            m['state'] == 'active' &&
            m['joinStatus'] == 'approved' &&
            ['windowOfficer', 'supervisor'].contains(m['role']) &&
            m['linkedUid'] is String) {
          staff.add(m['linkedUid'] as String);
        }
      }
      tx.set(ref, {
        'assignments': allocateStaff(
          queues,
          staff,
          Map<String, dynamic>.from(old),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
