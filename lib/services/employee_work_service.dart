import 'queue_operations_service.dart';
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

  Future<String> checkIn(String input, String qid, int window) async {
    await _canOperate();
    final fid = await _facility();
    var id = input.trim();
    if (id.startsWith('DAWROK|')) {
      final parts = id.split('|').where((p) => p.startsWith('ticket=')).toList();
      if (parts.length != 1) throw StateError('Invalid QR.');
      id = parts.single.substring(7);
    }
    await QueueOperationsService.instance.checkIn(id, fid, qid, window);
    await _log(fid, 'Checked in', id);
    return 'Ticket checked in.';
  }
  Future<String> callNext(String qid, int window) async {
    await _canOperate();
    return QueueOperationsService.instance.callNext(await _facility(), qid, window);
  }
  Future<String> changeTicket(String id, String action, String qid, int window) async {
    await _canOperate();
    final fid = await _facility();
    if (action == 'postpone') {
      await QueueOperationsService.instance.postpone(id, fid, qid, window);
    } else {
      await QueueOperationsService.instance.close(id, fid, action);
    }
    return 'Ticket updated: $action';
  }
}
