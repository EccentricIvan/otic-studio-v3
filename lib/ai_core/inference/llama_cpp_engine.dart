import 'package:llm_llamacpp/llm_llamacpp.dart' as llama;

import 'inference_engine.dart';

/// In-process GGUF inference via llama.cpp (`llm_llamacpp`).
///
/// Used for AfriSLM translation on Windows/Linux/macOS/Android so the
/// bundled `translate-afrislm.gguf` runs without a separate Ollama install.
class LlamaCppEngineImpl extends InferenceEngine {
  llama.LlamaCppChatRepository? _repo;
  String? _modelPath;

  @override
  bool get isReady => _repo != null && _modelPath != null;

  @override
  String get backendLabel => 'llama.cpp · AfriSLM';

  @override
  Future<void> loadModel(String modelPath) async {
    // Modest context — translation prompts are short; keeps RAM down for
    // school PCs that also load the chat model.
    llama.LlamaCppChatRepository? repo;
    try {
      repo = llama.LlamaCppChatRepository(
        contextSize: 1024,
        batchSize: 512,
        nGpuLayers: 99,
      );
      // ignore: deprecated_member_use — simple path; we own this repo instance
      await repo.loadModel(modelPath);
    } catch (_) {
      repo?.dispose();
      repo = llama.LlamaCppChatRepository(
        contextSize: 1024,
        batchSize: 256,
        nGpuLayers: 0,
      );
      try {
        // ignore: deprecated_member_use
        await repo.loadModel(modelPath);
      } catch (e) {
        repo.dispose();
        throw ModelLoadException('Failed to load translation model: $e');
      }
    }
    _repo?.dispose();
    _repo = repo;
    _modelPath = modelPath;
  }

  @override
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    TokenCallback? onToken,
  }) async {
    final repo = _repo;
    final modelPath = _modelPath;
    if (repo == null || modelPath == null) {
      throw StateError('Translation model not loaded.');
    }

    final buffer = StringBuffer();
    await for (final chunk in repo.streamChatWithGenerationOptions(
      modelPath,
      messages: [
        llama.LLMMessage(role: llama.LLMRole.user, content: prompt),
      ],
      think: false,
      generationOptions: llama.GenerationOptions(
        maxTokens: maxTokens,
        temperature: temperature,
        topP: temperature <= 0.0 ? 1.0 : 0.9,
        topK: temperature <= 0.0 ? 1 : 40,
        repeatPenalty: 1.05,
      ),
    )) {
      final text = chunk.message?.content;
      if (text == null || text.isEmpty) continue;
      buffer.write(text);
      onToken?.call(text);
    }

    final result = buffer.toString().trim();
    if (result.isEmpty) {
      throw StateError('Translation model returned an empty response.');
    }
    return result;
  }

  @override
  Future<void> dispose() async {
    _repo?.dispose();
    _repo = null;
    _modelPath = null;
  }
}
