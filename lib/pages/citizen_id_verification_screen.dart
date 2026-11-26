import '../services/local_card_check.dart';
import '../services/citizen_identity_service.dart';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../models/citizen_registration_draft.dart';
import 'citizen_pin_setup_screen.dart';

const _primary = Color(0xFF03A9F4);
const _ink = Color(0xFF475870);

/// Step 2 checks the front of the card locally before opening PIN setup.
class CitizenIdVerificationScreen extends StatefulWidget {
  const CitizenIdVerificationScreen({super.key, this.draft, this.scanCard});

  /// Data received from step 1; optional for resuming an existing account.
  final CitizenRegistrationDraft? draft;

  /// Replaces the ML Kit scanner in tests. Returns the cropped card image,
  /// or null when the user cancels.
  final Future<XFile?> Function()? scanCard;

  @override
  State<CitizenIdVerificationScreen> createState() =>
      _CitizenIdVerificationScreenState();
}

class _CitizenIdVerificationScreenState
    extends State<CitizenIdVerificationScreen> {
  // ML Kit document scanner: finds the card edges, crops and straightens it
  // on the device (Google Play services). Gallery import goes through the
  // same crop step, so the reader always receives the card alone.
  DocumentScanner? _scanner;

  Future<XFile?> _scanWithMlKit() async {
    final scanner = _scanner ??= DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: ScannerMode.base,
        pageLimit: 1,
        isGalleryImport: true,
      ),
    );
    final result = await scanner.scanDocument();
    final List<String> paths = [...?result.images];
    return paths.isEmpty ? null : XFile(paths.first);
  }
  Uint8List? _preview;
  String? _error;
  bool _busy = false;
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  CardCheck? _result;

  @override
  void dispose() {
    _scanner?.close();
    super.dispose();
  }

  Future<void> _checkFile(XFile file) async {
    final length = await file.length();
    if (!mounted) return;
    if (length <= 0 || length > 5 * 1024 * 1024) {
      setState(() => _error = 'Choose an image smaller than 5 MB.');
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _preview = bytes);
    final expected =
        widget.draft?.nationalId ??
        await CitizenIdentityService.instance.savedNationalId();
    final result = await readLocalCard(bytes, expected);
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _result = result);
    if (result == CardCheck.match) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CitizenPinSetupScreen(draft: widget.draft),
        ),
      );
    }
  }

  Future<void> _scan() async {
    if (_busy || !_supported) return;
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
      _preview = null;
    });
    try {
      final card = await (widget.scanCard ?? _scanWithMlKit)();
      if (card != null && mounted) await _checkFile(card);
    } on PlatformException catch (e) {
      // Cancelling the scanner is not an error.
      if (mounted && !(e.message ?? '').toLowerCase().contains('cancel'))
        setState(
          () => _error =
              'The scanner is not available. Update Google Play services and try again.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _error = 'Could not complete the local check. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _message {
    if (!_supported)
      return 'Please use the Android app for the on-device card check.';
    if (_error != null) return _error!;
    if (_busy) return 'Checking on this device…';
    return switch (_result) {
      CardCheck.different =>
        'The number differs from step 1. Check the number or retake the photo.',
      CardCheck.layout => 'Could not recognize the card layout. Photograph the full front upright, filling the frame.',
      CardCheck.unreadable => 'Could not read one clear nine-digit ID. Retake the photo without glare.',
      CardCheck.match => 'Card layout and ID number matched.',
      null => 'Scan the front of your card. The scanner finds its edges and crops it for you.',
    };
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
          Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF00699B),
            size: 19,
          ),
          SizedBox(width: 6),
          Text(
            'Step 2 of 3: Verification',
            style: TextStyle(
              color: Color(0xFF00699B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress() {
    return Row(
      children: List.generate(
        3,
        (i) => Container(
          width: 25,
          height: 7,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: i < 2 ? _primary : const Color(0xFFCFEAF7),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
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
            Image.memory(
              _preview!,
              fit: BoxFit.contain,
              gaplessPlayback: false,
              errorBuilder: (_, error, stack) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white),
              ),
            )
          else
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.badge_outlined, size: 82, color: Color(0xFFB9DEFA)),
                SizedBox(height: 8),
                Text(
                  'Front of identity card',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
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
              child: const Text(
                'On-device visual check',
                style: TextStyle(
                  color: Color(0xFF14527A),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              child: const Text(
                'Avoid glare and direct reflections',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoButton(
    String label,
    IconData icon,
    VoidCallback tap, {
    bool filled = false,
  }) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _busy || !_supported ? null : tap,
          icon: Icon(icon, size: 22),
          label: Text(label, style: const TextStyle(fontSize: 14)),
          style: OutlinedButton.styleFrom(
            foregroundColor: filled ? const Color(0xFF00699B) : _ink,
            backgroundColor: filled ? const Color(0xFFDFF5FF) : Colors.white,
            side: const BorderSide(color: Color(0xFFE9F0F4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
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
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 27,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [_pill(), const Spacer(), _progress()]),
            const SizedBox(height: 19),
            const Text(
              'Scan ID Document',
              style: TextStyle(fontSize: 30, color: _primary),
            ),
            const SizedBox(height: 9),
            const Text(
              'Scan the front of your Palestinian ID. The scanner finds the card edges, then crops and straightens it. Keep the title, number and field labels free of glare.',
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
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Card layout and ID number',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (_busy) const LinearProgressIndicator(),
                  Semantics(liveRegion: true, child: Text(_message)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _photoButton(
                  'Scan card',
                  Icons.document_scanner_outlined,
                  _scan,
                  filled: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Your photo is processed on this device. A visual match opens PIN setup; it does not certify the document or its holder.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _ink),
            ),
          ],
        ),
      ),
    );
  }
}
