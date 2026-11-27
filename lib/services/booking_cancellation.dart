import 'package:cloud_firestore/cloud_firestore.dart';

import 'facility_context.dart';
import 'queue_schedule.dart';
import 'server_clock.dart';

class BookingCancellation {
  static final db = FirebaseFirestore.instance;

  static Future<void> stopDay(String queueId) async {
    final fid = await FacilityContext.instance.requireFacilityId();
    final day = QueueSchedule.dayKey(await ServerClock.now());
    final queue = db.doc('facilities/$fid/queues/$queueId');
    final closure = queue.collection('closures').doc(day);
    await db.runTransaction((tx) async {
      if (!(await tx.get(closure)).exists) {
        tx.set(closure, {
          'closedAt': FieldValue.serverTimestamp(),
          'pending': true,
        });
      }
    });
    await finishDay(fid, queueId, day);
  }

  static Future<void> resume(String fid, String queueId) async {
    final pending = await db
        .doc('facilities/$fid/queues/$queueId')
        .collection('closures')
        .where('pending', isEqualTo: true)
        .get(const GetOptions(source: Source.server));
    for (final job in pending.docs) {
      await finishDay(fid, queueId, job.id);
    }
  }

  static Future<void> finishDay(String fid, String queueId, String day) async {
    final rows = await db
        .collection('bookings')
        .where('facilityId', isEqualTo: fid)
        .get(const GetOptions(source: Source.server));
    for (final row in rows.docs) {
      final b = row.data();
      if (b['queueId'] == queueId &&
          ['waiting', 'called'].contains(b['status']) &&
          _serviceDay(b) == day) {
        await cancel(row.id, byFacility: true);
      }
    }
    await db.doc('facilities/$fid/queues/$queueId/closures/$day').update({
      'pending': false,
    });
  }

  static String _serviceDay(Map<String, dynamic> b) {
    final slot = b['slotStart'];
    return slot is Timestamp
        ? QueueSchedule.dayKey(slot.toDate())
        : b['dayKey'] as String;
  }

  static Future<void> settleCitizenClosures(String uid) async {
    final tickets = await db
        .collection('bookings')
        .where('citizenId', isEqualTo: uid)
        .get(const GetOptions(source: Source.server));
    for (final row in tickets.docs) {
      final b = row.data();
      if (!['waiting', 'called'].contains(b['status'])) continue;
      final closure = db.doc(
        "facilities/${b['facilityId']}/queues/${b['queueId']}/closures/${_serviceDay(b)}",
      );
      if ((await closure.get(const GetOptions(source: Source.server))).exists) {
        await cancel(row.id, byFacility: true);
      }
    }
  }

  static Future<void> cancel(String id, {bool byFacility = false}) async {
    final ticket = db.collection('bookings').doc(id);
    await db.runTransaction((tx) async {
      final b = (await tx.get(ticket)).data()!;
      if (b['status'] == 'cancelled') return;
      if (b['status'] != 'waiting' &&
          !(byFacility && b['status'] == 'called')) {
        throw StateError('The ticket can no longer be cancelled.');
      }
      final fid = b['facilityId'], qid = b['queueId'], uid = b['citizenId'];
      final queue = db.doc('facilities/$fid/queues/$qid');
      final daily = queue.collection('days').doc(b['dayKey'] as String);
      final guard = db.doc('users/$uid/booking_days/${b['dayKey']}');
      final account = db.doc('citizen_accounts/$uid');
      final refund = b['reward'] == 'extra' || b['reward'] == 'priority';
      final stamp = FieldValue.serverTimestamp();
      if (b['status'] == 'waiting' &&
          b['offersPriority'] == true &&
          b['priorityBuyer'] == null) {
        tx.delete(queue.collection('priority_offers').doc(id));
      }
      tx.update(ticket, {
        'status': 'cancelled',
        'cancelledBy': byFacility ? 'facility' : 'citizen',
        'closedAt': stamp,
      });
      tx.update(daily, {
        'cancelled': FieldValue.increment(1),
        'lastCancelled': id,
        'updatedAt': stamp,
        if (b['reward'] == 'extra') 'rewardReserved': FieldValue.increment(-1),
      });
      tx.update(guard, {
        // The service key (current) and the queue key (tickets booked before
        // services were grouped); deleting a missing key changes nothing.
        FieldPath(['queues', '${fid}_$qid']): FieldValue.delete(),
        FieldPath(['queues', '$fid|${b['service']}']): FieldValue.delete(),
        FieldPath(['slots', b['slot'] as String]): FieldValue.delete(),
        'lastCancelled': id,
        'updatedAt': stamp,
      });
      if (b['status'] == 'called' && b['routingVersion'] == 2) {
        tx.set(queue.collection('lanes').doc('${b['windowNumber']}'), {
          'ticketId': '',
          'updatedAt': stamp,
        });
      }
      if (refund) {
        tx.update(account, {
          'points': FieldValue.increment(100),
          'lastBookingId': id,
          'lastAction': 'refund',
          'updatedAt': stamp,
        });
        tx.set(account.collection('point_transactions').doc('refund_$id'), {
          'bookingId': id,
          'points': 100,
          'reason': 'refund',
          'createdAt': stamp,
        });
      }
      tx.set(account.collection('events').doc('cancel_$id'), {
        'bookingId': id,
        'type': byFacility ? 'service_cancelled' : 'cancelled',
        'delta': refund ? 100 : 0,
        'read': false,
        'createdAt': stamp,
      });
    });
  }
}
