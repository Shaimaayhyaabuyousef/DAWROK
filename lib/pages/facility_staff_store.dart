import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/facility_context.dart';
import '../services/queue_assignment_service.dart';
import '../services/staff_pairing_service.dart';

enum StaffState { active, suspended, pending }
enum StaffRole { windowOfficer, supervisor, logistics }

class FacilityStaff {
  final int id;
  String name, nationalId, window, description;
  StaffRole role;
  StaffState state;
  String? photoUrl, inviteHash, linkedUid;
  String? linkCode;
  DateTime? codeExpiresAt;
  String joinStatus;
  String? requesterEmail, requestStatus;
  FacilityStaff({
    required this.id, required this.name, required this.nationalId,
    required this.window, required this.role, required this.state,
    this.description = '', this.photoUrl, this.inviteHash,
    this.linkedUid, this.joinStatus = 'legacy',
    this.linkCode, this.codeExpiresAt,
    this.requesterEmail, this.requestStatus,
  });
  bool get hasJoinRequest => requestStatus == 'requested';
}

class StaffInviteResult {
  final FacilityStaff member;
  final String code;
  final DateTime expiresAt;
  final String facilityNumber;
  const StaffInviteResult(this.member, this.code, this.expiresAt, this.facilityNumber);
}

class FacilityStaffStore extends ChangeNotifier {
  FacilityStaffStore._() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _generation++;
      _staffSub?.cancel(); _requestsSub?.cancel();
      _staffSub = null; _requestsSub = null;
      _assignSub?.cancel(); _assignments = {};
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

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _assignSub;
  Map<String, dynamic> _assignments = {};
  void _publish() {
    for (final item in _staff) {
      final assignment = _assignments[item.linkedUid];
      item.window = assignment is Map
        ? 'Queue ${assignment['queueId'].toString().replaceFirst('window_', '')} • ${assignment['windowNumber'] == 0 ? 'Direct service' : 'Window ${assignment['windowNumber']}'}'
        : 'Awaiting vacant service position';
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
      await _assignSub?.cancel();
      _assignSub = _db.collection('facilities').doc(fid).collection('operations').doc('assignments').snapshots().listen((snap) {
        if (generation != _generation) return;
        _assignments = Map<String, dynamic>.from(snap.data()?['assignments'] as Map? ?? {});
        _publish();
      }, onError: (Object e) { if (generation == _generation) { error = 'Cannot load service assignments: $e'; notifyListeners(); } });
      _requestsSub = _joins.where('facilityId', isEqualTo: fid)
          .snapshots().listen((snap) {
        if (generation != _generation) return;
        _requests..clear()..addEntries(snap.docs.map((doc) => MapEntry(doc.id, doc.data())));
        _publish();
      }, onError: (Object e) { error = '$e'; debugPrint('Staff claims: $e'); notifyListeners(); });
      _staffSub = _collection(fid).snapshots().listen((snap) {
        if (generation != _generation) return;
        _applyStaffDocs(snap.docs);
      }, onError: (Object e) {
        error = 'Cannot load employee cards: $e';
        debugPrint('DAWROK Staff list: $e');
        notifyListeners();
      });
    } catch (e) {
      if (generation == _generation) {
        error = 'Cannot load facility account: $e';
        debugPrint('DAWROK Staff facility: $e');
        notifyListeners();
      }
    }
  }

  void _applyStaffDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    _staff..clear()..addAll(docs.map((doc) {
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
            linkCode: m['linkCode'] as String?,
            codeExpiresAt: (m['codeExpiresAt'] as Timestamp?)?.toDate(),
            linkedUid: m['linkedUid'] as String?,
            joinStatus: m['joinStatus'] as String? ?? 'legacy',
          );
        }));
    error = null;
    _publish();
  }

  /// Explicit server read after writes and when visiting the Staff screen.
  /// This keeps the cards synchronized even if the real-time listener failed.
  Future<void> refresh() async {
    try {
      final fid = await _fid();
      final snap = await _collection(fid)
          .get(const GetOptions(source: Source.server));
      _applyStaffDocs(snap.docs);
      debugPrint('DAWROK: loaded ${snap.docs.length} staff records '
          'from facilities/$fid/staff');
    } on FirebaseException catch (e) {
      error = 'Could not read staff from Firebase: [${e.code}] ${e.message}';
      debugPrint('DAWROK $error');
      notifyListeners();
      rethrow;
    } catch (e) {
      error = 'Could not refresh staff: $e';
      debugPrint('DAWROK $error');
      notifyListeners();
      rethrow;
    }
  }

  Future<String> _fid() async {
    final fid = await FacilityContext.instance.requireFacilityId();
    _facilityId = fid;
    return fid;
  }
  Future<DocumentReference<Map<String,dynamic>>> _ref(FacilityStaff m) async =>
      _collection(await _fid()).doc('${m.id}');

  String _invitationNumber(DocumentSnapshot<Map<String, dynamic>> facility) {
    final number = facility.data()?['facilityNumber'];
    if (number is! String || !RegExp(r'^[1-9][0-9]{5}$').hasMatch(number)) {
      throw StateError('Ask the administrator to assign this facility a number before inviting staff.');
    }
    return number;
  }

  Future<StaffInviteResult> add({
    required String name, required String nationalId,
    required String window, required StaffRole role,
  }) async {
    final facility = await FacilityContext.instance.requireFacility();
    final fid = facility.id;
    final number = _invitationNumber(facility);
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
      'linkCode': code, 'codeExpiresAt': Timestamp.fromDate(expires),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_invites.doc(hash), {
      'facilityId': fid, 'staffId': '$id', 'status': 'issued',
      'issuedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expires),
    });
    try {
      await batch.commit();
      // Check the actual server docs: do not announce a successful save
      // merely because the local form submitted.
      final savedStaff = await staff.get(
        const GetOptions(source: Source.server));
      final savedInvite = await _invites.doc(hash).get(
        const GetOptions(source: Source.server));
      if (!savedStaff.exists || !savedInvite.exists ||
          savedStaff.data()?['linkCode'] != code) {
        throw StateError(
          'The staff invitation could not be verified on Firebase. '
          'Check facilities/$fid/staff/$id and staff_invites/$hash.');
      }
      debugPrint('DAWROK: staff and invite saved on server '
          'at facilities/$fid/staff/$id');
      try {
        await refresh();
      } catch (e) {
        // Both docs already exist; a list refresh error must not
        // hide the usable invitation code.
        debugPrint('DAWROK: invitation saved, list refresh failed: $e');
      }
      return StaffInviteResult(
        FacilityStaff(id: id, name: name, nationalId: nationalId,
          window: window, role: role, state: StaffState.pending,
          inviteHash: hash, joinStatus: 'invited',
          linkCode: code, codeExpiresAt: expires),
        code, expires, number,
      );
    } on FirebaseException catch (e) {
      debugPrint('DAWROK: failed to create staff invitation: '
          '[${e.code}] ${e.message}; facilityId=$fid');
      rethrow;
    }
  }

  Future<void> update(FacilityStaff m, {
    required String name, required String nationalId,
    required String window, required StaffRole role,
  }) async {
    final ref = await _ref(m);
    final batch = _db.batch();
    batch.update(ref, {'name':name.trim(), 'employeeId':nationalId.trim(), 'role':role.name});
    if (m.linkedUid != null && m.joinStatus == 'approved') {
      batch.update(_db.collection('staff_memberships').doc(m.linkedUid), {'role':role.name});
    }
    await batch.commit();
    await QueueAssignmentService.instance.rebalance(await _fid());
  }

  Future<StaffInviteResult> replaceInvite(FacilityStaff m) async {
    final facility = await FacilityContext.instance.requireFacility();
    final fid = facility.id;
    final number = _invitationNumber(facility);
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
      DocumentSnapshot<Map<String, dynamic>>? oldInvite;
      if (previous != null) {
        final oldClaim = await tx.get(_joins.doc(previous));
        oldInvite = await tx.get(_invites.doc(previous));
        if (oldClaim.data()?['status'] == 'requested') {
          throw StateError('Review the employee request before replacing its code.');
        }
      }
      tx.set(_invites.doc(hash), {
        'facilityId': fid, 'staffId': '${m.id}', 'status': 'issued',
        'issuedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expires),
      });
      if (previous != null && oldInvite?.data()?['status'] == 'issued') {
        tx.update(_invites.doc(previous), {
        'status': 'revoked', 'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(ref, {
        'inviteHash': hash, 'joinStatus': 'invited', 'state': 'pending',
        'linkCode': code, 'codeExpiresAt': Timestamp.fromDate(expires),
      });
    });
    return StaffInviteResult(m, code, expires, number);
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
      // Do not read another user's membership from a facility account.
      // If it already exists, the set is an UPDATE and Firestore rules deny
      // replacing its immutable fields.
      tx.update(staffRef, {
        'state': 'active', 'joinStatus': 'approved', 'linkedUid': uid,
        'linkCode': FieldValue.delete(), 'codeExpiresAt': FieldValue.delete(),
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
    await QueueAssignmentService.instance.rebalance(fid);
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
        'linkCode': FieldValue.delete(), 'codeExpiresAt': FieldValue.delete(),
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
    await QueueAssignmentService.instance.rebalance(await _fid());
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
