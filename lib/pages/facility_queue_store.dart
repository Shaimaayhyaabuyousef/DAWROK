import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Demo-only state. Connect this service to a server to make changes shared
/// between the facility staff and citizen applications.
enum FacilityQueueShift { morning, evening }

class FacilityQueue {
  final int windowNumber;
  final String service;
  final String counter;
  final int capacity;
  final int beneficiaries;
  final int waitingMinutes;
  final FacilityQueueShift shift;
  final TimeOfDay startsAt;
  final TimeOfDay endsAt;
  final bool isActive;

  const FacilityQueue({
    required this.windowNumber,
    required this.service,
    required this.counter,
    required this.capacity,
    required this.beneficiaries,
    required this.waitingMinutes,
    required this.shift,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  FacilityQueue copyWith({
    String? service,
    String? counter,
    int? capacity,
    int? beneficiaries,
    int? waitingMinutes,
    FacilityQueueShift? shift,
    TimeOfDay? startsAt,
    TimeOfDay? endsAt,
    bool? isActive,
  }) {
    return FacilityQueue(
      windowNumber: windowNumber,
      service: service ?? this.service,
      counter: counter ?? this.counter,
      capacity: capacity ?? this.capacity,
      beneficiaries: beneficiaries ?? this.beneficiaries,
      waitingMinutes: waitingMinutes ?? this.waitingMinutes,
      shift: shift ?? this.shift,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class FacilityQueueDraft {
  final String service;
  final int capacity;
  final int waitingMinutes;
  final FacilityQueueShift shift;
  final TimeOfDay startsAt;
  final TimeOfDay endsAt;

  const FacilityQueueDraft({
    required this.service,
    required this.capacity,
    required this.waitingMinutes,
    required this.shift,
    required this.startsAt,
    required this.endsAt,
  });
}

String facilityTimeText(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${hour.toString().padLeft(2, '0')}:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

int facilityTimeInMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

class FacilityQueueStore extends ChangeNotifier {
  FacilityQueueStore._();

  static final FacilityQueueStore instance = FacilityQueueStore._();

  // Two sample queues from the design. The summary is calculated from these
  // records, not hard-coded. Newly created queues start with 0 beneficiaries.
  final List<FacilityQueue> _queues = [
    const FacilityQueue(
      windowNumber: 2,
      service: 'General Service',
      counter: 'A',
      capacity: 50,
      beneficiaries: 42,
      waitingMinutes: 12,
      shift: FacilityQueueShift.morning,
      startsAt: TimeOfDay(hour: 8, minute: 0),
      endsAt: TimeOfDay(hour: 13, minute: 30),
      isActive: true,
    ),
    const FacilityQueue(
      windowNumber: 1,
      service: 'Appointments',
      counter: 'A',
      capacity: 50,
      beneficiaries: 36,
      waitingMinutes: 10,
      shift: FacilityQueueShift.evening,
      startsAt: TimeOfDay(hour: 14, minute: 0),
      endsAt: TimeOfDay(hour: 19, minute: 0),
      isActive: false,
    ),
  ];

  int _nextWindowNumber = 3;

  List<FacilityQueue> get queues => List.unmodifiable(_queues);

  int get totalQueues => _queues.length;
  int get totalWaiting => _queues.fold(0, (sum, q) => sum + q.beneficiaries);
  int get averageWaitMinutes => _queues.isEmpty
      ? 0
      : (_queues.fold(0, (sum, q) => sum + q.waitingMinutes) / _queues.length).round();

  void create(FacilityQueueDraft draft) {
    final nextNumber = _nextWindowNumber++;

    _queues.insert(0, FacilityQueue(
      windowNumber: nextNumber,
      service: draft.service,
      counter: 'A',
      capacity: draft.capacity,
      beneficiaries: 0,
      waitingMinutes: draft.waitingMinutes,
      shift: draft.shift,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
      isActive: true,
    ));
    notifyListeners();
  }

  void update(int windowNumber, FacilityQueueDraft draft) {
    final index = _queues.indexWhere((q) => q.windowNumber == windowNumber);
    if (index == -1) return;
    _queues[index] = _queues[index].copyWith(
      service: draft.service,
      capacity: draft.capacity,
      waitingMinutes: draft.waitingMinutes,
      shift: draft.shift,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
    );
    notifyListeners();
  }

  void setActive(int windowNumber, bool active) {
    final index = _queues.indexWhere((q) => q.windowNumber == windowNumber);
    if (index == -1) return;
    _queues[index] = _queues[index].copyWith(isActive: active);
    notifyListeners();
  }


void recordHandled(int windowNumber) {
  final index = _queues.indexWhere(
    (queue) => queue.windowNumber == windowNumber,
  );

  if (index == -1) return;

  final current = _queues[index];

  if (current.beneficiaries <= 0) return;

  _queues[index] = current.copyWith(
    beneficiaries: current.beneficiaries - 1,
  );

  notifyListeners();
}

  void delete(int windowNumber) {
    _queues.removeWhere((q) => q.windowNumber == windowNumber);
    notifyListeners();
  }
}
