import 'dart:typed_data';

import 'package:flutter/services.dart';

String cardDigits(String value) => value.replaceAllMapped(
  RegExp('[٠-٩۰-۹]'),
  (match) => ((match[0]!.codeUnitAt(0) & 15)).toString(),
);

String _words(String text) => text
    .replaceAll(RegExp('[ً-ْـ]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه');

enum CardCheck { match, layout, unreadable, different }

/// A visual consistency check, not proof of issuance or ownership.
CardCheck assessCard(
  double aspect,
  List<({String text, double y})> lines,
  String expected,
) {
  if (aspect < 1.15 || aspect > 2.35) return CardCheck.layout;
  final header = _words(
    lines.where((l) => l.y < 0.48).map((l) => l.text).join(' '),
  );
  final issuer = RegExp('فلسطين|פלסטינ|פלשתינ').hasMatch(header);
  final title = RegExp('بطاقه\\s+(?:ال)?هويه|תעודת\\s+זהות').hasMatch(header);
  final fieldRows =
      lines
          .where(
            (l) =>
                l.y > 0.25 &&
                RegExp(
                  'الاسم|اسم |العائله|الميلاد|الولاده|الجنس|الديانه|שם |לידה|משפחה',
                ).hasMatch(_words(l.text)),
          )
          .map((l) => l.y)
          .toList()
        ..sort();
  if (!issuer ||
      !title ||
      fieldRows.length < 2 ||
      fieldRows.last - fieldRows.first < 0.04) {
    return CardCheck.layout;
  }
  // Look at each printed line separately. Never concatenate dates or fields
  // from separate lines to manufacture a matching number.
  final numbers = <String>{};
  for (final line in lines) {
    final text = cardDigits(line.text).replaceAll(RegExp('[\u200e\u200f]'), '');
    for (final m in RegExp(r'[0-9]+(?:[ \t-]+[0-9]+)*').allMatches(text)) {
      final digits = m[0]!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 9) numbers.add(digits);
    }
  }
  if (numbers.length != 1 || !RegExp(r'^\d{9}$').hasMatch(expected))
    return CardCheck.unreadable;
  return numbers.single == expected ? CardCheck.match : CardCheck.different;
}

Future<CardCheck> readLocalCard(Uint8List image, String expected) async {
  final data = await const MethodChannel('dawrok/id_reader')
      .invokeMapMethod<String, dynamic>('read', image);
  if (data == null) return CardCheck.unreadable;
  final lines = (data['lines'] as List)
      .whereType<Map>()
      .map((l) => (text: l['text'] as String, y: (l['y'] as num).toDouble()))
      .toList();
  return assessCard((data['aspect'] as num).toDouble(), lines, expected);
}
