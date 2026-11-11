import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../../data/services/widget_sync_service.dart';
import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/household.dart';
import '../../../../domain/models/meal_window.dart';

/// ViewModel managing the 1-tap feeding screen, 10-second Undo timer,
/// partner notification banner, and Android widget state synchronization.
///
/// Cost-Control Design:
/// - Streams ONLY the single `households/{id}` document by default (1 read per state change).
/// - Lazily subscribes to the 7-day `feedings` subcollection only when the user expands
///   the history section, cutting Firestore read volume by >90%.
class FeederViewModel extends ChangeNotifier {
  FeederViewModel({
    required HouseholdRepository repository,
    required WidgetSyncService widgetSyncService,
    String initialHouseholdId = InMemoryHouseholdRepository.defaultHouseholdId,
    String initialMemberUid = InMemoryHouseholdRepository.keniUid,
    String initialMemberName = 'Keni',
    DateTime Function()? clock,
  })  : _repository = repository,
        _widgetSyncService = widgetSyncService,
        _householdId = initialHouseholdId,
        _currentMemberUid = initialMemberUid,
        _currentMemberName = initialMemberName,
        _clock = clock ?? DateTime.now {
    _subscribeToHousehold(_householdId);
  }

  final HouseholdRepository _repository;
  final WidgetSyncService _widgetSyncService;
  final DateTime Function() _clock;

  String _householdId;
  String _currentMemberUid;
  String _currentMemberName;

  StreamSubscription<Household?>? _householdSub;
  StreamSubscription<List<FeedingEvent>>? _historySub;
  Timer? _undoTimer;

  Household? _household;
  List<FeedingEvent> _history = const <FeedingEvent>[];
  bool _isHistoryExpanded = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _lastSeenFeedingId;

  /// Non-null during the 10-second Undo window right after the current user taps Feed.
  String? _undoableFeedingId;
  int _undoSecondsRemaining = 0;

  /// Push/realtime notification banner when the partner logs a meal.
  String? _partnerNotificationBanner;

  Household? get household => _household;
  List<FeedingEvent> get history => _history;
  bool get isHistoryExpanded => _isHistoryExpanded;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentMemberUid => _currentMemberUid;
  String get currentMemberName => _currentMemberName;
  int get undoSecondsRemaining => _undoSecondsRemaining;
  bool get canUndo => _undoableFeedingId != null && _undoSecondsRemaining > 0;
  String? get partnerNotificationBanner => _partnerNotificationBanner;
  HomeWidgetSnapshot? get widgetSnapshot => _widgetSyncService.latestSnapshot;

  ActiveMealWindow get activeWindow {
    final schedule = _household?.schedule ?? const MealSchedule();
    return ActiveMealWindow.forTime(_clock(), schedule: schedule);
  }

  FeedingEvent? get currentWindowFeeding {
    return _household?.feedingForWindow(activeWindow);
  }

  bool get isCurrentWindowFed => currentWindowFeeding != null;

  void _subscribeToHousehold(String householdId) {
    _isLoading = true;
    _errorMessage = null;
    _lastSeenFeedingId = null;
    notifyListeners();

    _householdSub?.cancel();
    _historySub?.cancel();

    _householdSub = _repository.watchHousehold(householdId).listen(
      (updatedHousehold) {
        final previousFeedingId = _lastSeenFeedingId;
        final latestFeeding = updatedHousehold?.lastFeeding;

        // Detect when a partner logs a meal in real time from the single-doc stream!
        if (previousFeedingId != null &&
            latestFeeding != null &&
            latestFeeding.id != previousFeedingId &&
            latestFeeding.fedByUid != _currentMemberUid) {
          final timeStr = formatTimeOfDay(latestFeeding.fedAt);
          _partnerNotificationBanner =
              '🐾 ${latestFeeding.fedByName} fed ${updatedHousehold!.petName} ${latestFeeding.mealPeriod.label} at $timeStr';
        }

        _lastSeenFeedingId = latestFeeding?.id ?? '';
        _household = updatedHousehold;
        _isLoading = false;

        if (updatedHousehold != null) {
          _widgetSyncService.syncHouseholdState(
            household: updatedHousehold,
            activeWindow: activeWindow,
            now: _clock(),
          );
        }
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    if (_isHistoryExpanded) {
      _subscribeToHistory(householdId);
    }
  }

  void _subscribeToHistory(String householdId) {
    _historySub?.cancel();
    _historySub = _repository.watchRecentFeedings(householdId).listen((events) {
      _history = events;
      notifyListeners();
    });
  }

  /// Lazily toggles the 7-day history stream so daily 2-second glances only read
  /// 1 Firestore document (`households/{id}`).
  void toggleHistoryExpanded() {
    _isHistoryExpanded = !_isHistoryExpanded;
    if (_isHistoryExpanded) {
      _subscribeToHistory(_householdId);
    } else {
      _historySub?.cancel();
      _historySub = null;
    }
    notifyListeners();
  }

  /// Primary 1-tap action: logs the current meal window for the active member.
  Future<void> markPetFed({bool isExtraMeal = false}) async {
    final currentHousehold = _household;
    if (currentHousehold == null) return;

    _errorMessage = null;
    try {
      final event = await _repository.logFeeding(
        householdId: currentHousehold.id,
        fedByUid: _currentMemberUid,
        fedByName: _currentMemberName,
        now: _clock(),
        isExtraMeal: isExtraMeal,
      );

      _startUndoCountdown(event.id);
    } on Object catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Simulates the partner (e.g. Ashley when Keni is active) logging the meal
  /// from their Android phone.
  Future<void> simulatePartnerFeed() async {
    final currentHousehold = _household;
    if (currentHousehold == null) return;

    final isKeniActive = _currentMemberUid == InMemoryHouseholdRepository.keniUid;
    final partnerUid =
        isKeniActive ? InMemoryHouseholdRepository.ashleyUid : InMemoryHouseholdRepository.keniUid;
    final partnerName = isKeniActive ? 'Ashley' : 'Keni';

    await _repository.logFeeding(
      householdId: currentHousehold.id,
      fedByUid: partnerUid,
      fedByName: partnerName,
      now: _clock(),
    );
  }

  void dismissPartnerBanner() {
    if (_partnerNotificationBanner != null) {
      _partnerNotificationBanner = null;
      notifyListeners();
    }
  }

  /// Reverts the meal logged within the 10-second Undo window.
  Future<void> undoLastFeed() async {
    final currentHousehold = _household;
    final feedingId = _undoableFeedingId;
    if (currentHousehold == null || feedingId == null) return;

    _cancelUndoTimer();
    try {
      await _repository.undoFeeding(
        householdId: currentHousehold.id,
        feedingId: feedingId,
        requestingUid: _currentMemberUid,
      );
      _partnerNotificationBanner = null;
      notifyListeners();
    } on Object catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Switches the active phone persona between Keni and Ashley for testing.
  void switchActiveMember({required String uid, required String name}) {
    _currentMemberUid = uid;
    _currentMemberName = name;
    _cancelUndoTimer();
    notifyListeners();
  }

  /// Creates a brand new household and switches to it.
  Future<void> createNewHousehold({
    required String memberName,
    required String petName,
  }) async {
    final created = await _repository.createHousehold(
      memberUid: _currentMemberUid,
      memberName: memberName,
      petName: petName,
    );
    _currentMemberName = memberName.trim().isEmpty ? 'Keni' : memberName.trim();
    _householdId = created.id;
    _cancelUndoTimer();
    _subscribeToHousehold(created.id);
  }

  /// Joins an existing household using a 6-character code.
  Future<void> joinHousehold({
    required String joinCode,
    required String memberName,
  }) async {
    final joined = await _repository.joinHouseholdByCode(
      joinCode: joinCode,
      memberUid: _currentMemberUid,
      memberName: memberName,
    );
    _currentMemberName = memberName.trim().isEmpty ? 'Ashley' : memberName.trim();
    _householdId = joined.id;
    _cancelUndoTimer();
    _subscribeToHousehold(joined.id);
  }

  void _startUndoCountdown(String feedingId) {
    _cancelUndoTimer();
    _undoableFeedingId = feedingId;
    _undoSecondsRemaining = 10;
    notifyListeners();

    _undoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_undoSecondsRemaining <= 1) {
        _cancelUndoTimer();
        notifyListeners();
      } else {
        _undoSecondsRemaining -= 1;
        notifyListeners();
      }
    });
  }

  void _cancelUndoTimer() {
    _undoTimer?.cancel();
    _undoTimer = null;
    _undoableFeedingId = null;
    _undoSecondsRemaining = 0;
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
    _cancelUndoTimer();
    _householdSub?.cancel();
    _historySub?.cancel();
    super.dispose();
  }
}
