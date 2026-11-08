import 'package:flutter/material.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/household.dart';
import '../../../../domain/models/meal_window.dart';
import '../../../core/app_theme.dart';
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

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: <Widget>[
                const Text('🐾 ', style: TextStyle(fontSize: 22)),
                Text(
                  'Who Fed ${household.petName}?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.key, size: 16),
                label: Text(
                  'Code: ${household.joinCode}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => OnboardingSheet(viewModel: viewModel),
                  );
                },
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: <Widget>[
                _MemberSwitcherBar(viewModel: viewModel),
                if (viewModel.partnerNotificationBanner != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _PartnerPushBanner(
                    message: viewModel.partnerNotificationBanner!,
                    onDismiss: viewModel.dismissPartnerBanner,
                  ),
                ],
                const SizedBox(height: 16),
                _HeroStatusAndFeedCard(
                  household: household,
                  window: window,
                  currentFeeding: currentFeeding,
                  isFed: isFed,
                  activeMemberName: viewModel.currentMemberName,
                  onTapFeed: () => viewModel.markPetFed(),
                  onTapExtraMeal: () =>
                      viewModel.markPetFed(isExtraMeal: true),
                ),
                if (viewModel.canUndo) ...<Widget>[
                  const SizedBox(height: 12),
                  _UndoBar(
                    secondsRemaining: viewModel.undoSecondsRemaining,
                    onUndo: viewModel.undoLastFeed,
                  ),
                ],
                const SizedBox(height: 20),
                _HomeWidgetPreviewCard(viewModel: viewModel),
                const SizedBox(height: 24),
                _RecentHistorySection(
                  petName: household.petName,
                  events: viewModel.history,
                ),
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
    final isKeni =
        viewModel.currentMemberUid == InMemoryHouseholdRepository.keniUid;
    final partnerName = isKeni ? 'Ashley' : 'Keni';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Viewing as:',
              style: TextStyle(
                color: AppTheme.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Keni'),
              selected: isKeni,
              onSelected: (_) => viewModel.switchActiveMember(
                uid: InMemoryHouseholdRepository.keniUid,
                name: 'Keni',
              ),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('Ashley'),
              selected: !isKeni,
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
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
          label: Text('Simulate $partnerName Tap'),
        ),
      ],
    );
  }
}

class _PartnerPushBanner extends StatelessWidget {
  const _PartnerPushBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.inkDark,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
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
    required this.activeMemberName,
    required this.onTapFeed,
    required this.onTapExtraMeal,
  });

  final Household household;
  final ActiveMealWindow window;
  final FeedingEvent? currentFeeding;
  final bool isFed;
  final String activeMemberName;
  final VoidCallback onTapFeed;
  final VoidCallback onTapExtraMeal;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isFed ? AppTheme.fedSurface : AppTheme.hungrySurface;
    final borderColor = isFed ? AppTheme.fedBorder : AppTheme.hungryBorder;
    final accentColor = isFed ? AppTheme.fedPrimary : AppTheme.hungryPrimary;

    final nextResetStr = FeederViewModel.formatTimeOfDay(
      window.nextTransitionTime,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${window.period.emoji} ${window.period.label.toUpperCase()} WINDOW',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Text(
                'Resets at $nextResetStr',
                style: const TextStyle(
                  color: AppTheme.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (currentFeeding != null) ...<Widget>[
            Text(
              '✅ ${household.petName} is Fed!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppTheme.inkDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${currentFeeding!.fedByName} fed ${household.petName} ${window.period.label} at ${FeederViewModel.formatTimeOfDay(currentFeeding!.fedAt)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.inkMuted,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: FeederView.heroFeedButtonKey,
              onPressed: null,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                'ALREADY FED (${currentFeeding!.fedByName.toUpperCase()})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onTapExtraMeal,
              child: const Text('Gave an extra meal or treat? Log bonus feed'),
            ),
          ] else ...<Widget>[
            Text(
              '${household.petName} needs ${window.period.label}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppTheme.inkDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              household.lastFeeding != null
                  ? 'Last fed: ${household.lastFeeding!.mealPeriod.label} by ${household.lastFeeding!.fedByName} at ${FeederViewModel.formatTimeOfDay(household.lastFeeding!.fedAt)}'
                  : 'No meals logged yet today',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.inkMuted,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: FeederView.heroFeedButtonKey,
              onPressed: onTapFeed,
              icon: const Icon(Icons.pets, size: 26),
              label: Text(
                'I FED ${household.petName.toUpperCase()} ${window.period.label.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.hungryPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '1 tap logs as $activeMemberName & sends push notification',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.inkMuted),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Accidental tap? Undo within ${secondsRemaining}s',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextButton.icon(
            key: FeederView.undoFeedButtonKey,
            onPressed: onUndo,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text(
              'UNDO',
              style: TextStyle(fontWeight: FontWeight.w800),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.inkDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.widgets_outlined, color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Text(
                'ANDROID HOME SCREEN WIDGET PREVIEW',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      snapshot.headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      snapshot.subheadline,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!snapshot.isFed)
                FilledButton(
                  onPressed: () => viewModel.markPetFed(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.hungryPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Feed'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentHistorySection extends StatelessWidget {
  const _RecentHistorySection({required this.petName, required this.events});

  final String petName;
  final List<FeedingEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          "$petName's 7-Day Meal Log",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.inkDark,
          ),
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No meals logged yet.'),
          )
        else
          ...events.map(
            (event) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Colors.black12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.fedSurface,
                  child: Text(event.mealPeriod.emoji),
                ),
                title: Text(
                  '${event.fedByName} fed $petName ${event.mealPeriod.label}${event.isExtraMeal ? " (Bonus)" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${event.windowDate} • ${FeederViewModel.formatTimeOfDay(event.fedAt)}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

