import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'inference_engine.dart';

/// Connects to a local Ollama instance running on the device.
/// Ollama serves models via HTTP at localhost:11434.
class OllamaEngine extends InferenceEngine {
  static const _baseUrl = 'http://127.0.0.1:11434';
  static const _defaultModel = 'gemma3:1b';

  String _model = _defaultModel;
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  String get backendLabel => 'Ollama · $_model';

  @override
  Future<void> loadModel(String modelPath) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$_baseUrl/api/tags'));
      final response = await request.close().timeout(const Duration(seconds: 5));
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final models = (json['models'] as List?) ?? [];

      if (models.isNotEmpty) {
        _model = (models.first['name'] as String?) ?? _defaultModel;
        _ready = true;
      } else {
        throw ModelLoadException(
          'Ollama is running but no models are installed. '
          'Open a terminal and run: ollama pull gemma3:1b',
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
  }) async {
    if (!_ready) throw StateError('Ollama not connected. Call loadModel() first.');

    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('$_baseUrl/api/generate'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'model': _model,
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
            onToken?.call(token);
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
      final response = await request.close().timeout(const Duration(seconds: 3));
      await response.drain<void>();
      client.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
