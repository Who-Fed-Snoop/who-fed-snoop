import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/scoop_holder_store.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/ui/core/app_theme.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';
import 'package:who_fed_snoop/ui/features/onboarding/views/onboarding_sheet.dart';

/// Host scaffold exposing a button to open [OnboardingSheet] in widget tests.
class OnboardingTestHostScreen extends StatelessWidget {
  const OnboardingTestHostScreen({super.key, required this.viewModel});

  final FeederViewModel viewModel;

  static const Key rootScreenKey = ValueKey<String>('test_host_root_screen');
  static const Key openPackHqButtonKey = ValueKey<String>(
    'test_open_pack_hq_button',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: rootScreenKey,
      body: Center(
        child: FilledButton(
          key: openPackHqButtonKey,
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => OnboardingSheet(viewModel: viewModel),
            );
          },
          child: const Text('Open Pack HQ'),
        ),
      ),
    );
  }
}

/// Builds a [FeederViewModel] for Pack HQ tests with its transition timer cancelled.
FeederViewModel createOnboardingTestViewModel({
  HouseholdRepository? repository,
  ScoopHolderStore? scoopHolderStore,
  String initialMemberName = 'Keni',
  DateTime? now,
}) {
  final fixedNow = now ?? DateTime(2026, 11, 8, 9, 30);
  final repo = repository ?? InMemoryHouseholdRepository(initialClock: fixedNow);
  final vm = FeederViewModel(
    repository: repo,
    widgetSyncService: WidgetSyncService(),
    scoopHolderStore: scoopHolderStore,
    initialMemberName: initialMemberName,
    clock: () => fixedNow,
  );
  vm.cancelWindowTransitionTimer();
  return vm;
}

/// Mounts [OnboardingTestHostScreen] and taps the Pack HQ button to open [OnboardingSheet].
Future<void> mountAndOpenOnboarding(
  WidgetTester tester,
  FeederViewModel viewModel,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: OnboardingTestHostScreen(viewModel: viewModel),
    ),
  );
  await tester.pumpAndSettle();
  viewModel.cancelWindowTransitionTimer();

  await tester.tap(find.byKey(OnboardingTestHostScreen.openPackHqButtonKey));
  await tester.pumpAndSettle();
  expect(find.byType(OnboardingSheet), findsOneWidget);
}
