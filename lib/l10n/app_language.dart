import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ar.dart';

/// The app language. English is the source language: every UI string in the
/// code is written in English and passed through [tr]. Arabic switches the
/// whole app to right-to-left through MaterialApp's locale.
class AppLanguage {
  AppLanguage._();

  static const _key = 'dawrok_language';
  static const supported = [Locale('en'), Locale('ar')];

  static final locale = ValueNotifier<Locale>(const Locale('en'));

  static bool get isArabic => locale.value.languageCode == 'ar';

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code == 'ar' || code == 'en') locale.value = Locale(code!);
    } catch (_) {
      // Keep English if local preferences are unavailable.
    }
  }

  static Future<void> set(String code) async {
    if (code != 'ar' && code != 'en') return;
    locale.value = Locale(code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, code);
    } catch (_) {}
  }
}

final Map<String, String> _cache = {};
final List<(RegExp, String)> _patterns = [
  for (final e in arabicPatterns.entries) (RegExp('^${e.key}\$'), e.value),
];

/// Translates an English UI string for the current language.
///
/// Exact strings come from [arabicStrings]. Strings built with values (for
/// example 'Window 3') are matched by [arabicPatterns], whose `$1`, `$2`
/// placeholders receive the captured values. Unknown text stays in English.
String tr(String text) {
  if (!AppLanguage.isArabic || text.isEmpty) return text;
  final exact = arabicStrings[text];
  if (exact != null) return exact;
  final cached = _cache[text];
  if (cached != null) return cached;
  var result = text;
  for (final (re, template) in _patterns) {
    final m = re.firstMatch(text);
    if (m == null) continue;
    result = template.replaceAllMapped(RegExp(r'\$(\d)'), (g) {
      final value = m.group(int.parse(g[1]!)) ?? '';
      return arabicStrings[value] ?? value;
    });
    break;
  }
  if (_cache.length < 2000) _cache[text] = result;
  return result;
}

/// [tr] for optional texts such as hints, labels and tooltips.
String? trOpt(String? text) => text == null ? null : tr(text);
