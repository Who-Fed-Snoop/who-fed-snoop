import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/ui/features/onboarding/views/onboarding_sheet.dart';
import 'package:who_fed_snoop/ui/features/settings/views/household_settings_sheet.dart';

import '../helpers/controllable_household_repository.dart';
import '../helpers/onboarding_test_harness.dart';

void main() {
  testWidgets(
    'Initializes member name from active persona (not hardcoded Ashley) and enforces 50/40/6 maxLength bounds',
    (WidgetTester tester) async {
      final viewModel = createOnboardingTestViewModel(initialMemberName: 'Keni');
      addTearDown(viewModel.dispose);

      await mountAndOpenOnboarding(tester, viewModel);

      final nameField = tester.widget<TextField>(
        find.byKey(OnboardingSheet.nameFieldKey),
      );
      expect(nameField.controller?.text, equals('Keni'));
      expect(nameField.maxLength, equals(50));

      final codeField = tester.widget<TextField>(
        find.byKey(OnboardingSheet.codeFieldKey),
      );
      expect(codeField.controller?.text, equals('SNOOP4'));
      expect(codeField.maxLength, equals(6));

      // Entering > 50 characters truncates to 50 matching firestore.rules
      await tester.enterText(
        find.byKey(OnboardingSheet.nameFieldKey),
        'A' * 65,
      );
      await tester.pump();
      expect(nameField.controller?.text.length, equals(50));

      // Switch to New Pet mode and verify 40-char maxLength on pet name
      final newPetTab = find.text('New Pet');
      await tester.ensureVisible(newPetTab);
      await tester.pumpAndSettle();
      await tester.tap(newPetTab);
      await tester.pumpAndSettle();

      final petNameField = tester.widget<TextField>(
        find.byKey(OnboardingSheet.petNameFieldKey),
      );
      expect(petNameField.controller?.text, equals('Snoop'));
      expect(petNameField.maxLength, equals(40));

      await tester.enterText(
        find.byKey(OnboardingSheet.petNameFieldKey),
        'B' * 55,
      );
      await tester.pump();
      expect(petNameField.controller?.text.length, equals(40));

      // Also verify persona propagation when switched to Dog Sitter
      Navigator.of(tester.element(find.byType(OnboardingSheet))).pop();
      await tester.pumpAndSettle();

      viewModel.switchActiveMember(
        uid: 'uid_sitter',
        name: 'Dog Sitter',
      );
      await tester.tap(find.byKey(OnboardingTestHostScreen.openPackHqButtonKey));
      await tester.pumpAndSettle();

      final sitterNameField = tester.widget<TextField>(
        find.byKey(OnboardingSheet.nameFieldKey),
      );
      expect(sitterNameField.controller?.text, equals('Dog Sitter'));
    },
  );

  testWidgets(
    'Pack HQ schedule & treat goal card opens HouseholdSettingsSheet and live-updates saved schedule and treat limit',
    (WidgetTester tester) async {
      final viewModel = createOnboardingTestViewModel();
      addTearDown(viewModel.dispose);

      await mountAndOpenOnboarding(tester, viewModel);

      expect(find.text('⚙️ Meal Windows & Treat Goal'), findsOneWidget);
      expect(find.text('🥣 Breakfast • 🍖 Dinner'), findsOneWidget);
      expect(find.text('🦴 4 treats/day'), findsOneWidget);

      // Open HouseholdSettingsSheet from Pack HQ
      await tester.tap(
        find.byKey(OnboardingSheet.openScheduleSettingsButtonKey),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(HouseholdSettingsSheet.sheetKey), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Add Lunch preset window and increase daily treat limit from 4 -> 6
      final lunchChip = find.byKey(
        HouseholdSettingsSheet.presetAddChipKey(MealPeriod.lunch),
      );
      await tester.ensureVisible(lunchChip);
      await tester.pumpAndSettle();
      await tester.tap(lunchChip);
      await tester.pumpAndSettle();

      final incButton = find.byKey(
        HouseholdSettingsSheet.treatLimitIncrementKey,
      );
      await tester.ensureVisible(incButton);
      await tester.pumpAndSettle();
      await tester.tap(incButton);
      await tester.pump();
      await tester.tap(incButton);
      await tester.pumpAndSettle();

      final saveButton = find.byKey(HouseholdSettingsSheet.saveButtonKey);
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      viewModel.cancelWindowTransitionTimer();

      // HouseholdSettingsSheet closes while OnboardingSheet remains open & live-updated
      expect(find.byKey(HouseholdSettingsSheet.sheetKey), findsNothing);
      expect(find.byType(OnboardingSheet), findsOneWidget);
      expect(
        find.text('🥣 Breakfast • 🍲 Lunch • 🍖 Dinner'),
        findsOneWidget,
      );
      expect(find.text('🦴 6 treats/day'), findsOneWidget);
      expect(viewModel.dailyTreatLimit, equals(6));
      expect(
        viewModel.schedule.enabledWindows.map((w) => w.id).toList(),
        equals(<String>['breakfast', 'lunch', 'dinner']),
      );
    },
  );

  testWidgets(
    'Invalid join code surfaces clean inline error without closing OnboardingSheet or popping root screen',
    (WidgetTester tester) async {
      final viewModel = createOnboardingTestViewModel();
      addTearDown(viewModel.dispose);

      await mountAndOpenOnboarding(tester, viewModel);

      await tester.enterText(
        find.byKey(OnboardingSheet.codeFieldKey),
        'BAD999',
      );
      await tester.pump();

      final submitBtn = find.byKey(OnboardingSheet.submitButtonKey);
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Sheet stays open, inline error banner renders cleanly without 'Bad state:'
      expect(find.byType(OnboardingSheet), findsOneWidget);
      expect(find.byKey(OnboardingTestHostScreen.rootScreenKey), findsOneWidget);
      expect(find.byKey(OnboardingSheet.errorBannerKey), findsOneWidget);
      expect(
        find.textContaining('No household found with code "BAD999"'),
        findsOneWidget,
      );
      expect(find.textContaining('Bad state:'), findsNothing);

      // Entering valid code afterwards recovers cleanly and pops OnboardingSheet once
      await tester.enterText(
        find.byKey(OnboardingSheet.codeFieldKey),
        'SNOOP4',
      );
      await tester.pump();
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      viewModel.cancelWindowTransitionTimer();

      expect(find.byType(OnboardingSheet), findsNothing);
      expect(find.byKey(OnboardingTestHostScreen.rootScreenKey), findsOneWidget);
    },
  );

  testWidgets(
    'Rapid double-tap on _submit() (Bug 5A) invokes repository once and pops ONLY OnboardingSheet, keeping root screen mounted',
    (WidgetTester tester) async {
      final fixedNow = DateTime(2026, 11, 8, 9, 30);
      final gatedRepo = ControllableHouseholdRepository(
        InMemoryHouseholdRepository(initialClock: fixedNow),
      );
      final viewModel = createOnboardingTestViewModel(
        repository: gatedRepo,
        now: fixedNow,
      );
      addTearDown(viewModel.dispose);

      await mountAndOpenOnboarding(tester, viewModel);

      // 1. Test async pending Completer double-tap in New Pet mode (createHousehold)
      await tester.tap(find.text('New Pet'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(OnboardingSheet.petNameFieldKey),
        'Milo',
      );
      await tester.pump();

      final createCompleter = Completer<void>();
      gatedRepo.createGate = createCompleter;

      final submitFinder = find.byKey(OnboardingSheet.submitButtonKey);
      await tester.ensureVisible(submitFinder);
      await tester.pumpAndSettle();

      // Rapid back-to-back taps in same frame + after frame rebuild while pending
      await tester.tap(submitFinder);
      await tester.tap(submitFinder, warnIfMissed: false);
      await tester.pump();
      await tester.tap(submitFinder, warnIfMissed: false);

      // Button is disabled while submitting and createHousehold was called ONLY once
      final buttonWhilePending = tester.widget<FilledButton>(submitFinder);
      expect(buttonWhilePending.onPressed, isNull);
      expect(gatedRepo.createCallCount, equals(1));

      // Complete pending creation and settle animations
      createCompleter.complete();
      await tester.pumpAndSettle();
      viewModel.cancelWindowTransitionTimer();

      expect(gatedRepo.createCallCount, equals(1));
      expect(find.byType(OnboardingSheet), findsNothing);
      expect(find.byKey(OnboardingTestHostScreen.rootScreenKey), findsOneWidget);
      expect(viewModel.household?.petName, equals('Milo'));

      // 2. Also test un-gated synchronous-frame double-tap in Join Code mode
      gatedRepo.createGate = null;
      gatedRepo.joinGate = null;

      await tester.tap(find.byKey(OnboardingTestHostScreen.openPackHqButtonKey));
      await tester.pumpAndSettle();
      expect(find.text("🐾 Milo's Pack HQ"), findsOneWidget);

      await tester.enterText(
        find.byKey(OnboardingSheet.codeFieldKey),
        'SNOOP4',
      );
      await tester.pump();
      await tester.ensureVisible(submitFinder);
      await tester.pumpAndSettle();

      await tester.tap(submitFinder);
      await tester.tap(submitFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      viewModel.cancelWindowTransitionTimer();

      expect(gatedRepo.joinCallCount, equals(1));
      expect(find.byType(OnboardingSheet), findsNothing);
      expect(find.byKey(OnboardingTestHostScreen.rootScreenKey), findsOneWidget);
    },
  );

  testWidgets(
    'Scoop Holder error surfaces inline in OnboardingSheet and Smart Link copy shows inline banner',
    (WidgetTester tester) async {
      final fixedNow = DateTime(2026, 11, 8, 9, 30);
      final controlled = ControllableHouseholdRepository(
        InMemoryHouseholdRepository(initialClock: fixedNow),
      )..updateMemberNameError = StateError('[cloud_firestore/permission-denied] denied');
      final viewModel = createOnboardingTestViewModel(
        repository: controlled,
        now: fixedNow,
      );
      addTearDown(viewModel.dispose);

      await mountAndOpenOnboarding(tester, viewModel);

      // Tapping Ashley while updateMemberName fails renders error inline inside ScoopHolderCard
      await tester.tap(find.byKey(OnboardingSheet.ashleyPersonaChipKey));
      await tester.pumpAndSettle();
      expect(find.byKey(OnboardingSheet.scoopHolderErrorBannerKey), findsOneWidget);
      expect(find.textContaining('Permission denied'), findsOneWidget);
      expect(viewModel.errorMessage, isNull);

      // Tapping a Smart Link shows inline copied confirmation inside the sheet
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<Object?, Object?>?;
            copiedText = args?['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final partnerLinkTitle = find.text('Partner Invite Link');
      await tester.ensureVisible(partnerLinkTitle);
      await tester.pumpAndSettle();
      await tester.tap(partnerLinkTitle);
      await tester.pumpAndSettle();

      expect(copiedText, contains('/join/SNOOP4'));
      expect(find.byKey(OnboardingSheet.smartLinkCopiedBannerKey), findsOneWidget);
      expect(find.textContaining('Copied Partner Invite Link!'), findsOneWidget);
    },
  );
}
