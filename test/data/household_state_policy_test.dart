import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:who_fed_snoop/data/repositories/firestore_household_mapper.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/repositories/household_state_policy.dart';
import 'package:who_fed_snoop/domain/models/feeding_event.dart';
import 'package:who_fed_snoop/domain/models/household.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/deep_link_coordinator.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/partner_activity_detector.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/undo_stack_controller.dart';

void main() {
  group('HouseholdStatePolicy', () {
    test('sanitizeName trims, falls back on empty, and truncates to maxLength', () {
      expect(
        HouseholdStatePolicy.sanitizeName('  Ashley  ', fallback: 'Keni', maxLength: 50),
        equals('Ashley'),
      );
      expect(
        HouseholdStatePolicy.sanitizeName('   ', fallback: 'Keni', maxLength: 50),
        equals('Keni'),
      );
      expect(
        HouseholdStatePolicy.sanitizeName('A' * 65, fallback: 'Member', maxLength: 50),
        equals('A' * 50),
      );
    });

    test('resolveInMemoryUidForName maps Keni, Ashley, fallback, and custom slugs', () {
      expect(
        HouseholdStatePolicy.resolveInMemoryUidForName('  KENI '),
        equals(HouseholdStatePolicy.keniUid),
      );
      expect(
        HouseholdStatePolicy.resolveInMemoryUidForName('ashley'),
        equals(HouseholdStatePolicy.ashleyUid),
      );
      expect(
        HouseholdStatePolicy.resolveInMemoryUidForName('Grandma'),
        equals('uid_grandma'),
      );
      expect(
        HouseholdStatePolicy.resolveInMemoryUidForName('Dog Sitter'),
        equals('uid_dog_sitter'),
      );
      expect(
        HouseholdStatePolicy.resolveInMemoryUidForName('Sam', fallback: 'uid_custom_auth'),
        equals('uid_custom_auth'),
      );
      expect(
        HouseholdStatePolicy.resolveInMemoryUidForName('   '),
        equals(HouseholdStatePolicy.keniUid),
      );
    });

    test('resolveBoundMemberName & shouldRegisterMemberOnColdStart avoid clobbering', () {
      expect(HouseholdStatePolicy.resolveBoundMemberName(null), isNull);
      expect(HouseholdStatePolicy.resolveBoundMemberName('   '), isNull);
      expect(HouseholdStatePolicy.resolveBoundMemberName('  Ashley '), equals('Ashley'));

      expect(
        HouseholdStatePolicy.shouldRegisterMemberOnColdStart(
          rawMembers: <String, Object?>{'uid_a': <String, Object?>{}},
          memberUid: 'uid_a',
          boundMemberName: 'Ashley',
        ),
        isFalse,
      );
      expect(
        HouseholdStatePolicy.shouldRegisterMemberOnColdStart(
          rawMembers: <String, Object?>{'uid_a': <String, Object?>{}},
          memberUid: 'uid_b',
          boundMemberName: 'Ashley',
        ),
        isTrue,
      );
      expect(
        HouseholdStatePolicy.shouldRegisterMemberOnColdStart(
          rawMembers: <String, Object?>{},
          memberUid: 'uid_b',
          boundMemberName: null,
        ),
        isFalse,
      );
    });

    test('applyMemberNameUpdate preserves fcmToken and skips no-op updates', () {
      final now = DateTime(2026, 11, 8, 9, 0);
      final household = Household(
        id: 'h_1',
        petName: 'Snoop',
        joinCode: 'SNOOP4',
        members: <String, HouseholdMember>{
          'uid_keni': HouseholdMember(
            uid: 'uid_keni',
            name: 'Keni',
            fcmToken: 'tok_123',
            joinedAt: now.subtract(const Duration(days: 5)),
          ),
        },
        createdAt: now.subtract(const Duration(days: 5)),
      );

      final noOp = HouseholdStatePolicy.applyMemberNameUpdate(
        household,
        memberUid: 'uid_keni',
        memberName: '  Keni ',
        now: now,
      );
      expect(noOp.changed, isFalse);

      final renamed = HouseholdStatePolicy.applyMemberNameUpdate(
        household,
        memberUid: 'uid_keni',
        memberName: 'Keni K',
        now: now,
      );
      expect(renamed.changed, isTrue);
      expect(renamed.isNewMember, isFalse);
      expect(renamed.member.fcmToken, equals('tok_123'));
      expect(renamed.household.members['uid_keni']?.name, equals('Keni K'));

      final added = HouseholdStatePolicy.applyMemberNameUpdate(
        household,
        memberUid: 'uid_sitter',
        memberName: 'Dog Sitter',
        now: now,
      );
      expect(added.changed, isTrue);
      expect(added.isNewMember, isTrue);
      expect(added.household.members['uid_sitter']?.name, equals('Dog Sitter'));
    });

    test('validateSettingsInputs, validateTreatInputs, and generateJoinCode enforce bounds', () {
      expect(
        () => HouseholdStatePolicy.validateSettingsInputs(dailyTreatLimit: 0),
        throwsArgumentError,
      );
      expect(
        () => HouseholdStatePolicy.validateSettingsInputs(petName: '  '),
        throwsArgumentError,
      );
      expect(
        HouseholdStatePolicy.validateSettingsInputs(dailyTreatLimit: 6, petName: '  Snoop  '),
        equals('Snoop'),
      );

      expect(
        () => HouseholdStatePolicy.validateTreatInputs(
          preset: TreatPreset.trainingTreat,
          givenByName: 'Keni',
          quantity: 21,
        ),
        throwsArgumentError,
      );
      expect(
        () => HouseholdStatePolicy.validateTreatInputs(
          preset: TreatPreset.custom,
          givenByName: 'Keni',
          customLabel: 'X' * 41,
          quantity: 1,
        ),
        throwsArgumentError,
      );

      final code = HouseholdStatePolicy.generateJoinCode('Snoop', random: Random(7));
      expect(code, matches(RegExp(r'^SNOO\d{2}$')));
    });

    test('pruneTodayMeals & pruneTodayTreats enforce caps and logical date retention', () {
      final now = DateTime(2026, 11, 8, 12, 0);
      final meals = <String, FeedingEvent>{};
      for (var i = 0; i < 30; i++) {
        final fedAt = now.subtract(Duration(hours: i));
        final id = 'meal_$i';
        meals[id] = FeedingEvent(
          id: id,
          mealPeriod: MealPeriod.breakfast,
          windowId: 'breakfast',
          windowLabel: 'Breakfast',
          windowEmoji: '🥣',
          windowDate: '2026-11-08',
          fedByUid: 'uid_keni',
          fedByName: 'Keni',
          fedAt: fedAt,
        );
      }
      meals['extra'] = FeedingEvent(
        id: 'extra',
        mealPeriod: MealPeriod.breakfast,
        windowId: 'breakfast',
        windowLabel: 'Breakfast',
        windowEmoji: '🥣',
        windowDate: '2026-11-08',
        fedByUid: 'uid_keni',
        fedByName: 'Keni',
        fedAt: now,
        isExtraMeal: true,
      );
      final prunedMeals = HouseholdStatePolicy.pruneTodayMeals(meals, now);
      expect(prunedMeals.length, equals(25));
      expect(prunedMeals.containsKey('extra'), isFalse);

      final treats = <TreatEvent>[
        TreatEvent(
          id: 'old_treat',
          preset: TreatPreset.dentalChew,
          label: 'Dental Chew',
          emoji: '🪥',
          quantity: 1,
          caloriesPerUnit: 85,
          logicalDate: '2026-11-05',
          givenByUid: 'uid_keni',
          givenByName: 'Keni',
          givenAt: now.subtract(const Duration(days: 3)),
        ),
        TreatEvent(
          id: 'prev_day_treat',
          preset: TreatPreset.dentalChew,
          label: 'Dental Chew',
          emoji: '🪥',
          quantity: 1,
          caloriesPerUnit: 85,
          logicalDate: '2026-11-07',
          givenByUid: 'uid_ashley',
          givenByName: 'Ashley',
          givenAt: now.subtract(const Duration(hours: 18)),
        ),
      ];
      final prunedTreats = HouseholdStatePolicy.pruneTodayTreats(treats, '2026-11-08');
      expect(prunedTreats.map((t) => t.id), equals(<String>['prev_day_treat']));
    });

    test('pruneTodayTreats drops malformed legacy entries and retains distinct empty-id items', () {
      final now = DateTime(2026, 11, 15, 18, 0);
      final treats = <TreatEvent>[
        TreatEvent(
          id: 'missing_uid',
          preset: TreatPreset.dentalChew,
          label: 'Dental Chew',
          emoji: '🪥',
          quantity: 1,
          caloriesPerUnit: 85,
          logicalDate: '2026-11-15',
          givenByUid: '   ',
          givenByName: 'Keni',
          givenAt: now,
        ),
        TreatEvent(
          id: 'bad_date',
          preset: TreatPreset.dentalChew,
          label: 'Dental Chew',
          emoji: '🪥',
          quantity: 1,
          caloriesPerUnit: 85,
          logicalDate: '2026/11/15',
          givenByUid: 'uid_keni',
          givenByName: 'Keni',
          givenAt: now,
        ),
        TreatEvent(
          id: '',
          preset: TreatPreset.dentalChew,
          label: 'Dental Chew',
          emoji: '🪥',
          quantity: 1,
          caloriesPerUnit: 85,
          logicalDate: '2026-11-15',
          givenByUid: 'uid_keni',
          givenByName: 'Keni',
          givenAt: now.subtract(const Duration(minutes: 5)),
        ),
        TreatEvent(
          id: '',
          preset: TreatPreset.trainingTreat,
          label: 'Training Treat',
          emoji: '🦴',
          quantity: 1,
          caloriesPerUnit: 15,
          logicalDate: '2026-11-15',
          givenByUid: 'uid_ashley',
          givenByName: 'Ashley',
          givenAt: now.subtract(const Duration(minutes: 10)),
        ),
      ];

      final pruned = HouseholdStatePolicy.pruneTodayTreats(treats, '2026-11-15');
      expect(pruned.length, equals(2));
      expect(pruned.first.preset, equals(TreatPreset.dentalChew));
      expect(pruned.last.preset, equals(TreatPreset.trainingTreat));
    });

    test(
        'FirestoreHouseholdMapper omits empty optional strings and enforces treat/feeding rule contract',
        () {
      final now = DateTime(2026, 11, 15, 18, 30);
      final household = Household(
        id: 'household_snoop_01',
        joinCode: 'SNOOP4',
        petName: 'Snoop',
        createdAt: now,
        members: <String, HouseholdMember>{
          'uid_keni': HouseholdMember(uid: 'uid_keni', name: 'Keni', joinedAt: now),
        },
      );

      for (final preset in TreatPreset.values) {
        final treat = HouseholdStatePolicy.buildTreatEvent(
          household: household,
          givenByUid: 'uid_keni',
          givenByName: 'Keni',
          now: now,
          preset: preset,
        );
        final map = FirestoreHouseholdMapper.treatToFirestoreMap(treat);
        expect(map['id'], isA<String>());
        expect((map['id']! as String).length, inInclusiveRange(1, 80));
        expect(map['preset'], equals(preset.id));
        expect(map['label'], equals(preset.label));
        expect((map['emoji']! as String).length, inInclusiveRange(1, 8));
        expect(map['quantity'], inInclusiveRange(1, 20));
        expect(map['caloriesPerUnit'], inInclusiveRange(0, 2000));
        expect(map['logicalDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
        expect(map['givenByUid'], equals('uid_keni'));
        expect(map['givenByName'], equals('Keni'));
        expect(map['givenAt'], isA<Timestamp>());
        expect(map.containsKey('note'), isFalse);
      }

      // Empty id and whitespace-only note must be omitted instead of serialized as ''
      final legacyTreat = TreatEvent.fromJson(<String, Object?>{
        'preset': 'dental_chew',
        'label': 'Dental Chew',
        'emoji': '🪥',
        'quantity': 1,
        'caloriesPerUnit': 85,
        'logicalDate': '2026-11-15',
        'givenByUid': 'uid_keni',
        'givenByName': 'Keni',
        'givenAt': now.toUtc().toIso8601String(),
        'note': '   ',
      });
      final legacyMap = FirestoreHouseholdMapper.treatToFirestoreMap(legacyTreat);
      expect(legacyMap.containsKey('id'), isFalse);
      expect(legacyMap.containsKey('note'), isFalse);

      // Feeding mapper omits empty optional id
      final legacyFeeding = FeedingEvent(
        id: '   ',
        mealPeriod: MealPeriod.dinner,
        windowDate: '2026-11-15',
        fedByUid: 'uid_keni',
        fedByName: 'Keni',
        fedAt: now,
      );
      final feedingMap = FirestoreHouseholdMapper.feedingToFirestoreMap(legacyFeeding);
      expect(feedingMap.containsKey('id'), isFalse);
      expect(feedingMap['fedAt'], isA<Timestamp>());
    });
  });

  group('UndoStackController', () {
    testWidgets('pushes LIFO entries, formats bannerText, ticks down, and pops cleanly',
        (WidgetTester tester) async {
      var notifyCount = 0;
      final controller = UndoStackController(onChanged: () => notifyCount += 1);
      addTearDown(controller.dispose);

      controller.push(
        const PendingUndoEntry(
          entryId: '2026-11-08_breakfast',
          kind: UndoKind.meal,
          label: 'Breakfast',
          emoji: '🥣',
        ),
      );
      expect(controller.canUndo, isTrue);
      expect(controller.bannerText, equals('🥣 Logged Breakfast! Undo within 10s'));

      await tester.pump(const Duration(seconds: 2));
      expect(controller.secondsRemaining, equals(8));

      controller.push(
        const PendingUndoEntry(
          entryId: 'treat_1',
          kind: UndoKind.treat,
          label: 'PB Kong',
          emoji: '🥜',
        ),
      );
      expect(controller.length, equals(2));
      expect(controller.bannerText, equals('🥜 Logged PB Kong! Undo within 10s (+1 more)'));

      final popped = controller.pop();
      expect(popped?.entryId, equals('treat_1'));
      expect(controller.activeEntry?.entryId, equals('2026-11-08_breakfast'));

      controller.removeById('2026-11-08_breakfast', kind: UndoKind.meal);
      expect(controller.isEmpty, isTrue);
      expect(controller.canUndo, isFalse);
      expect(notifyCount, greaterThan(0));
    });
  });

  group('PartnerActivityDetector', () {
    test('seeds baseline, ignores local echoes, and formats partner meal/treat banners', () {
      final baseTime = DateTime(2026, 11, 8, 9, 0);
      final localMeal = FeedingEvent(
        id: '2026-11-08_breakfast',
        mealPeriod: MealPeriod.breakfast,
        windowId: 'breakfast',
        windowLabel: 'Breakfast',
        windowEmoji: '🥣',
        windowDate: '2026-11-08',
        fedByUid: 'uid_keni',
        fedByName: 'Keni',
        fedAt: baseTime,
      );
      final partnerTreat = TreatEvent(
        id: 'treat_ashley_1',
        preset: TreatPreset.trainingTreat,
        label: 'Training Treat',
        emoji: '🦴',
        quantity: 2,
        caloriesPerUnit: 15,
        logicalDate: '2026-11-08',
        givenByUid: 'uid_ashley',
        givenByName: 'Ashley',
        givenAt: baseTime.add(const Duration(minutes: 5)),
      );

      final detector = PartnerActivityDetector();
      final initialHousehold = Household(
        id: 'h_1',
        petName: 'Snoop',
        joinCode: 'SNOOP4',
        members: const <String, HouseholdMember>{},
        createdAt: baseTime,
      );
      detector.seed(initialHousehold);
      expect(detector.hasSeeded, isTrue);

      detector.recordLocalMeal(localMeal);
      final echoBanner = detector.detectUpdates(
        initialHousehold.copyWith(
          lastFeeding: localMeal,
          todayMeals: <String, FeedingEvent>{localMeal.id: localMeal},
        ),
        currentMemberUid: 'uid_keni',
      );
      expect(echoBanner, isNull);

      final partnerBanner = detector.detectUpdates(
        initialHousehold.copyWith(
          lastFeeding: localMeal,
          todayMeals: <String, FeedingEvent>{localMeal.id: localMeal},
          todayTreats: <TreatEvent>[partnerTreat],
        ),
        currentMemberUid: 'uid_keni',
      );
      expect(partnerBanner, contains('Ashley gave Snoop 2x Training Treat'));
    });
  });

  group('DeepLinkCoordinator', () {
    test('routes /tap, /join, /s and ignores unknown URIs', () async {
      final now = DateTime(2026, 11, 8, 9, 0);
      final repo = InMemoryHouseholdRepository(initialClock: now);
      addTearDown(repo.dispose);

      var household =
          await repo.watchHousehold(InMemoryHouseholdRepository.defaultHouseholdId).first;
      final banners = <String>[];
      final errors = <Object>[];
      var joinedCode = '';
      var joinedMember = '';
      var tapLogs = 0;

      final coordinator = DeepLinkCoordinator(
        repository: repo,
        isDisposed: () => false,
        waitForHouseholdLoaded: () async {},
        waitForDeviceBound: () async {},
        getHousehold: () => household,
        getHouseholdId: () => household!.id,
        getCurrentMemberUid: () => InMemoryHouseholdRepository.keniUid,
        getCurrentMemberName: () => 'Keni',
        getActiveWindow: () => ActiveMealWindow.forTime(now),
        getErrorMessage: () => null,
        switchToLoadedHousehold: (h) => household = h,
        logMealForTap: () async {
          tapLogs += 1;
          return true;
        },
        joinHousehold: ({required joinCode, required memberName}) async {
          joinedCode = joinCode;
          joinedMember = memberName;
        },
        activateSitterPersona: banners.add,
        showBanner: banners.add,
        reportError: errors.add,
      );

      await coordinator.handleUri(Uri.parse('https://whofedsnoop.com/unknown/path'));
      expect(tapLogs, equals(0));

      await coordinator.handleUri(Uri.parse('https://whofedsnoop.com/join/SNOOP4'));
      expect(joinedCode, equals('SNOOP4'));
      expect(joinedMember, equals('Keni'));

      await coordinator.handleUri(Uri.parse('https://whofedsnoop.com/tap/household_snoop_01'));
      expect(tapLogs, equals(1));
      expect(banners.last, contains('Instant Tap-to-Feed'));

      await coordinator.handleUri(Uri.parse('https://whofedsnoop.com/s/SNOOP4'));
      expect(banners.last, contains('Dog Sitter Guest Pass active'));
      expect(errors, isEmpty);
    });
  });
}
