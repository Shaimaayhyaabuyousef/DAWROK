import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';

/// A DEMO capture is not an identity verification.
/// Real approval can only be recorded by a trusted backend/admin.
enum CitizenIdStatus { notSubmitted, demoReady, pending, verified, rejected }

class DemoBookingIdentity {
  final String identifier;
  final bool isDemo;
  const DemoBookingIdentity(this.identifier, {this.isDemo = true});
}

class CitizenIdentityService {
  CitizenIdentityService._();
  static final CitizenIdentityService instance = CitizenIdentityService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to continue.');
    return user;
  }

  DocumentReference<Map<String, dynamic>> _demoRef(String uid) =>
      _db.collection('demo_identity_checks').doc(uid);

  DocumentReference<Map<String, dynamic>> _realRef(String uid) =>
      _db.collection('identity_verifications').doc(uid);

  Future<void> _requireCitizen(User user) async {
    final profile = await _db.collection('users').doc(user.uid).get();
    if (profile.data()?['role'] != 'citizen') {
      throw StateError('This flow is only for citizen accounts.');
    }
    final claimRole = (await user.getIdTokenResult()).claims?['role'];
    if (claimRole != null && claimRole != 'citizen') {
      throw StateError('This account is not a citizen account.');
    }
  }

  /// Returns the actual review status only when a real review exists.
  /// Demo completion is reported separately as demoReady.
  Future<CitizenIdStatus> status() async {
    final user = _user;
    await _requireCitizen(user);
    final demo = await _demoRef(user.uid).get();
    if (demo.data()?['status'] == 'demo_ready' &&
        demo.data()?['mode'] == 'demo_only') {
      return CitizenIdStatus.demoReady;
    }
    // Real review data, if present, is a separate, administrator-managed flow.
    // During Spark demo development the collection may not be readable yet.
    try {
      final real = await _realRef(user.uid).get();
      switch (real.data()?['status']) {
        case 'verified': return CitizenIdStatus.verified;
        case 'pending': return CitizenIdStatus.pending;
        case 'rejected': return CitizenIdStatus.rejected;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    return CitizenIdStatus.notSubmitted;
  }

  /// This method never uploads photos, national IDs, or phone numbers.
  /// The selected image is inspected ONLY on this device for the demo.
  Future<void> submitDemo({required XFile image}) async {
    final user = _user;
    await _requireCitizen(user);
    final bytes = await image.length();
    if (bytes == 0 || bytes > 5 * 1024 * 1024) {
      throw ArgumentError('Choose a nonempty photo smaller than 5 MB.');
    }
    final old = await _demoRef(user.uid).get();
    if (old.exists) return; // Already completed the demo; no overwrite.

    await _demoRef(user.uid).set({
      'userId': user.uid,
      'mode': 'demo_only',
      'status': 'demo_ready',
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  /// A synthetic test identifier, never a National ID.
  /// Only useful for local demo tickets; NEVER use it for real queue access.
  Future<DemoBookingIdentity?> demoBookingIdentity() async {
    final user = _user;
    await _requireCitizen(user);
    final demo = await _demoRef(user.uid).get();
    final data = demo.data();
    if (data?['mode'] != 'demo_only' || data?['status'] != 'demo_ready') {
      return null;
    }
    return DemoBookingIdentity('DEMO-${user.uid.substring(0, 8).toUpperCase()}');
  }

  /// Kept for future production use, but demoReady never qualifies.
  Future<String?> verifiedNationalId() async {
    final user = _user;
    await _requireCitizen(user);
    final doc = await _realRef(user.uid).get();
    if (doc.data()?['status'] != 'verified') return null;
    final id = doc.data()?['nationalId'];
    return id is String ? id : null;
  }
}
