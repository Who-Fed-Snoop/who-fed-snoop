import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/domain/models/feeding_event.dart';
import 'package:who_fed_snoop/domain/models/household.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';

/// Test repository wrapper supporting controllable stream delays, slow writes,
/// and simulated non-InMemory backend behavior.
class _ControllableHouseholdRepository implements HouseholdRepository {
  _ControllableHouseholdRepository(this._delegate);

  final InMemoryHouseholdRepository _delegate;

  Completer<void>? watchHouseholdGate;
  Completer<void>? logFeedingGate;
  bool failLogFeeding = false;
  bool failHistoryStreams = false;
  int logFeedingCalls = 0;

  @override
  Stream<Household?> watchHousehold(String householdId) async* {
    if (watchHouseholdGate != null && !watchHouseholdGate!.isCompleted) {
      await watchHouseholdGate!.future;
    }
    yield* _delegate.watchHousehold(householdId);
  }

  @override
  Stream<List<FeedingEvent>> watchRecentFeedings(
    String householdId, {
    int limit = 50,
  }) {
    if (failHistoryStreams) {
      return Stream<List<FeedingEvent>>.error(
        StateError('Simulated feedings permission error'),
      );
    }
    return _delegate.watchRecentFeedings(householdId, limit: limit);
  }

  @override
  Stream<List<TreatEvent>> watchRecentTreats(
    String householdId, {
    int limit = 50,
  }) {
    if (failHistoryStreams) {
      return Stream<List<TreatEvent>>.error(
        StateError('Simulated treats permission error'),
      );
    }
    return _delegate.watchRecentTreats(householdId, limit: limit);
  }

  @override
  Future<Household> createHousehold({
    required String memberUid,
    required String memberName,
    required String petName,
  }) =>
      _delegate.createHousehold(
        memberUid: memberUid,
        memberName: memberName,
        petName: petName,
      );

  @override
  Future<Household> joinHouseholdByCode({
    required String joinCode,
    required String memberUid,
    required String memberName,
  }) =>
      _delegate.joinHouseholdByCode(
        joinCode: joinCode,
        memberUid: memberUid,
        memberName: memberName,
      );

  @override
  Future<Household> updateHouseholdSettings({
    required String householdId,
    required String requestingUid,
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  }) =>
      _delegate.updateHouseholdSettings(
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
  }) async {
    logFeedingCalls += 1;
    if (logFeedingGate != null && !logFeedingGate!.isCompleted) {
      await logFeedingGate!.future;
    }
    if (failLogFeeding) {
      throw StateError('Simulated Firestore write failure');
    }
    return _delegate.logFeeding(
      householdId: householdId,
      fedByUid: fedByUid,
      fedByName: fedByName,
      now: now,
      isExtraMeal: isExtraMeal,
    );
  }

  @override
  Future<void> undoFeeding({
    required String householdId,
    required String feedingId,
    required String requestingUid,
  }) =>
      _delegate.undoFeeding(
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
      _delegate.logTreat(
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
      _delegate.deleteTreat(
        householdId: householdId,
        treatId: treatId,
        requestingUid: requestingUid,
      );
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

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
        final controlled = _ControllableHouseholdRepository(inner);
        final vm = FeederViewModel(
          repository: controlled,
          widgetSyncService: WidgetSyncService(),
          clock: () => fixedNow,
        );
        addTearDown(() {
          vm.dispose();
          inner.dispose();
        });
        await _flushMicrotasks();

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
        await _flushMicrotasks();

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
        await _flushMicrotasks();

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
        await _flushMicrotasks();

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
        await _flushMicrotasks();

        // Log Breakfast first
        await vm.markPetFed();
        await _flushMicrotasks();
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
        await _flushMicrotasks();

        // Keni logs Breakfast, then immediately taps Undo
        await vm.markPetFed();
        await _flushMicrotasks();
        expect(vm.partnerNotificationBanner, isNull);

        await vm.undoLastFeed();
        await _flushMicrotasks();

        // Yesterday's Dinner by Ashley is restored to lastFeeding, MUST NOT show banner!
        expect(vm.isCurrentWindowFed, isFalse);
        expect(vm.partnerNotificationBanner, isNull);

        // Now Ashley logs Breakfast at the same fixedNow -> real partner banner MUST fire!
        await vm.simulatePartnerFeed();
        await _flushMicrotasks();
        expect(
          vm.partnerNotificationBanner,
          contains('Ashley fed Snoop Breakfast'),
        );
        vm.dismissPartnerBanner();

        // Bug 2B: Keni logs a bonus scoop (starts Undo), Ashley logs a treat, then Keni undoes bonus scoop
        await vm.markPetFed(isExtraMeal: true);
        await _flushMicrotasks();

        await repo.logTreat(
          householdId: InMemoryHouseholdRepository.defaultHouseholdId,
          givenByUid: InMemoryHouseholdRepository.ashleyUid,
          givenByName: 'Ashley',
          now: fixedNow.add(const Duration(minutes: 1)),
          preset: TreatPreset.dentalChew,
        );
        await _flushMicrotasks();
        expect(
          vm.partnerNotificationBanner,
          contains('Ashley gave Snoop Dental Chew'),
        );

        // Undoing Keni's bonus scoop MUST NOT wipe Ashley's unread treat banner!
        await vm.undoLastAction();
        await _flushMicrotasks();
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
        final controlled = _ControllableHouseholdRepository(inner);
        final vm = FeederViewModel(
          repository: controlled,
          widgetSyncService: WidgetSyncService(),
          clock: () => fixedNow,
        );
        addTearDown(inner.dispose);
        await _flushMicrotasks();

        // Gate logFeeding so we can test rapid double-tap + household switch mid-flight
        controlled.logFeedingGate = Completer<void>();

        final firstTap = vm.markPetFed(isExtraMeal: true);
        final secondTap = vm.markPetFed(isExtraMeal: true); // Blocked by _isLoggingMeal!
        await secondTap;
        expect(controlled.logFeedingCalls, equals(1));

        // Switch to a brand-new household before firstTap resolves
        await vm.createNewHousehold(memberName: 'Keni', petName: 'Max');
        await _flushMicrotasks();
        expect(vm.household?.petName, equals('Max'));
        expect(vm.partnerNotificationBanner, isNull);

        // Unblock slow logFeeding from old household -> must NOT push Undo onto Max's household!
        controlled.logFeedingGate!.complete();
        await firstTap;
        await _flushMicrotasks();
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

  group('FeederViewModel — Deep Links (/tap, /join, /s), Web Hash & Stream Errors', () {
    test(
      'cold-start /tap waits for household load, rejects wrong householdId, and suppresses banner on error (#12 Bug 6B)',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 8, 30);
        final inner = InMemoryHouseholdRepository(initialClock: fixedNow);
        final controlled = _ControllableHouseholdRepository(inner)
          ..watchHouseholdGate = Completer<void>();
        final vm = FeederViewModel(
          repository: controlled,
          widgetSyncService: WidgetSyncService(),
          clock: () => fixedNow,
        );
        addTearDown(() {
          vm.dispose();
          inner.dispose();
        });

        // Trigger /tap BEFORE watchHousehold has emitted its first snapshot
        final tapFuture = vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/tap/household_snoop_01'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(vm.isLoading, isTrue);

        // Release initial household snapshot -> /tap now logs Breakfast cleanly!
        controlled.watchHouseholdGate!.complete();
        await tapFuture;
        await _flushMicrotasks();

        expect(vm.isCurrentWindowFed, isTrue);
        expect(
          vm.partnerNotificationBanner,
          contains('Instant Tap-to-Feed: Logged Breakfast for Snoop!'),
        );

        // Wrong household ID -> sets errorMessage and does NOT overwrite banner with fake success
        vm.dismissPartnerBanner();
        await vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/tap/nonexistent_household_99'),
        );
        expect(vm.errorMessage, contains('nonexistent_household_99'));
        expect(vm.partnerNotificationBanner, isNull);
      },
    );

    test(
      'invalid /join and /s links populate errorMessage without crashing or falsely activating Dog Sitter mode (#12 Bug 6A & 6C)',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 8, 30);
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
        await _flushMicrotasks();

        // Invalid /join/TYPO99 does not throw unhandled StateError
        await vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/join/TYPO99'),
        );
        expect(vm.errorMessage, contains('TYPO99'));
        expect(vm.currentMemberName, equals('Keni'));

        // Invalid /s/sitter_xyz does NOT switch persona to Dog Sitter or show active banner
        vm.dismissError();
        await vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/s/sitter_xyz'),
        );
        expect(vm.errorMessage, isNotNull);
        expect(vm.currentMemberName, equals('Keni'));
        expect(vm.isSitterMode, isFalse);
        expect(vm.partnerNotificationBanner, isNull);

        // Valid /s/SNOOP4 activates Dog Sitter mode cleanly
        await vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/s/SNOOP4'),
        );
        expect(vm.errorMessage, isNull);
        expect(vm.currentMemberName, equals('Dog Sitter'));
        expect(vm.isSitterMode, isTrue);
        expect(
          vm.partnerNotificationBanner,
          contains('Dog Sitter Guest Pass active'),
        );
      },
    );

    test(
      'WidgetSyncService.extractWebInitialUri supports standard paths and hash-routed URLs (#12 Bug 6D)',
      () {
        expect(
          WidgetSyncService.extractWebInitialUri(
            Uri.parse('https://whofedsnoop.com/'),
          ),
          isNull,
        );
        expect(
          WidgetSyncService.extractWebInitialUri(
            Uri.parse('https://whofedsnoop.com/join/SNOOP4'),
          ),
          equals(Uri.parse('https://whofedsnoop.com/join/SNOOP4')),
        );
        expect(
          WidgetSyncService.extractWebInitialUri(
            Uri.parse('https://whofedsnoop.com/#/join/SNOOP4'),
          ),
          equals(Uri.parse('https://whofedsnoop.com/join/SNOOP4')),
        );
        expect(
          WidgetSyncService.extractWebInitialUri(
            Uri.parse('https://whofedsnoop.com/#s/SNOOP4'),
          ),
          equals(Uri.parse('https://whofedsnoop.com/s/SNOOP4')),
        );
      },
    );

    test(
      'non-InMemory repository guards simulatePartnerFeed and captures history stream errors (#12 Bug 7B & 8B)',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 10, 0);
        final inner = InMemoryHouseholdRepository(initialClock: fixedNow);
        final controlled = _ControllableHouseholdRepository(inner)..failHistoryStreams = true;
        final vm = FeederViewModel(
          repository: controlled,
          widgetSyncService: WidgetSyncService(),
          clock: () => fixedNow,
        );
        addTearDown(() {
          vm.dispose();
          inner.dispose();
        });
        await _flushMicrotasks();

        expect(vm.canSimulatePartner, isFalse);
        await vm.simulatePartnerFeed();
        expect(vm.errorMessage, contains('demo mode'));

        vm.dismissError();
        vm.toggleHistoryExpanded();
        await _flushMicrotasks();

        expect(vm.isHistoryExpanded, isTrue);
        expect(vm.errorMessage, contains('permission error'));
      },
    );
  });
}
