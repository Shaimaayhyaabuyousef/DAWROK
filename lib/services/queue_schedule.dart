/// Shared local-time slot generation and UTC persistence keys.
class QueueSchedule {
  static String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static String dayKey(DateTime time) {
    final utc = time.toUtc();
    return '${utc.year}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}';
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
