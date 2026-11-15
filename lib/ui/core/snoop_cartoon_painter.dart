import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Custom painter for Snoop — a curly black labradoodle reacting to mealtime
/// status with floppy ears, paws, golden collar, and food bowl.
class SnoopCartoonPainter extends CustomPainter {
  const SnoopCartoonPainter({required this.isFed});

  final bool isFed;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const headCy = 92.0;

    final coatPaint = Paint()
      ..color = AppTheme.snoopCoatBlack
      ..style = PaintingStyle.fill;
    final curlHighlightPaint = Paint()
      ..color = AppTheme.snoopCurlHighlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final muzzlePaint = Paint()
      ..color = const Color(0xFF2D2926)
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = AppTheme.inkDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Floppy curly Labradoodle ears (left & right)
    _drawCurlyEar(
      canvas,
      center: Offset(cx - 58, headCy + 8),
      angle: 0.22,
      coatPaint: coatPaint,
      curlHighlightPaint: curlHighlightPaint,
    );
    _drawCurlyEar(
      canvas,
      center: Offset(cx + 58, headCy + 8),
      angle: -0.22,
      coatPaint: coatPaint,
      curlHighlightPaint: curlHighlightPaint,
    );

    // 2. Shoulder / chest fluff & golden collar band
    _drawChestAndCollar(
      canvas,
      cx: cx,
      headCy: headCy,
      coatPaint: coatPaint,
      outlinePaint: outlinePaint,
    );

    // 3. Fluffy curly Labradoodle head silhouette (ring of overlapping curls)
    _drawCurlyHead(
      canvas,
      cx: cx,
      headCy: headCy,
      coatPaint: coatPaint,
      curlHighlightPaint: curlHighlightPaint,
    );

    // 4. Fluffy snout / muzzle with whisker puffs
    _drawMuzzle(
      canvas,
      cx: cx,
      headCy: headCy,
      muzzlePaint: muzzlePaint,
      curlHighlightPaint: curlHighlightPaint,
    );

    // 5. Mouth, tongue (when fed), or dramatic drool droplet (when hungry)
    if (isFed) {
      _drawFedMouth(canvas, cx: cx, headCy: headCy, outlinePaint: outlinePaint);
    } else {
      _drawHungryMouth(canvas, cx: cx, headCy: headCy);
    }

    // 6. Big boopable black nose with glossy highlight
    _drawNose(canvas, cx: cx, headCy: headCy);

    // 7. Expressive eyes & eyebrows
    if (isFed) {
      _drawFedEyes(canvas, cx: cx, headCy: headCy);
    } else {
      _drawHungryEyes(canvas, cx: cx, headCy: headCy);
    }

    // 8. Fluffy black paws resting on the edge beside the bowl
    _drawCurlyPaw(
      canvas,
      center: Offset(cx - 62, 168),
      coatPaint: coatPaint,
      curlHighlightPaint: curlHighlightPaint,
    );
    _drawCurlyPaw(
      canvas,
      center: Offset(cx + 62, 168),
      coatPaint: coatPaint,
      curlHighlightPaint: curlHighlightPaint,
    );

    // 9. Cartoon dog bowl in front of Snoop
    _drawFoodBowl(canvas, cx: cx, bottomY: 204, isFed: isFed);
  }

  void _drawChestAndCollar(
    Canvas canvas, {
    required double cx,
    required double headCy,
    required Paint coatPaint,
    required Paint outlinePaint,
  }) {
    final chestRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, headCy + 56), width: 84, height: 34),
      const Radius.circular(18),
    );
    canvas.drawRRect(chestRect, coatPaint);

    final collarRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, headCy + 46), width: 76, height: 12),
      const Radius.circular(8),
    );
    canvas.drawRRect(collarRect, Paint()..color = AppTheme.snoopCollarGold);
    canvas.drawRRect(collarRect, outlinePaint);
  }

  void _drawCurlyHead(
    Canvas canvas, {
    required double cx,
    required double headCy,
    required Paint coatPaint,
    required Paint curlHighlightPaint,
  }) {
    const headRadius = 46.0;
    canvas.drawCircle(Offset(cx, headCy), headRadius, coatPaint);
    const curlCount = 14;
    for (var i = 0; i < curlCount; i++) {
      final theta = (i * 2 * math.pi) / curlCount;
      final puffOffset = Offset(
        cx + math.cos(theta) * (headRadius - 4),
        headCy + math.sin(theta) * (headRadius - 6),
      );
      canvas.drawCircle(puffOffset, 15, coatPaint);
    }
    // Extra top floof crown curls
    canvas.drawCircle(Offset(cx - 14, headCy - 44), 16, coatPaint);
    canvas.drawCircle(Offset(cx, headCy - 48), 18, coatPaint);
    canvas.drawCircle(Offset(cx + 14, headCy - 44), 16, coatPaint);

    // Decorative curl highlight arcs on top head floof
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx - 12, headCy - 42), radius: 8),
      math.pi * 0.9,
      math.pi * 1.1,
      false,
      curlHighlightPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx + 4, headCy - 45), radius: 9),
      math.pi * 0.8,
      math.pi * 1.2,
      false,
      curlHighlightPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx + 20, headCy - 38), radius: 7),
      math.pi * 0.9,
      math.pi,
      false,
      curlHighlightPaint,
    );
  }

  void _drawMuzzle(
    Canvas canvas, {
    required double cx,
    required double headCy,
    required Paint muzzlePaint,
    required Paint curlHighlightPaint,
  }) {
    final snoutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, headCy + 17), width: 68, height: 42),
      const Radius.circular(22),
    );
    canvas.drawRRect(snoutRect, muzzlePaint);
    canvas.drawCircle(Offset(cx - 22, headCy + 19), 15, muzzlePaint);
    canvas.drawCircle(Offset(cx + 22, headCy + 19), 15, muzzlePaint);

    // Subtle snout highlight outline
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, headCy + 17), width: 68, height: 42),
      -math.pi * 0.85,
      math.pi * 0.7,
      false,
      curlHighlightPaint,
    );
  }

  void _drawFedMouth(
    Canvas canvas, {
    required double cx,
    required double headCy,
    required Paint outlinePaint,
  }) {
    // Rosy happy cheeks
    final blushPaint = Paint()..color = AppTheme.snoopTonguePink.withValues(alpha: 0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - 30, headCy + 12),
        width: 14,
        height: 8,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 30, headCy + 12),
        width: 14,
        height: 8,
      ),
      blushPaint,
    );

    // Goofy lolling pink tongue on the right side
    final tonguePath = Path()
      ..moveTo(cx + 2, headCy + 26)
      ..quadraticBezierTo(cx + 22, headCy + 28, cx + 20, headCy + 45)
      ..quadraticBezierTo(cx + 12, headCy + 54, cx + 3, headCy + 43)
      ..quadraticBezierTo(cx - 1, headCy + 35, cx + 2, headCy + 26)
      ..close();
    canvas.drawPath(tonguePath, Paint()..color = AppTheme.snoopTonguePink);
    canvas.drawPath(tonguePath, outlinePaint);

    // Tongue center groove
    canvas.drawLine(
      Offset(cx + 9, headCy + 30),
      Offset(cx + 12, headCy + 44),
      Paint()
        ..color = AppTheme.inkDark
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // Big happy W-smile
    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final leftSmile = Path()
      ..moveTo(cx, headCy + 19)
      ..quadraticBezierTo(cx - 10, headCy + 31, cx - 20, headCy + 22);
    final rightSmile = Path()
      ..moveTo(cx, headCy + 19)
      ..quadraticBezierTo(cx + 10, headCy + 31, cx + 20, headCy + 22);
    canvas.drawPath(leftSmile, smilePaint);
    canvas.drawPath(rightSmile, smilePaint);
  }

  void _drawHungryMouth(
    Canvas canvas, {
    required double cx,
    required double headCy,
  }) {
    // Hungry trembling puppy pout
    final poutPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final poutPath = Path()
      ..moveTo(cx - 13, headCy + 30)
      ..quadraticBezierTo(cx, headCy + 23, cx + 13, headCy + 30);
    canvas.drawPath(poutPath, poutPaint);

    // Dramatic cartoon drool droplet hanging from mouth corner
    final droolPath = Path()
      ..moveTo(cx + 14, headCy + 29)
      ..quadraticBezierTo(cx + 21, headCy + 40, cx + 16, headCy + 46)
      ..quadraticBezierTo(cx + 11, headCy + 48, cx + 10, headCy + 41)
      ..close();
    canvas.drawPath(droolPath, Paint()..color = AppTheme.snoopSkyAccent);
    canvas.drawPath(
      droolPath,
      Paint()
        ..color = AppTheme.inkDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _drawNose(Canvas canvas, {required double cx, required double headCy}) {
    final noseRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, headCy + 10), width: 24, height: 16),
      const Radius.circular(9),
    );
    canvas.drawRRect(noseRect, Paint()..color = const Color(0xFF0F0E0D));
    canvas.drawRRect(
      noseRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // White boop shine on nose
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 5, headCy + 6), width: 7, height: 4),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _drawFedEyes(
    Canvas canvas, {
    required double cx,
    required double headCy,
  }) {
    // Happy squinty arc eyes (^ ^)
    final happyEyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx - 19, headCy - 6),
        width: 18,
        height: 14,
      ),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      happyEyePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx + 19, headCy - 6),
        width: 18,
        height: 14,
      ),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      happyEyePaint,
    );

    // Relaxed cheerful eyebrows
    final browPaint = Paint()
      ..color = AppTheme.snoopCollarGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - 27, headCy - 20),
      Offset(cx - 12, headCy - 22),
      browPaint,
    );
    canvas.drawLine(
      Offset(cx + 12, headCy - 22),
      Offset(cx + 27, headCy - 20),
      browPaint,
    );
  }

  void _drawHungryEyes(
    Canvas canvas, {
    required double cx,
    required double headCy,
  }) {
    // Huge pleading soulful puppy-dog eyes with double catchlights
    for (final dir in [-1.0, 1.0]) {
      final eyeCenter = Offset(cx + dir * 19, headCy - 8);
      canvas.drawCircle(eyeCenter, 10.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        eyeCenter,
        8.0,
        Paint()..color = const Color(0xFF291D12),
      );
      canvas.drawCircle(eyeCenter, 5.2, Paint()..color = AppTheme.inkDark);
      // Big pleading catchlight
      canvas.drawCircle(
        eyeCenter + const Offset(-2.8, -2.8),
        3.2,
        Paint()..color = Colors.white,
      );
      // Secondary sparkle catchlight
      canvas.drawCircle(
        eyeCenter + const Offset(2.6, 2.4),
        1.5,
        Paint()..color = Colors.white,
      );
    }

    // Dramatic worried/pleading upturned eyebrows
    final pleadingBrowPaint = Paint()
      ..color = AppTheme.snoopCollarGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - 29, headCy - 18),
      Offset(cx - 11, headCy - 25),
      pleadingBrowPaint,
    );
    canvas.drawLine(
      Offset(cx + 11, headCy - 25),
      Offset(cx + 29, headCy - 18),
      pleadingBrowPaint,
    );
  }

  void _drawCurlyEar(
    Canvas canvas, {
    required Offset center,
    required double angle,
    required Paint coatPaint,
    required Paint curlHighlightPaint,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final earRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 32, height: 64),
      const Radius.circular(18),
    );
    canvas.drawRRect(earRect, coatPaint);

    // Curly bumps along outer edge of floppy ear
    for (final dy in [-20.0, -6.0, 8.0, 20.0]) {
      canvas.drawCircle(Offset(-10, dy), 11, coatPaint);
      canvas.drawCircle(Offset(10, dy), 11, coatPaint);
    }

    // Ear curl texture lines
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(0, -8), radius: 8),
      0.3,
      math.pi * 1.1,
      false,
      curlHighlightPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(0, 12), radius: 8),
      0.3,
      math.pi * 1.1,
      false,
      curlHighlightPaint,
    );

    canvas.restore();
  }

  void _drawCurlyPaw(
    Canvas canvas, {
    required Offset center,
    required Paint coatPaint,
    required Paint curlHighlightPaint,
  }) {
    final pawRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 34, height: 22),
      const Radius.circular(12),
    );
    canvas.drawRRect(pawRect, coatPaint);
    canvas.drawRRect(
      pawRect,
      Paint()
        ..color = AppTheme.snoopCurlHighlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Toe dividers
    canvas.drawLine(
      Offset(center.dx - 5, center.dy + 2),
      Offset(center.dx - 5, center.dy + 9),
      curlHighlightPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 5, center.dy + 2),
      Offset(center.dx + 5, center.dy + 9),
      curlHighlightPaint,
    );
  }

  void _drawFoodBowl(
    Canvas canvas, {
    required double cx,
    required double bottomY,
    required bool isFed,
  }) {
    final topY = bottomY - 30;
    final bowlPath = Path()
      ..moveTo(cx - 52, topY)
      ..lineTo(cx + 52, topY)
      ..lineTo(cx + 64, bottomY)
      ..lineTo(cx - 64, bottomY)
      ..close();

    final bowlColor = isFed ? AppTheme.fedPrimary : AppTheme.hungryPrimary;
    canvas.drawPath(bowlPath, Paint()..color = bowlColor);
    canvas.drawPath(
      bowlPath,
      Paint()
        ..color = AppTheme.inkDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round,
    );

    // Top inner opening ellipse of the bowl
    final rimRect = Rect.fromCenter(
      center: Offset(cx, topY),
      width: 104,
      height: 14,
    );
    canvas.drawOval(
      rimRect,
      Paint()..color = isFed ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
    );
    canvas.drawOval(
      rimRect,
      Paint()
        ..color = AppTheme.inkDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant SnoopCartoonPainter oldDelegate) => oldDelegate.isFed != isFed;
}
