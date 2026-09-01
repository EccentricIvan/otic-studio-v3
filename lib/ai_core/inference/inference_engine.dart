import 'package:flutter/foundation.dart';
import 'litert_lm_engine.dart';
import 'ollama_engine.dart';

/// Token-by-token streaming callback.
typedef TokenCallback = void Function(String token);

/// Unified interface for all local inference backends.
/// - Android      → LiteRtLmEngineImpl (flutter_gemma / MediaPipe)
/// - Windows/Linux → OllamaEngine (local Ollama server)
/// - Dev/Test     → MockEngine (instant canned responses)
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

/// Returns the correct engine for the current platform.
InferenceEngine createPlatformEngine() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return LiteRtLmEngineImpl();
  }
  return OllamaEngine();
}
