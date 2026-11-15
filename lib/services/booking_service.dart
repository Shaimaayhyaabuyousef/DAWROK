import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingReceipt {
  final String id, facilityId, facilityName, queueId, dayKey, slot;
  final int windowNumber;
  final DateTime slotStart;
  const BookingReceipt({required this.id, required this.facilityId,
    required this.facilityName, required this.queueId, required this.windowNumber,
    required this.dayKey, required this.slot, required this.slotStart});
}

/// All reservations occupy one aligned 30-minute slot in this Spark prototype.
/// Production needs trusted server validation of date, timezone and eligibility.
class BookingService {
  BookingService._();
  static final instance = BookingService._();
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String _two(int n) => n.toString().padLeft(2, '0');

  Future<BookingReceipt> reserve({
    required String facilityId, required String queueId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in as a citizen to book.');
    final now = DateTime.now();
    final slot = DateTime(now.year, now.month, now.day, now.hour,
        (now.minute ~/ 30 + 1) * 30);
    final dayKey = '${slot.year}${_two(slot.month)}${_two(slot.day)}';
    final slotKey = '${_two(slot.hour)}${_two(slot.minute)}';
    final queueKey = '${facilityId}_${queueId}';
    final facilityRef = db.collection('facilities').doc(facilityId);
    final queueRef = facilityRef.collection('queues').doc(queueId);
    final bookingRef = db.collection('bookings').doc();
    final guardRef = db.collection('users').doc(user.uid)
        .collection('booking_days').doc(dayKey);
    final capacityRef = queueRef.collection('days').doc(dayKey);
    final citizenRef = db.collection('users').doc(user.uid);

    late BookingReceipt receipt;
    await db.runTransaction((tx) async {
      // All reads precede writes; concurrent reservations retry atomically.
      final me = await tx.get(citizenRef);
      final facility = await tx.get(facilityRef);
      final queue = await tx.get(queueRef);
      final guard = await tx.get(guardRef);
      final daily = await tx.get(capacityRef);
      if (me.data()?['role'] != 'citizen') {
        throw StateError('Only citizens may reserve tickets.');
      }
      if (facility.data()?['isActive'] != true) {
        throw StateError('This facility is not currently available.');
      }
      final q = queue.data();
      if (q == null || q['archived'] == true || q['isActive'] != true) {
        throw StateError('This queue is not accepting tickets.');
      }
      final start = (q['startsAtMinutes'] as num?)?.toInt() ?? 0;
      final end = (q['endsAtMinutes'] as num?)?.toInt() ?? 0;
      final minute = slot.hour * 60 + slot.minute;
      if (minute < start || minute + 30 > end) {
        throw StateError('No 30-minute booking slot remains within queue hours today.');
      }
      final queues = Map<String, dynamic>.from((guard.data()?['queues'] as Map?) ?? {});
      final slots = Map<String, dynamic>.from((guard.data()?['slots'] as Map?) ?? {});
      if (queues.containsKey(queueKey)) {
        throw StateError('You already booked this queue today.');
      }
      if (slots.containsKey(slotKey)) {
        throw StateError('You already have a ticket for this time slot.');
      }
      final reserved = (daily.data()?['reserved'] as num?)?.toInt() ?? 0;
      final capacity = (q['capacity'] as num?)?.toInt() ?? 0;
      if (capacity < 1 || reserved >= capacity) {
        throw StateError('This queue has reached its daily booking capacity.');
      }
      queues[queueKey] = bookingRef.id;
      slots[slotKey] = bookingRef.id;
      tx.set(guardRef, {'uid': user.uid, 'queues': queues,
        'slots': slots, 'updatedAt': FieldValue.serverTimestamp()});
      tx.set(capacityRef, {'reserved': reserved + 1,
        'updatedAt': FieldValue.serverTimestamp()});
      tx.update(queueRef, {'waitingCount': FieldValue.increment(1)});
      tx.set(bookingRef, {
        'citizenId': user.uid,
        'citizenName': me.data()?['displayName'] ?? user.displayName ?? '',
        'facilityId': facilityId,
        'facilityName': facility.data()?['name'] ?? '',
        'queueId': queueId,
        'windowNumber': q['windowNumber'],
        'service': q['service'],
        'dayKey': dayKey, 'slot': slotKey,
        'slotStart': Timestamp.fromDate(slot),
        'status': 'waiting', 'checkedIn': false, 'postponements': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      receipt = BookingReceipt(
        id: bookingRef.id, facilityId: facilityId,
        facilityName: facility.data()?['name'] as String? ?? '',
        queueId: queueId,
        windowNumber: (q['windowNumber'] as num).toInt(),
        dayKey: dayKey, slot: slotKey, slotStart: slot,
      );
    });
    return receipt;
  }
}
