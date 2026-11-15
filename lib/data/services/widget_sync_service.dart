import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/models/household.dart';
import '../../domain/models/meal_window.dart';

/// Snapshot pushed to the Android Home Screen AppWidget (`WhoFedSnoopWidgetProvider`).
@immutable
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.petName,
    required this.headline,
    required this.subheadline,
    required this.isFed,
    required this.mealPeriod,
    required this.updatedAt,
    String? windowLabel,
    String? windowEmoji,
    this.nextTransitionTime,
    this.nextWindowLabel,
    this.nextWindowEmoji,
    this.todayTreatCount = 0,
    this.dailyTreatLimit = 4,
  })  : windowLabel = windowLabel ??
            (mealPeriod == MealPeriod.breakfast
                ? 'Breakfast'
                : mealPeriod == MealPeriod.lunch
                    ? 'Lunch'
                    : mealPeriod == MealPeriod.dinner
                        ? 'Dinner'
                        : mealPeriod == MealPeriod.lateSnack
                            ? 'Late Snack'
                            : 'Meal'),
        windowEmoji = windowEmoji ??
            (mealPeriod == MealPeriod.breakfast
                ? '🥣'
                : mealPeriod == MealPeriod.lunch
                    ? '🍲'
                    : mealPeriod == MealPeriod.dinner
                        ? '🍖'
                        : mealPeriod == MealPeriod.lateSnack
                            ? '🌙'
                            : '🐾');

  final String petName;
  final String headline;
  final String subheadline;
  final bool isFed;
  final MealPeriod mealPeriod;
  final String windowLabel;
  final String windowEmoji;
  final DateTime? nextTransitionTime;
  final String? nextWindowLabel;
  final String? nextWindowEmoji;
  final int todayTreatCount;
  final int dailyTreatLimit;
  final DateTime updatedAt;
}

/// Keeps the Android Home Screen Widget (`WhoFedSnoopWidgetProvider`) synchronized
/// whenever a meal is logged, a treat is tracked, or the meal window transitions,
/// and bridges native Android App Links / NFC / Widget tap intents.
class WidgetSyncService {
  WidgetSyncService({
    bool useEmulator = const bool.fromEnvironment('USE_FIREBASE_EMULATOR'),
  }) : _useEmulator = useEmulator;

  static const MethodChannel _platformChannel = MethodChannel(
    'com.whofedsnoop.who_fed_snoop/platform',
  );

  final bool _useEmulator;
  HomeWidgetSnapshot? _latestSnapshot;

  HomeWidgetSnapshot? get latestSnapshot => _latestSnapshot;

  /// Extracts a deep-link [Uri] from [base], supporting both standard path routing
  /// (`/join/SNOOP4`) and Flutter Web hash routing (`/#/join/SNOOP4` or `#join/SNOOP4`).
  @visibleForTesting
  static Uri? extractWebInitialUri(Uri base) {
    if (base.pathSegments.where((s) => s.isNotEmpty).length >= 2) {
      return base;
    }

    final fragment = base.fragment.trim();
    if (fragment.isNotEmpty) {
      final normalizedPath = fragment.startsWith('/') ? fragment : '/$fragment';
      final parsedFragment = Uri.tryParse(normalizedPath);
      if (parsedFragment != null &&
          parsedFragment.pathSegments.where((s) => s.isNotEmpty).length >= 2) {
        return Uri(
          scheme: base.scheme.isEmpty ? null : base.scheme,
          userInfo: base.userInfo.isEmpty ? null : base.userInfo,
          host: base.host.isEmpty ? null : base.host,
          port: base.hasPort ? base.port : null,
          path: parsedFragment.path,
          query: parsedFragment.hasQuery ? parsedFragment.query : null,
        );
      }
    }

    return null;
  }

  /// Registers a listener for deep-link / NFC / Widget button taps delivered
  /// while the Android activity is running (`onNewIntent`) and returns any
  /// initial launch deep link.
  Future<Uri?> initDeepLinkBridge({
    required FutureOr<void> Function(Uri uri) onDeepLinkReceived,
  }) async {
    if (kIsWeb) {
      return extractWebInitialUri(Uri.base);
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      _platformChannel.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'onDeepLink') {
          final raw = call.arguments as String?;
          if (raw != null && raw.isNotEmpty) {
            final parsed = Uri.tryParse(raw);
            if (parsed != null) {
              final resolved = extractWebInitialUri(parsed) ?? parsed;
              await onDeepLinkReceived(resolved);
            }
          }
        }
      });

      final rawInitial = await _platformChannel.invokeMethod<String>(
        'getInitialDeepLink',
      );
      if (rawInitial != null && rawInitial.isNotEmpty) {
        final parsed = Uri.tryParse(rawInitial);
        if (parsed != null) {
          return extractWebInitialUri(parsed) ?? parsed;
        }
      }
    } on MissingPluginException {
      // Safe no-op during widget tests
    } on PlatformException {
      // Safe no-op if platform channel fails
    } on FlutterError {
      // Safe no-op in pure Dart unit tests without ServicesBinding initialized
    }
    return null;
  }

  Future<HomeWidgetSnapshot> syncHouseholdState({
    required Household household,
    required ActiveMealWindow activeWindow,
    required DateTime now,
  }) async {
    final currentFeeding = household.feedingForWindow(activeWindow);
    final isFed = currentFeeding != null;

    final todayTreatCount = household.treatCountForDate(activeWindow.windowDate);
    final treatSuffix =
        todayTreatCount > 0 ? ' • 🦴 $todayTreatCount/${household.dailyTreatLimit} treats' : '';

    final String headline;
    final String subheadline;

    if (currentFeeding != null) {
      final formattedTime = _formatClockTime(currentFeeding.fedAt);
      headline = '✅ ${currentFeeding.fedByName} fed ${household.petName} ${activeWindow.label}';
      subheadline = 'Logged at $formattedTime$treatSuffix';
    } else {
      headline = '${activeWindow.emoji} ${household.petName} needs ${activeWindow.label}';
      final last = household.lastFeeding;
      if (last != null) {
        subheadline =
            'Last fed: ${last.effectiveLabel} by ${last.fedByName} (${_formatClockTime(last.fedAt)})$treatSuffix';
      } else {
        subheadline = 'Tap to log ${activeWindow.label.toLowerCase()}$treatSuffix';
      }
    }

    final snapshot = HomeWidgetSnapshot(
      petName: household.petName,
      headline: headline,
      subheadline: subheadline,
      isFed: isFed,
      mealPeriod: activeWindow.period,
      windowLabel: activeWindow.label,
      windowEmoji: activeWindow.emoji,
      nextTransitionTime: activeWindow.nextTransitionTime,
      nextWindowLabel: activeWindow.nextWindowLabel,
      nextWindowEmoji: activeWindow.nextWindowEmoji,
      todayTreatCount: todayTreatCount,
      dailyTreatLimit: household.dailyTreatLimit,
      updatedAt: now,
    );

    _latestSnapshot = snapshot;

    // Push snapshot to the native Android AppWidget if running on Android.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _platformChannel.invokeMethod<bool>(
          'updateHomeWidget',
          buildPlatformPayload(
            household: household,
            activeWindow: activeWindow,
            snapshot: snapshot,
          ),
        );
      } on MissingPluginException {
        // Ignored in unit/widget test environments.
      } on PlatformException {
        // Ignored if launcher widget service is unavailable.
      } on FlutterError {
        // Ignored in pure Dart unit tests where ServicesBinding is uninitialized.
      }
    }

    return snapshot;
  }

  /// Builds the platform-channel payload persisted into Android
  /// `who_fed_snoop_widget_prefs`, including `scheduleJson` and `useEmulator`
  /// so background widget wakeups can resolve rollovers and sync Firestore.
  @visibleForTesting
  Map<String, Object?> buildPlatformPayload({
    required Household household,
    required ActiveMealWindow activeWindow,
    required HomeWidgetSnapshot snapshot,
  }) {
    return <String, Object?>{
      'petName': snapshot.petName,
      'headline': snapshot.headline,
      'subheadline': snapshot.subheadline,
      'isFed': snapshot.isFed,
      'mealPeriod': activeWindow.label,
      'windowEmoji': activeWindow.emoji,
      'windowId': activeWindow.windowId,
      'windowDate': activeWindow.windowDate,
      'nextTransitionEpochMs': activeWindow.nextTransitionTime.millisecondsSinceEpoch,
      'nextWindowLabel': activeWindow.nextWindowLabel,
      'nextWindowEmoji': activeWindow.nextWindowEmoji,
      'householdId': household.id,
      'scheduleJson': jsonEncode(household.schedule.toJson()),
      'useEmulator': _useEmulator,
      'dailyTreatLimit': household.dailyTreatLimit,
      'todayTreatCount': snapshot.todayTreatCount,
      'treatLogicalDate': activeWindow.windowDate,
    };
  }

  static String _formatClockTime(DateTime time) {
    final local = time.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $suffix';
  }
}
