import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'facility_nav.dart';
import 'facility_staff_code_dialog.dart';
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
  bool _working = false;
  String? _saveError;

  @override void initState() {
    super.initState();
    name = TextEditingController(text: widget.editing?.name ?? '');
    id = TextEditingController(text: widget.editing?.nationalId ?? '');
    station = TextEditingController(text: widget.editing?.window ?? '');
    role = widget.editing?.role ?? StaffRole.windowOfficer;
  }
  @override void dispose() { name.dispose(); id.dispose(); station.dispose(); super.dispose(); }
  Future<void> _generate() async {
    if (_working) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _saveError = 'Complete all required fields first.');
      return;
    }
    setState(() { _working = true; _saveError = null; });
    try {
      final currentMember = widget.editing;
      StaffInviteResult? issued;
      if (currentMember == null) {
        issued = await FacilityStaffStore.instance.add(
          name: name.text.trim(),
          nationalId: id.text.trim(),
          window: 'Automatic',
          role: role,
        );
      } else {
        await FacilityStaffStore.instance.update(
          currentMember,
          name: name.text.trim(),
          nationalId: id.text.trim(),
          window: 'Automatic',
          role: role,
        );
        if (currentMember.joinStatus != 'approved') {
          issued = await FacilityStaffStore.instance.replaceInvite(currentMember);
        }
      }
      if (!mounted) return;
      if (issued != null) {
        await showStaffCodeDialog(
          context,
          code: issued.code,
          staffName: name.text.trim(),
          expiresAt: issued.expiresAt,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee details saved.')),
        );
      }
      // Return to the existing Staff cards; the new code is read from
      // the owner-only Firestore staff document by the real-time listener.
      if (mounted) Navigator.of(context).pop();
    } catch (e, stack) {
      debugPrint('DAWROK: Generate Link Code failed: $e');
      debugPrintStack(stackTrace: stack);
      String message;
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          message = 'Firebase denied saving this employee. Check that you '
              'signed in as the active facility owner, and that the latest '
              'firestore.rules were deployed to project dawrok-f908e. '
              'Error: [${e.code}] ${e.message ?? ''}';
        } else if (e.code == 'unavailable') {
          message = 'Cannot reach Firestore right now. Check the connection '
              'and retry. [${e.code}] ${e.message ?? ''}';
        } else {
          message = 'Firebase [${e.code}]: ${e.message ?? e.toString()}';
        }
      } else if (FirebaseAuth.instance.currentUser == null) {
        message = 'The facility session has expired. Sign in again.';
      } else {
        message = e.toString();
      }
      if (mounted) {
        setState(() => _saveError = message);
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Employee was not added'),
            content: SelectableText(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
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
          const Text('Assigned automatically to a vacant service position after approval.', style: TextStyle(color: Color(0xFF60738E))),
          const SizedBox(height: 15),
          if (_saveError != null) ...[
            Text(_saveError!, style: const TextStyle(
              color: Color(0xFFC62828), fontSize: 12)),
            const SizedBox(height: 12),
          ],
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(onPressed: _working ? null : _generate, style: ElevatedButton.styleFrom(backgroundColor: facilityBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), icon: const Icon(Icons.key_outlined), label: Text(_working ? 'Saving...' : 'Generate Link Code', style: const TextStyle(fontSize: 16)))),
        ])),
      ]),
    ))),
  );
  Widget _entry(TextEditingController controller, IconData icon, String hint) => TextFormField(
    controller: controller, validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
    decoration: InputDecoration(prefixIcon: Icon(icon, size: 18, color: facilityMuted), hintText: hint, isDense: true, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: facilityBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: facilityBorder))),
  );
  Widget _role(StaffRole value, IconData icon, String label) => Expanded(child: InkWell(
    onTap: () => setState(() => role = value), child: Container(height: 76, decoration: BoxDecoration(color: role == value ? const Color(0xFFEDF8FF) : const Color(0xFFF7F9FC), border: Border.all(color: role == value ? const Color(0xFF00A6EE) : facilityBorder, width: role == value ? 2 : 1), borderRadius: BorderRadius.circular(13)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 20, color: role == value ? const Color(0xFF007BBD) : facilityMuted), const SizedBox(height: 5), Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: role == value ? const Color(0xFF007BBD) : facilityDark))]))));
}
