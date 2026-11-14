import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'facility_queue_store.dart';
import 'facility_scan_store.dart';

const _blue = Color(0xFF4AAAF3);
const _bright = Color(0xFF04A8EF);
const _ink = Color(0xFF243148);
const _subtle = Color(0xFF62728B);
const _outline = Color(0xFFDFE8F1);

/// Facility owner counter panel. This screen does not require a staff record.
class FacilityScanScreen extends StatefulWidget {
  const FacilityScanScreen({super.key});

  @override
  State<FacilityScanScreen> createState() => _FacilityScanScreenState();
}

class _FacilityScanScreenState extends State<FacilityScanScreen> {
  final FacilityScanStore _visits = FacilityScanStore.instance;
  final FacilityQueueStore _queues = FacilityQueueStore.instance;
  final MobileScannerController _camera = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  int _windowNumber = 2;
  bool _processing = false;

  FacilityQueue? get _selectedQueue {
    for (final queue in _queues.queues) {
      if (queue.windowNumber == _windowNumber) return queue;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (_queues.queues.isNotEmpty && !_queues.queues.any((q) => q.windowNumber == _windowNumber)) {
      _windowNumber = _queues.queues.first.windowNumber;
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _message(String message, {bool invalid = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: invalid ? const Color(0xFFBA2546) : const Color(0xFF183C62),
    ));
  }

  void _perform(String Function(int) operation) {
    final queue = _selectedQueue;
    if (queue == null || !queue.isActive) {
      _message('Select an active counter first.', invalid: true);
      return;
    }
    _message(operation(_windowNumber));
  }

  Future<void> _changeCounter() async {
    try { await _camera.stop(); } catch (_) {}
    if (!mounted) return;
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose a counter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
              const SizedBox(height: 14),
              if (_queues.queues.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Create a queue first.')),
              for (final queue in _queues.queues)
                ListTile(
                  title: Text('Counter ${queue.windowNumber.toString().padLeft(2, '0')} • ${queue.service}'),
                  subtitle: Text(queue.isActive ? 'Active' : 'Stopped'),
                  trailing: queue.windowNumber == _windowNumber ? const Icon(Icons.check, color: _bright) : null,
                  onTap: () => Navigator.pop(sheetContext, queue.windowNumber),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice != null) setState(() => _windowNumber = choice);
    try { await _camera.start(); } catch (_) {}
  }

  Future<void> _handleCode(String raw) async {
    if (_processing) return;
    final queue = _selectedQueue;
    if (queue == null || !queue.isActive) {
      _message('Counter is stopped or unavailable.', invalid: true);
      return;
    }
    _processing = true;
    try { await _camera.stop(); } catch (_) {}
    if (!mounted) return;
    final result = _visits.verifyDemoCode(raw, _windowNumber);
    _message(result.message, invalid: result.outcome == FacilityScanOutcome.invalid);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    try {
      await _camera.start();
    } catch (_) {
      // The errorBuilder displays the permission/device error.
    } finally {
      _processing = false;
    }
  }

  Future<void> _manualInput() async {
    try { await _camera.stop(); } catch (_) {}
    if (!mounted) return;
    String typed = '';
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manual ticket input'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => typed = value,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Example: A-104',
            labelText: 'Ticket number / QR content',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, typed), child: const Text('Verify')),
        ],
      ),
    );
    if (!mounted) return;
    if (raw != null && raw.trim().isNotEmpty) {
      final queue = _selectedQueue;
      if (queue == null || !queue.isActive) {
        _message('Select an active counter first.', invalid: true);
      } else {
        final result = _visits.verifyDemoCode(raw, _windowNumber);
        _message(result.message, invalid: result.outcome == FacilityScanOutcome.invalid);
      }
    }
    try { await _camera.start(); } catch (_) {}
  }

  Future<void> _markAbsent() async {
    if (_selectedQueue?.isActive != true) {
      _message('Select an active counter first.', invalid: true);
      return;
    }
    final current = _visits.currentFor(_windowNumber);
    if (current == null) { _message('Call a visitor first.'); return; }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark visitor absent?'),
        content: Text('Ticket #${current.ticketNumber} will be removed from the waiting flow.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Mark absent')),
        ],
      ),
    );
    if (confirmed == true) _perform(_visits.markAbsent);
  }

  Future<void> _postponeCurrent() async {
    if (_selectedQueue?.isActive != true) {
      _message('Select an active counter first.', invalid: true);
      return;
    }
    final current = _visits.currentFor(_windowNumber);
    if (current == null) {
      _message('Call a visitor first.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Postpone this turn?'),
        content: Text('Ticket #${current.ticketNumber} will move to the end of the waiting queue without being cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Postpone'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) _perform(_visits.postponeCurrent);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_visits, _queues]),
            builder: (context, _) {
              final queue = _selectedQueue;
              final current = _visits.currentFor(_windowNumber);
              final active = queue?.isActive ?? false;
              return ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                children: [
                  Align(alignment: Alignment.centerLeft, child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 22),
                    onPressed: () => Navigator.pop(context),
                  )),
                  const SizedBox(height: 17),
                  _counterCard(active),
                  const SizedBox(height: 40),
                  _cameraFrame(),
                  const SizedBox(height: 12),
                  const Text('Please place the code inside the frame for automatic scanning.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _subtle, fontSize: 13, height: 1.35)),
                  const SizedBox(height: 13),
                  SizedBox(height: 41, child: OutlinedButton.icon(
                    onPressed: _manualInput,
                    icon: const Icon(Icons.keyboard_outlined, size: 19),
                    label: const Text('manual input', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF008CD3),
                      side: const BorderSide(color: Color(0xFFB1DEFF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                  const SizedBox(height: 38),
                  Row(children: [
                    Expanded(child: _actionButton('Next', Icons.chevron_right_rounded, _blue, () => _perform(_visits.callNext))),
                    const SizedBox(width: 14),
                    Expanded(child: _actionButton('Absent', null, const Color(0xFF133F64), _markAbsent)),
                    const SizedBox(width: 14),
                    Expanded(child: Tooltip(
                      message: 'Postpone current turn',
                      child: _actionButton('Post', null, const Color(0xFF133F64), _postponeCurrent),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  if (current != null) Text(
                    'Now calling: #${current.ticketNumber} • ${current.visitorName}',
                    style: const TextStyle(color: Color(0xFF007DAD), fontWeight: FontWeight.w600, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  if (current != null && current.checkedIn) ...[
                    const SizedBox(height: 10),
                    Center(child: TextButton.icon(
                      onPressed: () => _perform(_visits.markServed),
                      icon: const Icon(Icons.check_circle_outline, size: 19),
                      label: const Text('Complete service'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF009E75),
                      ),
                    )),
                  ],
                  const SizedBox(height: 35),
                  Row(children: [
                    const Text('RECENT SURVEYS', style: TextStyle(color: _subtle, fontSize: 12)),
                    const SizedBox(width: 9),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE9EFF6), borderRadius: BorderRadius.circular(18)),
                      child: Text('${_visits.logs.length} logs', style: const TextStyle(fontSize: 12, color: _ink))),
                  ]),
                  const Divider(height: 23, color: _outline),
                  for (final log in _visits.logs) _logTile(log),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _counterCard(bool active) => Container(
    height: 55,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _outline),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Color(0x0F25466C), blurRadius: 4, offset: Offset(0, 2))],
    ),
    child: Row(children: [
      Container(width: 33, height: 33,
        decoration: BoxDecoration(color: const Color(0xFFE0F5FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA7E3FF))),
        child: const Icon(Icons.apartment_rounded, color: _bright, size: 21)),
      const SizedBox(width: 12),
      Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text('Counter ${_windowNumber.toString().padLeft(2, '0')} • Floor 1',
          style: const TextStyle(color: _ink, fontSize: 16)))),
      const SizedBox(width: 6),
      Icon(Icons.circle, size: 8, color: active ? const Color(0xFF0AB97B) : Colors.orange),
      const SizedBox(width: 10),
      OutlinedButton(onPressed: _changeCounter,
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: const Color(0xFFE4F6FF), foregroundColor: _bright,
          side: const BorderSide(color: Color(0xFFBAE4FC)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
        child: const Text('Change', style: TextStyle(fontSize: 12))),
    ]),
  );

  Widget _cameraFrame() => AspectRatio(
    aspectRatio: 1.68,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Stack(fit: StackFit.expand, children: [
        Container(color: const Color(0xFF121C32)),
        MobileScanner(
          controller: _camera,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final raw = barcode.rawValue;
              if (raw != null && raw.isNotEmpty) {
                unawaited(_handleCode(raw));
                break;
              }
            }
          },
          errorBuilder: (_, error) => Container(
            color: const Color(0xFF182338),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(18),
            child: const Text('Camera unavailable. Use manual input below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70)),
          ),
        ),
        IgnorePointer(child: Container(
          decoration: BoxDecoration(
            color: const Color(0x30040E25),
            border: Border.all(color: const Color(0xFF8C97A8), width: 2.5),
            borderRadius: BorderRadius.circular(25),
          ),
        )),
        IgnorePointer(child: CustomPaint(painter: _ScannerCorners())),
        const IgnorePointer(child: Center(child: Icon(Icons.qr_code_scanner_rounded, color: Color(0x668ABED8), size: 75))),
      ]),
    ),
  );

  Widget _actionButton(String label, IconData? icon, Color color, VoidCallback onPressed) => SizedBox(
    height: 35,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        if (icon != null) Icon(icon, size: 20),
      ]),
    ),
  );

  Widget _logTile(FacilityScanLog log) {
    final valid = log.outcome != FacilityScanOutcome.invalid;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE9EDF3)))),
      child: Row(children: [
        CircleAvatar(radius: 20,
          backgroundColor: valid ? const Color(0xFF121B31) : const Color(0xFF500520),
          child: Icon(valid ? Icons.shopping_bag_outlined : Icons.warning_amber_rounded, color: Colors.white, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(log.label, style: TextStyle(color: valid ? _ink : const Color(0xFFE62B55), fontSize: 13)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: valid ? const Color(0xFFEAFBF4) : const Color(0xFFFFEFF2), borderRadius: BorderRadius.circular(5)),
              child: Text(valid ? 'Verified' : 'Failed attempt',
                style: TextStyle(color: valid ? const Color(0xFF009E75) : const Color(0xFFF02A56), fontSize: 11))),
          ]),
          const SizedBox(height: 4),
          Text('ID: ${log.identifier}', style: const TextStyle(color: Color(0xFF8595AE), fontSize: 12)),
        ])),
        Icon(valid ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 26, color: valid ? const Color(0xFF13B98E) : const Color(0xFFE93961)),
      ]),
    );
  }
}

class _ScannerCorners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF28B9FF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;
    final left = size.width * .29;
    final right = size.width * .71;
    final top = size.height * .16;
    final bottom = size.height * .84;
    const length = 23.0;
    final path = Path()
      ..moveTo(left + length, top)..lineTo(left + 8, top)..quadraticBezierTo(left, top, left, top + 8)..lineTo(left, top + length)
      ..moveTo(right - length, top)..lineTo(right - 8, top)..quadraticBezierTo(right, top, right, top + 8)..lineTo(right, top + length)
      ..moveTo(left + length, bottom)..lineTo(left + 8, bottom)..quadraticBezierTo(left, bottom, left, bottom - 8)..lineTo(left, bottom - length)
      ..moveTo(right - length, bottom)..lineTo(right - 8, bottom)..quadraticBezierTo(right, bottom, right, bottom - 8)..lineTo(right, bottom - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
