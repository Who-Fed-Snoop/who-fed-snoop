import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'comic_speech_bubble.dart';
import 'snoop_cartoon_painter.dart';

export 'comic_speech_bubble.dart';
export 'snoop_mini_avatar.dart';

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
          child: ComicSpeechBubble(
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
                    child: FloatingComicSticker(
                      label: isFed ? '💖 BELLY FULL!' : '💭 RUMBLE...',
                      backgroundColor: isFed ? const Color(0xFFFCE7F3) : Colors.white,
                      rotation: -0.10,
                    ),
                  ),

                  // Floating comic callout (top-right)
                  Positioned(
                    top: 10,
                    right: 4,
                    child: FloatingComicSticker(
                      label: isFed ? '✨ YUM!' : '🦴 FEED ME?',
                      backgroundColor: isFed ? AppTheme.snoopCollarGold : const Color(0xFFFEF3C7),
                      rotation: 0.11,
                    ),
                  ),

                  // Custom-painted Snoop (curly black labradoodle, floppy ears, paws, bowl)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SnoopCartoonPainter(isFed: isFed),
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
                        color: isFed ? AppTheme.fedSurface : AppTheme.hungrySurface,
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
