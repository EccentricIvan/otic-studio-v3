import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../translate/afrislm_model_manager.dart';
import 'model_manager.dart';

/// Result of ensuring APK-bundled models are on disk for the engines.
class BundledModelBootstrapResult {
  const BundledModelBootstrapResult({
    required this.chatReady,
    required this.translateReady,
    required this.extractedAnything,
    this.error,
  });

  final bool chatReady;
  final bool translateReady;
  final bool extractedAnything;
  final String? error;
}

/// Streams chat + translation models out of the Android APK asset pack into
/// the app documents `models/` folder on first launch.
///
/// Slim / debug APKs without those assets no-op and leave "Install from file"
/// as the install path. Desktop builds are skipped (they use exe-adjacent
/// `models/` from the release zip).
class BundledModelBootstrap {
  BundledModelBootstrap({
    ModelManager? chatManager,
    AfriSlmModelManager? translateManager,
  })  : _chat = chatManager ?? ModelManager(),
        _translate = translateManager ?? AfriSlmModelManager();

  static const _channelName = 'ai_connect_africa/bundled_models';
  static const chatAssetPath = 'models/${ModelManager.chatModelFileName}';
  static const translateAssetPath =
      'models/${AfriSlmModelManager.modelFileName}';

  final ModelManager _chat;
  final AfriSlmModelManager _translate;
  final MethodChannel _channel = const MethodChannel(_channelName);

  /// Reports 0..1 overall progress while extracting (null when nothing to do).
  Future<BundledModelBootstrapResult> ensureExtracted({
    void Function(double progress, String label)? onProgress,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      final chat = await _chat.checkModel();
      final translate = await _translate.checkModel();
      return BundledModelBootstrapResult(
        chatReady: chat.isReady,
        translateReady: translate.isReady,
        extractedAnything: false,
      );
    }

    try {
      final chatInfo = await _chat.checkModel();
      final translateInfo = await _translate.checkModel();
      final hasChatAsset = await _hasAsset(chatAssetPath);
      final hasTranslateAsset = await _hasAsset(translateAssetPath);

      var extracted = false;
      String? error;

      final steps = <({String asset, String dest, String label})>[];
      if (!chatInfo.isReady && hasChatAsset) {
        steps.add((
          asset: chatAssetPath,
          dest: await _chat.installTargetPath(),
          label: 'Chat model',
        ));
      }
      if (!translateInfo.isReady && hasTranslateAsset) {
        steps.add((
          asset: translateAssetPath,
          dest: await _translate.modelFilePath(),
          label: 'Translation model',
        ));
      }

      if (steps.isEmpty) {
        return BundledModelBootstrapResult(
          chatReady: chatInfo.isReady,
          translateReady: translateInfo.isReady,
          extractedAnything: false,
        );
      }

      for (var i = 0; i < steps.length; i++) {
        final step = steps[i];
        final base = i / steps.length;
        final span = 1.0 / steps.length;
        onProgress?.call(base, 'Preparing ${step.label}…');
        try {
          await _extract(
            assetPath: step.asset,
            destPath: step.dest,
            onProgress: (p) =>
                onProgress?.call(base + p * span, 'Preparing ${step.label}…'),
          );
          extracted = true;
        } catch (e) {
          error = e.toString();
          break;
        }
      }

      final chatAfter = await _chat.checkModel();
      final translateAfter = await _translate.checkModel();
      return BundledModelBootstrapResult(
        chatReady: chatAfter.isReady,
        translateReady: translateAfter.isReady,
        extractedAnything: extracted,
        error: error,
      );
    } on MissingPluginException {
      final chat = await _chat.checkModel();
      final translate = await _translate.checkModel();
      return BundledModelBootstrapResult(
        chatReady: chat.isReady,
        translateReady: translate.isReady,
        extractedAnything: false,
      );
    }
  }

  Future<bool> _hasAsset(String assetPath) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'hasBundledAsset',
        {'assetPath': assetPath},
      );
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _extract({
    required String assetPath,
    required String destPath,
    void Function(double progress)? onProgress,
  }) async {
    await Directory(p.dirname(destPath)).create(recursive: true);

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'extractProgress') return;
      final args = call.arguments;
      if (args is! Map) return;
      if (args['assetPath'] != assetPath) return;
      final progress = (args['progress'] as num?)?.toDouble();
      if (progress != null) onProgress?.call(progress);
    });

    try {
      await _channel.invokeMethod<bool>(
        'extractBundledAsset',
        {'assetPath': assetPath, 'destPath': destPath},
      );
    } on PlatformException catch (e) {
      throw StateError(e.message ?? e.toString());
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }
}
