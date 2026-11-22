import 'workspace_style.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'facility_nav.dart';
import 'package:flutter/services.dart';
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
  StaffInviteResult? _issued;
  final _resultKey = GlobalKey();

  @override void initState() {
    super.initState();
    name = TextEditingController(text: widget.editing?.name ?? '');
    id = TextEditingController(text: widget.editing?.nationalId ?? '');
    station = TextEditingController(text: widget.editing?.window ?? '');
    role = widget.editing?.role ?? StaffRole.windowOfficer;
  }
  @override void dispose() { name.dispose(); id.dispose(); station.dispose(); super.dispose(); }
  Future<void> _generate() async {
    if (_working || _issued != null) return;
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
        setState(() => _issued = issued);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final result = _resultKey.currentContext;
          if (result != null) Scrollable.ensureVisible(result);
        });
        return;
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
        message = e is StateError ? e.message : e.toString();
      }
      if (mounted) {
        setState(() => _saveError = message);
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            titleTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: facilityDark),
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
  @override Widget build(BuildContext context) => WorkspaceStyle(child: Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(26, (61.0 - MediaQuery.paddingOf(context).top).clamp(0.0, 61.0), 26, 30), child: Form(
      key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconButton(tooltip: 'Back', alignment: Alignment.centerLeft, padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context), icon: const WorkspaceIcon('back')),
        AbsorbPointer(absorbing: _issued != null, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFEDF3F9)), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x090B2439), blurRadius: 5, offset: Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Staff Full Name', style: TextStyle(fontSize: 20, color: facilityDark)),
          const SizedBox(height: 6),
          _entry(name, 'name', 'Staff full name'),
          const SizedBox(height: 14),
          const Text('Assigned Role', style: TextStyle(fontSize: 20, color: facilityDark)),
          const SizedBox(height: 6),
          Row(children: [
            _role(StaffRole.windowOfficer, 'officer', 'Window\nOfficer'),
            const SizedBox(width: 8),
            _role(StaffRole.supervisor, 'supervisor', 'Queue Super.'),
            const SizedBox(width: 8),
            _role(StaffRole.logistics, 'logistics', 'Logistics'),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('National / Emp ID', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              _entry(id, 'id', 'Employee ID', optional: true),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Station / Window', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              InputDecorator(
                decoration: InputDecoration(isDense: true, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: facilityBorder)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                child: const Row(children: [WorkspaceIcon('station'), SizedBox(width: 6), Expanded(child: Text('Automatic', style: TextStyle(fontSize: 12)))]),
              ),
            ])),
          ]),
          const SizedBox(height: 12),
          if (_saveError != null) ...[
            Text(_saveError!, style: const TextStyle(
              color: Color(0xFFC62828), fontSize: 12)),
            const SizedBox(height: 12),
          ],
          SizedBox(width: double.infinity, height: 42, child: ElevatedButton.icon(onPressed: _working || _issued != null ? null : _generate, style: ElevatedButton.styleFrom(backgroundColor: facilityBlue, foregroundColor: Colors.white, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), icon: const WorkspaceIcon('key', color: Colors.white), label: Text(_working ? 'Saving...' : _issued != null ? 'Link Code Generated' : 'Generate Link Code', style: const TextStyle(fontSize: 12)))),
        ]))),
        if (_issued case final issued?) ...[
          const SizedBox(height: 16),
          _pairingCard(issued),
        ],
      ]),
    ))),
  ));
  Widget _pairingCard(StaffInviteResult issued) {
    final expiry = issued.expiresAt.toLocal();
    final local = MaterialLocalizations.of(context);
    final expiryLabel = '${local.formatShortDate(expiry)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(expiry))}';
    return Container(
      key: _resultKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FCFF),
        border: Border.all(color: const Color(0xFFB3DFFF)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Active Pairing Code', style: TextStyle(fontSize: 14, color: facilityDark)),
        const Divider(height: 22, color: facilityBorder),
        SelectableText('Facility number: ${issued.facilityNumber}', textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('STAFF LINK PASSCODE', style: TextStyle(color: Color(0xFF70D8FF), fontSize: 10)),
              SelectableText(issued.code, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ])),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.copy_outlined, size: 15),
              label: const Text('Copy'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: issued.code));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied to clipboard')));
              },
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Text('Expires $expiryLabel', textAlign: TextAlign.center,
          style: const TextStyle(color: facilityMuted, fontSize: 11)),
      ]),
    );
  }

  Widget _entry(TextEditingController controller, String asset, String hint, {bool optional = false}) => TextFormField(
    controller: controller, style: const TextStyle(fontSize: 12), validator: (v) => !optional && (v == null || v.trim().isEmpty) ? 'Required' : null,
    decoration: InputDecoration(prefixIconConstraints: const BoxConstraints(minWidth: 36), prefixIcon: Center(widthFactor: 1, child: WorkspaceIcon(asset, color: facilityMuted)), hintText: hint, isDense: true, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: facilityBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: facilityBorder))),
  );
  Widget _role(StaffRole value, String asset, String label) => Expanded(child: InkWell(
    onTap: () => setState(() => role = value), child: Container(constraints: const BoxConstraints(minHeight: 76), padding: const EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration(color: role == value ? const Color(0xFFEDF8FF) : const Color(0xFFF7F9FC), border: Border.all(color: role == value ? const Color(0xFF00A6EE) : facilityBorder, width: role == value ? 2 : 1), borderRadius: BorderRadius.circular(13)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [WorkspaceIcon(asset, color: role == value ? const Color(0xFF007BBD) : facilityMuted), const SizedBox(height: 5), Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: role == value ? const Color(0xFF007BBD) : facilityDark))]))));
}
