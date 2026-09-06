import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_core/model/model_download_controller.dart';
import '../../ai_core/model/model_download_service.dart';
import '../../ai_core/model/model_manager.dart';
import '../../ai_core/model/model_package.dart';
import '../../ai_core/providers/ai_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_locale.dart';

/// "Fetch packages" — downloads the two model files from the GitHub release.
///
/// The models are not shipped inside the app (together they are ~1.2 GB,
/// far past Play's 500 MB base-module cap), so this is how a Play or
/// sideloaded install gets them. Each package is fetched separately: the
/// tutor model alone gives a working app in English, and on metered data
/// that distinction is worth real money to the student.
class FetchPackagesTile extends ConsumerWidget {
  const FetchPackagesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anyMissing = ref.watch(anyModelMissingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(
            anyMissing ? Icons.cloud_download_outlined : Icons.verified_outlined,
            color: anyMissing ? AppColors.primary : AppColors.teachColor,
          ),
          title: Text(tr(context, 'Fetch packages')),
          subtitle: Text(
            anyMissing
                ? tr(
                    context,
                    'Download the AI models to this device. Needs internet '
                    'once — the app runs offline afterwards.',
                  )
                : tr(context, 'All packages installed.'),
          ),
        ),
        for (final pkg in ModelPackage.all) _PackageRow(pkg: pkg),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PackageRow extends ConsumerWidget {
  const _PackageRow({required this.pkg});

  final ModelPackage pkg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelDownloadControllerProvider(pkg));
    final controller = ref.read(modelDownloadControllerProvider(pkg).notifier);
    final installed = _isInstalled(ref);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${pkg.label}  ·  ${_mb(pkg.approxBytes)} MB'
                  '${pkg.essential ? '' : ' · optional'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _action(context, state, controller, installed),
            ],
          ),
          if (state.isActive) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: state.fraction),
            const SizedBox(height: 4),
            Text(
              _progressLabel(context, state),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (state.phase == DownloadPhase.failed && state.error != null) ...[
            const SizedBox(height: 4),
            Text(
              state.error!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context,
    ModelDownloadState state,
    ModelDownloadController controller,
    bool installed,
  ) {
    if (state.isActive) {
      return TextButton(
        onPressed: controller.cancel,
        child: Text(tr(context, 'Cancel')),
      );
    }
    if (installed) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    }
    return FilledButton(
      onPressed: controller.start,
      child: Text(
        // A failed attempt resumes from where it stopped rather than
        // restarting, so the label should not imply starting over.
        state.phase == DownloadPhase.failed
            ? tr(context, 'Resume')
            : tr(context, 'Fetch'),
      ),
    );
  }

  bool _isInstalled(WidgetRef ref) {
    final info = pkg.id == 'chat'
        ? ref.watch(modelInfoProvider).valueOrNull
        : ref.watch(translateModelInfoProvider).valueOrNull;
    return info?.status == ModelStatus.ready;
  }

  String _progressLabel(BuildContext context, ModelDownloadState s) {
    switch (s.phase) {
      case DownloadPhase.connecting:
        return tr(context, 'Connecting…');
      case DownloadPhase.verifying:
        return tr(context, 'Checking the file is complete…');
      default:
        final total = s.totalBytes;
        final pct = s.fraction == null
            ? ''
            : ' · ${(s.fraction! * 100).toStringAsFixed(0)}%';
        return total == null
            ? '${_mb(s.receivedBytes)} MB'
            : '${_mb(s.receivedBytes)} / ${_mb(total)} MB$pct';
      }
  }

  static int _mb(int bytes) => (bytes / (1024 * 1024)).round();
}
