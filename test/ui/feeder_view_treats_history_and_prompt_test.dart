import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/scoop_holder_store.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';
import 'package:who_fed_snoop/main.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';
import 'package:who_fed_snoop/ui/features/feeder/views/feeder_view.dart';
import 'package:who_fed_snoop/ui/features/onboarding/views/scoop_holder_prompt_dialog.dart';
import 'package:who_fed_snoop/ui/features/treats/views/treat_jar_card.dart';

void main() {
  Future<void> bringIntoView(WidgetTester tester, Finder target) async {
    final scrollableFinder = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    if (target.evaluate().isEmpty && scrollableFinder.evaluate().isNotEmpty) {
      final state = tester.state<ScrollableState>(scrollableFinder.first);
      if (state.position.pixels > 0) {
        state.position.jumpTo(0);
        await tester.pump();
      }
      if (target.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          target,
          160,
          scrollable: scrollableFinder.first,
        );
      }
    }
    await tester.ensureVisible(target);
    await tester.pump();
  }

  testWidgets(
    'TreatJarCard logs treats orthogonally to meals, triggers Chonk Alert over limit, and stacks LIFO Undo with meals',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fixedNow = DateTime(2026, 11, 8, 9, 30); // Breakfast window
      final repository = InMemoryHouseholdRepository(initialClock: fixedNow);
      final widgetSyncService = WidgetSyncService();
      final viewModel = FeederViewModel(
        repository: repository,
        widgetSyncService: widgetSyncService,
        clock: () => fixedNow,
      );
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(WhoFedSnoopApp(viewModel: viewModel));
      await tester.pumpAndSettle();

      // Lower daily treat limit to 2 after initial household stream loads so we can test Chonk Alert cleanly
      await viewModel.updateHouseholdSettings(dailyTreatLimit: 2);
      await tester.pump();

      // 1. Logging a treat while unfed NEVER marks Breakfast as Fed!
      final trainingChip = find.byKey(
        TreatJarCard.presetChipKey(TreatPreset.trainingTreat),
      );
      await bringIntoView(tester, trainingChip);
      await tester.tap(trainingChip);
      await tester.pump();

      expect(viewModel.isCurrentWindowFed, isFalse);
      expect(find.textContaining('1 / 2 TREATS'), findsOneWidget);

      // Undo that first treat so we start clean for stacked Meal + Treat LIFO Undo
      final undoBtn = find.byKey(FeederView.undoFeedButtonKey);
      await bringIntoView(tester, undoBtn);
      await tester.tap(undoBtn);
      await tester.pump();
      expect(viewModel.todayTreatCount, equals(0));
      expect(viewModel.canUndo, isFalse);

      // 2. Log Breakfast meal, then immediately log PB Kong treat -> LIFO Undo stack!
      final heroBtn = find.byKey(FeederView.heroFeedButtonKey);
      await bringIntoView(tester, heroBtn);
      await tester.tap(heroBtn);
      await tester.pump();
      expect(find.text('✅ Snoop is Fed!'), findsOneWidget);
      expect(find.textContaining('🥣 Logged Breakfast!'), findsOneWidget);

      final pbKongChip = find.byKey(
        TreatJarCard.presetChipKey(TreatPreset.peanutButterKong),
      );
      await bringIntoView(tester, pbKongChip);
      await tester.tap(pbKongChip);
      await tester.pump();

      // Top of Undo stack is PB Kong (+1 more for Breakfast underneath)
      await bringIntoView(tester, undoBtn);
      expect(find.textContaining('🥜 Logged PB Kong!'), findsOneWidget);
      expect(find.textContaining('(+1 more)'), findsOneWidget);
      expect(viewModel.isCurrentWindowFed, isTrue);
      expect(viewModel.todayTreatCount, equals(1));

      // First tap on Undo reverts ONLY PB Kong treat; Breakfast stays Fed and surfaces next!
      await tester.tap(undoBtn);
      await tester.pump();

      expect(viewModel.todayTreatCount, equals(0));
      expect(viewModel.isCurrentWindowFed, isTrue);
      expect(find.textContaining('🥣 Logged Breakfast!'), findsOneWidget);

      // Second tap on Undo reverts Breakfast meal back to Hungry!
      await tester.tap(undoBtn);
      await tester.pump();
      expect(viewModel.isCurrentWindowFed, isFalse);
      expect(viewModel.canUndo, isFalse);
      await bringIntoView(tester, heroBtn);
      expect(find.text('Snoop needs Breakfast'), findsOneWidget);

      // 3. Exceed dailyTreatLimit (3 > 2) -> soft Chonk Alert banner appears without blocking
      await bringIntoView(tester, trainingChip);
      await tester.tap(trainingChip);
      await tester.pump();
      await bringIntoView(tester, trainingChip);
      await tester.tap(trainingChip);
      await tester.pump();
      expect(find.byKey(TreatJarCard.overLimitBannerKey), findsNothing);

      await bringIntoView(tester, trainingChip);
      await tester.tap(trainingChip);
      await tester.pump();
      await bringIntoView(
        tester,
        find.byKey(TreatJarCard.overLimitBannerKey),
      );
      expect(find.byKey(TreatJarCard.overLimitBannerKey), findsOneWidget);
      expect(find.textContaining('CHONK ALERT!'), findsOneWidget);

      // Clear 10s Undo countdown before teardown
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets(
    '7-Day Belly Log filters Meals vs Treats, ErrorBanner dismisses cleanly, and rich states fit 360x800 & 412x915 without overflow',
    (WidgetTester tester) async {
      const sizes = <Size>[Size(360, 800), Size(412, 915)];

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final fixedNow = DateTime(2026, 11, 8, 9, 30);
        final repository = InMemoryHouseholdRepository(initialClock: fixedNow);
        final widgetSyncService = WidgetSyncService();
        final viewModel = FeederViewModel(
          repository: repository,
          widgetSyncService: widgetSyncService,
          clock: () => fixedNow,
        );
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          WhoFedSnoopApp(key: ValueKey<Size>(size), viewModel: viewModel),
        );
        await tester.pumpAndSettle();
        await viewModel.updateHouseholdSettings(dailyTreatLimit: 1);
        await tester.pump();

        // Log a meal + 2 treats, then trigger an error so Fed card + Undo bar + Chonk Alert + ErrorBanner render simultaneously!
        final heroBtn = find.byKey(FeederView.heroFeedButtonKey);
        await bringIntoView(tester, heroBtn);
        await tester.tap(heroBtn);
        await tester.pump();

        final biscuitChip = find.byKey(
          TreatJarCard.presetChipKey(TreatPreset.crunchyBiscuit),
        );
        await bringIntoView(tester, biscuitChip);
        await tester.tap(biscuitChip);
        await tester.pump();
        await bringIntoView(tester, biscuitChip);
        await tester.tap(biscuitChip);
        await tester.pump();
        expect(find.byKey(TreatJarCard.overLimitBannerKey), findsOneWidget);

        // Trigger an error via mismatched /tap household ID -> ErrorBanner renders & dismisses cleanly
        await viewModel.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/tap/unknown_household_99'),
        );
        await tester.pump();
        final dismissErrBtn = find.byKey(FeederView.dismissErrorButtonKey);
        await bringIntoView(tester, dismissErrBtn);
        expect(find.byKey(FeederView.errorBannerKey), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(dismissErrBtn);
        await tester.pump();
        expect(find.byKey(FeederView.errorBannerKey), findsNothing);
        expect(viewModel.errorMessage, isNull);

        // Expand 7-Day Belly Log and verify All / Meals / Treats filter chips
        final historyToggle = find.byKey(FeederView.toggleHistoryButtonKey);
        await bringIntoView(tester, historyToggle);
        await tester.tap(historyToggle);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final allFilter = find.byKey(FeederView.historyFilterAllKey);
        await bringIntoView(tester, allFilter);

        expect(find.textContaining('Today (2026-11-08)'), findsOneWidget);
        expect(
          find.textContaining('Keni fed Snoop Breakfast'),
          findsWidgets,
        );
        expect(
          find.textContaining('Keni gave Snoop Crunchy Biscuit'),
          findsWidgets,
        );

        // Filter to Meals only -> treat history cards hide, meal cards (today + seeded yesterday) stay
        final mealsFilter = find.byKey(FeederView.historyFilterMealsKey);
        await bringIntoView(tester, mealsFilter);
        await tester.tap(mealsFilter);
        await tester.pump();
        expect(
          find.text('Keni gave Snoop Crunchy Biscuit'),
          findsNothing,
        );
        expect(
          find.text('Keni fed Snoop Breakfast'),
          findsNWidgets(2),
        );
        expect(find.textContaining('Yesterday (2026-11-07)'), findsOneWidget);

        // Filter to Treats only -> meal history cards hide, treat cards show
        final treatsFilter = find.byKey(FeederView.historyFilterTreatsKey);
        await bringIntoView(tester, treatsFilter);
        await tester.tap(treatsFilter);
        await tester.pump();
        expect(find.text('Keni fed Snoop Breakfast'), findsNothing);
        expect(
          find.text('Keni gave Snoop Crunchy Biscuit'),
          findsNWidgets(2),
        );

        // Filter back to All
        await bringIntoView(tester, allFilter);
        await tester.tap(allFilter);
        await tester.pump();
        expect(find.text('Keni fed Snoop Breakfast'), findsNWidgets(2));
        expect(
          find.text('Keni gave Snoop Crunchy Biscuit'),
          findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);

        // Drain 10s Undo timer cleanly before next iteration / teardown
        await tester.pump(const Duration(seconds: 10));
      }
    },
  );

  testWidgets(
    'Unbound device prompts "Who holds this phone?" once, persists Ashley across cold restart, and renders cleanly at 360x640 & 360x800',
    (WidgetTester tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Test prompt validation + overflow at compact height <680 (360x640) and 360x800
      for (final size in const <Size>[Size(360, 640), Size(360, 800)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesScoopHolderStore(prefs);
        final fixedNow = DateTime(2026, 11, 8, 9, 30);
        final repo = InMemoryHouseholdRepository(initialClock: fixedNow);
        addTearDown(repo.dispose);

        final vm1 = FeederViewModel(
          repository: repo,
          widgetSyncService: WidgetSyncService(),
          scoopHolderStore: store,
          clock: () => fixedNow,
        );
        addTearDown(vm1.dispose);

        await tester.pumpWidget(
          WhoFedSnoopApp(key: ValueKey<String>('cold_1_$size'), viewModel: vm1),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Prompt appears once on unbound device
        expect(find.byKey(ScoopHolderPromptDialog.dialogKey), findsOneWidget);
        expect(find.text('Who holds this phone?'), findsOneWidget);

        // Empty custom submit shows inline validation error without overflow
        await tester.tap(find.byKey(ScoopHolderPromptDialog.customSubmitButtonKey));
        await tester.pumpAndSettle();
        expect(find.byKey(ScoopHolderPromptDialog.errorTextKey), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Ashley taps "🐾 Ashley" -> binds device & closes prompt cleanly
        await tester.tap(find.byKey(ScoopHolderPromptDialog.ashleyButtonKey));
        await tester.pumpAndSettle();

        expect(find.byKey(ScoopHolderPromptDialog.dialogKey), findsNothing);
        expect(vm1.isDeviceBound, isTrue);
        expect(vm1.currentMemberName, equals('Ashley'));
        expect(find.textContaining('1 tap logs as Ashley'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Cold restart with a fresh ViewModel reading the same SharedPreferences
        final storeAfterRestart = SharedPreferencesScoopHolderStore(prefs);
        final vm2 = FeederViewModel(
          repository: repo,
          widgetSyncService: WidgetSyncService(),
          scoopHolderStore: storeAfterRestart,
          clock: () => fixedNow,
        );
        addTearDown(vm2.dispose);

        await tester.pumpWidget(
          WhoFedSnoopApp(key: ValueKey<String>('cold_2_$size'), viewModel: vm2),
        );
        await tester.pumpAndSettle();

        // Never re-prompts on bound cold start, and keeps Ashley as active Scoop Holder
        expect(find.byKey(ScoopHolderPromptDialog.dialogKey), findsNothing);
        expect(vm2.currentMemberName, equals('Ashley'));
        expect(find.textContaining('1 tap logs as Ashley'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
