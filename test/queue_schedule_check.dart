// Standalone regression check: dart test/queue_schedule_check.dart
import '../lib/services/queue_schedule.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final now = DateTime(2026, 11, 15, 10, 15);
  final slots = QueueSchedule.availableSlots(480, 720, now);
  check(slots.length == 3, 'Only 10:30, 11:00 and 11:30 remain');
  check(slots.first == DateTime(2026, 11, 15, 10, 30), 'Next future slot');
  check(QueueSchedule.availableSlots(480, 600, now).isEmpty, 'Closed queue');
  check(QueueSchedule.availableSlots(720, 480, now).isEmpty, 'Invalid hours');
  check(
    QueueSchedule.availableSlots(600, 620, now).isEmpty,
    'No complete slot',
  );
  check(
    QueueSchedule.availableSlots(615, 690, DateTime(2026, 11, 15, 9)).length ==
        2,
    'Round opening time up to half hour',
  );
  check(
    QueueSchedule.dayKey(DateTime.parse('2026-11-15T00:30:00+02:00')) ==
        '20261114',
    'Day keys must match Firestore UTC timestamps',
  );
  check(QueueSchedule.clock(1440) == '24:00', 'Closing at midnight');
  print('Queue schedule regression checks passed.');
}
