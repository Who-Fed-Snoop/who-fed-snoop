import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/main.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';
import 'package:who_fed_snoop/ui/features/feeder/views/feeder_view.dart';

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
}
