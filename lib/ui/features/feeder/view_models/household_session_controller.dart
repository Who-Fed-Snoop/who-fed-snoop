import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../../data/repositories/household_state_policy.dart';
import '../../../../data/services/scoop_holder_store.dart';
import '../../../../domain/models/feeding_event.dart';
import '../../../../domain/models/household.dart';
import '../../../../domain/models/treat_event.dart';
import 'partner_activity_detector.dart';
import 'undo_stack_controller.dart';

/// Manages household/history Firestore streams, Scoop Holder device binding,
/// and household create/join orchestration.
class HouseholdSessionController {
  HouseholdSessionController({
    required HouseholdRepository repository,
    required ScoopHolderStore? scoopHolderStore,
    required PartnerActivityDetector partnerDetector,
    required UndoStackController undoController,
    required String initialHouseholdId,
    required String initialMemberUid,
    required String initialMemberName,
    required VoidCallback onChanged,
    required VoidCallback clearError,
    required void Function(String? banner) onPartnerBanner,
    required void Function(Object error) onError,
    required void Function(Household household, {required bool rescheduleTimer}) onHouseholdUpdated,
  })  : _repository = repository,
        _scoopHolderStore = scoopHolderStore,
        _partnerDetector = partnerDetector,
        _undoController = undoController,
        _householdId = initialHouseholdId,
        _currentMemberUid = initialMemberUid,
        _currentMemberName = initialMemberName,
        _onChanged = onChanged,
        _clearError = clearError,
        _onPartnerBanner = onPartnerBanner,
        _onError = onError,
        _onHouseholdUpdated = onHouseholdUpdated {
    _initScoopHolderBinding(initialMemberUid);
    subscribeToHousehold(_householdId);
  }

  final HouseholdRepository _repository;
  final ScoopHolderStore? _scoopHolderStore;
  final PartnerActivityDetector _partnerDetector;
  final UndoStackController _undoController;
  final VoidCallback _onChanged;
  final VoidCallback _clearError;
  final void Function(String? banner) _onPartnerBanner;
  final void Function(Object error) _onError;
  final void Function(Household household, {required bool rescheduleTimer}) _onHouseholdUpdated;

  String _householdId;
  String _currentMemberUid;
  String _currentMemberName;
  bool _isDeviceBound = true;
  bool _hasSyncedMissingMemberOnLoad = false;
  bool _isHistoryExpanded = false;
  bool _isLoading = true;
  bool _isSwitchingHousehold = false;
  bool _isDisposed = false;

  Household? _household;
  List<FeedingEvent> _history = const <FeedingEvent>[];
  List<TreatEvent> _recentTreats = const <TreatEvent>[];

  StreamSubscription<Household?>? _householdSub;
  StreamSubscription<List<FeedingEvent>>? _historySub;
  StreamSubscription<List<TreatEvent>>? _treatHistorySub;
  Completer<void>? _initialLoadCompleter;
  Completer<void>? _bindingCompleter;

  Household? get household => _household;
  List<FeedingEvent> get history => _history;
  List<TreatEvent> get recentTreats => _recentTreats;
  bool get isHistoryExpanded => _isHistoryExpanded;
  bool get isLoading => _isLoading;
  String get householdId => _householdId;
  String get currentMemberUid => _currentMemberUid;
  String get currentMemberName => _currentMemberName;
  bool get isDeviceBound => _isDeviceBound;
  bool get needsScoopHolderPrompt => !_isDeviceBound;
  bool get isSitterMode => _currentMemberName == 'Dog Sitter';
  bool get canSimulatePartner => _repository is InMemoryHouseholdRepository;

  void _initScoopHolderBinding(String fallbackUid) {
    final store = _scoopHolderStore;
    if (store == null) return;
    final storedName = store.getMemberName()?.trim();
    if (storedName == null || storedName.isEmpty) {
      _isDeviceBound = false;
      _bindingCompleter = Completer<void>();
      return;
    }
    _isDeviceBound = true;
    _currentMemberName = HouseholdStatePolicy.sanitizeName(
      storedName,
      fallback: 'Member',
      maxLength: 50,
    );
    if (_repository is InMemoryHouseholdRepository) {
      final storedUid = store.getMemberUid()?.trim();
      _currentMemberUid = (storedUid != null && storedUid.isNotEmpty)
          ? storedUid
          : HouseholdStatePolicy.resolveInMemoryUidForName(
              storedName,
              fallback: fallbackUid,
            );
    }
  }

  /// Subscribes to the primary `households/{id}` stream and optionally history streams.
  void subscribeToHousehold(String householdId, {Household? initialHousehold}) {
    _householdSub?.cancel();
    _cancelHistoryStreams();
    _clearError();
    _onPartnerBanner(null);
    _history = const <FeedingEvent>[];
    _recentTreats = const <TreatEvent>[];
    _partnerDetector.reset();

    if (initialHousehold != null) {
      _partnerDetector.seed(initialHousehold);
      _applyHouseholdSnapshot(initialHousehold);
    } else {
      _household = null;
      _isLoading = true;
      _initialLoadCompleter = Completer<void>();
    }
    if (!_isDisposed) _onChanged();

    _householdSub = _repository.watchHousehold(householdId).listen(
      (updated) => _handleHouseholdSnapshot(householdId, updated),
      onError: (Object error) {
        if (_isDisposed || _householdId != householdId) return;
        _isLoading = false;
        _completeCompleter(_initialLoadCompleter);
        _onError(error);
      },
    );

    if (_isHistoryExpanded) _subscribeToHistoryStreams(householdId);
  }

  void _handleHouseholdSnapshot(String householdId, Household? updated) {
    if (_isDisposed || _householdId != householdId) return;
    if (updated != null) {
      if (!_partnerDetector.hasSeeded) {
        _partnerDetector.seed(updated);
      } else {
        final banner = _partnerDetector.detectUpdates(updated, currentMemberUid: _currentMemberUid);
        if (banner != null) _onPartnerBanner(banner);
      }
      if (_isDeviceBound &&
          !_hasSyncedMissingMemberOnLoad &&
          !updated.members.containsKey(_currentMemberUid)) {
        _hasSyncedMissingMemberOnLoad = true;
        unawaited(_syncBoundMemberName(updated.id));
      }
      _applyHouseholdSnapshot(updated);
    } else {
      _household = null;
      _isLoading = false;
      _completeCompleter(_initialLoadCompleter);
    }
    _onChanged();
  }

  void _applyHouseholdSnapshot(Household household) {
    _household = household;
    _isLoading = false;
    _completeCompleter(_initialLoadCompleter);
    _onHouseholdUpdated(household, rescheduleTimer: true);
  }

  void toggleHistoryExpanded() {
    if (_isDisposed) return;
    _isHistoryExpanded = !_isHistoryExpanded;
    if (_isHistoryExpanded) {
      _subscribeToHistoryStreams(_householdId);
    } else {
      _cancelHistoryStreams();
    }
    _onChanged();
  }

  /// Applies an optimistic household update before the async stream round-trip.
  void applyOptimisticHousehold(
    Household updated, {
    bool syncWidgetNow = true,
    bool rescheduleTimer = false,
  }) {
    _household = updated;
    if (syncWidgetNow) {
      _onHouseholdUpdated(updated, rescheduleTimer: rescheduleTimer);
    }
  }

  /// Switches the active household to an already loaded [target] snapshot.
  void switchToLoadedHousehold(Household target) {
    _householdId = target.id;
    _undoController.clear();
    subscribeToHousehold(target.id, initialHousehold: target);
  }

  /// Binds or switches the active phone Scoop Holder and syncs `members[uid].name`.
  Future<void> switchActiveMember({required String uid, required String name}) async {
    if (_isDisposed) return;
    final cleanName = HouseholdStatePolicy.sanitizeName(
      name,
      fallback: 'Member',
      maxLength: 50,
    );
    if (_repository is InMemoryHouseholdRepository) _currentMemberUid = uid;
    _bindLocalMember(cleanName);
    _onChanged();

    await _scoopHolderStore?.saveScoopHolder(name: cleanName, uid: _currentMemberUid);

    final currentHousehold = _household;
    if (!_isDisposed && currentHousehold != null) {
      try {
        await _repository.updateMemberName(
          householdId: currentHousehold.id,
          memberUid: _currentMemberUid,
          memberName: cleanName,
        );
      } on Object catch (e) {
        _onError(e);
      }
    }
  }

  Future<void> createNewHousehold({required String memberName, required String petName}) =>
      _switchHousehold(
        () => _repository.createHousehold(
          memberUid: _currentMemberUid,
          memberName: memberName,
          petName: petName,
        ),
        memberName: memberName,
        fallbackName: 'Keni',
      );

  Future<void> joinHousehold({required String joinCode, required String memberName}) =>
      _switchHousehold(
        () => _repository.joinHouseholdByCode(
          joinCode: joinCode,
          memberUid: _currentMemberUid,
          memberName: memberName,
        ),
        memberName: memberName,
        fallbackName: 'Ashley',
      );

  /// Activates the temporary Dog Sitter persona for `/s/{code}` links.
  void activateSitterPersona() {
    _currentMemberName = 'Dog Sitter';
    _isDeviceBound = true;
    _completeCompleter(_bindingCompleter);
  }

  Future<void> waitForHouseholdLoaded() => _awaitIf(!_isLoading, _initialLoadCompleter);

  Future<void> waitForDeviceBound() => _awaitIf(_isDeviceBound, _bindingCompleter);

  void dispose() {
    _isDisposed = true;
    _completeCompleter(_initialLoadCompleter);
    _completeCompleter(_bindingCompleter);
    _householdSub?.cancel();
    _cancelHistoryStreams();
  }

  Future<void> _switchHousehold(
    Future<Household> Function() loadHousehold, {
    required String memberName,
    required String fallbackName,
  }) async {
    if (_isDisposed || _isSwitchingHousehold) return;
    _isSwitchingHousehold = true;
    try {
      final target = await loadHousehold();
      if (_isDisposed) return;
      _bindLocalMember(
        HouseholdStatePolicy.sanitizeName(
          memberName,
          fallback: fallbackName,
          maxLength: 50,
        ),
      );
      _householdId = target.id;
      subscribeToHousehold(target.id, initialHousehold: target);
      await _scoopHolderStore?.saveScoopHolder(name: _currentMemberName, uid: _currentMemberUid);
    } finally {
      _isSwitchingHousehold = false;
    }
  }

  void _bindLocalMember(String name) {
    _currentMemberName = name;
    _isDeviceBound = true;
    _completeCompleter(_bindingCompleter);
    _undoController.clear();
  }

  Future<void> _awaitIf(bool alreadyReady, Completer<void>? completer) async {
    if (alreadyReady || completer == null || completer.isCompleted) return;
    await completer.future;
  }

  void _subscribeToHistoryStreams(String householdId) {
    _cancelHistoryStreams();
    _historySub = _watchScoped(
      householdId,
      _repository.watchRecentFeedings(householdId),
      (events) => _history = events,
    );
    _treatHistorySub = _watchScoped(
      householdId,
      _repository.watchRecentTreats(householdId),
      (treats) => _recentTreats = treats,
    );
  }

  StreamSubscription<T> _watchScoped<T>(
    String householdId,
    Stream<T> stream,
    void Function(T value) assign,
  ) =>
      stream.listen(
        (value) {
          if (_isDisposed || _householdId != householdId) return;
          assign(value);
          _onChanged();
        },
        onError: (Object e) {
          if (_isDisposed || _householdId != householdId) return;
          _onError(e);
        },
      );

  void _cancelHistoryStreams() {
    _historySub?.cancel();
    _treatHistorySub?.cancel();
    _historySub = null;
    _treatHistorySub = null;
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

  void _completeCompleter(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}
