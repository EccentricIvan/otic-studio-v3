// Manual, ad-hoc smoke test for the full translate-in -> chat -> translate-out
// pipeline (Swahili student <-> English tutor). Needs a real chat model file
// on disk and a running local Ollama server with the AfriSLM tag registered.
// Lives outside test/ so `flutter test` (and CI) never picks it up.
// Run directly:
//   flutter test test_manual/manual_translation_smoke_test.dart
import 'dart:io';

import 'package:ai_connect_africa/ai_core/inference/litert_lm_engine.dart';
import 'package:ai_connect_africa/ai_core/inference/ollama_engine.dart';
import 'package:ai_connect_africa/ai_core/translate/translation_pipeline.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  // TestWidgetsFlutterBinding fakes all HttpClient traffic (400s, no real
  // request) for test isolation — this script intentionally talks to a real
  // local Ollama server, so restore real networking.
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});
  const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((MethodCall call) async => Directory.systemTemp.path);

  test('Swahili student message round-trips through English chat', () async {
    await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);

    const chatModelPath =
        r'C:\Users\esian\OneDrive\Documents\OTIC\chat-model.litertlm';
    stdout.writeln('Chat model exists: ${File(chatModelPath).existsSync()}');

    stdout.writeln('\n--- Loading translation engine (Ollama) ---');
    final translateEngine = OllamaEngine(modelTag: 'ai-connect-africa-translate');
    await translateEngine.loadModel('');
    final pipeline = TranslationPipeline(translateEngine);
    stdout.writeln('Translation engine ready: ${translateEngine.isReady}');

    const swahiliQuestion = 'Maji huchemka kwa nyuzi joto ngapi?'; // "At what temperature does water boil?"
    stdout.writeln('\nStudent (Swahili): $swahiliQuestion');

    final englishQuestion = await pipeline.toEnglish(swahiliQuestion, 'sw');
    stdout.writeln('Translated to English: $englishQuestion');

    stdout.writeln('\n--- Loading chat engine (LiteRT-LM, CPU) ---');
    final chatEngine = LiteRtLmEngineImpl();
    final loadStart = DateTime.now();
    await chatEngine.loadModel(chatModelPath);
    stdout.writeln(
      'Chat model loaded in ${DateTime.now().difference(loadStart).inSeconds}s. '
      'backend=${chatEngine.backendLabel}',
    );

    stdout.write('English tutor response: ');
    final genStart = DateTime.now();
    final englishAnswer = await chatEngine.generate(
      prompt: englishQuestion,
      maxTokens: 150,
      onToken: (t) => stdout.write(t),
    );
    stdout.writeln(
      '\n(generated in ${DateTime.now().difference(genStart).inSeconds}s)',
    );

    stdout.writeln('\n--- Translating tutor response back to Swahili ---');
    final swahiliAnswer = await pipeline.fromEnglish(englishAnswer, 'sw');
    stdout.writeln('Student sees (Swahili): $swahiliAnswer');

    await chatEngine.dispose();
    await translateEngine.dispose();

    expect(englishQuestion.trim(), isNotEmpty);
    expect(englishAnswer.trim(), isNotEmpty);
    expect(swahiliAnswer.trim(), isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
