import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Neo-brutalist comic speech bubble with a pointed tail used above Snoop's
/// illustration.
class ComicSpeechBubble extends StatelessWidget {
  const ComicSpeechBubble({
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

/// Tilted comic callout sticker floating around the Snoop mascot canvas.
class FloatingComicSticker extends StatelessWidget {
  const FloatingComicSticker({
    super.key,
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
  const _TraitPill({required this.label, required this.backgroundColor});

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
