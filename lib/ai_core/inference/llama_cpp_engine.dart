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
    // Inference happens inside llm_llamacpp's persistent helper isolate,
    // which loads the GGUF per request and frees it again (llama_free +
    // llama_model_free in a finally). The default constructor plus
    // loadModel() would additionally hold a *second* copy in this isolate
    // that inference never reads — it is only consulted for the path — so
    // on Android that was ~670 MB resident for nothing, and a ~1.9 GB peak
    // while translating on top of the chat model. That does not fit a 4 GB
    // phone. withModelPath keeps only the path, which is what the package
    // documents ("the main isolate no longer calls any llama.cpp
    // functions"), and drops the steady state to just the chat model.
    //
    // nGpuLayers stays 0: translation prompts are short (<=120 tokens), so
    // CPU is fast enough, memory stays predictable on low-end devices, and
    // it removes the GPU-load-failure retry entirely. A bad file now
    // surfaces on first generate instead of here, which the callers
    // already treat as soft-fail (see localizeOutgoing/localizeIncoming).
    _repo?.dispose();
    _repo = llama.LlamaCppChatRepository.withModelPath(
      modelPath,
      contextSize: 1024,
      batchSize: 256,
      nGpuLayers: 0,
    );
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
