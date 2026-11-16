import 'package:flutter/material.dart';

import '../../../../domain/models/meal_window.dart';
import '../../../core/app_theme.dart';

/// Summary card showing active meal windows and daily treat limit with an Edit trigger.
class ScheduleAndTreatGoalCard extends StatelessWidget {
  const ScheduleAndTreatGoalCard({
    super.key,
    this.cardKey = defaultCardKey,
    this.buttonKey = defaultButtonKey,
    required this.schedule,
    required this.dailyTreatLimit,
    required this.enabled,
    required this.onConfigure,
  });

  final Key cardKey;
  final Key buttonKey;
  final MealSchedule schedule;
  final int dailyTreatLimit;
  final bool enabled;
  final VoidCallback onConfigure;

  static const Key defaultCardKey = ValueKey<String>(
    'onboarding_schedule_settings_card',
  );
  static const Key defaultButtonKey = ValueKey<String>(
    'onboarding_open_schedule_settings_button',
  );

  static String formatScheduleSummary(MealSchedule schedule) {
    final windows = schedule.enabledWindows;
    if (windows.isEmpty) {
      return '🥣 Breakfast • 🍖 Dinner';
    }
    return windows.map((w) => '${w.emoji} ${w.label}').join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: cardKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onConfigure : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppTheme.comicCardDecoration(
            color: AppTheme.creamCard,
            borderRadius: 20,
            borderWidth: 2,
            shadowOffset: 3,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '⚙️ Meal Windows & Treat Goal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.inkDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatScheduleSummary(schedule),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.inkDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: AppTheme.comicPillDecoration(
                        color: AppTheme.hungrySurface,
                        borderWidth: 1.5,
                      ),
                      child: Text(
                        '🦴 $dailyTreatLimit treats/day',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.inkDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: buttonKey,
                onPressed: enabled ? onConfigure : null,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.snoopCollarGold,
                  foregroundColor: AppTheme.snoopCoatBlack,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  minimumSize: const Size(56, 44),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  side: const BorderSide(color: AppTheme.inkDark, width: 1.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section rendering the Partner Invite, NFC Food-Bin Sticker, and Dog Sitter Smart Links.
class PackHqSmartLinksSection extends StatelessWidget {
  const PackHqSmartLinksSection({
    super.key,
    required this.joinUri,
    required this.nfcTapUri,
    required this.sitterUri,
    this.copiedBannerMessage,
    required this.onCopyLink,
  });

  static const Key copiedBannerKey = ValueKey<String>('smart_link_copied_banner');

  final Uri joinUri;
  final Uri nfcTapUri;
  final Uri sitterUri;
  final String? copiedBannerMessage;
  final void Function(String label, Uri uri) onCopyLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: AppTheme.comicPillDecoration(
                color: AppTheme.snoopCollarGold,
                borderWidth: 1.8,
              ),
              child: const Text(
                'TAP TO COPY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: AppTheme.snoopCoatBlack,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'whofedsnoop.com Smart Links (Tap to Copy)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: AppTheme.inkDark,
                ),
              ),
            ),
          ],
        ),
        if (copiedBannerMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            key: copiedBannerKey,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: AppTheme.comicCardDecoration(
              color: AppTheme.fedSurface,
              borderColor: AppTheme.inkDark,
              borderRadius: 12,
              borderWidth: 1.8,
              shadowOffset: 2,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppTheme.fedPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    copiedBannerMessage!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.inkDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        SmartPassCard(
          icon: Icons.person_add_alt_1_outlined,
          badgeLabel: 'PACK INVITE',
          badgeColor: AppTheme.hungrySurface,
          accentColor: AppTheme.hungryPrimary,
          title: 'Partner Invite Link',
          subtitle: joinUri.toString(),
          onTap: () => onCopyLink('Partner Invite Link', joinUri),
        ),
        const SizedBox(height: 10),
        SmartPassCard(
          icon: Icons.nfc,
          badgeLabel: 'KIBBLE BIN',
          badgeColor: AppTheme.fedSurface,
          accentColor: AppTheme.fedPrimary,
          title: 'NFC Food-Bin Sticker URL',
          subtitle: nfcTapUri.toString(),
          onTap: () => onCopyLink('NFC Tag URL', nfcTapUri),
        ),
        const SizedBox(height: 10),
        SmartPassCard(
          icon: Icons.badge_outlined,
          badgeLabel: 'VIP SITTER',
          badgeColor: AppTheme.snoopSkyAccent.withValues(alpha: 0.2),
          accentColor: AppTheme.snoopCoatBlack,
          title: 'Dog Sitter Web Pass',
          subtitle: sitterUri.toString(),
          onTap: () => onCopyLink('Dog Sitter Web Pass', sitterUri),
        ),
      ],
    );
  }
}

/// Tap-to-copy Smart Link card used in Pack HQ for invite, NFC, and sitter passes.
class SmartPassCard extends StatelessWidget {
  const SmartPassCard({
    super.key,
    required this.icon,
    required this.badgeLabel,
    required this.badgeColor,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String badgeLabel;
  final Color badgeColor;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppTheme.comicCardDecoration(
            color: AppTheme.creamCard,
            borderRadius: 18,
            borderWidth: 2,
            shadowOffset: 3,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.inkDark, width: 2),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: AppTheme.inkDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: AppTheme.comicPillDecoration(
                            color: badgeColor,
                            borderWidth: 1.4,
                          ),
                          child: Text(
                            badgeLabel,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.inkDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.snoopCollarGold.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.inkDark, width: 1.5),
                ),
                child: const Icon(
                  Icons.copy,
                  size: 16,
                  color: AppTheme.snoopCoatBlack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
