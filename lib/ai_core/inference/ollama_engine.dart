import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'inference_engine.dart';

/// Connects to a local Ollama instance running on the device and talks to
/// one specific model tag — currently used only for the AfriSLM translation
/// model (`ai-connect-africa-translate`, created locally by
/// OllamaModelInstaller from a USB-distributed GGUF; never `ollama pull`ed
/// over the internet). Ollama serves models via HTTP at localhost:11434.
class OllamaEngine extends InferenceEngine {
  OllamaEngine({required this.modelTag});

  static const _baseUrl = 'http://127.0.0.1:11434';

  /// The exact Ollama model tag this engine must find installed, e.g.
  /// `ai-connect-africa-translate`.
  final String modelTag;

  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  String get backendLabel => 'Ollama · $modelTag';

  @override
  Future<void> loadModel(String modelPath) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$_baseUrl/api/tags'));
      final response = await request.close().timeout(const Duration(seconds: 5));
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final models = (json['models'] as List?) ?? [];
      final names = models
          .map((m) => (m as Map<String, dynamic>)['name'] as String?)
          .whereType<String>()
          .toList();

      // Ollama always qualifies a bare tag with a version, e.g. `ollama
      // create foo` registers it as `foo:latest` — match that too, not just
      // an exact bare-tag string.
      if (names.any((n) => n == modelTag || n.startsWith('$modelTag:'))) {
        _ready = true;
      } else {
        throw ModelLoadException(
          'Ollama is running but "$modelTag" isn\'t installed yet. '
          'Install the model from Settings first.',
        );
      }
      client.close();
    } on TimeoutException {
      throw ModelLoadException(
        'Cannot connect to Ollama. Make sure Ollama is running '
        '(open a terminal and run: ollama serve).',
      );
    } on SocketException {
      throw ModelLoadException(
        'Cannot connect to Ollama at $_baseUrl. '
        'Install Ollama from ollama.com, then run: ollama serve',
      );
    }
  }

  @override
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    TokenCallback? onToken,
    String? systemPrompt,
  }) async {
    if (!_ready) throw StateError('Ollama not connected. Call loadModel() first.');

    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('$_baseUrl/api/generate'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'model': modelTag,
      'prompt': prompt,
      'stream': true,
      'options': {
        'num_predict': maxTokens,
        'temperature': temperature,
      },
    }));

    final response = await request.close();
    final buffer = StringBuffer();

    await for (final chunk in response.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final token = json['response'] as String? ?? '';
          if (token.isNotEmpty) {
            buffer.write(token);
            await emitToken(onToken, token);
          }
        } catch (_) {}
      }
    }

    client.close();
    return buffer.toString();
  }

  @override
  Future<void> dispose() async {
    _ready = false;
  }

  /// Check if Ollama is reachable.
  static Future<bool> isAvailable() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$_baseUrl/api/tags'));
      final response = await request.close().timeout(const Duration(seconds: 1));
      await response.drain<void>();
      client.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
