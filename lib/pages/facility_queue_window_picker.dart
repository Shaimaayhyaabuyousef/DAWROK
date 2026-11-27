import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/queue_assignment_service.dart';

/// Resume unfinished service at an unstaffed window, or take the first free one.
int? availableOwnerWindow(
  Iterable<int> windows,
  Set<int> assigned,
  Set<int> occupied,
) {
  final unstaffed = windows.where((w) => !assigned.contains(w));
  // Finish outstanding service before starting another at a different window.
  return unstaffed.where(occupied.contains).firstOrNull ??
      unstaffed.firstOrNull;
}

Future<int?> resolveOwnerWindow(String facilityId, String queueId) async {
  final db = FirebaseFirestore.instance;
  final facility = db.collection('facilities').doc(facilityId);
  final queue = facility.collection('queues').doc(queueId);
  const server = GetOptions(source: Source.server);
  final config = (await queue.get(server)).data();
  if (config == null || config['archived'] == true) {
    throw StateError('This queue is no longer available.');
  }
  final windows = serviceWindows((config['windowCount'] as num?)?.toInt() ?? 1);
  final assignments =
      (await facility.collection('operations').doc('assignments').get(server))
          .data();
  final assigned = assignedServiceWindows(assignments, queueId);
  final active = windows.toSet();
  if (config['schemaVersion'] == 3 && windows.first != 0) {
    final counters = await facility
        .collection('counters')
        .where('queueId', isEqualTo: queueId)
        .get(server);
    active.retainAll(
      counters.docs
          .where((doc) => doc.data()['isActive'] == true)
          .map((doc) => doc.data()['windowNumber'])
          .whereType<int>(),
    );
  }
  final lanes = await queue.collection('lanes').get(server);
  final occupied = lanes.docs
      .where((doc) => (doc.data()['ticketId'] as String? ?? '').isNotEmpty)
      .map((doc) => int.tryParse(doc.id))
      .whereType<int>()
      .toSet();
  return availableOwnerWindow(active, assigned, occupied);
}
