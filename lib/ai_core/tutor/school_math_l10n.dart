import 'school_math.dart';

/// Nouns / method names that stay in English inside a local-language step.
const kMathEnglishTerms = <String>[
  'PEMDAS',
  'BODMAS',
  'fraction',
  'numerator',
  'denominator',
  'percent',
  'percentage',
  'equation',
  'perimeter',
  'area',
  'rectangle',
  'formula',
];

final _termPattern = RegExp(
  '\\b(${kMathEnglishTerms.map(RegExp.escape).join('|')})\\b',
  caseSensitive: false,
);

/// Numbers, fractions, and the variable `x` stay in English.
final _constPattern = RegExp(
  r"\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)?|\bx\b",
);

class ProtectedProse {
  const ProtectedProse(this.text, this.slots);

  final String text;
  final List<String> slots;

  String restore(String translated) {
    var out = translated;
    for (var i = 0; i < slots.length; i++) {
      out = out.replaceAll('⟦$i⟧', slots[i]);
      out = out.replaceAll('[[$i]]', slots[i]);
    }
    return out;
  }
}

/// Pin terms, constants, and names so AfriSLM cannot rewrite them.
ProtectedProse protectMathProse(String english) {
  final slots = <String>[];
  var text = english.replaceAllMapped(_constPattern, (m) {
    final i = slots.length;
    slots.add(m.group(0)!);
    return '⟦$i⟧';
  });
  text = text.replaceAllMapped(_termPattern, (m) {
    final i = slots.length;
    slots.add(m.group(0)!);
    return '⟦$i⟧';
  });
  return ProtectedProse(text, slots);
}

/// Translate step titles and "why" lines. Formulas, calculations, and the
/// numeric [SchoolMathSolution.answer] are never sent to the translator.
Future<SchoolMathSolution> localizeSchoolMath(
  SchoolMathSolution math, {
  required Future<String> Function(String english) translate,
}) async {
  final cache = <String, String>{};

  Future<String> one(String english) async {
    final trimmed = english.trim();
    if (trimmed.isEmpty) return english;
    final hit = cache[trimmed];
    if (hit != null) return hit;
    final protected = protectMathProse(trimmed);
    final raw = (await translate(protected.text)).trim();
    final out = raw.isEmpty ? trimmed : protected.restore(raw);
    cache[trimmed] = out;
    return out;
  }

  final steps = <MathStep>[];
  for (final step in math.steps) {
    steps.add(step.copyWith(
      title: await one(step.title),
      why: await one(step.why),
    ));
  }

  return math.copyWith(
    steps: steps,
    hint: await one(math.hint),
    practiceQuestion: math.practiceQuestion,
  );
}
