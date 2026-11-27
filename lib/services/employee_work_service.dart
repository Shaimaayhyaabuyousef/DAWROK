import 'facility_context.dart';

import 'package:flutter/foundation.dart';

import 'queue_operations_service.dart';
import 'queue_audit_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Employee operations are checked again in Firestore rules. An employee
/// invitation code alone never grants work permissions.
class EmployeeWorkService {
  EmployeeWorkService.forEmployee(this.facilityId) : _owner = false;
  EmployeeWorkService.forFacilityOwner(this.facilityId) : _owner = true;
  final String facilityId;
  final bool _owner;
  final _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _membership() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in first.');
    final membership = await _db
        .collection('staff_memberships')
        .doc(user.uid)
        .get();
    final m = membership.data();
    if (m == null || m['state'] != 'active') {
      throw StateError('Your facility has not activated this account.');
    }
    final profile = await _db.collection('staff_profiles').doc(user.uid).get();
    if (profile.data()?['profileCompleted'] != true) {
      throw StateError('Complete your profile before working.');
    }
    return m;
  }

  Future<String> _facility() async {
    if (_owner) {
      final id = await FacilityContext.instance.requireFacilityId();
      if (id != facilityId)
        throw StateError('This queue belongs to another facility.');
      return id;
    }
    final membership = await _membership();
    if (!{'windowOfficer', 'supervisor'}.contains(membership['role'])) {
      throw StateError('Your assigned role cannot manage queue tickets.');
    }
    final id = membership['facilityId'];
    if (id != facilityId)
      throw StateError('Your facility assignment has changed.');
    return facilityId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> tickets(String fid) => _db
      .collection('bookings')
      .where('facilityId', isEqualTo: fid)
      .snapshots();

  Future<Map<String, dynamic>> checkIn(
    String id,
    String qid,
    int window,
  ) async {
    final fid = await _facility();
    final booking = await QueueOperationsService.instance.checkIn(
      id,
      fid,
      qid,
      window,
      owner: _owner,
    );
    try {
      await QueueAuditService.record(fid, 'Checked in', id);
    } on FirebaseException catch (error) {
      debugPrint('Check-in saved. Audit write failed: ${error.code}');
    }
    return booking;
  }

  Future<String> callNext(String qid, int window) async {
    return QueueOperationsService.instance.callNext(
      await _facility(),
      qid,
      window,
      owner: _owner,
    );
  }

  Future<String> changeTicket(
    String id,
    String action,
    String qid,
    int window,
  ) async {
    final fid = await _facility();
    if (action == 'postpone') {
      await QueueOperationsService.instance.postpone(id, fid, qid, window, owner: _owner);
    } else {
      await QueueOperationsService.instance.close(
        id,
        fid,
        action,
        owner: _owner,
        queueId: qid,
        window: window,
      );
    }
    return 'Ticket updated: $action';
  }
}

String employeeTicketCode(String raw, String facilityId, String queueId) {
  final input = raw.trim();
  if (!input.startsWith('DAWROK|'))
    return input.startsWith('#') ? input.substring(1) : input;
  final fields = <String, String>{};
  for (final part in input.substring(7).split('|')) {
    final equals = part.indexOf('=');
    if (equals <= 0 || equals == part.length - 1)
      throw StateError('Invalid QR code.');
    final key = part.substring(0, equals);
    if (fields.containsKey(key)) throw StateError('Invalid QR code.');
    fields[key] = part.substring(equals + 1);
  }
  if (fields['facility'] != facilityId || fields['queue'] != queueId) {
    throw StateError('This ticket belongs to a different queue.');
  }
  final id = fields['ticket'];
  if (id == null || id.isEmpty) throw StateError('Invalid QR code.');
  return id;
}
