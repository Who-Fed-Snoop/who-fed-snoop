import 'dart:math';

import '../../domain/models/active_meal_window.dart';
import '../../domain/models/feeding_event.dart';
import '../../domain/models/household.dart';
import '../../domain/models/meal_schedule.dart';
import '../../domain/models/treat_event.dart';

/// Shared validation, pruning, sanitization, and state-transition rules
/// enforced consistently by both [InMemoryHouseholdRepository] and
/// [FirestoreHouseholdRepository].
abstract final class HouseholdStatePolicy {
  static const String defaultHouseholdId = 'household_snoop_01';
  static const String defaultJoinCode = 'SNOOP4';
  static const String keniUid = 'uid_keni';
  static const String ashleyUid = 'uid_ashley';
  static const String defaultPetName = 'Snoop';
  static const int defaultDailyTreatLimit = 4;

  static int _idSequence = 0;

  /// Returns a monotonic base-36 suffix for unique bonus meal and treat IDs.
  static String nextUniqueSuffix() => (++_idSequence).toRadixString(36);

  /// Trims [raw], falls back to [fallback] when empty, and truncates to [maxLength].
  static String sanitizeName(
    String raw, {
    required String fallback,
    required int maxLength,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;
    if (trimmed.length <= maxLength) return trimmed;
    return trimmed.substring(0, maxLength);
  }

  /// Resolves a Scoop Holder display [name] to its canonical in-memory UID.
  ///
  /// Returns [fallback] when provided for non-preset names; otherwise derives
  /// a deterministic `uid_<slug>` identifier.
  static String resolveInMemoryUidForName(String name, {String? fallback}) {
    final lower = name.trim().toLowerCase();
    if (lower == 'keni') return keniUid;
    if (lower == 'ashley') return ashleyUid;
    if (fallback != null) return fallback;
    final slug = lower.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return slug.isEmpty ? keniUid : 'uid_$slug';
  }

  /// Resolves an optional cold-start Scoop Holder name; returns `null` when unbound.
  static String? resolveBoundMemberName(String? memberName) {
    final trimmed = memberName?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return sanitizeName(trimmed, fallback: 'Keni', maxLength: 50);
  }

  /// Returns `true` when cold-start initialization should register [memberUid]
  /// without clobbering any existing `members[memberUid]` entry.
  static bool shouldRegisterMemberOnColdStart({
    required Object? rawMembers,
    required String memberUid,
    required String? boundMemberName,
  }) {
    return boundMemberName != null && rawMembers is Map && !rawMembers.containsKey(memberUid);
  }

  /// Computes a non-clobbering `members[memberUid]` display name update.
  static ({
    Household household,
    HouseholdMember member,
    bool changed,
    bool isNewMember,
  }) applyMemberNameUpdate(
    Household household, {
    required String memberUid,
    required String memberName,
    required DateTime now,
  }) {
    final cleanName = sanitizeName(memberName, fallback: 'Member', maxLength: 50);
    final existingMember = household.members[memberUid];
    if (existingMember != null && existingMember.name == cleanName) {
      return (household: household, member: existingMember, changed: false, isNewMember: false);
    }

    final updatedMember = existingMember != null
        ? HouseholdMember(
            uid: memberUid,
            name: cleanName,
            fcmToken: existingMember.fcmToken,
            joinedAt: existingMember.joinedAt,
          )
        : HouseholdMember(uid: memberUid, name: cleanName, joinedAt: now);

    final updatedMembers = Map<String, HouseholdMember>.of(household.members)
      ..[memberUid] = updatedMember;

    return (
      household: household.copyWith(members: updatedMembers),
      member: updatedMember,
      changed: true,
      isNewMember: existingMember == null,
    );
  }

  /// Validates settings updates and returns the sanitized pet name (if provided).
  static String? validateSettingsInputs({
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  }) {
    if (schedule != null) {
      final validationError = schedule.validate();
      if (validationError != null) throw ArgumentError(validationError);
    }
    if (dailyTreatLimit != null && (dailyTreatLimit < 1 || dailyTreatLimit > 50)) {
      throw ArgumentError('Daily treat limit must be between 1 and 50.');
    }
    if (petName == null) return null;
    final trimmed = petName.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw ArgumentError('Pet name must be between 1 and 40 characters.');
    }
    return trimmed;
  }

  /// Validates and normalizes treat logging inputs against Firestore rules bounds.
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

    final cleanGivenByName = sanitizeName(givenByName, fallback: 'Someone', maxLength: 40);

    return (
      label: resolvedLabel,
      givenByName: cleanGivenByName,
      quantity: quantity,
      caloriesPerUnit: resolvedCalories,
      note: (trimmedNote != null && trimmedNote.isNotEmpty) ? trimmedNote : null,
    );
  }

  /// Builds a normalized [FeedingEvent] for [window] using a deterministic or unique bonus ID.
  static FeedingEvent buildFeedingEvent({
    required ActiveMealWindow window,
    required String fedByUid,
    required String fedByName,
    required DateTime now,
    required bool isExtraMeal,
  }) {
    final cleanFedByName = sanitizeName(fedByName, fallback: 'Someone', maxLength: 50);
    final eventId = isExtraMeal
        ? '${window.deterministicId}_extra_${now.millisecondsSinceEpoch}_${nextUniqueSuffix()}'
        : window.deterministicId;

    return FeedingEvent(
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
  }

  /// Validates inputs and constructs a normalized [TreatEvent] for [household].
  static TreatEvent buildTreatEvent({
    required Household household,
    required String givenByUid,
    required String givenByName,
    required DateTime now,
    required TreatPreset preset,
    String? customLabel,
    int quantity = 1,
    int? caloriesPerUnit,
    String? note,
  }) {
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

    return TreatEvent(
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
  static List<TreatEvent> pruneTodayTreats(List<TreatEvent> treats, String activeLogicalDate) {
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

  /// Orders remaining feeding candidates newest-first when reverting `lastFeeding`.
  static List<FeedingEvent> rankPreviousFeedingCandidates({
    required Map<String, FeedingEvent> updatedTodayMeals,
    Iterable<FeedingEvent> historyMeals = const <FeedingEvent>[],
    bool preferHistoryWhenPresent = false,
  }) {
    if (preferHistoryWhenPresent) {
      final historyList = historyMeals.toList()..sort((a, b) => b.fedAt.compareTo(a.fedAt));
      if (historyList.isNotEmpty) return historyList;
    }
    return <String, FeedingEvent>{
      for (final m in updatedTodayMeals.values) m.id: m,
      for (final m in historyMeals) m.id: m,
    }.values.toList()
      ..sort((a, b) => b.fedAt.compareTo(a.fedAt));
  }

  /// Returns the newest remaining feeding event to restore as `lastFeeding` on undo.
  static FeedingEvent? computePreviousLatestFeeding({
    required Map<String, FeedingEvent> updatedTodayMeals,
    Iterable<FeedingEvent> historyMeals = const <FeedingEvent>[],
    bool preferHistoryWhenPresent = false,
  }) {
    final candidates = rankPreviousFeedingCandidates(
      updatedTodayMeals: updatedTodayMeals,
      historyMeals: historyMeals,
      preferHistoryWhenPresent: preferHistoryWhenPresent,
    );
    return candidates.isNotEmpty ? candidates.first : null;
  }

  /// Generates a 6-character household join code (`<4 letters><2 digits>`).
  static String generateJoinCode(String petName, {Random? random}) {
    final letters =
        petName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '').padRight(4, 'X').substring(0, 4);
    final digits = ((random ?? Random()).nextInt(90) + 10).toString();
    return '$letters$digits';
  }
}
