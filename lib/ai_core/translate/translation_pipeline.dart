import 'package:flutter/foundation.dart';

import '../inference/inference_engine.dart';
import 'supported_languages.dart';

/// True when [text] is very likely already English (Latin + common words).
/// Used to skip a slow AfriSLM round-trip when the student typed English.
bool looksLikeEnglish(String text) {
  final t = text.trim();
  if (t.isEmpty) return true;
  if (RegExp(r'[\u1200-\u137F]').hasMatch(t)) return false; // Ge'ez (Amharic)
  final padded = ' ${t.toLowerCase()} ';
  const markers = [
    ' the ', ' is ', ' are ', ' what ', ' how ', ' why ', ' i ',
    " i'm ", ' you ', ' a ', ' to ', ' in ', ' of ', ' and ', ' for ',
    ' my ', ' can ', ' do ', ' this ', ' that ', ' please ', ' explain ',
  ];
  var hits = 0;
  for (final m in markers) {
    if (padded.contains(m)) hits++;
  }
  return hits >= 2;
}

/// Wraps the AfriSLM translation engine with two single-shot calls so the
/// tutor pipeline can stay entirely in English while the student reads and
/// writes in their own language. Callers should treat translation as
/// best-effort — on failure, fall back to the original text rather than
/// blocking the chat (see ChatNotifier.send in ai_provider.dart).
class TranslationPipeline {
  TranslationPipeline(this._engine);
  final InferenceEngine _engine;

  Future<String> toEnglish(String text, String fromLanguageCode) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || fromLanguageCode == 'en') return text;
    // Students often type English even when the UI is in another language.
    // Skip a full model round-trip in that case — it is the largest delay.
    if (looksLikeEnglish(trimmed)) return text;
    final fromName = languageName(fromLanguageCode);
    final prompt = 'Translate to English. Output the translation only.\n\n'
        '($fromName)\n$trimmed';
    final result = await _engine.generate(
      prompt: prompt,
      maxTokens: _tokenBudget(trimmed),
      temperature: 0.0,
    );
    final cleaned = _stripThinking(result);
    if (cleaned.isEmpty) {
      debugPrint(
        'TRANSLATION EMPTY (in: $fromLanguageCode -> en) - keeping original. '
        'Raw model output was ${result.length} chars.',
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
    final toName = languageName(toLanguageCode);
    final prompt = 'Translate to $toName. Output the translation only.\n\n'
        '$trimmed';
    final result = await _engine.generate(
      prompt: prompt,
      maxTokens: _tokenBudget(trimmed),
      temperature: 0.0,
      onToken: onToken,
    );
    final cleaned = _stripThinking(result);
    if (cleaned.isEmpty) {
      // The visible symptom of this is "the reply came back in English".
      debugPrint(
        'TRANSLATION EMPTY (out: en -> $toLanguageCode) - falling back to '
        'English. Raw model output was ${result.length} chars.',
      );
      return text;
    }
    return cleaned;
  }

  /// One model call for the tutor reply plus follow-up.
  Future<(String reply, String followUp)> fromEnglishPair(
    String reply,
    String followUp,
    String toLanguageCode,
  ) async {
    if (toLanguageCode == 'en') return (reply, followUp);
    if (followUp.trim().isEmpty) {
      return (await fromEnglish(reply, toLanguageCode), followUp);
    }
    final toName = languageName(toLanguageCode);
    final prompt = 'Translate both parts to $toName. Keep the labels.\n'
        'A: $reply\n'
        'B: $followUp';
    final result = await _engine.generate(
      prompt: prompt,
      maxTokens: _tokenBudget('$reply $followUp') + 32,
      temperature: 0.0,
    );
    final cleaned = _stripThinking(result);
    final a = RegExp(r'A:\s*([\s\S]+?)(?:\nB:|$)', caseSensitive: false)
        .firstMatch(cleaned)
        ?.group(1)
        ?.trim();
    final b = RegExp(r'B:\s*([\s\S]+)$', caseSensitive: false)
        .firstMatch(cleaned)
        ?.group(1)
        ?.trim();
    if (a != null && a.isNotEmpty) {
      return (a, b ?? followUp);
    }
    return (await fromEnglish(reply, toLanguageCode), followUp);
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
