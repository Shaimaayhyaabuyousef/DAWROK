import 'package:first_project/pages/facility_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('facility QR round trip and older codes', () {
    expect(facilityIdFromQr(facilityQrPayload('abc123')), 'abc123');
    expect(facilityIdFromQr('dawrok://facility/abc123/check-in?demoSession=1'), 'abc123');
    expect(facilityIdFromQr('DAWROK|ticket=1|facility=x|queue=y'), isNull);
    expect(facilityIdFromQr('https://example.com/facility/abc'), isNull);
    expect(facilityIdFromQr('dawrok://facility/'), isNull);
  });
}
