import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/scoop_holder_store.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';
import 'package:who_fed_snoop/main.dart';
import 'package:who_fed_snoop/ui/core/snoop_mascot.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';
import 'package:who_fed_snoop/ui/features/feeder/views/feeder_view.dart';
import 'package:who_fed_snoop/ui/features/onboarding/views/onboarding_sheet.dart';
import 'package:who_fed_snoop/ui/features/onboarding/views/scoop_holder_prompt_dialog.dart';
import 'package:who_fed_snoop/ui/features/settings/views/household_settings_sheet.dart';
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
    '1-tap logs meal, locks button against double-feeding, and supports 10s Undo',
    (WidgetTester tester) async {
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
      await tester.pump();

      // Initially Snoop needs Breakfast, and 7-day history is collapsed to save Firestore reads
      expect(find.text('Snoop needs Breakfast'), findsOneWidget);
      expect(find.text('I FED SNOOP BREAKFAST'), findsOneWidget);
      expect(viewModel.isHistoryExpanded, isFalse);

      // Yesterday's seeded meal shows explicit 'yesterday' context in subtitle
      expect(find.textContaining('yesterday at'), findsOneWidget);

      // Keni taps the giant 1-tap button
      await tester.tap(find.byKey(FeederView.heroFeedButtonKey));
      await tester.pump();

      // Status flips to Fed, bonus meal copy separates kibble from treats, and Undo bar appears
      expect(find.text('✅ Snoop is Fed!'), findsOneWidget);
      expect(
        find.text('🥣 Gave an extra scoop of kibble? Log bonus meal'),
        findsOneWidget,
      );
      expect(find.byKey(FeederView.undoFeedButtonKey), findsOneWidget);

      // Keni taps Undo within 10s
      await tester.tap(find.byKey(FeederView.undoFeedButtonKey));
      await tester.pump();

      // Reverts back to needing Breakfast WITHOUT firing a false partner banner (#12 Bug 2A)
      expect(find.text('Snoop needs Breakfast'), findsOneWidget);
      expect(viewModel.partnerNotificationBanner, isNull);
    },
  );

  testWidgets(
    'Partner feed updates single-doc stream, shows notification banner, and lazy-loads history',
    (WidgetTester tester) async {
      final fixedNow = DateTime(2026, 11, 8, 18, 15); // Dinner window
      final repository = InMemoryHouseholdRepository(initialClock: fixedNow);
      final widgetSyncService = WidgetSyncService();
      final viewModel = FeederViewModel(
        repository: repository,
        widgetSyncService: widgetSyncService,
        clock: () => fixedNow,
      );
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(WhoFedSnoopApp(viewModel: viewModel));
      await tester.pump();

      expect(find.text('Snoop needs Dinner'), findsOneWidget);

      // Simulate Ashley tapping "I Fed Snoop" from Pack HQ demo controls
      await tester.tap(find.byKey(FeederView.openPackHqButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(OnboardingSheet.simulatePartnerButtonKey));
      await tester.pump();
      Navigator.of(tester.element(find.byType(OnboardingSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.text('✅ Snoop is Fed!'), findsOneWidget);
      expect(find.textContaining('Ashley fed Snoop Dinner'), findsWidgets);

      // Expand 7-day meal log lazily on demand (scroll into view first in 800x600 test viewport)
      final toggleButton = find.byKey(FeederView.toggleHistoryButtonKey);
      await tester.scrollUntilVisible(toggleButton, 200);
      await tester.tap(toggleButton);
      await tester.pump();

      expect(viewModel.isHistoryExpanded, isTrue);
      expect(viewModel.history, isNotEmpty);
    },
  );

  testWidgets(
    'NFC / Android Widget /tap deep link automatically logs meal and /s activates Dog Sitter pass',
    (WidgetTester tester) async {
      final fixedNow = DateTime(2026, 11, 8, 8, 45); // Breakfast window
      final repository = InMemoryHouseholdRepository(initialClock: fixedNow);
      final widgetSyncService = WidgetSyncService();
      final viewModel = FeederViewModel(
        repository: repository,
        widgetSyncService: widgetSyncService,
        clock: () => fixedNow,
      );
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(WhoFedSnoopApp(viewModel: viewModel));
      await tester.pump();

      // 1. Activate Dog Sitter Guest Pass (/s/SNOOP4)
      await viewModel.handleIncomingUri(
        Uri.parse('https://whofedsnoop.com/s/SNOOP4'),
      );
      await tester.pump();

      expect(viewModel.currentMemberName, equals('Dog Sitter'));
      expect(find.textContaining('Dog Sitter Guest Pass active'), findsOneWidget);

      // Main screen stays free of Scoop Holder switcher chips (no accidental taps)
      expect(find.byKey(OnboardingSheet.keniPersonaChipKey), findsNothing);
      expect(find.byKey(OnboardingSheet.ashleyPersonaChipKey), findsNothing);

      // Verify Dog Sitter gets its own selected chip inside Pack HQ while neither Keni nor Ashley is falsely selected (#12 Bug 7A)
      await tester.tap(find.byKey(FeederView.openPackHqButtonKey));
      await tester.pumpAndSettle();

      final customChip = tester.widget<ChoiceChip>(
        find.byKey(OnboardingSheet.customPersonaChipKey),
      );
      expect(customChip.selected, isTrue);
      final ashleyChip = tester.widget<ChoiceChip>(
        find.byKey(OnboardingSheet.ashleyPersonaChipKey),
      );
      final keniChip = tester.widget<ChoiceChip>(
        find.byKey(OnboardingSheet.keniPersonaChipKey),
      );
      expect(ashleyChip.selected, isFalse);
      expect(keniChip.selected, isFalse);

      Navigator.of(tester.element(find.byType(OnboardingSheet))).pop();
      await tester.pumpAndSettle();

      // 2. Trigger NFC / Widget 1-tap feed link (/tap/household_snoop_01)
      await viewModel.handleIncomingUri(
        Uri.parse('https://whofedsnoop.com/tap/household_snoop_01'),
      );
      await tester.pump();

      expect(find.text('✅ Snoop is Fed!'), findsOneWidget);
      expect(
        find.textContaining('Dog Sitter fed Snoop Breakfast'),
        findsWidgets,
      );

      // Advance 10 seconds to verify the Undo timer expires cleanly
      await tester.pump(const Duration(seconds: 10));
      expect(viewModel.canUndo, isFalse);
    },
  );

  testWidgets(
    'SnoopMascotIllustration and SnoopTraitBadges render in hungry and fed states and OnboardingSheet opens cleanly',
    (WidgetTester tester) async {
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

      // Verify SnoopTraitBadges render all three personality pills
      expect(find.byType(SnoopTraitBadges), findsOneWidget);
      expect(find.textContaining('90 lb Black Labradoodle'), findsWidgets);
      expect(find.textContaining('100% Handsome'), findsOneWidget);
      expect(find.textContaining('Professional Goofball'), findsOneWidget);

      // Verify SnoopMascotIllustration renders in hungry state
      final hungryMascot = tester.widget<SnoopMascotIllustration>(
        find.byType(SnoopMascotIllustration),
      );
      expect(hungryMascot.isFed, isFalse);
      expect(hungryMascot.mealLabel, equals('Breakfast'));
      expect(find.text('SNOOP • 90 LB'), findsOneWidget);
      expect(
        find.textContaining('wasting away to a mere 89.9 lbs'),
        findsOneWidget,
      );

      // Tap feed button and verify SnoopMascotIllustration transitions to fed state
      await tester.tap(find.byKey(FeederView.heroFeedButtonKey));
      await tester.pumpAndSettle();

      final fedMascot = tester.widget<SnoopMascotIllustration>(
        find.byType(SnoopMascotIllustration),
      );
      expect(fedMascot.isFed, isTrue);
      expect(fedMascot.fedByName, equals('Keni'));
      expect(find.textContaining('90 lbs of pure happiness!'), findsOneWidget);

      // Open OnboardingSheet from the AppBar Pack pill and verify no overflow
      await tester.tap(find.text('Pack: SNOOP4'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingSheet), findsOneWidget);
      expect(find.text("🐾 Snoop's Pack HQ"), findsOneWidget);
      expect(find.text('Partner Invite Link'), findsOneWidget);
      expect(find.text('NFC Food-Bin Sticker URL'), findsOneWidget);
      expect(find.text('Dog Sitter Web Pass'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Advance 10 seconds to clear the Undo countdown timer before teardown
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets(
    'Visual layout and typography scale cleanly across standard portrait phone sizes (360x800, 375x812, 390x844, 412x915)',
    (WidgetTester tester) async {
      const phoneSizes = <Size>[
        Size(360, 800),
        Size(375, 812),
        Size(390, 844),
        Size(412, 915),
      ];

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final size in phoneSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

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
        expect(tester.takeException(), isNull);

        // Verify SnoopMascotIllustration uses full phone layout (compact == false)
        final mascot = tester.widget<SnoopMascotIllustration>(
          find.byType(SnoopMascotIllustration),
        );
        expect(mascot.compact, isFalse);

        // Verify speech bubble text is NOT inside a FittedBox and renders at 13.5px
        final speechTextFinder = find.textContaining(
          'wasting away to a mere 89.9 lbs',
        );
        expect(speechTextFinder, findsOneWidget);
        expect(
          find.ancestor(
            of: speechTextFinder,
            matching: find.byType(FittedBox),
          ),
          findsNothing,
        );
        final speechText = tester.widget<Text>(speechTextFinder);
        expect(speechText.style?.fontSize, equals(13.5));

        // Verify hungry headline typography renders at phone scale (fontSize == 26)
        final hungryHeadlineFinder = find.text('Snoop needs Breakfast');
        expect(hungryHeadlineFinder, findsOneWidget);
        final hungryHeadline = tester.widget<Text>(hungryHeadlineFinder);
        expect(hungryHeadline.style?.fontSize, equals(26));

        // Tap 1-tap feed button and verify fed state at this phone size
        final heroFeedButton = find.byKey(FeederView.heroFeedButtonKey);
        await tester.ensureVisible(heroFeedButton);
        await tester.pumpAndSettle();
        await tester.tap(heroFeedButton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final fedHeadlineFinder = find.text('✅ Snoop is Fed!');
        expect(fedHeadlineFinder, findsOneWidget);
        final fedHeadline = tester.widget<Text>(fedHeadlineFinder);
        expect(fedHeadline.style?.fontSize, equals(26));

        // Open OnboardingSheet and verify no layout overflow at this phone size
        await tester.tap(find.text('Pack: SNOOP4'));
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingSheet), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Close sheet and clear the 10s Undo timer before testing next phone size
        Navigator.of(tester.element(find.byType(OnboardingSheet))).pop();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 10));
      }
    },
  );

  testWidgets(
    'Editing household meal schedule via ⚙️ Schedule updates active window & custom labels live',
    (WidgetTester tester) async {
      // 12:30 PM falls inside Breakfast (4 AM..2 PM) on the default 2-window schedule,
      // and flips immediately to Lunch once a 12:00 PM Lunch window is added!
      final fixedNow = DateTime(2026, 11, 8, 12, 30);
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

      expect(find.text('🥣 BREAKFAST WINDOW'), findsOneWidget);
      expect(find.text('Snoop needs Breakfast'), findsOneWidget);

      // Open HouseholdSettingsSheet via compact "⚙️ Schedule" pill on FeederView
      await tester.tap(find.byKey(FeederView.openScheduleButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(HouseholdSettingsSheet.sheetKey), findsOneWidget);

      // Verify adding a custom window defaults to 'Snack 1' (#24 §2)
      final addCustomBtn = find.byKey(HouseholdSettingsSheet.addCustomWindowButtonKey);
      await tester.ensureVisible(addCustomBtn);
      await tester.tap(addCustomBtn);
      await tester.pump();
      expect(find.text('Snack 1'), findsOneWidget);

      // Also add the 12:00 PM Lunch preset and rename it to 'Midday Kibble'
      final addLunchChip = find.byKey(
        HouseholdSettingsSheet.presetAddChipKey(MealPeriod.lunch),
      );
      await tester.ensureVisible(addLunchChip);
      await tester.tap(addLunchChip);
      await tester.pump();

      final editLunchBtn = find.byKey(HouseholdSettingsSheet.windowEditButtonKey('lunch'));
      await tester.ensureVisible(editLunchBtn);
      await tester.tap(editLunchBtn);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(HouseholdSettingsSheet.editDialogLabelFieldKey),
        'Midday Kibble',
      );
      await tester.tap(
        find.byKey(HouseholdSettingsSheet.editDialogApplyButtonKey),
      );
      await tester.pumpAndSettle();

      // Save updated schedule
      final saveBtn = find.byKey(HouseholdSettingsSheet.saveButtonKey);
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // FeederView immediately reflects the custom 'Midday Kibble' window at 12:30 PM!
      expect(find.text('🍲 MIDDAY KIBBLE WINDOW'), findsOneWidget);
      expect(find.text('Snoop needs Midday Kibble'), findsOneWidget);
      expect(find.text('I FED SNOOP MIDDAY KIBBLE'), findsOneWidget);
    },
  );

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
