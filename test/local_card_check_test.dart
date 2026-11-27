import 'package:first_project/services/local_card_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fields = [
    (text: 'السلطة الوطنية الفلسطينية', y: 0.1),
    (text: 'بطاقة هوية', y: 0.2),
    (text: 'الاسم الشخصي', y: 0.5),
    (text: 'تاريخ الميلاد', y: 0.7),
  ];
  const expected = '123456789';
  test('recognizes the front layout and one matching number', () {
    for (final number in [expected, '١٢٣٤٥٦٧٨٩', '۱۲۳ ۴۵۶ ۷۸۹']) {
      expect(
        assessCard(1.6, [...fields, (text: number, y: 0.4)], expected),
        CardCheck.match,
      );
    }
  });
  test('rejects another number and ambiguous or missing digits', () {
    expect(
      assessCard(1.6, [...fields, (text: '123456788', y: 0.4)], expected),
      CardCheck.different,
    );
    expect(assessCard(1.6, fields, expected), CardCheck.unreadable);
    expect(
      assessCard(1.6, [
        ...fields,
        (text: expected, y: 0.4),
        (text: '123456788', y: 0.8),
      ], expected),
      CardCheck.unreadable,
    );
  });
  test('matching digits alone, misplaced header and portrait photos fail', () {
    const number = (text: expected, y: 0.4);
    expect(assessCard(1.6, [number], expected), CardCheck.layout);
    expect(
      assessCard(1.6, [
        ...fields.skip(1),
        (text: fields.first.text, y: 0.9),
        number,
      ], expected),
      CardCheck.layout,
    );
    expect(assessCard(0.6, [...fields, number], expected), CardCheck.layout);
  });
}
