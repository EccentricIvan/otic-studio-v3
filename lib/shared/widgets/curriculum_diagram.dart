import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a bundled curriculum diagram (SVG) with a fallback label.
class CurriculumDiagram extends StatelessWidget {
  const CurriculumDiagram({
    super.key,
    required this.assetPath,
    this.semanticLabel,
  });

  final String assetPath;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: SvgPicture.asset(
          assetPath,
          fit: BoxFit.contain,
          semanticsLabel: semanticLabel ?? 'Lesson diagram',
          placeholderBuilder: (_) => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ),
    );
  }
}
