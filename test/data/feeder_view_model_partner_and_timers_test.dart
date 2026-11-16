import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';

import '../helpers/controllable_household_repository.dart';

void main() {
  group('FeederViewModel — Partner Notifications, Timers & Concurrency Fixes', () {
    test(
      'undoing today meal never triggers fake partner banner from yesterday, while preserving real partner banners (#12 Bug 2A & 2B)',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 9, 30);
        final repo = InMemoryHouseholdRepository(initialClock: fixedNow);
        final vm = FeederViewModel(
          repository: repo,
          widgetSyncService: WidgetSyncService(),
          clock: () => fixedNow,
        );
        addTearDown(() {
          vm.dispose();
          repo.dispose();
        });
        await flushMicrotasks();

        // Keni logs Breakfast, then immediately taps Undo
        await vm.markPetFed();
        await flushMicrotasks();
        expect(vm.partnerNotificationBanner, isNull);

        await vm.undoLastFeed();
        await flushMicrotasks();

        // Yesterday's Dinner by Ashley is restored to lastFeeding, MUST NOT show banner!
        expect(vm.isCurrentWindowFed, isFalse);
        expect(vm.partnerNotificationBanner, isNull);

        // Now Ashley logs Breakfast at the same fixedNow -> real partner banner MUST fire!
        await vm.simulatePartnerFeed();
        await flushMicrotasks();
        expect(
          vm.partnerNotificationBanner,
          contains('Ashley fed Snoop Breakfast'),
        );
        vm.dismissPartnerBanner();

        // Bug 2B: Keni logs a bonus scoop (starts Undo), Ashley logs a treat, then Keni undoes bonus scoop
        await vm.markPetFed(isExtraMeal: true);
        await flushMicrotasks();

        await repo.logTreat(
          householdId: InMemoryHouseholdRepository.defaultHouseholdId,
          givenByUid: InMemoryHouseholdRepository.ashleyUid,
          givenByName: 'Ashley',
          now: fixedNow.add(const Duration(minutes: 1)),
          preset: TreatPreset.dentalChew,
        );
        await flushMicrotasks();
        expect(
          vm.partnerNotificationBanner,
          contains('Ashley gave Snoop Dental Chew'),
        );

        // Undoing Keni's bonus scoop MUST NOT wipe Ashley's unread treat banner!
        await vm.undoLastAction();
        await flushMicrotasks();
        expect(
          vm.partnerNotificationBanner,
          contains('Ashley gave Snoop Dental Chew'),
        );
      },
    );

    testWidgets(
      'window transition timer automatically flips Fed Breakfast to Hungry Dinner and syncs Home Widget (#12 Bug 3)',
      (WidgetTester tester) async {
        var now = DateTime(2026, 11, 8, 13, 59, 55); // 5s before 2:00 PM Dinner
        final repo = InMemoryHouseholdRepository(initialClock: now);
        final sync = WidgetSyncService();
        final vm = FeederViewModel(
          repository: repo,
          widgetSyncService: sync,
          clock: () => now,
        );
        await tester.pump();

        await vm.markPetFed();
        await tester.pump();
        expect(vm.activeWindow.period, equals(MealPeriod.breakfast));
        expect(vm.isCurrentWindowFed, isTrue);
        expect(sync.latestSnapshot?.isFed, isTrue);

        // Advance wall clock and pump past 14:00:00 without any user tap or repo write
        now = DateTime(2026, 11, 8, 14, 0, 1);
        await tester.pump(const Duration(seconds: 6));

        expect(vm.activeWindow.period, equals(MealPeriod.dinner));
        expect(vm.isCurrentWindowFed, isFalse);
        expect(sync.latestSnapshot?.isFed, isFalse);
        expect(sync.latestSnapshot?.headline, contains('Snoop needs Dinner'));

        vm.dispose();
        repo.dispose();
      },
    );

    test(
      'in-flight guard blocks duplicate rapid taps and household switch / dispose guards late completions (#12 Bug 4 & 5B)',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 9, 0);
        final inner = InMemoryHouseholdRepository(initialClock: fixedNow);
        final controlled = ControllableHouseholdRepository(inner);
        final vm = FeederViewModel(
          repository: controlled,
          widgetSyncService: WidgetSyncService(),
          clock: () => fixedNow,
        );
        addTearDown(inner.dispose);
        await flushMicrotasks();

        // Gate logFeeding so we can test rapid double-tap + household switch mid-flight
        controlled.logFeedingGate = Completer<void>();

        final firstTap = vm.markPetFed(isExtraMeal: true);
        final secondTap = vm.markPetFed(isExtraMeal: true); // Blocked by _isLoggingMeal!
        await secondTap;
        expect(controlled.logFeedingCalls, equals(1));

        // Switch to a brand-new household before firstTap resolves
        await vm.createNewHousehold(memberName: 'Keni', petName: 'Max');
        await flushMicrotasks();
        expect(vm.household?.petName, equals('Max'));
        expect(vm.partnerNotificationBanner, isNull);

        // Unblock slow logFeeding from old household -> must NOT push Undo onto Max's household!
        controlled.logFeedingGate!.complete();
        await firstTap;
        await flushMicrotasks();
        expect(vm.canUndo, isFalse);

        // Dispose while another logFeeding is in-flight -> must not throw or leak timers
        controlled.logFeedingGate = Completer<void>();
        final lateTap = vm.markPetFed();
        vm.dispose();
        controlled.logFeedingGate!.complete();
        await lateTap;
      },
    );
  });
}
