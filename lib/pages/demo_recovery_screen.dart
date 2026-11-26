import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/phone_login.dart';

/// Local rehearsal only. This screen has no Authentication or Firestore access.
class DemoRecoveryScreen extends StatefulWidget {
  const DemoRecoveryScreen({super.key});
  @override
  State<DemoRecoveryScreen> createState() => _DemoRecoveryScreenState();
}

class _DemoRecoveryScreenState extends State<DemoRecoveryScreen> {
  final _phone = TextEditingController();
  String? _code, _error;
  String _entry = '';
  DateTime? _expires;
  Timer? _timer;
  int get _seconds => _expires == null
      ? 0
      : max(
          0,
          (_expires!.difference(DateTime.now()).inMilliseconds / 1000).ceil(),
        );

  void _send() {
    final error = validateMobile(_phone.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _timer?.cancel();
    setState(() {
      _code = Random.secure().nextInt(10000).toString().padLeft(4, '0');
      _expires = DateTime.now().add(const Duration(minutes: 1));
      _entry = '';
      _error = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) timer.cancel();
      setState(() {});
    });
  }

  void _verify() {
    if (_seconds == 0 || _entry != _code) {
      setState(
        () => _error = _seconds == 0
            ? 'Code expired. Request a new code.'
            : 'Incorrect code. Try again.',
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Demo complete. Contact the administrator to reset your account password.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: Text(_code == null ? 'Forget Password' : 'Enter Security PIN'),
      centerTitle: true,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            children: [
              if (_code == null) ...[
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(onPressed: _send, child: const Text('Send')),
                const SizedBox(height: 16),
                const Text(
                  'Demo code on this device • valid for 1 minute. For a real password reset, contact the administrator.',
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const Icon(
                  Icons.lock_outline,
                  size: 60,
                  color: Colors.lightBlue,
                ),
                const SizedBox(height: 22),
                Text('Demo PIN: $_code', textAlign: TextAlign.center),
                Text('Expires in $_seconds s', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(
                  List.generate(
                    4,
                    (i) => i < _entry.length ? '●' : '○',
                  ).join('  '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 22),
                GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 1.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final key in [
                      '1',
                      '2',
                      '3',
                      '4',
                      '5',
                      '6',
                      '7',
                      '8',
                      '9',
                      'C',
                      '0',
                      '⌫',
                    ])
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _error = null;
                          if (key == 'C') {
                            _entry = '';
                          } else if (key == '⌫') {
                            if (_entry.isNotEmpty)
                              _entry = _entry.substring(0, _entry.length - 1);
                          } else if (_entry.length < 4) {
                            _entry += key;
                          }
                        }),
                        child: Text(key, style: const TextStyle(fontSize: 20)),
                      ),
                  ],
                ),
                FilledButton(
                  onPressed: _entry.length == 4 ? _verify : null,
                  child: const Text('Verify demo PIN'),
                ),
                if (_seconds == 0)
                  TextButton(
                    onPressed: _send,
                    child: const Text('Request new code'),
                  ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
