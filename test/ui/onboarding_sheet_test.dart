import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/domain/models/feeding_event.dart';
import 'package:who_fed_snoop/domain/models/household.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';
import 'package:who_fed_snoop/ui/core/app_theme.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';
import 'package:who_fed_snoop/ui/features/onboarding/views/onboarding_sheet.dart';
import 'package:who_fed_snoop/ui/features/settings/views/household_settings_sheet.dart';

class _TestHostScreen extends StatelessWidget {
  const _TestHostScreen({required this.viewModel});

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

/// Wrapper around [InMemoryHouseholdRepository] that gates `joinHouseholdByCode`
/// and `createHousehold` behind optional [Completer]s and counts invocations.
class _GatedHouseholdRepository implements HouseholdRepository {
  _GatedHouseholdRepository(this._inner);

  final InMemoryHouseholdRepository _inner;

  Completer<void>? joinGate;
  Completer<void>? createGate;
  int joinCallCount = 0;
  int createCallCount = 0;

  @override
  Stream<Household?> watchHousehold(String householdId) => _inner.watchHousehold(householdId);

  @override
  Stream<List<FeedingEvent>> watchRecentFeedings(
    String householdId, {
    int limit = 50,
  }) =>
      _inner.watchRecentFeedings(householdId, limit: limit);

  @override
  Stream<List<TreatEvent>> watchRecentTreats(
    String householdId, {
    int limit = 50,
  }) =>
      _inner.watchRecentTreats(householdId, limit: limit);

  @override
  Future<Household> createHousehold({
    required String memberUid,
    required String memberName,
    required String petName,
  }) async {
    createCallCount += 1;
    final gate = createGate;
    if (gate != null) {
      await gate.future;
    }
    return _inner.createHousehold(
      memberUid: memberUid,
      memberName: memberName,
      petName: petName,
    );
  }

  @override
  Future<Household> joinHouseholdByCode({
    required String joinCode,
    required String memberUid,
    required String memberName,
  }) async {
    joinCallCount += 1;
    final gate = joinGate;
    if (gate != null) {
      await gate.future;
    }
    return _inner.joinHouseholdByCode(
      joinCode: joinCode,
      memberUid: memberUid,
      memberName: memberName,
    );
  }

  @override
  Future<Household> updateHouseholdSettings({
    required String householdId,
    required String requestingUid,
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  }) =>
      _inner.updateHouseholdSettings(
        householdId: householdId,
        requestingUid: requestingUid,
        schedule: schedule,
        dailyTreatLimit: dailyTreatLimit,
        petName: petName,
      );

  @override
  Future<FeedingEvent> logFeeding({
    required String householdId,
    required String fedByUid,
    required String fedByName,
    required DateTime now,
    bool isExtraMeal = false,
  }) =>
      _inner.logFeeding(
        householdId: householdId,
        fedByUid: fedByUid,
        fedByName: fedByName,
        now: now,
        isExtraMeal: isExtraMeal,
      );

  @override
  Future<void> undoFeeding({
    required String householdId,
    required String feedingId,
    required String requestingUid,
  }) =>
      _inner.undoFeeding(
        householdId: householdId,
        feedingId: feedingId,
        requestingUid: requestingUid,
      );

  @override
  Future<TreatEvent> logTreat({
    required String householdId,
    required String givenByUid,
    required String givenByName,
    required DateTime now,
    required TreatPreset preset,
    String? customLabel,
    int quantity = 1,
    int? caloriesPerUnit,
    String? note,
  }) =>
      _inner.logTreat(
        householdId: householdId,
        givenByUid: givenByUid,
        givenByName: givenByName,
        now: now,
        preset: preset,
        customLabel: customLabel,
        quantity: quantity,
        caloriesPerUnit: caloriesPerUnit,
        note: note,
      );

  @override
  Future<void> deleteTreat({
    required String householdId,
    required String treatId,
    required String requestingUid,
  }) =>
      _inner.deleteTreat(
        householdId: householdId,
        treatId: treatId,
        requestingUid: requestingUid,
      );
}

void main() {
  FeederViewModel createTestViewModel({
    HouseholdRepository? repository,
    String initialMemberName = 'Keni',
    DateTime? now,
  }) {
    final fixedNow = now ?? DateTime(2026, 11, 8, 9, 30);
    final repo = repository ?? InMemoryHouseholdRepository(initialClock: fixedNow);
    final vm = FeederViewModel(
      repository: repo,
      widgetSyncService: WidgetSyncService(),
      initialMemberName: initialMemberName,
      clock: () => fixedNow,
    );
    vm.cancelWindowTransitionTimer();
    return vm;
  }

  Future<void> mountAndOpenOnboarding(
    WidgetTester tester,
    FeederViewModel viewModel,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: _TestHostScreen(viewModel: viewModel),
      ),
    );
    await tester.pumpAndSettle();
    viewModel.cancelWindowTransitionTimer();

    await tester.tap(find.byKey(_TestHostScreen.openPackHqButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingSheet), findsOneWidget);
  }

  testWidgets(
    'Initializes member name from active persona (not hardcoded Ashley) and enforces 50/40/6 maxLength bounds',
    (WidgetTester tester) async {
      final viewModel = createTestViewModel(initialMemberName: 'Keni');
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
      await tester.tap(find.text('New Pet'));
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
      await tester.tap(find.byKey(_TestHostScreen.openPackHqButtonKey));
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
      final viewModel = createTestViewModel();
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
      final viewModel = createTestViewModel();
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
      expect(find.byKey(_TestHostScreen.rootScreenKey), findsOneWidget);
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
      expect(find.byKey(_TestHostScreen.rootScreenKey), findsOneWidget);
    },
  );

  testWidgets(
    'Rapid double-tap on _submit() (Bug 5A) invokes repository once and pops ONLY OnboardingSheet, keeping root screen mounted',
    (WidgetTester tester) async {
      final fixedNow = DateTime(2026, 11, 8, 9, 30);
      final gatedRepo = _GatedHouseholdRepository(
        InMemoryHouseholdRepository(initialClock: fixedNow),
      );
      final viewModel = createTestViewModel(
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
      expect(find.byKey(_TestHostScreen.rootScreenKey), findsOneWidget);
      expect(viewModel.household?.petName, equals('Milo'));

      // 2. Also test un-gated synchronous-frame double-tap in Join Code mode
      gatedRepo.createGate = null;
      gatedRepo.joinGate = null;

      await tester.tap(find.byKey(_TestHostScreen.openPackHqButtonKey));
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
      expect(find.byKey(_TestHostScreen.rootScreenKey), findsOneWidget);
    },
  );

  testWidgets(
    'Renders OnboardingSheet and nested HouseholdSettingsSheet with zero RenderFlex overflows at 360x800 and 412x915',
    (WidgetTester tester) async {
      const viewports = <Size>[
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

        final viewModel = createTestViewModel();
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
}
