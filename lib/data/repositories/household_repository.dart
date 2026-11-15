import 'dart:async';
import 'dart:math';

import '../../domain/models/feeding_event.dart';
import '../../domain/models/household.dart';
import '../../domain/models/meal_window.dart';
import '../../domain/models/treat_event.dart';

/// Single source of truth for household state, meal schedules, feeding logs, and treats.
abstract class HouseholdRepository {
  /// Streams real-time changes to the active household document.
  Stream<Household?> watchHousehold(String householdId);

  /// Streams the rolling feeding history for [householdId], newest first.
  Stream<List<FeedingEvent>> watchRecentFeedings(
    String householdId, {
    int limit = 50,
  });

  /// Streams the rolling treat history for [householdId], newest first.
  Stream<List<TreatEvent>> watchRecentTreats(
    String householdId, {
    int limit = 50,
  });

  /// Creates a new household and registers the creator as the first member.
  Future<Household> createHousehold({
    required String memberUid,
    required String memberName,
    required String petName,
  });

  /// Joins an existing household using its 6-character [joinCode].
  Future<Household> joinHouseholdByCode({
    required String joinCode,
    required String memberUid,
    required String memberName,
  });

  /// Updates household configuration (`schedule`, `dailyTreatLimit`, `petName`).
  Future<Household> updateHouseholdSettings({
    required String householdId,
    required String requestingUid,
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  });

  /// Logs a meal for the active window using a deterministic ID (`YYYY-MM-DD_windowId`)
  /// so simultaneous taps from Keni & Ashley are idempotent and never double-log.
  Future<FeedingEvent> logFeeding({
    required String householdId,
    required String fedByUid,
    required String fedByName,
    required DateTime now,
    bool isExtraMeal = false,
  });

  /// Reverts a logged meal and restores `lastFeeding` / `todayMeals` cleanly.
  Future<void> undoFeeding({
    required String householdId,
    required String feedingId,
    required String requestingUid,
  });

  /// Logs a treat event without modifying `lastFeeding` or `todayMeals`.
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
  });

  /// Deletes a logged treat event without modifying `lastFeeding` or `todayMeals`.
  Future<void> deleteTreat({
    required String householdId,
    required String treatId,
    required String requestingUid,
  });
}

/// Real-time in-memory implementation of [HouseholdRepository] that mirrors
/// Cloud Firestore semantics (deterministic IDs, instant stream updates, and
/// pre-seeded Keni & Ashley partner simulation).
class InMemoryHouseholdRepository implements HouseholdRepository {
  InMemoryHouseholdRepository({DateTime? initialClock}) {
    final seedNow = initialClock ?? DateTime.now();
    _seedDefaultHousehold(seedNow);
  }

  final Map<String, Household> _households = <String, Household>{};
  final Map<String, List<FeedingEvent>> _feedingsByHousehold = <String, List<FeedingEvent>>{};
  final Map<String, List<TreatEvent>> _treatsByHousehold = <String, List<TreatEvent>>{};

  final StreamController<String> _changeController = StreamController<String>.broadcast();

  static const String defaultHouseholdId = 'household_snoop_01';
  static const String defaultJoinCode = 'SNOOP4';
  static const String keniUid = 'uid_keni';
  static const String ashleyUid = 'uid_ashley';

  static int _idSequence = 0;

  static String nextUniqueSuffix() => (++_idSequence).toRadixString(36);

  void _seedDefaultHousehold(DateTime now) {
    // Seed yesterday's dinner and breakfast so the 7-day history looks realistic out of the box.
    final yesterdayMorning = DateTime(now.year, now.month, now.day - 1, 8, 12);
    final yesterdayEvening = DateTime(now.year, now.month, now.day - 1, 18, 25);

    final yesterdayBreakfastWindow = ActiveMealWindow.forTime(yesterdayMorning);
    final yesterdayDinnerWindow = ActiveMealWindow.forTime(yesterdayEvening);

    final breakfastEvent = FeedingEvent(
      id: yesterdayBreakfastWindow.deterministicId,
      mealPeriod: MealPeriod.breakfast,
      windowId: yesterdayBreakfastWindow.windowId,
      windowLabel: yesterdayBreakfastWindow.label,
      windowEmoji: yesterdayBreakfastWindow.emoji,
      windowDate: yesterdayBreakfastWindow.windowDate,
      fedByUid: keniUid,
      fedByName: 'Keni',
      fedAt: yesterdayMorning,
    );

    final dinnerEvent = FeedingEvent(
      id: yesterdayDinnerWindow.deterministicId,
      mealPeriod: MealPeriod.dinner,
      windowId: yesterdayDinnerWindow.windowId,
      windowLabel: yesterdayDinnerWindow.label,
      windowEmoji: yesterdayDinnerWindow.emoji,
      windowDate: yesterdayDinnerWindow.windowDate,
      fedByUid: ashleyUid,
      fedByName: 'Ashley',
      fedAt: yesterdayEvening,
    );

    final seededTodayMeals = pruneTodayMeals(
      <String, FeedingEvent>{
        breakfastEvent.id: breakfastEvent,
        dinnerEvent.id: dinnerEvent,
      },
      now,
    );

    final household = Household(
      id: defaultHouseholdId,
      joinCode: defaultJoinCode,
      petName: 'Snoop',
      createdAt: yesterdayMorning,
      isPro: false,
      members: <String, HouseholdMember>{
        keniUid: HouseholdMember(
          uid: keniUid,
          name: 'Keni',
          joinedAt: yesterdayMorning,
        ),
        ashleyUid: HouseholdMember(
          uid: ashleyUid,
          name: 'Ashley',
          joinedAt: yesterdayMorning.add(const Duration(minutes: 2)),
        ),
      },
      lastFeeding: dinnerEvent,
      dailyTreatLimit: 4,
      todayMeals: seededTodayMeals,
      todayTreats: const <TreatEvent>[],
    );

    _households[defaultHouseholdId] = household;
    _feedingsByHousehold[defaultHouseholdId] = <FeedingEvent>[
      dinnerEvent,
      breakfastEvent,
    ];
    _treatsByHousehold[defaultHouseholdId] = <TreatEvent>[];
  }

  @override
  Stream<Household?> watchHousehold(String householdId) async* {
    yield _households[householdId];
    await for (final changedId in _changeController.stream) {
      if (changedId == householdId) {
        yield _households[householdId];
      }
    }
  }

  @override
  Stream<List<FeedingEvent>> watchRecentFeedings(
    String householdId, {
    int limit = 50,
  }) async* {
    yield _getSortedFeedings(householdId, limit: limit);
    await for (final changedId in _changeController.stream) {
      if (changedId == householdId) {
        yield _getSortedFeedings(householdId, limit: limit);
      }
    }
  }

  @override
  Stream<List<TreatEvent>> watchRecentTreats(
    String householdId, {
    int limit = 50,
  }) async* {
    yield _getSortedTreats(householdId, limit: limit);
    await for (final changedId in _changeController.stream) {
      if (changedId == householdId) {
        yield _getSortedTreats(householdId, limit: limit);
      }
    }
  }

  List<FeedingEvent> _getSortedFeedings(String householdId, {required int limit}) {
    final list = List<FeedingEvent>.of(
      _feedingsByHousehold[householdId] ?? const <FeedingEvent>[],
    );
    list.sort((a, b) => b.fedAt.compareTo(a.fedAt));
    return list.take(limit).toList(growable: false);
  }

  List<TreatEvent> _getSortedTreats(String householdId, {required int limit}) {
    final list = List<TreatEvent>.of(
      _treatsByHousehold[householdId] ?? const <TreatEvent>[],
    );
    list.sort((a, b) => b.givenAt.compareTo(a.givenAt));
    return list.take(limit).toList(growable: false);
  }

  @override
  Future<Household> createHousehold({
    required String memberUid,
    required String memberName,
    required String petName,
  }) async {
    final now = DateTime.now();
    final cleanPet = _sanitizeName(petName, fallback: 'Snoop', maxLength: 40);
    final cleanMember = _sanitizeName(memberName, fallback: 'Keni', maxLength: 50);
    final id = 'household_${now.millisecondsSinceEpoch}_${nextUniqueSuffix()}';
    final joinCode = _generateJoinCode(cleanPet);

    final household = Household(
      id: id,
      joinCode: joinCode,
      petName: cleanPet,
      createdAt: now,
      members: <String, HouseholdMember>{
        memberUid: HouseholdMember(
          uid: memberUid,
          name: cleanMember,
          joinedAt: now,
        ),
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
    final match = _households.values.where(
      (h) => h.joinCode.toUpperCase() == normalizedCode,
    );

    if (match.isEmpty) {
      throw StateError(
        'No household found with code "$normalizedCode". Try $defaultJoinCode!',
      );
    }

    final existing = match.first;
    final cleanName = _sanitizeName(memberName, fallback: 'Ashley', maxLength: 50);
    final updatedMembers = Map<String, HouseholdMember>.of(existing.members)
      ..[memberUid] = HouseholdMember(
        uid: memberUid,
        name: cleanName,
        joinedAt: DateTime.now(),
      );

    final updated = existing.copyWith(members: updatedMembers);
    _households[existing.id] = updated;
    _changeController.add(existing.id);
    return updated;
  }

  @override
  Future<Household> updateHouseholdSettings({
    required String householdId,
    required String requestingUid,
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  }) async {
    final household = _households[householdId];
    if (household == null) {
      throw StateError('Household $householdId not found.');
    }
    if (!household.members.containsKey(requestingUid)) {
      throw StateError('Only household members can update settings.');
    }

    if (schedule != null) {
      final validationError = schedule.validate();
      if (validationError != null) {
        throw ArgumentError(validationError);
      }
    }

    if (dailyTreatLimit != null && (dailyTreatLimit < 1 || dailyTreatLimit > 50)) {
      throw ArgumentError('Daily treat limit must be between 1 and 50.');
    }

    String? updatedPetName;
    if (petName != null) {
      final trimmed = petName.trim();
      if (trimmed.isEmpty || trimmed.length > 40) {
        throw ArgumentError('Pet name must be between 1 and 40 characters.');
      }
      updatedPetName = trimmed;
    }

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
    final household = _households[householdId];
    if (household == null) {
      throw StateError('Household $householdId not found.');
    }

    final window = ActiveMealWindow.forTime(now, schedule: household.schedule);
    final list = _feedingsByHousehold.putIfAbsent(
      householdId,
      () => <FeedingEvent>[],
    );

    // Deterministic ID prevents race-condition double-feeds for the same window.
    if (!isExtraMeal) {
      final existingIndex = list.indexWhere(
        (event) => event.id == window.deterministicId,
      );
      if (existingIndex != -1) {
        return list[existingIndex];
      }
      final fromMap = household.feedingForWindow(window);
      if (fromMap != null) {
        return fromMap;
      }
    }

    final cleanFedByName = _sanitizeName(
      fedByName,
      fallback: 'Someone',
      maxLength: 50,
    );

    final eventId = isExtraMeal
        ? '${window.deterministicId}_extra_${now.millisecondsSinceEpoch}_${nextUniqueSuffix()}'
        : window.deterministicId;

    final newEvent = FeedingEvent(
      id: eventId,
      mealPeriod: window.period,
      windowId: window.windowId,
      windowLabel: window.label,
      windowEmoji: window.emoji,
      windowDate: window.windowDate,
      fedByUid: fedByUid,
      fedByName: cleanFedByName,
      fedAt: now,
      isExtraMeal: isExtraMeal,
    );

    list.insert(0, newEvent);

    final updatedTodayMeals = Map<String, FeedingEvent>.of(household.todayMeals);
    if (!isExtraMeal) {
      updatedTodayMeals[newEvent.id] = newEvent;
    }

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

    final candidates = <String, FeedingEvent>{
      for (final m in updatedTodayMeals.values) m.id: m,
      if (list != null)
        for (final m in list) m.id: m,
    }.values.toList()
      ..sort((a, b) => b.fedAt.compareTo(a.fedAt));

    final previousLatest = candidates.isNotEmpty ? candidates.first : null;
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
    final household = _households[householdId];
    if (household == null) {
      throw StateError('Household $householdId not found.');
    }

    final validated = validateTreatInputs(
      preset: preset,
      givenByName: givenByName,
      customLabel: customLabel,
      quantity: quantity,
      caloriesPerUnit: caloriesPerUnit,
      note: note,
    );

    final logicalDate = household.schedule.logicalDateFor(now);
    final treatId = 'treat_${logicalDate}_${now.millisecondsSinceEpoch}_${nextUniqueSuffix()}';

    final newTreat = TreatEvent(
      id: treatId,
      preset: preset,
      label: validated.label,
      emoji: preset.emoji,
      quantity: validated.quantity,
      caloriesPerUnit: validated.caloriesPerUnit,
      logicalDate: logicalDate,
      givenByUid: givenByUid,
      givenByName: validated.givenByName,
      givenAt: now,
      note: validated.note,
    );

    final list = _treatsByHousehold.putIfAbsent(
      householdId,
      () => <TreatEvent>[],
    );
    list.insert(0, newTreat);

    final updatedTodayTreats = pruneTodayTreats(
      <TreatEvent>[newTreat, ...household.todayTreats],
      logicalDate,
    );

    // Strictly orthogonal: never modifies lastFeeding or todayMeals.
    _households[householdId] = household.copyWith(
      todayTreats: updatedTodayTreats,
    );
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

    final list = _treatsByHousehold[householdId];
    list?.removeWhere((t) => t.id == treatId);

    final updatedTodayTreats = List<TreatEvent>.unmodifiable(
      household.todayTreats.where((t) => t.id != treatId),
    );

    _households[householdId] = household.copyWith(
      todayTreats: updatedTodayTreats,
    );
    _changeController.add(householdId);
  }

  /// Retains regular meals from the last 48 hours, capped at 25 entries (`<= 30` rule limit).
  static Map<String, FeedingEvent> pruneTodayMeals(
    Map<String, FeedingEvent> meals,
    DateTime referenceNow,
  ) {
    final recent = meals.values
        .where(
          (e) => !e.isExtraMeal && referenceNow.difference(e.fedAt) <= const Duration(hours: 48),
        )
        .toList()
      ..sort((a, b) => b.fedAt.compareTo(a.fedAt));

    final bounded = <String, FeedingEvent>{};
    for (final meal in recent.take(25)) {
      bounded[meal.id] = meal;
    }
    return Map<String, FeedingEvent>.unmodifiable(bounded);
  }

  /// Retains treats for [activeLogicalDate] (and the preceding logical date for midnight safety),
  /// sorted newest-first and capped at 50 entries (`<= 50` Firestore rules limit).
  static List<TreatEvent> pruneTodayTreats(
    List<TreatEvent> treats,
    String activeLogicalDate,
  ) {
    final prevDate = _previousLogicalDateString(activeLogicalDate);
    final seenIds = <String>{};
    final filtered = <TreatEvent>[];
    for (final treat in treats) {
      if ((treat.logicalDate == activeLogicalDate || treat.logicalDate == prevDate) &&
          seenIds.add(treat.id)) {
        filtered.add(treat);
      }
    }
    filtered.sort((a, b) => b.givenAt.compareTo(a.givenAt));
    return List<TreatEvent>.unmodifiable(filtered.take(50));
  }

  static String _previousLogicalDateString(String logicalDate) {
    final parts = logicalDate.split('-');
    if (parts.length != 3) return logicalDate;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return logicalDate;
    return ActiveMealWindow.formatDate(DateTime(y, m, d - 1));
  }

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
  }) {
    if (quantity < 1 || quantity > 20) {
      throw ArgumentError('Treat quantity must be between 1 and 20.');
    }

    final resolvedCalories = caloriesPerUnit ?? preset.defaultCalories;
    if (resolvedCalories < 0 || resolvedCalories > 2000) {
      throw ArgumentError('Treat calories per unit must be between 0 and 2000.');
    }

    final trimmedCustom = customLabel?.trim();
    final resolvedLabel =
        (trimmedCustom != null && trimmedCustom.isNotEmpty) ? trimmedCustom : preset.label;
    if (resolvedLabel.length > 40) {
      throw ArgumentError('Treat label must be at most 40 characters.');
    }

    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.length > 140) {
      throw ArgumentError('Treat note must be at most 140 characters.');
    }

    final cleanGivenByName = _sanitizeName(
      givenByName,
      fallback: 'Someone',
      maxLength: 40,
    );

    return (
      label: resolvedLabel,
      givenByName: cleanGivenByName,
      quantity: quantity,
      caloriesPerUnit: resolvedCalories,
      note: (trimmedNote != null && trimmedNote.isNotEmpty) ? trimmedNote : null,
    );
  }

  static String _sanitizeName(
    String raw, {
    required String fallback,
    required int maxLength,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;
    if (trimmed.length <= maxLength) return trimmed;
    return trimmed.substring(0, maxLength);
  }

  String _generateJoinCode(String petName) {
    final letters =
        petName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '').padRight(4, 'X').substring(0, 4);
    final digits = (Random().nextInt(90) + 10).toString();
    return '$letters$digits';
  }

  void dispose() {
    _changeController.close();
  }
}
