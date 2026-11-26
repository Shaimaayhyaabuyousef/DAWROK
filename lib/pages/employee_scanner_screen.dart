import '../services/queue_schedule.dart';
import '../services/server_clock.dart';
import '../services/facility_time.dart';
import 'employee_ticket_result.dart';
import 'workspace_style.dart';
import 'scanner_corners.dart';
import '../services/queue_audit_service.dart';
import 'absence_button.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/employee_work_service.dart';
import 'package:first_project/l10n/app_language.dart';

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
    this.facilityOwner = false,
  });
  final String facilityId, queueId;
  final int windowNumber;
  final bool facilityOwner;

  @override
  State<EmployeeScannerScreen> createState() => _EmployeeScannerScreenState();
}

class _EmployeeScannerScreenState extends State<EmployeeScannerScreen> {
  late final _operator = widget.facilityOwner
      ? EmployeeWorkService.forFacilityOwner(widget.facilityId)
      : EmployeeWorkService.forEmployee(widget.facilityId);
  final _text = TextEditingController();
  bool _busy = false;
  String? _failure;
  Map<String, dynamic>? _match;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _match = null;
      _failure = null;
    });
    try {
      final message = await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(message))));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _failure = e is StateError
              ? e.message
              : 'Queue action failed. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  late final _tickets = FirebaseFirestore.instance
      .collection('bookings')
      .where('facilityId', isEqualTo: widget.facilityId)
      .where('queueId', isEqualTo: widget.queueId);
  late final _updates = _tickets.snapshots();

  bool _calledHere(QueryDocumentSnapshot<Map<String, dynamic>> ticket) =>
      ticket.data()['status'] == 'called' &&
      ticket.data()['windowNumber'] == widget.windowNumber;

  Future<void> _verify(String raw) async {
    if (_busy || raw.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _match = null;
      _failure = null;
    });
    try {
      final code = employeeTicketCode(raw, widget.facilityId, widget.queueId);
      final tickets = (await _tickets.get(
        const GetOptions(source: Source.server),
      )).docs;
      final current = tickets.where(_calledHere).firstOrNull?.id;
      var ticket = tickets.where((d) => d.id == code).firstOrNull;
      if (ticket == null &&
          !raw.trim().startsWith('DAWROK|') &&
          int.tryParse(code) != null) {
        final day = QueueSchedule.dayKey(await ServerClock.now());
        final matches = tickets
            .where(
              (d) =>
                  d.data()['dayKey'] == day &&
                  d.data()['queuePosition'] == int.tryParse(code),
            )
            .toList();
        if (matches.length == 1) ticket = matches.single;
      }
      if (ticket == null) {
        throw StateError(
          'Ticket not found in this queue. Check the ticket ID.',
        );
      }
      if (!{'waiting', 'called'}.contains(ticket.data()['status'])) {
        throw StateError('This ticket is already closed.');
      }
      if (current == null) {
        throw StateError('Call the next ticket before checking it in.');
      }
      if (ticket.id != current) {
        final expected = tickets.firstWhere((d) => d.id == current);
        final actual = ticket.data()['queuePosition'] ?? ticket.id;
        final position = expected.data()['queuePosition'] ?? current;
        final slot = ticket.data()['slotStart'] as Timestamp?;
        final time = slot == null ? null : FacilityTime.wall(slot.toDate());
        final appointment = time == null
            ? ''
            : ' Its appointment is at ${QueueSchedule.clock(time.hour * 60 + time.minute)}.';
        throw StateError(
          'This is ticket #$actual, not #$position.$appointment Please wait for the called turn.',
        );
      }
      final data = await _operator.checkIn(
        ticket.id,
        widget.queueId,
        widget.windowNumber,
      );
      if (mounted) setState(() => _match = {...data, 'ticketId': ticket!.id});
    } on StateError catch (error) {
      if (mounted) setState(() => _failure = error.message);
      try {
        await QueueAuditService.record(
          widget.facilityId,
          'Invalid code',
          '',
          outcome: 'invalid',
        );
      } on FirebaseException catch (e) {
        debugPrint('Could not record invalid scan: ${e.code}');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _failure = 'Unable to verify this ticket. Check your connection and assignment.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkspaceStyle(
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _updates,
          builder: (context, tickets) {
            if (tickets.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr("Queue unavailable. Return home")),
                ),
              );
            }
            if (!tickets.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final queueTickets = tickets.requireData.docs;
            final called = queueTickets.where(_calledHere);
            final waiting = queueTickets.where(
              (doc) => doc.data()['status'] == 'waiting',
            );
            final current = called.isNotEmpty ? called.first.id : null;
            final visibleMatch = _match?['ticketId'] == current ? _match : null;
            return ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(23, 14, 23, 33),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.black,
                      size: 23,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E8F2)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 37,
                        height: 37,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F7FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.apartment_outlined,
                          color: _blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr(widget.windowNumber == 0
                              ? 'Direct queue service'
                              : 'Counter ${widget.windowNumber.toString().padLeft(2, '0')}'),
                          style: const TextStyle(color: _ink, fontSize: 16),
                        ),
                      ),
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: waiting.isNotEmpty || called.isNotEmpty
                            ? const Color(0xFF10B58B)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 13),
                    ],
                  ),
                ),
                const SizedBox(height: 42),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _text,
                    enabled: !_busy,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) => _verify(v),
                    onChanged: (_) => setState(() {
                      _match = null;
                      _failure = null;
                    }),
                    decoration: InputDecoration(
                      hintText: tr('Ticket ID or turn number'),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xfffafbfd),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _failure != null
                              ? const Color(0xffffb7b7)
                              : visibleMatch != null
                              ? const Color(0xff9be4b8)
                              : const Color(0xffdce5ef),
                        ),
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_text.text.trim().isNotEmpty)
                            IconButton(
                              tooltip: tr('Verify ticket'),
                              icon: const Icon(Icons.check, color: _blue),
                              onPressed: () => _verify(_text.text),
                            ),
                          IconButton(
                            tooltip: tr('Scan QR code'),
                            icon: const Icon(
                              Icons.qr_code_scanner,
                              color: _blue,
                            ),
                            onPressed: _busy
                                ? null
                                : () async {
                                    final code =
                                        await showModalBottomSheet<String>(
                                          context: context,
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          backgroundColor: Colors.white,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(40),
                                            ),
                                          ),
                                          builder: (_) => const _ScannerSheet(),
                                        );
                                    if (code != null && mounted) {
                                      await _verify(code);
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_failure != null || visibleMatch != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: EmployeeTicketResult(
                      match: visibleMatch,
                      failure: _failure,
                    ),
                  ),
                const SizedBox(height: 38),
                Row(
                  children: [
                    Expanded(
                      child: _action(
                        'Next',
                        () => _run(
                          () => current != null
                              ? Future.value('Finish the current ticket first.')
                              : waiting.isEmpty
                              ? Future.value('No waiting tickets.')
                              : _operator.callNext(
                                  widget.queueId,
                                  widget.windowNumber,
                                ),
                        ),
                        primary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AbsenceButton(
                        calledAt: called.isEmpty
                            ? null
                            : (called.first.data()['calledAt'] as Timestamp?)
                                  ?.toDate(),
                        onAbsent:
                            current == null ||
                                called.first.data()['checkedIn'] == true
                            ? null
                            : () => _run(
                                () => _operator.changeTicket(
                                  current,
                                  'absent',
                                  widget.queueId,
                                  widget.windowNumber,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _action(
                        'Post',
                        current == null
                            ? null
                            : () => _run(
                                () => _operator.changeTicket(
                                  current,
                                  'postpone',
                                  widget.queueId,
                                  widget.windowNumber,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (current != null && called.first.data()['checkedIn'] == true)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => _operator.changeTicket(
                              current,
                              'served',
                              widget.queueId,
                              widget.windowNumber,
                            ),
                          ),
                    child: Text(tr('Complete service')),
                  ),
                const SizedBox(height: 47),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('facilities')
                      .doc(widget.facilityId)
                      .collection('queue_logs')
                      .orderBy('createdAt', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (context, logs) {
                    if (logs.hasError) {
                      return Text(
                        tr('Logs error: ${logs.error}'),
                        style: const TextStyle(color: Colors.red),
                      );
                    }
                    final docs = (logs.data?.docs ?? [])
                        .where(
                          (doc) =>
                              const {
                                'Checked in',
                                'Ticket check-in',
                              }.contains(doc.data()['label']) ||
                              doc.data()['outcome'] == 'invalid',
                        )
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              tr('RECENT SURVEYS'),
                              style: TextStyle(
                                color: Color(0xFF52657F),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Text(
                              tr('${docs.length} logs'),
                              style: const TextStyle(color: Color(0xFF8A9DB3)),
                            ),
                          ],
                        ),
                        const Divider(height: 21),
                        if (docs.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(14),
                            child: Text(
                              tr('No scans yet.'),
                              style: TextStyle(color: _muted),
                            ),
                          ),
                        for (final doc in docs) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor:
                                  doc.data()['outcome'] == 'invalid'
                                  ? const Color(0xff570c20)
                                  : const Color(0xFF111D34),
                              child: Icon(
                                doc.data()['outcome'] == 'invalid'
                                    ? Icons.warning_amber_rounded
                                    : Icons.shopping_bag_outlined,
                                color: Colors.white,
                              ),
                            ),
                            title: Wrap(
                              spacing: 6,
                              children: [
                                Text(
                                  tr(doc.data()['label'] as String? ?? 'Ticket'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  tr(doc.data()['outcome'] == 'invalid'
                                      ? 'Failed attempt'
                                      : 'Verified'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: doc.data()['outcome'] == 'invalid'
                                        ? Colors.red
                                        : Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              tr('ID: ${doc.data()['identifier'] ?? ''}'),
                            ),
                            trailing: Icon(
                              doc.data()['outcome'] == 'invalid'
                                  ? Icons.cancel_outlined
                                  : Icons.check_circle_outline,
                              color: doc.data()['outcome'] == 'invalid'
                                  ? Colors.redAccent
                                  : const Color(0xFF10AD86),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _action(String text, VoidCallback? action, {bool primary = false}) =>
      ElevatedButton(
        onPressed: _busy ? null : action,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 43),
          backgroundColor: primary
              ? const Color(0xFF4FAAF4)
              : const Color(0xFF12456D),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(tr(text), style: const TextStyle(fontSize: 13)),
      );
}

class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet();
  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  final camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool returning = false;
  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  Future<void> control(Future<void> Function() action) async {
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
  Widget build(BuildContext context) => WorkspaceStyle(
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 18, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.circle, color: _blue, size: 10),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('QR Code Scanner'),
                    style: TextStyle(fontSize: 18, color: _ink),
                  ),
                ),
                IconButton(
                  tooltip: tr('Flashlight'),
                  icon: const Icon(Icons.flash_on_outlined),
                  onPressed: () => control(camera.toggleTorch),
                ),
                IconButton(
                  tooltip: tr('Switch camera'),
                  icon: const Icon(Icons.cameraswitch_outlined),
                  onPressed: () => control(camera.switchCamera),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 1.5,
                child: MobileScanner(
                  controller: camera,
                  onDetect: (capture) {
                    final value = capture.barcodes.firstOrNull?.rawValue;
                    if (returning ||
                        value == null ||
                        value.isEmpty ||
                        ModalRoute.of(context)?.isCurrent != true) {
                      return;
                    }
                    returning = true;
                    Navigator.pop(context, value);
                  },
                  overlayBuilder: (context, constraints) => IgnorePointer(
                    child: SizedBox.expand(
                      child: CustomPaint(painter: ScannerCorners()),
                    ),
                  ),
                  errorBuilder: (_, error) => ColoredBox(
                    color: _ink,
                    child: Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          tr('Camera unavailable. Enter ticket manually.'),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr('Please place the code inside the\nframe for automatic scanning.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          ],
        ),
      ),
    ),
  );
}
