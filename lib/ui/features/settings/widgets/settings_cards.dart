import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';

/// Header card displayed at the top of `HouseholdSettingsSheet`.
class SettingsHeaderCard extends StatelessWidget {
  const SettingsHeaderCard({super.key, required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.creamCard,
        borderRadius: 20,
        shadowOffset: 3,
      ),
      child: Row(
        children: <Widget>[
          const SnoopMiniAvatar(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "⏰ $petName's Meal Schedule & Treats",
                  style: const TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.inkDark,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Syncs instantly across the whole pack',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card with `-` / `+` stepper for configuring the household's daily treat allowance (`1..20`).
class DailyTreatAllowanceCard extends StatelessWidget {
  const DailyTreatAllowanceCard({
    super.key,
    required this.petName,
    required this.dailyTreatLimit,
    required this.onChanged,
  });

  final String petName;
  final int dailyTreatLimit;
  final ValueChanged<int> onChanged;

  static const Key decrementKey = ValueKey<String>('settings_treat_limit_dec');
  static const Key incrementKey = ValueKey<String>('settings_treat_limit_inc');
  static const Key valueKey = ValueKey<String>('settings_treat_limit_value');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.creamCard,
        borderRadius: 18,
        borderWidth: 2,
        shadowOffset: 3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text(
                '🦴 Daily Treat Allowance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.inkDark,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    key: decrementKey,
                    onPressed: dailyTreatLimit > 1 ? () => onChanged(dailyTreatLimit - 1) : null,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Container(
                    key: valueKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: AppTheme.comicPillDecoration(
                      color: AppTheme.snoopCollarGold,
                      borderWidth: 1.6,
                    ),
                    child: Text(
                      '$dailyTreatLimit / day',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.inkDark,
                      ),
                    ),
                  ),
                  IconButton(
                    key: incrementKey,
                    onPressed: dailyTreatLimit < 20 ? () => onChanged(dailyTreatLimit + 1) : null,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Shows a gentle "Chonk Alert!" badge on the Treat Jar if '
            '$petName gets more than $dailyTreatLimit treats '
            'in one logical day.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared Neo-Brutalist notice/error banner inside `HouseholdSettingsSheet`.
class SettingsNoticeBanner extends StatelessWidget {
  const SettingsNoticeBanner({
    super.key,
    required this.backgroundColor,
    required this.leading,
    required this.message,
  });

  final Color backgroundColor;
  final Widget leading;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: AppTheme.comicCardDecoration(
        color: backgroundColor,
        borderRadius: 14,
        borderWidth: 1.8,
        shadowOffset: 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          leading,
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.inkDark,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
