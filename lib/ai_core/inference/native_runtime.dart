/// Embedded inference FFI — no PyTorch, no extra ONNX session.
///
/// The product asked for a plugin such as `flutter_llama_cpp` or
/// `onnxruntime_flutter`. Those would be a third resident runtime next to
/// the two we already ship, and they would break the 1.2 GB RAM ceiling
/// documented in `docs/DUAL_MODEL_MEMORY.md`.
///
/// Bindings already in tree:
///
///   * Chat brain — [LiteRtLmEngineImpl] via `flutter_gemma` /
///     `flutter_gemma_litertlm` (LiteRT-LM, `.litertlm`).
///   * Translation — [LlamaCppEngineImpl] via `llm_llamacpp` (llama.cpp,
///     `.gguf`). This **is** the embedded llama.cpp FFI the request asked
///     for; a second package with the same job is not added.
///
/// Streaming pipeline: [OutboundTranslateStream] in `dual_model_stream.dart`.
/// Generation knobs: [kTutorTemperature], [kTranslateTemperature],
/// [kDoSample], [kTopP], [kMaxNewTokens], [kTranslateFlushChars] in
/// `runtime_config.dart` (greedy `temperature: 0.0`, `do_sample: false`,
/// `top_p: 1.0`, flush at 50 characters).
/// Sequential swap: [EngineScheduler]. Prompt intern: [PinnedPromptCache].
library;

export 'dual_model_stream.dart';
export 'engine_scheduler.dart';
export 'pinned_prompt_cache.dart';
export 'runtime_config.dart';
