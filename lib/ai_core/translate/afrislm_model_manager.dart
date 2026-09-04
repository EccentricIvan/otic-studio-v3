import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../model/model_manager.dart' show ModelInfo, ModelStatus;

/// Locates and installs the TranslatePsy-AfriSLM translation model (GGUF).
///
/// Desktop loads this file into a local Ollama server (see
/// OllamaModelInstaller); Android will load it directly through a llama.cpp
/// binding once that engine exists. Both read the same canonical file below,
/// so there is one on-disk name regardless of platform or quant tier picked.
class AfriSlmModelManager {
  static const modelFileName = 'translate-afrislm.gguf';
  static const _markerFileName = 'translate-afrislm.install.json';
  // AfriSLM 0.8B Q4 is roughly 500MB-1GB; reject obvious truncations.
  static const _minSizeBytes = 300 * 1024 * 1024; // 300 MB

  Future<String> modelFilePath() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final appFiles = await getApplicationDocumentsDirectory();
      return p.join(appFiles.path, 'models', modelFileName);
    }
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'OTIC', modelFileName);
  }

  Future<ModelInfo> checkModel() async {
    final path = await modelFilePath();
    final file = File(path);
    if (!await file.exists()) {
      return const ModelInfo(status: ModelStatus.notInstalled);
    }

    final size = await file.length();
    if (size < _minSizeBytes) {
      return ModelInfo(status: ModelStatus.corrupted, path: path, sizeBytes: size);
    }
    return ModelInfo(status: ModelStatus.ready, path: path, sizeBytes: size);
  }

  /// Copies a user-picked GGUF file into the expected location. Mirrors
  /// ModelManager.installFromFile's atomic `.part` rename + size validation.
  Future<ModelInfo> installFromFile(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const AfriSlmInstallException('The selected file no longer exists.');
    }

    final ext = p.extension(sourcePath).toLowerCase();
    if (ext != '.gguf') {
      throw const AfriSlmInstallException(
        'Wrong file type. The translation model needs a .gguf file.',
      );
    }

    final size = await source.length();
    if (size < _minSizeBytes) {
      throw const AfriSlmInstallException(
        'That file is too small to be the AfriSLM translation model — it '
        'should be at least a few hundred MB. The download or copy may be '
        'incomplete.',
      );
    }

    final targetPath = await modelFilePath();
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
      await _writeMarker(sourceUrl: null, sizeBytes: size);
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      if (await partial.exists()) await partial.delete();
      if (e is FileSystemException) {
        throw const AfriSlmInstallException(
          'Could not copy the model — the device may not have enough '
          'free storage (about 1 GB is needed).',
        );
      }
      rethrow;
    }
    return checkModel();
  }

  /// Downloads the GGUF from a direct URL with progress, atomically
  /// installing it only once fully received.
  Future<ModelInfo> downloadModel(
    String url, {
    void Function(AfriSlmDownloadProgress progress)? onProgress,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AfriSlmInstallException('Enter a valid model URL.');
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const AfriSlmInstallException(
        'The model URL must start with http:// or https://.',
      );
    }

    final targetPath = await modelFilePath();
    final target = File(targetPath);
    await target.parent.create(recursive: true);

    final partial = File('$targetPath.part');
    if (await partial.exists()) await partial.delete();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..userAgent = 'AI Connect Africa AfriSLM downloader';

    IOSink? sink;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AfriSlmInstallException(
          'Download failed with HTTP ${response.statusCode}.',
        );
      }

      final total = response.contentLength > 0 ? response.contentLength : null;
      var received = 0;
      sink = partial.openWrite();

      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(
          AfriSlmDownloadProgress(receivedBytes: received, totalBytes: total),
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final size = await partial.length();
      if (size < _minSizeBytes) {
        throw const AfriSlmInstallException(
          'The downloaded file is too small for the AfriSLM model. '
          'Check that the URL points directly to a GGUF file.',
        );
      }

      if (await target.exists()) await target.delete();
      await partial.rename(targetPath);
      await _writeMarker(sourceUrl: uri.toString(), sizeBytes: size);
      return ModelInfo(status: ModelStatus.ready, path: targetPath, sizeBytes: size);
    } on AfriSlmInstallException {
      rethrow;
    } on FileSystemException {
      throw const AfriSlmInstallException(
        'Could not save the model. The device may not have enough free storage.',
      );
    } on SocketException catch (e) {
      throw AfriSlmInstallException('Network error: ${e.message}');
    } finally {
      client.close(force: true);
      try {
        await sink?.close();
      } catch (_) {}
      if (await partial.exists()) {
        try {
          await partial.delete();
        } catch (_) {}
      }
    }
  }

  Future<File> _markerFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, 'OTIC', _markerFileName));
  }

  Future<void> _writeMarker({
    required String? sourceUrl,
    required int sizeBytes,
  }) async {
    try {
      final marker = await _markerFile();
      await marker.parent.create(recursive: true);
      await marker.writeAsString(
        jsonEncode({
          'installed': true,
          'modelFileName': modelFileName,
          'sourceUrl': sourceUrl,
          'sizeBytes': sizeBytes,
          'installedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (_) {
      // Marker is informational only — never block install on it.
    }
  }
}

class AfriSlmInstallException implements Exception {
  const AfriSlmInstallException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AfriSlmDownloadProgress {
  const AfriSlmDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return receivedBytes / total;
  }
}
