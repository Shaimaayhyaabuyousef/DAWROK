import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/citizen_registration_draft.dart';
import 'citizen_pin_setup_screen.dart';

const _primary = Color(0xFF03A9F4);
const _ink = Color(0xFF475870);

/// Step 2 of 3: local SAMPLE-image preview only.
/// Does not recognize, validate, transmit or store a real identity document.
class CitizenIdVerificationScreen extends StatefulWidget {
  const CitizenIdVerificationScreen({
    super.key,
    this.draft,
  });

  /// Data received from step 1; optional for resuming an existing account.
  final CitizenRegistrationDraft? draft;

  @override
  State<CitizenIdVerificationScreen> createState() =>
      _CitizenIdVerificationScreenState();
}

class _CitizenIdVerificationScreenState
    extends State<CitizenIdVerificationScreen> {
  final _picker = ImagePicker();
  Uint8List? _preview;
  String? _error;
  bool _busy = false;
  final _checks = [false, false, false];

  @override
  void initState() {
    super.initState();
    _recoverLostPhoto();
  }

  Future<void> _recoverLostPhoto() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final response = await _picker.retrieveLostData();
      if (response.files case final List<XFile> files when files.isNotEmpty) {
        await _loadFile(files.first);
      }
    } catch (_) {
      // A lost demo sample is noncritical; user can select another.
    }
  }

  Future<void> _loadFile(XFile file) async {
    final length = await file.length();
    if (length <= 0 || length > 5 * 1024 * 1024) {
      throw const FormatException('Choose an image smaller than 5 MB.');
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _preview = bytes;
      _error = null;
      for (var i = 0; i < _checks.length; i++) {
        _checks[i] = false;
      }
    });
  }

  Future<void> _choose(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1400,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (file == null) return;
      await _loadFile(file);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not open photo: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _back() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('login', (_) => false);
    }
  }

  void _next() {
    if (_preview == null || _checks.any((element) => !element)) {
      setState(() => _error =
          'Select a sample image and confirm all three visual checks.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CitizenPinSetupScreen(draft: widget.draft),
      ),
    );
  }

  Widget _pill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFD7EFFB),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, color: Color(0xFF00699B), size: 19),
          SizedBox(width: 6),
          Text('Step 2 of 3: Verification',
            style: TextStyle(color: Color(0xFF00699B),
              fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _progress() {
    return Row(
      children: List.generate(3, (i) => Container(
        width: 25,
        height: 7,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: i < 2 ? _primary : const Color(0xFFCFEAF7),
          borderRadius: BorderRadius.circular(8),
        ),
      )),
    );
  }

  Widget _photoArea() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF081D2B),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_preview != null)
            Image.memory(_preview!, fit: BoxFit.contain, gaplessPlayback: false)
          else
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.badge_outlined, size: 82,
                  color: Color(0xFFB9DEFA)),
                SizedBox(height: 8),
                Text('Sample image preview',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          Positioned(
            top: 14,
            left: 13,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Text('DEMO • No automatic ID verification',
                style: TextStyle(color: Color(0xFF14527A),
                  fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
          Positioned(
            bottom: 13,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('Avoid glare and direct reflections',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _check(int index, String text) {
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      value: _checks[index],
      activeColor: const Color(0xFF19B78C),
      title: Text(text,
        style: const TextStyle(fontSize: 14, color: Color(0xFF26364D))),
      onChanged: _preview == null ? null : (v) => setState(() {
        _checks[index] = v ?? false;
        _error = null;
      }),
    );
  }

  Widget _photoButton(String label, IconData icon, VoidCallback tap,
      {bool filled = false}) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : tap,
          icon: Icon(icon, size: 22),
          label: Text(label, style: const TextStyle(fontSize: 14)),
          style: OutlinedButton.styleFrom(
            foregroundColor: filled ? const Color(0xFF00699B) : _ink,
            backgroundColor: filled ? const Color(0xFFDFF5FF) : Colors.white,
            side: const BorderSide(color: Color(0xFFE9F0F4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: _busy ? null : _back,
                icon: const Icon(Icons.arrow_back_ios_new, size: 27, color: Colors.black),
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [_pill(), const Spacer(), _progress()]),
            const SizedBox(height: 19),
            const Text('Scan ID Document',
              style: TextStyle(fontSize: 30, color: _primary)),
            const SizedBox(height: 9),
            const Text(
              'Align a sample identity card within the frame. '
              'Check that the image is clear. No real document verification is performed.',
              style: TextStyle(color: _ink, fontSize: 15, height: 1.45),
            ),
            const SizedBox(height: 22),
            _photoArea(),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF2F4F6)),
                boxShadow: const [BoxShadow(color: Color(0x0C000000),
                  blurRadius: 5, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Manual Preview Check (Demo)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  _check(0, 'All 4 corners are visible and aligned'),
                  _check(1, 'Text is readable; no glare on details'),
                  _check(2, 'Photo has sufficient lighting'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _photoButton('Retake Photo', Icons.refresh,
                  () => _choose(ImageSource.camera), filled: true),
                const SizedBox(width: 11),
                _photoButton('Upload File', Icons.image_outlined,
                  () => _choose(ImageSource.gallery)),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
            ],
            const Text('Use sample images only. The photo stays on this device; '
              'it is not uploaded to Firebase.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _ink)),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _busy ? null : _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Continue to PIN →',
                  style: TextStyle(fontSize: 19)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
