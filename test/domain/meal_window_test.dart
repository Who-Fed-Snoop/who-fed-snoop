import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/domain/models/deep_link_route.dart';
import 'package:who_fed_snoop/domain/models/feeding_event.dart';
import 'package:who_fed_snoop/domain/models/household.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';

void main() {
  group('ActiveMealWindow (default 2-window schedule)', () {
    test('returns Breakfast window between 4:00 AM and 1:59 PM', () {
      final morning = DateTime(2026, 11, 8, 8, 15);
      final window = ActiveMealWindow.forTime(morning);

      expect(window.period, equals(MealPeriod.breakfast));
      expect(window.windowId, equals('breakfast'));
      expect(window.label, equals('Breakfast'));
      expect(window.emoji, equals('🥣'));
      expect(window.windowDate, equals('2026-11-08'));
      expect(window.deterministicId, equals('2026-11-08_breakfast'));
      expect(window.nextTransitionTime, equals(DateTime(2026, 11, 8, 14, 0)));
      expect(window.nextWindowLabel, equals('Dinner'));
      expect(window.nextWindowEmoji, equals('🍖'));
    });

    test('transitions automatically to Dinner at 2:00 PM (14:00)', () {
      final afternoon = DateTime(2026, 11, 8, 14, 0);
      final window = ActiveMealWindow.forTime(afternoon);

      expect(window.period, equals(MealPeriod.dinner));
      expect(window.windowId, equals('dinner'));
      expect(window.windowDate, equals('2026-11-08'));
      expect(window.deterministicId, equals('2026-11-08_dinner'));
      expect(window.nextTransitionTime, equals(DateTime(2026, 11, 9, 4, 0)));
      expect(window.nextWindowLabel, equals('Breakfast'));
      expect(window.nextWindowEmoji, equals('🥣'));
    });

    test('keeps previous evening Dinner window active between midnight and 3:59 AM', () {
      final lateNight = DateTime(2026, 11, 9, 1, 30);
      final window = ActiveMealWindow.forTime(lateNight);

      expect(window.period, equals(MealPeriod.dinner));
      expect(window.windowDate, equals('2026-11-08'));
      expect(window.deterministicId, equals('2026-11-08_dinner'));
      expect(window.nextTransitionTime, equals(DateTime(2026, 11, 9, 4, 0)));
    });
  });

  group('Custom MealSchedule & Validation', () {
    test('resolves 4-window minute-precision schedule and midnight wrap-around', () {
      final schedule = MealSchedule.fromWindows(<MealWindowConfig>[
        MealWindowConfig.fromPreset(
          MealPeriod.breakfast,
          startHour: 6,
          startMinute: 30,
        ),
        MealWindowConfig.fromPreset(
          MealPeriod.lunch,
          startHour: 12,
          startMinute: 15,
        ),
        MealWindowConfig.fromPreset(
          MealPeriod.dinner,
          startHour: 17,
          startMinute: 45,
        ),
        const MealWindowConfig(
          id: 'bedtime_snack',
          period: MealPeriod.lateSnack,
          label: 'Bedtime Biscuit',
          emoji: '🌙',
          startHour: 21,
          startMinute: 30,
        ),
      ]);

      expect(schedule.validate(), isNull);

      // 06:29 AM -> still yesterday's Bedtime Biscuit!
      final beforeMorning = ActiveMealWindow.forTime(
        DateTime(2026, 11, 9, 6, 29),
        schedule: schedule,
      );
      expect(beforeMorning.windowId, equals('bedtime_snack'));
      expect(beforeMorning.label, equals('Bedtime Biscuit'));
      expect(beforeMorning.windowDate, equals('2026-11-08'));
      expect(beforeMorning.deterministicId, equals('2026-11-08_bedtime_snack'));
      expect(
        beforeMorning.nextTransitionTime,
        equals(DateTime(2026, 11, 9, 6, 30)),
      );
      expect(beforeMorning.nextWindowLabel, equals('Breakfast'));

      // 06:30 AM -> flips to today's Breakfast
      final morning = ActiveMealWindow.forTime(
        DateTime(2026, 11, 9, 6, 30),
        schedule: schedule,
      );
      expect(morning.windowId, equals('breakfast'));
      expect(morning.windowDate, equals('2026-11-09'));
      expect(morning.nextTransitionTime, equals(DateTime(2026, 11, 9, 12, 15)));
      expect(morning.nextWindowLabel, equals('Lunch'));

      // 12:15 PM -> Lunch
      final midday = ActiveMealWindow.forTime(
        DateTime(2026, 11, 9, 12, 15),
        schedule: schedule,
      );
      expect(midday.period, equals(MealPeriod.lunch));
      expect(midday.nextTransitionTime, equals(DateTime(2026, 11, 9, 17, 45)));

      // 22:00 -> Bedtime Biscuit wrapping to tomorrow 06:30
      final night = ActiveMealWindow.forTime(
        DateTime(2026, 11, 9, 22, 0),
        schedule: schedule,
      );
      expect(night.windowId, equals('bedtime_snack'));
      expect(night.windowDate, equals('2026-11-09'));
      expect(night.nextTransitionTime, equals(DateTime(2026, 11, 10, 6, 30)));
      expect(schedule.logicalDateFor(DateTime(2026, 11, 10, 2, 0)), equals('2026-11-09'));
    });

    test('does not crash with AssertionError when deserializing inverted legacy hours', () {
      final malformed = MealSchedule.fromJson(<String, Object?>{
        'breakfastStartHour': 18,
        'dinnerStartHour': 6,
      });

      // Safe runtime resolution without throwing AssertionError
      final window = ActiveMealWindow.forTime(
        DateTime(2026, 11, 8, 10, 0),
        schedule: malformed,
      );
      expect(window.windowDate, equals('2026-11-08'));

      // Explicit validate() reports the invalid hour order
      expect(malformed.validate(), isNotNull);
    });

    test('validates window count, enabled count, duplicate IDs, and 15-min spacing', () {
      // Zero enabled windows
      final noneEnabled = MealSchedule.fromWindows(<MealWindowConfig>[
        MealWindowConfig.fromPreset(MealPeriod.breakfast, enabled: false),
      ]);
      expect(noneEnabled.validate(), contains('At least 1'));

      // >6 windows
      final sevenWindows = MealSchedule.fromWindows(
        List<MealWindowConfig>.generate(
          7,
          (i) => MealWindowConfig(
            id: 'win_$i',
            period: MealPeriod.custom,
            label: 'Meal $i',
            emoji: '🐾',
            startHour: i * 2,
          ),
        ),
      );
      expect(sevenWindows.validate(), contains('Maximum 6'));

      // <15 minutes apart intra-day
      final tooClose = MealSchedule.fromWindows(<MealWindowConfig>[
        MealWindowConfig.fromPreset(MealPeriod.breakfast, startHour: 8, startMinute: 0),
        MealWindowConfig.fromPreset(MealPeriod.lunch, startHour: 8, startMinute: 10),
      ]);
      expect(tooClose.validate(), contains('15 minutes apart'));

      // <15 minutes apart across midnight (23:55 and 00:05 = 10 min gap)
      final wrapTooClose = MealSchedule.fromWindows(<MealWindowConfig>[
        MealWindowConfig.fromPreset(MealPeriod.breakfast, startHour: 0, startMinute: 5),
        MealWindowConfig.fromPreset(MealPeriod.lateSnack, startHour: 23, startMinute: 55),
      ]);
      expect(wrapTooClose.validate(), contains('across midnight'));

      // Duplicate IDs
      final dupIds = MealSchedule.fromWindows(const <MealWindowConfig>[
        MealWindowConfig(
          id: 'custom_1',
          period: MealPeriod.custom,
          label: 'First',
          emoji: '🥣',
          startHour: 7,
        ),
        MealWindowConfig(
          id: 'custom_1',
          period: MealPeriod.custom,
          label: 'Second',
          emoji: '🍖',
          startHour: 18,
        ),
      ]);
      expect(dupIds.validate(), contains('Duplicate'));
    });

    test('trims leading/trailing whitespace on id, label, and emoji for rules & deterministicId',
        () {
      // 24 trimmed chars ('Second Breakfast Window!') + trailing spaces = 26 raw chars.
      final schedule = MealSchedule.fromWindows(const <MealWindowConfig>[
        MealWindowConfig(
          id: ' custom_1 ',
          period: MealPeriod.custom,
          label: ' Second Breakfast Window! ',
          emoji: ' 🥣 ',
          startHour: 8,
          startMinute: 0,
        ),
      ]);

      expect(schedule.validate(), isNull);
      final win = schedule.allWindows.single;
      expect(win.id, equals('custom_1'));
      expect(win.label, equals('Second Breakfast Window!'));
      expect(win.label.length, equals(24));
      expect(win.emoji, equals('🥣'));

      final serialized =
          (schedule.toJson()['windows'] as List<Object?>).single as Map<String, Object?>;
      expect(serialized['id'], equals('custom_1'));
      expect(serialized['label'], equals('Second Breakfast Window!'));
      expect(serialized['emoji'], equals('🥣'));

      // Also verify direct const MealSchedule(windows: [...]) trims in ActiveMealWindow.forTime & toJson
      const directSchedule = MealSchedule(
        windows: <MealWindowConfig>[
          MealWindowConfig(
            id: ' custom_2 ',
            period: MealPeriod.custom,
            label: ' Late Nightibble ',
            emoji: ' 🌙 ',
            startHour: 21,
          ),
        ],
      );
      final active = ActiveMealWindow.forTime(
        DateTime(2026, 11, 8, 22, 0),
        schedule: directSchedule,
      );
      expect(active.windowId, equals('custom_2'));
      expect(active.label, equals('Late Nightibble'));
      expect(active.emoji, equals('🌙'));
      expect(active.deterministicId, equals('2026-11-08_custom_2'));
    });
  });

  group('FeedingEvent, TreatEvent & Household helpers', () {
    test('bonus meal never satisfies a regular window via matchesWindow', () {
      final window = ActiveMealWindow.forTime(DateTime(2026, 11, 8, 9, 0));
      final bonus = FeedingEvent(
        id: '2026-11-08_breakfast_extra_1',
        mealPeriod: MealPeriod.breakfast,
        windowId: 'breakfast',
        windowDate: '2026-11-08',
        fedByUid: 'uid_keni',
        fedByName: 'Keni',
        fedAt: DateTime(2026, 11, 8, 9, 0),
        isExtraMeal: true,
      );

      expect(bonus.matchesWindow(window), isFalse);
    });

    test('TreatEvent supports preset.id and preset.name plus Firestore Timestamp', () {
      final ts = Timestamp.fromDate(DateTime(2026, 11, 8, 15, 30));
      final fromId = TreatEvent.fromJson(<String, Object?>{
        'id': 'treat_1',
        'preset': 'pb_kong',
        'label': 'PB Kong',
        'emoji': '🥜',
        'quantity': 2,
        'caloriesPerUnit': 120,
        'logicalDate': '2026-11-08',
        'givenByUid': 'uid_ashley',
        'givenByName': 'Ashley',
        'givenAt': ts,
        'note': 'Frozen kong',
      });

      expect(fromId.preset, equals(TreatPreset.peanutButterKong));
      expect(fromId.totalCalories, equals(240));
      expect(fromId.note, equals('Frozen kong'));
      expect(TreatPreset.fromString('peanutButterKong'), equals(TreatPreset.peanutButterKong));

      final household = Household(
        id: 'h1',
        joinCode: 'SNOOP4',
        petName: 'Snoop',
        createdAt: DateTime(2026, 11, 8, 8, 0),
        members: const <String, HouseholdMember>{},
        dailyTreatLimit: 1,
        todayTreats: <TreatEvent>[fromId],
      );

      expect(household.treatCountForDate('2026-11-08'), equals(2));
      expect(household.treatCaloriesForDate('2026-11-08'), equals(240));
      expect(household.isOverTreatLimit('2026-11-08'), isTrue);
      expect(household.treatCountForDate('2026-11-09'), equals(0));
    });
  });

  group('WhofedsnoopDeepLink (whofedsnoop.com)', () {
    test('parses partner invite link /join/SNOOP4', () {
      final uri = Uri.parse('https://whofedsnoop.com/join/snoop4');
      final parsed = WhofedsnoopDeepLink.tryParse(uri);

      expect(parsed, isNotNull);
      expect(parsed!.kind, equals(DeepLinkKind.joinHousehold));
      expect(parsed.targetId, equals('SNOOP4'));
    });

    test('parses NFC food-bin sticker link /tap/household_snoop_01', () {
      final uri = Uri.parse('https://www.whofedsnoop.com/tap/household_snoop_01');
      final parsed = WhofedsnoopDeepLink.tryParse(uri);

      expect(parsed, isNotNull);
      expect(parsed!.kind, equals(DeepLinkKind.nfcTapToFeed));
      expect(parsed.targetId, equals('household_snoop_01'));
    });

    test('parses dog sitter web pass /s/sitter_xyz', () {
      final uri = Uri.parse('https://whofedsnoop.com/s/sitter_xyz');
      final parsed = WhofedsnoopDeepLink.tryParse(uri);

      expect(parsed, isNotNull);
      expect(parsed!.kind, equals(DeepLinkKind.sitterGuestPass));
      expect(parsed.targetId, equals('sitter_xyz'));
    });
  });
}
