import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Deterministic, offline-generated student portrait from a name seed.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.showRing = false,
  });

  final String name;
  final double size;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final seed = name.trim().isEmpty ? 'Learner' : name.trim();
    return Semantics(
      label: 'Avatar for $seed',
      child: Container(
        width: size,
        height: size,
        decoration: showRing
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 2,
                ),
              )
            : null,
        child: ClipOval(
          child: CustomPaint(
            painter: _GeneratedPortraitPainter(seed: seed),
            child: Center(
              child: Text(
                seed.isNotEmpty ? seed[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.34,
                  shadows: const [
                    Shadow(blurRadius: 6, color: Color(0x66000000)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneratedPortraitPainter extends CustomPainter {
  _GeneratedPortraitPainter({required this.seed});

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(_hash(seed));
    final palette = _palettes[rnd.nextInt(_palettes.length)];

    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.$1, palette.$2],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Soft abstract shapes — unique per student, no network needed.
    for (var i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.08 + rnd.nextDouble() * 0.12);
      final cx = size.width * (0.15 + rnd.nextDouble() * 0.7);
      final cy = size.height * (0.15 + rnd.nextDouble() * 0.7);
      final r = size.shortestSide * (0.12 + rnd.nextDouble() * 0.28);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    // Stylized head + shoulders silhouette
    final figure = Paint()..color = Colors.white.withValues(alpha: 0.22);
    final headR = size.shortestSide * 0.22;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.38),
      headR,
      figure,
    );
    final shoulder = Path()
      ..moveTo(size.width * 0.18, size.height)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.55,
        size.width * 0.82,
        size.height,
      )
      ..close();
    canvas.drawPath(shoulder, figure);
  }

  @override
  bool shouldRepaint(covariant _GeneratedPortraitPainter oldDelegate) =>
      oldDelegate.seed != seed;

  static int _hash(String s) {
    var h = 2166136261;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0x7fffffff;
    }
    return h;
  }

  static const _palettes = <(Color, Color)>[
    (Color(0xFF2E96E8), Color(0xFF1B6BB5)),
    (Color(0xFF1FA7A0), Color(0xFF147A75)),
    (Color(0xFFE89B2E), Color(0xFFC07416)),
    (Color(0xFF6B7FD7), Color(0xFF4A5BB8)),
    (Color(0xFFE86B6B), Color(0xFFC44545)),
    (Color(0xFF3DBE7A), Color(0xFF2A8F5A)),
    (Color(0xFF9B6BDE), Color(0xFF7448B0)),
    (Color(0xFF4A9BD9), Color(0xFF2E6FA8)),
  ];
}
