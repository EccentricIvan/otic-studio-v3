// Manual, ad-hoc smoke test for the full translate-in -> chat -> translate-out
// pipeline (Swahili student <-> English tutor). Needs real model files on disk:
//   - chat-model.litertlm (LiteRT-LM)
//   - translate-afrislm.gguf (loaded in-process via llama.cpp)
// Lives outside test/ so `flutter test` (and CI) never picks it up.
// Run directly:
//   flutter test test_manual/manual_translation_smoke_test.dart
import 'dart:io';

import 'package:ai_connect_africa/ai_core/inference/litert_lm_engine.dart';
import 'package:ai_connect_africa/ai_core/inference/llama_cpp_engine.dart';
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
  SharedPreferences.setMockInitialValues({});
  const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((MethodCall call) async => Directory.systemTemp.path);

  test('Swahili student message round-trips through English chat', () async {
    await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);

    const chatModelPath =
        r'C:\Users\esian\OneDrive\Documents\OTIC\chat-model.litertlm';
    const translateModelPath =
        r'C:\Users\esian\otic-studio-v3\dist\models\translate-afrislm.gguf';
    // Fallbacks if models live next to a release build.
    final translateCandidates = [
      translateModelPath,
      r'C:\Users\esian\OneDrive\Documents\OTIC\translate-afrislm.gguf',
      r'C:\Users\esian\otic-studio-v3\build\windows\x64\runner\Release\models\translate-afrislm.gguf',
    ];
    final translatePath = translateCandidates.firstWhere(
      (p) => File(p).existsSync(),
      orElse: () => translateModelPath,
    );

    stdout.writeln('Chat model exists: ${File(chatModelPath).existsSync()}');
    stdout.writeln('Translate model: $translatePath '
        '(exists: ${File(translatePath).existsSync()})');

    stdout.writeln('\n--- Loading translation engine (llama.cpp) ---');
    final translateEngine = LlamaCppEngineImpl();
    await translateEngine.loadModel(translatePath);
    final pipeline = TranslationPipeline(translateEngine);

    const swahili = 'Habari, naweza kujifunza photosynthesis?';
    stdout.writeln('Student (sw): $swahili');
    final englishIn = await pipeline.toEnglish(swahili, 'sw');
    stdout.writeln('→ English: $englishIn');

    stdout.writeln('\n--- Loading chat engine ---');
    final chat = LiteRtLmEngineImpl();
    await chat.loadModel(chatModelPath);
    final replyEn = await chat.generate(
      prompt: 'You are a brief tutor. Student asked: $englishIn\nReply in 2 sentences.',
      maxTokens: 120,
      temperature: 0.4,
    );
    stdout.writeln('Tutor (en): $replyEn');

    final replySw = await pipeline.fromEnglish(replyEn, 'sw');
    stdout.writeln('→ Swahili: $replySw');

    expect(englishIn.toLowerCase(), isNot(equals(swahili.toLowerCase())));
    expect(replySw, isNotEmpty);

    await translateEngine.dispose();
    await chat.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
