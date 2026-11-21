import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


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

  /// Returning employees always sign in using email and password only.
  /// A link code is never required for login and is never re-submitted here.
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (result.user == null) throw StateError('Could not sign in.');
    return routeFor(result.user);
  }

  Future<void> authenticateForJoin({
    required String email,
    required String password,
    required bool existingAccount,
  }) async {
    final result = existingAccount
        ? await _auth.signInWithEmailAndPassword(email: email.trim(), password: password)
        : await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    if (result.user == null) throw StateError('Could not authenticate the employee account.');
  }

  Future<String> currentDestination() => routeFor(_auth.currentUser);
}
