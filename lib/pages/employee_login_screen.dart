import '../services/phone_login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/employee_access_service.dart';
import 'package:first_project/l10n/app_language.dart';

const _blue = Color(0xFF03A9F4);
const _ink = Color(0xFF22334D);

/// Returning staff use phone and password ONLY. The invitation code is
/// entered on EmployeeJoinScreen when first requesting facility access.
class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final destination = await EmployeeAccessService.instance.signIn(
        phone: _phone.text,
        password: _password.text,
      );
      if (!mounted) return;
      if (destination == 'employee_login_screen') {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() => _error =
              'No staff request is linked to this account. '
              'Choose Request to Join Facility first.');
        }
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = switch (e.code) {
          'invalid-credential' || 'wrong-password' || 'user-not-found' =>
            'Incorrect phone number or password.',
          'too-many-requests' => 'Too many attempts. Try again later.',
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

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: trOpt(label),
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
        child: Center(
          child: ConstrainedBox(
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
                  const SizedBox(height: 43),
                  const CircleAvatar(
                    radius: 41,
                    backgroundColor: Color(0xFFE8F7FF),
                    child: Icon(Icons.badge_outlined, color: _blue, size: 43),
                  ),
                  const SizedBox(height: 20),
                  Text(tr('Employee Sign In'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _ink, fontSize: 28,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    tr('Sign in with your phone number and password. '
                    'Your facility approval is saved in Firebase.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF7C8DA7),
                      fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 34),
                  TextFormField(
                    controller: _phone,
                    enabled: !_busy,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration('Phone Number', Icons.phone_outlined),
                    validator: validateMobile,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: !_showPassword,
                    onFieldSubmitted: (_) => _signIn(),
                    decoration: _decoration('Password', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _showPassword = !_showPassword),
                        icon: Icon(_showPassword
                          ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                    validator: (v) => (v ?? '').isEmpty
                      ? 'Enter your password' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(tr(_error!), style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(tr('Sign In'),
                          style: TextStyle(fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: _busy
                      ? null
                      : () => Navigator.pushNamed(context, 'employee_join_screen'),
                    child: Text(tr('New employee? Request to Join Facility'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _blue)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr('An invitation code is needed only when you apply '
                    'to join a facility, not when signing in.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8C9CB4),
                      fontSize: 12, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
