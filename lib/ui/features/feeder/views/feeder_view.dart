import 'package:flutter/material.dart';

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
import '../widgets/belly_log_history_section.dart';
import '../widgets/feeder_banners.dart';
import '../widgets/hero_status_and_feed_card.dart';
import '../widgets/home_widget_preview_card.dart';

export '../widgets/belly_log_history_section.dart';
export '../widgets/feeder_banners.dart';
export '../widgets/hero_status_and_feed_card.dart';
export '../widgets/home_widget_preview_card.dart';

/// Main single-screen view designed around the "2-Second Rule":
/// 1. Glance immediately at Snoop's current meal window & daily treat jar state.
/// 2. Tap once to mark Snoop fed or log a treat and notify your partner.
class FeederView extends StatefulWidget {
  const FeederView({super.key, required this.viewModel});

  final FeederViewModel viewModel;

  static const Key heroFeedButtonKey = HeroStatusAndFeedCard.feedButtonKey;
  static const Key undoFeedButtonKey = UndoBar.undoButtonKey;
  static const Key toggleHistoryButtonKey = RecentHistorySection.toggleButtonKey;
  static const Key openScheduleButtonKey = HeroStatusAndFeedCard.openScheduleButtonKey;
  static const Key openPackHqButtonKey = Key('open_pack_hq_button');
  static const Key bonusMealButtonKey = HeroStatusAndFeedCard.bonusMealButtonKey;
  static const Key errorBannerKey = ErrorBanner.bannerKey;
  static const Key dismissErrorButtonKey = ErrorBanner.dismissButtonKey;
  static const Key retryHouseholdButtonKey = Key('retry_household_button');
  static const Key historyFilterAllKey = RecentHistorySection.filterAllKey;
  static const Key historyFilterMealsKey = RecentHistorySection.filterMealsKey;
  static const Key historyFilterTreatsKey = RecentHistorySection.filterTreatsKey;

  @override
  State<FeederView> createState() => _FeederViewState();
}

class _FeederViewState extends State<FeederView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _undoBarKey = GlobalKey();
  bool _isScoopPromptOpen = false;
  bool _promptCheckScheduled = false;
  String? _lastSnackError;

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
      _lastSnackError = widget.viewModel.errorMessage;
      _schedulePromptCheck();
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_handleViewModelChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleViewModelChanged() {
    if (widget.viewModel.needsScoopHolderPrompt && !_isScoopPromptOpen) {
      _schedulePromptCheck();
    }
    final currentError = widget.viewModel.errorMessage;
    if (currentError == null) {
      _lastSnackError = null;
    } else if (currentError != _lastSnackError) {
      _lastSnackError = currentError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
        if (!isCurrentRoute) return;
        _showActionSnackBar(
          '⚠️ $currentError',
          actionLabel: 'Dismiss',
          onAction: widget.viewModel.dismissError,
        );
      });
    }
  }

  void _showActionSnackBar(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: actionLabel != null && onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: AppTheme.snoopCollarGold,
                  onPressed: onAction,
                )
              : null,
        ),
      );
  }

  bool _isUndoBarOffscreen() {
    if (!_scrollController.hasClients) return false;
    if (_scrollController.offset > 120) return true;
    final undoContext = _undoBarKey.currentContext;
    if (undoContext == null) return false;
    final box = undoContext.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    final top = box.localToGlobal(Offset.zero).dy;
    return top + box.size.height < kToolbarHeight;
  }

  Future<void> _handleQuickTreatTap(TreatPreset preset) async {
    final treat = await widget.viewModel.logQuickTreat(preset);
    if (treat != null && mounted && _isUndoBarOffscreen()) {
      _showActionSnackBar(
        '${treat.emoji} ${treat.label} added — tap UNDO',
        actionLabel: 'UNDO',
        onAction: widget.viewModel.undoLastAction,
      );
    }
  }

  Future<void> _handleWidgetPreviewFeed() async {
    await widget.viewModel.markPetFed();
    if (mounted &&
        widget.viewModel.errorMessage == null &&
        widget.viewModel.canUndo &&
        _isUndoBarOffscreen()) {
      _showActionSnackBar(
        '🥣 ${widget.viewModel.activeWindow.label} marked fed — tap UNDO',
        actionLabel: 'UNDO',
        onAction: widget.viewModel.undoLastAction,
      );
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
          rethrowOnError: true,
        ),
      ),
    );
  }

  void _openPackHq(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OnboardingSheet(viewModel: widget.viewModel),
    );
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
          return FeederEmptyStateScaffold(
            errorMessage: viewModel.errorMessage,
            retryButtonKey: FeederView.retryHouseholdButtonKey,
            onDismissError: () {
              ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
              viewModel.dismissError();
            },
            onRetry: viewModel.retryHouseholdSubscription,
          );
        }

        final window = viewModel.activeWindow;
        final currentFeeding = viewModel.currentWindowFeeding;
        final isFed = currentFeeding != null;
        final isCompactHeight = MediaQuery.sizeOf(context).height < 680;
        final sectionGap = isCompactHeight ? 6.0 : 14.0;
        final windowYesterday = _previousCalendarDate(window.windowDate);
        final logicalDate = viewModel.currentLogicalDate;
        final logYesterday =
            logicalDate == window.windowDate ? windowYesterday : _previousCalendarDate(logicalDate);

        return Scaffold(
          appBar: buildFeederAppBar(
            petName: household.petName,
            joinCode: household.joinCode,
            isFed: isFed,
            packHqButtonKey: FeederView.openPackHqButtonKey,
            onOpenPackHq: () => _openPackHq(context),
          ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                FeederPinnedBanners(
                  errorMessage: viewModel.errorMessage,
                  partnerBanner: viewModel.partnerNotificationBanner,
                  isCompactHeight: isCompactHeight,
                  onDismissError: () {
                    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
                    viewModel.dismissError();
                  },
                  onDismissPartnerBanner: viewModel.dismissPartnerBanner,
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isCompactHeight ? 4 : 12,
                    ),
                    children: <Widget>[
                      const SnoopTraitBadges(),
                      SizedBox(height: sectionGap),
                      HeroStatusAndFeedCard(
                        household: household,
                        window: window,
                        currentFeeding: currentFeeding,
                        isFed: isFed,
                        isLoggingMeal: viewModel.isLoggingMeal,
                        isCompactHeight: isCompactHeight,
                        activeMemberName: viewModel.currentMemberName,
                        yesterdayLogicalDate: windowYesterday,
                        onTapFeed: () => viewModel.markPetFed(),
                        onTapExtraMeal: () => viewModel.markPetFed(isExtraMeal: true),
                        onOpenSchedule: () => _openHouseholdSettings(context, household),
                      ),
                      if (viewModel.canUndo || viewModel.isUndoing) ...<Widget>[
                        SizedBox(height: sectionGap),
                        UndoBar(
                          key: _undoBarKey,
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
                        activeLoggingPreset: viewModel.activeLoggingPreset,
                        deletingTreatIds: viewModel.deletingTreatIds,
                        onLogPreset: _handleQuickTreatTap,
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
                            rethrowOnError: true,
                          );
                        },
                        onDeleteTreat: viewModel.deleteTreat,
                        onOpenSettings: () => _openHouseholdSettings(context, household),
                      ),
                      SizedBox(height: isCompactHeight ? 10 : 16),
                      HomeWidgetPreviewCard(
                        snapshot: viewModel.widgetSnapshot,
                        isLoggingMeal: viewModel.isLoggingMeal,
                        onTapFeed: _handleWidgetPreviewFeed,
                      ),
                      SizedBox(height: isCompactHeight ? 10 : 16),
                      RecentHistorySection(
                        petName: household.petName,
                        isExpanded: viewModel.isHistoryExpanded,
                        isLoadingHistory: viewModel.isLoadingHistory,
                        onToggleExpanded: viewModel.toggleHistoryExpanded,
                        mealEvents: viewModel.history,
                        treatEvents: viewModel.recentTreats,
                        currentLogicalDate: logicalDate,
                        yesterdayLogicalDate: logYesterday,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
