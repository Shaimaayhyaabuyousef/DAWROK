import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/employee_access_service.dart';
import '../services/staff_pairing_service.dart';
import 'package:first_project/l10n/app_language.dart';

const _blue = Color(0xFF03A9F4);
const _ink = Color(0xFF22334D);

/// An employee reaches this screen only after entering a facility number,
/// single-use link code and phone number on EmployeeJoinScreen.
///
/// Creating (or signing in to) a Firebase Auth account here is one step of
/// submitting a join request. It is NOT the recurring staff login screen.
class EmployeeRegisterScreen extends StatefulWidget {
  const EmployeeRegisterScreen({
    super.key,
    required this.facilityNumber,
    required this.invitationCode,
    required this.contactPhone,
  });

  final String facilityNumber;
  final String invitationCode;
  final String contactPhone;

  @override
  State<EmployeeRegisterScreen> createState() => _EmployeeRegisterScreenState();
}

class _EmployeeRegisterScreenState extends State<EmployeeRegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _existingAccount = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await EmployeeAccessService.instance.authenticateForJoin(
        phone: widget.contactPhone,
        password: _password.text,
        existingAccount: _existingAccount,
      );
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      // A newly created account can retry after a cancelled or failed request.
      setState(() => _existingAccount = true);
      final sent = await StaffPairingService.instance.requestToJoin(
        widget.invitationCode,
        facilityNumber: widget.facilityNumber,
        phone: widget.contactPhone,
        confirm: _confirmFacility,
      );
      if (!mounted || !sent) return;
      Navigator.pushNamedAndRemoveUntil(context, 'employee_pending_screen', (_) => false);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = switch (e.code) {
          'email-already-in-use' =>
            'This phone number already has an account. Select "I already have an account".',
          'weak-password' => 'Choose a password with at least 6 characters.',
          'invalid-credential' || 'wrong-password' || 'user-not-found' =>
            'Incorrect phone number or password.',
          _ => e.message ?? e.code,
        });
      }
    } catch (e) {
      if (mounted) setState(() =>
          _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmFacility(String name) async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return false;
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Confirm facility')),
        content: Text(tr('Send your join request to $name?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Send request')),
          ),
        ],
      ),
    ) ?? false;
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _blue),
    filled: true,
    fillColor: const Color(0xFFF9FCFF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFD6E8F4)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFD6E8F4)),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(25, 15, 25, 40),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, color: _ink),
                  ),
                ),
                const SizedBox(height: 36),
                const CircleAvatar(
                  radius: 41,
                  backgroundColor: Color(0xFFE8F7FF),
                  child: Icon(Icons.person_add_alt_1_outlined,
                    color: _blue, size: 43),
                ),
                const SizedBox(height: 20),
                Text(tr('Request to Join Facility'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _ink, fontSize: 26,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  tr('Your facility number and link code were entered in the previous step. '
                  'Provide your account details to submit the request for approval.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF7C8DA7),
                    fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 25),
                Row(children: [
                  Expanded(child: _mode('Create account', false)),
                  const SizedBox(width: 10),
                  Expanded(child: _mode('Existing account', true)),
                ]),
                const SizedBox(height: 22),
                TextFormField(initialValue: widget.contactPhone, readOnly: true,
                  decoration: _decoration('Phone Number', Icons.phone_outlined)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: !_showPassword,
                  decoration: _decoration('Password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _showPassword = !_showPassword),
                      icon: Icon(_showPassword
                        ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  validator: (v) => (v ?? '').length >= 6
                    ? null : 'Enter at least 6 characters',
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  SelectableText(tr(_error!),
                    style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(tr('Verify invitation'),
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  tr('Your request stays saved in Firebase. After approval, '
                  'future sign-ins require your phone number and password only.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8C9CB4),
                    fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        )),
      ),
    ),
  );

  Widget _mode(String label, bool existing) => InkWell(
    onTap: _busy ? null : () => setState(() {
      _existingAccount = existing;
      _error = null;
    }),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _existingAccount == existing
          ? const Color(0xFFE8F7FF) : Colors.white,
        border: Border.all(
          color: _existingAccount == existing
            ? _blue : const Color(0xFFDDE9F2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(tr(label), style: TextStyle(
        color: _existingAccount == existing
          ? _blue : const Color(0xFF7C8DA7),
        fontWeight: FontWeight.w600,
      )),
    ),
  );
}
