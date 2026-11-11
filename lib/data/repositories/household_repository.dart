import 'dart:async';
import 'dart:math';

import '../../domain/models/feeding_event.dart';
import '../../domain/models/household.dart';
import '../../domain/models/meal_window.dart';

/// Single source of truth for household state and feeding logs.
abstract class HouseholdRepository {
  /// Streams real-time changes to the active household document.
  Stream<Household?> watchHousehold(String householdId);

  /// Streams the 7-day rolling feeding history for [householdId], newest first.
  Stream<List<FeedingEvent>> watchRecentFeedings(
    String householdId, {
    int limit = 14,
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

  /// Logs a meal for the active window using a deterministic ID (`YYYY-MM-DD_period`)
  /// so simultaneous taps from Keni & Ashley are idempotent and never double-log.
  Future<FeedingEvent> logFeeding({
    required String householdId,
    required String fedByUid,
    required String fedByName,
    required DateTime now,
    bool isExtraMeal = false,
  });

  /// Reverts a recently logged feeding (10-second Undo window).
  Future<void> undoFeeding({
    required String householdId,
    required String feedingId,
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

  final StreamController<String> _changeController = StreamController<String>.broadcast();

  static const String defaultHouseholdId = 'household_snoop_01';
  static const String defaultJoinCode = 'SNOOP4';
  static const String keniUid = 'uid_keni';
  static const String ashleyUid = 'uid_ashley';

  void _seedDefaultHousehold(DateTime now) {
    // Seed yesterday's dinner and breakfast so the 7-day history looks realistic out of the box.
    final yesterdayMorning = DateTime(now.year, now.month, now.day - 1, 8, 12);
    final yesterdayEvening = DateTime(now.year, now.month, now.day - 1, 18, 25);

    final yesterdayBreakfastWindow = ActiveMealWindow.forTime(yesterdayMorning);
    final yesterdayDinnerWindow = ActiveMealWindow.forTime(yesterdayEvening);

    final breakfastEvent = FeedingEvent(
      id: yesterdayBreakfastWindow.deterministicId,
      mealPeriod: MealPeriod.breakfast,
      windowDate: yesterdayBreakfastWindow.windowDate,
      fedByUid: keniUid,
      fedByName: 'Keni',
      fedAt: yesterdayMorning,
    );

    final dinnerEvent = FeedingEvent(
      id: yesterdayDinnerWindow.deterministicId,
      mealPeriod: MealPeriod.dinner,
      windowDate: yesterdayDinnerWindow.windowDate,
      fedByUid: ashleyUid,
      fedByName: 'Ashley',
      fedAt: yesterdayEvening,
    );

    final household = Household(
      id: defaultHouseholdId,
      joinCode: defaultJoinCode,
      petName: 'Snoop',
      createdAt: yesterdayMorning,
      isPro: true,
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
    );

    _households[defaultHouseholdId] = household;
    _feedingsByHousehold[defaultHouseholdId] = <FeedingEvent>[
      dinnerEvent,
      breakfastEvent,
    ];
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
    int limit = 14,
  }) async* {
    yield _getSortedFeedings(householdId, limit: limit);
    await for (final changedId in _changeController.stream) {
      if (changedId == householdId) {
        yield _getSortedFeedings(householdId, limit: limit);
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

  @override
  Future<Household> createHousehold({
    required String memberUid,
    required String memberName,
    required String petName,
  }) async {
    final now = DateTime.now();
    final cleanPet = petName.trim().isEmpty ? 'Snoop' : petName.trim();
    final cleanMember = memberName.trim().isEmpty ? 'Keni' : memberName.trim();
    final id = 'household_${now.millisecondsSinceEpoch}';
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
    final cleanName = memberName.trim().isEmpty ? 'Ashley' : memberName.trim();
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
    }

    final eventId = isExtraMeal
        ? '${window.deterministicId}_extra_${now.millisecondsSinceEpoch}'
        : window.deterministicId;

    final newEvent = FeedingEvent(
      id: eventId,
      mealPeriod: window.period,
      windowDate: window.windowDate,
      fedByUid: fedByUid,
      fedByName: fedByName,
      fedAt: now,
      isExtraMeal: isExtraMeal,
    );

    list.insert(0, newEvent);
    _households[householdId] = household.copyWith(lastFeeding: newEvent);
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

    final list = _feedingsByHousehold[householdId];
    if (list == null) return;

    final targetIndex = list.indexWhere((e) => e.id == feedingId);
    if (targetIndex == -1) return;

    final target = list[targetIndex];
    if (target.fedByUid != requestingUid) {
      throw StateError('Only ${target.fedByName} can undo this meal log.');
    }

    list.removeAt(targetIndex);
    list.sort((a, b) => b.fedAt.compareTo(a.fedAt));

    final previousLatest = list.isNotEmpty ? list.first : null;
    _households[householdId] = household.copyWith(
      lastFeeding: previousLatest,
      clearLastFeeding: previousLatest == null,
    );
    _changeController.add(householdId);
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
