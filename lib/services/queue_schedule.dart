/// Shared local-time slot generation and UTC persistence keys.
class QueueSchedule {
  static String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static String dayKey(DateTime time) {
    final utc = time.toUtc();
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
    final day = dayKey(remaining.first);
    final windows = <DateTime>[
      for (var i = 0; i < windowCount; i++)
        DateTime(now.year, now.month, now.day, 0, firstMinute + i * 30),
    ].where((time) => dayKey(time) == day).toList();
    final perWindow = (capacity + windowCount - 1) ~/ windowCount;
    final index = (reserved ~/ perWindow).clamp(0, windows.length - 1);
    final planned = windows[index];
    return planned.isAfter(remaining.first) ? planned : remaining.first;
  }

  static List<DateTime> availableSlots(int start, int end, DateTime now) {
    if (start < 0 || end > 1440 || start >= end) return [];
    final slots = <DateTime>[];
    for (
      var minute = ((start + 29) ~/ 30) * 30;
      minute + 30 <= end;
      minute += 30
    ) {
      final time = DateTime(
        now.year,
        now.month,
        now.day,
        minute ~/ 60,
        minute % 60,
      );
      if (time.isAfter(now)) slots.add(time);
    }
    return slots;
  }
}
