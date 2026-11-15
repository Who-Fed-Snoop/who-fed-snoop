import 'dart:async';

import '../../domain/models/active_meal_window.dart';
import '../../domain/models/feeding_event.dart';
import '../../domain/models/household.dart';
import '../../domain/models/meal_period.dart';
import '../../domain/models/meal_schedule.dart';
import '../../domain/models/treat_event.dart';
import 'household_repository.dart';
import 'household_state_policy.dart';

/// Real-time in-memory implementation of [HouseholdRepository] that mirrors
/// Cloud Firestore semantics (deterministic IDs, instant stream updates, and
/// pre-seeded Keni & Ashley partner simulation).
class InMemoryHouseholdRepository implements HouseholdRepository {
  InMemoryHouseholdRepository({DateTime? initialClock}) {
    _seedDefaultHousehold(initialClock ?? DateTime.now());
  }

  final Map<String, Household> _households = <String, Household>{};
  final Map<String, List<FeedingEvent>> _feedingsByHousehold = <String, List<FeedingEvent>>{};
  final Map<String, List<TreatEvent>> _treatsByHousehold = <String, List<TreatEvent>>{};

  final StreamController<String> _changeController = StreamController<String>.broadcast();

  static const String defaultHouseholdId = HouseholdStatePolicy.defaultHouseholdId;
  static const String defaultJoinCode = HouseholdStatePolicy.defaultJoinCode;
  static const String keniUid = HouseholdStatePolicy.keniUid;
  static const String ashleyUid = HouseholdStatePolicy.ashleyUid;

  static String nextUniqueSuffix() => HouseholdStatePolicy.nextUniqueSuffix();

  void _seedDefaultHousehold(DateTime now) {
    // Seed yesterday's dinner and breakfast so the 7-day history looks realistic out of the box.
    final yesterdayMorning = DateTime(now.year, now.month, now.day - 1, 8, 12);
    final yesterdayEvening = DateTime(now.year, now.month, now.day - 1, 18, 25);
    final breakfastWindow = ActiveMealWindow.forTime(yesterdayMorning);
    final dinnerWindow = ActiveMealWindow.forTime(yesterdayEvening);

    final breakfastEvent = FeedingEvent(
      id: breakfastWindow.deterministicId,
      mealPeriod: MealPeriod.breakfast,
      windowId: breakfastWindow.windowId,
      windowLabel: breakfastWindow.label,
      windowEmoji: breakfastWindow.emoji,
      windowDate: breakfastWindow.windowDate,
      fedByUid: keniUid,
      fedByName: 'Keni',
      fedAt: yesterdayMorning,
    );

    final dinnerEvent = FeedingEvent(
      id: dinnerWindow.deterministicId,
      mealPeriod: MealPeriod.dinner,
      windowId: dinnerWindow.windowId,
      windowLabel: dinnerWindow.label,
      windowEmoji: dinnerWindow.emoji,
      windowDate: dinnerWindow.windowDate,
      fedByUid: ashleyUid,
      fedByName: 'Ashley',
      fedAt: yesterdayEvening,
    );

    final seededTodayMeals = pruneTodayMeals(<String, FeedingEvent>{
      breakfastEvent.id: breakfastEvent,
      dinnerEvent.id: dinnerEvent,
    }, now);

    _households[defaultHouseholdId] = Household(
      id: defaultHouseholdId,
      joinCode: defaultJoinCode,
      petName: HouseholdStatePolicy.defaultPetName,
      createdAt: yesterdayMorning,
      isPro: false,
      members: <String, HouseholdMember>{
        keniUid: HouseholdMember(uid: keniUid, name: 'Keni', joinedAt: yesterdayMorning),
        ashleyUid: HouseholdMember(
          uid: ashleyUid,
          name: 'Ashley',
          joinedAt: yesterdayMorning.add(const Duration(minutes: 2)),
        ),
      },
      lastFeeding: dinnerEvent,
      dailyTreatLimit: HouseholdStatePolicy.defaultDailyTreatLimit,
      todayMeals: seededTodayMeals,
      todayTreats: const <TreatEvent>[],
    );
    _feedingsByHousehold[defaultHouseholdId] = <FeedingEvent>[dinnerEvent, breakfastEvent];
    _treatsByHousehold[defaultHouseholdId] = <TreatEvent>[];
  }

  @override
  Stream<Household?> watchHousehold(String householdId) =>
      _watchKeyed(householdId, () => _households[householdId]);

  @override
  Stream<List<FeedingEvent>> watchRecentFeedings(String householdId, {int limit = 50}) =>
      _watchKeyed(householdId, () => _getSortedFeedings(householdId, limit: limit));

  @override
  Stream<List<TreatEvent>> watchRecentTreats(String householdId, {int limit = 50}) =>
      _watchKeyed(householdId, () => _getSortedTreats(householdId, limit: limit));

  Stream<T> _watchKeyed<T>(String householdId, T Function() read) async* {
    yield read();
    await for (final changedId in _changeController.stream) {
      if (changedId == householdId) yield read();
    }
  }

  List<FeedingEvent> _getSortedFeedings(String householdId, {required int limit}) {
    final list = List<FeedingEvent>.of(_feedingsByHousehold[householdId] ?? const <FeedingEvent>[]);
    list.sort((a, b) => b.fedAt.compareTo(a.fedAt));
    return list.take(limit).toList(growable: false);
  }

  List<TreatEvent> _getSortedTreats(String householdId, {required int limit}) {
    final list = List<TreatEvent>.of(_treatsByHousehold[householdId] ?? const <TreatEvent>[]);
    list.sort((a, b) => b.givenAt.compareTo(a.givenAt));
    return list.take(limit).toList(growable: false);
  }

  Household _requireHousehold(String householdId) {
    final household = _households[householdId];
    if (household == null) throw StateError('Household $householdId not found.');
    return household;
  }

  @override
  Future<Household> createHousehold({
    required String memberUid,
    required String memberName,
    required String petName,
  }) async {
    final now = DateTime.now();
    final cleanPet = HouseholdStatePolicy.sanitizeName(
      petName,
      fallback: HouseholdStatePolicy.defaultPetName,
      maxLength: 40,
    );
    final cleanMember =
        HouseholdStatePolicy.sanitizeName(memberName, fallback: 'Keni', maxLength: 50);
    final id = 'household_${now.millisecondsSinceEpoch}_${nextUniqueSuffix()}';

    final household = Household(
      id: id,
      joinCode: HouseholdStatePolicy.generateJoinCode(cleanPet),
      petName: cleanPet,
      createdAt: now,
      members: <String, HouseholdMember>{
        memberUid: HouseholdMember(uid: memberUid, name: cleanMember, joinedAt: now),
      },
    );

    _households[id] = household;
    _feedingsByHousehold[id] = <FeedingEvent>[];
    _treatsByHousehold[id] = <TreatEvent>[];
    _changeController.add(id);
    return household;
  }

  @override
  Future<Household> joinHouseholdByCode({
    required String joinCode,
    required String memberUid,
    required String memberName,
  }) async {
    final normalizedCode = joinCode.trim().toUpperCase();
    final match = _households.values.where((h) => h.joinCode.toUpperCase() == normalizedCode);
    if (match.isEmpty) {
      throw StateError('No household found with code "$normalizedCode". Try $defaultJoinCode!');
    }

    final existing = match.first;
    final cleanName =
        HouseholdStatePolicy.sanitizeName(memberName, fallback: 'Ashley', maxLength: 50);
    final updatedMembers = Map<String, HouseholdMember>.of(existing.members)
      ..[memberUid] = HouseholdMember(uid: memberUid, name: cleanName, joinedAt: DateTime.now());

    final updated = existing.copyWith(members: updatedMembers);
    _households[existing.id] = updated;
    _changeController.add(existing.id);
    return updated;
  }

  @override
  Future<Household> updateMemberName({
    required String householdId,
    required String memberUid,
    required String memberName,
  }) async {
    final household = _requireHousehold(householdId);
    final result = HouseholdStatePolicy.applyMemberNameUpdate(
      household,
      memberUid: memberUid,
      memberName: memberName,
      now: DateTime.now(),
    );
    if (!result.changed) return household;

    _households[householdId] = result.household;
    _changeController.add(householdId);
    return result.household;
  }

  @override
  Future<Household> updateHouseholdSettings({
    required String householdId,
    required String requestingUid,
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  }) async {
    final household = _requireHousehold(householdId);
    if (!household.members.containsKey(requestingUid)) {
      throw StateError('Only household members can update settings.');
    }

    final updatedPetName = HouseholdStatePolicy.validateSettingsInputs(
      schedule: schedule,
      dailyTreatLimit: dailyTreatLimit,
      petName: petName,
    );

    final updated = household.copyWith(
      schedule: schedule,
      dailyTreatLimit: dailyTreatLimit,
      petName: updatedPetName,
    );
    _households[householdId] = updated;
    _changeController.add(householdId);
    return updated;
  }

  @override
  Future<FeedingEvent> logFeeding({
    required String householdId,
    required String fedByUid,
    required String fedByName,
    required DateTime now,
    bool isExtraMeal = false,
  }) async {
    final household = _requireHousehold(householdId);
    final window = ActiveMealWindow.forTime(now, schedule: household.schedule);
    final list = _feedingsByHousehold.putIfAbsent(householdId, () => <FeedingEvent>[]);

    // Deterministic ID prevents race-condition double-feeds for the same window.
    if (!isExtraMeal) {
      final existingIndex = list.indexWhere((event) => event.id == window.deterministicId);
      if (existingIndex != -1) return list[existingIndex];
      final fromMap = household.feedingForWindow(window);
      if (fromMap != null) return fromMap;
    }

    final newEvent = HouseholdStatePolicy.buildFeedingEvent(
      window: window,
      fedByUid: fedByUid,
      fedByName: fedByName,
      now: now,
      isExtraMeal: isExtraMeal,
    );
    list.insert(0, newEvent);

    final updatedTodayMeals = Map<String, FeedingEvent>.of(household.todayMeals);
    if (!isExtraMeal) updatedTodayMeals[newEvent.id] = newEvent;

    _households[householdId] = household.copyWith(
      lastFeeding: newEvent,
      todayMeals: pruneTodayMeals(updatedTodayMeals, now),
    );
    _changeController.add(householdId);
    return newEvent;
  }

  @override
  Future<void> undoFeeding({
    required String householdId,
    required String feedingId,
    required String requestingUid,
  }) async {
    final household = _households[householdId];
    if (household == null) return;
    if (!household.members.containsKey(requestingUid)) {
      throw StateError('Only household members can undo a meal log.');
    }

    final list = _feedingsByHousehold[householdId];
    if (list != null) {
      list.removeWhere((e) => e.id == feedingId);
      list.sort((a, b) => b.fedAt.compareTo(a.fedAt));
    }

    final updatedTodayMeals = Map<String, FeedingEvent>.of(household.todayMeals)..remove(feedingId);
    final previousLatest = HouseholdStatePolicy.computePreviousLatestFeeding(
      updatedTodayMeals: updatedTodayMeals,
      historyMeals: list ?? const <FeedingEvent>[],
    );

    _households[householdId] = household.copyWith(
      lastFeeding: previousLatest,
      clearLastFeeding: previousLatest == null,
      todayMeals: Map<String, FeedingEvent>.unmodifiable(updatedTodayMeals),
    );
    _changeController.add(householdId);
  }

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
  }) async {
    final household = _requireHousehold(householdId);
    final newTreat = HouseholdStatePolicy.buildTreatEvent(
      household: household,
      givenByUid: givenByUid,
      givenByName: givenByName,
      now: now,
      preset: preset,
      customLabel: customLabel,
      quantity: quantity,
      caloriesPerUnit: caloriesPerUnit,
      note: note,
    );

    _treatsByHousehold.putIfAbsent(householdId, () => <TreatEvent>[]).insert(0, newTreat);
    final updatedTodayTreats = pruneTodayTreats(
      <TreatEvent>[newTreat, ...household.todayTreats],
      newTreat.logicalDate,
    );

    // Strictly orthogonal: never modifies lastFeeding or todayMeals.
    _households[householdId] = household.copyWith(todayTreats: updatedTodayTreats);
    _changeController.add(householdId);
    return newTreat;
  }

  @override
  Future<void> deleteTreat({
    required String householdId,
    required String treatId,
    required String requestingUid,
  }) async {
    final household = _households[householdId];
    if (household == null) return;
    if (!household.members.containsKey(requestingUid)) {
      throw StateError('Only household members can delete treats.');
    }

    _treatsByHousehold[householdId]?.removeWhere((t) => t.id == treatId);
    _households[householdId] = household.copyWith(
      todayTreats: List<TreatEvent>.unmodifiable(
        household.todayTreats.where((t) => t.id != treatId),
      ),
    );
    _changeController.add(householdId);
  }

  /// Retains regular meals from the last 48 hours, capped at 25 entries (`<= 30` rule limit).
  static Map<String, FeedingEvent> pruneTodayMeals(
    Map<String, FeedingEvent> meals,
    DateTime referenceNow,
  ) =>
      HouseholdStatePolicy.pruneTodayMeals(meals, referenceNow);

  /// Retains treats for [activeLogicalDate] (and the preceding logical date for midnight safety),
  /// sorted newest-first and capped at 50 entries (`<= 50` Firestore rules limit).
  static List<TreatEvent> pruneTodayTreats(List<TreatEvent> treats, String activeLogicalDate) =>
      HouseholdStatePolicy.pruneTodayTreats(treats, activeLogicalDate);

  static ({
    String label,
    String givenByName,
    int quantity,
    int caloriesPerUnit,
    String? note,
  }) validateTreatInputs({
    required TreatPreset preset,
    required String givenByName,
    String? customLabel,
    required int quantity,
    int? caloriesPerUnit,
    String? note,
  }) =>
      HouseholdStatePolicy.validateTreatInputs(
        preset: preset,
        givenByName: givenByName,
        customLabel: customLabel,
        quantity: quantity,
        caloriesPerUnit: caloriesPerUnit,
        note: note,
      );

  void dispose() => _changeController.close();
}
