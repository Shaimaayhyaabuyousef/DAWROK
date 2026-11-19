import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'booking_order.dart';
import 'citizen_account_service.dart';
import 'queue_assignment_service.dart';

/// Owner and assigned employee share the same transactional operations.
class QueueOperationsService {
  QueueOperationsService._();
  static final instance = QueueOperationsService._();
  final db = FirebaseFirestore.instance;

  Future<void> _log(String fid, String label, String id) async {
    try {
      await db.collection('facilities').doc(fid).collection('queue_logs').add({
        'label': label,
        'identifier': id.length > 25 ? id.substring(0, 25) : id,
        'outcome': 'verified',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Queue action saved; log unavailable: $e');
    }
  }

  Future<String> callNext(String fid, String qid, int window) async {
    // Refetch after a conflict: another window may have taken the candidate.
    for (var attempt = 0; attempt < 4; attempt++) {
      final snap = await db
          .collection('bookings')
          .where('facilityId', isEqualTo: fid)
          .get();
      final rows =
          snap.docs
              .where(
                (d) =>
                    d.data()['queueId'] == qid &&
                    d.data()['status'] == 'waiting' &&
                    !((d.data()['slotStart'] as Timestamp?)?.toDate().isAfter(
                          DateTime.now(),
                        ) ??
                        false),
              )
              .toList()
            ..sort(
              (a, b) => compareBookingRows(a.data(), a.id, b.data(), b.id),
            );
      if (rows.isEmpty) return 'No tickets are due for service yet.';
      final candidate = rows.first;
      final qref = db
          .collection('facilities')
          .doc(fid)
          .collection('queues')
          .doc(qid);
      final lane = qref.collection('lanes').doc('$window');
      try {
        await db.runTransaction((tx) async {
          final q = (await tx.get(qref)).data();
          final lock = (await tx.get(lane)).data();
          final ticket = (await tx.get(candidate.reference)).data();
          if (q == null ||
              q['archived'] == true ||
              !serviceWindows((q['windowCount'] as num?)?.toInt() ?? 1)
                  .contains(window)) {
            throw StateError('This service position is unavailable.');
          }
          if ((lock?['ticketId'] as String? ?? '').isNotEmpty)
            throw StateError('Finish or postpone the current ticket first.');
          if (ticket?['status'] != 'waiting') throw const QueueClaimConflict();
          final time = (ticket?['slotStart'] as Timestamp?)?.toDate();
          if (time != null && time.isAfter(DateTime.now()))
            throw StateError(
              'The next ticket is scheduled for ${time.toLocal()}.',
            );
          tx.update(candidate.reference, {
            'status': 'called',
            'windowNumber': window,
            'routingVersion': 2,
            'calledAt': FieldValue.serverTimestamp(),
          });
          tx.set(lane, {
            'ticketId': candidate.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
        await _log(fid, 'Called', candidate.id);
        return 'Calling ticket #${candidate.id}';
      } on QueueClaimConflict {
        continue;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || attempt == 3) rethrow;
        final fresh = await candidate.reference.get(
          const GetOptions(source: Source.server),
        );
        if (fresh.data()?['status'] == 'waiting') rethrow;
      }
    }
    throw StateError('The queue changed. Please tap Next again.');
  }

  Future<void> checkIn(String id, String fid, String qid, int window) async {
    final ref = db.collection('bookings').doc(id);
    await db.runTransaction((tx) async {
      final b = (await tx.get(ref)).data();
      if (b == null ||
          b['facilityId'] != fid ||
          b['queueId'] != qid ||
          !['waiting', 'called'].contains(b['status']))
        throw StateError('Ticket does not belong to this active queue.');
      if (b['routingVersion'] == 2 &&
          b['status'] == 'called' &&
          b['windowNumber'] != window)
        throw StateError('Ticket is called at a different window.');
      if (b['checkedIn'] == true)
        throw StateError('Ticket already checked in.');
      tx.update(ref, {'checkedIn': true});
    });
  }

  Future<void> postpone(String id, String fid, String qid, int window) async {
    final ref = db.collection('bookings').doc(id);
    final lane = db
        .collection('facilities')
        .doc(fid)
        .collection('queues')
        .doc(qid)
        .collection('lanes')
        .doc('$window');
    await db.runTransaction((tx) async {
      final b = (await tx.get(ref)).data();
      final lock = (await tx.get(lane)).data();
      if (b == null ||
          b['facilityId'] != fid ||
          b['queueId'] != qid ||
          b['status'] != 'called' ||
          (b['routingVersion'] == 2 &&
              (b['windowNumber'] != window || lock?['ticketId'] != id)))
        throw StateError('The current ticket changed.');
      tx.update(ref, {
        'status': 'waiting',
        'postponements': (b['postponements'] as num).toInt() + 1,
        'postponedAt': FieldValue.serverTimestamp(),
        'windowNumber': 0,
      });
      if (b['routingVersion'] == 2)
        tx.set(lane, {
          'ticketId': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
    });
    await _log(fid, 'Postponed', id);
  }

  Future<void> close(String id, String fid, String outcome) async {
    await CitizenAccountService.instance.completeTicket(id, fid, outcome);
    await _log(fid, outcome, id);
  }
}

class QueueClaimConflict implements Exception {
  const QueueClaimConflict();
}
