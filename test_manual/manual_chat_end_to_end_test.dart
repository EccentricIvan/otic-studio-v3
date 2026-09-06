// Manual end-to-end smoke test for the chat the student actually uses:
// ChatNotifier.send() driving the real AfriSLM translator around the real
// Qwen3-0.6B tutor, with the same providers the app wires up.
//
// manual_translation_smoke_test.dart exercises the two engines directly.
// This one goes through the provider graph instead, so it also covers the
// parts that decide whether a real student ever sees a translated reply:
// language resolution, the safety gate, follow-up handling and the
// English-buffering rule.
//
// Needs real model files on disk:
//   - chat-model.litertlm       (LiteRT-LM)
//   - translate-afrislm.gguf    (llama.cpp, in-process)
// Lives outside test/ so `flutter test` (and CI) never picks it up.
// Run directly:
//   flutter test test_manual/manual_chat_end_to_end_test.dart
import 'dart:io';

import 'package:ai_connect_africa/ai_core/inference/inference_engine.dart';
import 'package:ai_connect_africa/ai_core/inference/litert_lm_engine.dart';
import 'package:ai_connect_africa/ai_core/inference/llama_cpp_engine.dart';
import 'package:ai_connect_africa/ai_core/providers/ai_provider.dart';
import 'package:ai_connect_africa/l10n/language_provider.dart';
import 'package:ai_connect_africa/db/providers/db_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _repo = r'C:\Users\esian\otic-studio-v3';

String _firstExisting(List<String> candidates, String label) {
  final hit = candidates.firstWhere(
    (p) => File(p).existsSync(),
    orElse: () => '',
  );
  if (hit.isEmpty) {
    throw StateError('No $label model found. Looked in:\n  ${candidates.join('\n  ')}');
  }
  return hit;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  SharedPreferences.setMockInitialValues({});
  const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler(
          (MethodCall call) async => Directory.systemTemp.path);

  test('a Swahili student gets a Swahili reply through ChatNotifier',
      () async {
    await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);

    final chatPath = _firstExisting([
      r'C:\Users\esian\OneDrive\Documents\OTIC\chat-model.litertlm',
      '$_repo\\dist\\models\\chat-model.litertlm',
      '$_repo\\build\\windows\\x64\\runner\\Release\\models\\chat-model.litertlm',
    ], 'chat');
    final translatePath = _firstExisting([
      '$_repo\\dist\\models\\translate-afrislm.gguf',
      r'C:\Users\esian\OneDrive\Documents\OTIC\translate-afrislm.gguf',
      '$_repo\\build\\windows\\x64\\runner\\Release\\models\\translate-afrislm.gguf',
    ], 'translate');

    stdout.writeln('Chat model:      $chatPath');
    stdout.writeln('Translate model: $translatePath');

    stdout.writeln('\n--- Loading engines ---');
    final chatEngine = LiteRtLmEngineImpl();
    await chatEngine.loadModel(chatPath);
    final translateEngine = LlamaCppEngineImpl();
    await translateEngine.loadModel(translatePath);
    stdout.writeln('chat: ${chatEngine.backendLabel} (ready=${chatEngine.isReady})');
    stdout.writeln(
        'translate: ${translateEngine.backendLabel} (ready=${translateEngine.isReady})');

    // Same graph the app builds, with the two engines pinned to the real
    // files instead of being discovered by the model managers.
    final container = ProviderContainer(overrides: [
      // A guest: nothing is written to disk, and the language comes from the
      // in-session override exactly as it does when a guest picks one.
      activeStudentProvider.overrideWith((ref) async => null),
      engineLoadedProvider.overrideWith((ref) async => chatEngine),
      translateEngineLoadedProvider
          .overrideWith((ref) async => translateEngine as InferenceEngine?),
    ]);
    addTearDown(container.dispose);
    container.read(languageOverrideProvider.notifier).adoptSaved('sw');

    const swahili = 'Habari, naweza kujifunza photosynthesis?';
    stdout.writeln('\nStudent (sw): $swahili');

    final started = DateTime.now();
    await container.read(chatProvider.notifier).send(swahili);
    final elapsed = DateTime.now().difference(started);

    final state = container.read(chatProvider).requireValue;
    for (final m in state.messages) {
      stdout.writeln('${m.isUser ? 'student' : 'tutor  '}: ${m.text}');
      if (!m.isUser && (m.followUp ?? '').isNotEmpty) {
        stdout.writeln('follow-up: ${m.followUp}');
      }
    }
    stdout.writeln('\nturn took ${elapsed.inSeconds}s');

    expect(state.isGenerating, isFalse);
    expect(state.errorMessage, isNull,
        reason: 'the turn reported an error to the student');
    expect(state.messages, hasLength(2));

    final reply = state.messages.last;
    expect(reply.isUser, isFalse);
    expect(reply.isError, isFalse);
    expect(reply.text.trim(), isNotEmpty);

    // The visible symptom of a broken round trip is an English reply on a
    // Swahili screen. This is a weak signal on purpose — it catches the
    // wholesale fallback, not a bad translation.
    final english = RegExp(r'\b(the|photosynthesis is|plants|sunlight)\b',
        caseSensitive: false);
    final looksEnglish = english.allMatches(reply.text).length >= 2;
    stdout.writeln(looksEnglish
        ? '\nWARNING: reply still looks like English — translation fell back.'
        : '\nReply is not plain English: outbound leg produced Swahili.');
    expect(looksEnglish, isFalse,
        reason: 'the tutor reply came back in English despite lang=sw');

    await translateEngine.dispose();
    await chatEngine.dispose();
  }, timeout: const Timeout(Duration(minutes: 15)));
}
