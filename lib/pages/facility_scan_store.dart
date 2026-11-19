import '../services/queue_operations_service.dart';
import '../services/booking_order.dart';
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
  final String queueId;
  final int estimatedMinutes;
  FacilityVisitStatus status;
  bool checkedIn;
  int postponements;

  FacilityVisit({
    required this.ticketNumber,
    required this.visitorName,
    required this.maskedId,
    required this.windowNumber,
    required this.queueId,
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
          ..addAll((snap.docs.toList()..sort((a,b) => compareBookingRows(a.data(),a.id,b.data(),b.id))).map((d) {
            final m = d.data();
            final status = FacilityVisitStatus.values.firstWhere(
              (v) => v.name == m['status'], orElse: () => FacilityVisitStatus.waiting);
            return FacilityVisit(
              ticketNumber: d.id,
              visitorName: m['citizenName'] as String? ?? '',
              maskedId: '••••',
              windowNumber: m['routingVersion'] == 2 ? (m['windowNumber'] as num?)?.toInt() ?? 0 : 1,
              queueId: m['queueId'] as String? ?? '',
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

  FacilityVisit? currentFor(int n, {int window = 0}) {
    for (final v in _visits) {
      if (v.queueId == 'window_$n' && v.windowNumber == window && v.status == FacilityVisitStatus.called) return v;
    }
    return null;
  }

  int waitingCount(int n) => _visits.where((v) => v.queueId == 'window_$n' && v.status == FacilityVisitStatus.waiting).length;

  Future<String> callNext(int n, {int window = 0}) async {
    final message = await QueueOperationsService.instance.callNext(_facilityId!, 'window_$n', window);
    return message;
  }

  Future<String> markAbsent(int n, {int window = 0}) => _closeCurrent(n, window, 'absent');
  Future<String> markServed(int n, {int window = 0}) => _closeCurrent(n, window, 'served');
  Future<String> _closeCurrent(int n, int window, String outcome) async {
    final v = currentFor(n, window: window);
    if (v == null) return 'Call a visitor first.';
    await QueueOperationsService.instance.close(v.ticketNumber, _facilityId!, outcome);
    return 'Ticket marked $outcome.';
  }
  Future<String> postponeCurrent(int n, {int window = 0}) async {
    final v = currentFor(n, window: window);
    if (v == null) return 'Call a visitor first.';
    if (waitingCount(n) == 0) return 'No other visitors are waiting.';
    await QueueOperationsService.instance.postpone(v.ticketNumber, _facilityId!, 'window_$n', window);
    return 'Ticket postponed.';
  }

  Future<FacilityScanResult> verifyDemoCode(String raw, int queueNumber, {int window = 0}) async {
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
          m['queueId'] != 'window_$queueNumber') {
        return _invalid(raw, 'Ticket is not valid for this counter.');
      }
      if (m['status'] == 'served' || m['status'] == 'absent') {
        return _invalid(raw, 'Ticket is already closed.');
      }
      if (m['checkedIn'] == true) return const FacilityScanResult(
        FacilityScanOutcome.repeated, 'Ticket already checked in.');
      await QueueOperationsService.instance.checkIn(ticketId, id, 'window_$queueNumber', window);
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
