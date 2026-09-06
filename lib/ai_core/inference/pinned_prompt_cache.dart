/// Interns structural system prompts so every turn reuses the same
/// [String] instance.
///
/// LiteRT-LM pins [kTutorContract] through `createChat(systemInstruction:)`.
/// llama.cpp's helper isolate still frees the GGUF after each request, so
/// a native prefix-KV cannot survive across calls — the interned string
/// plus the Drift translation cache is what skips re-reading headers for
/// repeated clauses.
class PinnedPromptCache {
  PinnedPromptCache._();

  static final Map<String, String> _intern = {};

  static String intern(String prompt) =>
      _intern.putIfAbsent(prompt, () => prompt);

  static int get size => _intern.length;
}
