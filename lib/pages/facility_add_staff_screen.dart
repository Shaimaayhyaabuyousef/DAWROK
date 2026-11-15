import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'facility_nav.dart';
import 'facility_staff_store.dart';

class FacilityAddStaffScreen extends StatefulWidget {
  final FacilityStaff? editing;
  const FacilityAddStaffScreen({super.key, this.editing});
  @override State<FacilityAddStaffScreen> createState() => _FacilityAddStaffScreenState();
}

class _FacilityAddStaffScreenState extends State<FacilityAddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController name, id, station;
  StaffRole role = StaffRole.windowOfficer;
  String? passcode;
  DateTime? expiresAt;
  @override void initState() {
    super.initState();
    name = TextEditingController(text: widget.editing?.name ?? '');
    id = TextEditingController(text: widget.editing?.nationalId ?? '');
    station = TextEditingController(text: widget.editing?.window ?? '');
    role = widget.editing?.role ?? StaffRole.windowOfficer;
  }
  @override void dispose() { name.dispose(); id.dispose(); station.dispose(); super.dispose(); }
  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      if (widget.editing == null) {
        await FacilityStaffStore.instance.add(
          name: name.text.trim(), nationalId: id.text.trim(),
          window: station.text.trim(), role: role);
      } else {
        await FacilityStaffStore.instance.update(widget.editing!,
          name: name.text.trim(), nationalId: id.text.trim(),
          window: station.text.trim(), role: role);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Staff saved in Firebase. Secure invitation codes are not enabled yet.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())));
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(26, 16, 26, 30), child: Form(
      key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, size: 23)),
        const SizedBox(height: 35),
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFEDF3F9)), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x090B2439), blurRadius: 5, offset: Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Staff Full Name', style: TextStyle(fontSize: 22, color: facilityDark)),
          const SizedBox(height: 6),
          _entry(name, Icons.person_outline, 'Staff full name'),
          const SizedBox(height: 17),
          const Text('Assigned Role', style: TextStyle(fontSize: 22, color: facilityDark)),
          const SizedBox(height: 10),
          Row(children: [
            _role(StaffRole.windowOfficer, Icons.co_present_outlined, 'Window\nOfficer'),
            const SizedBox(width: 8),
            _role(StaffRole.supervisor, Icons.groups_outlined, 'Queue Super.'),
            const SizedBox(width: 8),
            _role(StaffRole.logistics, Icons.local_shipping_outlined, 'Logistics'),
          ]),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('National / Emp ID'), _entry(id, Icons.badge_outlined, 'ID number')])), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Station / Window'), _entry(station, Icons.dns_outlined, 'Window B')]))]),
          const SizedBox(height: 15),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(onPressed: _generate, style: ElevatedButton.styleFrom(backgroundColor: facilityBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), icon: const Icon(Icons.key_outlined), label: const Text('Generate Link Code', style: TextStyle(fontSize: 16)))),
        ])),
        if (passcode != null) ...[const SizedBox(height: 18), _passcodeCard()],
      ]),
    ))),
  );
  Widget _entry(TextEditingController controller, IconData icon, String hint) => TextFormField(
    controller: controller, validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
    decoration: InputDecoration(prefixIcon: Icon(icon, size: 18, color: facilityMuted), hintText: hint, isDense: true, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: facilityBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: facilityBorder))),
  );
  Widget _role(StaffRole value, IconData icon, String label) => Expanded(child: InkWell(
    onTap: () => setState(() => role = value), child: Container(height: 76, decoration: BoxDecoration(color: role == value ? const Color(0xFFEDF8FF) : const Color(0xFFF7F9FC), border: Border.all(color: role == value ? const Color(0xFF00A6EE) : facilityBorder, width: role == value ? 2 : 1), borderRadius: BorderRadius.circular(13)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 20, color: role == value ? const Color(0xFF007BBD) : facilityMuted), const SizedBox(height: 5), Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: role == value ? const Color(0xFF007BBD) : facilityDark))]))));
  Widget _passcodeCard() => Container(width: double.infinity, padding: const EdgeInsets.all(17), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFB6E6FF)), borderRadius: BorderRadius.circular(24)), child: Column(children: [
    const Row(children: [Icon(Icons.circle, color: Color(0xFF00A5EE), size: 11), SizedBox(width: 9), Expanded(child: Text('Active Pairing Code', style: TextStyle(fontSize: 16, color: facilityDark))), Text('24h validity', style: TextStyle(color: Color(0xFF007EB7)))]),
    const Divider(height: 27),
    const Text('Scan QR or enter alphanumeric code on device', textAlign: TextAlign.center, style: TextStyle(color: facilityMuted, fontSize: 13)),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF101728), borderRadius: BorderRadius.circular(16)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('STAFF LINK PASSCODE', style: TextStyle(color: Color(0xFF34C1FF), fontSize: 12)), Text(passcode!, style: const TextStyle(color: Colors.white, fontSize: 21))])), IconButton(onPressed: () {Clipboard.setData(ClipboardData(text: passcode!)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));}, icon: const Icon(Icons.copy, color: Colors.white)), IconButton(onPressed: () {Clipboard.setData(ClipboardData(text: passcode!)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share via copied code')));}, icon: const Icon(Icons.share, color: Color(0xFF00AAEF)))])),
    const SizedBox(height: 12), const Text('Valid for 24 hours. Provide this code to the employee to complete registration.', textAlign: TextAlign.center, style: TextStyle(color: facilityMuted, fontSize: 12)),
  ]));
}
