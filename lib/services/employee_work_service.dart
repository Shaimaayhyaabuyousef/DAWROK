import 'facility_context.dart';
import 'package:flutter/foundation.dart';

import 'queue_operations_service.dart';
import 'queue_audit_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Employee operations are checked again in Firestore rules. An employee
/// invitation code alone never grants work permissions.
class EmployeeWorkService {
  EmployeeWorkService._() : _ownerFacilityId = null;
  EmployeeWorkService.forFacilityOwner(String facilityId) : _ownerFacilityId = facilityId;
  final String? _ownerFacilityId;
  static final instance = EmployeeWorkService._();
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
    if (_ownerFacilityId != null) {
      final id = await FacilityContext.instance.requireFacilityId();
      if (id != _ownerFacilityId) throw StateError('This queue belongs to another facility.');
      return id;
    }
    final membership = await _membership();
    if (!{'windowOfficer', 'supervisor'}.contains(membership['role'])) {
      throw StateError('Your assigned role cannot manage queue tickets.');
    }
    final id = membership['facilityId'];
    if (id is! String || id.isEmpty) throw StateError('Invalid facility.');
    return id;
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
      requireCalled: true,
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
      await QueueOperationsService.instance.postpone(id, fid, qid, window);
    } else {
      await QueueOperationsService.instance.close(id, fid, action, queueId: qid, window: window);
    }
    return 'Ticket updated: $action';
  }
}

String employeeTicketCode(String raw, String facilityId, String queueId) {
  final input = raw.trim();
  if (!input.startsWith('DAWROK|'))
    return input.startsWith('#') ? input.substring(1) : input;
  final fields = Uri.splitQueryString(input.substring(7).replaceAll('|', '&'));
  if (fields['facility'] != facilityId || fields['queue'] != queueId) {
    throw StateError('This ticket belongs to a different queue.');
  }
  final id = fields['ticket'];
  if (id == null || id.isEmpty) throw StateError('Invalid QR code.');
  return id;
}
