import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/citizen_auth_service.dart';
import '../services/app_auth_service.dart';

const Color _primary = Color(0xFF03A9F4);

/// Shared email/password login for citizens and facilities.
/// Social sign-in and public sign-up remain citizen-only.
class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await action();
      if (!mounted || !result) return;
      Navigator.pushNamedAndRemoveUntil(context, 'home_screen', (_) => false);
    } catch (e) {
      if (mounted && !isCitizenAuthCancellation(e)) {
        setState(() => _error = citizenAuthErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (_busy || !_key.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final destination = await AppAuthService.instance.signInWithEmail(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        destination,
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = citizenAuthErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          child: Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _busy ? null : () => Navigator.pushReplacementNamed(context, 'onboarding'),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                ),
                const SizedBox(height: 10),
                Center(child: SvgPicture.asset('assets/images/logo.svg', width: 118, height: 118)),
                const SizedBox(height: 10),
                const Text(
                  'Sign In',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _primary, fontSize: 29, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Citizens and facilities',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF62728B)),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value ?? '').trim().contains('@')
                      ? null
                      : 'Enter your email address',
                  decoration: _decoration('Email Address', Icons.email_outlined),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: !_showPassword,
                  validator: (value) => (value ?? '').isEmpty ? 'Enter your password' : null,
                  onFieldSubmitted: (_) => _signInWithEmail(),
                  decoration: _decoration('Password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : () async {
                      if (!_email.text.trim().contains('@')) {
                        setState(() => _error = 'Enter your email to reset the password.');
                        return;
                      }
                      try {
                        await CitizenAuthService.instance.sendPasswordReset(_email.text);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset link requested. Check your email.')),
                        );
                      } catch (e) {
                        if (mounted) setState(() => _error = citizenAuthErrorMessage(e));
                      }
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _signInWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sign In', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => Navigator.pushNamed(
                    context, 'employee_login_screen'),
                  icon: const Icon(Icons.badge_outlined, color: _primary),
                  label: const Text('Employee Sign In',
                    style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: Color(0xFFA8DDF9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR')),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Social sign-in is for citizens only',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF62728B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                // Social sign-in buttons are defined inside this file.
                _socialButton(
                  label: 'Continue with Google',
                  mark: 'G',
                  markColor: const Color(0xFF4285F4),
                  onPressed: () => _perform(
                    CitizenAuthService.instance.signInWithGoogle,
                  ),
                ),
                const SizedBox(height: 11),
                _socialButton(
                  label: 'Continue with X',
                  mark: '𝕏',
                  markColor: const Color(0xFF111111),
                  onPressed: () => _perform(
                    CitizenAuthService.instance.signInWithX,
                  ),
                ),
                const SizedBox(height: 11),
                _socialButton(
                  label: 'Continue with Facebook',
                  mark: 'f',
                  markColor: const Color(0xFF1877F2),
                  onPressed: () => _perform(
                    CitizenAuthService.instance.signInWithFacebook,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("New citizen?"),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pushReplacementNamed(context, 'signup'),
                      child: const Text('Create citizen account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Button widget local to Login; no CitizenSocialButtons import needed.
  Widget _socialButton({
    required String label,
    required String mark,
    required Color markColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF25354B),
          side: const BorderSide(color: Color(0xFFDCE7F1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                mark,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: markColor,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 34),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: _primary),
        filled: true,
        fillColor: const Color(0xFFF7FAFE),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE7F1)),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
}
