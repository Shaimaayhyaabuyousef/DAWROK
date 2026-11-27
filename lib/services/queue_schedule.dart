import 'facility_time.dart';

/// Shared local-time slot generation and UTC persistence keys.
class QueueSchedule {
  static String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static String dayKey(DateTime time) {
    final utc = FacilityTime.wall(time);
    return '${utc.year}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}';
  }

  /// Assign by the queue's reservation counter, never by a citizen-selected time.
  /// Capacity is spread over the existing 30-minute arrival windows. Windows
  /// that have elapsed are skipped; the appointment remains an estimate.
  static DateTime? nextBooking({
    required int start,
    required int end,
    required int capacity,
    required int reserved,
    required DateTime now,
  }) {
    if (capacity < 1 || reserved < 0) return null;
    final firstMinute = ((start + 29) ~/ 30) * 30;
    final windowCount = (end - firstMinute) ~/ 30;
    if (start < 0 || end > 1440 || windowCount < 1) return null;
    final remaining = availableSlots(start, end, now);
    if (remaining.isEmpty) return null;
    final windows = _windows(start, end, now);
    final perWindow = (capacity + windowCount - 1) ~/ windowCount;
    final index = (reserved ~/ perWindow).clamp(0, windows.length - 1);
    final planned = windows[index];
    return planned.isAfter(remaining.first) ? planned : remaining.first;
  }

  static List<DateTime> availableSlots(int start, int end, DateTime now) {
    if (start < 0 || end > 1440 || start >= end) return [];
    return _windows(start, end, now).where((t) => t.isAfter(now)).toList();
  }

  static List<DateTime> _windows(int start, int end, DateTime now) {
    final wall = FacilityTime.wall(now);
    final midnight = DateTime.utc(wall.year, wall.month, wall.day);
    final slots = <DateTime>[];
    // Iterate absolute instants so skipped/repeated wall hours follow the zone.
    for (int m = -180; m < 1440 - 120; m += 30) {
      final instant = midnight.add(Duration(minutes: m));
      final local = FacilityTime.wall(instant);
      final minute = local.hour * 60 + local.minute;
      if (local.day == wall.day && minute >= start && minute + 30 <= end)
        slots.add(instant);
    }
    return slots;
  }
}
