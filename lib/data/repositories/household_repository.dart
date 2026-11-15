import '../../domain/models/feeding_event.dart';
import '../../domain/models/household.dart';
import '../../domain/models/meal_schedule.dart';
import '../../domain/models/treat_event.dart';

export 'in_memory_household_repository.dart';

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

  /// Registers or updates [memberUid]'s display name in `households/{id}.members`.
  Future<Household> updateMemberName({
    required String householdId,
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
