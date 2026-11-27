import 'phone_login.dart';
import 'national_id.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/citizen_registration_draft.dart';

/// Create citizens after the 3 signup steps, using their phone and password.
/// No ID photographs are uploaded. The typed ID is self-reported, NOT verified.
class CitizenSignupService {
  CitizenSignupService._();
  static final CitizenSignupService instance = CitizenSignupService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> complete({
    required String pin,
    CitizenRegistrationDraft? draft,
  }) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain four digits.');
    }

    User? user;
    if (draft != null) {
      final email = mobileLoginId(draft.phone);
      final fullName = draft.fullName.trim();
      final nationalId = draft.nationalId.trim();
      final phone = localMobile(draft.phone)!;

      if (fullName.length < 3 || fullName.length > 120) {
        throw const FormatException('Enter your full name.');
      }
      if (!validNationalId(nationalId)) {
        throw const FormatException('This ID number is not valid.');
      }

      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: draft.password,
      );
      user = result.user;
      if (user == null) throw StateError('Failed to create Firebase account.');

      // One Firestore batch means the profile, self-reported ID and demo
      // progress cannot be half-written. The matching rules use getAfter().
      try {
        // One ID number belongs to one account. Reading a claim owned by
        // another account is denied, which means the number is taken.
        final claimRef = _db.collection('national_id_claims').doc(nationalId);
        try {
          await claimRef.get();
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            throw const FormatException(
              'This ID number is already registered to another account.',
            );
          }
          rethrow;
        }
        final batch = _db.batch();
        batch.set(claimRef, {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(_db.collection('users').doc(user.uid), {
          'uid': user.uid,
          'role': 'citizen',
          'displayName': fullName,
          'email': email,
          'phone': phone,
          'address': '',
          'photoUrl': '',
          'providers': ['password'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(_db.collection('citizen_identity').doc(user.uid), {
          'userId': user.uid,
          'nationalId': nationalId,
          'status': 'self_reported',
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(_db.collection('demo_identity_checks').doc(user.uid), {
          'userId': user.uid,
          'mode': 'demo_only',
          'status': 'demo_ready',
          'submittedAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
        try {
          await user.updateDisplayName(fullName);
        } catch (e) {
          debugPrint('Auth display-name sync failed: $e');
        }
      } catch (_) {
        // Only remove the newly-created Firebase Auth user when the batch
        // fails. Firestore batch writes are atomic.
        try {
          await user.delete();
        } catch (_) {
          // A re-login may be needed to delete the partially made Auth user.
        }
        rethrow;
      }
    } else {
      user = _auth.currentUser;
      if (user == null) throw StateError('Sign in to complete registration.');
      final profile = await _db.collection('users').doc(user.uid).get();
      if (profile.data()?['role'] != 'citizen') {
        throw StateError('Only citizens can complete registration.');
      }
      final ref = _db.collection('demo_identity_checks').doc(user.uid);
      if (!(await ref.get()).exists) {
        await ref.set({
          'userId': user.uid,
          'mode': 'demo_only',
          'status': 'demo_ready',
          'submittedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // The demo PIN is NOT a Firebase login factor. Do not save it in Firestore
    // or fall back to plaintext/localStorage if secure storage is unavailable.
    if (!kIsWeb) {
      try {
        await _secureStorage.write(key: 'dawrok_demo_pin_${user.uid}', value: pin);
      } catch (e) {
        debugPrint('Secure demo PIN storage unavailable: $e');
      }
    }
  }
}
