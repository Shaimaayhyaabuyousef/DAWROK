import 'citizen_account_service.dart';
import 'reliability_policy.dart';
import 'queue_schedule.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingReceipt {
  final String id, facilityId, facilityName, queueId, dayKey, slot;
  final String nationalId;
  final int windowNumber, queuePosition, windowCount;
  final DateTime slotStart;
  const BookingReceipt({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.queueId,
    required this.windowNumber,
    required this.queuePosition,
    required this.windowCount,
    required this.dayKey,
    required this.slot,
    required this.slotStart,
    required this.nationalId,
  });
}

/// Assigns an arrival window and a unique daily turn in one transaction.
class BookingService {
  BookingService._();
  static final instance = BookingService._();
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String _two(int n) => n.toString().padLeft(2, '0');

  Future<BookingReceipt> reserve({
    required String facilityId,
    required String queueId,
    String reward = 'none',
  }) async {
    if (!['none', 'extra', 'priority'].contains(reward))
      throw ArgumentError.value(reward);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in as a citizen to book.');
    final queueKey = '${facilityId}_${queueId}';
    final facilityRef = db.collection('facilities').doc(facilityId);
    final queueRef = facilityRef.collection('queues').doc(queueId);
    final bookingRef = db.collection('bookings').doc();
    final citizenRef = db.collection('users').doc(user.uid);

    late BookingReceipt receipt;
    DocumentReference<Map<String, dynamic>>? attemptedDaily;
    int? attemptedReserved;
    for (var attempt = 0; ; attempt++) {
      try {
        await db.runTransaction((tx) async {
          // All reads precede writes; concurrent reservations retry atomically.
          final me = await tx.get(citizenRef);
          final identity = await tx.get(
            db.collection('citizen_identity').doc(user.uid),
          );
          final facility = await tx.get(facilityRef);
          final queue = await tx.get(queueRef);
          final now = DateTime.now(); // Recomputed on every transaction retry.
          final q = queue.data();
          if (q == null || q['archived'] == true || q['isActive'] != true) {
            throw StateError('This queue is not accepting tickets.');
          }
          final start = (q['startsAtMinutes'] as num?)?.toInt() ?? 0;
          final end = (q['endsAtMinutes'] as num?)?.toInt() ?? 0;
          final capacity = (q['capacity'] as num?)?.toInt() ?? 0;
          final first = QueueSchedule.nextBooking(
            start: start,
            end: end,
            capacity: capacity,
            reserved: 0,
            now: now,
          );
          if (first == null)
            throw StateError('No available booking times today.');
          final dayKey = QueueSchedule.dayKey(first);
          final capacityRef = queueRef.collection('days').doc(dayKey);
          final daily = await tx.get(capacityRef);
          attemptedDaily = capacityRef;
          final reserved = (daily.data()?['reserved'] as num?)?.toInt() ?? 0;
          attemptedReserved = reserved;
          var slot = QueueSchedule.nextBooking(
            start: start,
            end: end,
            capacity: capacity,
            reserved: reserved,
            now: now,
          )!;
          final lastSlot = (daily.data()?['lastSlotStart'] as Timestamp?)
              ?.toDate();
          if (lastSlot != null && lastSlot.isAfter(slot)) slot = lastSlot;
          if (QueueSchedule.dayKey(slot) != dayKey ||
              slot.hour * 60 + slot.minute + 30 > end) {
            throw StateError('No available booking times today.');
          }
          final utc = slot.toUtc();
          final slotKey = '${_two(utc.hour)}${_two(utc.minute)}';
          final guardRef = citizenRef.collection('booking_days').doc(dayKey);
          final guard = await tx.get(guardRef);
          final accountRef = CitizenAccountService.instance.account(user.uid);
          final account = CitizenAccountService.policy(
            (await tx.get(accountRef)).data(),
          );
          if (account.blocked(DateTime.now()))
            throw StateError(
              account.reviewRequired
                  ? 'Booking is restricted pending review. Please submit a report.'
                  : 'Booking is temporarily restricted until ${account.blockedUntil!.toLocal()}.',
            );
          if (reward != 'none' && account.points < ReliabilityPolicy.rewardCost)
            throw StateError('You need 100 points to redeem this reward.');
          if (me.data()?['role'] != 'citizen') {
            throw StateError('Only citizens may reserve tickets.');
          }
          final nationalId = identity.data()?['nationalId'];
          if (nationalId is! String ||
              !RegExp(r'^\d{9}$').hasMatch(nationalId)) {
            throw StateError(
              'Complete registration with your national ID before booking.',
            );
          }
          if (facility.data()?['isActive'] != true ||
              facility.data()?['isOnline'] != true) {
            throw StateError('This facility is not currently available.');
          }
          final queues = Map<String, dynamic>.from(
            (guard.data()?['queues'] as Map?) ?? {},
          );
          final slots = Map<String, dynamic>.from(
            (guard.data()?['slots'] as Map?) ?? {},
          );
          if (queues.containsKey(queueKey)) {
            throw StateError('You already booked this queue today.');
          }
          if (slots.containsKey(slotKey)) {
            throw StateError('You already have a ticket for this time slot.');
          }
          final rewardReserved =
              (daily.data()?['rewardReserved'] as num?)?.toInt() ?? 0;
          final rewardCapacity = (q['rewardCapacity'] as num?)?.toInt() ?? 0;
          final normalUsed = reserved - rewardReserved;
          if (reward == 'extra') {
            if (normalUsed < capacity)
              throw StateError(
                'Regular places are still available. Choose a regular booking.',
              );
            if (rewardReserved >= rewardCapacity)
              throw StateError(
                'No reward places are available for this queue.',
              );
          } else if (capacity < 1 || normalUsed >= capacity)
            throw StateError('Regular booking capacity is full.');
          queues[queueKey] = bookingRef.id;
          slots[slotKey] = bookingRef.id;
          tx.set(guardRef, {
            'uid': user.uid,
            'queues': queues,
            'slots': slots,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(capacityRef, {
            'reserved': reserved + 1,
            'lastSlotStart': Timestamp.fromDate(slot),
            'rewardReserved': rewardReserved + (reward == 'extra' ? 1 : 0),
            'lastBookingId': bookingRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(bookingRef, {
            'reward': reward,
            'citizenId': user.uid,
            'citizenName': me.data()?['displayName'] ?? user.displayName ?? '',
            'facilityId': facilityId,
            'facilityName': facility.data()?['name'] ?? '',
            'queueId': queueId,
            'windowNumber': 0,
            'windowCount': (q['windowCount'] as num?)?.toInt() ?? 1,
            'routingVersion': 2,
            'queuePosition': reserved + 1,
            'service': q['service'],
            'dayKey': dayKey,
            'slot': slotKey,
            'slotStart': Timestamp.fromDate(slot),
            'status': 'waiting',
            'checkedIn': false,
            'postponements': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (reward != 'none') {
            tx.set(accountRef, {
              'points': account.points - 100,
              'streak': account.streak,
              'suspendedAt': account.suspendedAt == null
                  ? null
                  : Timestamp.fromDate(account.suspendedAt!),
              'reviewRequired': account.reviewRequired,
              'lastBookingId': bookingRef.id,
              'lastAction': 'redeem',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          tx.set(
            CitizenAccountService.instance
                .events(user.uid)
                .doc('book_${bookingRef.id}'),
            {
              'type': 'booking',
              'bookingId': bookingRef.id,
              'delta': reward == 'none' ? 0 : -100,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
          receipt = BookingReceipt(
            id: bookingRef.id,
            facilityId: facilityId,
            facilityName: facility.data()?['name'] as String? ?? '',
            queueId: queueId,
            windowNumber: 0,
            windowCount: (q['windowCount'] as num?)?.toInt() ?? 1,
            queuePosition: reserved + 1,
            dayKey: dayKey,
            slot: slotKey,
            slotStart: slot,
            nationalId: nationalId,
          );
        });
        return receipt;
      } on FirebaseException catch (error) {
        // Rules may observe a competing commit before the SDK's conflict check.
        // Retry only a proven counter race, never an arbitrary permission error.
        if (error.code != 'permission-denied' ||
            attempt >= 2 ||
            attemptedDaily == null ||
            attemptedReserved == null)
          rethrow;
        final latest = await attemptedDaily!.get(
          const GetOptions(source: Source.server),
        );
        if ((latest.data()?['reserved'] as num?)?.toInt() == attemptedReserved)
          rethrow;
      }
    }
  }
}
