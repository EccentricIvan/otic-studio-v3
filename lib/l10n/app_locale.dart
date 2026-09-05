import 'package:flutter/widgets.dart';

import 'ui_strings.dart';
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
  return kUiStrings[code]?[english] ??
      kUiStringsMore[code]?[english] ??
      english;
}

String trFill(BuildContext context, String english, Map<String, String> vars) {
  var out = tr(context, english);
  vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}
