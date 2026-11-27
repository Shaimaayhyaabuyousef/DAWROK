import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:first_project/services/reliability_policy.dart';
import 'package:first_project/services/booking_order.dart';

void main() {
  test('a paid swap preserves other positions and cancelling restores the original order', () {
    final target = {
      'queuePosition': 1,
      'dispatchPosition': 3,
      'priorityBuyer': 'buyer',
    };
    final other = {'queuePosition': 2};
    final buyer = {
      'queuePosition': 3,
      'dispatchPosition': 1,
      'priorityTarget': 'target',
      'reward': 'priority',
    };
    expect(compareBookingRows(buyer, 'buyer', other, 'other'), lessThan(0));
    expect(
      compareBookingRows(target, 'target', other, 'other'),
      greaterThan(0),
    );
    expect(
      compareBookingRows(
        target,
        'target',
        other,
        'other',
        cancelled: {'buyer'},
      ),
      lessThan(0),
    );
  });
  test(
    'attendance resets consecutive misses; third miss bans for seven days',
    () {
      final now = DateTime.utc(2026, 11, 17);
      var a = const ReliabilityPolicy();
      a = a.close('absent', now).close('absent', now).close('served', now);
      expect(a.streak, 0);
      expect(a.points, -5);
      for (var i = 0; i < 3; i++) {
        a = a.close('absent', now);
      }
      expect(a.points, -20);
      expect(a.blocked(now.add(const Duration(days: 6))), isTrue);
      expect(a.blocked(now.add(const Duration(days: 7))), isFalse);
      a = a
          .close('served', now.add(const Duration(days: 8)))
          .close('absent', now.add(const Duration(days: 9)));
      expect(a.reviewRequired, isTrue);
      expect(a.blocked(now.add(const Duration(days: 90))), isTrue);
    },
  );
  test(
    'priority never precedes earlier slot; creation time and id break ties',
    () {
      final time = Timestamp.fromDate(DateTime.utc(2026, 11, 17, 9));
      final later = Timestamp.fromDate(DateTime.utc(2026, 11, 17, 10));
      final normal = {'slotStart': time, 'createdAt': time, 'reward': 'none'};
      final priority = {...normal, 'reward': 'priority'};
      expect(
        compareBookingRows(normal, 'a', {...priority, 'slotStart': later}, 'b'),
        lessThan(0),
      );
      expect(compareBookingRows(priority, 'b', normal, 'a'), lessThan(0));
      expect(compareBookingRows(normal, 'a', normal, 'b'), lessThan(0));
    },
  );
}
