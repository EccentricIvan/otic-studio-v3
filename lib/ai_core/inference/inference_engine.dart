import 'litert_lm_engine.dart';

/// Token-by-token streaming callback.
typedef TokenCallback = void Function(String token);

/// Unified interface for all local inference backends.
/// - Chat (Android/Windows/Linux) → LiteRtLmEngineImpl (flutter_gemma_litertlm, Qwen3-0.6B)
/// - Translate (desktop/Android)  → LlamaCppEngineImpl (in-process llama.cpp, AfriSLM GGUF)
/// - Dev/Test                     → MockEngine (instant canned responses)
abstract class InferenceEngine {
  bool get isReady;
  String get backendLabel;

  /// True when answers are canned demos, not a real local model.
  bool get isDemo => false;

  /// Load the model file from [modelPath].
  Future<void> loadModel(String modelPath);

  /// Generate a response, streaming tokens via [onToken].
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    TokenCallback? onToken,
  });

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
