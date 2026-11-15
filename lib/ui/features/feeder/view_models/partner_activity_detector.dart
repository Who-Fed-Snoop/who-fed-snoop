import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/household.dart';
import '../../../../domain/models/treat_event.dart';

/// Deduplicated real-time partner event detector so Undo rollbacks never
/// trigger false notifications from historical meals or treats.
class PartnerActivityDetector {
  bool _hasSeeded = false;
  final Map<String, String> _knownMealFingerprints = <String, String>{};
  final Set<String> _seenTreatIds = <String>{};
  final Set<String> _locallyAuthoredFingerprints = <String>{};
  DateTime? _highWaterMealAt;
  DateTime? _highWaterTreatAt;

  bool get hasSeeded => _hasSeeded;

  /// Clears all tracked fingerprints and high-water timestamps (e.g. on household switch).
  void reset() {
    _hasSeeded = false;
    _knownMealFingerprints.clear();
    _seenTreatIds.clear();
    _locallyAuthoredFingerprints.clear();
    _highWaterMealAt = null;
    _highWaterTreatAt = null;
  }

  /// Seeds baseline meal/treat state from the initial household snapshot without alerting.
  void seed(Household household) {
    _hasSeeded = true;
    for (final meal in _collectHouseholdMeals(household)) {
      _knownMealFingerprints[meal.id] = _mealFingerprint(meal);
      if (_highWaterMealAt == null || meal.fedAt.isAfter(_highWaterMealAt!)) {
        _highWaterMealAt = meal.fedAt;
      }
    }
    for (final treat in household.todayTreats) {
      _seenTreatIds.add(treat.id);
      if (_highWaterTreatAt == null || treat.givenAt.isAfter(_highWaterTreatAt!)) {
        _highWaterTreatAt = treat.givenAt;
      }
    }
  }

  /// Records a meal authored by this device so its snapshot echo never raises a partner banner.
  void recordLocalMeal(FeedingEvent meal) {
    final fingerprint = _mealFingerprint(meal);
    _locallyAuthoredFingerprints.add('${meal.id}|$fingerprint');
    _knownMealFingerprints[meal.id] = fingerprint;
    if (_highWaterMealAt == null || meal.fedAt.isAfter(_highWaterMealAt!)) {
      _highWaterMealAt = meal.fedAt;
    }
  }

  /// Records a treat authored by this device so its snapshot echo never raises a partner banner.
  void recordLocalTreat(TreatEvent treat) {
    _locallyAuthoredFingerprints.add('treat|${treat.id}');
    _seenTreatIds.add(treat.id);
    if (_highWaterTreatAt == null || treat.givenAt.isAfter(_highWaterTreatAt!)) {
      _highWaterTreatAt = treat.givenAt;
    }
  }

  /// Inspects [updatedHousehold] for newly observed partner meals or treats.
  /// Returns a formatted notification banner if a new partner update was detected, or `null`.
  String? detectUpdates(
    Household updatedHousehold, {
    required String currentMemberUid,
  }) {
    String? banner;

    final currentMeals = _collectHouseholdMeals(updatedHousehold);
    final activeMealIds = <String>{for (final m in currentMeals) m.id};

    // Prune fingerprints of undone/deleted meals so deterministic window IDs
    // (e.g. `YYYY-MM-DD_breakfast`) fire cleanly if re-logged by a partner later.
    _knownMealFingerprints.removeWhere((id, _) => !activeMealIds.contains(id));

    for (final meal in currentMeals) {
      final fingerprint = _mealFingerprint(meal);
      final previousFingerprint = _knownMealFingerprints[meal.id];
      _knownMealFingerprints[meal.id] = fingerprint;

      final isUnseenVersion = previousFingerprint != fingerprint;
      final isNotHistoricalRollback =
          _highWaterMealAt == null || !meal.fedAt.isBefore(_highWaterMealAt!);
      final isFromPartner = meal.fedByUid != currentMemberUid &&
          !_locallyAuthoredFingerprints.contains('${meal.id}|$fingerprint');

      if (isUnseenVersion && isNotHistoricalRollback && isFromPartner) {
        final timeStr = formatTimeOfDay(meal.fedAt);
        banner = meal.isExtraMeal
            ? '🥣 ${meal.fedByName} logged a bonus ${meal.effectiveLabel} scoop for ${updatedHousehold.petName} at $timeStr'
            : '🐾 ${meal.fedByName} fed ${updatedHousehold.petName} ${meal.effectiveLabel} at $timeStr';
      }

      if (_highWaterMealAt == null || meal.fedAt.isAfter(_highWaterMealAt!)) {
        _highWaterMealAt = meal.fedAt;
      }
    }

    // Sort treats oldest-to-newest so if multiple arrive at once, the newest wins the banner.
    final sortedTreats = List<TreatEvent>.of(updatedHousehold.todayTreats)
      ..sort((a, b) => a.givenAt.compareTo(b.givenAt));
    final activeTreatIds = <String>{for (final t in sortedTreats) t.id};
    _seenTreatIds.removeWhere((id) => !activeTreatIds.contains(id));

    for (final treat in sortedTreats) {
      final isNewTreat = _seenTreatIds.add(treat.id);
      final isNotHistoricalRollback =
          _highWaterTreatAt == null || !treat.givenAt.isBefore(_highWaterTreatAt!);
      final isFromPartner = treat.givenByUid != currentMemberUid &&
          !_locallyAuthoredFingerprints.contains('treat|${treat.id}');

      if (isNewTreat && isNotHistoricalRollback && isFromPartner) {
        final timeStr = formatTimeOfDay(treat.givenAt);
        final qtyPrefix = treat.quantity > 1 ? '${treat.quantity}x ' : '';
        banner =
            '${treat.emoji} ${treat.givenByName} gave ${updatedHousehold.petName} $qtyPrefix${treat.label} at $timeStr';
      }

      if (_highWaterTreatAt == null || treat.givenAt.isAfter(_highWaterTreatAt!)) {
        _highWaterTreatAt = treat.givenAt;
      }
    }

    return banner;
  }

  /// Formats a local timestamp as `h:mm AM/PM` for banners and history rows.
  static String formatTimeOfDay(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  static List<FeedingEvent> _collectHouseholdMeals(Household household) {
    final byId = <String, FeedingEvent>{...household.todayMeals};
    final latest = household.lastFeeding;
    if (latest != null && latest.id.isNotEmpty) {
      byId[latest.id] = latest;
    }
    return byId.values.toList()..sort((a, b) => a.fedAt.compareTo(b.fedAt));
  }

  static String _mealFingerprint(FeedingEvent meal) =>
      '${meal.fedByUid}@${meal.fedAt.microsecondsSinceEpoch}';
}
