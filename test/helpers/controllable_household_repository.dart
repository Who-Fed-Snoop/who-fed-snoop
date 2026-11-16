import 'dart:async';

import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/domain/models/feeding_event.dart';
import 'package:who_fed_snoop/domain/models/household.dart';
import 'package:who_fed_snoop/domain/models/meal_window.dart';
import 'package:who_fed_snoop/domain/models/treat_event.dart';

/// Test repository wrapper supporting controllable stream delays, slow writes,
/// invocation counters, and simulated non-InMemory backend behavior.
class ControllableHouseholdRepository implements HouseholdRepository {
  ControllableHouseholdRepository(this._delegate);

  final InMemoryHouseholdRepository _delegate;

  Completer<void>? watchHouseholdGate;
  Completer<void>? logFeedingGate;
  Completer<void>? joinGate;
  Completer<void>? createGate;
  bool failLogFeeding = false;
  bool failHistoryStreams = false;
  int logFeedingCalls = 0;
  int updateMemberNameCalls = 0;
  int joinCallCount = 0;
  int createCallCount = 0;

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
  }) async {
    createCallCount += 1;
    final gate = createGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    return _delegate.createHousehold(
      memberUid: memberUid,
      memberName: memberName,
      petName: petName,
    );
  }

  @override
  Future<Household> joinHouseholdByCode({
    required String joinCode,
    required String memberUid,
    required String memberName,
  }) async {
    joinCallCount += 1;
    final gate = joinGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    return _delegate.joinHouseholdByCode(
      joinCode: joinCode,
      memberUid: memberUid,
      memberName: memberName,
    );
  }

  @override
  Future<Household> updateMemberName({
    required String householdId,
    required String memberUid,
    required String memberName,
  }) {
    updateMemberNameCalls += 1;
    return _delegate.updateMemberName(
      householdId: householdId,
      memberUid: memberUid,
      memberName: memberName,
    );
  }

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

/// Flushes two event-loop turns so async stream/Completer updates settle in unit tests.
Future<void> flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
