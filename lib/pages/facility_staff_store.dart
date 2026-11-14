import 'package:flutter/foundation.dart';

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
  FacilityStaffStore._();
  static final instance = FacilityStaffStore._();
  int _nextId = 4;
  final List<FacilityStaff> _staff = [
    FacilityStaff(id: 1, name: 'Ahmed Mansour', nationalId: '1092847291', window: 'Window A', role: StaffRole.supervisor,
      state: StaffState.active, description: 'Field Supervisor: Oversees beneficiary queue intake, terminal check-ins, and protocol compliance.'),
    FacilityStaff(id: 2, name: 'Sarah Al-Khalil', nationalId: '1092847292', window: 'Window B', role: StaffRole.windowOfficer,
      state: StaffState.active, description: 'Queue Registrar: Handles token generation, biometric verification, and fast-track vulnerable family quotas.'),
    FacilityStaff(id: 3, name: 'Sarah Al-Khalil', nationalId: '1092847293', window: 'Window C', role: StaffRole.windowOfficer,
      state: StaffState.pending, description: 'Queue Registrar: Handles token generation, biometric verification, and fast-track vulnerable family quotas.'),
  ];
  List<FacilityStaff> get staff => List.unmodifiable(_staff);
  FacilityStaff add({required String name, required String nationalId, required String window, required StaffRole role}) {
    final member = FacilityStaff(id: _nextId++, name: name, nationalId: nationalId, window: window, role: role, state: StaffState.pending);
    _staff.add(member); notifyListeners(); return member;
  }
  void update(FacilityStaff member, {required String name, required String nationalId, required String window, required StaffRole role}) {
    member.name = name; member.nationalId = nationalId; member.window = window; member.role = role; notifyListeners();
  }
  void changeState(FacilityStaff member, StaffState state) { member.state = state; notifyListeners(); }
  void remove(FacilityStaff member) { _staff.removeWhere((e) => e.id == member.id); notifyListeners(); }
}
