/// Palestinian ID numbers are nine digits whose last digit is a check digit
/// (the same weighted 1-2 scheme used by the Population Registry).
bool validNationalId(String id) {
  if (!RegExp(r'^\d{9}$').hasMatch(id)) return false;
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    var d = (id.codeUnitAt(i) - 48) * (i.isEven ? 1 : 2);
    if (d > 9) d -= 9;
    sum += d;
  }
  return sum % 10 == 0;
}
