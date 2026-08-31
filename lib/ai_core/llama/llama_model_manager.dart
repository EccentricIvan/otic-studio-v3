import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LlamaModelStatus {
  ready,
  notInstalled,
  corrupted,
}

class LlamaModelInfo {
  const LlamaModelInfo({
    required this.status,
    required this.path,
    this.sizeBytes,
    this.sourceUrl,
  });

  final LlamaModelStatus status;
  final String path;
  final int? sizeBytes;
  final String? sourceUrl;

  bool get isReady => status == LlamaModelStatus.ready;
}

class LlamaModelDownloadException implements Exception {
  const LlamaModelDownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LlamaDownloadProgress {
  const LlamaDownloadProgress({
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

class LlamaModelManager {
  static const modelFileName = 'llama-3.2-1b-q4_k_m.gguf';
  static const _markerFileName = 'llama-3.2-1b-q4_k_m.install.json';
  static const _minSizeBytes = 500 * 1024 * 1024;

  Future<LlamaModelInfo> checkModel() async {
    final modelPath = await modelFilePath();
    final model = File(modelPath);
    final sourceUrl = await _readSourceUrl();

    if (!await model.exists()) {
      return LlamaModelInfo(
        status: LlamaModelStatus.notInstalled,
        path: modelPath,
        sourceUrl: sourceUrl,
      );
    }

    final size = await model.length();
    if (size < _minSizeBytes) {
      return LlamaModelInfo(
        status: LlamaModelStatus.corrupted,
        path: modelPath,
        sizeBytes: size,
        sourceUrl: sourceUrl,
      );
    }

    await _writeMarker(sourceUrl: sourceUrl, sizeBytes: size);
    return LlamaModelInfo(
      status: LlamaModelStatus.ready,
      path: modelPath,
      sizeBytes: size,
      sourceUrl: sourceUrl,
    );
  }

  Future<LlamaModelInfo> downloadModel(
    String url, {
    void Function(LlamaDownloadProgress progress)? onProgress,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const LlamaModelDownloadException('Enter a valid model URL.');
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const LlamaModelDownloadException(
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
      ..userAgent = 'AI Connect Africa llama.cpp test downloader';

    IOSink? sink;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LlamaModelDownloadException(
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
          LlamaDownloadProgress(receivedBytes: received, totalBytes: total),
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final size = await partial.length();
      if (size < _minSizeBytes) {
        throw const LlamaModelDownloadException(
          'The downloaded file is too small for Llama 3.2 1B Q4_K_M. '
          'Check that the URL points directly to a GGUF file.',
        );
      }

      if (await target.exists()) await target.delete();
      await partial.rename(targetPath);
      await _writeMarker(sourceUrl: uri.toString(), sizeBytes: size);
      return LlamaModelInfo(
        status: LlamaModelStatus.ready,
        path: targetPath,
        sizeBytes: size,
        sourceUrl: uri.toString(),
      );
    } on LlamaModelDownloadException {
      rethrow;
    } on FileSystemException {
      throw const LlamaModelDownloadException(
        'Could not save the model. The device may not have enough free storage.',
      );
    } on SocketException catch (e) {
      throw LlamaModelDownloadException('Network error: ${e.message}');
    } catch (e) {
      final message = e.toString();
      if (_looksLikeOutOfMemory(message)) {
        throw const LlamaModelDownloadException(
          'The device ran out of memory while downloading the model.',
        );
      }
      throw LlamaModelDownloadException('Download failed: $e');
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

  Future<String> modelFilePath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'models', 'llama_cpp', modelFileName);
  }

  Future<File> _markerFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, 'models', 'llama_cpp', _markerFileName));
  }

  Future<String?> _readSourceUrl() async {
    try {
      final marker = await _markerFile();
      if (!await marker.exists()) return null;
      final json = jsonDecode(await marker.readAsString());
      if (json is Map<String, Object?>) return json['sourceUrl'] as String?;
    } catch (_) {}
    return null;
  }

  Future<void> _writeMarker({
    required String? sourceUrl,
    required int sizeBytes,
  }) async {
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
  }

  static bool _looksLikeOutOfMemory(String message) {
    final lower = message.toLowerCase();
    return lower.contains('outofmemory') ||
        lower.contains('out of memory') ||
        lower.contains('allocation failed');
  }
}
