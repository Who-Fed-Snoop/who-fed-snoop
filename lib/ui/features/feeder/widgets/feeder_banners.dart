import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Dismissible error banner shown when an action or stream sync fails.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  static const Key bannerKey = Key('feeder_error_banner');
  static const Key dismissButtonKey = Key('dismiss_error_button');

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _FeederStatusBanner(
      bannerKey: bannerKey,
      backgroundColor: const Color(0xFFFFEBEE),
      borderColor: AppTheme.inkDark,
      emoji: '⚠️ ',
      message: message,
      textColor: AppTheme.inkDark,
      fontWeight: FontWeight.w800,
      dismissButtonKey: dismissButtonKey,
      dismissTooltip: 'Dismiss error',
      dismissIconColor: AppTheme.inkDark,
      onDismiss: onDismiss,
    );
  }
}

/// High-contrast banner announcing a partner's recent feeding or treat action.
class PartnerPushBanner extends StatelessWidget {
  const PartnerPushBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _FeederStatusBanner(
      backgroundColor: AppTheme.snoopCoatBlack,
      borderColor: AppTheme.snoopCollarGold,
      emoji: '📣 ',
      message: message,
      textColor: Colors.white,
      fontWeight: FontWeight.w700,
      dismissIconColor: Colors.white70,
      onDismiss: onDismiss,
    );
  }
}

class _FeederStatusBanner extends StatelessWidget {
  const _FeederStatusBanner({
    this.bannerKey,
    required this.backgroundColor,
    required this.borderColor,
    required this.emoji,
    required this.message,
    required this.textColor,
    required this.fontWeight,
    this.dismissButtonKey,
    this.dismissTooltip,
    required this.dismissIconColor,
    required this.onDismiss,
  });

  final Key? bannerKey;
  final Color backgroundColor;
  final Color borderColor;
  final String emoji;
  final String message;
  final Color textColor;
  final FontWeight fontWeight;
  final Key? dismissButtonKey;
  final String? dismissTooltip;
  final Color dismissIconColor;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: bannerKey,
      decoration: AppTheme.comicCardDecoration(
        color: backgroundColor,
        borderColor: borderColor,
        borderRadius: 16,
        borderWidth: 2,
        shadowOffset: 3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: fontWeight,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            key: dismissButtonKey,
            tooltip: dismissTooltip,
            onPressed: onDismiss,
            icon: Icon(Icons.close, color: dismissIconColor, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Countdown bar allowing the user to undo the most recent meal or treat log.
class UndoBar extends StatelessWidget {
  const UndoBar({
    super.key,
    required this.bannerText,
    required this.secondsRemaining,
    required this.isUndoing,
    required this.onUndo,
  });

  static const Key undoButtonKey = Key('undo_feed_button');

  final String bannerText;
  final int secondsRemaining;
  final bool isUndoing;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final displayMessage = bannerText.isNotEmpty
        ? bannerText
        : '🦴 Accidental scoop? Undo within ${secondsRemaining}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.creamCard,
        borderColor: AppTheme.inkDark,
        borderRadius: 16,
        borderWidth: 2,
        shadowOffset: 3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              displayMessage,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppTheme.inkDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            key: undoButtonKey,
            onPressed: isUndoing ? null : onUndo,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: AppTheme.snoopCollarGold,
              foregroundColor: AppTheme.inkDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: AppTheme.inkDark, width: 1.5),
              ),
            ),
            icon: const Icon(Icons.undo, size: 16),
            label: const Text(
              'UNDO',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
