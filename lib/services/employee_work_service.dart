import 'citizen_account_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Employee operations are checked again in Firestore rules. An employee
/// invitation code alone never grants work permissions.
class EmployeeWorkService {
  EmployeeWorkService._();
  static final instance = EmployeeWorkService._();
  final _db = FirebaseFirestore.instance;

  Future<Map<String,dynamic>> _membership() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in first.');
    final membership = await _db.collection('staff_memberships')
        .doc(user.uid).get();
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
    final m = await _membership();
    final fid = m['facilityId'];
    if (fid is! String || fid.isEmpty) throw StateError('Invalid facility.');
    return fid;
  }

  Future<void> _canOperate() async {
    final m = await _membership();
    if (m['role'] != 'windowOfficer' && m['role'] != 'supervisor') {
      throw StateError('Your assigned role cannot manage queue tickets.');
    }
  }

  Stream<QuerySnapshot<Map<String,dynamic>>> tickets(String fid) =>
      _db.collection('bookings').where('facilityId', isEqualTo: fid).snapshots();

  Future<void> _log(String fid, String label, String ticketId) async {
    await _db.collection('facilities').doc(fid).collection('queue_logs').add({
      'label': label, 'identifier': ticketId.length > 25
        ? ticketId.substring(0, 25) : ticketId,
      'outcome': 'verified',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> checkIn(String input) async {
    await _canOperate();
    final fid = await _facility();
    var id = input.trim();
    if (id.startsWith('DAWROK|')) {
      final parts = id.split('|');
      final entry = parts.where((p) => p.startsWith('ticket=')).toList();
      if (entry.length != 1) throw StateError('Invalid ticket QR.');
      id = entry.single.substring(7);
    }
    if (id.isEmpty) throw StateError('Enter a ticket number or QR payload.');
    final ref = _db.collection('bookings').doc(id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || data['facilityId'] != fid) {
        throw StateError('This ticket does not belong to your facility.');
      }
      if (data['status'] != 'waiting' && data['status'] != 'called') {
        throw StateError('This ticket is not available for check-in.');
      }
      if (data['checkedIn'] == true) throw StateError('Already checked in.');
      tx.update(ref, {'checkedIn': true});
    });
    await _log(fid, 'Ticket check-in', id);
    return 'Ticket verified and checked in.';
  }

  Future<String> changeTicket(String id, String action) async {
    await _canOperate();
    final fid = await _facility();
    final ref = _db.collection('bookings').doc(id);
    if (action == 'served' || action == 'absent') {
      await CitizenAccountService.instance.completeTicket(id, fid, action);
      await _log(fid, action, id);
      return 'Ticket updated: $action';
    }
    await _db.runTransaction((tx) async {
      final ticket = await tx.get(ref);
      final data = ticket.data();
      if (data == null || data['facilityId'] != fid) {
        throw StateError('Ticket not found in your facility.');
      }
      final state = data['status'];
      if (action == 'called' && state == 'waiting') {
        tx.update(ref, {'status':'called',
          'calledAt': FieldValue.serverTimestamp()});
      } else if (action == 'postpone' && state == 'called') {
        tx.update(ref, {'status':'waiting',
          'postponements': FieldValue.increment(1)});
      } else {
        throw StateError('Ticket cannot be $action from state $state.');
      }
    });
    await _log(fid, action, id);
    return 'Ticket updated: $action';
  }
}
