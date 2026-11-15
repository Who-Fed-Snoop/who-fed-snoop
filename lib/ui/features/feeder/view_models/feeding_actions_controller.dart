import 'package:flutter/foundation.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/meal_window.dart';
import '../../../../domain/models/treat_event.dart';
import 'household_session_controller.dart';
import 'partner_activity_detector.dart';
import 'undo_stack_controller.dart';

/// Handles meal logging, treat logging/deletion, household settings validation,
/// Undo execution, and demo partner simulation with optimistic UI updates.
class FeedingActionsController {
  FeedingActionsController({
    required HouseholdRepository repository,
    required HouseholdSessionController session,
    required PartnerActivityDetector partnerDetector,
    required UndoStackController undoController,
    required DateTime Function() clock,
    required VoidCallback clearError,
    required VoidCallback onChanged,
    required void Function(Object error) onError,
  })  : _repository = repository,
        _session = session,
        _partnerDetector = partnerDetector,
        _undoController = undoController,
        _clock = clock,
        _clearError = clearError,
        _onChanged = onChanged,
        _onError = onError;

  final HouseholdRepository _repository;
  final HouseholdSessionController _session;
  final PartnerActivityDetector _partnerDetector;
  final UndoStackController _undoController;
  final DateTime Function() _clock;
  final VoidCallback _clearError;
  final VoidCallback _onChanged;
  final void Function(Object error) _onError;

  bool _isLoggingMeal = false;
  bool _isUndoing = false;
  bool _isUpdatingSettings = false;
  bool _isDisposed = false;

  bool get isLoggingMeal => _isLoggingMeal;
  bool get isUndoing => _isUndoing;
  bool get isUpdatingSettings => _isUpdatingSettings;

  /// Logs the active meal window (or a bonus scoop when [isExtraMeal] is true).
  Future<bool> markPetFed({bool isExtraMeal = false}) async {
    if (_isDisposed || _isLoggingMeal) return false;
    final currentHousehold = _session.household;
    if (currentHousehold == null) return false;

    final targetHouseholdId = currentHousehold.id;
    final callNow = _clock();
    final windowBefore = ActiveMealWindow.forTime(callNow, schedule: currentHousehold.schedule);
    final preexistingForWindow =
        !isExtraMeal ? currentHousehold.feedingForWindow(windowBefore) : null;

    _isLoggingMeal = true;
    _clearError();
    try {
      final event = await _repository.logFeeding(
        householdId: targetHouseholdId,
        fedByUid: _session.currentMemberUid,
        fedByName: _session.currentMemberName,
        now: callNow,
        isExtraMeal: isExtraMeal,
      );
      if (_isDisposed || _session.householdId != targetHouseholdId) return false;

      final wasNewlyLogged = isExtraMeal ||
          (preexistingForWindow == null &&
              event.fedByUid == _session.currentMemberUid &&
              event.fedAt.isAtSameMomentAs(callNow));

      if (wasNewlyLogged) {
        _partnerDetector.recordLocalMeal(event);
        final latest = _session.household;
        if (latest != null && latest.id == targetHouseholdId) {
          final updatedMeals = Map<String, FeedingEvent>.of(latest.todayMeals);
          if (!isExtraMeal) updatedMeals[event.id] = event;
          _session.applyOptimisticHousehold(
            latest.copyWith(
              lastFeeding: event,
              todayMeals: Map<String, FeedingEvent>.unmodifiable(updatedMeals),
            ),
          );
        }
        final undoLabel = isExtraMeal ? 'Bonus ${event.effectiveLabel}' : event.effectiveLabel;
        _undoController.push(
          PendingUndoEntry(
            entryId: event.id,
            kind: UndoKind.meal,
            label: undoLabel,
            emoji: event.effectiveEmoji,
            householdId: targetHouseholdId,
          ),
        );
      } else {
        final latest = _session.household;
        if (latest != null &&
            latest.id == targetHouseholdId &&
            !isExtraMeal &&
            !latest.todayMeals.containsKey(event.id)) {
          final updatedMeals = Map<String, FeedingEvent>.of(latest.todayMeals)..[event.id] = event;
          _session.applyOptimisticHousehold(
            latest.copyWith(todayMeals: Map<String, FeedingEvent>.unmodifiable(updatedMeals)),
            syncWidgetNow: false,
          );
          _onChanged();
        }
      }
      return true;
    } on Object catch (e) {
      _onError(e);
      return false;
    } finally {
      _isLoggingMeal = false;
    }
  }

  /// Logs a preset or custom treat without affecting meal window status.
  Future<TreatEvent?> logTreat({
    required TreatPreset preset,
    String? customLabel,
    required int quantity,
    required int caloriesPerUnit,
    String? note,
  }) async {
    if (_isDisposed) return null;
    final currentHousehold = _session.household;
    if (currentHousehold == null) return null;

    final targetHouseholdId = currentHousehold.id;
    _clearError();
    try {
      final treat = await _repository.logTreat(
        householdId: targetHouseholdId,
        givenByUid: _session.currentMemberUid,
        givenByName: _session.currentMemberName,
        now: _clock(),
        preset: preset,
        customLabel: customLabel,
        quantity: quantity,
        caloriesPerUnit: caloriesPerUnit,
        note: note,
      );
      if (_isDisposed || _session.householdId != targetHouseholdId) return null;

      _partnerDetector.recordLocalTreat(treat);
      final latest = _session.household;
      if (latest != null &&
          latest.id == targetHouseholdId &&
          !latest.todayTreats.any((t) => t.id == treat.id)) {
        _session.applyOptimisticHousehold(
          latest.copyWith(
            todayTreats: List<TreatEvent>.unmodifiable(<TreatEvent>[treat, ...latest.todayTreats]),
          ),
        );
      }

      final displayLabel = treat.quantity > 1 ? '${treat.quantity}x ${treat.label}' : treat.label;
      _undoController.push(
        PendingUndoEntry(
          entryId: treat.id,
          kind: UndoKind.treat,
          label: displayLabel,
          emoji: treat.emoji,
          householdId: targetHouseholdId,
        ),
      );
      return treat;
    } on Object catch (e) {
      _onError(e);
      return null;
    }
  }

  /// Deletes a treat and removes any matching entry from the Undo stack.
  Future<void> deleteTreat(String treatId) async {
    if (_isDisposed) return;
    final currentHousehold = _session.household;
    if (currentHousehold == null) return;

    _undoController.removeById(treatId, kind: UndoKind.treat);
    _clearError();
    _onChanged();
    try {
      await _repository.deleteTreat(
        householdId: currentHousehold.id,
        treatId: treatId,
        requestingUid: _session.currentMemberUid,
      );
      if (!_isDisposed) _onChanged();
    } on Object catch (e) {
      _onError(e);
    }
  }

  /// Validates and persists custom meal windows, daily treat goal, and/or pet name.
  Future<bool> updateHouseholdSettings({
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  }) async {
    if (_isDisposed || _isUpdatingSettings) return false;
    final currentHousehold = _session.household;
    if (currentHousehold == null) {
      _onError('No active household loaded.');
      return false;
    }
    final validationError = _validateSettings(
      schedule: schedule,
      dailyTreatLimit: dailyTreatLimit,
      petName: petName,
    );
    if (validationError != null) {
      _onError(validationError);
      return false;
    }

    final targetHouseholdId = currentHousehold.id;
    _isUpdatingSettings = true;
    _clearError();
    try {
      final updated = await _repository.updateHouseholdSettings(
        householdId: targetHouseholdId,
        requestingUid: _session.currentMemberUid,
        schedule: schedule,
        dailyTreatLimit: dailyTreatLimit,
        petName: petName,
      );
      if (_isDisposed || _session.householdId != targetHouseholdId) return false;

      _session.applyOptimisticHousehold(updated, rescheduleTimer: true);
      _onChanged();
      return true;
    } on Object catch (e) {
      _onError(e);
      return false;
    } finally {
      _isUpdatingSettings = false;
    }
  }

  /// Simulates the partner logging the current meal in offline/demo mode.
  Future<void> simulatePartnerFeed() async {
    if (_isDisposed) return;
    final currentHousehold = _session.household;
    if (currentHousehold == null) return;
    if (!_session.canSimulatePartner) {
      _onError('Partner simulation is only available in local demo mode.');
      return;
    }
    final isKeniActive = _session.currentMemberUid == InMemoryHouseholdRepository.keniUid;
    _clearError();
    try {
      await _repository.logFeeding(
        householdId: currentHousehold.id,
        fedByUid: isKeniActive
            ? InMemoryHouseholdRepository.ashleyUid
            : InMemoryHouseholdRepository.keniUid,
        fedByName: isKeniActive ? 'Ashley' : 'Keni',
        now: _clock(),
      );
    } on Object catch (e) {
      _onError(e);
    }
  }

  /// Pops and reverts the top entry on the 10-second LIFO Undo stack.
  Future<void> undoLastAction() async {
    if (_isDisposed || _isUndoing) return;
    final currentHousehold = _session.household;
    if (currentHousehold == null || _undoController.isEmpty) return;

    final entry = _undoController.pop()!;
    _clearError();
    _onChanged();

    final targetHouseholdId =
        entry.householdId.isNotEmpty ? entry.householdId : currentHousehold.id;
    if (targetHouseholdId != _session.householdId) return;

    _isUndoing = true;
    try {
      if (entry.kind == UndoKind.meal) {
        await _repository.undoFeeding(
          householdId: targetHouseholdId,
          feedingId: entry.entryId,
          requestingUid: _session.currentMemberUid,
        );
      } else {
        await _repository.deleteTreat(
          householdId: targetHouseholdId,
          treatId: entry.entryId,
          requestingUid: _session.currentMemberUid,
        );
      }
      if (!_isDisposed) _onChanged();
    } on Object catch (e) {
      _onError(e);
    } finally {
      _isUndoing = false;
    }
  }

  void dispose() {
    _isDisposed = true;
  }

  String? _validateSettings({MealSchedule? schedule, int? dailyTreatLimit, String? petName}) {
    if (schedule != null) {
      final scheduleError = schedule.validate();
      if (scheduleError != null) return scheduleError;
    }
    if (dailyTreatLimit != null && (dailyTreatLimit < 1 || dailyTreatLimit > 50)) {
      return 'Daily treat limit must be between 1 and 50.';
    }
    if (petName != null) {
      final trimmed = petName.trim();
      if (trimmed.isEmpty || trimmed.length > 40) {
        return 'Pet name must be between 1 and 40 characters.';
      }
    }
    return null;
  }
}
