import 'package:flutter_gemma/flutter_gemma.dart';
import 'inference_engine.dart';

/// Android engine — Google LiteRT-LM runtime via flutter_gemma 1.x.
/// Runs Gemma 3 1B entirely on-device (GPU delegate when available).
class LiteRtLmEngineImpl extends InferenceEngine {
  InferenceModel? _model;

  @override
  bool get isReady => _model != null;

  @override
  String get backendLabel => 'LiteRT-LM · Gemma 3 1B';

  @override
  Future<void> loadModel(String modelPath) async {
    try {
      final installed = await FlutterGemma.isModelInstalled('gemma');
      if (!installed) {
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
        ).fromFile(modelPath).install();
      }
      _model = await FlutterGemma.getActiveModel(maxTokens: 512);
    } catch (e) {
      throw ModelLoadException('LiteRT-LM failed to load "$modelPath": $e');
    }
  }

  @override
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    TokenCallback? onToken,
  }) async {
    if (_model == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    final chat = await _model!.createChat(maxOutputTokens: maxTokens);
    chat.addQueryChunk(Message.text(text: prompt, isUser: true));

    final buffer = StringBuffer();
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        final token = response.token;
        if (token.isNotEmpty) {
          buffer.write(token);
          onToken?.call(token);
        }
      }
    }
    return buffer.toString();
  }

  @override
  Future<void> dispose() async {
    _model?.close();
    _model = null;
  }
}
