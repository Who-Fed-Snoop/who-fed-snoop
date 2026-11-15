import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../../data/services/scoop_holder_store.dart';
import '../../../../data/services/widget_sync_service.dart';
import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/household.dart';
import '../../../../domain/models/meal_window.dart';
import '../../../../domain/models/treat_event.dart';
import 'deep_link_coordinator.dart';
import 'feeding_actions_controller.dart';
import 'household_session_controller.dart';
import 'partner_activity_detector.dart';
import 'undo_stack_controller.dart';

export 'undo_stack_controller.dart' show PendingUndoEntry, UndoKind;

/// ViewModel facade managing the 1-tap feeding screen, custom household feeding
/// windows, orthogonal treat jar tracking, 10-second LIFO Undo stack, partner
/// notifications, deep links, and Android widget state synchronization.
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
  })  : _clock = clock ?? DateTime.now,
        _widgetSyncService = widgetSyncService {
    _undoController = UndoStackController(onChanged: _notifyIfActive);
    _session = HouseholdSessionController(
      repository: repository,
      scoopHolderStore: scoopHolderStore,
      partnerDetector: _partnerDetector,
      undoController: _undoController,
      initialHouseholdId: initialHouseholdId,
      initialMemberUid: initialMemberUid,
      initialMemberName: initialMemberName,
      onChanged: _notifyIfActive,
      clearError: () => _errorMessage = null,
      onPartnerBanner: (banner) => _partnerNotificationBanner = banner,
      onError: _captureError,
      onHouseholdUpdated: (household, {required bool rescheduleTimer}) {
        _syncWidget(household);
        if (rescheduleTimer) _scheduleWindowTransitionTimer();
      },
    );
    _actions = FeedingActionsController(
      repository: repository,
      session: _session,
      partnerDetector: _partnerDetector,
      undoController: _undoController,
      clock: _clock,
      clearError: () => _errorMessage = null,
      onChanged: _notifyIfActive,
      onError: _captureError,
    );
    _deepLinkCoordinator = _buildDeepLinkCoordinator(repository);
    _scheduleWindowTransitionTimer();
  }

  final DateTime Function() _clock;
  final WidgetSyncService _widgetSyncService;
  final PartnerActivityDetector _partnerDetector = PartnerActivityDetector();
  late final UndoStackController _undoController;
  late final HouseholdSessionController _session;
  late final FeedingActionsController _actions;
  late final DeepLinkCoordinator _deepLinkCoordinator;

  Timer? _windowTransitionTimer;
  bool _isDisposed = false;
  bool _isWindowTimerPaused = false;
  String? _errorMessage;
  String? _partnerNotificationBanner;

  Household? get household => _session.household;
  List<FeedingEvent> get history => _session.history;
  List<TreatEvent> get recentTreats => _session.recentTreats;
  bool get isHistoryExpanded => _session.isHistoryExpanded;
  bool get isLoading => _session.isLoading;
  bool get isLoggingMeal => _actions.isLoggingMeal;
  bool get isUndoing => _actions.isUndoing;
  bool get isUpdatingSettings => _actions.isUpdatingSettings;
  String? get errorMessage => _errorMessage;
  String get currentMemberUid => _session.currentMemberUid;
  String get currentMemberName => _session.currentMemberName;
  bool get isDeviceBound => _session.isDeviceBound;
  bool get needsScoopHolderPrompt => _session.needsScoopHolderPrompt;
  bool get isSitterMode => _session.isSitterMode;
  bool get canSimulatePartner => _session.canSimulatePartner;

  /// Active household feeding schedule (defaults to 4:00 AM Breakfast & 2:00 PM Dinner).
  MealSchedule get schedule => household?.schedule ?? const MealSchedule();

  /// Daily household treat allowance before showing a soft warning badge.
  int get dailyTreatLimit => household?.dailyTreatLimit ?? 4;

  /// Household logical date (`YYYY-MM-DD`), rolling over at the earliest morning window.
  String get currentLogicalDate => schedule.logicalDateFor(_clock());

  /// Currently active meal window for [_clock] and [schedule].
  ActiveMealWindow get activeWindow => ActiveMealWindow.forTime(_clock(), schedule: schedule);

  /// Set of `windowId`s already logged on the active logical date.
  Set<String> get todayLoggedWindowIds =>
      household?.fedWindowIdsForDate(activeWindow.windowDate) ?? const <String>{};

  /// Regular meal logged for [activeWindow], if any (never satisfied by treats or bonus scoops).
  FeedingEvent? get currentWindowFeeding => household?.feedingForWindow(activeWindow);

  bool get isCurrentWindowFed => currentWindowFeeding != null;

  /// Treats logged on [currentLogicalDate], newest first.
  List<TreatEvent> get todayTreats =>
      household?.treatsForDate(currentLogicalDate) ?? const <TreatEvent>[];

  /// Total treat units (`sum(quantity)`) given on [currentLogicalDate].
  int get todayTreatCount => household?.treatCountForDate(currentLogicalDate) ?? 0;

  /// Total estimated treat calories (`sum(totalCalories)`) on [currentLogicalDate].
  int get todayTreatCalories => household?.treatCaloriesForDate(currentLogicalDate) ?? 0;

  /// True when [todayTreatCount] strictly exceeds [dailyTreatLimit].
  bool get isOverTreatLimit => household?.isOverTreatLimit(currentLogicalDate) ?? false;

  /// Read-only view of all active 10-second Undo entries (oldest to newest).
  List<PendingUndoEntry> get undoStack => _undoController.entries;

  /// Top-of-stack Undo entry that [undoLastAction] will revert next.
  PendingUndoEntry? get activeUndoEntry => _undoController.activeEntry;

  /// Count of pending items currently in the 10-second Undo stack.
  int get pendingUndoCount => _undoController.length;

  /// Seconds remaining on the top-of-stack Undo entry (`0` when empty).
  int get undoSecondsRemaining => _undoController.secondsRemaining;

  /// True when at least one unexpired entry is available to undo.
  bool get canUndo => _undoController.canUndo;

  /// Formatted status copy for the Undo bar.
  String get undoBannerText => _undoController.bannerText;

  String? get partnerNotificationBanner => _partnerNotificationBanner;
  HomeWidgetSnapshot? get widgetSnapshot => _widgetSyncService.latestSnapshot;

  /// Lazily toggles the 7-day meal & treat history streams so daily 2-second glances
  /// only read 1 Firestore document (`households/{id}`).
  void toggleHistoryExpanded() => _session.toggleHistoryExpanded();

  /// Primary 1-tap action: logs the current meal window for the active member.
  Future<void> markPetFed({bool isExtraMeal = false}) async {
    await _actions.markPetFed(isExtraMeal: isExtraMeal);
  }

  /// Logs a 1-tap preset treat (`quantity = 1`) without affecting meal window status,
  /// pushing a non-clobbering 10-second Undo entry onto [undoStack].
  Future<TreatEvent?> logQuickTreat(TreatPreset preset) => _actions.logTreat(
        preset: preset,
        quantity: 1,
        caloriesPerUnit: preset.defaultCalories,
      );

  /// Logs a custom treat with configurable label, quantity, calories, and optional note.
  Future<TreatEvent?> logCustomTreat({
    required String label,
    int quantity = 1,
    int caloriesPerUnit = 30,
    String? note,
  }) =>
      _actions.logTreat(
        preset: TreatPreset.custom,
        customLabel: label,
        quantity: quantity,
        caloriesPerUnit: caloriesPerUnit,
        note: note,
      );

  /// Deletes a specific treat from Today's Treats / history and removes any matching
  /// entry from [undoStack].
  Future<void> deleteTreat(String treatId) => _actions.deleteTreat(treatId);

  /// Validates and persists custom meal windows, daily treat goal, and/or pet name.
  Future<bool> updateHouseholdSettings({
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  }) =>
      _actions.updateHouseholdSettings(
        schedule: schedule,
        dailyTreatLimit: dailyTreatLimit,
        petName: petName,
      );

  /// Simulates the partner (e.g. Ashley when Keni is active) logging the meal
  /// from their Android phone when running in offline/demo mode.
  Future<void> simulatePartnerFeed() => _actions.simulatePartnerFeed();

  void dismissPartnerBanner() {
    if (_isDisposed || _partnerNotificationBanner == null) return;
    _partnerNotificationBanner = null;
    notifyListeners();
  }

  void dismissError() {
    if (_isDisposed || _errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Pops and reverts the top entry on the 10-second LIFO Undo stack.
  Future<void> undoLastAction() => _actions.undoLastAction();

  /// Backward-compatible alias for [undoLastAction].
  Future<void> undoLastFeed() => undoLastAction();

  /// Binds or switches the active phone Scoop Holder and syncs `members[uid].name`.
  Future<void> switchActiveMember({required String uid, required String name}) =>
      _session.switchActiveMember(uid: uid, name: name);

  /// Binds an unbound device to a specific Scoop Holder for future cold starts.
  Future<void> bindScoopHolder({required String uid, required String name}) =>
      _session.switchActiveMember(uid: uid, name: name);

  /// Creates a brand new household and switches to it.
  Future<void> createNewHousehold({required String memberName, required String petName}) =>
      _session.createNewHousehold(memberName: memberName, petName: petName);

  /// Joins an existing household using a 6-character code.
  Future<void> joinHousehold({required String joinCode, required String memberName}) =>
      _session.joinHousehold(joinCode: joinCode, memberName: memberName);

  /// Processes incoming `/tap`, `/join`, and `/s` deep links via [DeepLinkCoordinator].
  Future<void> handleIncomingUri(Uri uri) => _deepLinkCoordinator.handleUri(uri);

  /// Re-evaluates the active meal window and logical date against [_clock],
  /// re-syncs the Android Home Widget, and notifies listeners.
  void refreshForClockChange() {
    if (_isDisposed) return;
    final now = _clock();
    final currentHousehold = household;
    if (currentHousehold != null) _syncWidget(currentHousehold, now: now);
    _scheduleWindowTransitionTimer();
    notifyListeners();
  }

  void _syncWidget(Household household, {DateTime? now}) {
    final effectiveNow = now ?? _clock();
    _widgetSyncService.syncHouseholdState(
      household: household,
      activeWindow: ActiveMealWindow.forTime(effectiveNow, schedule: household.schedule),
      now: effectiveNow,
    );
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

  DeepLinkCoordinator _buildDeepLinkCoordinator(HouseholdRepository repository) =>
      DeepLinkCoordinator(
        repository: repository,
        isDisposed: () => _isDisposed,
        waitForHouseholdLoaded: _session.waitForHouseholdLoaded,
        waitForDeviceBound: _session.waitForDeviceBound,
        getHousehold: () => _session.household,
        getHouseholdId: () => _session.householdId,
        getCurrentMemberUid: () => _session.currentMemberUid,
        getCurrentMemberName: () => _session.currentMemberName,
        getActiveWindow: () => activeWindow,
        getErrorMessage: () => _errorMessage,
        switchToLoadedHousehold: _session.switchToLoadedHousehold,
        logMealForTap: () => _actions.markPetFed(isExtraMeal: false),
        joinHousehold: _session.joinHousehold,
        activateSitterPersona: (banner) {
          _session.activateSitterPersona();
          _errorMessage = null;
          _partnerNotificationBanner = banner;
          notifyListeners();
        },
        showBanner: (banner) {
          _partnerNotificationBanner = banner;
          notifyListeners();
        },
        reportError: _captureError,
      );

  void _scheduleWindowTransitionTimer() {
    _windowTransitionTimer?.cancel();
    _windowTransitionTimer = null;
    if (_isDisposed || _isWindowTimerPaused) return;

    final now = _clock();
    final window = ActiveMealWindow.forTime(now, schedule: schedule);
    final rawDelay = window.nextTransitionTime.difference(now);
    final delay = rawDelay < const Duration(seconds: 1) ? const Duration(seconds: 1) : rawDelay;
    _windowTransitionTimer = Timer(delay, () {
      if (!_isDisposed) refreshForClockChange();
    });
  }

  void _notifyIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  void _captureError(Object error) {
    if (_isDisposed) return;
    var text = error.toString();
    if (text.startsWith('Bad state: ')) {
      text = text.substring('Bad state: '.length);
    } else if (text.startsWith('Invalid argument(s): ')) {
      text = text.substring('Invalid argument(s): '.length);
    }
    _errorMessage = text;
    notifyListeners();
  }

  static String formatTimeOfDay(DateTime dateTime) =>
      PartnerActivityDetector.formatTimeOfDay(dateTime);

  @override
  void dispose() {
    _isDisposed = true;
    _undoController.dispose();
    _actions.dispose();
    _session.dispose();
    _windowTransitionTimer?.cancel();
    _windowTransitionTimer = null;
    super.dispose();
  }
}
