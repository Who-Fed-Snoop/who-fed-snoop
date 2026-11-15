import 'package:flutter/material.dart';

import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/treat_event.dart';
import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';
import '../view_models/feeder_view_model.dart';

enum _BellyLogFilter { all, meals, treats }

class _BellyLogEntry {
  const _BellyLogEntry.meal(this.meal) : treat = null;
  const _BellyLogEntry.treat(this.treat) : meal = null;

  final FeedingEvent? meal;
  final TreatEvent? treat;

  String get logicalDate => meal != null ? meal!.windowDate : treat!.logicalDate;
  DateTime get timestamp => meal != null ? meal!.fedAt : treat!.givenAt;
}

/// Expandable 7-day Belly Log showing combined meal & treat history with filters.
class RecentHistorySection extends StatefulWidget {
  const RecentHistorySection({
    super.key,
    required this.petName,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.mealEvents,
    required this.treatEvents,
    required this.currentLogicalDate,
    this.yesterdayLogicalDate,
  });

  static const Key toggleButtonKey = Key('toggle_history_button');
  static const Key filterAllKey = Key('history_filter_all');
  static const Key filterMealsKey = Key('history_filter_meals');
  static const Key filterTreatsKey = Key('history_filter_treats');

  final String petName;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final List<FeedingEvent> mealEvents;
  final List<TreatEvent> treatEvents;
  final String currentLogicalDate;
  final String? yesterdayLogicalDate;

  @override
  State<RecentHistorySection> createState() => _RecentHistorySectionState();
}

class _RecentHistorySectionState extends State<RecentHistorySection> {
  _BellyLogFilter _filter = _BellyLogFilter.all;

  String _formatDateHeader(String date) {
    if (date == widget.currentLogicalDate) {
      return '📅 Today ($date)';
    }
    if (widget.yesterdayLogicalDate != null && date == widget.yesterdayLogicalDate) {
      return '📅 Yesterday ($date)';
    }
    return '📅 $date';
  }

  List<_BellyLogEntry> _filteredEntries() {
    final includeMeals = _filter != _BellyLogFilter.treats;
    final includeTreats = _filter != _BellyLogFilter.meals;
    return <_BellyLogEntry>[
      if (includeMeals)
        for (final meal in widget.mealEvents) _BellyLogEntry.meal(meal),
      if (includeTreats)
        for (final treat in widget.treatEvents) _BellyLogEntry.treat(treat),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries();
    final groupedByDate = <String, List<_BellyLogEntry>>{};
    for (final entry in entries) {
      groupedByDate.putIfAbsent(entry.logicalDate, () => <_BellyLogEntry>[]).add(entry);
    }
    final sortedDates = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    final mealCountByDate = <String, int>{};
    for (final meal in widget.mealEvents) {
      mealCountByDate[meal.windowDate] = (mealCountByDate[meal.windowDate] ?? 0) + 1;
    }
    final treatUnitsByDate = <String, int>{};
    final treatCaloriesByDate = <String, int>{};
    for (final treat in widget.treatEvents) {
      treatUnitsByDate[treat.logicalDate] =
          (treatUnitsByDate[treat.logicalDate] ?? 0) + treat.quantity;
      treatCaloriesByDate[treat.logicalDate] =
          (treatCaloriesByDate[treat.logicalDate] ?? 0) + treat.totalCalories;
    }

    final emptyMessage = switch (_filter) {
      _BellyLogFilter.all =>
        'No meals or treats logged yet — ${widget.petName} is awaiting kibble!',
      _BellyLogFilter.meals => 'No meals logged in the 7-day Belly Log yet.',
      _BellyLogFilter.treats => 'No treats logged in the 7-day Belly Log yet.',
    };

    final filterSpecs = <(_BellyLogFilter, Key, String)>[
      (
        _BellyLogFilter.all,
        RecentHistorySection.filterAllKey,
        'All (${widget.mealEvents.length + widget.treatEvents.length})',
      ),
      (
        _BellyLogFilter.meals,
        RecentHistorySection.filterMealsKey,
        '🥣 Meals (${widget.mealEvents.length})',
      ),
      (
        _BellyLogFilter.treats,
        RecentHistorySection.filterTreatsKey,
        '🦴 Treats (${widget.treatEvents.length})',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton.icon(
          key: RecentHistorySection.toggleButtonKey,
          onPressed: widget.onToggleExpanded,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppTheme.creamCard,
            foregroundColor: AppTheme.inkDark,
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: AppTheme.inkDark, width: 2),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: Icon(widget.isExpanded ? Icons.expand_less : Icons.history),
          label: Text(
            widget.isExpanded
                ? "Hide ${widget.petName}'s 7-Day Belly Log"
                : "Show ${widget.petName}'s 7-Day Belly Log",
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (widget.isExpanded) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              for (final (filterValue, chipKey, label) in filterSpecs)
                ChoiceChip(
                  key: chipKey,
                  label: Text(label),
                  selected: _filter == filterValue,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _filter = filterValue),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            for (final date in sortedDates) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      _formatDateHeader(date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        color: AppTheme.inkDark,
                      ),
                    ),
                    Text(
                      _buildDailySummaryBadge(
                        meals: mealCountByDate[date] ?? 0,
                        treats: treatUnitsByDate[date] ?? 0,
                        kcal: treatCaloriesByDate[date] ?? 0,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              for (final entry in groupedByDate[date]!)
                entry.meal != null
                    ? _MealHistoryCard(
                        petName: widget.petName,
                        event: entry.meal!,
                      )
                    : _TreatHistoryCard(
                        petName: widget.petName,
                        treat: entry.treat!,
                      ),
            ],
        ],
      ],
    );
  }

  static String _buildDailySummaryBadge({
    required int meals,
    required int treats,
    required int kcal,
  }) {
    final mealPart = '$meals ${meals == 1 ? 'meal' : 'meals'}';
    final treatPart = '$treats ${treats == 1 ? 'treat' : 'treats'}';
    if (treats > 0 && kcal > 0) {
      return '$mealPart • $treatPart ($kcal kcal)';
    }
    return '$mealPart • $treatPart';
  }
}

class _HistoryCardShell extends StatelessWidget {
  const _HistoryCardShell({
    required this.backgroundColor,
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  final Color backgroundColor;
  final Widget leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.comicCardDecoration(
        color: backgroundColor,
        borderRadius: 16,
        borderWidth: 2,
        shadowOffset: 2,
      ),
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppTheme.inkDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _MealHistoryCard extends StatelessWidget {
  const _MealHistoryCard({required this.petName, required this.event});

  final String petName;
  final FeedingEvent event;

  @override
  Widget build(BuildContext context) {
    return _HistoryCardShell(
      backgroundColor: AppTheme.creamCard,
      leading: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const SnoopMiniAvatar(size: 38, isHappy: true),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppTheme.snoopCollarGold,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.inkDark, width: 1.5),
              ),
              child: Text(
                event.effectiveEmoji,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
      title:
          '${event.fedByName} fed $petName ${event.effectiveLabel}${event.isExtraMeal ? " (Bonus)" : ""}',
      subtitle: '${event.windowDate} • ${FeederViewModel.formatTimeOfDay(event.fedAt)}',
    );
  }
}

class _TreatHistoryCard extends StatelessWidget {
  const _TreatHistoryCard({required this.petName, required this.treat});

  final String petName;
  final TreatEvent treat;

  @override
  Widget build(BuildContext context) {
    final qtyPrefix = treat.quantity > 1 ? '${treat.quantity}x ' : '';
    final trimmedNote = treat.note?.trim();
    final noteSuffix = (trimmedNote != null && trimmedNote.isNotEmpty) ? ' • “$trimmedNote”' : '';

    return _HistoryCardShell(
      backgroundColor: Colors.white,
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.snoopCollarGold.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.inkDark, width: 1.8),
        ),
        child: Text(treat.emoji, style: const TextStyle(fontSize: 18)),
      ),
      title: '${treat.givenByName} gave $petName $qtyPrefix${treat.label}',
      subtitle:
          '${treat.logicalDate} • ${FeederViewModel.formatTimeOfDay(treat.givenAt)} • ${treat.totalCalories} kcal$noteSuffix',
    );
  }
}
