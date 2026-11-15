import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Only the administrator provisions a facility account and its facility document.
/// No facility is synthesized when the database is empty.
class FacilityContext {
  FacilityContext._();
  static final instance = FacilityContext._();

  final FirebaseFirestore db = FirebaseFirestore.instance;

  Future<String> requireFacilityId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Please sign in.');
    final profile = await db.collection('users').doc(user.uid).get();
    final data = profile.data();
    if (data?['role'] != 'facility' || data?['status'] != 'active') {
      throw StateError('An active facility account is required.');
    }
    final id = data?['facilityId'];
    if (id is! String || id.isEmpty) {
      throw StateError('This facility account has not been provisioned by an administrator.');
    }
    final facility = await db.collection('facilities').doc(id).get();
    if (!facility.exists || facility.data()?['ownerUid'] != user.uid ||
        facility.data()?['isActive'] != true) {
      throw StateError('Your facility is not active or is not linked to this account.');
    }
    return id;
  }
}
