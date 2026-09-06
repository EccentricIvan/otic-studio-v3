import 'package:flutter_test/flutter_test.dart';
import 'package:ai_connect_africa/ai_core/inference/inference_engine.dart';
import 'package:ai_connect_africa/ai_core/translate/supported_languages.dart';
import 'package:ai_connect_africa/ai_core/translate/translation_pipeline.dart';

/// Records every prompt it's asked to generate and returns a canned
/// response, so tests can assert on exactly what TranslationPipeline sends
/// to the engine without needing a real model.
class _RecordingEngine extends InferenceEngine {
  final List<String> prompts = [];
  String nextResponse = 'translated text';

  @override
  bool get isReady => true;

  @override
  String get backendLabel => 'Recording';

  @override
  Future<void> loadModel(String modelPath) async {}

  @override
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    TokenCallback? onToken,
    String? systemPrompt,
  }) async {
    prompts.add(prompt);
    return nextResponse;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('TranslationPipeline', () {
    test('toEnglish is a no-op for English input', () async {
      final engine = _RecordingEngine();
      final pipeline = TranslationPipeline(engine);

      final result = await pipeline.toEnglish('hello there', 'en');

      expect(result, 'hello there');
      expect(engine.prompts, isEmpty);
    });

    test('toEnglish is a no-op for empty input', () async {
      final engine = _RecordingEngine();
      final pipeline = TranslationPipeline(engine);

      final result = await pipeline.toEnglish('   ', 'sw');

      expect(result, '   ');
      expect(engine.prompts, isEmpty);
    });

    test('toEnglish names the source language and asks for a clean translation', () async {
      final engine = _RecordingEngine()..nextResponse = 'How are you?';
      final pipeline = TranslationPipeline(engine);

      final result = await pipeline.toEnglish('Oli otya?', 'lg');

      expect(engine.prompts, hasLength(1));
      expect(engine.prompts.single, contains('Luganda'));
      expect(engine.prompts.single, contains('Oli otya?'));
      expect(engine.prompts.single, contains('English'));
      expect(result, 'How are you?');
    });

    test('fromEnglish names the target language', () async {
      final engine = _RecordingEngine()..nextResponse = 'Oli otya?';
      final pipeline = TranslationPipeline(engine);

      final result = await pipeline.fromEnglish('How are you?', 'lg');

      expect(engine.prompts.single, contains('Luganda'));
      expect(engine.prompts.single, contains('How are you?'));
      expect(result, 'Oli otya?');
    });

    test('fromEnglish is a no-op when the target is English', () async {
      final engine = _RecordingEngine();
      final pipeline = TranslationPipeline(engine);

      final result = await pipeline.fromEnglish('hello', 'en');

      expect(result, 'hello');
      expect(engine.prompts, isEmpty);
    });

    test('strips a leaked <think>...</think> block from the response', () async {
      final engine = _RecordingEngine()
        ..nextResponse = '<think>the student asked about water</think>How are you?';
      final pipeline = TranslationPipeline(engine);

      final result = await pipeline.toEnglish('Oli otya?', 'lg');

      expect(result, 'How are you?');
    });

    test('strips a stray closing </think> with no opening tag', () async {
      final engine = _RecordingEngine()..nextResponse = '</think>\n\nHow are you?';
      final pipeline = TranslationPipeline(engine);

      final result = await pipeline.toEnglish('Oli otya?', 'lg');

      expect(result, 'How are you?');
    });

    test('falls back to the original text if the engine returns blank', () async {
      final engine = _RecordingEngine()..nextResponse = '   ';
      final pipeline = TranslationPipeline(engine);

      final result = await pipeline.toEnglish('Oli otya?', 'lg');

      expect(result, 'Oli otya?');
    });

    test('covers every supported language for both directions', () async {
      final engine = _RecordingEngine();
      final pipeline = TranslationPipeline(engine);

      for (final lang in supportedLanguages.where((l) => l.code != 'en')) {
        await pipeline.toEnglish('sample text', lang.code);
        await pipeline.fromEnglish('sample text', lang.code);
      }

      // Two calls (toEnglish + fromEnglish) per non-English language.
      expect(engine.prompts, hasLength((supportedLanguages.length - 1) * 2));
    });
  });
}
