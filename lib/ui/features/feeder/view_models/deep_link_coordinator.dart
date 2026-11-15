import '../../../../data/repositories/household_repository.dart';
import '../../../../domain/models/deep_link_route.dart';
import '../../../../domain/models/household.dart';
import '../../../../domain/models/meal_window.dart';

typedef DeepLinkStrategy = Future<void> Function(WhofedsnoopDeepLink route);

/// Strategy-based router for incoming `/tap`, `/join`, and `/s` deep links.
class DeepLinkCoordinator {
  DeepLinkCoordinator({
    required HouseholdRepository repository,
    required bool Function() isDisposed,
    required Future<void> Function() waitForHouseholdLoaded,
    required Future<void> Function() waitForDeviceBound,
    required Household? Function() getHousehold,
    required String Function() getHouseholdId,
    required String Function() getCurrentMemberUid,
    required String Function() getCurrentMemberName,
    required ActiveMealWindow Function() getActiveWindow,
    required String? Function() getErrorMessage,
    required void Function(Household household) switchToLoadedHousehold,
    required Future<bool> Function() logMealForTap,
    required Future<void> Function({
      required String joinCode,
      required String memberName,
    }) joinHousehold,
    required void Function(String banner) activateSitterPersona,
    required void Function(String banner) showBanner,
    required void Function(Object error) reportError,
  })  : _repository = repository,
        _isDisposed = isDisposed,
        _waitForHouseholdLoaded = waitForHouseholdLoaded,
        _waitForDeviceBound = waitForDeviceBound,
        _getHousehold = getHousehold,
        _getHouseholdId = getHouseholdId,
        _getCurrentMemberUid = getCurrentMemberUid,
        _getCurrentMemberName = getCurrentMemberName,
        _getActiveWindow = getActiveWindow,
        _getErrorMessage = getErrorMessage,
        _switchToLoadedHousehold = switchToLoadedHousehold,
        _logMealForTap = logMealForTap,
        _joinHousehold = joinHousehold,
        _activateSitterPersona = activateSitterPersona,
        _showBanner = showBanner,
        _reportError = reportError {
    _strategies = <DeepLinkKind, DeepLinkStrategy>{
      DeepLinkKind.nfcTapToFeed: _handleTapToFeed,
      DeepLinkKind.joinHousehold: _handleJoinHousehold,
      DeepLinkKind.sitterGuestPass: _handleSitterGuestPass,
    };
  }

  final HouseholdRepository _repository;
  final bool Function() _isDisposed;
  final Future<void> Function() _waitForHouseholdLoaded;
  final Future<void> Function() _waitForDeviceBound;
  final Household? Function() _getHousehold;
  final String Function() _getHouseholdId;
  final String Function() _getCurrentMemberUid;
  final String Function() _getCurrentMemberName;
  final ActiveMealWindow Function() _getActiveWindow;
  final String? Function() _getErrorMessage;
  final void Function(Household household) _switchToLoadedHousehold;
  final Future<bool> Function() _logMealForTap;
  final Future<void> Function({
    required String joinCode,
    required String memberName,
  }) _joinHousehold;
  final void Function(String banner) _activateSitterPersona;
  final void Function(String banner) _showBanner;
  final void Function(Object error) _reportError;

  late final Map<DeepLinkKind, DeepLinkStrategy> _strategies;

  /// Parses [uri] and dispatches it to the matching route strategy.
  Future<void> handleUri(Uri uri) async {
    if (_isDisposed()) return;
    final route = WhofedsnoopDeepLink.tryParse(uri);
    if (route == null) return;

    final strategy = _strategies[route.kind];
    if (strategy == null) return;

    try {
      await strategy(route);
    } on Object catch (e) {
      if (!_isDisposed()) {
        _reportError(e);
      }
    }
  }

  Future<void> _handleTapToFeed(WhofedsnoopDeepLink route) async {
    await _waitForHouseholdLoaded();
    if (_isDisposed()) return;
    // FB-001: Unbound devices must confirm Scoop Holder identity before logging `/tap`.
    await _waitForDeviceBound();
    if (_isDisposed()) return;

    if (route.targetId != _getHouseholdId()) {
      final targetHousehold = await _repository.watchHousehold(route.targetId).first;
      if (_isDisposed()) return;
      if (targetHousehold == null || !targetHousehold.members.containsKey(_getCurrentMemberUid())) {
        _reportError('Household "${route.targetId}" was not found for this account.');
        return;
      }
      _switchToLoadedHousehold(targetHousehold);
    }

    if (_getHousehold() == null) {
      if (_getErrorMessage() == null) {
        _reportError('Unable to load household for Tap-to-Feed.');
      }
      return;
    }

    final succeeded = await _logMealForTap();
    if (_isDisposed()) return;
    final currentHousehold = _getHousehold();
    if (succeeded && _getErrorMessage() == null && currentHousehold != null) {
      _showBanner(
        '🏷️ Instant Tap-to-Feed: Logged ${_getActiveWindow().label} for ${currentHousehold.petName}!',
      );
    }
  }

  Future<void> _handleJoinHousehold(WhofedsnoopDeepLink route) async {
    await _joinHousehold(
      joinCode: route.targetId,
      memberName: _getCurrentMemberName(),
    );
  }

  Future<void> _handleSitterGuestPass(WhofedsnoopDeepLink route) async {
    await _waitForHouseholdLoaded();
    if (_isDisposed()) return;

    final normalizedCode = route.targetId.trim().toUpperCase();
    final existing = _getHousehold();
    final matchesActiveHousehold =
        existing != null && existing.joinCode.toUpperCase() == normalizedCode;

    var joinedOk = false;
    Object? joinError;
    try {
      await _joinHousehold(
        joinCode: route.targetId,
        memberName: 'Dog Sitter',
      );
      joinedOk = true;
    } on Object catch (e) {
      joinError = e;
    }

    if (_isDisposed()) return;

    if (joinedOk || matchesActiveHousehold) {
      final petName = _getHousehold()?.petName ?? 'Snoop';
      _activateSitterPersona(
        '🦴 Dog Sitter Guest Pass active — tap below when you feed $petName!',
      );
    } else {
      _reportError(
        joinError ?? 'Invalid Dog Sitter pass code "$normalizedCode".',
      );
    }
  }
}
