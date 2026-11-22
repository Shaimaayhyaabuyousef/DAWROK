import 'server_clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'reliability_policy.dart';

class CitizenAccountService {
  CitizenAccountService._();
  static final instance = CitizenAccountService._();
  final db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> account(String uid) =>
      db.collection('citizen_accounts').doc(uid);
  CollectionReference<Map<String, dynamic>> events(String uid) =>
      account(uid).collection('events');
  static ReliabilityPolicy policy(Map<String, dynamic>? data) =>
      ReliabilityPolicy(
        points: (data?['points'] as num?)?.toInt() ?? 0,
        streak: (data?['streak'] as num?)?.toInt() ?? 0,
        suspendedAt: (data?['suspendedAt'] as Timestamp?)?.toDate(),
        reviewRequired: data?['reviewRequired'] == true,
      );
  Future<void> ensureWelcome() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = events(uid).doc('welcome');
    await db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) return;
      tx.set(ref, {
        'type': 'welcome',
        'bookingId': '',
        'delta': 0,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> completeTicket(
    String ticketId,
    String facilityId,
    String outcome,
  ) async {
    if (!['served', 'absent'].contains(outcome))
      throw ArgumentError.value(outcome);
    await ServerClock.now();
    final ticketRef = db.collection('bookings').doc(ticketId);
    await db.runTransaction((tx) async {
      final ticket = (await tx.get(ticketRef)).data();
      if (ticket == null ||
          ticket['facilityId'] != facilityId ||
          ticket['status'] != 'called')
        throw StateError(
          'This ticket is not currently called in your facility.',
        );
      if (outcome == 'served' && ticket['checkedIn'] != true)
        throw StateError('Check-in is required.');
      if (outcome == 'absent') {
        final called = (ticket['calledAt'] as Timestamp?)?.toDate();
        if (ticket['checkedIn'] == true || called == null ||
            ServerClock.estimate.isBefore(called.add(const Duration(minutes:10)))) {
          throw StateError('Absence requires ten minutes after calling and no check-in.');
        }
      }
      final uid = ticket['citizenId'] as String;
      final old = policy((await tx.get(account(uid))).data());
      final next = old.close(outcome, ServerClock.estimate);
      DocumentReference<Map<String, dynamic>>? lane;
      if (ticket['routingVersion'] == 2) {
        lane = db.collection('facilities').doc(facilityId).collection('queues')
            .doc(ticket['queueId'] as String).collection('lanes').doc('${ticket['windowNumber']}');
        if ((await tx.get(lane)).data()?['ticketId'] != ticketId) throw StateError('This service position no longer holds the ticket.');
      }
      if (lane != null) tx.set(lane, {'ticketId':'', 'updatedAt':FieldValue.serverTimestamp()});
      tx.update(ticketRef, {
        'status': outcome,
        'closedAt': FieldValue.serverTimestamp(),
      });
      tx.set(account(uid), {
        'points': next.points,
        'streak': next.streak,
        'suspendedAt': old.suspendedAt == null && next.suspendedAt != null
            ? FieldValue.serverTimestamp()
            : (old.suspendedAt == null
                  ? null
                  : Timestamp.fromDate(old.suspendedAt!)),
        'reviewRequired': next.reviewRequired,
        'lastBookingId': ticketId,
        'lastAction': outcome,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(account(uid).collection('point_transactions').doc('result_$ticketId'), {
        'bookingId':ticketId, 'points':outcome == 'served' ? 5 : -5,
        'reason':outcome, 'createdAt':FieldValue.serverTimestamp(),
      });
      tx.set(events(uid).doc('result_$ticketId'), {
        'type': outcome,
        'bookingId': ticketId,
        'delta': outcome == 'served' ? 5 : -5,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
