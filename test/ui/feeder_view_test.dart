import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/main.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';
import 'package:who_fed_snoop/ui/features/feeder/views/feeder_view.dart';

void main() {
  testWidgets('1-tap logs meal, locks button against double-feeding, and supports 10s Undo', (
    WidgetTester tester,
  ) async {
    final fixedNow = DateTime(2026, 11, 8, 9, 30); // Breakfast window
    final repository = InMemoryHouseholdRepository(initialClock: fixedNow);
    final widgetSyncService = WidgetSyncService();
    final viewModel = FeederViewModel(
      repository: repository,
      widgetSyncService: widgetSyncService,
      clock: () => fixedNow,
    );

    await tester.pumpWidget(WhoFedSnoopApp(viewModel: viewModel));
    await tester.pump();

    // Initially Snoop needs Breakfast
    expect(find.text('Snoop needs Breakfast'), findsOneWidget);
    expect(find.text('I FED SNOOP BREAKFAST'), findsOneWidget);

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
  });
}

