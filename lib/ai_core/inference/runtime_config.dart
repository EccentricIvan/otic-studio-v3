/// On-device dual-SLM budget and generation knobs.
///
/// Both engines stay mapped, not copied:
///   * Chat brain — Qwen3-0.6B via LiteRT-LM (``.litertlm``, ~330–590 MB)
///   * Translation — AfriSLM 0.8B Q4 via llama.cpp (``.gguf``, ~500–650 MB)
///
/// Active RAM stays under **1.2 GB** because:
///   1. Weights are memory-mapped.
///   2. [EngineScheduler] lets only one native decode run at a time.
///      Qwen's Dart loop *awaits* each flushed clause through AfriSLM, so
///      LiteRT stops pulling tokens while the GGUF is mapped.
///   3. [kMaxNewTokens] caps KV-cache growth.
///   4. Greedy decode ([kDoSample] = false) skips nucleus sampling graphs.
///   5. Tutor [kTutorContract] is pinned once via LiteRT `systemInstruction`.
///   6. AfriSLM system prompts are interned; the Drift cache skips a reload
///      when the same clause has been translated already.
///
/// FFI: LiteRT-LM + llm_llamacpp only. Do not add PyTorch/ONNX beside them.
library;

/// Greedy decode. `0.0` is fully deterministic (`do_sample: false`).
const double kTutorTemperature = 0.0;

/// AfriSLM model-card setting.
const double kTranslateTemperature = 0.0;

/// Hardcoded `do_sample: false`.
const bool kDoSample = false;

/// Nucleus disabled — the full distribution is unused because [kTopK] is 1.
const double kTopP = 1.0;

/// Greedy: consider only the argmax token.
const int kTopK = 1;

/// Fixed seed so two identical prompts decode the same way.
const int kRandomSeed = 0;

/// Hard cap on tutor decode length.
const int kMaxNewTokens = 150;

/// Forward English into AfriSLM at this many characters if no punctuation.
const int kTranslateFlushChars = 50;
