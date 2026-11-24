import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/citizen_registration_draft.dart';
import '../services/local_card_check.dart';
import 'citizen_id_verification_screen.dart';

const _primary = Color(0xFF03A9F4);
const _titleBlue = Color(0xFF4FAAF4);
const _lightBlue = Color(0xFFE3F2FC);
const _grey = Color(0xFF8F9299);
const _ink = Color(0xFF455771);

/// Step 1/3: UI + validation only. No Firebase account is created here.
/// The layout is based on the 393-point Figma reference, with scrolling
/// instead of shrinking the design on short mobile/browser viewports.
class CitizenSignUpScreen extends StatefulWidget {
  const CitizenSignUpScreen({super.key});

  @override
  State<CitizenSignUpScreen> createState() => _CitizenSignUpScreenState();
}

class _CitizenSignUpScreenState extends State<CitizenSignUpScreen> {
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _agreed = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _next() {

    // Do not use a real ID card while testing.
    final fullName = _name.text.trim();
    final nationalId = cardDigits(_id.text.trim());
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (fullName.length < 3) {
      _notice('Please enter your full name.');
      return;
    }
    if (!RegExp(r'^\d{9}$').hasMatch(nationalId)) {
      _notice('Enter your nine-digit ID number.');
      return;
    }
    final compactPhone = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^(?:0|\+970|00970)?5[69]\d{7}$')
        .hasMatch(compactPhone)) {
      _notice('Enter a valid 059 or 056 mobile number.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _notice('Please enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      _notice('Password must be at least 8 characters long.');
      return;
    }
    if (password != _confirm.text) {
      _notice('Passwords do not match.');
      return;
    }
    if (!_agreed) {
      _notice('Please review and accept the terms.');
      return;
    }

    final draft = CitizenRegistrationDraft(
      fullName: fullName,
      nationalId: nationalId,
      phone: phone,
      email: email,
      password: password,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CitizenIdVerificationScreen(draft: draft),
      ),
    );
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('login');
    }
  }

  void _information(String title, String description) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Height and field decoration are kept independent from validation messages,
  // so errors never move the form away from the supplied reference layout.
  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required double height,
    bool featured = false,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    List<TextInputFormatter>? formatters,
    Widget? suffix,
    Widget? prefix,
  }) {
    return Container(
      height: height,
      padding: EdgeInsets.all(featured ? 2 : 0),
      decoration: BoxDecoration(
        color: featured ? const Color(0xFFF0FAFF) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: featured ? const Color(0xFF60C8F7) : _lightBlue,
          width: featured ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        textInputAction: action,
        textDirection: TextDirection.ltr,
        textAlignVertical: TextAlignVertical.center,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: !obscure,
        inputFormatters: formatters,
        onSubmitted: action == TextInputAction.done ? (_) => _next() : null,
        style: const TextStyle(fontSize: 15.5, color: Color(0xFF23354A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _grey, fontSize: 15.5),
          prefixIcon: prefix,
          suffixIcon: suffix ?? Icon(icon, color: featured ? _titleBlue : _grey, size: 23),
          suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 38),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          filled: true,
          fillColor: featured ? const Color(0xFFF0FAFF) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: featured
                ? const BorderSide(color: Color(0xFF79D1FA), width: 1)
                : BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: featured
                ? const BorderSide(color: Color(0xFF79D1FA), width: 1)
                : BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _position({
    required double top,
    required double scale,
    required Widget child,
    bool fullWidth = true,
  }) {
    return Positioned(
      top: top * scale,
      left: fullWidth ? 27 * scale : 0,
      right: fullWidth ? 27 * scale : 0,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 393 logical pixels = screenshot reference width.
            // Limit scaling on tablets, and scroll instead of squeezing height.
            final scale = math.min(constraints.maxWidth / 393.0, 1.12);
            final canvasHeight = math.max(constraints.maxHeight, 778 * scale);

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: SizedBox(
                height: canvasHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 17 * scale,
                      top: 6 * scale,
                      child: IconButton(
                        onPressed: _back,
                        icon: Icon(Icons.arrow_back_ios_new,
                            size: 24 * scale, color: Colors.black),
                      ),
                    ),
                    _position(
                      top: 0,
                      scale: scale,
                      fullWidth: false,
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/logo.svg',
                          width: 107 * scale,
                          height: 107 * scale,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    _position(
                      top: 103,
                      scale: scale,
                      fullWidth: false,
                      child: Text(
                        'Signup',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _titleBlue,
                          fontSize: 29 * scale,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    _position(
                      top: 179,
                      scale: scale,
                      child: Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 13.5 * scale,
                          color: const Color(0xFF0087D0),
                        ),
                      ),
                    ),
                    _position(
                      top: 198,
                      scale: scale,
                      child: _field(
                        controller: _name,
                        hint: 'User Name',
                        icon: Icons.person_outline_rounded,
                        height: 52 * scale,
                        featured: true,
                      ),
                    ),
                    _position(
                      top: 265,
                      scale: scale,
                      child: _field(
                        controller: _id,
                        hint: 'ID',
                        icon: Icons.badge_outlined,
                        keyboard: TextInputType.number,
                        formatters: [
                          FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]')),
                          LengthLimitingTextInputFormatter(9),
                        ],
                        height: 40 * scale,
                      ),
                    ),
                    _position(
                      top: 316,
                      scale: scale,
                      child: _field(
                        controller: _phone,
                        hint: 'Mobile phone',
                        icon: Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                        height: 40 * scale,
                        prefix: Container(
                          width: 65 * scale,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: _lightBlue),
                            ),
                          ),
                          child: Text('+970',
                              style: TextStyle(
                                color: _grey,
                                fontSize: 14.5 * scale,
                              )),
                        ),
                      ),
                    ),
                    // Email is required because authentication uses Email/Password.
                    _position(
                      top: 366,
                      scale: scale,
                      child: _field(
                        controller: _email,
                        hint: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        height: 40 * scale,
                      ),
                    ),
                    _position(
                      top: 416,
                      scale: scale,
                      child: _field(
                        controller: _password,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _hidePassword,
                        height: 40 * scale,
                        suffix: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                              color: _grey, size: 22),
                        ),
                      ),
                    ),
                    _position(
                      top: 466,
                      scale: scale,
                      child: _field(
                        controller: _confirm,
                        hint: 'Confirm Password',
                        icon: Icons.lock_reset_outlined,
                        obscure: _hideConfirm,
                        action: TextInputAction.done,
                        height: 40 * scale,
                        suffix: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                          icon: Icon(
                            _hideConfirm
                                ? Icons.lock_reset_outlined
                                : Icons.visibility_outlined,
                            color: _grey, size: 22,
                          ),
                        ),
                      ),
                    ),
                    _position(
                      top: 516,
                      scale: scale,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _agreed,
                            activeColor: _titleBlue,
                            side: const BorderSide(color: _titleBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: (value) =>
                                setState(() => _agreed = value ?? false),
                          ),
                          Flexible(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('I agree to the ',
                                  style: TextStyle(
                                    fontSize: 13 * scale,
                                    color: _ink,
                                    fontWeight: FontWeight.w600,
                                  )),
                                GestureDetector(
                                  onTap: () => _information(
                                    'Registration terms',
                                    'Your ID number is saved to your account. The card photo is examined on this device to compare the number and layout. This is a visual check only.',
                                  ),
                                  child: Text(
                                    'Terms and Conditions',
                                    style: TextStyle(
                                      fontSize: 13 * scale,
                                      color: const Color(0xFF0087D0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _position(
                      top: 560,
                      scale: scale,
                      child: SizedBox(
                        height: 53 * scale,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _titleBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12 * scale),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Signup',
                                  style: TextStyle(fontSize: 22 * scale)),
                              SizedBox(width: 10 * scale),
                              Icon(Icons.arrow_forward_rounded, size: 23 * scale),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _position(
                      top: 677,
                      scale: scale,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Are you Staff? ',
                              style: TextStyle(color: const Color(0xFF70829D),
                                  fontSize: 13.5 * scale)),
                          GestureDetector(
                            onTap: () => _information(
                              'Join with code',
                              'Staff accounts are created by facilities or '
                              'administrators. The invitation-code feature '
                              'is not configured yet.',
                            ),
                            child: Text(
                              'Join with code',
                              style: TextStyle(
                                fontSize: 13.5 * scale,
                                color: const Color(0xFF0087D0),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _position(
                      top: 703,
                      scale: scale,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already have account? ',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 13 * scale,
                              )),
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushReplacementNamed('login'),
                            child: Text('Signin',
                              style: TextStyle(
                                fontSize: 13.5 * scale,
                                color: const Color(0xFF19283F),
                                fontWeight: FontWeight.w700,
                              )),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
