import 'phone_login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'citizen_identity_service.dart';
import 'employee_access_service.dart';

/// Shared sign-in: the role is resolved from a trusted Firestore profile.
/// This service never creates a facility account or changes anyone's role.
class AppAuthService {
  AppAuthService._();

  static final AppAuthService instance = AppAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: mobileLoginId(phone),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('تعذّر إكمال تسجيل الدخول.');
    }

    try {
      return await destinationForUser(user);
    } catch (_) {
      // Do not leave an unauthorized user signed into this app.
      await _auth.signOut();
      rethrow;
    }
  }

  Future<String> destinationForUser(User user) async {
    // The rules for users/{uid} must allow the user to read *only*
    // their own document. The role is provisioned by an admin.
    final snapshot = await _db.collection('users').doc(user.uid).get();
    final data = snapshot.data();
    if (data == null) {
      // Employees have independent Auth identities; owner approval creates
      // a protected membership instead of a self-assigned role in users.
      return EmployeeAccessService.instance.routeFor(user);
    }

    final role = data['role'];
    final token = await user.getIdTokenResult();
    final claimRole = token.claims?['role'];
    if (claimRole != null && claimRole != role) {
      throw StateError('صلاحية الحساب لا تطابق بياناته.');
    }

    if (role == 'citizen') {
      final state = await CitizenIdentityService.instance.status();
      // A completed demo is allowed into the LOCAL test UI, not real queues.
      if (state == CitizenIdStatus.demoReady ||
          state == CitizenIdStatus.verified) {
        return 'home_screen';
      }
      return 'citizen_id_verification';
    }

    if (role == 'facility') {
      if (data['status'] != 'active') {
        throw StateError('حساب المنشأة غير مفعّل.');
      }
      final facilityId = data['facilityId'];
      if (facilityId is! String || facilityId.trim().isEmpty) {
        throw StateError('لم يُربط هذا الحساب بمنشأة بعد.');
      }
      return 'facility_home_screen';
    }

    throw StateError('نوع الحساب غير مدعوم في شاشة الدخول.');
  }

  /// Used by Splash to restore a previously signed-in citizen or facility.
  Future<String> destinationForCurrentSession() async {
    final user = _auth.currentUser;
    if (user == null) return 'onboarding';

    try {
      return await destinationForUser(user);
    } catch (_) {
      // An invalid or inaccessible profile must not route to a facility.
      await _auth.signOut();
      return 'login';
    }
  }
}
