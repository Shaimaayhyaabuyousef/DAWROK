import 'package:flutter/foundation.dart';
import 'facility_queue_store.dart';

/// Local-only sample data for prototyping the facility's counter operations.
/// It is deliberately NOT an authentication or QR verification service.
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

/// The facility owner can use this store directly; it does not depend on
/// FacilityStaffStore or on the number of employee accounts.
class FacilityScanStore extends ChangeNotifier {
  FacilityScanStore._();
  static final FacilityScanStore instance = FacilityScanStore._();

  final List<FacilityVisit> _visits = [
    FacilityVisit(ticketNumber: 'A-104', visitorName: 'Khalid Abdullah Al-Omari', maskedId: 'SA-49102', windowNumber: 2, estimatedMinutes: 8),
    FacilityVisit(ticketNumber: 'A-105', visitorName: 'Fatima Salem Al-Dawsari', maskedId: 'SA-38291', windowNumber: 2, estimatedMinutes: 15),
    FacilityVisit(ticketNumber: 'A-106', visitorName: 'Mohammad Tariq Hassan', maskedId: 'SA-58190', windowNumber: 2, estimatedMinutes: 22),
    FacilityVisit(ticketNumber: 'A-108', visitorName: 'Nour El-Din Mansoor', maskedId: 'SA-58191', windowNumber: 2, estimatedMinutes: 30),
    FacilityVisit(ticketNumber: 'B-201', visitorName: 'Hana Ali', maskedId: 'SA-10001', windowNumber: 1, estimatedMinutes: 10),
  ];

  final List<FacilityScanLog> _logs = [
    FacilityScanLog(label: 'Visitor card', identifier: '8492-X', outcome: FacilityScanOutcome.verified, createdAt: DateTime.now()),
    FacilityScanLog(label: 'Visitor card', identifier: '1104-V', outcome: FacilityScanOutcome.verified, createdAt: DateTime.now()),
    FacilityScanLog(label: 'Invalid code', identifier: '9921-E', outcome: FacilityScanOutcome.invalid, createdAt: DateTime.now()),
  ];

  List<FacilityVisit> get visits => List.unmodifiable(_visits);
  List<FacilityScanLog> get logs => List.unmodifiable(_logs);

  FacilityVisit? currentFor(int windowNumber) {
    for (final visit in _visits) {
      if (visit.windowNumber == windowNumber && visit.status == FacilityVisitStatus.called) return visit;
    }
    return null;
  }

  int waitingCount(int windowNumber) => _visits.where((v) => v.windowNumber == windowNumber && v.status == FacilityVisitStatus.waiting).length;

  String callNext(int windowNumber) {
    if (currentFor(windowNumber) != null) return 'Finish or mark the current ticket absent first.';
    for (final visit in _visits) {
      if (visit.windowNumber == windowNumber && visit.status == FacilityVisitStatus.waiting) {
        visit.status = FacilityVisitStatus.called;
        notifyListeners();
        return 'Calling ticket #${visit.ticketNumber} — ${visit.visitorName}';
      }
    }
    return 'There are no waiting tickets for this counter.';
  }

  String markAbsent(int windowNumber) {
    final current = currentFor(windowNumber);
    if (current == null) return 'Call a visitor first.';
    current.status = FacilityVisitStatus.absent;
    FacilityQueueStore.instance.recordHandled(windowNumber);
    notifyListeners();
    return 'Ticket #${current.ticketNumber} marked absent.';
  }

  /// Moves the currently called ticket to the end of THIS counter's waiting
  /// line. The booking stays active and the total number of visitors does not
  /// change. Call Next afterward to call the next waiting visitor.
  String postponeCurrent(int windowNumber) {
    final current = currentFor(windowNumber);
    if (current == null) return 'Call a visitor first.';

    final someoneElseWaiting = _visits.any((visit) =>
        visit.windowNumber == windowNumber &&
        visit.status == FacilityVisitStatus.waiting);
    if (!someoneElseWaiting) {
      return 'No other visitors are waiting in this counter.';
    }

    current.status = FacilityVisitStatus.waiting;
    current.postponements++;
    // Preserve checkedIn: postponing does not invalidate a verified check-in.
    // Reorder the shared list: callNext scans it from the beginning.
    _visits.remove(current);
    _visits.add(current);
    notifyListeners();
    return 'Ticket #${current.ticketNumber} postponed to the end of the queue. Tap Next to call the next visitor.';
  }

  String markServed(int windowNumber) {
    final current = currentFor(windowNumber);
    if (current == null) return 'Call a visitor first.';
    if (!current.checkedIn) return 'Verify the ticket QR or enter the ticket number before completing service.';
    current.status = FacilityVisitStatus.served;
    FacilityQueueStore.instance.recordHandled(windowNumber);
    notifyListeners();
    return 'Service completed for #${current.ticketNumber}.';
  }

  /// Accepts either a bare ticket number (A-104) or a demo citizen ticket
  /// payload, e.g. DAWROK|ticket=A-104|facility=...|queue=...
  /// Never treats a client-provided QR string as trustworthy authentication.
  FacilityScanResult verifyDemoCode(String rawValue, int windowNumber) {
    final raw = rawValue.trim();
    String ticket = raw;
    if (raw.startsWith('DAWROK|')) {
      final parts = raw.split('|');
      final matches = parts.skip(1).where((part) => part.startsWith('ticket=')).toList();
      if (matches.length != 1) {
        return _invalid(raw, 'Invalid ticket format.');
      }
      ticket = matches.single.substring('ticket='.length).trim();
    }
    final candidate = ticket.toUpperCase();
    FacilityVisit? found;
    for (final visit in _visits) {
      if (visit.ticketNumber.toUpperCase() == candidate) {
        found = visit;
        break;
      }
    }
    if (found == null) return _invalid(raw, 'Ticket not found in the local demo data.');
    if (found.windowNumber != windowNumber) return _invalid(raw, 'Ticket belongs to another counter.');
    if (found.status == FacilityVisitStatus.served || found.status == FacilityVisitStatus.absent) {
      return _invalid(raw, 'This ticket is already closed.');
    }
    if (found.checkedIn) return const FacilityScanResult(FacilityScanOutcome.repeated, 'Ticket already checked in.');

    found.checkedIn = true;
    _addLog('Visitor card', found.maskedId, FacilityScanOutcome.verified);
    notifyListeners();
    return FacilityScanResult(FacilityScanOutcome.verified, 'Verified (demo): ${found.visitorName} — #${found.ticketNumber}');
  }

  FacilityScanResult _invalid(String raw, String reason) {
    final compact = raw.isEmpty ? 'empty' : (raw.length > 12 ? raw.substring(0, 12) : raw);
    _addLog('Invalid code', compact, FacilityScanOutcome.invalid);
    notifyListeners();
    return FacilityScanResult(FacilityScanOutcome.invalid, reason);
  }

  void _addLog(String label, String id, FacilityScanOutcome outcome) {
    _logs.insert(0, FacilityScanLog(label: label, identifier: id, outcome: outcome, createdAt: DateTime.now()));
    if (_logs.length > 20) _logs.removeLast();
  }
}
