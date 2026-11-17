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
      final uid = ticket['citizenId'] as String;
      final old = policy((await tx.get(account(uid))).data());
      final next = old.close(outcome, DateTime.now());
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
