import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/citizen_registration_draft.dart';
import '../services/citizen_signup_service.dart';

const _blue = Color(0xFF03A9F4);
const _ink = Color(0xFF19283F);

/// Step 3 of 3: PIN setup for the demo device only.
/// PIN is never accepted as server authentication.
class CitizenPinSetupScreen extends StatefulWidget {
  const CitizenPinSetupScreen({super.key, this.draft});

  final CitizenRegistrationDraft? draft;

  @override
  State<CitizenPinSetupScreen> createState() => _CitizenPinSetupScreenState();
}

class _CitizenPinSetupScreenState extends State<CitizenPinSetupScreen> {
  String _digits = '';
  bool _saving = false;
  String? _error;

  void _pressDigit(String digit) {
    if (_saving || _digits.length >= 4) return;
    setState(() {
      _digits += digit;
      _error = null;
    });
  }

  void _removeDigit() {
    if (_saving || _digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _error = null;
    });
  }

  Future<void> _continue() async {
    if (_saving) return;
    if (_digits.length != 4) {
      setState(() => _error = 'Enter all four digits.');
      return;
    }
    // One-time PIN entry: no confirmation screen.
    if (RegExp(r'^(\d)\1{3}$').hasMatch(_digits)) {
      setState(() => _error = 'Avoid repeating the same digit four times.');
      return;
    }

    setState(() => _saving = true);
    try {
      await CitizenSignupService.instance.complete(
        draft: widget.draft,
        pin: _digits,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('home_screen', (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _authMessage(e));
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          'Registration could not be completed. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this phone number already exists. Return to Signin.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      default:
        return 'Account error (${e.code}).';
    }
  }

  Widget _key(String digit, {String caption = '', IconData? icon,
      bool subdued = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: SizedBox(
          height: 62,
          child: OutlinedButton(
            onPressed: _saving ? null : () {
              if (digit == 'clear') {
                setState(() { _digits = ''; _error = null; });
              } else if (digit == 'back') {
                _removeDigit();
              } else {
                _pressDigit(digit);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              backgroundColor: subdued
                  ? const Color(0xFFF7F9FC) : Colors.white,
              side: const BorderSide(color: Color(0xFFE3EAF2), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: icon != null
                ? Icon(icon, size: 26)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(digit == 'clear' ? 'C' : digit,
                        style: TextStyle(fontSize: digit == 'clear' ? 22 : 28,
                            fontWeight: FontWeight.w700)),
                      if (caption.isNotEmpty)
                        Text(caption, style: const TextStyle(
                          fontSize: 9, color: Color(0xFF91A0B8))),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _keyRow(List<Widget> children) => Row(children: children);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new,
                  size: 27, color: Colors.black),
              ),
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7EFFB),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Text('Step 3 of 3: Security PIN',
                    style: TextStyle(color: Color(0xFF00699B),
                        fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                const Spacer(),
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 25,
                    height: 7,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                height: 95,
                width: 95,
                decoration: BoxDecoration(
                  color: const Color(0xFFA1D7FA),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.lock_outline_rounded,
                  color: Colors.white, size: 65),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create a 4-digit code for this device.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, height: 1.35),
            ),
            const SizedBox(height: 35),
            const Text('Enter Security PIN',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, color: _blue)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) => Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _digits.length ? _blue : Colors.white,
                  border: Border.all(color: index < _digits.length
                      ? _blue : Colors.black, width: 2),
                ),
              )),
            ),
            const SizedBox(height: 33),
            _keyRow([_key('1'), _key('2', caption: 'ABC'), _key('3', caption: 'DEF')]),
            _keyRow([_key('4', caption: 'GHI'), _key('5', caption: 'JKL'), _key('6', caption: 'MNO')]),
            _keyRow([_key('7', caption: 'PQRS'), _key('8', caption: 'TUV'), _key('9', caption: 'WXYZ')]),
            _keyRow([_key('clear', caption: 'CLEAR', subdued: true),
              _key('0', caption: '+'),
              _key('back', icon: Icons.backspace_outlined, subdued: true)]),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _continue,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _blue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Finish Signup',
                        style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 11),
            const Text('Demo PIN is stored on this device only. '
              'Your Firebase password remains the account credential.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF73859D))),
          ],
        ),
      ),
    );
  }
}
