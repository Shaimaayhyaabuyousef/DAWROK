import 'package:flutter/material.dart';
import 'facility_nav.dart';
import 'facility_staff_store.dart';
import 'facility_add_staff_screen.dart';

class FacilityStaffScreen extends StatelessWidget {
  const FacilityStaffScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(bottom: false, child: AnimatedBuilder(
      animation: FacilityStaffStore.instance,
      builder: (context, _) => Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(19, 45, 19, 20), children: [
          ...FacilityStaffStore.instance.staff.map((s) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _staffCard(context, s))),
          const SizedBox(height: 3),
          SizedBox(height: 54, child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacilityAddStaffScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: facilityBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            icon: const Icon(Icons.add_circle_outline, size: 24), label: const Text('Add Staff Member', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)))),
        ])),
      ]),
    )),
    bottomNavigationBar: const FacilityBottomNav(selected: 2),
  );

  Widget _staffCard(BuildContext context, FacilityStaff s) {
    final isPending = s.state == StaffState.pending;
    final active = s.state == StaffState.active;
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: const Color(0xFFE0E9F1)), borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Color(0x0C2A5C86), blurRadius: 9, offset: Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(color: facilityDark, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            if (!isPending) Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: active ? const Color(0xFFECFFF4) : const Color(0xFFFFF3E6), border: Border.all(color: active ? const Color(0xFF9EF4C8) : const Color(0xFFFFD9A2)), borderRadius: BorderRadius.circular(5)), child: Text(active ? 'Active' : 'Stopped', style: TextStyle(color: active ? const Color(0xFF008A60) : const Color(0xFFD57A00), fontSize: 12))),
              Text(s.window, style: const TextStyle(color: Color(0xFF60738E), fontSize: 13)),
            ]),
          ])),
          Container(height: 65, width: 65, decoration: BoxDecoration(color: const Color(0xFFE2F4FF), border: Border.all(color: const Color(0xFFA7E3FF), width: 2), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(_initials(s.name), style: const TextStyle(fontSize: 21, color: Color(0xFF008FD3))))),
        ]),
        const SizedBox(height: 10),
        Text(s.description.isNotEmpty ? s.description : _roleDescription(s.role), style: const TextStyle(color: Color(0xFF485971), height: 1.55, fontSize: 13)),
        const Divider(height: 25, color: Color(0xFFE5EBF1)),
        if (isPending)
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _action('Reject', Icons.delete_outline, const Color(0xFFEB2856), const Color(0xFFFFF1F3), () async {
              if (await confirmFacilityAction(context, 'Reject ${s.name}?')) FacilityStaffStore.instance.remove(s);
            }), const SizedBox(width: 8),
            _action('Accept', Icons.check_circle_outline, const Color(0xFF6FAE34), const Color(0xFFE8F4D9), () => FacilityStaffStore.instance.changeState(s, StaffState.active)),
          ])
        else ...[
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _action('Delete', Icons.delete_outline, const Color(0xFFEB2856), const Color(0xFFFFF1F3), () async {
              if (await confirmFacilityAction(context, 'Delete ${s.name}?')) FacilityStaffStore.instance.remove(s);
            }), const SizedBox(width: 8),
            _action('Edit', Icons.edit_note_outlined, const Color(0xFF34455E), const Color(0xFFF2F5F9), () => Navigator.push(context, MaterialPageRoute(builder: (_) => FacilityAddStaffScreen(editing: s)))),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 38, child: OutlinedButton.icon(
            onPressed: () => FacilityStaffStore.instance.changeState(s, active ? StaffState.suspended : StaffState.active),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC86B00), backgroundColor: const Color(0xFFFFFBEB), side: const BorderSide(color: Color(0xFFF7D86E)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
            icon: Icon(active ? Icons.block : Icons.check_circle_outline, size: 16), label: Text(active ? 'Removal of validity' : 'Restore validity'),
          )),
        ],
      ]),
    );
  }
  Widget _action(String label, IconData icon, Color fg, Color bg, VoidCallback callback) =>
    SizedBox(height: 35, child: OutlinedButton.icon(onPressed: callback, style: OutlinedButton.styleFrom(backgroundColor: bg, foregroundColor: fg, side: BorderSide(color: fg.withValues(alpha: .2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(horizontal: 10)), icon: Icon(icon, size: 17), label: Text(label)));
  String _initials(String name) => name.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0]).join().toUpperCase();
  String _roleDescription(StaffRole role) => switch (role) {
    StaffRole.windowOfficer => 'Window Officer: Handles queue intake and customer check-ins.',
    StaffRole.supervisor => 'Queue Supervisor: Oversees staff and queue operations.',
    StaffRole.logistics => 'Logistics: Coordinates deliveries and service operations.',
  };
}
