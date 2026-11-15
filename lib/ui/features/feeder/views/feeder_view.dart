import 'package:flutter/material.dart';

import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/household.dart';
import '../../../../domain/models/meal_window.dart';
import '../../../../domain/models/treat_event.dart';
import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';
import '../../onboarding/views/onboarding_sheet.dart';
import '../../onboarding/views/scoop_holder_prompt_dialog.dart';
import '../../settings/views/household_settings_sheet.dart';
import '../../treats/views/treat_jar_card.dart';
import '../view_models/feeder_view_model.dart';

/// Main single-screen view designed around the "2-Second Rule":
/// 1. Glance immediately at Snoop's current meal window & daily treat jar state.
/// 2. Tap once to mark Snoop fed or log a treat and notify your partner.
class FeederView extends StatefulWidget {
  const FeederView({super.key, required this.viewModel});

  final FeederViewModel viewModel;

  static const Key heroFeedButtonKey = Key('hero_feed_button');
  static const Key undoFeedButtonKey = Key('undo_feed_button');
  static const Key toggleHistoryButtonKey = Key('toggle_history_button');
  static const Key openScheduleButtonKey = Key('open_schedule_button');
  static const Key openPackHqButtonKey = Key('open_pack_hq_button');
  static const Key bonusMealButtonKey = Key('bonus_meal_button');
  static const Key errorBannerKey = Key('feeder_error_banner');
  static const Key dismissErrorButtonKey = Key('dismiss_error_button');
  static const Key historyFilterAllKey = Key('history_filter_all');
  static const Key historyFilterMealsKey = Key('history_filter_meals');
  static const Key historyFilterTreatsKey = Key('history_filter_treats');

  @override
  State<FeederView> createState() => _FeederViewState();
}

class _FeederViewState extends State<FeederView> {
  bool _isScoopPromptOpen = false;
  bool _promptCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_handleViewModelChanged);
    _schedulePromptCheck();
  }

  @override
  void didUpdateWidget(covariant FeederView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_handleViewModelChanged);
      widget.viewModel.addListener(_handleViewModelChanged);
      _schedulePromptCheck();
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_handleViewModelChanged);
    super.dispose();
  }

  void _handleViewModelChanged() {
    if (widget.viewModel.needsScoopHolderPrompt && !_isScoopPromptOpen) {
      _schedulePromptCheck();
    }
  }

  void _schedulePromptCheck() {
    if (_promptCheckScheduled) return;
    _promptCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptCheckScheduled = false;
      _maybeShowScoopHolderPrompt();
    });
  }

  Future<void> _maybeShowScoopHolderPrompt() async {
    if (!mounted ||
        _isScoopPromptOpen ||
        widget.viewModel.isLoading ||
        widget.viewModel.household == null ||
        !widget.viewModel.needsScoopHolderPrompt) {
      return;
    }

    _isScoopPromptOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ScoopHolderPromptDialog(viewModel: widget.viewModel),
      );
    } finally {
      _isScoopPromptOpen = false;
    }
  }

  void _openHouseholdSettings(BuildContext context, Household household) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HouseholdSettingsSheet(
        petName: household.petName,
        initialSchedule: widget.viewModel.schedule,
        initialDailyTreatLimit: widget.viewModel.dailyTreatLimit,
        todayLoggedWindowIds: widget.viewModel.todayLoggedWindowIds,
        onSave: (schedule, dailyTreatLimit) => widget.viewModel.updateHouseholdSettings(
          schedule: schedule,
          dailyTreatLimit: dailyTreatLimit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final household = viewModel.household;
        if (household == null) {
          return const Scaffold(
            body: Center(child: Text('No household configured.')),
          );
        }

        final window = viewModel.activeWindow;
        final currentFeeding = viewModel.currentWindowFeeding;
        final isFed = currentFeeding != null;
        final screenSize = MediaQuery.sizeOf(context);
        final isCompactHeight = screenSize.height < 680;
        final sectionGap = isCompactHeight ? 6.0 : 14.0;

        return Scaffold(
          appBar: AppBar(
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
                        'Who Fed ${household.petName}?',
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
                  key: FeederView.openPackHqButtonKey,
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => OnboardingSheet(viewModel: viewModel),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: AppTheme.comicPillDecoration(
                      color: AppTheme.snoopCollarGold,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.pets,
                          size: 14,
                          color: AppTheme.inkDark,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Pack: ${household.joinCode}',
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
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isCompactHeight ? 4 : 12,
              ),
              children: <Widget>[
                const SnoopTraitBadges(),
                if (viewModel.errorMessage != null) ...<Widget>[
                  SizedBox(height: sectionGap),
                  _ErrorBanner(
                    message: viewModel.errorMessage!,
                    onDismiss: viewModel.dismissError,
                  ),
                ],
                if (viewModel.partnerNotificationBanner != null) ...<Widget>[
                  SizedBox(height: sectionGap),
                  _PartnerPushBanner(
                    message: viewModel.partnerNotificationBanner!,
                    onDismiss: viewModel.dismissPartnerBanner,
                  ),
                ],
                SizedBox(height: sectionGap),
                _HeroStatusAndFeedCard(
                  household: household,
                  window: window,
                  currentFeeding: currentFeeding,
                  isFed: isFed,
                  isLoggingMeal: viewModel.isLoggingMeal,
                  isCompactHeight: isCompactHeight,
                  activeMemberName: viewModel.currentMemberName,
                  onTapFeed: () => viewModel.markPetFed(),
                  onTapExtraMeal: () => viewModel.markPetFed(isExtraMeal: true),
                  onOpenSchedule: () => _openHouseholdSettings(context, household),
                ),
                if (viewModel.canUndo) ...<Widget>[
                  SizedBox(height: sectionGap),
                  _UndoBar(
                    bannerText: viewModel.undoBannerText,
                    secondsRemaining: viewModel.undoSecondsRemaining,
                    isUndoing: viewModel.isUndoing,
                    onUndo: viewModel.undoLastAction,
                  ),
                ],
                SizedBox(height: isCompactHeight ? 8 : 14),
                TreatJarCard(
                  petName: household.petName,
                  todayTreats: viewModel.todayTreats,
                  dailyTreatLimit: viewModel.dailyTreatLimit,
                  currentMemberUid: viewModel.currentMemberUid,
                  isCompact: isCompactHeight,
                  onLogPreset: (preset) {
                    viewModel.logQuickTreat(preset);
                  },
                  onLogCustomTreat: ({
                    required label,
                    required quantity,
                    required caloriesPerUnit,
                    note,
                  }) async {
                    await viewModel.logCustomTreat(
                      label: label,
                      quantity: quantity,
                      caloriesPerUnit: caloriesPerUnit,
                      note: note,
                    );
                  },
                  onDeleteTreat: (treatId) {
                    viewModel.deleteTreat(treatId);
                  },
                  onOpenSettings: () => _openHouseholdSettings(context, household),
                ),
                SizedBox(height: isCompactHeight ? 10 : 16),
                _HomeWidgetPreviewCard(viewModel: viewModel),
                SizedBox(height: isCompactHeight ? 10 : 16),
                _RecentHistorySection(
                  petName: household.petName,
                  isExpanded: viewModel.isHistoryExpanded,
                  onToggleExpanded: viewModel.toggleHistoryExpanded,
                  mealEvents: viewModel.history,
                  treatEvents: viewModel.recentTreats,
                  currentLogicalDate: viewModel.currentLogicalDate,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: FeederView.errorBannerKey,
      decoration: AppTheme.comicCardDecoration(
        color: const Color(0xFFFFEBEE),
        borderColor: AppTheme.inkDark,
        borderRadius: 16,
        borderWidth: 2,
        shadowOffset: 3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: <Widget>[
          const Text('⚠️ ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.inkDark,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            key: FeederView.dismissErrorButtonKey,
            tooltip: 'Dismiss error',
            onPressed: onDismiss,
            icon: const Icon(Icons.close, color: AppTheme.inkDark, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _PartnerPushBanner extends StatelessWidget {
  const _PartnerPushBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.snoopCoatBlack,
        borderColor: AppTheme.snoopCollarGold,
        borderRadius: 16,
        borderWidth: 2,
        shadowOffset: 3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: <Widget>[
          const Text('📣 ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _HeroStatusAndFeedCard extends StatelessWidget {
  const _HeroStatusAndFeedCard({
    required this.household,
    required this.window,
    required this.currentFeeding,
    required this.isFed,
    required this.isLoggingMeal,
    required this.isCompactHeight,
    required this.activeMemberName,
    required this.onTapFeed,
    required this.onTapExtraMeal,
    required this.onOpenSchedule,
  });

  final Household household;
  final ActiveMealWindow window;
  final FeedingEvent? currentFeeding;
  final bool isFed;
  final bool isLoggingMeal;
  final bool isCompactHeight;
  final String activeMemberName;
  final VoidCallback onTapFeed;
  final VoidCallback onTapExtraMeal;
  final VoidCallback onOpenSchedule;

  static String _formatLastFedSubtitle(
    FeedingEvent last,
    ActiveMealWindow currentWindow,
  ) {
    final timeStr = FeederViewModel.formatTimeOfDay(last.fedAt);
    final label = last.effectiveLabel;
    if (last.windowDate == currentWindow.windowDate) {
      return 'Last fed: $label by ${last.fedByName} at $timeStr';
    }
    final yesterday = _previousCalendarDate(currentWindow.windowDate);
    if (yesterday != null && last.windowDate == yesterday) {
      return 'Last fed: $label by ${last.fedByName} yesterday at $timeStr';
    }
    return 'Last fed: $label by ${last.fedByName} on ${last.windowDate} at $timeStr';
  }

  static String? _previousCalendarDate(String yyyyMmDd) {
    final parts = yyyyMmDd.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return ActiveMealWindow.formatDate(DateTime(y, m, d - 1));
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isFed ? AppTheme.fedSurface : AppTheme.hungrySurface;
    final accentColor = isFed ? AppTheme.fedPrimary : AppTheme.hungryPrimary;

    final nextResetStr = FeederViewModel.formatTimeOfDay(
      window.nextTransitionTime,
    );

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
          Wrap(
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
                    fontSize: isCompactHeight ? 11 : 12,
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: isCompactHeight ? 3 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      '⏰ Resets at $nextResetStr',
                      style: TextStyle(
                        color: AppTheme.inkMuted,
                        fontSize: isCompactHeight ? 11 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: FeederView.openScheduleButtonKey,
                      borderRadius: BorderRadius.circular(999),
                      onTap: onOpenSchedule,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: isCompactHeight ? 3 : 5,
                        ),
                        decoration: AppTheme.comicPillDecoration(
                          color: Colors.white,
                          borderColor: AppTheme.inkDark,
                          borderWidth: 1.6,
                        ),
                        child: Text(
                          '⚙️ Schedule',
                          style: TextStyle(
                            color: AppTheme.inkDark,
                            fontSize: isCompactHeight ? 11 : 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isCompactHeight ? 4 : 12),
          SnoopMascotIllustration(
            isFed: isFed,
            mealLabel: window.label,
            petName: household.petName,
            fedByName: currentFeeding?.fedByName,
            compact: isCompactHeight,
          ),
          SizedBox(height: isCompactHeight ? 4 : 12),
          if (currentFeeding != null) ...<Widget>[
            Text(
              '✅ ${household.petName} is Fed!',
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
              '${currentFeeding!.fedByName} fed ${household.petName} ${window.label} at ${FeederViewModel.formatTimeOfDay(currentFeeding!.fedAt)}',
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
              key: FeederView.heroFeedButtonKey,
              onPressed: null,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'ALREADY FED (${currentFeeding!.fedByName.toUpperCase()})',
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
              key: FeederView.bonusMealButtonKey,
              onPressed: isLoggingMeal ? null : onTapExtraMeal,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppTheme.inkDark,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '🥣 Gave an extra scoop of kibble? Log bonus meal',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isCompactHeight ? 12 : 13,
                  ),
                ),
              ),
            ),
          ] else ...<Widget>[
            Text(
              '${household.petName} needs ${window.label}',
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
              household.lastFeeding != null
                  ? _formatLastFedSubtitle(household.lastFeeding!, window)
                  : 'No meals logged yet today',
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
                key: FeederView.heroFeedButtonKey,
                onPressed: isLoggingMeal ? null : onTapFeed,
                icon: Icon(Icons.pets, size: isCompactHeight ? 20 : 24),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'I FED ${household.petName.toUpperCase()} ${window.label.toUpperCase()}',
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
                    side: const BorderSide(
                      color: AppTheme.inkDark,
                      width: 2.5,
                    ),
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
          ],
        ],
      ),
    );
  }
}

class _UndoBar extends StatelessWidget {
  const _UndoBar({
    required this.bannerText,
    required this.secondsRemaining,
    required this.isUndoing,
    required this.onUndo,
  });

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
            key: FeederView.undoFeedButtonKey,
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

class _HomeWidgetPreviewCard extends StatelessWidget {
  const _HomeWidgetPreviewCard({required this.viewModel});

  final FeederViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final snapshot = viewModel.widgetSnapshot;
    if (snapshot == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.snoopCoatBlack,
        borderColor: AppTheme.snoopCollarGold,
        borderRadius: 20,
        borderWidth: 2.5,
        shadowOffset: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.widgets_outlined,
                color: AppTheme.snoopCollarGold,
                size: 15,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'SNOOP-CAM • ANDROID HOME WIDGET PREVIEW',
                  style: TextStyle(
                    color: AppTheme.snoopCollarGold,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.snoopCurlHighlight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LIVE SYNC',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              SnoopMiniAvatar(size: 34, isHappy: snapshot.isFed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      snapshot.headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      snapshot.subheadline,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!snapshot.isFed)
                FilledButton.icon(
                  onPressed: viewModel.isLoggingMeal ? null : () => viewModel.markPetFed(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.snoopCollarGold,
                    foregroundColor: AppTheme.inkDark,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(color: Colors.white, width: 1.5),
                    ),
                  ),
                  icon: const Icon(Icons.pets, size: 14),
                  label: const Text(
                    'Feed',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _BellyLogFilter { all, meals, treats }

class _BellyLogEntry {
  const _BellyLogEntry.meal(this.meal) : treat = null;
  const _BellyLogEntry.treat(this.treat) : meal = null;

  final FeedingEvent? meal;
  final TreatEvent? treat;

  String get logicalDate => meal != null ? meal!.windowDate : treat!.logicalDate;
  DateTime get timestamp => meal != null ? meal!.fedAt : treat!.givenAt;
}

class _RecentHistorySection extends StatefulWidget {
  const _RecentHistorySection({
    required this.petName,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.mealEvents,
    required this.treatEvents,
    required this.currentLogicalDate,
  });

  final String petName;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final List<FeedingEvent> mealEvents;
  final List<TreatEvent> treatEvents;
  final String currentLogicalDate;

  @override
  State<_RecentHistorySection> createState() => _RecentHistorySectionState();
}

class _RecentHistorySectionState extends State<_RecentHistorySection> {
  _BellyLogFilter _filter = _BellyLogFilter.all;

  String _formatDateHeader(String date) {
    if (date == widget.currentLogicalDate) {
      return '📅 Today ($date)';
    }
    final yesterday = _HeroStatusAndFeedCard._previousCalendarDate(
      widget.currentLogicalDate,
    );
    if (yesterday != null && date == yesterday) {
      return '📅 Yesterday ($date)';
    }
    return '📅 $date';
  }

  @override
  Widget build(BuildContext context) {
    final includeMeals = _filter != _BellyLogFilter.treats;
    final includeTreats = _filter != _BellyLogFilter.meals;

    final entries = <_BellyLogEntry>[
      if (includeMeals)
        for (final meal in widget.mealEvents) _BellyLogEntry.meal(meal),
      if (includeTreats)
        for (final treat in widget.treatEvents) _BellyLogEntry.treat(treat),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Group entries by logical date (descending date order).
    final groupedByDate = <String, List<_BellyLogEntry>>{};
    for (final entry in entries) {
      groupedByDate.putIfAbsent(entry.logicalDate, () => <_BellyLogEntry>[]).add(entry);
    }
    final sortedDates = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    // Precompute full-day meal & treat counts/kcal for rich daily headers.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton.icon(
          key: FeederView.toggleHistoryButtonKey,
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
              ChoiceChip(
                key: FeederView.historyFilterAllKey,
                label: Text(
                  'All (${widget.mealEvents.length + widget.treatEvents.length})',
                ),
                selected: _filter == _BellyLogFilter.all,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _filter = _BellyLogFilter.all),
              ),
              ChoiceChip(
                key: FeederView.historyFilterMealsKey,
                label: Text('🥣 Meals (${widget.mealEvents.length})'),
                selected: _filter == _BellyLogFilter.meals,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _filter = _BellyLogFilter.meals),
              ),
              ChoiceChip(
                key: FeederView.historyFilterTreatsKey,
                label: Text('🦴 Treats (${widget.treatEvents.length})'),
                selected: _filter == _BellyLogFilter.treats,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _filter = _BellyLogFilter.treats),
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

class _MealHistoryCard extends StatelessWidget {
  const _MealHistoryCard({required this.petName, required this.event});

  final String petName;
  final FeedingEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.creamCard,
        borderRadius: 16,
        borderWidth: 2,
        shadowOffset: 2,
      ),
      child: ListTile(
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
                  border: Border.all(
                    color: AppTheme.inkDark,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  event.effectiveEmoji,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          '${event.fedByName} fed $petName ${event.effectiveLabel}${event.isExtraMeal ? " (Bonus)" : ""}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppTheme.inkDark,
          ),
        ),
        subtitle: Text(
          '${event.windowDate} • ${FeederViewModel.formatTimeOfDay(event.fedAt)}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.inkMuted,
          ),
        ),
      ),
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
    final noteSuffix =
        (treat.note != null && treat.note!.trim().isNotEmpty) ? ' • “${treat.note!.trim()}”' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.comicCardDecoration(
        color: Colors.white,
        borderRadius: 16,
        borderWidth: 2,
        shadowOffset: 2,
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.snoopCollarGold.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.inkDark, width: 1.8),
          ),
          child: Text(
            treat.emoji,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        title: Text(
          '${treat.givenByName} gave $petName $qtyPrefix${treat.label}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppTheme.inkDark,
          ),
        ),
        subtitle: Text(
          '${treat.logicalDate} • ${FeederViewModel.formatTimeOfDay(treat.givenAt)} • ${treat.totalCalories} kcal$noteSuffix',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.inkMuted,
          ),
        ),
      ),
    );
  }
}
