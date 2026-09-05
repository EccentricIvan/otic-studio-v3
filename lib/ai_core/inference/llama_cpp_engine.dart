import 'dart:async';

import 'package:llm_llamacpp/llm_llamacpp.dart' as llama;

import 'inference_engine.dart';

/// In-process GGUF inference via llama.cpp (`llm_llamacpp`).
///
/// Used for AfriSLM translation on Windows/Linux/macOS/Android so the
/// bundled `translate-afrislm.gguf` runs without a separate Ollama install.
class LlamaCppEngineImpl extends InferenceEngine {
  llama.LlamaCppChatRepository? _repo;
  String? _modelPath;

  /// True once the native stack has produced at least one token. Until then
  /// we cannot tell a slow machine from a native layer that never came up,
  /// so the first token gets the long deadline below.
  bool _nativeEverWorked = false;

  /// Set when the first call died without producing a token — the native
  /// stack is broken on this machine, not merely slow. Later calls then fail
  /// immediately instead of freezing the chat for minutes each time.
  String? _deadReason;

  /// Deadline for the first token of a call.
  ///
  /// It has to cover a full model load, because llm_llamacpp reloads the
  /// GGUF on *every* request: the helper isolate frees it in a `finally`
  /// after each one, and every LlamaCppChatRepository constructor funnels
  /// into the same PersistentInferenceIsolate.runInference(modelPath:).
  /// So each call pays ~670 MB of disk I/O plus prompt eval before token 1.
  static const _firstTokenTimeout = Duration(minutes: 3);

  /// Deadline between two tokens once generation is actually under way.
  static const _betweenTokensTimeout = Duration(seconds: 60);

  @override
  bool get isReady =>
      _repo != null && _modelPath != null && _deadReason == null;

  @override
  String get backendLabel => 'llama.cpp · AfriSLM';

  /// Why translation is unavailable, or null while it still looks healthy.
  /// Callers use this to tell the student translation is off rather than
  /// silently handing them English.
  String? get failureReason => _deadReason;

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
      // A 280-token tutor reply plus instructions, plus up to 512 tokens of
      // translated output, does not fit in 1024. Undersizing the context
      // truncates the translation, which is what made replies fall back to
      // English.
      contextSize: 2048,
      batchSize: 256,
      nGpuLayers: 0,
    );
    _modelPath = modelPath;
    _nativeEverWorked = false;
    _deadReason = null;
  }

  @override
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    TokenCallback? onToken,
    String? systemPrompt,
  }) async {
    final repo = _repo;
    final modelPath = _modelPath;
    if (repo == null || modelPath == null) {
      throw StateError('Translation model not loaded.');
    }
    // An earlier call proved the native stack is broken here. Fail in
    // milliseconds rather than making the student wait out the watchdog
    // again on every single message.
    final dead = _deadReason;
    if (dead != null) {
      throw StateError(dead);
    }

    // A real system turn, not a string glued onto the front of the user
    // message: llm_llamacpp renders these through the GGUF's own chat
    // template, and AfriSLM was trained with the translator persona in the
    // system role. Concatenating instead would put it off-distribution,
    // which is where a 0.8B model starts inventing text.
    final stream = repo.streamChatWithGenerationOptions(
      modelPath,
      messages: [
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
          llama.LLMMessage(role: llama.LLMRole.system, content: systemPrompt),
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
    );

    // Why this is a watchdog rather than a plain `await for`:
    //
    // When llm_llamacpp's helper isolate fails to initialise the native
    // backend it prints the error and *returns* — without ever creating its
    // receive port or answering the main isolate (see _isolateMain in
    // persistent_inference_isolate.dart). The completer that
    // _ensureInitialized awaits is never completed, so the inference stream
    // emits nothing, never closes and never errors. `await for` on it hangs
    // the caller forever, and no try/catch can ever fire.
    //
    // That is not theoretical. On Windows, ggml.dll carries a *load-time*
    // import on ggml-vulkan.dll, which imports vulkan-1.dll. On a machine
    // with no Vulkan runtime — generic display drivers, common on the
    // low-end laptops this project targets — llama.dll cannot load at all,
    // so translation froze the chat on its generating indicator with no
    // recovery. Android is unaffected: libvulkan.so ships with the OS.
    //
    // The watchdog turns that dead silence into an ordinary error, which
    // localizeOutgoing/localizeIncoming already soft-fail and log.
    final buffer = StringBuffer();
    final done = Completer<void>();
    StreamSubscription<Object?>? sub;
    Timer? watchdog;

    void fail(String message) {
      if (done.isCompleted) return;
      // Only latch when nothing ever came through: a stall mid-generation
      // can be a slow machine, but silence on the very first token means
      // the native library never came up.
      if (!_nativeEverWorked) _deadReason = message;
      watchdog?.cancel();
      unawaited(sub?.cancel());
      done.completeError(StateError(message));
    }

    void arm(Duration limit) {
      watchdog?.cancel();
      watchdog = Timer(limit, () {
        fail(
          _nativeEverWorked
              ? 'Translation stalled for ${limit.inSeconds}s with no new '
                  'output.'
              : 'Translation produced no output within ${limit.inSeconds}s. '
                  'The llama.cpp native library most likely failed to load; '
                  'on Windows that happens when the Vulkan runtime is '
                  'missing, because ggml.dll imports ggml-vulkan.dll at '
                  'load time.',
        );
      });
    }

    arm(_firstTokenTimeout);
    sub = stream.listen(
      (chunk) {
        final text = chunk.message?.content;
        if (text == null || text.isEmpty) return;
        _nativeEverWorked = true;
        buffer.write(text);
        onToken?.call(text);
        arm(_betweenTokensTimeout);
      },
      onError: (Object e, StackTrace st) {
        if (done.isCompleted) return;
        watchdog?.cancel();
        done.completeError(e, st);
      },
      onDone: () {
        if (done.isCompleted) return;
        watchdog?.cancel();
        done.complete();
      },
      cancelOnError: true,
    );

    try {
      await done.future;
    } finally {
      watchdog?.cancel();
      await sub.cancel();
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
    _deadReason = null;
    _nativeEverWorked = false;
  }
}
