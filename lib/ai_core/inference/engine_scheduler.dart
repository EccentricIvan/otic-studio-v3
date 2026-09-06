import 'dart:async';

/// One native decode at a time.
///
/// Qwen (LiteRT) and AfriSLM (llama.cpp) must not prefill in the same
/// millisecond window on a 4 GB phone. The brain loop awaits each flushed
/// clause's translation ([OutboundTranslateStream.addEnglish]), and that
/// translation takes this lock. LiteRT's `await for` then stops pulling
/// tokens, so the GGUF can load, decode, and free before the next Qwen
/// token is consumed.
class EngineScheduler {
  EngineScheduler._();
  static final EngineScheduler instance = EngineScheduler._();

  Future<void> _tail = Future.value();

  Future<T> exclusive<T>(Future<T> Function() job) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    try {
      try {
        await previous;
      } catch (_) {}
      return await job();
    } finally {
      if (!done.isCompleted) done.complete();
    }
  }
}
