import '../services/booking_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/employee_work_service.dart';

const _blue = Color(0xFF03A9F4);
const _ink = Color(0xFF28374E);
const _muted = Color(0xFF71829B);

/// Employee scanner: uses the real facility booking records and audit logs.
class EmployeeScannerScreen extends StatefulWidget {
  const EmployeeScannerScreen({
    super.key,
    required this.facilityId,
    required this.queueId,
    required this.windowNumber,
  });
  final String facilityId, queueId;
  final int windowNumber;

  @override
  State<EmployeeScannerScreen> createState() => _EmployeeScannerScreenState();
}

class _EmployeeScannerScreenState extends State<EmployeeScannerScreen> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _text = TextEditingController();
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _camera.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _result = null; });
    try {
      final result = await action();
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _result = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _manual() {
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Manual ticket input'),
      content: TextField(
        controller: _text,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Ticket number or QR content',
          border: OutlineInputBorder())),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            _run(() => EmployeeWorkService.instance.checkIn(_text.text));
          },
          child: const Text('Verify')),
      ],
    ));
  }

  Future<void> _scan(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes.isEmpty ? null
        : capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    await _run(() => EmployeeWorkService.instance.checkIn(code));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('bookings')
          .where('facilityId', isEqualTo: widget.facilityId).snapshots(),
        builder: (context, tickets) {
          final queueTickets = tickets.data?.docs.where((doc) =>
            doc.data()['queueId'] == widget.queueId).toList() ?? [];
          final called = queueTickets.where((doc) =>
            doc.data()['status'] == 'called').toList();
          final waiting = queueTickets.where((doc) =>
            doc.data()['status'] == 'waiting').toList();
          waiting.sort((a,b) => compareBookingRows(a.data(),a.id,b.data(),b.id));
          final current = called.isNotEmpty ? called.first.id : null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(23, 14, 23, 33),
            children: [
              Align(alignment: Alignment.centerLeft, child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.black, size: 23))),
              const SizedBox(height: 34),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E8F2)),
                  borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Container(width: 37, height: 37,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F7FF),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.apartment_outlined, color: _blue)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    'Counter ${widget.windowNumber.toString().padLeft(2, '0')}  •  Floor 1',
                    style: const TextStyle(color: _ink, fontSize: 16))),
                  CircleAvatar(radius: 4, backgroundColor:
                    waiting.isNotEmpty || called.isNotEmpty
                      ? const Color(0xFF10B58B) : Colors.grey),
                  const SizedBox(width: 13),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFE7F7FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                    child: const Text('Change', style: TextStyle(color: _blue))),
                ]),
              ),
              const SizedBox(height: 42),
              Container(
                height: 217,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF192237),
                  border: Border.all(color: const Color(0xFF8E9AAD), width: 2),
                  borderRadius: BorderRadius.circular(26)),
                child: Stack(children: [
                  MobileScanner(
                    controller: _camera,
                    onDetect: _scan,
                    errorBuilder: (context, error) => Center(child:
                      Text('Camera unavailable. Use manual input.\n$error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 12))),
                  ),
                  IgnorePointer(child: Center(child: Container(
                    height: 139, width: 139,
                    decoration: BoxDecoration(
                      border: Border.all(color: _blue, width: 3),
                      borderRadius: BorderRadius.circular(19)),
                  ))),
                ]),
              ),
              const SizedBox(height: 13),
              const Text('Please place the code inside the frame for automatic scanning.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13, height: 1.35)),
              const SizedBox(height: 13),
              OutlinedButton.icon(
                onPressed: _busy ? null : _manual,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('manual input',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: const Color(0xFF0086D3),
                  side: const BorderSide(color: Color(0xFFB5DFFB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              ),
              if (_result != null) Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Text(_result!, textAlign: TextAlign.center,
                  style: const TextStyle(color: _blue, fontSize: 12))),
              const SizedBox(height: 38),
              Row(children: [
                Expanded(child: _action('Next', () => _run(() =>
                  current != null ? Future.value('Finish the current ticket first.') : waiting.isEmpty
                    ? Future.value('No waiting tickets.')
                    : EmployeeWorkService.instance.changeTicket(
                        waiting.first.id, 'called')), primary: true)),
                const SizedBox(width: 12),
                Expanded(child: _action('Absent', current == null ? null
                  : () => _run(() => EmployeeWorkService.instance
                    .changeTicket(current, 'absent')))),
                const SizedBox(width: 12),
                Expanded(child: _action('Post', current == null ? null
                  : () => _run(() => EmployeeWorkService.instance
                    .changeTicket(current, 'postpone')))),
              ]),
              const SizedBox(height: 47),
              StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                stream: FirebaseFirestore.instance
                  .collection('facilities').doc(widget.facilityId)
                  .collection('queue_logs').orderBy('createdAt', descending: true)
                  .limit(10).snapshots(),
                builder: (context, logs) {
                  if (logs.hasError) return Text('Logs error: ${logs.error}',
                    style: const TextStyle(color: Colors.red));
                  final docs = logs.data?.docs ?? [];
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('RECENT SURVEYS', style: TextStyle(
                        color: Color(0xFF52657F), fontSize: 13)),
                      const SizedBox(width: 11),
                      Text('${docs.length} logs',
                        style: const TextStyle(color: Color(0xFF8A9DB3))),
                    ]),
                    const Divider(height: 21),
                    if (docs.isEmpty) const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No scans yet.', style: TextStyle(color: _muted))),
                    for (final doc in docs) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(backgroundColor: const Color(0xFF111D34),
                          child: Icon(doc.data()['outcome'] == 'invalid'
                            ? Icons.warning_amber_rounded
                            : Icons.shopping_bag_outlined, color: Colors.white)),
                        title: Text(doc.data()['label'] as String? ?? 'Ticket'),
                        subtitle: Text('ID: ${doc.data()['identifier'] ?? ''}'),
                        trailing: Icon(
                          doc.data()['outcome'] == 'invalid'
                            ? Icons.cancel_outlined : Icons.check_circle_outline,
                          color: doc.data()['outcome'] == 'invalid'
                            ? Colors.redAccent : const Color(0xFF10AD86)),
                      ),
                      const Divider(height: 1),
                    ],
                  ]);
                },
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _action(String text, VoidCallback? action, {bool primary = false}) =>
      ElevatedButton(
        onPressed: _busy ? null : action,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 43),
          backgroundColor: primary ? const Color(0xFF4FAAF4) : const Color(0xFF12456D),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13)),
          padding: EdgeInsets.zero,
        ),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      );
}
