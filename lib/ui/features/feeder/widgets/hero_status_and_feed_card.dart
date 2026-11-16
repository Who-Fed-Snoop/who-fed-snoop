import 'package:flutter/material.dart';

import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/household.dart';
import '../../../../domain/models/meal_window.dart';
import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';
import '../view_models/feeder_view_model.dart';

/// Primary hero card showing the active meal window, Snoop's state, and 1-tap feed CTA.
class HeroStatusAndFeedCard extends StatelessWidget {
  const HeroStatusAndFeedCard({
    super.key,
    required this.household,
    required this.window,
    required this.currentFeeding,
    required this.isFed,
    required this.isLoggingMeal,
    required this.isCompactHeight,
    required this.activeMemberName,
    this.yesterdayLogicalDate,
    required this.onTapFeed,
    required this.onTapExtraMeal,
    required this.onOpenSchedule,
  });

  static const Key feedButtonKey = Key('hero_feed_button');
  static const Key openScheduleButtonKey = Key('open_schedule_button');
  static const Key bonusMealButtonKey = Key('bonus_meal_button');

  final Household household;
  final ActiveMealWindow window;
  final FeedingEvent? currentFeeding;
  final bool isFed;
  final bool isLoggingMeal;
  final bool isCompactHeight;
  final String activeMemberName;
  final String? yesterdayLogicalDate;
  final VoidCallback onTapFeed;
  final VoidCallback onTapExtraMeal;
  final VoidCallback onOpenSchedule;

  String _formatLastFedSubtitle(FeedingEvent last) {
    final timeStr = FeederViewModel.formatTimeOfDay(last.fedAt);
    final label = last.effectiveLabel;
    if (last.windowDate == window.windowDate) {
      return 'Last fed: $label by ${last.fedByName} at $timeStr';
    }
    if (yesterdayLogicalDate != null && last.windowDate == yesterdayLogicalDate) {
      return 'Last fed: $label by ${last.fedByName} yesterday at $timeStr';
    }
    return 'Last fed: $label by ${last.fedByName} on ${last.windowDate} at $timeStr';
  }

  Widget _buildHeaderRow(Color accentColor) {
    final nextResetStr = FeederViewModel.formatTimeOfDay(
      window.nextTransitionTime,
    );
    final pillPadding = EdgeInsets.symmetric(
      horizontal: 10,
      vertical: isCompactHeight ? 3 : 5,
    );
    final labelSize = isCompactHeight ? 11.0 : 12.0;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: isCompactHeight ? 3 : 5,
          ),
          decoration: AppTheme.comicPillDecoration(
            color: accentColor.withValues(alpha: 0.18),
            borderColor: AppTheme.inkDark,
            borderWidth: 1.8,
          ),
          child: Text(
            '${window.emoji} ${window.label.toUpperCase()} WINDOW',
            style: TextStyle(
              color: AppTheme.inkDark,
              fontWeight: FontWeight.w900,
              fontSize: labelSize,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Container(
              padding: pillPadding,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                '⏰ Resets at $nextResetStr',
                style: TextStyle(
                  color: AppTheme.inkMuted,
                  fontSize: labelSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: openScheduleButtonKey,
                borderRadius: BorderRadius.circular(999),
                onTap: onOpenSchedule,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
                  child: Center(
                    widthFactor: 1.0,
                    child: Container(
                      padding: pillPadding,
                      decoration: AppTheme.comicPillDecoration(
                        color: Colors.white,
                        borderColor: AppTheme.inkDark,
                        borderWidth: 1.6,
                      ),
                      child: Text(
                        '⚙️ Schedule',
                        style: TextStyle(
                          color: AppTheme.inkDark,
                          fontSize: labelSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildFedSection(FeedingEvent feeding) {
    final headlineStyle = TextStyle(
      fontSize: isCompactHeight ? 21 : 26,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.4,
      height: 1.15,
      color: AppTheme.inkDark,
    );

    return <Widget>[
      Text(
        '✅ ${household.petName} is Fed!',
        textAlign: TextAlign.center,
        style: headlineStyle,
      ),
      SizedBox(height: isCompactHeight ? 2 : 6),
      Text(
        '${feeding.fedByName} fed ${household.petName} ${window.label} at ${FeederViewModel.formatTimeOfDay(feeding.fedAt)}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isCompactHeight ? 12.5 : 14.5,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: AppTheme.inkMuted,
        ),
      ),
      SizedBox(height: isCompactHeight ? 6 : 14),
      FilledButton.icon(
        key: feedButtonKey,
        onPressed: null,
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'ALREADY FED (${feeding.fedByName.toUpperCase()})',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        style: FilledButton.styleFrom(
          visualDensity: isCompactHeight ? VisualDensity.compact : VisualDensity.standard,
          padding: EdgeInsets.symmetric(
            vertical: isCompactHeight ? 10 : 16,
            horizontal: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.inkDark, width: 2),
          ),
        ),
      ),
      SizedBox(height: isCompactHeight ? 0 : 6),
      TextButton(
        key: bonusMealButtonKey,
        onPressed: isLoggingMeal ? null : onTapExtraMeal,
        style: TextButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          minimumSize: const Size(48, 44),
          foregroundColor: AppTheme.inkDark,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isLoggingMeal
                ? '🥣 Logging bonus meal...'
                : '🥣 Gave an extra scoop of kibble? Log bonus meal',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isCompactHeight ? 12 : 13,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildHungrySection() {
    final petName = household.petName;
    final subtitle = household.lastFeeding != null
        ? _formatLastFedSubtitle(household.lastFeeding!)
        : 'No meals logged yet today';

    return <Widget>[
      Text(
        '$petName needs ${window.label}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isCompactHeight ? 21 : 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.4,
          height: 1.15,
          color: AppTheme.inkDark,
        ),
      ),
      SizedBox(height: isCompactHeight ? 2 : 6),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isCompactHeight ? 12.5 : 14.5,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: AppTheme.inkMuted,
        ),
      ),
      SizedBox(height: isCompactHeight ? 8 : 16),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: AppTheme.inkDark,
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: FilledButton.icon(
          key: feedButtonKey,
          onPressed: isLoggingMeal ? null : onTapFeed,
          icon: Icon(
            isLoggingMeal ? Icons.hourglass_top : Icons.pets,
            size: isCompactHeight ? 20 : 24,
          ),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isLoggingMeal
                  ? 'LOGGING ${window.label.toUpperCase()}...'
                  : 'I FED ${petName.toUpperCase()} ${window.label.toUpperCase()}',
              style: TextStyle(
                fontSize: isCompactHeight ? 16 : 17.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.hungryPrimary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: isCompactHeight ? 12 : 18,
              horizontal: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.inkDark, width: 2.5),
            ),
          ),
        ),
      ),
      SizedBox(height: isCompactHeight ? 4 : 8),
      Text(
        '🐾 1 tap logs as $activeMemberName & alerts the pack',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isCompactHeight ? 11 : 12.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.inkMuted,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isFed ? AppTheme.fedSurface : AppTheme.hungrySurface;
    final accentColor = isFed ? AppTheme.fedPrimary : AppTheme.hungryPrimary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: isCompactHeight
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
          : const EdgeInsets.all(20),
      decoration: AppTheme.comicCardDecoration(
        color: surfaceColor,
        borderColor: AppTheme.inkDark,
        borderRadius: 24,
        borderWidth: 2.5,
        shadowOffset: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeaderRow(accentColor),
          SizedBox(height: isCompactHeight ? 4 : 12),
          SnoopMascotIllustration(
            isFed: isFed,
            mealLabel: window.label,
            petName: household.petName,
            fedByName: currentFeeding?.fedByName,
            compact: isCompactHeight,
          ),
          SizedBox(height: isCompactHeight ? 4 : 12),
          if (currentFeeding != null)
            ..._buildFedSection(currentFeeding!)
          else
            ..._buildHungrySection(),
        ],
      ),
    );
  }
}
