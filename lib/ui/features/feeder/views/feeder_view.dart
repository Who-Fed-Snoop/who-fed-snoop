import 'package:flutter/material.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/household.dart';
import '../../../../domain/models/meal_window.dart';
import '../../../core/app_theme.dart';
import '../../../core/snoop_mascot.dart';
import '../../onboarding/views/onboarding_sheet.dart';
import '../view_models/feeder_view_model.dart';

/// Main single-screen view designed around the "2-Second Rule":
/// 1. Glance immediately at Snoop's current meal window state.
/// 2. Tap once to mark Snoop fed and notify your partner.
class FeederView extends StatelessWidget {
  const FeederView({super.key, required this.viewModel});

  final FeederViewModel viewModel;

  static const Key heroFeedButtonKey = Key('hero_feed_button');
  static const Key undoFeedButtonKey = Key('undo_feed_button');
  static const Key simulatePartnerButtonKey = Key('simulate_partner_button');
  static const Key toggleHistoryButtonKey = Key('toggle_history_button');

  @override
  Widget build(BuildContext context) {
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
                SizedBox(height: isCompactHeight ? 4 : 10),
                _MemberSwitcherBar(viewModel: viewModel),
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
                  isCompactHeight: isCompactHeight,
                  activeMemberName: viewModel.currentMemberName,
                  onTapFeed: () => viewModel.markPetFed(),
                  onTapExtraMeal: () => viewModel.markPetFed(isExtraMeal: true),
                ),
                if (viewModel.canUndo) ...<Widget>[
                  SizedBox(height: sectionGap),
                  _UndoBar(
                    secondsRemaining: viewModel.undoSecondsRemaining,
                    onUndo: viewModel.undoLastFeed,
                  ),
                ],
                SizedBox(height: isCompactHeight ? 10 : 16),
                _HomeWidgetPreviewCard(viewModel: viewModel),
                SizedBox(height: isCompactHeight ? 10 : 16),
                _RecentHistorySection(
                  petName: household.petName,
                  isExpanded: viewModel.isHistoryExpanded,
                  onToggleExpanded: viewModel.toggleHistoryExpanded,
                  events: viewModel.history,
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

class _MemberSwitcherBar extends StatelessWidget {
  const _MemberSwitcherBar({required this.viewModel});

  final FeederViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isKeni = viewModel.currentMemberName.toLowerCase() == 'keni';
    final partnerName = isKeni ? 'Ashley' : 'Keni';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: AppTheme.comicCardDecoration(
        color: AppTheme.creamCard,
        borderRadius: 16,
        borderWidth: 2,
        shadowOffset: 2,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text(
                '🥣 Scoop Holder:',
                style: TextStyle(
                  color: AppTheme.inkDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              ChoiceChip(
                label: const Text('Keni'),
                selected: isKeni,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => viewModel.switchActiveMember(
                  uid: InMemoryHouseholdRepository.keniUid,
                  name: 'Keni',
                ),
              ),
              ChoiceChip(
                label: const Text('Ashley'),
                selected: !isKeni,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => viewModel.switchActiveMember(
                  uid: InMemoryHouseholdRepository.ashleyUid,
                  name: 'Ashley',
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            key: FeederView.simulatePartnerButtonKey,
            onPressed: viewModel.simulatePartnerFeed,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              side: const BorderSide(color: AppTheme.inkDark, width: 1.8),
              foregroundColor: AppTheme.inkDark,
              backgroundColor: AppTheme.snoopCollarGold.withValues(alpha: 0.25),
            ),
            icon: const Icon(Icons.notifications_active_outlined, size: 16),
            label: Text(
              'Simulate $partnerName Tap',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
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
    required this.isCompactHeight,
    required this.activeMemberName,
    required this.onTapFeed,
    required this.onTapExtraMeal,
  });

  final Household household;
  final ActiveMealWindow window;
  final FeedingEvent? currentFeeding;
  final bool isFed;
  final bool isCompactHeight;
  final String activeMemberName;
  final VoidCallback onTapFeed;
  final VoidCallback onTapExtraMeal;

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
                  '${window.period.emoji} ${window.period.label.toUpperCase()} WINDOW',
                  style: TextStyle(
                    color: AppTheme.inkDark,
                    fontWeight: FontWeight.w900,
                    fontSize: isCompactHeight ? 11 : 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
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
            ],
          ),
          SizedBox(height: isCompactHeight ? 4 : 12),
          SnoopMascotIllustration(
            isFed: isFed,
            mealLabel: window.period.label,
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
              '${currentFeeding!.fedByName} fed ${household.petName} ${window.period.label} at ${FeederViewModel.formatTimeOfDay(currentFeeding!.fedAt)}',
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
                visualDensity: isCompactHeight
                    ? VisualDensity.compact
                    : VisualDensity.standard,
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
              onPressed: onTapExtraMeal,
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
                  '🦴 Gave an extra meal or treat? Log bonus feed',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isCompactHeight ? 12 : 13,
                  ),
                ),
              ),
            ),
          ] else ...<Widget>[
            Text(
              '${household.petName} needs ${window.period.label}',
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
                  ? 'Last fed: ${household.lastFeeding!.mealPeriod.label} by ${household.lastFeeding!.fedByName} at ${FeederViewModel.formatTimeOfDay(household.lastFeeding!.fedAt)}'
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
                onPressed: onTapFeed,
                icon: Icon(Icons.pets, size: isCompactHeight ? 20 : 24),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'I FED ${household.petName.toUpperCase()} ${window.period.label.toUpperCase()}',
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
  const _UndoBar({required this.secondsRemaining, required this.onUndo});

  final int secondsRemaining;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
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
              '🦴 Accidental scoop? Undo within ${secondsRemaining}s',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppTheme.inkDark,
              ),
            ),
          ),
          TextButton.icon(
            key: FeederView.undoFeedButtonKey,
            onPressed: onUndo,
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
                  onPressed: () => viewModel.markPetFed(),
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

class _RecentHistorySection extends StatelessWidget {
  const _RecentHistorySection({
    required this.petName,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.events,
  });

  final String petName;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final List<FeedingEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton.icon(
          key: FeederView.toggleHistoryButtonKey,
          onPressed: onToggleExpanded,
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
          icon: Icon(isExpanded ? Icons.expand_less : Icons.history),
          label: Text(
            isExpanded
                ? "Hide $petName's 7-Day Belly Log"
                : "Show $petName's 7-Day Belly Log",
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (isExpanded) ...<Widget>[
          const SizedBox(height: 10),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No meals logged yet — Snoop is awaiting kibble!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            ...events.map(
              (event) => Container(
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
                            event.mealPeriod.emoji,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    '${event.fedByName} fed $petName ${event.mealPeriod.label}${event.isExtraMeal ? " (Bonus)" : ""}',
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
              ),
            ),
        ],
      ],
    );
  }
}
