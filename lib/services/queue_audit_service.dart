import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QueueAuditService {
  static Future<void> record(
    String fid,
    String label,
    String bookingId, {
    String outcome = 'verified',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to record a queue action.');
    final db = FirebaseFirestore.instance;
    final me = await db.collection('users').doc(uid).get();
    final owner = me.data()?['role'] == 'facility';
    final member = owner
        ? null
        : (await db.collection('staff_memberships').doc(uid).get()).data();
    final validId = outcome == 'invalid' ? '' : bookingId;
    await db.collection('facilities').doc(fid).collection('queue_logs').add({
      'actorUid': uid,
      'staffId': owner ? '' : member?['staffId'] ?? '',
      'actorRole': me.data()?['role'] == 'facility' ? 'facility' : 'employee',
      'bookingId': validId,
      'label': label,
      'identifier': validId.isEmpty
          ? 'Invalid code'
          : validId.substring(0, validId.length.clamp(0, 25)),
      'outcome': outcome,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
