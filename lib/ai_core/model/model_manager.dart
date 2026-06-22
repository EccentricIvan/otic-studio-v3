import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum ModelStatus {
  /// Model file found and ready to load.
  ready,

  /// No model file present — user must transfer via USB.
  notInstalled,

  /// Model file exists but is corrupted (wrong size / bad header).
  corrupted,
}

/// A user-facing problem while installing a model from a picked file.
class ModelInstallException implements Exception {
  const ModelInstallException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ModelInfo {
  const ModelInfo({
    required this.status,
    this.path,
    this.sizeBytes,
    this.platform,
  });

  final ModelStatus status;
  final String? path;
  final int? sizeBytes;
  final String? platform;

  bool get isReady => status == ModelStatus.ready;
}

/// Locates the Gemma 3 1B model file on the device.
///
/// Expected locations (checked in order):
///   Android  → <externalStorage>/OTIC/gemma-3-1b.bin
///              → <appFiles>/models/gemma-3-1b.bin
///   Windows  → <appDocuments>\OTIC\gemma-3-1b-q4_k_m.gguf
///   Linux    → <appDocuments>/OTIC/gemma-3-1b-q4_k_m.gguf
class ModelManager {
  static const _androidModelNames = ['gemma-model.bin', 'gemma-model.task'];
  static const _desktopModelName = 'gemma-3-1b-q4_k_m.gguf';
  // Minimum sane file size — reject obvious truncations
  static const _minSizeBytes = 200 * 1024 * 1024; // 200 MB

  Future<ModelInfo> checkModel() async {
    final candidates = await _candidatePaths();
    for (final path in candidates) {
      final file = File(path);
      if (!await file.exists()) continue;
      final size = await file.length();
      if (size < _minSizeBytes) {
        return ModelInfo(
          status: ModelStatus.corrupted,
          path: path,
          sizeBytes: size,
          platform: _platformLabel,
        );
      }
      return ModelInfo(
        status: ModelStatus.ready,
        path: path,
        sizeBytes: size,
        platform: _platformLabel,
      );
    }
    return const ModelInfo(status: ModelStatus.notInstalled);
  }

  Future<List<String>> _candidatePaths() async {
    final paths = <String>[];

    if (defaultTargetPlatform == TargetPlatform.android) {
      // External storage (USB-accessible)
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          for (final name in _androidModelNames) {
            paths.add(
              p.join(
                ext.parent.parent.parent.parent.path,
                'OTIC',
                name,
              ),
            );
          }
        }
      } catch (_) {}
      // App-internal files dir
      final appFiles = await getApplicationDocumentsDirectory();
      for (final name in _androidModelNames) {
        paths.add(p.join(appFiles.path, 'models', name));
      }
    } else {
      // Windows / Linux — Documents/OTIC/
      final docs = await getApplicationDocumentsDirectory();
      paths.add(p.join(docs.path, 'OTIC', _desktopModelName));
      // Also check next to the executable (dev convenience)
      paths.add(p.join(Directory.current.path, 'models', _desktopModelName));
    }
    return paths;
  }

  String get _platformLabel {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android (LiteRT-LM)';
      case TargetPlatform.windows:
        return 'Windows (Ollama)';
      case TargetPlatform.linux:
        return 'Linux (Ollama)';
      default:
        return 'Unknown';
    }
  }

  /// Destination used when the user installs a model through the app.
  Future<String> installTargetPath({String extension = '.task'}) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final name = extension == '.bin' ? 'gemma-model.bin' : 'gemma-model.task';
      final appFiles = await getApplicationDocumentsDirectory();
      return p.join(appFiles.path, 'models', name);
    }
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'OTIC', _desktopModelName);
  }

  /// Copies a user-picked model file into the expected location.
  ///
  /// Validates extension and size first, copies to a `.part` file and
  /// renames on success so an interrupted copy is never mistaken for a
  /// valid model. Reports progress as 0..1 through [onProgress].
  Future<ModelInfo> installFromFile(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const ModelInstallException('The selected file no longer exists.');
    }

    final allowed = defaultTargetPlatform == TargetPlatform.android
        ? const ['.bin', '.task']
        : const ['.gguf'];
    final ext = p.extension(sourcePath).toLowerCase();
    if (!allowed.contains(ext)) {
      throw ModelInstallException(
        'Wrong file type. This device needs a ${allowed.join(' or ')} '
        'model file.',
      );
    }

    final size = await source.length();
    if (size < _minSizeBytes) {
      throw const ModelInstallException(
        'That file is too small to be the Gemma model — it should be '
        'around 800 MB to 1 GB. The download or copy may be incomplete.',
      );
    }

    final targetPath = await installTargetPath(extension: ext);
    final target = File(targetPath);
    await target.parent.create(recursive: true);

    final partial = File('$targetPath.part');
    final sink = partial.openWrite();
    var copied = 0;
    try {
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
        copied += chunk.length;
        onProgress?.call(copied / size);
      }
      await sink.flush();
      await sink.close();
      if (await target.exists()) await target.delete();
      await partial.rename(targetPath);
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      if (await partial.exists()) await partial.delete();
      if (e is FileSystemException) {
        throw const ModelInstallException(
          'Could not copy the model — the device may not have enough '
          'free storage (about 1 GB is needed).',
        );
      }
      rethrow;
    }
    return checkModel();
  }

  /// Where to tell the user to put the model file.
  Future<String> installInstructions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Transfer the model file to your phone with a USB cable, then '
          'choose it with Install from file.\n\n'
          'Model: gemma3-1B-it-int4.task (~541 MB)\n'
          'Source: Download from Kaggle (Google Gemma 3 LiteRT tab).';
    }
    return 'Transfer the model file to this device, then choose it with '
        'Install from file.\n\n'
        'Model: gemma-3-1b-q4_k_m.gguf (~800 MB)\n'
        'Source: Download from Hugging Face (bartowski/gemma-3-1B-it-GGUF) '
        'on a device with internet.';
  }
}
