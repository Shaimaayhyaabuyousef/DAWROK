import 'package:first_project/l10n/app_language.dart';
import 'package:first_project/services/national_id.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppLanguage.locale.value = const Locale('en'));

  test('English keeps the source text', () {
    expect(tr('Scan card'), 'Scan card');
    expect(tr('Window 3'), 'Window 3');
  });

  test('Arabic translates exact and value strings', () {
    AppLanguage.locale.value = const Locale('ar');
    expect(tr('Scan card'), 'مسح البطاقة');
    expect(tr('Window 3'), 'الشباك 3');
    expect(tr('Go to window 2 now.'), 'توجّه إلى الشباك 2 الآن.');
    expect(tr('10:30 AM'), '10:30 ص');
    expect(tr('Good morning, Sara'), 'صباح الخير، Sara');
    expect(tr('A facility name'), 'A facility name');
  });

  test('national ID check digit', () {
    expect(validNationalId('000000018'), isTrue);
    expect(validNationalId('407830363'), isTrue);
    expect(validNationalId('123456789'), isFalse);
    expect(validNationalId('12345678'), isFalse);
  });
}
