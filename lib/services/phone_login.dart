/// Canonical login number. Ownership is not verified by SMS in this app.
String? localMobile(String? input) {
  final digits = (input ?? '')
      .replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
        final code = m[0]!.codeUnitAt(0);
        return (code - (code >= 0x6f0 ? 0x6f0 : 0x660)).toString();
      })
      .replaceAll(RegExp(r'[\s()-]'), '');
  final match = RegExp(r'^(?:0|\+970|00970|970)?(5[69][0-9]{7})$')
      .firstMatch(digits);
  return match == null ? null : '0${match[1]}';
}

String? validateMobile(String? value) => localMobile(value) == null
    ? 'Enter a valid 059 or 056 mobile number.'
    : null;

String mobileLoginId(String phone) {
  final local = localMobile(phone);
  if (local == null) throw const FormatException('Invalid mobile number.');
  return 'p970${local.substring(1)}@login.dawrok.invalid';
}
