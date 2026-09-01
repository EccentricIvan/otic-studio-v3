import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Soft offline illustration: a smiling child using a tablet.
class LearnerHeroIllustration extends StatelessWidget {
  const LearnerHeroIllustration({
    super.key,
    this.height = 168,
    this.variant = LearnerScene.soloTablet,
  });

  final double height;
  final LearnerScene variant;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Semantics(
      label: variant == LearnerScene.soloTablet
          ? 'Illustration of a smiling child using a learning tablet'
          : 'Illustration of two smiling children learning together',
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ac.isDark
                ? const [Color(0xFF152536), Color(0xFF1A2E44)]
                : const [Color(0xFFF3F9FD), Color(0xFFE8F4FC)],
          ),
          border: Border.all(color: ac.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _LearnerScenePainter(
            scene: variant,
            isDark: ac.isDark,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

enum LearnerScene { soloTablet, friends }

class _LearnerScenePainter extends CustomPainter {
  _LearnerScenePainter({required this.scene, required this.isDark});

  final LearnerScene scene;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackdrop(canvas, size);

    if (scene == LearnerScene.friends) {
      _drawChild(
        canvas,
        size,
        anchor: Offset(size.width * 0.34, size.height * 0.72),
        scale: 0.78,
        skin: const Color(0xFF8D5524),
        shirt: const Color(0xFF3DBE7A),
        withTablet: false,
      );
      _drawChild(
        canvas,
        size,
        anchor: Offset(size.width * 0.62, size.height * 0.74),
        scale: 0.86,
        skin: const Color(0xFF5C3A21),
        shirt: AppColors.primary,
        withTablet: true,
      );
    } else {
      _drawChild(
        canvas,
        size,
        anchor: Offset(size.width * 0.52, size.height * 0.78),
        scale: 1.0,
        skin: const Color(0xFF6B4226),
        shirt: AppColors.primary,
        withTablet: true,
      );
    }
  }

  void _drawBackdrop(Canvas canvas, Size size) {
    final soft = Paint()
      ..color = AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.10);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.28),
      size.height * 0.42,
      soft,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.2),
      size.height * 0.32,
      soft..color = const Color(0xFF1FA7A0).withValues(alpha: isDark ? 0.10 : 0.08),
    );

    // Soft ground
    final ground = Paint()
      ..color = (isDark ? const Color(0xFF24384F) : Colors.white)
          .withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.92),
        width: size.width * 0.78,
        height: size.height * 0.16,
      ),
      ground,
    );
  }

  void _drawChild(
    Canvas canvas,
    Size size, {
    required Offset anchor,
    required double scale,
    required Color skin,
    required Color shirt,
    required bool withTablet,
  }) {
    final unit = size.height * 0.12 * scale;
    final headCenter = Offset(anchor.dx, anchor.dy - unit * 3.2);
    final headR = unit * 1.15;

    // Body / shirt
    final body = Path()
      ..moveTo(anchor.dx - unit * 1.5, anchor.dy + unit * 0.2)
      ..quadraticBezierTo(
        anchor.dx,
        anchor.dy - unit * 2.1,
        anchor.dx + unit * 1.5,
        anchor.dy + unit * 0.2,
      )
      ..lineTo(anchor.dx + unit * 1.7, anchor.dy + unit * 1.4)
      ..quadraticBezierTo(
        anchor.dx,
        anchor.dy + unit * 0.7,
        anchor.dx - unit * 1.7,
        anchor.dy + unit * 1.4,
      )
      ..close();
    canvas.drawPath(body, Paint()..color = shirt);

    // Arms
    final armPaint = Paint()
      ..color = skin
      ..strokeWidth = unit * 0.42
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (withTablet) {
      canvas.drawLine(
        Offset(anchor.dx - unit * 1.15, anchor.dy - unit * 1.1),
        Offset(anchor.dx - unit * 0.35, anchor.dy - unit * 0.15),
        armPaint,
      );
      canvas.drawLine(
        Offset(anchor.dx + unit * 1.15, anchor.dy - unit * 1.1),
        Offset(anchor.dx + unit * 0.45, anchor.dy - unit * 0.05),
        armPaint,
      );
    } else {
      canvas.drawLine(
        Offset(anchor.dx + unit * 1.1, anchor.dy - unit * 1.15),
        Offset(anchor.dx + unit * 2.0, anchor.dy - unit * 0.55),
        armPaint,
      );
    }

    // Tablet
    if (withTablet) {
      final tab = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(anchor.dx, anchor.dy - unit * 0.35),
          width: unit * 2.6,
          height: unit * 1.7,
        ),
        Radius.circular(unit * 0.22),
      );
      canvas.drawRRect(tab, Paint()..color = const Color(0xFF1A2B3C));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(anchor.dx, anchor.dy - unit * 0.35),
            width: unit * 2.25,
            height: unit * 1.35,
          ),
          Radius.circular(unit * 0.12),
        ),
        Paint()..color = const Color(0xFFE8F4FC),
      );
      // App UI hints on tablet
      final ui = Paint()..color = AppColors.primary.withValues(alpha: 0.75);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            anchor.dx - unit * 0.95,
            anchor.dy - unit * 0.75,
            unit * 0.9,
            unit * 0.28,
          ),
          Radius.circular(unit * 0.08),
        ),
        ui,
      );
      canvas.drawCircle(
        Offset(anchor.dx + unit * 0.55, anchor.dy - unit * 0.45),
        unit * 0.22,
        Paint()..color = const Color(0xFF1FA7A0),
      );
    }

    // Head
    canvas.drawCircle(headCenter, headR, Paint()..color = skin);

    // Hair
    final hair = Paint()..color = const Color(0xFF1A120C);
    canvas.drawArc(
      Rect.fromCircle(center: headCenter.translate(0, -headR * 0.15), radius: headR * 1.05),
      math.pi * 1.05,
      math.pi * 0.95,
      true,
      hair,
    );
    canvas.drawCircle(
      headCenter.translate(-headR * 0.55, -headR * 0.55),
      headR * 0.28,
      hair,
    );
    canvas.drawCircle(
      headCenter.translate(headR * 0.5, -headR * 0.58),
      headR * 0.26,
      hair,
    );

    // Eyes
    final eye = Paint()..color = const Color(0xFF1A120C);
    canvas.drawCircle(headCenter.translate(-headR * 0.32, -headR * 0.05), headR * 0.09, eye);
    canvas.drawCircle(headCenter.translate(headR * 0.32, -headR * 0.05), headR * 0.09, eye);
    // Smile
    final smile = Paint()
      ..color = const Color(0xFF1A120C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = headR * 0.1
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: headCenter.translate(0, headR * 0.22),
        width: headR * 0.85,
        height: headR * 0.7,
      ),
      0.15,
      math.pi - 0.3,
      false,
      smile,
    );
    // Cheek blush
    final blush = Paint()..color = const Color(0xFFE86B6B).withValues(alpha: 0.28);
    canvas.drawCircle(headCenter.translate(-headR * 0.55, headR * 0.25), headR * 0.16, blush);
    canvas.drawCircle(headCenter.translate(headR * 0.55, headR * 0.25), headR * 0.16, blush);
  }

  @override
  bool shouldRepaint(covariant _LearnerScenePainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.isDark != isDark;
}
