import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/scoop_holder_store.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/main.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';
import 'package:who_fed_snoop/ui/features/onboarding/views/onboarding_sheet.dart';
import 'package:who_fed_snoop/ui/features/onboarding/views/scoop_holder_prompt_dialog.dart';
import 'package:who_fed_snoop/ui/features/settings/views/household_settings_sheet.dart';

import '../helpers/controllable_household_repository.dart';
import '../helpers/onboarding_test_harness.dart';

void main() {
  testWidgets(
    'Renders OnboardingSheet and nested HouseholdSettingsSheet with zero RenderFlex overflows at 360x640, 360x800, and 412x915',
    (WidgetTester tester) async {
      const viewports = <Size>[
        Size(360, 640),
        Size(360, 800),
        Size(412, 915),
      ];

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final viewModel = createOnboardingTestViewModel();
        addTearDown(viewModel.dispose);

        await mountAndOpenOnboarding(tester, viewModel);
        expect(tester.takeException(), isNull);

        // Trigger error banner + New Pet mode to verify dense states have zero overflow
        await tester.enterText(
          find.byKey(OnboardingSheet.codeFieldKey),
          'NOPE00',
        );
        await tester.pump();
        final submitBtn = find.byKey(OnboardingSheet.submitButtonKey);
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final newPetTab = find.text('New Pet');
        await tester.ensureVisible(newPetTab);
        await tester.pumpAndSettle();
        await tester.tap(newPetTab);
        await tester.pumpAndSettle();
        expect(find.byKey(OnboardingSheet.petNameFieldKey), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Open HouseholdSettingsSheet from Pack HQ at this viewport size
        final editScheduleBtn = find.byKey(
          OnboardingSheet.openScheduleSettingsButtonKey,
        );
        await tester.ensureVisible(editScheduleBtn);
        await tester.pumpAndSettle();
        await tester.tap(editScheduleBtn);
        await tester.pumpAndSettle();
        expect(find.byKey(HouseholdSettingsSheet.sheetKey), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Dismiss both sheets before next viewport iteration
        Navigator.of(
          tester.element(find.byKey(HouseholdSettingsSheet.sheetKey)),
        ).pop();
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(OnboardingSheet))).pop();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'Pack HQ Scoop Holder card switches Keni / Ashley / Custom, persists locally, and syncs household members',
    (WidgetTester tester) async {
      final fixedNow = DateTime(2026, 11, 8, 9, 30);
      final repo = InMemoryHouseholdRepository(initialClock: fixedNow);
      final store = InMemoryScoopHolderStore(
        initialName: 'Keni',
        initialUid: InMemoryHouseholdRepository.keniUid,
      );
      final viewModel = createOnboardingTestViewModel(
        repository: repo,
        scoopHolderStore: store,
        now: fixedNow,
      );
      addTearDown(() {
        viewModel.dispose();
        repo.dispose();
      });

      await mountAndOpenOnboarding(tester, viewModel);

      expect(find.byKey(OnboardingSheet.scoopHolderCardKey), findsOneWidget);
      expect(find.text('Bound: Keni'), findsOneWidget);

      // Switch Scoop Holder to Ashley in Pack HQ
      await tester.tap(find.byKey(OnboardingSheet.ashleyPersonaChipKey));
      await tester.pumpAndSettle();

      expect(viewModel.currentMemberName, equals('Ashley'));
      expect(store.getMemberName(), equals('Ashley'));
      expect(find.text('Bound: Ashley'), findsOneWidget);

      final nameField = tester.widget<TextField>(
        find.byKey(OnboardingSheet.nameFieldKey),
      );
      expect(nameField.controller?.text, equals('Ashley'));

      // Switch to a custom Scoop Holder name via Custom dialog
      await tester.tap(find.byKey(OnboardingSheet.customPersonaButtonKey));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(OnboardingSheet.customPersonaDialogFieldKey),
        'Grandma',
      );
      await tester.tap(find.byKey(OnboardingSheet.customPersonaDialogSaveKey));
      await tester.pumpAndSettle();

      expect(viewModel.currentMemberName, equals('Grandma'));
      expect(store.getMemberName(), equals('Grandma'));
      expect(find.text('Bound: Grandma'), findsOneWidget);
      expect(
        viewModel.household?.members[viewModel.currentMemberUid]?.name,
        equals('Grandma'),
      );
    },
  );

  testWidgets(
    'ScoopHolderPromptDialog stays open and displays inline error when member sync fails',
    (WidgetTester tester) async {
      final fixedNow = DateTime(2026, 11, 8, 9, 30);
      final inner = InMemoryHouseholdRepository(initialClock: fixedNow);
      final promptRepo = ControllableHouseholdRepository(inner)
        ..updateMemberNameError = StateError('[cloud_firestore/permission-denied] denied');
      final vmPrompt = FeederViewModel(
        repository: promptRepo,
        widgetSyncService: WidgetSyncService(),
        scoopHolderStore: InMemoryScoopHolderStore(),
        clock: () => fixedNow,
      );
      addTearDown(() {
        vmPrompt.dispose();
        inner.dispose();
      });

      await tester.pumpWidget(WhoFedSnoopApp(viewModel: vmPrompt));
      await tester.pumpAndSettle();
      expect(find.byKey(ScoopHolderPromptDialog.dialogKey), findsOneWidget);

      await tester.tap(find.byKey(ScoopHolderPromptDialog.ashleyButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ScoopHolderPromptDialog.dialogKey), findsOneWidget);
      expect(find.byKey(ScoopHolderPromptDialog.errorTextKey), findsOneWidget);
      expect(find.textContaining('Permission denied'), findsOneWidget);
    },
  );
}
