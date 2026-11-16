import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';

/// Builds the main Neo-Brutalist AppBar for `FeederView` with a 48dp Pack HQ pill.
AppBar buildFeederAppBar({
  required String petName,
  required String joinCode,
  required bool isFed,
  required Key packHqButtonKey,
  required VoidCallback onOpenPackHq,
}) {
  return AppBar(
    titleSpacing: 16,
    title: Row(
      children: <Widget>[
        SnoopMiniAvatar(size: 36, isHappy: isFed),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Who Fed $petName?',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  color: AppTheme.inkDark,
                  letterSpacing: -0.3,
                ),
              ),
              const Text(
                '90 lb Black Labradoodle • Official Belly Tracker',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: AppTheme.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 14),
        child: InkWell(
          key: packHqButtonKey,
          borderRadius: BorderRadius.circular(999),
          onTap: onOpenPackHq,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: AppTheme.comicPillDecoration(
                  color: AppTheme.snoopCollarGold,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.pets, size: 14, color: AppTheme.inkDark),
                    const SizedBox(width: 5),
                    Text(
                      'Pack: $joinCode',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: AppTheme.inkDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

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
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(Icons.close, color: dismissIconColor, size: 18),
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
        : (isUndoing
            ? '🦴 Reverting last action...'
            : '🦴 Accidental scoop? Undo within ${secondsRemaining}s');

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
              tapTargetSize: MaterialTapTargetSize.padded,
              minimumSize: const Size(64, 44),
              backgroundColor: AppTheme.snoopCollarGold,
              foregroundColor: AppTheme.inkDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: AppTheme.inkDark, width: 1.5),
              ),
            ),
            icon: Icon(isUndoing ? Icons.hourglass_top : Icons.undo, size: 16),
            label: Text(
              isUndoing ? 'Undoing...' : 'UNDO',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned header slot keeping [ErrorBanner] and [PartnerPushBanner] visible
/// regardless of [ListView] scroll offset.
class FeederPinnedBanners extends StatelessWidget {
  const FeederPinnedBanners({
    super.key,
    required this.errorMessage,
    required this.partnerBanner,
    required this.isCompactHeight,
    required this.onDismissError,
    required this.onDismissPartnerBanner,
  });

  final String? errorMessage;
  final String? partnerBanner;
  final bool isCompactHeight;
  final VoidCallback onDismissError;
  final VoidCallback onDismissPartnerBanner;

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null && partnerBanner == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isCompactHeight ? 4 : 8,
        16,
        isCompactHeight ? 2 : 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (errorMessage != null)
            ErrorBanner(
              message: errorMessage!,
              onDismiss: onDismissError,
            ),
          if (errorMessage != null && partnerBanner != null)
            SizedBox(height: isCompactHeight ? 4 : 8),
          if (partnerBanner != null)
            PartnerPushBanner(
              message: partnerBanner!,
              onDismiss: onDismissPartnerBanner,
            ),
        ],
      ),
    );
  }
}

/// Fallback view displayed when no household snapshot is available, exposing
/// any startup stream error and a Retry trigger.
class FeederEmptyStateScaffold extends StatelessWidget {
  const FeederEmptyStateScaffold({
    super.key,
    required this.errorMessage,
    required this.retryButtonKey,
    required this.onDismissError,
    required this.onRetry,
  });

  final String? errorMessage;
  final Key retryButtonKey;
  final VoidCallback onDismissError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (errorMessage != null) ...<Widget>[
                  ErrorBanner(
                    message: errorMessage!,
                    onDismiss: onDismissError,
                  ),
                  const SizedBox(height: 16),
                ],
                const Center(
                  child: SnoopMiniAvatar(size: 56, isHappy: false),
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage != null ? 'Unable to load household.' : 'No household configured.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.inkDark,
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: FilledButton.icon(
                    key: retryButtonKey,
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
