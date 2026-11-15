import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../../data/services/scoop_holder_store.dart';
import '../../../../data/services/widget_sync_service.dart';
import '../../../../domain/models/deep_link_route.dart';
import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/household.dart';
import '../../../../domain/models/meal_window.dart';
import '../../../../domain/models/treat_event.dart';

/// Distinguishes whether a pending 10-second Undo target is a meal or a treat.
enum UndoKind { meal, treat }

/// Immutable entry on the 10-second LIFO Undo stack.
@immutable
class PendingUndoEntry {
  const PendingUndoEntry({
    required this.entryId,
    required this.kind,
    required this.label,
    String? emoji,
    this.householdId = '',
    this.secondsRemaining = 10,
  }) : emoji = emoji ?? (kind == UndoKind.meal ? '🥣' : '🦴');

  final String entryId;
  final UndoKind kind;
  final String label;
  final String emoji;
  final String householdId;
  final int secondsRemaining;

  PendingUndoEntry tick() => PendingUndoEntry(
        entryId: entryId,
        kind: kind,
        label: label,
        emoji: emoji,
        householdId: householdId,
        secondsRemaining: secondsRemaining - 1,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingUndoEntry &&
          entryId == other.entryId &&
          kind == other.kind &&
          label == other.label &&
          emoji == other.emoji &&
          householdId == other.householdId &&
          secondsRemaining == other.secondsRemaining;

  @override
  int get hashCode => Object.hash(
        entryId,
        kind,
        label,
        emoji,
        householdId,
        secondsRemaining,
      );
}

/// ViewModel managing the 1-tap feeding screen, custom household feeding windows,
/// orthogonal treat jar tracking, non-clobbering 10-second LIFO Undo stack,
/// partner notification banner, and Android widget state synchronization.
///
/// Cost-Control Design:
/// - Streams ONLY the single `households/{id}` document by default (1 read per state change).
/// - Lazily subscribes to the 7-day `feedings` and `treats` subcollections only when
///   the user expands the history section, cutting Firestore read volume by >90%.
class FeederViewModel extends ChangeNotifier {
  FeederViewModel({
    required HouseholdRepository repository,
    required WidgetSyncService widgetSyncService,
    ScoopHolderStore? scoopHolderStore,
    String initialHouseholdId = InMemoryHouseholdRepository.defaultHouseholdId,
    String initialMemberUid = InMemoryHouseholdRepository.keniUid,
    String initialMemberName = 'Keni',
    DateTime Function()? clock,
  })  : _repository = repository,
        _widgetSyncService = widgetSyncService,
        _scoopHolderStore = scoopHolderStore,
        _householdId = initialHouseholdId,
        _currentMemberUid = initialMemberUid,
        _currentMemberName = initialMemberName,
        _clock = clock ?? DateTime.now {
    if (scoopHolderStore != null) {
      final storedName = scoopHolderStore.getMemberName()?.trim();
      final storedUid = scoopHolderStore.getMemberUid()?.trim();
      if (storedName != null && storedName.isNotEmpty) {
        _isDeviceBound = true;
        _currentMemberName = _truncateMemberName(storedName);
        if (repository is InMemoryHouseholdRepository) {
          _currentMemberUid = (storedUid != null && storedUid.isNotEmpty)
              ? storedUid
              : _resolveInMemoryUidForName(storedName, fallback: initialMemberUid);
        }
      } else {
        _isDeviceBound = false;
        _bindingCompleter = Completer<void>();
      }
    }
    _subscribeToHousehold(_householdId);
    _scheduleWindowTransitionTimer();
  }

  final HouseholdRepository _repository;
  final WidgetSyncService _widgetSyncService;
  final ScoopHolderStore? _scoopHolderStore;
  final DateTime Function() _clock;

  String _householdId;
  String _currentMemberUid;
  String _currentMemberName;
  bool _isDeviceBound = true;
  bool _hasSyncedMissingMemberOnLoad = false;

  StreamSubscription<Household?>? _householdSub;
  StreamSubscription<List<FeedingEvent>>? _historySub;
  StreamSubscription<List<TreatEvent>>? _treatHistorySub;
  Timer? _undoTimer;
  Timer? _windowTransitionTimer;
  Completer<void>? _initialLoadCompleter;
  Completer<void>? _bindingCompleter;

  Household? _household;
  List<FeedingEvent> _history = const <FeedingEvent>[];
  List<TreatEvent> _recentTreats = const <TreatEvent>[];
  bool _isHistoryExpanded = false;
  bool _isLoading = true;
  bool _isDisposed = false;
  bool _isWindowTimerPaused = false;

  bool _isLoggingMeal = false;
  bool _isUndoing = false;
  bool _isUpdatingSettings = false;
  bool _isSwitchingHousehold = false;

  String? _errorMessage;

  /// LIFO stack of unexpired 10-second undo entries (meals & treats).
  final List<PendingUndoEntry> _undoStack = <PendingUndoEntry>[];

  /// Deduplicated real-time partner event tracking so Undo rollbacks never
  /// trigger false notifications from historical meals.
  bool _hasSeededSnapshotEvents = false;
  final Map<String, String> _knownMealFingerprints = <String, String>{};
  final Set<String> _seenTreatIds = <String>{};
  final Set<String> _locallyAuthoredFingerprints = <String>{};
  DateTime? _highWaterMealAt;
  DateTime? _highWaterTreatAt;

  /// Push/realtime notification banner when a partner logs a meal or treat.
  String? _partnerNotificationBanner;

  Household? get household => _household;
  List<FeedingEvent> get history => _history;
  List<TreatEvent> get recentTreats => _recentTreats;
  bool get isHistoryExpanded => _isHistoryExpanded;
  bool get isLoading => _isLoading;
  bool get isLoggingMeal => _isLoggingMeal;
  bool get isUndoing => _isUndoing;
  bool get isUpdatingSettings => _isUpdatingSettings;
  String? get errorMessage => _errorMessage;
  String get currentMemberUid => _currentMemberUid;
  String get currentMemberName => _currentMemberName;
  bool get isDeviceBound => _isDeviceBound;
  bool get needsScoopHolderPrompt => !_isDeviceBound;
  bool get isSitterMode => _currentMemberName == 'Dog Sitter';
  bool get canSimulatePartner => _repository is InMemoryHouseholdRepository;

  /// Active household feeding schedule (defaults to 4:00 AM Breakfast & 2:00 PM Dinner).
  MealSchedule get schedule => _household?.schedule ?? const MealSchedule();

  /// Daily household treat allowance before showing a soft warning badge.
  int get dailyTreatLimit => _household?.dailyTreatLimit ?? 4;

  /// Household logical date (`YYYY-MM-DD`), rolling over at the earliest morning window.
  String get currentLogicalDate => schedule.logicalDateFor(_clock());

  /// Currently active meal window for [_clock] and [schedule].
  ActiveMealWindow get activeWindow {
    return ActiveMealWindow.forTime(_clock(), schedule: schedule);
  }

  /// Set of `windowId`s already logged on the active logical date.
  Set<String> get todayLoggedWindowIds {
    return _household?.fedWindowIdsForDate(activeWindow.windowDate) ?? const <String>{};
  }

  /// Regular meal logged for [activeWindow], if any (never satisfied by treats or bonus scoops).
  FeedingEvent? get currentWindowFeeding {
    return _household?.feedingForWindow(activeWindow);
  }

  bool get isCurrentWindowFed => currentWindowFeeding != null;

  /// Treats logged on [currentLogicalDate], newest first.
  List<TreatEvent> get todayTreats {
    return _household?.treatsForDate(currentLogicalDate) ?? const <TreatEvent>[];
  }

  /// Total treat units (`sum(quantity)`) given on [currentLogicalDate].
  int get todayTreatCount {
    return _household?.treatCountForDate(currentLogicalDate) ?? 0;
  }

  /// Total estimated treat calories (`sum(totalCalories)`) on [currentLogicalDate].
  int get todayTreatCalories {
    return _household?.treatCaloriesForDate(currentLogicalDate) ?? 0;
  }

  /// True when [todayTreatCount] strictly exceeds [dailyTreatLimit].
  bool get isOverTreatLimit {
    return _household?.isOverTreatLimit(currentLogicalDate) ?? false;
  }

  /// Read-only view of all active 10-second Undo entries (oldest to newest).
  List<PendingUndoEntry> get undoStack => List<PendingUndoEntry>.unmodifiable(_undoStack);

  /// Top-of-stack Undo entry that [undoLastAction] will revert next.
  PendingUndoEntry? get activeUndoEntry => _undoStack.isEmpty ? null : _undoStack.last;

  /// Count of pending items currently in the 10-second Undo stack.
  int get pendingUndoCount => _undoStack.length;

  /// Seconds remaining on the top-of-stack Undo entry (`0` when empty).
  int get undoSecondsRemaining => _undoStack.isEmpty ? 0 : _undoStack.last.secondsRemaining;

  /// True when at least one unexpired entry is available to undo.
  bool get canUndo => _undoStack.isNotEmpty && _undoStack.last.secondsRemaining > 0;

  /// Formatted status copy for the Undo bar (e.g. `'🥣 Logged Breakfast! Undo within 8s'`
  /// or `'🥜 Logged PB Kong! Undo within 9s (+1 more)'`).
  String get undoBannerText {
    final top = activeUndoEntry;
    if (top == null || top.secondsRemaining <= 0) return '';
    final extraCount = _undoStack.length - 1;
    final moreSuffix = extraCount > 0 ? ' (+$extraCount more)' : '';
    return '${top.emoji} Logged ${top.label}! Undo within ${top.secondsRemaining}s$moreSuffix';
  }

  String? get partnerNotificationBanner => _partnerNotificationBanner;
  HomeWidgetSnapshot? get widgetSnapshot => _widgetSyncService.latestSnapshot;

  void _subscribeToHousehold(
    String householdId, {
    Household? initialHousehold,
  }) {
    _householdSub?.cancel();
    _historySub?.cancel();
    _treatHistorySub?.cancel();
    _historySub = null;
    _treatHistorySub = null;

    _errorMessage = null;
    _partnerNotificationBanner = null;
    _history = const <FeedingEvent>[];
    _recentTreats = const <TreatEvent>[];
    _resetPartnerEventTracking();

    if (initialHousehold != null) {
      _household = initialHousehold;
      _isLoading = false;
      _seedSnapshotEvents(initialHousehold);
      _completeInitialLoad();
      _widgetSyncService.syncHouseholdState(
        household: initialHousehold,
        activeWindow: activeWindow,
        now: _clock(),
      );
      _scheduleWindowTransitionTimer();
    } else {
      _household = null;
      _isLoading = true;
      _initialLoadCompleter = Completer<void>();
    }

    if (!_isDisposed) {
      notifyListeners();
    }

    _householdSub = _repository.watchHousehold(householdId).listen(
      (updatedHousehold) {
        if (_isDisposed || _householdId != householdId) return;

        if (updatedHousehold != null) {
          if (!_hasSeededSnapshotEvents) {
            _seedSnapshotEvents(updatedHousehold);
          } else {
            _detectPartnerUpdates(updatedHousehold);
          }
        }

        _household = updatedHousehold;
        _isLoading = false;
        _completeInitialLoad();

        if (updatedHousehold != null) {
          if (_isDeviceBound &&
              !_hasSyncedMissingMemberOnLoad &&
              !updatedHousehold.members.containsKey(_currentMemberUid)) {
            _hasSyncedMissingMemberOnLoad = true;
            unawaited(_syncBoundMemberName(updatedHousehold.id));
          }
          _widgetSyncService.syncHouseholdState(
            household: updatedHousehold,
            activeWindow: activeWindow,
            now: _clock(),
          );
        }
        _scheduleWindowTransitionTimer();
        notifyListeners();
      },
      onError: (Object error) {
        if (_isDisposed || _householdId != householdId) return;
        _errorMessage = _formatError(error);
        _isLoading = false;
        _completeInitialLoad();
        notifyListeners();
      },
    );

    if (_isHistoryExpanded) {
      _subscribeToHistoryStreams(householdId);
    }
  }

  void _resetPartnerEventTracking() {
    _hasSeededSnapshotEvents = false;
    _knownMealFingerprints.clear();
    _seenTreatIds.clear();
    _locallyAuthoredFingerprints.clear();
    _highWaterMealAt = null;
    _highWaterTreatAt = null;
  }

  void _seedSnapshotEvents(Household household) {
    _hasSeededSnapshotEvents = true;
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

  void _detectPartnerUpdates(Household updatedHousehold) {
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
      final isFromPartner = meal.fedByUid != _currentMemberUid &&
          !_locallyAuthoredFingerprints.contains('${meal.id}|$fingerprint');

      if (isUnseenVersion && isNotHistoricalRollback && isFromPartner) {
        final timeStr = formatTimeOfDay(meal.fedAt);
        if (meal.isExtraMeal) {
          _partnerNotificationBanner =
              '🥣 ${meal.fedByName} logged a bonus ${meal.effectiveLabel} scoop for ${updatedHousehold.petName} at $timeStr';
        } else {
          _partnerNotificationBanner =
              '🐾 ${meal.fedByName} fed ${updatedHousehold.petName} ${meal.effectiveLabel} at $timeStr';
        }
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
      final isFromPartner = treat.givenByUid != _currentMemberUid &&
          !_locallyAuthoredFingerprints.contains('treat|${treat.id}');

      if (isNewTreat && isNotHistoricalRollback && isFromPartner) {
        final timeStr = formatTimeOfDay(treat.givenAt);
        final qtyPrefix = treat.quantity > 1 ? '${treat.quantity}x ' : '';
        _partnerNotificationBanner =
            '${treat.emoji} ${treat.givenByName} gave ${updatedHousehold.petName} $qtyPrefix${treat.label} at $timeStr';
      }

      if (_highWaterTreatAt == null || treat.givenAt.isAfter(_highWaterTreatAt!)) {
        _highWaterTreatAt = treat.givenAt;
      }
    }
  }

  List<FeedingEvent> _collectHouseholdMeals(Household household) {
    final byId = <String, FeedingEvent>{
      ...household.todayMeals,
    };
    final latest = household.lastFeeding;
    if (latest != null && latest.id.isNotEmpty) {
      byId[latest.id] = latest;
    }
    final list = byId.values.toList()..sort((a, b) => a.fedAt.compareTo(b.fedAt));
    return list;
  }

  static String _mealFingerprint(FeedingEvent meal) =>
      '${meal.fedByUid}@${meal.fedAt.microsecondsSinceEpoch}';

  void _completeInitialLoad() {
    final completer = _initialLoadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _waitForHouseholdLoaded() async {
    if (!_isLoading) return;
    final completer = _initialLoadCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
  }

  void _completeBinding() {
    final completer = _bindingCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _waitForDeviceBound() async {
    if (_isDeviceBound) return;
    final completer = _bindingCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
  }

  Future<void> _syncBoundMemberName(String householdId) async {
    if (_isDisposed) return;
    try {
      await _repository.updateMemberName(
        householdId: householdId,
        memberUid: _currentMemberUid,
        memberName: _currentMemberName,
      );
    } on Object {
      // Best-effort registration when missing on cold start; never clobbers or blocks UI.
    }
  }

  static String _truncateMemberName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Member';
    return trimmed.length <= 50 ? trimmed : trimmed.substring(0, 50);
  }

  static String _resolveInMemoryUidForName(String name, {required String fallback}) {
    final lower = name.trim().toLowerCase();
    if (lower == 'keni') return InMemoryHouseholdRepository.keniUid;
    if (lower == 'ashley') return InMemoryHouseholdRepository.ashleyUid;
    return fallback;
  }

  void _subscribeToHistoryStreams(String householdId) {
    _historySub?.cancel();
    _treatHistorySub?.cancel();

    _historySub = _repository.watchRecentFeedings(householdId).listen(
      (events) {
        if (_isDisposed || _householdId != householdId) return;
        _history = events;
        notifyListeners();
      },
      onError: (Object error) {
        if (_isDisposed || _householdId != householdId) return;
        _errorMessage = _formatError(error);
        notifyListeners();
      },
    );

    _treatHistorySub = _repository.watchRecentTreats(householdId).listen(
      (treats) {
        if (_isDisposed || _householdId != householdId) return;
        _recentTreats = treats;
        notifyListeners();
      },
      onError: (Object error) {
        if (_isDisposed || _householdId != householdId) return;
        _errorMessage = _formatError(error);
        notifyListeners();
      },
    );
  }

  /// Lazily toggles the 7-day meal & treat history streams so daily 2-second glances
  /// only read 1 Firestore document (`households/{id}`).
  void toggleHistoryExpanded() {
    if (_isDisposed) return;
    _isHistoryExpanded = !_isHistoryExpanded;
    if (_isHistoryExpanded) {
      _subscribeToHistoryStreams(_householdId);
    } else {
      _historySub?.cancel();
      _treatHistorySub?.cancel();
      _historySub = null;
      _treatHistorySub = null;
    }
    notifyListeners();
  }

  /// Primary 1-tap action: logs the current meal window for the active member.
  Future<void> markPetFed({bool isExtraMeal = false}) async {
    await _markPetFedInternal(isExtraMeal: isExtraMeal);
  }

  Future<bool> _markPetFedInternal({required bool isExtraMeal}) async {
    if (_isDisposed || _isLoggingMeal) return false;
    final currentHousehold = _household;
    if (currentHousehold == null) return false;

    final targetHouseholdId = currentHousehold.id;
    final callNow = _clock();
    final windowBefore = ActiveMealWindow.forTime(
      callNow,
      schedule: currentHousehold.schedule,
    );
    final preexistingForWindow =
        !isExtraMeal ? currentHousehold.feedingForWindow(windowBefore) : null;

    _isLoggingMeal = true;
    _errorMessage = null;
    try {
      final event = await _repository.logFeeding(
        householdId: targetHouseholdId,
        fedByUid: _currentMemberUid,
        fedByName: _currentMemberName,
        now: callNow,
        isExtraMeal: isExtraMeal,
      );

      if (_isDisposed || _householdId != targetHouseholdId) return false;

      final wasNewlyLogged = isExtraMeal ||
          (preexistingForWindow == null &&
              event.fedByUid == _currentMemberUid &&
              event.fedAt.isAtSameMomentAs(callNow));

      if (wasNewlyLogged) {
        final fingerprint = _mealFingerprint(event);
        _locallyAuthoredFingerprints.add('${event.id}|$fingerprint');
        _knownMealFingerprints[event.id] = fingerprint;
        if (_highWaterMealAt == null || event.fedAt.isAfter(_highWaterMealAt!)) {
          _highWaterMealAt = event.fedAt;
        }

        // Apply optimistic household state immediately before async stream round-trip
        final latestHousehold = _household;
        if (latestHousehold != null && latestHousehold.id == targetHouseholdId) {
          final updatedMeals = Map<String, FeedingEvent>.of(
            latestHousehold.todayMeals,
          );
          if (!isExtraMeal) {
            updatedMeals[event.id] = event;
          }
          _household = latestHousehold.copyWith(
            lastFeeding: event,
            todayMeals: Map<String, FeedingEvent>.unmodifiable(updatedMeals),
          );
          _widgetSyncService.syncHouseholdState(
            household: _household!,
            activeWindow: activeWindow,
            now: _clock(),
          );
        }

        final undoLabel = isExtraMeal ? 'Bonus ${event.effectiveLabel}' : event.effectiveLabel;
        _pushUndoEntry(
          PendingUndoEntry(
            entryId: event.id,
            kind: UndoKind.meal,
            label: undoLabel,
            emoji: event.effectiveEmoji,
            householdId: targetHouseholdId,
          ),
        );
      } else {
        // Sync optimistic existing partner event if discovered on tap
        final latestHousehold = _household;
        if (latestHousehold != null &&
            latestHousehold.id == targetHouseholdId &&
            !isExtraMeal &&
            !latestHousehold.todayMeals.containsKey(event.id)) {
          final updatedMeals = Map<String, FeedingEvent>.of(
            latestHousehold.todayMeals,
          )..[event.id] = event;
          _household = latestHousehold.copyWith(
            todayMeals: Map<String, FeedingEvent>.unmodifiable(updatedMeals),
          );
          notifyListeners();
        }
      }
      return true;
    } on Object catch (e) {
      if (!_isDisposed) {
        _errorMessage = _formatError(e);
        notifyListeners();
      }
      return false;
    } finally {
      _isLoggingMeal = false;
    }
  }

  /// Logs a 1-tap preset treat (`quantity = 1`) without affecting meal window status,
  /// pushing a non-clobbering 10-second Undo entry onto [undoStack].
  Future<TreatEvent?> logQuickTreat(TreatPreset preset) {
    return _logTreatInternal(
      preset: preset,
      quantity: 1,
      caloriesPerUnit: preset.defaultCalories,
    );
  }

  /// Logs a custom treat with configurable label, quantity, calories, and optional note.
  Future<TreatEvent?> logCustomTreat({
    required String label,
    int quantity = 1,
    int caloriesPerUnit = 30,
    String? note,
  }) {
    return _logTreatInternal(
      preset: TreatPreset.custom,
      customLabel: label,
      quantity: quantity,
      caloriesPerUnit: caloriesPerUnit,
      note: note,
    );
  }

  Future<TreatEvent?> _logTreatInternal({
    required TreatPreset preset,
    String? customLabel,
    required int quantity,
    required int caloriesPerUnit,
    String? note,
  }) async {
    if (_isDisposed) return null;
    final currentHousehold = _household;
    if (currentHousehold == null) return null;

    final targetHouseholdId = currentHousehold.id;
    final callNow = _clock();
    _errorMessage = null;

    try {
      final treat = await _repository.logTreat(
        householdId: targetHouseholdId,
        givenByUid: _currentMemberUid,
        givenByName: _currentMemberName,
        now: callNow,
        preset: preset,
        customLabel: customLabel,
        quantity: quantity,
        caloriesPerUnit: caloriesPerUnit,
        note: note,
      );

      if (_isDisposed || _householdId != targetHouseholdId) return null;

      _locallyAuthoredFingerprints.add('treat|${treat.id}');
      _seenTreatIds.add(treat.id);
      if (_highWaterTreatAt == null || treat.givenAt.isAfter(_highWaterTreatAt!)) {
        _highWaterTreatAt = treat.givenAt;
      }

      final latestHousehold = _household;
      if (latestHousehold != null && latestHousehold.id == targetHouseholdId) {
        final alreadyInList = latestHousehold.todayTreats.any((t) => t.id == treat.id);
        if (!alreadyInList) {
          _household = latestHousehold.copyWith(
            todayTreats: List<TreatEvent>.unmodifiable(
              <TreatEvent>[treat, ...latestHousehold.todayTreats],
            ),
          );
          _widgetSyncService.syncHouseholdState(
            household: _household!,
            activeWindow: activeWindow,
            now: _clock(),
          );
        }
      }

      final displayLabel = treat.quantity > 1 ? '${treat.quantity}x ${treat.label}' : treat.label;
      _pushUndoEntry(
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
      if (!_isDisposed) {
        _errorMessage = _formatError(e);
        notifyListeners();
      }
      return null;
    }
  }

  /// Deletes a specific treat from Today's Treats / history and removes any matching
  /// entry from [undoStack].
  Future<void> deleteTreat(String treatId) async {
    if (_isDisposed) return;
    final currentHousehold = _household;
    if (currentHousehold == null) return;

    final targetHouseholdId = currentHousehold.id;
    _removeUndoEntryById(treatId, kind: UndoKind.treat);
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteTreat(
        householdId: targetHouseholdId,
        treatId: treatId,
        requestingUid: _currentMemberUid,
      );
      if (!_isDisposed) {
        notifyListeners();
      }
    } on Object catch (e) {
      if (!_isDisposed) {
        _errorMessage = _formatError(e);
        notifyListeners();
      }
    }
  }

  /// Validates and persists custom meal windows, daily treat goal, and/or pet name.
  Future<bool> updateHouseholdSettings({
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  }) async {
    if (_isDisposed || _isUpdatingSettings) return false;
    final currentHousehold = _household;
    if (currentHousehold == null) {
      _errorMessage = 'No active household loaded.';
      notifyListeners();
      return false;
    }

    if (schedule != null) {
      final validationError = schedule.validate();
      if (validationError != null) {
        _errorMessage = validationError;
        notifyListeners();
        return false;
      }
    }

    if (dailyTreatLimit != null && (dailyTreatLimit < 1 || dailyTreatLimit > 50)) {
      _errorMessage = 'Daily treat limit must be between 1 and 50.';
      notifyListeners();
      return false;
    }

    if (petName != null) {
      final trimmed = petName.trim();
      if (trimmed.isEmpty || trimmed.length > 40) {
        _errorMessage = 'Pet name must be between 1 and 40 characters.';
        notifyListeners();
        return false;
      }
    }

    final targetHouseholdId = currentHousehold.id;
    _isUpdatingSettings = true;
    _errorMessage = null;

    try {
      final updated = await _repository.updateHouseholdSettings(
        householdId: targetHouseholdId,
        requestingUid: _currentMemberUid,
        schedule: schedule,
        dailyTreatLimit: dailyTreatLimit,
        petName: petName,
      );

      if (_isDisposed || _householdId != targetHouseholdId) return false;

      _household = updated;
      _widgetSyncService.syncHouseholdState(
        household: updated,
        activeWindow: activeWindow,
        now: _clock(),
      );
      _scheduleWindowTransitionTimer();
      notifyListeners();
      return true;
    } on Object catch (e) {
      if (!_isDisposed) {
        _errorMessage = _formatError(e);
        notifyListeners();
      }
      return false;
    } finally {
      _isUpdatingSettings = false;
    }
  }

  /// Simulates the partner (e.g. Ashley when Keni is active) logging the meal
  /// from their Android phone when running in offline/demo mode.
  Future<void> simulatePartnerFeed() async {
    if (_isDisposed) return;
    final currentHousehold = _household;
    if (currentHousehold == null) return;

    if (!canSimulatePartner) {
      _errorMessage = 'Partner simulation is only available in local demo mode.';
      notifyListeners();
      return;
    }

    final isKeniActive = _currentMemberUid == InMemoryHouseholdRepository.keniUid;
    final partnerUid =
        isKeniActive ? InMemoryHouseholdRepository.ashleyUid : InMemoryHouseholdRepository.keniUid;
    final partnerName = isKeniActive ? 'Ashley' : 'Keni';

    _errorMessage = null;
    try {
      await _repository.logFeeding(
        householdId: currentHousehold.id,
        fedByUid: partnerUid,
        fedByName: partnerName,
        now: _clock(),
      );
    } on Object catch (e) {
      if (!_isDisposed) {
        _errorMessage = _formatError(e);
        notifyListeners();
      }
    }
  }

  void dismissPartnerBanner() {
    if (_isDisposed) return;
    if (_partnerNotificationBanner != null) {
      _partnerNotificationBanner = null;
      notifyListeners();
    }
  }

  void dismissError() {
    if (_isDisposed) return;
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Pops and reverts the top entry on the 10-second LIFO Undo stack
  /// (either a meal via `undoFeeding` or a treat via `deleteTreat`), preserving
  /// any earlier unexpired Undo entries and any unread partner notification banner.
  Future<void> undoLastAction() async {
    if (_isDisposed || _isUndoing) return;
    final currentHousehold = _household;
    if (currentHousehold == null || _undoStack.isEmpty) return;

    final entry = _undoStack.removeLast();
    if (_undoStack.isEmpty) {
      _undoTimer?.cancel();
      _undoTimer = null;
    }
    _errorMessage = null;
    notifyListeners();

    final targetHouseholdId =
        entry.householdId.isNotEmpty ? entry.householdId : currentHousehold.id;
    if (targetHouseholdId != _householdId) {
      return;
    }

    _isUndoing = true;
    try {
      if (entry.kind == UndoKind.meal) {
        await _repository.undoFeeding(
          householdId: targetHouseholdId,
          feedingId: entry.entryId,
          requestingUid: _currentMemberUid,
        );
      } else {
        await _repository.deleteTreat(
          householdId: targetHouseholdId,
          treatId: entry.entryId,
          requestingUid: _currentMemberUid,
        );
      }
      if (!_isDisposed) {
        notifyListeners();
      }
    } on Object catch (e) {
      if (!_isDisposed) {
        _errorMessage = _formatError(e);
        notifyListeners();
      }
    } finally {
      _isUndoing = false;
    }
  }

  /// Backward-compatible alias for [undoLastAction].
  Future<void> undoLastFeed() => undoLastAction();

  /// Binds or switches the active phone Scoop Holder (e.g. between Keni and Ashley),
  /// persists the selection locally, and syncs `households/{id}.members[uid].name`.
  ///
  /// When running against live Firestore, keeps [_currentMemberUid] anchored to
  /// the authenticated device UID so `firestore.rules` (`fedByUid == request.auth.uid`)
  /// is always satisfied; when running against [InMemoryHouseholdRepository],
  /// switches the simulated UID as well.
  Future<void> switchActiveMember({required String uid, required String name}) async {
    if (_isDisposed) return;
    final cleanName = _truncateMemberName(name);
    if (_repository is InMemoryHouseholdRepository) {
      _currentMemberUid = uid;
    }
    _currentMemberName = cleanName;
    _isDeviceBound = true;
    _completeBinding();
    _clearUndoStack();
    notifyListeners();

    await _scoopHolderStore?.saveScoopHolder(
      name: cleanName,
      uid: _currentMemberUid,
    );

    final currentHousehold = _household;
    if (!_isDisposed && currentHousehold != null) {
      try {
        await _repository.updateMemberName(
          householdId: currentHousehold.id,
          memberUid: _currentMemberUid,
          memberName: cleanName,
        );
      } on Object catch (e) {
        if (!_isDisposed) {
          _errorMessage = _formatError(e);
          notifyListeners();
        }
      }
    }
  }

  /// Binds an unbound device to a specific Scoop Holder for future cold starts.
  Future<void> bindScoopHolder({required String uid, required String name}) =>
      switchActiveMember(uid: uid, name: name);

  /// Creates a brand new household and switches to it.
  Future<void> createNewHousehold({
    required String memberName,
    required String petName,
  }) async {
    if (_isDisposed || _isSwitchingHousehold) return;
    _isSwitchingHousehold = true;
    try {
      final created = await _repository.createHousehold(
        memberUid: _currentMemberUid,
        memberName: memberName,
        petName: petName,
      );
      if (_isDisposed) return;
      _currentMemberName = memberName.trim().isEmpty ? 'Keni' : _truncateMemberName(memberName);
      _isDeviceBound = true;
      _completeBinding();
      _householdId = created.id;
      _clearUndoStack();
      _subscribeToHousehold(created.id, initialHousehold: created);
      await _scoopHolderStore?.saveScoopHolder(
        name: _currentMemberName,
        uid: _currentMemberUid,
      );
    } finally {
      _isSwitchingHousehold = false;
    }
  }

  /// Joins an existing household using a 6-character code.
  Future<void> joinHousehold({
    required String joinCode,
    required String memberName,
  }) async {
    if (_isDisposed || _isSwitchingHousehold) return;
    _isSwitchingHousehold = true;
    try {
      final joined = await _repository.joinHouseholdByCode(
        joinCode: joinCode,
        memberUid: _currentMemberUid,
        memberName: memberName,
      );
      if (_isDisposed) return;
      _currentMemberName = memberName.trim().isEmpty ? 'Ashley' : _truncateMemberName(memberName);
      _isDeviceBound = true;
      _completeBinding();
      _householdId = joined.id;
      _clearUndoStack();
      _subscribeToHousehold(joined.id, initialHousehold: joined);
      await _scoopHolderStore?.saveScoopHolder(
        name: _currentMemberName,
        uid: _currentMemberUid,
      );
    } finally {
      _isSwitchingHousehold = false;
    }
  }

  /// Processes incoming deep links from:
  /// - Android Home Screen Widget "I Fed Snoop" button (`/tap/{householdId}`)
  /// - Physical NFC food-bin sticker (`/tap/{householdId}`)
  /// - Partner invite link (`/join/{joinCode}`)
  /// - Dog Sitter temporary web pass (`/s/{joinCode}`)
  Future<void> handleIncomingUri(Uri uri) async {
    if (_isDisposed) return;
    final route = WhofedsnoopDeepLink.tryParse(uri);
    if (route == null) return;

    try {
      switch (route.kind) {
        case DeepLinkKind.nfcTapToFeed:
          await _waitForHouseholdLoaded();
          if (_isDisposed) return;
          await _waitForDeviceBound();
          if (_isDisposed) return;

          if (route.targetId != _householdId) {
            final targetHousehold = await _repository.watchHousehold(route.targetId).first;
            if (_isDisposed) return;
            if (targetHousehold == null ||
                !targetHousehold.members.containsKey(_currentMemberUid)) {
              _errorMessage = 'Household "${route.targetId}" was not found for this account.';
              notifyListeners();
              return;
            }
            _householdId = targetHousehold.id;
            _clearUndoStack();
            _subscribeToHousehold(
              targetHousehold.id,
              initialHousehold: targetHousehold,
            );
          }

          if (_household == null) {
            _errorMessage ??= 'Unable to load household for Tap-to-Feed.';
            notifyListeners();
            return;
          }

          final succeeded = await _markPetFedInternal(isExtraMeal: false);
          if (_isDisposed) return;
          if (succeeded && _errorMessage == null && _household != null) {
            final petName = _household!.petName;
            _partnerNotificationBanner =
                '🏷️ Instant Tap-to-Feed: Logged ${activeWindow.label} for $petName!';
            notifyListeners();
          }

        case DeepLinkKind.joinHousehold:
          await joinHousehold(
            joinCode: route.targetId,
            memberName: _currentMemberName,
          );

        case DeepLinkKind.sitterGuestPass:
          await _waitForHouseholdLoaded();
          if (_isDisposed) return;

          final normalizedCode = route.targetId.trim().toUpperCase();
          final matchesActiveHousehold =
              _household != null && _household!.joinCode.toUpperCase() == normalizedCode;

          var joinedOk = false;
          Object? joinError;
          try {
            await joinHousehold(
              joinCode: route.targetId,
              memberName: 'Dog Sitter',
            );
            joinedOk = true;
          } on Object catch (e) {
            joinError = e;
          }

          if (_isDisposed) return;

          if (joinedOk || matchesActiveHousehold) {
            _currentMemberName = 'Dog Sitter';
            _isDeviceBound = true;
            _completeBinding();
            _errorMessage = null;
            _partnerNotificationBanner =
                '🦴 Dog Sitter Guest Pass active — tap below when you feed ${_household?.petName ?? "Snoop"}!';
            notifyListeners();
          } else {
            _errorMessage = _formatError(
              joinError ?? 'Invalid Dog Sitter pass code "$normalizedCode".',
            );
            notifyListeners();
          }
      }
    } on Object catch (e) {
      if (!_isDisposed) {
        _errorMessage = _formatError(e);
        notifyListeners();
      }
    }
  }

  /// Re-evaluates the active meal window and logical date against [_clock]
  /// (e.g. when a scheduled window cutoff passes or the app resumes from background),
  /// re-syncs the Android Home Widget, and notifies listeners.
  void refreshForClockChange() {
    if (_isDisposed) return;
    final now = _clock();
    final currentHousehold = _household;
    if (currentHousehold != null) {
      _widgetSyncService.syncHouseholdState(
        household: currentHousehold,
        activeWindow: ActiveMealWindow.forTime(
          now,
          schedule: currentHousehold.schedule,
        ),
        now: now,
      );
    }
    _scheduleWindowTransitionTimer();
    notifyListeners();
  }

  /// Pauses the background window-transition timer when the host widget tree detaches.
  void cancelWindowTransitionTimer() {
    _isWindowTimerPaused = true;
    _windowTransitionTimer?.cancel();
    _windowTransitionTimer = null;
  }

  /// Resumes the background window-transition timer when a host widget tree attaches.
  void ensureWindowTransitionTimer() {
    if (_isDisposed) return;
    _isWindowTimerPaused = false;
    _scheduleWindowTransitionTimer();
  }

  void _scheduleWindowTransitionTimer() {
    _windowTransitionTimer?.cancel();
    _windowTransitionTimer = null;
    if (_isDisposed || _isWindowTimerPaused) return;

    final now = _clock();
    final window = ActiveMealWindow.forTime(now, schedule: schedule);
    final rawDelay = window.nextTransitionTime.difference(now);
    final delay = rawDelay < const Duration(seconds: 1) ? const Duration(seconds: 1) : rawDelay;

    _windowTransitionTimer = Timer(delay, () {
      if (_isDisposed) return;
      refreshForClockChange();
    });
  }

  void _pushUndoEntry(PendingUndoEntry entry) {
    if (_isDisposed) return;
    _undoStack.removeWhere(
      (existing) => existing.kind == entry.kind && existing.entryId == entry.entryId,
    );
    _undoStack.add(entry);
    notifyListeners();

    _undoTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed) {
        _clearUndoStack();
        return;
      }
      for (var i = _undoStack.length - 1; i >= 0; i--) {
        final next = _undoStack[i].tick();
        if (next.secondsRemaining <= 0) {
          _undoStack.removeAt(i);
        } else {
          _undoStack[i] = next;
        }
      }
      if (_undoStack.isEmpty) {
        _undoTimer?.cancel();
        _undoTimer = null;
      }
      notifyListeners();
    });
  }

  void _removeUndoEntryById(String entryId, {required UndoKind kind}) {
    _undoStack.removeWhere(
      (entry) => entry.kind == kind && entry.entryId == entryId,
    );
    if (_undoStack.isEmpty) {
      _undoTimer?.cancel();
      _undoTimer = null;
    }
  }

  void _clearUndoStack() {
    _undoTimer?.cancel();
    _undoTimer = null;
    _undoStack.clear();
  }

  static String _formatError(Object error) {
    var text = error.toString();
    if (text.startsWith('Bad state: ')) {
      text = text.substring('Bad state: '.length);
    } else if (text.startsWith('Invalid argument(s): ')) {
      text = text.substring('Invalid argument(s): '.length);
    }
    return text;
  }

  static String formatTimeOfDay(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _clearUndoStack();
    _windowTransitionTimer?.cancel();
    _windowTransitionTimer = null;
    _completeInitialLoad();
    _completeBinding();
    _householdSub?.cancel();
    _historySub?.cancel();
    _treatHistorySub?.cancel();
    super.dispose();
  }
}
