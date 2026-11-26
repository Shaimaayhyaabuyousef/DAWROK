import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:first_project/l10n/app_language.dart';

import 'center_details_screen.dart';
import 'facility_qr.dart';
import 'scanner_corners.dart';

/// Opens the citizen camera to scan a facility's QR code, then shows that
/// facility so the citizen can join one of its queues.
Future<void> openFacilityScanner(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CitizenFacilityScanner()),
    );

class CitizenFacilityScanner extends StatefulWidget {
  const CitizenFacilityScanner({super.key});

  @override
  State<CitizenFacilityScanner> createState() => _CitizenFacilityScannerState();
}

class _CitizenFacilityScannerState extends State<CitizenFacilityScanner> {
  final _camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _opening = false;
  String? _lastInvalid;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (_opening || value == null || value.isEmpty) return;
    final id = facilityIdFromQr(value);
    if (id == null) {
      if (_lastInvalid == value) return;
      _lastInvalid = value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('This is not a DAWROK facility code.'))),
      );
      return;
    }
    _opening = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CenterDetailsScreen(
          facilityId: id,
          name: '',
          address: '',
          rating: '',
          openingFrom: '',
          openingTo: '',
        ),
      ),
    );
  }

  Future<void> _control(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Camera control unavailable.'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1E33),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            overlayBuilder: (context, constraints) => IgnorePointer(
              child: SizedBox.expand(
                child: CustomPaint(painter: ScannerCorners()),
              ),
            ),
            errorBuilder: (_, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  tr('Camera unavailable. Allow camera access and try again.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: tr('Back'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      tr('Scan facility QR'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Flashlight'),
                    onPressed: () => _control(_camera.toggleTorch),
                    icon: const Icon(Icons.flash_on_outlined, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            start: 24,
            end: 24,
            bottom: 48,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  tr('Point the camera at the QR code shown at the facility to open it and join its queue.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
