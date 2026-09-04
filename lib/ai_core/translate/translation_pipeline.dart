import '../inference/inference_engine.dart';
import 'supported_languages.dart';

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
    final fromName = languageName(fromLanguageCode);
    final prompt = 'Translate the following $fromName text to English. '
        'Reply with only the English translation, no explanation, no quotes.\n\n'
        '$trimmed';
    final result = await _engine.generate(prompt: prompt, maxTokens: 400, temperature: 0.2);
    final cleaned = _stripThinking(result);
    return cleaned.isEmpty ? text : cleaned;
  }

  Future<String> fromEnglish(String text, String toLanguageCode) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || toLanguageCode == 'en') return text;
    final toName = languageName(toLanguageCode);
    final prompt = 'Translate the following English text to $toName. '
        'Reply with only the $toName translation, no explanation, no quotes.\n\n'
        '$trimmed';
    final result = await _engine.generate(prompt: prompt, maxTokens: 400, temperature: 0.2);
    final cleaned = _stripThinking(result);
    return cleaned.isEmpty ? text : cleaned;
  }

  /// AfriSLM is a reasoning model — raw completion APIs (Ollama's
  /// `/api/generate`) don't apply the chat template's thinking filter the
  /// way the on-device chat engine does, so a `<think>...</think>` span (or,
  /// with no explicit opening tag, just a stray closing `</think>`) can leak
  /// into the response text. Strip it before showing the student anything.
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
