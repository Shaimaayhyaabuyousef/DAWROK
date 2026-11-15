import 'package:flutter/material.dart';

import '../services/employee_access_service.dart';

const _blue = Color(0xFF03A9F4);
const _ink = Color(0xFF22334D);

/// Staff-only entry; no citizen/facility screen layout is changed.
class EmployeeLoginScreen extends StatefulWidget {
  final String? facilityId;
  final String? invitationCode;
  final String? contactPhone;
  const EmployeeLoginScreen({
    super.key, this.facilityId, this.invitationCode, this.contactPhone,
  });
  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _newAccount = true;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.invitationCode != null) _code.text = widget.invitationCode!;
  }
  @override
  void dispose() {
    _email.dispose(); _password.dispose(); _code.dispose(); super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final destination = _newAccount
          ? await EmployeeAccessService.instance.createAccount(
              email: _email.text, password: _password.text,
              invitationCode: _code.text,
              facilityId: widget.facilityId, phone: widget.contactPhone)
          : await EmployeeAccessService.instance.signIn(
              email: _email.text, password: _password.text,
              invitationCode: _code.text.isEmpty ? null : _code.text,
              facilityId: widget.facilityId, phone: widget.contactPhone);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _blue),
    filled: true,
    fillColor: const Color(0xFFF9FCFF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFD6E8F4))),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFD6E8F4))),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(25, 15, 25, 40),
      child: Form(key: _form, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: _ink))),
          const SizedBox(height: 36),
          CircleAvatar(
            radius: 41, backgroundColor: const Color(0xFFE8F7FF),
            child: const Icon(Icons.badge_outlined, color: _blue, size: 43)),
          const SizedBox(height: 20),
          const Text('Create Staff Account', textAlign: TextAlign.center,
            style: TextStyle(color: _ink, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Complete your Firebase sign-in details. The facility will review your request before work access is enabled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF7C8DA7), fontSize: 13, height: 1.5)),
          const SizedBox(height: 31),
          Row(children: [
            Expanded(child: _mode('New employee', true)),
            const SizedBox(width: 10),
            Expanded(child: _mode('Sign in', false)),
          ]),
          const SizedBox(height: 22),
          TextFormField(
            controller: _email, keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _decoration('Email Address', Icons.email_outlined),
            validator: (v) => (v ?? '').contains('@') ? null : 'Enter your email'),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password, obscureText: !_showPassword,
            textInputAction: TextInputAction.next,
            decoration: _decoration('Password', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility))),
            validator: (v) => (v ?? '').length >= 6
                ? null : 'Enter at least 6 characters'),
          const SizedBox(height: 14),
          TextFormField(
            controller: _code, textCapitalization: TextCapitalization.characters,
            decoration: _decoration(
              _newAccount ? 'Staff Link Code' : 'Link Code (only if not linked yet)',
              Icons.vpn_key_outlined),
            validator: (v) => _newAccount && (v ?? '').trim().isEmpty
                ? 'Invitation code is required for first registration' : null),
          const SizedBox(height: 11),
          const Text('Use the unique code provided by your facility. An approved employee signs in with email and password only.',
            style: TextStyle(color: Color(0xFF8C9CB4), fontSize: 12, height: 1.45)),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 28),
          SizedBox(height: 54, child: ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _busy
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(_newAccount ? 'Create Account & Request Access' : 'Sign In',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 13),
          const Text('Approval is stored in Firebase. You can close the app and return later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8C9CB4), fontSize: 12)),
        ],
      )))),
  );

  Widget _mode(String label, bool mode) => InkWell(
    onTap: () => setState(() { _newAccount = mode; _error = null; }),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _newAccount == mode ? const Color(0xFFE8F7FF) : Colors.white,
        border: Border.all(
          color: _newAccount == mode ? _blue : const Color(0xFFDDE9F2)),
        borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(
        color: _newAccount == mode ? _blue : const Color(0xFF7C8DA7),
        fontWeight: FontWeight.w600))),
  );
}
