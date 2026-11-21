import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A staff link code is a one-time invitation, NOT a password or a login
/// credential. The employee must first authenticate with Firebase Auth.
/// This service is ready for the future employee screens.
class StaffPairingService {
  StaffPairingService._();
  static final instance = StaffPairingService._();

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _pattern = RegExp(r'^[A-HJ-NP-Z2-9]{20}$');
  final _db = FirebaseFirestore.instance;

  String normalize(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  String digest(String code) {
    final cleaned = normalize(code);
    if (!_pattern.hasMatch(cleaned)) {
      throw const FormatException('Enter a valid staff invitation code.');
    }
    return sha256.convert(utf8.encode(cleaned)).toString();
  }

  String newCode() {
    final random = Random.secure();
    final raw = List.generate(
      20,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
    return [
      raw.substring(0, 4),
      raw.substring(4, 8),
      raw.substring(8, 12),
      raw.substring(12, 16),
      raw.substring(16, 20),
    ].join('-');
  }

  /// Creates exactly one join request for a valid invitation. The Firebase
  /// security rules verify identity, expiry and invitation ownership again.
  Future<void> requestToJoin(String displayedCode, {
    String? facilityId, String? phone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in with an employee account before using the code.');
    }
    if (user.email == null || user.email!.isEmpty) {
      throw StateError('An email-based Firebase Auth account is required.');
    }
    final hash = digest(displayedCode);
    final invite = await _db.collection('staff_invites').doc(hash).get();
    final data = invite.data();
    final expiry = (data?['expiresAt'] as Timestamp?)?.toDate();
    if (data == null || data['status'] != 'issued' ||
        expiry == null || !expiry.isAfter(DateTime.now())) {
      throw StateError('Invitation not found, expired or already used.');
    }
    if (facilityId != null && facilityId.trim().isNotEmpty &&
        facilityId.trim() != data['facilityId']) {
      throw StateError('Facility ID does not match the invitation.');
    }
    if (phone != null && phone.trim().isNotEmpty &&
        !RegExp(r'^\+?[0-9\s-]{8,20}$').hasMatch(phone.trim())) {
      throw StateError('Enter a valid phone number.');
    }
    await _db.collection('staff_join_requests').doc(hash).set({
      'facilityId': data['facilityId'],
      'staffId': data['staffId'],
      'employeeUid': user.uid,
      'employeeEmail': user.email!,
      'phone': (phone ?? '').trim(),
      'status': 'requested',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> requestStatus(String displayedCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in first.');
    final hash = digest(displayedCode);
    final request = await _db.collection('staff_join_requests').doc(hash).get();
    if (!request.exists) return 'not_requested';
    if (request.data()?['employeeUid'] != user.uid) {
      throw StateError('This request belongs to a different account.');
    }
    return request.data()?['status'] as String? ?? 'unknown';
  }

  Future<Map<String, dynamic>?> myApprovedMembership() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final snap = await _db.collection('staff_memberships').doc(user.uid).get();
    return snap.data();
  }
}

