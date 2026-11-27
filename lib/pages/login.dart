import '../services/phone_login.dart';
import 'demo_recovery_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/citizen_auth_service.dart';
import '../services/app_auth_service.dart';
import 'package:first_project/l10n/app_language.dart';

const Color _primary = Color(0xFF2196F3);

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _key = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signInWithPhone() async {
    if (_busy || !_key.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final destination = await AppAuthService.instance.signInWithPhone(
        phone: _phone.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
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
          padding: const EdgeInsetsDirectional.fromSTEB(22, 12, 22, 30),
          child: Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.pushReplacementNamed(
                            context,
                            'onboarding',
                          ),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                ),
                SizedBox(
                  height: (MediaQuery.sizeOf(context).height * .08).clamp(
                    18.0,
                    66.0,
                  ),
                ),
                Center(
                  child: SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 84,
                    height: 84,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr('Signin'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _primary,
                    fontSize: 29,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 44),
                TextFormField(
                  controller: _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: validateMobile,
                  decoration: _decoration('Phone Number', Icons.phone_outlined),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: !_showPassword,
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'Enter your password' : null,
                  onFieldSubmitted: (_) => _signInWithPhone(),
                  decoration: _decoration('Password', Icons.lock_outline)
                      .copyWith(
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    tr(_error!),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 8),
                const SizedBox(height: 38),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _signInWithPhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(tr('Signin'), style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DemoRecoveryScreen(),
                            ),
                          ),
                    child: Text(tr('Forgot Password?')),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tr("Don’t have an account?")),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.pushReplacementNamed(
                              context,
                              'signup',
                            ),
                      child: Text(tr('SignUp')),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.pushNamed(
                          context,
                          'employee_login_screen',
                        ),
                  child: Text(tr('Employee account')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
    hintText: trOpt(hint),
    hintStyle: const TextStyle(color: _primary),
    suffixIcon: Icon(icon, color: _primary),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDCE7F1)),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );
}
