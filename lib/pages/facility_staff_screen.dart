import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'facility_nav.dart';
import 'facility_staff_store.dart';
import 'facility_add_staff_screen.dart';
import 'facility_staff_code_dialog.dart';

class FacilityStaffScreen extends StatefulWidget {
  const FacilityStaffScreen({super.key});

  @override
  State<FacilityStaffScreen> createState() => _FacilityStaffScreenState();
}

class _FacilityStaffScreenState extends State<FacilityStaffScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await FacilityStaffStore.instance.refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load staff from Firebase: $e')),
          );
        }
      }
    });
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(bottom: false, child: AnimatedBuilder(
      animation: FacilityStaffStore.instance,
      builder: (context, _) => Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(19, 45, 19, 20), children: [
          if (FacilityStaffStore.instance.error != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText(FacilityStaffStore.instance.error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          ],
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

  Future<void> _write(BuildContext context, Future<void> Function() action) async {
    try { await action(); }
    catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())));
    }
  }
  Future<void> _reissue(BuildContext context, FacilityStaff staff) async {
    try {
      final issued = await FacilityStaffStore.instance.replaceInvite(staff);
      if (!context.mounted) return;
      await showStaffCodeDialog(
        context,
        code: issued.code,
        staffName: staff.name,
        expiresAt: issued.expiresAt,
      );
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Widget _inviteCard(BuildContext context, FacilityStaff staff) {
    final code = staff.linkCode;
    if (code == null || code.isEmpty) return const SizedBox.shrink();
    final expired = staff.codeExpiresAt != null &&
        DateTime.now().isAfter(staff.codeExpiresAt!);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        border: Border.all(color: const Color(0xFFBDE6FF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.key_outlined, color: Color(0xFF008DD8), size: 18),
          const SizedBox(width: 7),
          const Expanded(child: Text('Employee Link Code',
              style: TextStyle(color: facilityDark,
                fontWeight: FontWeight.w600, fontSize: 13))),
          Text(expired ? 'Expired' : 'Valid for 24h',
            style: TextStyle(fontSize: 11,
              color: expired ? Colors.redAccent : const Color(0xFF007CB2))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: SelectableText(code,
            style: const TextStyle(color: facilityDark,
              fontWeight: FontWeight.bold, fontSize: 15))),
          IconButton(
            tooltip: 'Copy employee link code',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined,
              color: Color(0xFF008DD8), size: 21),
          ),
        ]),
        if (expired)
          const Text('Generate a new code before the employee joins.',
            style: TextStyle(color: Colors.redAccent, fontSize: 11)),
      ]),
    );
  }

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
        if (isPending) ...[
          if (s.linkCode != null) _inviteCard(context, s),
          if (s.hasJoinRequest) ...[
            if (s.requesterEmail != null) Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Request from: ${s.requesterEmail}',
                style: const TextStyle(fontSize: 12, color: facilityMuted))),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _action('Reject', Icons.cancel_outlined,
                const Color(0xFFEB2856), const Color(0xFFFFF1F3),
                () => _write(context, () => FacilityStaffStore.instance.reject(s))),
              const SizedBox(width: 8),
              _action('Accept', Icons.check_circle_outline,
                const Color(0xFF6FAE34), const Color(0xFFE8F4D9),
                () => _write(context, () => FacilityStaffStore.instance.approve(s))),
            ]),
          ] else ...[
            const Text('Waiting for the employee to enter their invitation code.',
              style: TextStyle(fontSize: 12, color: facilityMuted)),
            const SizedBox(height: 9),
            Align(alignment: Alignment.centerRight,
              child: _action(s.linkCode == null ? 'New Code' : 'Regenerate Code', Icons.key_outlined,
                const Color(0xFF007AB6), const Color(0xFFE8F5FF),
                () => _reissue(context, s))),
          ],
        ]
        else ...[
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _action('Delete', Icons.delete_outline, const Color(0xFFEB2856), const Color(0xFFFFF1F3), () async {
              if (await confirmFacilityAction(context, 'Delete ${s.name}?') && context.mounted) await _write(context, () => FacilityStaffStore.instance.remove(s));
            }), const SizedBox(width: 8),
            _action('Edit', Icons.edit_note_outlined, const Color(0xFF34455E), const Color(0xFFF2F5F9), () => Navigator.push(context, MaterialPageRoute(builder: (_) => FacilityAddStaffScreen(editing: s)))),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 38, child: OutlinedButton.icon(
            onPressed: () => s.joinStatus == 'approved'
              ? _write(context, () => FacilityStaffStore.instance.changeState(s, active ? StaffState.suspended : StaffState.active))
              : _reissue(context, s),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC86B00), backgroundColor: const Color(0xFFFFFBEB), side: const BorderSide(color: Color(0xFFF7D86E)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
            icon: Icon(active ? Icons.block : Icons.check_circle_outline, size: 16), label: Text(s.joinStatus == 'approved'
              ? (active ? 'Removal of validity' : 'Restore validity')
              : 'Generate New Code'),
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
