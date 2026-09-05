import 'package:flutter/foundation.dart';

import '../inference/inference_engine.dart';
import 'supported_languages.dart';

/// True when [text] is very likely already English (Latin + common words).
/// Used to skip a slow AfriSLM round-trip when the student typed English.
///
/// Deliberately hard to trigger. A false positive here is not a slow path,
/// it is a *wrong* one: the student's message goes to the tutor untranslated
/// and comes back as nonsense, which reads exactly like the model
/// hallucinating. The earlier version needed only two hits from a list that
/// included ' a ' and ' i ' — both standalone words in Yoruba and Hausa — so
/// ordinary sentences in those languages were being passed through as
/// "English". Single-letter markers are gone and the threshold is three.
bool looksLikeEnglish(String text) {
  final t = text.trim();
  if (t.isEmpty) return true;
  if (RegExp(r'[ሀ-፿]').hasMatch(t)) return false; // Ge'ez (Amharic)
  final padded = ' ${t.toLowerCase()} ';
  const markers = [
    ' the ', ' is ', ' are ', ' what ', ' how ', ' why ', ' you ',
    " i'm ", ' to ', ' in ', ' of ', ' and ', ' for ',
    ' my ', ' can ', ' do ', ' this ', ' that ', ' please ', ' explain ',
  ];
  var hits = 0;
  for (final m in markers) {
    if (padded.contains(m)) hits++;
  }
  return hits >= 3;
}

/// Wraps the AfriSLM translation engine with single-shot calls so the tutor
/// pipeline can stay entirely in English while the student reads and writes
/// in their own language. Callers should treat translation as best-effort —
/// on failure, fall back to the original text rather than blocking the chat
/// (see ChatNotifier.send in ai_provider.dart).
class TranslationPipeline {
  TranslationPipeline(this._engine);
  final InferenceEngine _engine;

  /// The prompt format TranslatePsy-AfriSLM was actually trained on, taken
  /// from its model card.
  ///
  /// This matters more than anything else in this file. The model is 0.8B
  /// and quantised to 4-bit; it holds its shape only near the distribution
  /// it was tuned on. We previously sent a bare "Translate to Swahili.
  /// Output the translation only." with no system turn at all, which is off
  /// that distribution and is where invented text and commentary creep in.
  String _systemPrompt(String from, String to) =>
      'You are a professional $from to $to translator. Your goal is to '
      'accurately convey the meaning and nuances of the original $from text '
      'while adhering to $to grammar, vocabulary, and cultural '
      'sensitivities. Produce only the $to translation, without any '
      'additional explanations or commentary.';

  String _userPrompt(String from, String to, String text) =>
      'Please translate the following $from text into $to: $text.\n\n'
      'Translation:';

  /// One translation call in the model's trained shape.
  Future<String> _translate(
    String text,
    String fromName,
    String toName, {
    TokenCallback? onToken,
  }) async {
    final result = await _engine.generate(
      prompt: _userPrompt(fromName, toName, text),
      systemPrompt: _systemPrompt(fromName, toName),
      maxTokens: _tokenBudget(text),
      temperature: 0.0, // the model card's recommended setting
      onToken: onToken,
    );
    return _stripThinking(result);
  }

  Future<String> toEnglish(String text, String fromLanguageCode) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || fromLanguageCode == 'en') return text;
    // Students often type English even when the UI is in another language.
    // Skip a full model round-trip in that case — it is the largest delay.
    if (looksLikeEnglish(trimmed)) return text;
    final cleaned = await _translate(
      trimmed,
      languagePromptName(fromLanguageCode),
      'English',
    );
    if (cleaned.isEmpty) {
      debugPrint(
        'TRANSLATION EMPTY (in: $fromLanguageCode -> en) - keeping original.',
      );
      return text;
    }
    return cleaned;
  }

  Future<String> fromEnglish(
    String text,
    String toLanguageCode, {
    TokenCallback? onToken,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || toLanguageCode == 'en') return text;
    final cleaned = await _translate(
      trimmed,
      'English',
      languagePromptName(toLanguageCode),
      onToken: onToken,
    );
    if (cleaned.isEmpty) {
      // The visible symptom of this is "the reply came back in English".
      debugPrint(
        'TRANSLATION EMPTY (out: en -> $toLanguageCode) - falling back to '
        'English.',
      );
      return text;
    }
    return cleaned;
  }

  /// Translates a tutor reply and its follow-up prompt.
  ///
  /// These used to go out as one call with `A:`/`B:` labels to save a model
  /// round-trip, and the reply was recovered with a regex. AfriSLM was
  /// trained on single-text translation only, so a two-part labelled prompt
  /// is off-distribution: the model can drop a label, translate the labels
  /// themselves, or merge the parts — and the regex then silently fell back
  /// to English. Two plain calls are slower and correct. Most follow-ups are
  /// static l10n strings that never reach here at all (see ChatNotifier),
  /// so in practice this rarely costs the extra call.
  Future<(String reply, String followUp)> fromEnglishPair(
    String reply,
    String followUp,
    String toLanguageCode,
  ) async {
    if (toLanguageCode == 'en') return (reply, followUp);
    final translatedReply = await fromEnglish(reply, toLanguageCode);
    if (followUp.trim().isEmpty) return (translatedReply, followUp);
    return (translatedReply, await fromEnglish(followUp, toLanguageCode));
  }

  /// Output budget for one translation call.
  ///
  /// This used to clamp at 120 tokens while the tutor generates replies at
  /// maxTokens: 280, so any full-length answer was guaranteed to be cut off
  /// mid-sentence - and if the truncated output stripped down to nothing,
  /// the caller silently fell back to the English original. The ceiling has
  /// to sit above what the tutor can produce, not below it.
  ///
  /// The multiplier is 3x rather than 2x because the African languages here
  /// tokenize far less efficiently than English in this vocabulary: the same
  /// sentence routinely costs more tokens coming out than going in.
  int _tokenBudget(String text) {
    final words = text.split(RegExp(r'\s+')).length;
    final n = words * 3 + 32;
    if (n < 64) return 64;
    if (n > 512) return 512;
    return n;
  }

  /// AfriSLM is a reasoning model — llama.cpp completions can still emit a
  /// `<think>...</think>` span (or a stray closing `</think>`) into the
  /// response text. Strip it before showing the student anything.
  String _stripThinking(String text) {
    var result = text.replaceAll(
      RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
      '',
    );
    final closeTag = RegExp(r'</think>', caseSensitive: false);
    final match = closeTag.firstMatch(result);
    if (match != null) {
      result = result.substring(match.end);
    }
    return result.trim();
  }
}
