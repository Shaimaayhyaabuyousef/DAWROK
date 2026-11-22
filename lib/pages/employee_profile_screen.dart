import 'workspace_style.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/employee_access_service.dart';

const _blue = Color(0xFF03A9F4);
const _dark = Color(0xFF22334D);

/// First approval forces this page; its completion is enforced by Firestore
/// rules before employee work/queue data becomes available.
class EmployeeProfileScreen extends StatefulWidget {
  final bool embedded;
  const EmployeeProfileScreen({super.key, this.embedded = false});
  @override State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}
class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _emergencyPhone = TextEditingController();
  bool _loading = true, _saving = false;

  @override void initState() {
    super.initState(); _load();
  }
  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('staff_profiles')
          .doc(uid).get();
      if (!mounted) return;
      final m = snap.data() ?? {};
      _fullName.text = m['fullName'] as String? ?? '';
      _phone.text = m['phone'] as String? ?? '';
      if (_phone.text.isEmpty) {
        final membership = await FirebaseFirestore.instance
            .collection('staff_memberships').doc(uid).get();
        final hash = membership.data()?['inviteHash'] as String?;
        if (hash != null) {
          final join = await FirebaseFirestore.instance
              .collection('staff_join_requests').doc(hash).get();
          _phone.text = join.data()?['phone'] as String? ?? '';
        }
      }
      _address.text = m['address'] as String? ?? '';
      _emergencyPhone.text = m['emergencyPhone'] as String? ?? '';
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load profile: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fullName.dispose(); _phone.dispose();
    _address.dispose(); _emergencyPhone.dispose(); super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance.collection('staff_profiles').doc(uid);
      final existing = await ref.get();
      final fields = <String, dynamic>{
        'uid': uid, 'fullName': _fullName.text.trim(),
        'phone': _phone.text.trim(), 'address': _address.text.trim(),
        'emergencyPhone': _emergencyPhone.text.trim(),
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (existing.exists) {
        await ref.update(fields);
      } else {
        await ref.set({...fields, 'createdAt': FieldValue.serverTimestamp()});
      }
      await FirebaseAuth.instance.currentUser?.updateDisplayName(_fullName.text.trim());
      final destination = await EmployeeAccessService.instance.currentDestination();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context,
        destination == 'employee_home_screen'
          ? 'employee_home_screen' : 'employee_pending_screen', (_) => false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save employee profile: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _blue),
    filled: true,
    fillColor: const Color(0xFFF9FCFF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDCE9F3))),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _field(TextEditingController c, String label, IconData icon, {
      TextInputType? keyboard, int minLength = 3}) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: TextFormField(
      controller: c, keyboardType: keyboard,
      decoration: _decoration(label, icon),
      validator: (v) => (v ?? '').trim().length >= minLength
        ? null : 'Enter a valid $label',
    ),
  );

  Widget _profileCard({
    required String label,
    required Widget child,
    String? badge,
    Color badgeColor = _blue,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD2EDFD)),
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [BoxShadow(
        color: Color(0x09062E4F),
        blurRadius: 5, offset: Offset(0, 3)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(
          color: Color(0xFF3A4B62),
          fontSize: 15, fontWeight: FontWeight.w700))),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FE),
              borderRadius: BorderRadius.circular(8)),
            child: Text(badge, style: TextStyle(
              color: badgeColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
      ]),
      const SizedBox(height: 6),
      child,
    ]),
  );

  Widget _valueInput(
    TextEditingController controller,
    String placeholder, {
    IconData? icon,
    TextInputType? keyboard,
    bool required = true,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboard,
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      prefixIconConstraints: const BoxConstraints(minWidth: 30),
      prefixIcon: icon == null ? null : Icon(icon, color: _blue, size: 18),
      hintText: placeholder,
      hintStyle: const TextStyle(color: Color(0xFF9EACC0)),
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF64C8FC))),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFDAE6F3))),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _blue, width: 2)),
    ),
    validator: (value) {
      final text = (value ?? '').trim();
      if (required && text.length < 3) return 'Enter a valid $placeholder';
      if (keyboard == TextInputType.phone &&
          !RegExp(r'^\+?[0-9\s-]{8,20}$').hasMatch(text)) {
        return 'Enter a valid phone number';
      }
      return null;
    },
  );

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return WorkspaceStyle(child: PopScope(
      canPop: widget.embedded,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 19, 26, 33),
            child: Form(key: _form, child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.topRight, child: IconButton(
                  tooltip: 'Settings',
                  onPressed: _saving ? null
                    : () => Navigator.pushNamed(context, 'app_settings'),
                  icon: const Icon(Icons.settings_outlined,
                    color: Color(0xFF65768F), size: 26))),
                const SizedBox(height: 32),
                Align(alignment: Alignment.center, child: Stack(children: [
                  CircleAvatar(
                    radius: 76,
                    backgroundColor: const Color(0xFFB3E8FD),
                    child: const CircleAvatar(
                      radius: 73,
                      backgroundColor: Color(0xFFF0FAFF),
                      child: Icon(Icons.person_outline,
                        size: 81, color: _blue))),
                  Positioned(bottom: 0, right: 0, child: Container(
                    width: 37, height: 37,
                    decoration: BoxDecoration(
                      color: _blue, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 20))),
                ])),
                const SizedBox(height: 32),
                _profileCard(
                  label: 'Name Of Staff',
                  badge: 'Required',
                  child: _valueInput(_fullName, 'Full Name'),
                ),
                StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
                  stream: uid == null ? const Stream.empty() :
                    FirebaseFirestore.instance.collection('staff_memberships')
                        .doc(uid).snapshots(),
                  builder: (context, membership) => _profileCard(
                    label: 'ID',
                    badge: '✓ Registered',
                    badgeColor: const Color(0xFF00A678),
                    child: Row(children: [
                      const Icon(Icons.badge_outlined, color: _blue),
                      const SizedBox(width: 9),
                      Expanded(child: Text(
                        membership.data?.data()?['staffId'] as String? ?? '—',
                        style: const TextStyle(color: _dark, fontSize: 18))),
                      TextButton.icon(
                        onPressed: () async {
                          final id = membership.data?.data()?['staffId'] as String?;
                          if (id == null) return;
                          await Clipboard.setData(ClipboardData(text: id));
                          if (context.mounted) ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Copied')));
                        },
                        icon: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('Copy'),
                      ),
                    ]),
                  ),
                ),
                _profileCard(
                  label: 'Phone',
                  child: _valueInput(_phone, 'Phone Number',
                    icon: Icons.phone_outlined, keyboard: TextInputType.phone),
                ),
                _profileCard(
                  label: 'Address',
                  child: _valueInput(_address, 'Address',
                    icon: Icons.location_on_outlined),
                ),
                _profileCard(
                  label: 'Emergency Phone',
                  child: _valueInput(_emergencyPhone, 'Emergency Phone',
                    icon: Icons.contact_phone_outlined,
                    keyboard: TextInputType.phone),
                ),
                const SizedBox(height: 3),
                SizedBox(height: 48, child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                  ),
                  child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
                )),
                const SizedBox(height: 23),
              ],
            )),
          ),
        ),
      ),
    ));
  }
}
