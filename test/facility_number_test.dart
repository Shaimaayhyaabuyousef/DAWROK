import 'package:first_project/services/facility_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staff can enter or paste facility numbers in local digit scripts', () {
    for (final input in ['100024', ' ١٠٠٠٢٤ ', '۱۰۰۰۲۴']) {
      expect(validFacilityNumber(input), isTrue);
      expect(normalizeFacilityNumber(input), '100024');
    }
    for (final input in ['', '010024', '10002', '1000024', 'AB1024']) {
      expect(validFacilityNumber(input), isFalse);
    }
  });
}
