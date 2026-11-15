import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/facility_context.dart';

enum FacilityVisitStatus { waiting, called, served, absent }
enum FacilityScanOutcome { verified, repeated, invalid }

class FacilityVisit {
  final String ticketNumber;
  final String visitorName;
  final String maskedId;
  final int windowNumber;
  final int estimatedMinutes;
  FacilityVisitStatus status;
  bool checkedIn;
  int postponements;

  FacilityVisit({
    required this.ticketNumber,
    required this.visitorName,
    required this.maskedId,
    required this.windowNumber,
    required this.estimatedMinutes,
    this.status = FacilityVisitStatus.waiting,
    this.checkedIn = false,
    this.postponements = 0,
  });
}

class FacilityScanLog {
  final String label;
  final String identifier;
  final FacilityScanOutcome outcome;
  final DateTime createdAt;

  FacilityScanLog({
    required this.label,
    required this.identifier,
    required this.outcome,
    required this.createdAt,
  });
}

class FacilityScanResult {
  final FacilityScanOutcome outcome;
  final String message;
  const FacilityScanResult(this.outcome, this.message);
}

class FacilityScanStore extends ChangeNotifier {
  FacilityScanStore._() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      _bookingsSub?.cancel();
      _logsSub?.cancel();
      _facilityId = null;
      _visits.clear(); _logs.clear();
      notifyListeners();
      _listen();
    });
  }
  static final instance = FacilityScanStore._();
  final _db = FirebaseFirestore.instance;
  String? _facilityId;
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? _bookingsSub, _logsSub;
  final List<FacilityVisit> _visits = [];
  final List<FacilityScanLog> _logs = [];
  List<FacilityVisit> get visits => List.unmodifiable(_visits);
  List<FacilityScanLog> get logs => List.unmodifiable(_logs);

  Future<void> _listen() async {
    try {
      final id = await FacilityContext.instance.requireFacilityId();
      _facilityId = id;
      _bookingsSub = _db.collection('bookings')
          .where('facilityId', isEqualTo: id)
          .snapshots().listen((snap) {
        _visits
          ..clear()
          ..addAll(snap.docs.map((d) {
            final m = d.data();
            final status = FacilityVisitStatus.values.firstWhere(
              (v) => v.name == m['status'], orElse: () => FacilityVisitStatus.waiting);
            return FacilityVisit(
              ticketNumber: d.id,
              visitorName: m['citizenName'] as String? ?? '',
              maskedId: '••••',
              windowNumber: (m['windowNumber'] as num?)?.toInt() ?? 0,
              estimatedMinutes: 30,
              status: status, checkedIn: m['checkedIn'] == true,
              postponements: (m['postponements'] as num?)?.toInt() ?? 0,
            );
          }));
        notifyListeners();
      });
      _logsSub = _db.collection('facilities').doc(id).collection('queue_logs')
          .orderBy('createdAt', descending: true).limit(20)
          .snapshots().listen((snap) {
        _logs
          ..clear()
          ..addAll(snap.docs.map((d) {
            final m = d.data();
            return FacilityScanLog(
              label: m['label'] as String? ?? '',
              identifier: m['identifier'] as String? ?? '',
              outcome: FacilityScanOutcome.values.firstWhere(
                (v) => v.name == m['outcome'], orElse: () => FacilityScanOutcome.invalid),
              createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }));
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Facility scans not available: ${e.toString()}');
      notifyListeners();
    }
  }

  DocumentReference<Map<String,dynamic>> _ticket(String id) =>
      _db.collection('bookings').doc(id);

  Future<void> _log(String label, String identifier, FacilityScanOutcome result) async {
    final id = _facilityId;
    if (id == null) return;
    await _db.collection('facilities').doc(id).collection('queue_logs').add({
      'label': label, 'identifier': identifier.length > 25
          ? identifier.substring(0, 25) : identifier,
      'outcome': result.name, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  FacilityVisit? currentFor(int windowNumber) {
    for (final v in _visits) {
      if (v.windowNumber == windowNumber && v.status == FacilityVisitStatus.called) return v;
    }
    return null;
  }

  int waitingCount(int n) => _visits.where((v) =>
    v.windowNumber == n && v.status == FacilityVisitStatus.waiting).length;

  Future<String> callNext(int n) async {
    if (currentFor(n) != null) return 'Finish or mark the current ticket absent first.';
    final candidates = _visits.where((v) => v.windowNumber == n &&
      v.status == FacilityVisitStatus.waiting).toList();
    if (candidates.isEmpty) return 'There are no waiting tickets for this counter.';
    final v = candidates.first;
    await _ticket(v.ticketNumber).update({
      'status': 'called', 'calledAt': FieldValue.serverTimestamp(),
    });
    await _log('Called', v.ticketNumber, FacilityScanOutcome.verified);
    return 'Calling ticket #${v.ticketNumber} — ${v.visitorName}';
  }

  Future<String> markAbsent(int n) async {
    final v = currentFor(n);
    if (v == null) return 'Call a visitor first.';
    await _close(v, 'absent');
    return 'Ticket #${v.ticketNumber} marked absent.';
  }

  Future<String> postponeCurrent(int n) async {
    final v = currentFor(n);
    if (v == null) return 'Call a visitor first.';
    final waiting = _visits.any((v) => v.windowNumber == n &&
        v.status == FacilityVisitStatus.waiting);
    if (!waiting) return 'No other visitors are waiting in this counter.';
    await _ticket(v.ticketNumber).update({
      'status': 'waiting', 'postponements': FieldValue.increment(1),
    });
    await _log('Postponed', v.ticketNumber, FacilityScanOutcome.verified);
    return 'Ticket #${v.ticketNumber} postponed.';
  }

  Future<String> markServed(int n) async {
    final v = currentFor(n);
    if (v == null) return 'Call a visitor first.';
    if (!v.checkedIn) return 'Verify the ticket before completing service.';
    await _close(v, 'served');
    return 'Service completed for #${v.ticketNumber}.';
  }

  Future<void> _close(FacilityVisit v, String status) async {
    final id = _facilityId;
    if (id == null) throw StateError('Facility is not loaded.');
    await _db.runTransaction((tx) async {
      final b = await tx.get(_ticket(v.ticketNumber));
      if (b.data()?['status'] != 'called') throw StateError('Ticket is no longer called.');
      if (status == 'served' && b.data()?['checkedIn'] != true) {
        throw StateError('Check-in is required before serving.');
      }
      tx.update(_ticket(v.ticketNumber), {
        'status': status, 'closedAt': FieldValue.serverTimestamp(),
      });
    });
    await _log(status == 'served' ? 'Served' : 'Absent', v.ticketNumber,
        FacilityScanOutcome.verified);
  }

  Future<FacilityScanResult> verifyDemoCode(String raw, int windowNumber) async {
    final id = _facilityId;
    if (id == null) return const FacilityScanResult(
      FacilityScanOutcome.invalid, 'Facility is not loaded.');
    var ticketId = raw.trim();
    if (ticketId.startsWith('DAWROK|')) {
      final parts = ticketId.split('|');
      final tickets = parts.where((x) => x.startsWith('ticket=')).toList();
      if (tickets.length != 1) return _invalid(raw, 'Malformed ticket QR.');
      ticketId = tickets.single.substring('ticket='.length);
    }
    if (ticketId.isEmpty) return _invalid(raw, 'Empty ticket.');
    try {
      final snap = await _ticket(ticketId).get();
      final m = snap.data();
      if (m == null || m['facilityId'] != id ||
          m['windowNumber'] != windowNumber) {
        return _invalid(raw, 'Ticket is not valid for this counter.');
      }
      if (m['status'] == 'served' || m['status'] == 'absent') {
        return _invalid(raw, 'Ticket is already closed.');
      }
      if (m['checkedIn'] == true) return const FacilityScanResult(
        FacilityScanOutcome.repeated, 'Ticket already checked in.');
      await _ticket(ticketId).update({'checkedIn': true});
      await _log('Ticket check-in', ticketId, FacilityScanOutcome.verified);
      return FacilityScanResult(FacilityScanOutcome.verified,
        'Ticket checked in: ${m['citizenName']} — #$ticketId');
    } catch (e) {
      return _invalid(raw, 'Unable to validate ticket: ${e.toString()}');
    }
  }

  FacilityScanResult _invalid(String raw, String reason) {
    _log('Invalid ticket', raw, FacilityScanOutcome.invalid);
    return FacilityScanResult(FacilityScanOutcome.invalid, reason);
  }
}
