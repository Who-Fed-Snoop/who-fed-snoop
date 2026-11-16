import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';

import '../helpers/controllable_household_repository.dart';

void main() {
  group('FeederViewModel — Non-clobbering 10s LIFO Undo Stack', () {
    testWidgets(
      'logging meal then treat stacks both entries and undoes LIFO without clobbering',
      (WidgetTester tester) async {
        var now = DateTime(2026, 11, 8, 9, 0);
        final repo = InMemoryHouseholdRepository(initialClock: now);
        final sync = WidgetSyncService();
        final vm = FeederViewModel(
          repository: repo,
          widgetSyncService: sync,
          clock: () => now,
        );

        await tester.pump();
        expect(vm.isCurrentWindowFed, isFalse);
        expect(vm.canUndo, isFalse);

        // 1. Log Breakfast at t=0s
        await vm.markPetFed();
        await tester.pump();
        expect(vm.isCurrentWindowFed, isTrue);
        expect(vm.pendingUndoCount, equals(1));
        expect(vm.activeUndoEntry?.kind, equals(UndoKind.meal));
        expect(vm.undoSecondsRemaining, equals(10));
        expect(vm.undoBannerText, contains('Logged Breakfast! Undo within 10s'));

        // Advance 3s -> Breakfast has 7s left
        await tester.pump(const Duration(seconds: 3));
        expect(vm.undoSecondsRemaining, equals(7));

        // 2. Log a PB Kong treat at t=3s
        now = DateTime(2026, 11, 8, 9, 0, 3);
        await vm.logQuickTreat(TreatPreset.peanutButterKong);
        await tester.pump();

        expect(vm.todayTreatCount, equals(1));
        expect(vm.isCurrentWindowFed, isTrue);
        expect(vm.pendingUndoCount, equals(2));
        expect(vm.activeUndoEntry?.kind, equals(UndoKind.treat));
        expect(vm.undoSecondsRemaining, equals(10));
        expect(
          vm.undoBannerText,
          contains('Logged PB Kong! Undo within 10s (+1 more)'),
        );

        // 3. First Undo reverts ONLY the PB Kong treat; Breakfast stays fed & undoable!
        await vm.undoLastAction();
        await tester.pump();

        expect(vm.todayTreatCount, equals(0));
        expect(vm.isCurrentWindowFed, isTrue);
        expect(vm.pendingUndoCount, equals(1));
        expect(vm.activeUndoEntry?.kind, equals(UndoKind.meal));
        expect(vm.undoSecondsRemaining, equals(7));
        expect(vm.undoBannerText, contains('Logged Breakfast! Undo within 7s'));
        expect(vm.undoBannerText, isNot(contains('more')));

        // 4. Second Undo reverts Breakfast cleanly
        await vm.undoLastFeed();
        await tester.pump();

        expect(vm.isCurrentWindowFed, isFalse);
        expect(vm.canUndo, isFalse);
        expect(vm.pendingUndoCount, equals(0));

        vm.dispose();
        repo.dispose();
      },
    );

    testWidgets(
      'multiple treats within 10s expire independently and deleteTreat removes matching undo entry',
      (WidgetTester tester) async {
        var now = DateTime(2026, 11, 8, 11, 0);
        final repo = InMemoryHouseholdRepository(initialClock: now);
        final vm = FeederViewModel(
          repository: repo,
          widgetSyncService: WidgetSyncService(),
          clock: () => now,
        );
        await tester.pump();

        final firstTreat = await vm.logQuickTreat(TreatPreset.trainingTreat);
        await tester.pump();
        expect(firstTreat, isNotNull);

        await tester.pump(const Duration(seconds: 4));
        now = DateTime(2026, 11, 8, 11, 0, 4);
        final secondTreat = await vm.logCustomTreat(
          label: 'Blueberry Bite',
          quantity: 2,
          caloriesPerUnit: 10,
          note: 'Good recall',
        );
        await tester.pump();
        expect(secondTreat, isNotNull);
        expect(vm.pendingUndoCount, equals(2));
        expect(vm.todayTreatCount, equals(3)); // 1 + 2

        // Manually deleting the first treat from Today's Treats removes it from _undoStack
        await vm.deleteTreat(firstTreat!.id);
        await tester.pump();
        expect(vm.todayTreatCount, equals(2));
        expect(vm.pendingUndoCount, equals(1));
        expect(vm.activeUndoEntry?.entryId, equals(secondTreat!.id));

        // Remaining entry expires after 10s total
        await tester.pump(const Duration(seconds: 10));
        expect(vm.canUndo, isFalse);

        vm.dispose();
        repo.dispose();
      },
    );

    test(
      'idempotent partner-win on logFeeding never offers Undo for partner meal (#12 Bug 1B)',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 8, 30);
        final inner = InMemoryHouseholdRepository(initialClock: fixedNow);
        final controlled = ControllableHouseholdRepository(inner);
        final vm = FeederViewModel(
          repository: controlled,
          widgetSyncService: WidgetSyncService(),
          clock: () => fixedNow,
        );
        addTearDown(() {
          vm.dispose();
          inner.dispose();
        });
        await flushMicrotasks();

        // Pause household stream delivery so vm._household still looks unfed when Keni taps
        controlled.watchHouseholdGate = Completer<void>();
        await inner.logFeeding(
          householdId: InMemoryHouseholdRepository.defaultHouseholdId,
          fedByUid: InMemoryHouseholdRepository.ashleyUid,
          fedByName: 'Ashley',
          now: fixedNow.subtract(const Duration(seconds: 2)),
        );

        // Keni taps Feed; repository idempotently returns Ashley's existing event
        await vm.markPetFed();
        await flushMicrotasks();

        expect(vm.canUndo, isFalse);
        expect(vm.pendingUndoCount, equals(0));
      },
    );
  });

  group('FeederViewModel — Treats Orthogonality, Limits & Custom Schedule', () {
    test(
      'logging treats never marks meal window fed, tracks allowance & kcal, and respects pre-morning logical date',
      () async {
        // 1:30 AM on Nov 9 -> still belongs to Nov 8 logical date before 4:00 AM Breakfast!
        var now = DateTime(2026, 11, 9, 1, 30);
        final repo = InMemoryHouseholdRepository(
          initialClock: DateTime(2026, 11, 8, 12, 0),
        );
        final sync = WidgetSyncService();
        final vm = FeederViewModel(
          repository: repo,
          widgetSyncService: sync,
          clock: () => now,
        );
        addTearDown(() {
          vm.dispose();
          repo.dispose();
        });
        await flushMicrotasks();

        expect(vm.currentLogicalDate, equals('2026-11-08'));
        expect(vm.activeWindow.period, equals(MealPeriod.dinner));
        expect(vm.isCurrentWindowFed, isFalse);

        // Log 3x Crunchy Biscuit (45 kcal each) + 2x PB Kong (120 kcal each) = 5 treats (> limit 4)
        await vm.logCustomTreat(
          label: 'Crunchy Biscuit',
          quantity: 3,
          caloriesPerUnit: 45,
        );
        await vm.logCustomTreat(
          label: 'PB Kong',
          quantity: 2,
          caloriesPerUnit: 120,
        );
        await flushMicrotasks();

        expect(vm.isCurrentWindowFed, isFalse);
        expect(vm.widgetSnapshot?.isFed, isFalse);
        expect(vm.widgetSnapshot?.subheadline, contains('5/4 treats'));
        expect(vm.todayTreatCount, equals(5));
        expect(vm.todayTreatCalories, equals(3 * 45 + 2 * 120));
        expect(vm.isOverTreatLimit, isTrue);

        // Roll past 4:00 AM morning cutoff -> new logical day (2026-11-09) resets daily treat count to 0!
        now = DateTime(2026, 11, 9, 4, 5);
        vm.refreshForClockChange();

        expect(vm.currentLogicalDate, equals('2026-11-09'));
        expect(vm.activeWindow.period, equals(MealPeriod.breakfast));
        expect(vm.todayTreatCount, equals(0));
        expect(vm.isOverTreatLimit, isFalse);
      },
    );

    test(
      'updateHouseholdSettings validates schedule, saves custom windows, and preserves logged window IDs',
      () async {
        var now = DateTime(2026, 11, 8, 8, 30);
        final repo = InMemoryHouseholdRepository(initialClock: now);
        final vm = FeederViewModel(
          repository: repo,
          widgetSyncService: WidgetSyncService(),
          clock: () => now,
        );
        addTearDown(() {
          vm.dispose();
          repo.dispose();
        });
        await flushMicrotasks();

        // Log Breakfast first
        await vm.markPetFed();
        await flushMicrotasks();
        expect(vm.todayLoggedWindowIds, contains('breakfast'));

        // Reject invalid schedule (<15 min apart) cleanly
        final invalidSchedule = MealSchedule.fromWindows(const <MealWindowConfig>[
          MealWindowConfig(
            id: 'breakfast',
            period: MealPeriod.breakfast,
            label: 'Breakfast',
            emoji: '🥣',
            startHour: 8,
            startMinute: 0,
          ),
          MealWindowConfig(
            id: 'lunch',
            period: MealPeriod.lunch,
            label: 'Lunch',
            emoji: '🍲',
            startHour: 8,
            startMinute: 10,
          ),
        ]);
        final invalidSaved = await vm.updateHouseholdSettings(
          schedule: invalidSchedule,
        );
        expect(invalidSaved, isFalse);
        expect(vm.errorMessage, contains('15 minutes apart'));

        vm.dismissError();
        expect(vm.errorMessage, isNull);

        // Save valid 3-window schedule (Breakfast 6:30, Lunch 12:30, Dinner 18:30) + limit 6
        final validSchedule = MealSchedule.fromWindows(<MealWindowConfig>[
          MealWindowConfig.fromPreset(
            MealPeriod.breakfast,
            startHour: 6,
            startMinute: 30,
          ),
          MealWindowConfig.fromPreset(
            MealPeriod.lunch,
            startHour: 12,
            startMinute: 30,
          ),
          MealWindowConfig.fromPreset(
            MealPeriod.dinner,
            startHour: 18,
            startMinute: 30,
          ),
        ]);

        final saved = await vm.updateHouseholdSettings(
          schedule: validSchedule,
          dailyTreatLimit: 6,
        );
        expect(saved, isTrue);
        expect(vm.errorMessage, isNull);
        expect(vm.dailyTreatLimit, equals(6));
        expect(vm.isCurrentWindowFed, isTrue); // Breakfast 2026-11-08_breakfast still fed!

        // Advance clock to 12:45 PM -> active window is now Lunch (unfed)
        now = DateTime(2026, 11, 8, 12, 45);
        vm.refreshForClockChange();
        expect(vm.activeWindow.label, equals('Lunch'));
        expect(vm.isCurrentWindowFed, isFalse);
      },
    );
  });
}
