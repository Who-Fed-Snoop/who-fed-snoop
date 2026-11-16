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
  Completer<void>? logTreatGate;
  Completer<void>? deleteTreatGate;
  Completer<void>? updateSettingsGate;
  Completer<void>? updateMemberNameGate;
  Completer<void>? undoFeedingGate;
  Completer<void>? recentHistoryGate;
  Completer<void>? joinGate;
  Completer<void>? createGate;
  bool failLogFeeding = false;
  bool failHistoryStreams = false;
  Object? watchHouseholdError;
  Object? logTreatError;
  Object? deleteTreatError;
  Object? updateSettingsError;
  Object? updateMemberNameError;
  Object? undoFeedingError;
  int logFeedingCalls = 0;
  int logTreatCalls = 0;
  int updateMemberNameCalls = 0;
  int joinCallCount = 0;
  int createCallCount = 0;

  @override
  Stream<Household?> watchHousehold(String householdId) async* {
    if (watchHouseholdGate != null && !watchHouseholdGate!.isCompleted) {
      await watchHouseholdGate!.future;
    }
    if (watchHouseholdError != null) {
      throw watchHouseholdError!;
    }
    yield* _delegate.watchHousehold(householdId);
  }

  @override
  Stream<List<FeedingEvent>> watchRecentFeedings(
    String householdId, {
    int limit = 50,
  }) async* {
    if (recentHistoryGate != null && !recentHistoryGate!.isCompleted) {
      await recentHistoryGate!.future;
    }
    if (failHistoryStreams) {
      throw StateError('Simulated feedings permission error');
    }
    yield* _delegate.watchRecentFeedings(householdId, limit: limit);
  }

  @override
  Stream<List<TreatEvent>> watchRecentTreats(
    String householdId, {
    int limit = 50,
  }) async* {
    if (recentHistoryGate != null && !recentHistoryGate!.isCompleted) {
      await recentHistoryGate!.future;
    }
    if (failHistoryStreams) {
      throw StateError('Simulated treats permission error');
    }
    yield* _delegate.watchRecentTreats(householdId, limit: limit);
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
  }) async {
    updateMemberNameCalls += 1;
    final gate = updateMemberNameGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    if (updateMemberNameError != null) {
      throw updateMemberNameError!;
    }
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
  }) async {
    final gate = updateSettingsGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    if (updateSettingsError != null) {
      throw updateSettingsError!;
    }
    return _delegate.updateHouseholdSettings(
      householdId: householdId,
      requestingUid: requestingUid,
      schedule: schedule,
      dailyTreatLimit: dailyTreatLimit,
      petName: petName,
    );
  }

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
  }) async {
    final gate = undoFeedingGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    if (undoFeedingError != null) {
      throw undoFeedingError!;
    }
    return _delegate.undoFeeding(
      householdId: householdId,
      feedingId: feedingId,
      requestingUid: requestingUid,
    );
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
    logTreatCalls += 1;
    final gate = logTreatGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    if (logTreatError != null) {
      throw logTreatError!;
    }
    return _delegate.logTreat(
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
  }

  @override
  Future<void> deleteTreat({
    required String householdId,
    required String treatId,
    required String requestingUid,
  }) async {
    final gate = deleteTreatGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    if (deleteTreatError != null) {
      throw deleteTreatError!;
    }
    return _delegate.deleteTreat(
      householdId: householdId,
      treatId: treatId,
      requestingUid: requestingUid,
    );
  }
}

/// Flushes two event-loop turns so async stream/Completer updates settle in unit tests.
Future<void> flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
