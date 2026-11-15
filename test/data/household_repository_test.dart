import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';

void main() {
  group('InMemoryHouseholdRepository — Custom Windows & Schedule Edits', () {
    test(
      'preserves earlier window fed status in todayMeals when later window is logged then shifted forward',
      () async {
        final seedTime = DateTime(2026, 11, 8, 7, 0);
        final repo = InMemoryHouseholdRepository(initialClock: seedTime);
        addTearDown(repo.dispose);

        const hId = InMemoryHouseholdRepository.defaultHouseholdId;
        const keni = InMemoryHouseholdRepository.keniUid;
        const ashley = InMemoryHouseholdRepository.ashleyUid;

        // Configure 3-window schedule: Breakfast 7:00, Lunch 12:00, Dinner 18:00
        final threeWindowSchedule = MealSchedule.fromWindows(<MealWindowConfig>[
          MealWindowConfig.fromPreset(MealPeriod.breakfast, startHour: 7),
          MealWindowConfig.fromPreset(MealPeriod.lunch, startHour: 12),
          MealWindowConfig.fromPreset(MealPeriod.dinner, startHour: 18),
        ]);

        await repo.updateHouseholdSettings(
          householdId: hId,
          requestingUid: keni,
          schedule: threeWindowSchedule,
        );

        // 8:00 AM: Keni logs Breakfast
        final breakfast = await repo.logFeeding(
          householdId: hId,
          fedByUid: keni,
          fedByName: 'Keni',
          now: DateTime(2026, 11, 8, 8, 0),
        );
        expect(breakfast.id, equals('2026-11-08_breakfast'));

        // 12:15 PM: Ashley logs Lunch (lastFeeding now points to Lunch)
        final lunch = await repo.logFeeding(
          householdId: hId,
          fedByUid: ashley,
          fedByName: 'Ashley',
          now: DateTime(2026, 11, 8, 12, 15),
        );
        expect(lunch.id, equals('2026-11-08_lunch'));

        // 12:30 PM: Household shifts Lunch start time to 1:00 PM (13:00),
        // making 12:30 PM fall back inside the Breakfast window!
        final shiftedSchedule = MealSchedule.fromWindows(<MealWindowConfig>[
          MealWindowConfig.fromPreset(MealPeriod.breakfast, startHour: 7),
          MealWindowConfig.fromPreset(MealPeriod.lunch, startHour: 13),
          MealWindowConfig.fromPreset(MealPeriod.dinner, startHour: 18),
        ]);
        final updatedHousehold = await repo.updateHouseholdSettings(
          householdId: hId,
          requestingUid: ashley,
          schedule: shiftedSchedule,
        );

        final activeAt1230 = ActiveMealWindow.forTime(
          DateTime(2026, 11, 8, 12, 30),
          schedule: updatedHousehold.schedule,
        );
        expect(activeAt1230.windowId, equals('breakfast'));

        // Breakfast MUST still report fed via todayMeals!
        expect(updatedHousehold.isFedForWindow(activeAt1230), isTrue);
        expect(
          updatedHousehold.feedingForWindow(activeAt1230)?.fedByName,
          equals('Keni'),
        );
      },
    );

    test('rejects invalid schedule updates and non-member updates', () async {
      final repo = InMemoryHouseholdRepository(
        initialClock: DateTime(2026, 11, 8, 9, 0),
      );
      addTearDown(repo.dispose);

      const hId = InMemoryHouseholdRepository.defaultHouseholdId;

      await expectLater(
        repo.updateHouseholdSettings(
          householdId: hId,
          requestingUid: 'uid_stranger',
          dailyTreatLimit: 5,
        ),
        throwsStateError,
      );

      final invalidSchedule = MealSchedule.fromWindows(<MealWindowConfig>[
        MealWindowConfig.fromPreset(MealPeriod.breakfast, enabled: false),
      ]);
      await expectLater(
        repo.updateHouseholdSettings(
          householdId: hId,
          requestingUid: InMemoryHouseholdRepository.keniUid,
          schedule: invalidSchedule,
        ),
        throwsArgumentError,
      );
    });
  });

  group('InMemoryHouseholdRepository — Idempotency, Bonus Meals & Undo', () {
    test('simultaneous regular meal taps are idempotent and return existing event', () async {
      final now = DateTime(2026, 11, 8, 8, 30);
      final repo = InMemoryHouseholdRepository(initialClock: now);
      addTearDown(repo.dispose);

      const hId = InMemoryHouseholdRepository.defaultHouseholdId;

      final first = await repo.logFeeding(
        householdId: hId,
        fedByUid: InMemoryHouseholdRepository.keniUid,
        fedByName: 'Keni',
        now: now,
      );
      final second = await repo.logFeeding(
        householdId: hId,
        fedByUid: InMemoryHouseholdRepository.ashleyUid,
        fedByName: 'Ashley',
        now: now.add(const Duration(milliseconds: 50)),
      );

      expect(second.id, equals(first.id));
      expect(second.fedByUid, equals(InMemoryHouseholdRepository.keniUid));
    });

    test(
      'bonus meal does not mark unfed window as fed, and undoing bonus meal restores regular meal',
      () async {
        final now = DateTime(2026, 11, 8, 9, 0);
        final repo = InMemoryHouseholdRepository(initialClock: now);
        addTearDown(repo.dispose);

        const hId = InMemoryHouseholdRepository.defaultHouseholdId;
        const keni = InMemoryHouseholdRepository.keniUid;
        final window = ActiveMealWindow.forTime(now);

        // 1. Log bonus scoop while Breakfast is STILL unfed
        final bonusWhileUnfed = await repo.logFeeding(
          householdId: hId,
          fedByUid: keni,
          fedByName: 'Keni',
          now: now,
          isExtraMeal: true,
        );
        var current = await repo.watchHousehold(hId).first;
        expect(current!.isFedForWindow(window), isFalse);
        await repo.undoFeeding(
          householdId: hId,
          feedingId: bonusWhileUnfed.id,
          requestingUid: keni,
        );

        // 2. Log regular Breakfast, then log two rapid bonus scoops at identical clock instant
        final regularMeal = await repo.logFeeding(
          householdId: hId,
          fedByUid: keni,
          fedByName: 'Keni',
          now: now,
        );
        final bonus1 = await repo.logFeeding(
          householdId: hId,
          fedByUid: InMemoryHouseholdRepository.ashleyUid,
          fedByName: 'Ashley',
          now: now,
          isExtraMeal: true,
        );
        final bonus2 = await repo.logFeeding(
          householdId: hId,
          fedByUid: InMemoryHouseholdRepository.ashleyUid,
          fedByName: 'Ashley',
          now: now,
          isExtraMeal: true,
        );

        // Rapid taps with frozen clock still get distinct IDs
        expect(bonus1.id, isNot(equals(bonus2.id)));

        // Hero window feeding still points to Keni's regular Breakfast, not the bonus scoop
        current = await repo.watchHousehold(hId).first;
        expect(current!.feedingForWindow(window)?.id, equals(regularMeal.id));
        expect(current.feedingForWindow(window)?.fedByName, equals('Keni'));

        // Undoing both bonus scoops restores lastFeeding to Keni's regular Breakfast
        await repo.undoFeeding(
          householdId: hId,
          feedingId: bonus2.id,
          requestingUid: keni, // Any household member can undo
        );
        await repo.undoFeeding(
          householdId: hId,
          feedingId: bonus1.id,
          requestingUid: keni,
        );

        current = await repo.watchHousehold(hId).first;
        expect(current!.isFedForWindow(window), isTrue);
        expect(current.lastFeeding?.id, equals(regularMeal.id));
      },
    );
  });

  group('InMemoryHouseholdRepository & WidgetSyncService — Treats Orthogonality', () {
    test(
      'logging and deleting treats never mutates meal state, respects midnight logicalDate, and updates widget subheadline',
      () async {
        final morning = DateTime(2026, 11, 8, 9, 0);
        final repo = InMemoryHouseholdRepository(initialClock: morning);
        final widgetSync = WidgetSyncService();
        addTearDown(repo.dispose);

        const hId = InMemoryHouseholdRepository.defaultHouseholdId;
        const keni = InMemoryHouseholdRepository.keniUid;
        const ashley = InMemoryHouseholdRepository.ashleyUid;

        final beforeHousehold = (await repo.watchHousehold(hId).first)!;
        final morningWindow = ActiveMealWindow.forTime(morning);
        expect(beforeHousehold.isFedForWindow(morningWindow), isFalse);

        // Rapid-tap 2 treats at the exact same frozen timestamp
        final t1 = await repo.logTreat(
          householdId: hId,
          givenByUid: keni,
          givenByName: 'Keni',
          now: morning,
          preset: TreatPreset.trainingTreat,
          quantity: 2,
        );
        final t2 = await repo.logTreat(
          householdId: hId,
          givenByUid: ashley,
          givenByName: 'Ashley',
          now: morning,
          preset: TreatPreset.peanutButterKong,
          note: 'Post-walk kong',
        );

        expect(t1.id, isNot(equals(t2.id)));
        expect(t1.logicalDate, equals('2026-11-08'));

        var updated = (await repo.watchHousehold(hId).first)!;
        // Meal state & lastFeeding MUST remain completely untouched!
        expect(updated.isFedForWindow(morningWindow), isFalse);
        expect(updated.lastFeeding, equals(beforeHousehold.lastFeeding));

        // Treat counts & calories aggregate accurately (2 training + 1 kong = 3 treats, 150 kcal)
        expect(updated.treatCountForDate('2026-11-08'), equals(3));
        expect(updated.treatCaloriesForDate('2026-11-08'), equals(150));
        expect(updated.isOverTreatLimit('2026-11-08'), isFalse);

        // Widget sync keeps isFed == false while appending treat progress to subheadline
        final snapshot = await widgetSync.syncHouseholdState(
          household: updated,
          activeWindow: morningWindow,
          now: morning,
        );
        expect(snapshot.isFed, isFalse);
        expect(snapshot.headline, contains('Snoop needs Breakfast'));
        expect(snapshot.subheadline, contains('🦴 3/4 treats'));

        // Late-night treat at 1:30 AM on Nov 9 (before 4:00 AM Breakfast cutoff)
        // attaches to Nov 8's logical date and triggers over-limit (> 4)!
        final lateNightTreat = await repo.logTreat(
          householdId: hId,
          givenByUid: keni,
          givenByName: 'Keni',
          now: DateTime(2026, 11, 9, 1, 30),
          preset: TreatPreset.dentalChew,
          quantity: 2,
        );
        expect(lateNightTreat.logicalDate, equals('2026-11-08'));

        updated = (await repo.watchHousehold(hId).first)!;
        expect(updated.treatCountForDate('2026-11-08'), equals(5));
        expect(updated.isOverTreatLimit('2026-11-08'), isTrue);
        // Meanwhile Nov 9 (starting at 4:00 AM) starts fresh at 0 treats!
        expect(updated.treatCountForDate('2026-11-09'), equals(0));

        // Stream history returns all 3 treat logs newest-first
        final recentTreats = await repo.watchRecentTreats(hId).first;
        expect(recentTreats.length, equals(3));
        expect(recentTreats.first.id, equals(lateNightTreat.id));

        // Partner (Keni) deletes Ashley's treat; meal status still untouched
        await repo.deleteTreat(
          householdId: hId,
          treatId: t2.id,
          requestingUid: keni,
        );
        updated = (await repo.watchHousehold(hId).first)!;
        expect(updated.treatCountForDate('2026-11-08'), equals(4));
        expect(updated.isOverTreatLimit('2026-11-08'), isFalse);
      },
    );
  });

  group('InMemoryHouseholdRepository — Member Display Name Sync (FB-001)', () {
    test(
      'updateMemberName registers new member, updates existing member preserving joinedAt, and rejects unknown household',
      () async {
        final seedNow = DateTime(2026, 11, 8, 9, 0);
        final repo = InMemoryHouseholdRepository(initialClock: seedNow);
        addTearDown(repo.dispose);

        const hId = InMemoryHouseholdRepository.defaultHouseholdId;
        final initial = (await repo.watchHousehold(hId).first)!;
        final originalJoinedAt = initial.members[InMemoryHouseholdRepository.ashleyUid]!.joinedAt;

        // 1. Update existing member preserves joinedAt and updates name (sanitized & capped at 50)
        final updatedExisting = await repo.updateMemberName(
          householdId: hId,
          memberUid: InMemoryHouseholdRepository.ashleyUid,
          memberName: '  Ashley Keni  ',
        );
        final ashleyMember = updatedExisting.members[InMemoryHouseholdRepository.ashleyUid]!;
        expect(ashleyMember.name, equals('Ashley Keni'));
        expect(ashleyMember.joinedAt, equals(originalJoinedAt));

        // 2. Register a previously unknown device UID without clobbering existing members
        final longName = 'X' * 65;
        final addedMember = await repo.updateMemberName(
          householdId: hId,
          memberUid: 'uid_anon_device_2',
          memberName: longName,
        );
        expect(addedMember.members['uid_anon_device_2']?.name.length, equals(50));
        expect(addedMember.members[InMemoryHouseholdRepository.keniUid]?.name, equals('Keni'));
        expect(
          addedMember.members[InMemoryHouseholdRepository.ashleyUid]?.name,
          equals('Ashley Keni'),
        );

        // 3. Rejects nonexistent household
        await expectLater(
          repo.updateMemberName(
            householdId: 'missing_household',
            memberUid: 'uid_anon_device_2',
            memberName: 'Ashley',
          ),
          throwsStateError,
        );
      },
    );
  });
}
