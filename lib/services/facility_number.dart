String normalizeFacilityNumber(String input) => input.trim().replaceAllMapped(
  RegExp('[٠-٩۰-۹]'),
  (match) {
    final digit = match[0]!.codeUnitAt(0);
    return (digit - (digit >= 0x06F0 ? 0x06F0 : 0x0660)).toString();
  },
);

bool validFacilityNumber(String input) =>
    RegExp(r'^[1-9][0-9]{5}$').hasMatch(normalizeFacilityNumber(input));
