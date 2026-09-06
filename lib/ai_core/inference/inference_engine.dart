import 'dart:async';

import 'litert_lm_engine.dart';

/// Token-by-token streaming callback.
///
/// May return a [Future] so the brain loop can await outbound AfriSLM
/// after a clause flush (sequential swap — see [EngineScheduler]).
typedef TokenCallback = FutureOr<void> Function(String token);

/// Awaits [onToken] when it returns a [Future].
Future<void> emitToken(TokenCallback? onToken, String token) async {
  if (onToken == null) return;
  await Future.sync(() => onToken(token));
}

/// Unified interface for all local inference backends.
/// - Chat (Android/Windows/Linux) → LiteRtLmEngineImpl (flutter_gemma_litertlm, Qwen3-0.6B)
/// - Translate (desktop/Android)  → LlamaCppEngineImpl (in-process llama.cpp, AfriSLM GGUF)
/// - Dev/Test                     → MockEngine (instant canned responses)
///
/// Native FFI lives in those two plugins — see `native_runtime.dart`.
/// Do not add onnxruntime_flutter or a second llama.cpp package beside them.
abstract class InferenceEngine {
  bool get isReady;
  String get backendLabel;

  /// True when answers are canned demos, not a real local model.
  bool get isDemo => false;

  /// Load the model file from [modelPath].
  Future<void> loadModel(String modelPath);

  /// Generate a response, streaming tokens via [onToken].
  ///
  /// [systemPrompt] is pinned when the runtime can keep it in KV
  /// ([LiteRtLmEngineImpl] via `createChat(systemInstruction:)`) or sent as
  /// a real system turn ([LlamaCppEngineImpl] / AfriSLM).
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    TokenCallback? onToken,
    String? systemPrompt,
  });

  /// Drop a pinned chat session (tutor "New session") so the next
  /// generate re-pins [systemPrompt] without leftover turns.
  Future<void> resetSession() async {}

  /// Release native resources.
  Future<void> dispose();
}

class ModelLoadException implements Exception {
  ModelLoadException(this.message);
  final String message;
  @override
  String toString() => 'ModelLoadException: $message';
}

/// Returns the chat engine — LiteRT-LM runs Qwen3-0.6B identically on
/// Android, Windows, and Linux, so there's no per-platform branch here
/// anymore (web is short-circuited earlier, in ai_provider.dart).
InferenceEngine createPlatformEngine() {
  return LiteRtLmEngineImpl();
}
