import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/employee_access_service.dart';

const _blue = Color(0xFF03A9F4);
const _dark = Color(0xFF22334D);

/// First approval forces this page; its completion is enforced by Firestore
/// rules before employee work/queue data becomes available.
class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 35),
          child: Form(key: _form, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 19),
              CircleAvatar(
                radius: 46, backgroundColor: const Color(0xFFE8F6FF),
                child: const Icon(Icons.person_outline, color: _blue, size: 55)),
              const SizedBox(height: 20),
              const Text('Complete Your Profile',
                textAlign: TextAlign.center,
                style: TextStyle(color: _dark, fontWeight: FontWeight.w700, fontSize: 27)),
              const SizedBox(height: 10),
              const Text('Your facility approved your account. Please complete all employee information before starting work.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8195AC), height: 1.5, fontSize: 13)),
              const SizedBox(height: 34),
              _field(_fullName, 'Full Name', Icons.badge_outlined),
              _field(_phone, 'Phone Number', Icons.phone_outlined,
                keyboard: TextInputType.phone, minLength: 8),
              _field(_address, 'Address', Icons.location_on_outlined),
              _field(_emergencyPhone, 'Emergency Phone', Icons.contact_phone_outlined,
                keyboard: TextInputType.phone, minLength: 8),
              const SizedBox(height: 17),
              SizedBox(height: 54, child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save & Start Working',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)))),
              const SizedBox(height: 14),
              const Text('This step is required on your first approved sign-in.',
                textAlign: TextAlign.center, style: TextStyle(
                  fontSize: 12, color: Color(0xFF93A3B8))),
            ],
          )),
        )),
    ),
  );
}
