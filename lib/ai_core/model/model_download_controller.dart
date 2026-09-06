import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ai_provider.dart';
import 'model_download_service.dart';
import 'model_manager.dart';
import 'model_package.dart';

final modelDownloadServiceProvider =
    Provider<ModelDownloadService>((ref) => ModelDownloadService());

/// Per-package download state, keyed by [ModelPackage.id].
final modelDownloadControllerProvider = StateNotifierProvider.family<
    ModelDownloadController, ModelDownloadState, ModelPackage>(
  (ref, pkg) => ModelDownloadController(ref, pkg),
);

class ModelDownloadController extends StateNotifier<ModelDownloadState> {
  ModelDownloadController(this._ref, this._pkg)
      : super(const ModelDownloadState());

  final Ref _ref;
  final ModelPackage _pkg;
  CancellationToken? _token;

  Future<void> start() async {
    if (state.isActive) return;
    final token = CancellationToken();
    _token = token;

    try {
      final targetPath = await _targetPath();
      await _ref.read(modelDownloadServiceProvider).download(
            _pkg,
            targetPath: targetPath,
            cancelToken: token,
            onState: (s) {
              if (mounted) state = s;
            },
          );

      // Discovery caches whether the file exists, so both model providers
      // have to be re-read before the tutor or translation engine will pick
      // the new file up without an app restart.
      _ref.invalidate(modelInfoProvider);
      _ref.invalidate(translateModelInfoProvider);
    } on ModelDownloadException catch (e) {
      debugPrint('model download (${_pkg.id}) failed: $e');
      // The service already emitted the failed state with its message.
    } finally {
      _token = null;
    }
  }

  void cancel() => _token?.cancel();

  /// The download lands exactly where model discovery already looks, so a
  /// finished download needs no extraction or copy step afterwards.
  Future<String> _targetPath() async {
    switch (_pkg.id) {
      case 'chat':
        return _ref.read(modelManagerProvider).installTargetPath();
      case 'translate':
        return _ref.read(translateModelManagerProvider).modelFilePath();
      default:
        throw ModelDownloadException('Unknown model package: ${_pkg.id}');
    }
  }
}

/// True when neither model is on the device yet — the state where the app
/// should lead with the download button rather than a USB instruction.
final anyModelMissingProvider = Provider<bool>((ref) {
  final chat = ref.watch(modelInfoProvider).valueOrNull;
  final translate = ref.watch(translateModelInfoProvider).valueOrNull;
  return chat?.status != ModelStatus.ready ||
      translate?.status != ModelStatus.ready;
});
