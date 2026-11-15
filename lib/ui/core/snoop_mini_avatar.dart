import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Cute circular cartoon badge of Snoop's fluffy black labradoodle face
/// with his golden collar accent and pink tongue / puppy eyes.
class SnoopMiniAvatar extends StatelessWidget {
  const SnoopMiniAvatar({super.key, this.size = 40, this.isHappy = true});

  final double size;
  final bool isHappy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isHappy ? AppTheme.fedSurface : AppTheme.hungrySurface,
        border: Border.all(color: AppTheme.inkDark, width: 2.2),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.inkDark,
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size.square(size),
          painter: _SnoopMiniAvatarPainter(isHappy: isHappy),
        ),
      ),
    );
  }
}

class _SnoopMiniAvatarPainter extends CustomPainter {
  const _SnoopMiniAvatarPainter({required this.isHappy});

  final bool isHappy;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.34;

    final coatPaint = Paint()..color = AppTheme.snoopCoatBlack;
    final highlightPaint = Paint()
      ..color = AppTheme.snoopCurlHighlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;

    // Floppy ears
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - r * 0.95, cy + r * 0.15),
        width: r * 0.65,
        height: r * 1.25,
      ),
      coatPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + r * 0.95, cy + r * 0.15),
        width: r * 0.65,
        height: r * 1.25,
      ),
      coatPaint,
    );

    // Golden collar accent at bottom
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + r * 0.95),
          width: r * 1.3,
          height: r * 0.35,
        ),
        Radius.circular(r * 0.2),
      ),
      Paint()..color = AppTheme.snoopCollarGold,
    );

    // Curly head circle + top curls
    canvas.drawCircle(Offset(cx, cy), r, coatPaint);
    canvas.drawCircle(
      Offset(cx - r * 0.35, cy - r * 0.82),
      r * 0.38,
      coatPaint,
    );
    canvas.drawCircle(Offset(cx, cy - r * 0.90), r * 0.42, coatPaint);
    canvas.drawCircle(
      Offset(cx + r * 0.35, cy - r * 0.82),
      r * 0.38,
      coatPaint,
    );

    // Top curl highlight
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy - r * 0.78), radius: r * 0.22),
      math.pi * 0.85,
      math.pi * 1.1,
      false,
      highlightPaint,
    );

    // Eyes
    if (isHappy) {
      final eyeArcPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.055
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx - r * 0.38, cy - r * 0.1),
          width: r * 0.42,
          height: r * 0.32,
        ),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        eyeArcPaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx + r * 0.38, cy - r * 0.1),
          width: r * 0.42,
          height: r * 0.32,
        ),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        eyeArcPaint,
      );
    } else {
      for (final dir in [-1.0, 1.0]) {
        final eyeOffset = Offset(cx + dir * r * 0.38, cy - r * 0.12);
        canvas.drawCircle(eyeOffset, r * 0.22, Paint()..color = Colors.white);
        canvas.drawCircle(
          eyeOffset,
          r * 0.13,
          Paint()..color = AppTheme.inkDark,
        );
        canvas.drawCircle(
          eyeOffset + Offset(-r * 0.05, -r * 0.05),
          r * 0.06,
          Paint()..color = Colors.white,
        );
      }
    }

    // Little pink tongue when happy
    if (isHappy) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + r * 0.18, cy + r * 0.52),
          width: r * 0.36,
          height: r * 0.46,
        ),
        Paint()..color = AppTheme.snoopTonguePink,
      );
    }

    // Boopable nose
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.18),
        width: r * 0.48,
        height: r * 0.32,
      ),
      Paint()..color = Colors.black,
    );
    canvas.drawCircle(
      Offset(cx - r * 0.08, cy + r * 0.13),
      r * 0.07,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _SnoopMiniAvatarPainter oldDelegate) =>
      oldDelegate.isHappy != isHappy;
}
