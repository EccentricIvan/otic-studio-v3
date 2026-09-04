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

/// Locates the chat model (.litertlm) on the device — currently Qwen3-0.6B.
///
/// LiteRT-LM runs this file identically on Android, Windows, and Linux, so
/// there is a single canonical on-disk filename [chatModelFileName] instead
/// of a per-platform name — only the containing folder differs. Kept
/// model-agnostic (not e.g. "qwen3-chat.litertlm") since swapping the
/// backing model is just a ModelType change in litert_lm_engine.dart.
///
/// Expected locations (checked in order):
///   Android          → <externalStorage>/OTIC/chat-model.litertlm
///                       → <appFiles>/models/chat-model.litertlm
///   Windows / Linux  → <appDocuments>\OTIC\chat-model.litertlm
class ModelManager {
  static const chatModelFileName = 'chat-model.litertlm';
  // Minimum sane file size — reject obvious truncations. Smallest supported
  // quant (Qwen3-0.6B dynamic int4) is ~330 MB; leave margin below that.
  static const _minSizeBytes = 250 * 1024 * 1024; // 250 MB

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
          paths.add(
            p.join(
              ext.parent.parent.parent.parent.path,
              'OTIC',
              chatModelFileName,
            ),
          );
        }
      } catch (_) {}
      // App-internal files dir
      final appFiles = await getApplicationDocumentsDirectory();
      paths.add(p.join(appFiles.path, 'models', chatModelFileName));
    } else {
      // Windows / Linux — Documents/OTIC/
      final docs = await getApplicationDocumentsDirectory();
      paths.add(p.join(docs.path, 'OTIC', chatModelFileName));
      // Also check next to the executable (dev convenience)
      paths.add(p.join(Directory.current.path, 'models', chatModelFileName));
    }
    return paths;
  }

  String get _platformLabel {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android (LiteRT-LM)';
      case TargetPlatform.windows:
        return 'Windows (LiteRT-LM)';
      case TargetPlatform.linux:
        return 'Linux (LiteRT-LM)';
      default:
        return 'Unknown';
    }
  }

  /// Destination used when the user installs a model through the app.
  Future<String> installTargetPath() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final appFiles = await getApplicationDocumentsDirectory();
      return p.join(appFiles.path, 'models', chatModelFileName);
    }
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'OTIC', chatModelFileName);
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

    final ext = p.extension(sourcePath).toLowerCase();
    if (ext != '.litertlm') {
      throw const ModelInstallException(
        'Wrong file type. This device needs a .litertlm model file.',
      );
    }

    final size = await source.length();
    if (size < _minSizeBytes) {
      throw const ModelInstallException(
        'That file is too small to be the chat model — it should be at '
        'least a few hundred MB. The download or copy may be incomplete.',
      );
    }

    final targetPath = await installTargetPath();
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
    return 'Transfer the model file to this device, then choose it with '
        'Install from file.\n\n'
        'Model: Qwen3-0.6B .litertlm file (~330-590 MB depending on quant)\n'
        'Source: Download from Hugging Face '
        '(litert-community/Qwen3-0.6B) on a device with internet — '
        'Apache-2.0, no license click-through needed.';
  }
}
