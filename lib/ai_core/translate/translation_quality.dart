/// Output validation for AfriSLM translations.
///
/// TranslatePsy-AfriSLM is 0.8B and 4-bit quantized. Near its trained
/// distribution it is good; pushed off it — a long input, an unusual
/// language name, a prompt shape it never saw — it does not fail loudly. It
/// invents. The observed failure modes are all here, and every one of them
/// used to reach the student as if it were a real translation:
///
///   * echoes the instruction back ("Please translate the following…")
///   * prefixes commentary ("Here is the translation:", "Sure!")
///   * returns the English input unchanged
///   * loops a phrase until it hits the token budget
///
/// These are pure functions over strings so they can be tested exhaustively
/// without a model — see test/translation_quality_test.dart.
library;

import 'supported_languages.dart';

/// Why a candidate translation was refused.
enum TranslationRejection {
  /// Nothing left after stripping thinking spans and scaffolding.
  empty,

  /// Output is the input again — the model did not translate.
  unchanged,

  /// Output carries the prompt's own instruction text.
  echoedPrompt,

  /// A phrase repeats far past anything natural — decoder loop.
  repetitionLoop,

  /// Output is wildly longer than the input could justify.
  lengthBlowup,

  /// Target is a non-English language but the output still reads English.
  stillEnglish,
}

extension TranslationRejectionLabel on TranslationRejection {
  String get label {
    switch (this) {
      case TranslationRejection.empty:
        return 'empty output';
      case TranslationRejection.unchanged:
        return 'output identical to input';
      case TranslationRejection.echoedPrompt:
        return 'model echoed the instruction';
      case TranslationRejection.repetitionLoop:
        return 'model looped a phrase';
      case TranslationRejection.lengthBlowup:
        return 'output implausibly long';
      case TranslationRejection.stillEnglish:
        return 'output still reads as English';
    }
  }
}

/// Instruction fragments that must never survive into a translation. Lower
/// case; matched against a lower-cased candidate.
const _promptEchoes = <String>[
  'please translate the following',
  'translate the following',
  'you are a professional',
  'here is the translation',
  'here is my translation',
  'sure, here',
  'sure! here',
  'as an ai',
  'i cannot translate',
  'without any additional explanations',
];

/// Leading labels the model sometimes prepends. Stripped rather than
/// rejected — the translation after them is usually fine.
final _leadingLabels = RegExp(
  r'^\s*(translation|translated text|output|answer|result)\s*[:\-]\s*',
  caseSensitive: false,
);

/// Removes a `<think>` span, a stray closing tag, and any leading label.
///
/// Moved here from TranslationPipeline so cleaning and judging live
/// together: a check that ran before the label was stripped would reject
/// "Translation: <good Swahili>" as an echoed prompt.
String cleanTranslationOutput(String raw) {
  var result = raw.replaceAll(
    RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
    '',
  );
  final closeTag = RegExp(r'</think>', caseSensitive: false).firstMatch(result);
  if (closeTag != null) {
    result = result.substring(closeTag.end);
  }
  result = result.replaceFirst(_leadingLabels, '').trim();
  // Surrounding quotes the model sometimes adds around the whole output.
  if (result.length > 1) {
    final first = result[0];
    final last = result[result.length - 1];
    const openers = ['"', '“'];
    const closers = ['"', '”'];
    if (openers.contains(first) && closers.contains(last)) {
      result = result.substring(1, result.length - 1);
    }
  }
  return result.trim();
}

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

int _wordCount(String s) =>
    s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

/// True when some 3-word phrase repeats more than [threshold] times —
/// the shape of a decoder that has fallen into a loop.
bool hasRepetitionLoop(String text, {int threshold = 4}) {
  final words = _normalize(text).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length < 12) return false;
  final counts = <String, int>{};
  for (var i = 0; i + 3 <= words.length; i++) {
    final gram = '${words[i]} ${words[i + 1]} ${words[i + 2]}';
    final n = (counts[gram] ?? 0) + 1;
    if (n > threshold) return true;
    counts[gram] = n;
  }
  return false;
}

/// Judges a cleaned candidate translation of [source] into [toCode].
///
/// Returns null when the candidate is acceptable. Callers retry once on a
/// rejection and fall back to the source text if the retry also fails —
/// showing the untranslated original is honest, showing invented text is
/// not.
///
/// [strictEnglishCheck] gates the weakest signal. `looksLikeEnglish` needs
/// three marker hits and was tuned to be hard to trigger on African-language
/// input; run in reverse on *output* it can fire on a correct translation
/// that embeds English technical terms. So it only applies on the first
/// pass, where the cost of being wrong is one retry — never on the retry
/// itself, where it would throw away a probably-good translation.
TranslationRejection? judgeTranslation({
  required String source,
  required String candidate,
  required String toCode,
  bool strictEnglishCheck = true,
}) {
  final text = candidate.trim();
  if (text.isEmpty) return TranslationRejection.empty;

  final lower = text.toLowerCase();
  for (final echo in _promptEchoes) {
    if (lower.contains(echo)) return TranslationRejection.echoedPrompt;
  }

  final normSource = _normalize(source);
  final normCandidate = _normalize(text);
  if (normCandidate.isEmpty) return TranslationRejection.empty;
  if (normCandidate == normSource) return TranslationRejection.unchanged;

  if (hasRepetitionLoop(text)) return TranslationRejection.repetitionLoop;

  final srcWords = _wordCount(source);
  final outWords = _wordCount(text);
  // African languages in this vocabulary tokenize less efficiently than
  // English, and short inputs legitimately expand a lot, so the ceiling is
  // generous and only catches genuine runaway.
  if (srcWords >= 4 && outWords > srcWords * 6 + 20) {
    return TranslationRejection.lengthBlowup;
  }

  if (strictEnglishCheck && toCode != 'en' && outWords >= 8) {
    // Only meaningful once the output is long enough for the markers to
    // mean something. Below that it is noise.
    if (_readsAsEnglish(text)) return TranslationRejection.stillEnglish;
  }

  return null;
}

/// Same marker approach as `looksLikeEnglish`, applied to model *output*.
/// Kept separate so tuning one never silently changes the other, and set one
/// hit stricter because a correct translation may legitimately carry an
/// English technical term or two.
bool _readsAsEnglish(String text) {
  final padded = ' ${text.toLowerCase()} ';
  const markers = [
    ' the ', ' is ', ' are ', ' what ', ' how ', ' why ', ' you ',
    ' to ', ' in ', ' of ', ' and ', ' for ', ' with ', ' that ',
    ' this ', ' can ', ' from ', ' it ', ' they ', ' we ',
  ];
  var hits = 0;
  for (final m in markers) {
    if (padded.contains(m)) hits++;
  }
  return hits >= 4;
}

/// Human-readable model identity for the cache key. Two different GGUFs — a
/// re-quantize (tools/quantize_translate_model.ps1 can emit Q4_K_M, Q4_0, …)
/// or a newer release — must never share cached rows, because they do not
/// produce the same translations.
String modelTagFor({required String path, required int sizeBytes}) {
  final name = path.split(RegExp(r'[\\/]')).last;
  return '$name:$sizeBytes';
}

/// Language name as it must appear in a prompt, re-exported so callers of
/// this file don't also have to import supported_languages.
String promptNameFor(String code) => languagePromptName(code);
