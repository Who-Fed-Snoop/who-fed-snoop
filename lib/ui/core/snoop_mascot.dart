import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Custom-drawn, cartoony, whimsical illustration of Snoop — a handsome, goofy,
/// 90 lb black labradoodle — reacting dramatically to his mealtime status.
class SnoopMascotIllustration extends StatelessWidget {
  const SnoopMascotIllustration({
    super.key,
    required this.isFed,
    required this.mealLabel,
    this.petName = 'Snoop',
    this.fedByName,
    this.compact = false,
  });

  final bool isFed;
  final String mealLabel;
  final String petName;
  final String? fedByName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final quoteText = isFed
        ? '"90 lbs of pure happiness! Thanks${fedByName != null ? ', $fedByName' : ''} for $mealLabel! *burp*"'
        : '"I am wasting away to a mere 89.9 lbs! Need $mealLabel!"';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Goofy comic speech bubble above Snoop (always outside FittedBox for crisp phone typography)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _ComicSpeechBubble(
            key: ValueKey<String>(
              'speech_${isFed}_${mealLabel}_${fedByName}_$compact',
            ),
            text: quoteText,
            isFed: isFed,
            compact: compact,
          ),
        ),
        SizedBox(height: compact ? 2 : 6),

        // Main cartoon canvas + floating status badges (scaled cleanly without affecting speech typography)
        SizedBox(
          height: compact ? 95 : 190,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 280,
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Subtle radial comic backdrop halo
                  Positioned(
                    top: 14,
                    child: Container(
                      width: 176,
                      height: 176,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFed
                            ? AppTheme.fedBorder.withValues(alpha: 0.35)
                            : AppTheme.hungryBorder.withValues(alpha: 0.40),
                        border: Border.all(
                          color: AppTheme.inkDark.withValues(alpha: 0.15),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  // Floating comic callout (top-left)
                  Positioned(
                    top: 6,
                    left: 4,
                    child: _FloatingComicSticker(
                      label: isFed ? '💖 BELLY FULL!' : '💭 RUMBLE...',
                      backgroundColor:
                          isFed ? const Color(0xFFFCE7F3) : Colors.white,
                      rotation: -0.10,
                    ),
                  ),

                  // Floating comic callout (top-right)
                  Positioned(
                    top: 10,
                    right: 4,
                    child: _FloatingComicSticker(
                      label: isFed ? '✨ YUM!' : '🦴 FEED ME?',
                      backgroundColor: isFed
                          ? AppTheme.snoopCollarGold
                          : const Color(0xFFFEF3C7),
                      rotation: 0.11,
                    ),
                  ),

                  // Custom-painted Snoop (curly black labradoodle, floppy ears, paws, bowl)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SnoopCartoonPainter(isFed: isFed),
                    ),
                  ),

                  // Golden dog tag pill at collar level ("SNOOP • 90 LB")
                  Positioned(
                    bottom: 44,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.snoopCollarGold,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.inkDark, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: AppTheme.inkDark,
                            offset: Offset(0, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        '${petName.toUpperCase()} • 90 LB',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppTheme.inkDark,
                        ),
                      ),
                    ),
                  ),

                  // Bowl front label ("YUM!" vs "EMPTY!")
                  Positioned(
                    bottom: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isFed
                            ? AppTheme.fedSurface
                            : AppTheme.hungrySurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.inkDark, width: 1.5),
                      ),
                      child: Text(
                        isFed ? '✨ LICKED CLEAN ✨' : '🥣 0% KIBBLE',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: AppTheme.inkDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComicSpeechBubble extends StatelessWidget {
  const _ComicSpeechBubble({
    super.key,
    required this.text,
    required this.isFed,
    required this.compact,
  });

  final String text;
  final bool isFed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: AppTheme.creamCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.inkDark, width: 2.2),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.inkDark,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isFed ? '😋' : '🥺',
                style: TextStyle(fontSize: compact ? 16 : 18),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 12.0 : 13.5,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.inkDark,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const CustomPaint(
          size: Size(18, 8),
          painter: _SpeechTailPainter(fillColor: AppTheme.creamCard),
        ),
      ],
    );
  }
}

class _SpeechTailPainter extends CustomPainter {
  const _SpeechTailPainter({required this.fillColor});

  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppTheme.inkDark
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, fillPaint);

    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(borderPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechTailPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor;
}

class _FloatingComicSticker extends StatelessWidget {
  const _FloatingComicSticker({
    required this.label,
    required this.backgroundColor,
    required this.rotation,
  });

  final String label;
  final Color backgroundColor;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.inkDark, width: 1.8),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.inkDark,
              offset: Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: AppTheme.inkDark,
          ),
        ),
      ),
    );
  }
}

class _SnoopCartoonPainter extends CustomPainter {
  const _SnoopCartoonPainter({required this.isFed});

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
    final chestRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, headCy + 56), width: 84, height: 34),
      const Radius.circular(18),
    );
    canvas.drawRRect(chestRect, coatPaint);

    final collarRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, headCy + 46), width: 76, height: 12),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      collarRect,
      Paint()..color = AppTheme.snoopCollarGold,
    );
    canvas.drawRRect(collarRect, outlinePaint);

    // 3. Fluffy curly Labradoodle head silhouette (ring of overlapping curls)
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

    // 4. Fluffy snout / muzzle with whisker puffs
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

    // 5. Mouth, tongue (when fed), or dramatic drool droplet (when hungry)
    if (isFed) {
      // Rosy happy cheeks
      final blushPaint = Paint()
        ..color = AppTheme.snoopTonguePink.withValues(alpha: 0.45);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 30, headCy + 12), width: 14, height: 8),
        blushPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 30, headCy + 12), width: 14, height: 8),
        blushPaint,
      );

      // Goofy lolling pink tongue on the right side
      final tonguePath = Path()
        ..moveTo(cx + 2, headCy + 26)
        ..quadraticBezierTo(cx + 22, headCy + 28, cx + 20, headCy + 45)
        ..quadraticBezierTo(cx + 12, headCy + 54, cx + 3, headCy + 43)
        ..quadraticBezierTo(cx - 1, headCy + 35, cx + 2, headCy + 26)
        ..close();
      canvas.drawPath(
        tonguePath,
        Paint()..color = AppTheme.snoopTonguePink,
      );
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
    } else {
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
      canvas.drawPath(
        droolPath,
        Paint()..color = AppTheme.snoopSkyAccent,
      );
      canvas.drawPath(
        droolPath,
        Paint()
          ..color = AppTheme.inkDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // 6. Big boopable black nose with glossy highlight
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

    // 7. Expressive eyes & eyebrows
    if (isFed) {
      // Happy squinty arc eyes (^ ^)
      final happyEyePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx - 19, headCy - 6), width: 18, height: 14),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        happyEyePaint,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx + 19, headCy - 6), width: 18, height: 14),
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
    } else {
      // Huge pleading soulful puppy-dog eyes with double catchlights
      for (final dir in [-1.0, 1.0]) {
        final eyeCenter = Offset(cx + dir * 19, headCy - 8);
        canvas.drawCircle(eyeCenter, 10.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          eyeCenter,
          8.0,
          Paint()..color = const Color(0xFF291D12),
        );
        canvas.drawCircle(
          eyeCenter,
          5.2,
          Paint()..color = AppTheme.inkDark,
        );
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

    final bowlColor =
        isFed ? AppTheme.fedPrimary : AppTheme.hungryPrimary;
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
      Paint()
        ..color = isFed ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
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
  bool shouldRepaint(covariant _SnoopCartoonPainter oldDelegate) =>
      oldDelegate.isFed != isFed;
}

/// Cute circular cartoon badge of Snoop's fluffy black labradoodle face
/// with his golden collar accent and pink tongue / puppy eyes.
class SnoopMiniAvatar extends StatelessWidget {
  const SnoopMiniAvatar({
    super.key,
    this.size = 40,
    this.isHappy = true,
  });

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
        border: Border.all(
          color: AppTheme.inkDark,
          width: 2.2,
        ),
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
    canvas.drawCircle(Offset(cx - r * 0.35, cy - r * 0.82), r * 0.38, coatPaint);
    canvas.drawCircle(Offset(cx, cy - r * 0.90), r * 0.42, coatPaint);
    canvas.drawCircle(Offset(cx + r * 0.35, cy - r * 0.82), r * 0.38, coatPaint);

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
        canvas.drawCircle(eyeOffset, r * 0.13, Paint()..color = AppTheme.inkDark);
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

/// Compact, whimsical wrap of cartoon mini-pills celebrating Snoop's personality.
class SnoopTraitBadges extends StatelessWidget {
  const SnoopTraitBadges({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        _TraitPill(
          label: '🐕‍🦺 90 lb Black Labradoodle',
          backgroundColor: Color(0xFFFEF3C7),
        ),
        _TraitPill(
          label: '✨ 100% Handsome',
          backgroundColor: Color(0xFFE0F2FE),
        ),
        _TraitPill(
          label: '🤪 Professional Goofball',
          backgroundColor: Color(0xFFFCE7F3),
        ),
      ],
    );
  }
}

class _TraitPill extends StatelessWidget {
  const _TraitPill({
    required this.label,
    required this.backgroundColor,
  });

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: AppTheme.comicPillDecoration(
        color: backgroundColor,
        borderColor: AppTheme.inkDark,
        borderWidth: 1.8,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w800,
          color: AppTheme.inkDark,
        ),
      ),
    );
  }
}
