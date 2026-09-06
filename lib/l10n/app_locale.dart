import 'package:flutter/widgets.dart';

import 'ui_strings.dart';
import 'ui_strings_generated.dart';
import 'ui_strings_more.dart';

class AppLocale extends InheritedWidget {
  const AppLocale({super.key, required this.languageCode, required super.child});

  final String languageCode;

  static String of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLocale>()?.languageCode ??
        'en';
  }

  @override
  bool updateShouldNotify(AppLocale oldWidget) =>
      languageCode != oldWidget.languageCode;
}

/// Looks up a UI string. [english] is both the key and the English fallback.
String tr(BuildContext context, String english) {
  final code = AppLocale.of(context);
  if (code == 'en') return english;
  // Curated tables first, machine-generated last: a reviewed translation must
  // always outrank the 0.8B batch output for the same key.
  return kUiStrings[code]?[english] ??
      kUiStringsMore[code]?[english] ??
      kUiStringsGenerated[code]?[english] ??
      english;
}

/// True when [english] has a real entry for [code], i.e. `tr` would return a
/// translation rather than silently handing back the English.
///
/// Lets callers tell "already localized" apart from "fell through to English"
/// and send only the latter to the translation model.
bool hasUiString(String code, String english) {
  if (code == 'en') return true;
  return kUiStrings[code]?[english] != null ||
      kUiStringsMore[code]?[english] != null ||
      kUiStringsGenerated[code]?[english] != null;
}

String trFill(BuildContext context, String english, Map<String, String> vars) {
  var out = tr(context, english);
  vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}
