import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/main.dart';
import 'package:who_fed_snoop/ui/core/snoop_mascot.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';
import 'package:who_fed_snoop/ui/features/feeder/views/feeder_view.dart';
import 'package:who_fed_snoop/ui/features/onboarding/views/onboarding_sheet.dart';

void main() {
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

      // Keni taps the giant 1-tap button
      await tester.tap(find.byKey(FeederView.heroFeedButtonKey));
      await tester.pump();

      // Status flips to Fed and Undo bar appears
      expect(find.text('✅ Snoop is Fed!'), findsOneWidget);
      expect(find.byKey(FeederView.undoFeedButtonKey), findsOneWidget);

      // Keni taps Undo within 10s
      await tester.tap(find.byKey(FeederView.undoFeedButtonKey));
      await tester.pump();

      // Reverts back to needing Breakfast
      expect(find.text('Snoop needs Breakfast'), findsOneWidget);
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

      // Simulate Ashley tapping "I Fed Snoop" on her phone
      await tester.tap(find.byKey(FeederView.simulatePartnerButtonKey));
      await tester.pump();

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
}
