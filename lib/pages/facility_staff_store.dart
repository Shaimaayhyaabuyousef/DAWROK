import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/facility_context.dart';
import '../services/staff_pairing_service.dart';

enum StaffState { active, suspended, pending }
enum StaffRole { windowOfficer, supervisor, logistics }

class FacilityStaff {
  final int id;
  String name, nationalId, window, description;
  StaffRole role;
  StaffState state;
  String? photoUrl, inviteHash, linkedUid;
  String joinStatus;
  String? requesterEmail, requestStatus;
  FacilityStaff({
    required this.id, required this.name, required this.nationalId,
    required this.window, required this.role, required this.state,
    this.description = '', this.photoUrl, this.inviteHash,
    this.linkedUid, this.joinStatus = 'legacy',
    this.requesterEmail, this.requestStatus,
  });
  bool get hasJoinRequest => requestStatus == 'requested';
}

class StaffInviteResult {
  final FacilityStaff member;
  final String code;
  final DateTime expiresAt;
  const StaffInviteResult(this.member, this.code, this.expiresAt);
}

class FacilityStaffStore extends ChangeNotifier {
  FacilityStaffStore._() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _generation++;
      _staffSub?.cancel(); _requestsSub?.cancel();
      _staffSub = null; _requestsSub = null;
      _facilityId = null; _staff.clear(); _requests.clear();
      error = null; notifyListeners(); _listen();
    });
  }
  static final instance = FacilityStaffStore._();
  final _db = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? _staffSub, _requestsSub;
  final List<FacilityStaff> _staff = [];
  final Map<String,Map<String,dynamic>> _requests = {};
  String? _facilityId, error;
  int _generation = 0;
  List<FacilityStaff> get staff => List.unmodifiable(_staff);
  CollectionReference<Map<String,dynamic>> _collection(String fid) =>
      _db.collection('facilities').doc(fid).collection('staff');
  CollectionReference<Map<String,dynamic>> get _invites => _db.collection('staff_invites');
  CollectionReference<Map<String,dynamic>> get _joins => _db.collection('staff_join_requests');

  void _publish() {
    for (final item in _staff) {
      final claim = item.inviteHash == null ? null : _requests[item.inviteHash];
      item.requestStatus = claim?['status'] as String?;
      item.requesterEmail = claim?['employeeEmail'] as String?;
    }
    notifyListeners();
  }
  Future<void> _listen() async {
    final generation = ++_generation;
    try {
      final fid = await FacilityContext.instance.requireFacilityId();
      if (generation != _generation) return;
      _facilityId = fid;
      _requestsSub = _joins.where('facilityId', isEqualTo: fid)
          .snapshots().listen((snap) {
        if (generation != _generation) return;
        _requests..clear()..addEntries(snap.docs.map((doc) => MapEntry(doc.id, doc.data())));
        _publish();
      }, onError: (Object e) { error = '$e'; debugPrint('Staff claims: $e'); notifyListeners(); });
      _staffSub = _collection(fid).snapshots().listen((snap) {
        if (generation != _generation) return;
        _staff..clear()..addAll(snap.docs.map((doc) {
          final m = doc.data();
          return FacilityStaff(
            id: int.tryParse(doc.id) ?? 0,
            name: m['name'] as String? ?? '',
            nationalId: m['employeeId'] as String? ?? '',
            window: m['window'] as String? ?? '',
            role: StaffRole.values.firstWhere((x) => x.name == m['role'], orElse: () => StaffRole.windowOfficer),
            state: StaffState.values.firstWhere((x) => x.name == m['state'], orElse: () => StaffState.pending),
            description: m['description'] as String? ?? '',
            inviteHash: m['inviteHash'] as String?,
            linkedUid: m['linkedUid'] as String?,
            joinStatus: m['joinStatus'] as String? ?? 'legacy',
          );
        }));
        error = null; _publish();
      }, onError: (Object e) { error = '$e'; debugPrint('Staff listing: $e'); notifyListeners(); });
    } catch (e) {
      if (generation == _generation) { error = '$e'; debugPrint('Staff facility: $e'); notifyListeners(); }
    }
  }

  Future<String> _fid() async {
    final fid = await FacilityContext.instance.requireFacilityId();
    _facilityId = fid;
    return fid;
  }
  Future<DocumentReference<Map<String,dynamic>>> _ref(FacilityStaff m) async =>
      _collection(await _fid()).doc('${m.id}');

  Future<StaffInviteResult> add({
    required String name, required String nationalId,
    required String window, required StaffRole role,
  }) async {
    final fid = await _fid();
    final id = DateTime.now().microsecondsSinceEpoch;
    final code = StaffPairingService.instance.newCode();
    final hash = StaffPairingService.instance.digest(code);
    final expires = DateTime.now().add(const Duration(hours: 24));
    final staff = _collection(fid).doc('$id');
    final batch = _db.batch();
    batch.set(staff, {
      'name': name.trim(), 'employeeId': nationalId.trim(),
      'window': window.trim(), 'role': role.name,
      'state': 'pending', 'description': '',
      'joinStatus': 'invited', 'inviteHash': hash,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_invites.doc(hash), {
      'facilityId': fid, 'staffId': '$id', 'status': 'issued',
      'issuedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expires),
    });
    await batch.commit();
    return StaffInviteResult(
      FacilityStaff(id: id, name: name, nationalId: nationalId,
        window: window, role: role, state: StaffState.pending,
        inviteHash: hash, joinStatus: 'invited'),
      code, expires,
    );
  }

  Future<void> update(FacilityStaff m, {
    required String name, required String nationalId,
    required String window, required StaffRole role,
  }) async {
    await (await _ref(m)).update({
      'name': name.trim(), 'employeeId': nationalId.trim(),
      'window': window.trim(), 'role': role.name,
    });
  }

  Future<StaffInviteResult> replaceInvite(FacilityStaff m) async {
    final fid = await _fid();
    final ref = _collection(fid).doc('${m.id}');
    final code = StaffPairingService.instance.newCode();
    final hash = StaffPairingService.instance.digest(code);
    final expires = DateTime.now().add(const Duration(hours: 24));
    await _db.runTransaction((tx) async {
      final staff = await tx.get(ref);
      if (!staff.exists) throw StateError('Employee not found.');
      final data = staff.data()!;
      if (data['joinStatus'] == 'approved' || data['linkedUid'] != null) {
        throw StateError('This employee is already approved.');
      }
      final previous = data['inviteHash'] as String?;
      if (previous != null) {
        final oldClaim = await tx.get(_joins.doc(previous));
        if (oldClaim.data()?['status'] == 'requested') {
          throw StateError('Review the employee request before replacing its code.');
        }
      }
      tx.set(_invites.doc(hash), {
        'facilityId': fid, 'staffId': '${m.id}', 'status': 'issued',
        'issuedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expires),
      });
      if (previous != null) tx.update(_invites.doc(previous), {
        'status': 'revoked', 'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'inviteHash': hash, 'joinStatus': 'invited', 'state': 'pending',
      });
    });
    return StaffInviteResult(m, code, expires);
  }

  Future<void> approve(FacilityStaff m) async {
    final fid = await _fid();
    final staffRef = _collection(fid).doc('${m.id}');
    await _db.runTransaction((tx) async {
      final staff = await tx.get(staffRef);
      final data = staff.data();
      if (data == null || data['joinStatus'] != 'invited' || data['state'] != 'pending') {
        throw StateError('Employee is not awaiting approval.');
      }
      final hash = data['inviteHash'] as String?;
      if (hash == null) throw StateError('No invitation found.');
      final joinRef = _joins.doc(hash);
      final inviteRef = _invites.doc(hash);
      final join = await tx.get(joinRef);
      final invite = await tx.get(inviteRef);
      if (join.data()?['status'] != 'requested' ||
          join.data()?['staffId'] != '${m.id}' ||
          join.data()?['facilityId'] != fid ||
          invite.data()?['status'] != 'issued') {
        throw StateError('Employee has not requested to join with this code.');
      }
      final uid = join.data()?['employeeUid'] as String?;
      if (uid == null || uid.isEmpty) throw StateError('Employee account is missing.');
      final membershipRef = _db.collection('staff_memberships').doc(uid);
      final existing = await tx.get(membershipRef);
      if (existing.exists) throw StateError('This employee is already linked.');
      tx.update(staffRef, {
        'state': 'active', 'joinStatus': 'approved', 'linkedUid': uid,
      });
      tx.update(joinRef, {
        'status': 'approved', 'reviewedAt': FieldValue.serverTimestamp(),
      });
      tx.update(inviteRef, {
        'status': 'redeemed', 'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(membershipRef, {
        'facilityId': fid, 'staffId': '${m.id}', 'role': data['role'],
        'window': data['window'], 'inviteHash': hash, 'state': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> reject(FacilityStaff m) async {
    final fid = await _fid();
    final staffRef = _collection(fid).doc('${m.id}');
    await _db.runTransaction((tx) async {
      final staff = await tx.get(staffRef);
      final hash = staff.data()?['inviteHash'] as String?;
      if (hash == null || staff.data()?['state'] != 'pending') {
        throw StateError('No pending staff member.');
      }
      final joinRef = _joins.doc(hash);
      final inviteRef = _invites.doc(hash);
      final claim = await tx.get(joinRef);
      if (claim.data()?['status'] != 'requested') {
        throw StateError('No request is waiting for approval.');
      }
      tx.update(joinRef, {
        'status': 'rejected', 'reviewedAt': FieldValue.serverTimestamp(),
      });
      tx.update(inviteRef, {
        'status': 'revoked', 'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(staffRef, {
        'joinStatus': 'rejected', 'state': 'suspended',
      });
    });
  }

  Future<void> changeState(FacilityStaff m, StaffState state) async {
    if (m.joinStatus != 'approved' || m.linkedUid == null ||
        !(state == StaffState.active || state == StaffState.suspended)) {
      throw StateError('A confirmed employee is required.');
    }
    final ref = await _ref(m);
    final membership = _db.collection('staff_memberships').doc(m.linkedUid);
    final batch = _db.batch();
    batch.update(ref, {'state': state.name});
    batch.update(membership, {'state': state.name});
    await batch.commit();
  }

  Future<void> remove(FacilityStaff m) async {
    final ref = await _ref(m);
    if (m.joinStatus == 'approved') {
      throw StateError('Suspend approved staff before removing their account.');
    }
    final batch = _db.batch();
    batch.delete(ref);
    if (m.inviteHash != null) {
      batch.update(_invites.doc(m.inviteHash), {
        'status': 'revoked', 'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
