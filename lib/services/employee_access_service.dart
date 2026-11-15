import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'staff_pairing_service.dart';

/// Persists across app/browser restarts. No page must remain open while the
/// facility reviews the employee's join request.
class EmployeeAccessService {
  EmployeeAccessService._();
  static final instance = EmployeeAccessService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> routeFor(User? user) async {
    if (user == null) return 'employee_login_screen';
    final membership = await _db.collection('staff_memberships').doc(user.uid).get();
    if (membership.exists) {
      if (membership.data()?['state'] != 'active') return 'employee_pending_screen';
      final profile = await _db.collection('staff_profiles').doc(user.uid).get();
      return profile.data()?['profileCompleted'] == true
          ? 'employee_home_screen' : 'employee_profile_screen';
    }
    final claims = await _db.collection('staff_join_requests')
        .where('employeeUid', isEqualTo: user.uid).limit(1).get();
    if (claims.docs.isNotEmpty) return 'employee_pending_screen';
    return 'employee_login_screen';
  }

  Future<String> signIn({required String email, required String password,
    String? invitationCode, String? facilityId, String? phone}) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(), password: password);
    if (result.user == null) throw StateError('Could not sign in.');
    if (invitationCode != null && invitationCode.trim().isNotEmpty) {
      await StaffPairingService.instance.requestToJoin(invitationCode,
        facilityId: facilityId, phone: phone);
    }
    return routeFor(result.user);
  }

  Future<String> createAccount({
    required String email, required String password,
    required String invitationCode,
    String? facilityId,
    String? phone,
  }) async {
    if (invitationCode.trim().isEmpty) {
      throw StateError('Ask your facility for a staff invitation code first.');
    }
    if (password.length < 6) {
      throw StateError('Password must contain at least 6 characters.');
    }
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(), password: password);
    if (result.user == null) throw StateError('Could not create staff account.');
    await StaffPairingService.instance.requestToJoin(invitationCode,
      facilityId: facilityId, phone: phone);
    return 'employee_pending_screen';
  }

  Future<String> currentDestination() => routeFor(_auth.currentUser);
}
