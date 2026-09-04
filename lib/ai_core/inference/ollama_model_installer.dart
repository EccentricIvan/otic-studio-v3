import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The Ollama tag the AfriSLM translation model is registered under.
/// `ollama create` builds this tag locally from a USB-distributed GGUF —
/// never `ollama pull`ed over the internet.
const afriSlmOllamaTag = 'ai-connect-africa-translate';

class OllamaInstallException implements Exception {
  const OllamaInstallException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Registers a locally-distributed GGUF file as an Ollama model tag by
/// shelling out to `ollama create`, so translation works without ever
/// pulling a model over the internet.
class OllamaModelInstaller {
  Future<bool> isOllamaOnPath() async {
    try {
      final result = await Process.run('ollama', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Creates (or replaces) the `tag` model in the local Ollama server from
  /// `ggufPath`. Returns once `ollama create` finishes.
  Future<void> createFromGguf({
    required String ggufPath,
    String tag = afriSlmOllamaTag,
  }) async {
    if (!await File(ggufPath).exists()) {
      throw OllamaInstallException('Model file not found at $ggufPath.');
    }
    if (!await isOllamaOnPath()) {
      throw const OllamaInstallException(
        'Ollama isn\'t installed. Install it from ollama.com, then try again.',
      );
    }

    final modelfile = await _writeModelfile(ggufPath);
    try {
      final result = await Process.run(
        'ollama',
        ['create', tag, '-f', modelfile.path],
      );
      if (result.exitCode != 0) {
        throw OllamaInstallException(
          'ollama create failed: ${result.stderr ?? result.stdout}',
        );
      }
    } finally {
      try {
        await modelfile.delete();
      } catch (_) {}
    }
  }

  Future<File> _writeModelfile(String ggufPath) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, 'ai-connect-africa.Modelfile'));
    // A bare FROM pointing at the GGUF is enough — Ollama reads the chat
    // template embedded in the GGUF's metadata when present.
    await file.writeAsString('FROM ${p.absolute(ggufPath)}\n');
    return file;
  }
}
