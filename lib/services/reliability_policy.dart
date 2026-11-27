/// Results are scored in the order in which authorized staff close tickets.
class ReliabilityPolicy {
  static const rewardCost = 100;
  static const suspension = Duration(days: 7);
  final int points, streak;
  final DateTime? suspendedAt;
  final bool reviewRequired;
  const ReliabilityPolicy({
    this.points = 0,
    this.streak = 0,
    this.suspendedAt,
    this.reviewRequired = false,
  });
  DateTime? get blockedUntil => suspendedAt?.add(suspension);
  bool blocked(DateTime now) =>
      reviewRequired || (blockedUntil != null && now.isBefore(blockedUntil!));
  ReliabilityPolicy close(String outcome, DateTime now) {
    if (!['served', 'absent'].contains(outcome))
      throw ArgumentError.value(outcome);
    final absent = outcome == 'absent';
    final firstBan = absent && suspendedAt == null && streak + 1 >= 3;
    return ReliabilityPolicy(
      points: points + (absent ? -5 : 5),
      streak: !absent || firstBan ? 0 : streak + 1,
      suspendedAt: firstBan ? now : suspendedAt,
      reviewRequired:
          reviewRequired ||
          (absent && suspendedAt != null && !now.isBefore(blockedUntil!)),
    );
  }
}
