import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/facility_context.dart';
enum StaffState { active, suspended, pending }
enum StaffRole { windowOfficer, supervisor, logistics }

class FacilityStaff {
  final int id;
  String name, nationalId, window, description;
  StaffRole role;
  StaffState state;
  String? photoUrl;
  FacilityStaff({required this.id, required this.name, required this.nationalId,
    required this.window, required this.role, required this.state,
    this.description = '', this.photoUrl});
}

class FacilityStaffStore extends ChangeNotifier {
  FacilityStaffStore._() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      _subscription?.cancel();
      _facilityId = null;
      _staff.clear();
      notifyListeners();
      _listen();
    });
  }
  static final instance = FacilityStaffStore._();
  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? _subscription;
  final List<FacilityStaff> _staff = [];
  String? _facilityId;
  String? error;
  List<FacilityStaff> get staff => List.unmodifiable(_staff);

  Future<void> _listen() async {
    try {
      final id = await FacilityContext.instance.requireFacilityId();
      _facilityId = id;
      _subscription = _db.collection('facilities').doc(id).collection('staff')
          .snapshots().listen((snap) {
        _staff
          ..clear()
          ..addAll(snap.docs.map((d) {
            final x = d.data();
            return FacilityStaff(
              id: int.tryParse(d.id) ?? 0,
              name: x['name'] as String? ?? '',
              nationalId: x['employeeId'] as String? ?? '',
              window: x['window'] as String? ?? '',
              role: StaffRole.values.firstWhere(
                (v) => v.name == x['role'], orElse: () => StaffRole.windowOfficer),
              state: StaffState.values.firstWhere(
                (v) => v.name == x['state'], orElse: () => StaffState.pending),
              description: x['description'] as String? ?? '',
            );
          }));
        error = null;
        notifyListeners();
      }, onError: (Object e) { error = e.toString(); notifyListeners(); });
    } catch (e) { error = e.toString(); notifyListeners(); }
  }

  DocumentReference<Map<String,dynamic>> _ref(int id) {
    final facilityId = _facilityId;
    if (facilityId == null) throw StateError('Facility has not loaded.');
    return _db.collection('facilities').doc(facilityId).collection('staff')
        .doc('$id');
  }

  Future<FacilityStaff> add({
    required String name, required String nationalId,
    required String window, required StaffRole role,
  }) async {
    final fid = await FacilityContext.instance.requireFacilityId();
    final id = DateTime.now().microsecondsSinceEpoch;
    final member = FacilityStaff(id: id, name: name, nationalId: nationalId,
      window: window, role: role, state: StaffState.pending);
    await _db.collection('facilities').doc(fid).collection('staff').doc('$id').set({
      'name': name.trim(), 'employeeId': nationalId.trim(),
      'window': window.trim(), 'role': role.name, 'state': StaffState.pending.name,
      'description': '', 'createdAt': FieldValue.serverTimestamp(),
    });
    return member;
  }

  Future<void> update(FacilityStaff member, {
    required String name, required String nationalId,
    required String window, required StaffRole role,
  }) => _ref(member.id).update({
    'name': name.trim(), 'employeeId': nationalId.trim(),
    'window': window.trim(), 'role': role.name,
  });

  Future<void> changeState(FacilityStaff member, StaffState state) =>
      _ref(member.id).update({'state': state.name});

  Future<void> remove(FacilityStaff member) => _ref(member.id).delete();
}
