import 'package:flutter/material.dart';

import '../../../../domain/models/treat_event.dart';
import '../../../core/app_theme.dart';
import '../widgets/custom_treat_sheet.dart';
import '../widgets/treat_jar_rows.dart';

export '../widgets/custom_treat_sheet.dart' show CustomTreatSheet, OnLogCustomTreat;

/// Standalone Neo-Brutalist Material 3 card for Snoop's daily Treat Jar:
/// - Live daily treat count & calorie badge + soft over-limit warning ("Chonk Alert!")
/// - 1-tap quick preset chips + custom treat bottom sheet
/// - Expandable "Today's Treats" drawer with per-item delete action
class TreatJarCard extends StatefulWidget {
  const TreatJarCard({
    super.key,
    required this.petName,
    required this.todayTreats,
    required this.dailyTreatLimit,
    required this.currentMemberUid,
    this.isCompact = false,
    this.activeLoggingPreset,
    this.deletingTreatIds = const <String>{},
    required this.onLogPreset,
    required this.onLogCustomTreat,
    required this.onDeleteTreat,
    this.onOpenSettings,
  });

  final String petName;
  final List<TreatEvent> todayTreats;
  final int dailyTreatLimit;
  final String currentMemberUid;
  final bool isCompact;
  final TreatPreset? activeLoggingPreset;
  final Set<String> deletingTreatIds;
  final ValueChanged<TreatPreset> onLogPreset;
  final OnLogCustomTreat onLogCustomTreat;
  final ValueChanged<String> onDeleteTreat;
  final VoidCallback? onOpenSettings;

  static const Key cardKey = ValueKey<String>('treat_jar_card');
  static const Key allowancePillKey = ValueKey<String>('treat_allowance_pill');
  static const Key overLimitBannerKey = ValueKey<String>(
    'treat_over_limit_banner',
  );
  static const Key customTreatButtonKey = ValueKey<String>(
    'treat_custom_button',
  );
  static const Key drawerToggleKey = ValueKey<String>('treat_drawer_toggle');

  static ValueKey<String> presetChipKey(TreatPreset preset) =>
      ValueKey<String>('treat_preset_${preset.id}');

  static ValueKey<String> deleteTreatButtonKey(String treatId) =>
      TodayTreatRow.deleteButtonKey(treatId);

  static const List<TreatPreset> _quickPresets = <TreatPreset>[
    TreatPreset.trainingTreat,
    TreatPreset.dentalChew,
    TreatPreset.peanutButterKong,
    TreatPreset.crunchyBiscuit,
  ];

  @override
  State<TreatJarCard> createState() => _TreatJarCardState();
}

class _TreatJarCardState extends State<TreatJarCard> {
  bool _isDrawerExpanded = false;

  int get _totalTreatCount =>
      widget.todayTreats.fold<int>(0, (total, treat) => total + treat.quantity);

  int get _totalCalories => widget.todayTreats.fold<int>(
        0,
        (total, treat) => total + treat.totalCalories,
      );

  Future<void> _openCustomTreatSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomTreatSheet(
        petName: widget.petName,
        onSubmit: widget.onLogCustomTreat,
      ),
    );
  }

  static String _shortPresetLabel(TreatPreset preset) {
    switch (preset) {
      case TreatPreset.trainingTreat:
        return 'Training';
      case TreatPreset.dentalChew:
        return 'Dental Chew';
      case TreatPreset.peanutButterKong:
        return 'PB Kong';
      case TreatPreset.crunchyBiscuit:
        return 'Biscuit';
      case TreatPreset.custom:
        return 'Custom';
    }
  }

  static String _formatClockTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final sortedTreats = List<TreatEvent>.of(widget.todayTreats)
      ..sort((a, b) => b.givenAt.compareTo(a.givenAt));
    final count = _totalTreatCount;
    final calories = _totalCalories;
    final limit = widget.dailyTreatLimit;
    final isOverLimit = count > limit;
    final overBy = count - limit;

    final pillBgColor = isOverLimit
        ? AppTheme.snoopTonguePink.withValues(alpha: 0.30)
        : (count > 0 ? AppTheme.fedSurface : AppTheme.snoopCollarGold.withValues(alpha: 0.32));

    final pillText = isOverLimit
        ? '⚠️ $count / $limit TREATS • CHONK ALERT!'
        : '$count / $limit TREATS • $calories KCAL';

    return Container(
      key: TreatJarCard.cardKey,
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCompact ? 14 : 16,
        vertical: widget.isCompact ? 10 : 14,
      ),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.creamCard,
        borderColor: AppTheme.inkDark,
        borderRadius: 22,
        borderWidth: 2.2,
        shadowOffset: 3.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header + Daily Allowance Pill
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                "🦴 ${widget.petName.toUpperCase()}'S TREAT JAR",
                style: TextStyle(
                  fontSize: widget.isCompact ? 13 : 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: AppTheme.inkDark,
                ),
              ),
              InkWell(
                key: TreatJarCard.allowancePillKey,
                onTap: widget.onOpenSettings,
                borderRadius: BorderRadius.circular(999),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
                  child: Center(
                    widthFactor: 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: AppTheme.comicPillDecoration(
                        color: pillBgColor,
                        borderColor: AppTheme.inkDark,
                        borderWidth: 1.7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              pillText,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.inkDark,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (widget.onOpenSettings != null) ...<Widget>[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.tune,
                              size: 13,
                              color: AppTheme.inkDark,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Soft Over-Limit Warning Banner (never blocks truthful logging)
          if (isOverLimit) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              key: TreatJarCard.overLimitBannerKey,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppTheme.comicCardDecoration(
                color: AppTheme.snoopTonguePink.withValues(alpha: 0.16),
                borderColor: AppTheme.inkDark,
                borderRadius: 14,
                borderWidth: 1.8,
                shadowOffset: 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('🐾 ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      'Easy on the snacks! ${widget.petName} is +$overBy over the '
                      '$limit-treat daily goal ($calories kcal today).',
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
            ),
          ],

          SizedBox(height: widget.isCompact ? 8 : 10),

          // 1-Tap Preset Chips + Custom Button
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              for (final preset in TreatJarCard._quickPresets)
                QuickTreatChip(
                  key: TreatJarCard.presetChipKey(preset),
                  emoji: preset.emoji,
                  label: _shortPresetLabel(preset),
                  calories: preset.defaultCalories,
                  backgroundColor: AppTheme.hungrySurface,
                  isLoading: widget.activeLoggingPreset == preset,
                  enabled: widget.activeLoggingPreset == null,
                  onTap: () => widget.onLogPreset(preset),
                ),
              QuickTreatChip(
                key: TreatJarCard.customTreatButtonKey,
                emoji: '✨',
                label: '+ Custom',
                backgroundColor: AppTheme.snoopCollarGold.withValues(
                  alpha: 0.35,
                ),
                isLoading: widget.activeLoggingPreset == TreatPreset.custom,
                enabled: widget.activeLoggingPreset == null,
                onTap: _openCustomTreatSheet,
              ),
            ],
          ),

          SizedBox(height: widget.isCompact ? 6 : 8),

          // Expandable Today's Treats Drawer
          InkWell(
            key: TreatJarCard.drawerToggleKey,
            onTap: () => setState(() => _isDrawerExpanded = !_isDrawerExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.pageBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.inkDark, width: 1.6),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      sortedTreats.isEmpty
                          ? 'No treats logged yet today (${(limit - count).clamp(0, limit)} left in daily goal)'
                          : (_isDrawerExpanded
                              ? "Hide Today's Treats (${sortedTreats.length})"
                              : _buildCollapsedSummary(sortedTreats)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.inkDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isDrawerExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppTheme.inkDark,
                  ),
                ],
              ),
            ),
          ),

          if (_isDrawerExpanded) ...<Widget>[
            const SizedBox(height: 8),
            if (sortedTreats.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Tap any preset above when Snoop earns a snack!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkMuted,
                  ),
                ),
              )
            else
              for (final treat in sortedTreats)
                TodayTreatRow(
                  treat: treat,
                  timeString: _formatClockTime(treat.givenAt),
                  isDeleting: widget.deletingTreatIds.contains(treat.id),
                  onDelete: () => widget.onDeleteTreat(treat.id),
                ),
          ],
        ],
      ),
    );
  }

  String _buildCollapsedSummary(List<TreatEvent> sortedTreats) {
    final latest = sortedTreats.first;
    final qtySuffix = latest.quantity > 1 ? ' (x${latest.quantity})' : '';
    final timeStr = _formatClockTime(latest.givenAt);
    return 'Latest: ${latest.emoji} ${latest.label}$qtySuffix by '
        '${latest.givenByName} at $timeStr • View (${sortedTreats.length})';
  }
}
