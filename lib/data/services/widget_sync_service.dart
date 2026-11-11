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
  });

  final String petName;
  final String headline;
  final String subheadline;
  final bool isFed;
  final MealPeriod mealPeriod;
  final DateTime updatedAt;
}

/// Keeps the Android Home Screen Widget (`WhoFedSnoopWidgetProvider`) synchronized
/// whenever a meal is logged or the meal window transitions, and bridges native
/// Android App Links / NFC / Widget tap intents.
class WidgetSyncService {
  static const MethodChannel _platformChannel = MethodChannel(
    'com.whofedsnoop.who_fed_snoop/platform',
  );

  HomeWidgetSnapshot? _latestSnapshot;

  HomeWidgetSnapshot? get latestSnapshot => _latestSnapshot;

  /// Registers a listener for deep-link / NFC / Widget button taps delivered
  /// while the Android activity is running (`onNewIntent`) and returns any
  /// initial launch deep link.
  Future<Uri?> initDeepLinkBridge({
    required void Function(Uri uri) onDeepLinkReceived,
  }) async {
    if (kIsWeb) {
      final base = Uri.base;
      if (base.pathSegments.length >= 2) {
        return base;
      }
      return null;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    _platformChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onDeepLink') {
        final raw = call.arguments as String?;
        if (raw != null && raw.isNotEmpty) {
          final parsed = Uri.tryParse(raw);
          if (parsed != null) {
            onDeepLinkReceived(parsed);
          }
        }
      }
    });

    try {
      final rawInitial = await _platformChannel.invokeMethod<String>(
        'getInitialDeepLink',
      );
      if (rawInitial != null && rawInitial.isNotEmpty) {
        return Uri.tryParse(rawInitial);
      }
    } on MissingPluginException {
      // Safe no-op during widget tests
    } on PlatformException {
      // Safe no-op if platform channel fails
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

    final String headline;
    final String subheadline;

    if (currentFeeding != null) {
      final formattedTime = _formatClockTime(currentFeeding.fedAt);
      headline =
          '✅ ${currentFeeding.fedByName} fed ${household.petName} ${activeWindow.period.label}';
      subheadline = 'Logged at $formattedTime';
    } else {
      headline =
          '${activeWindow.period.emoji} ${household.petName} needs ${activeWindow.period.label}';
      final last = household.lastFeeding;
      if (last != null) {
        subheadline =
            'Last fed: ${last.mealPeriod.label} by ${last.fedByName} (${_formatClockTime(last.fedAt)})';
      } else {
        subheadline = 'Tap to log ${activeWindow.period.label.toLowerCase()}';
      }
    }

    final snapshot = HomeWidgetSnapshot(
      petName: household.petName,
      headline: headline,
      subheadline: subheadline,
      isFed: isFed,
      mealPeriod: activeWindow.period,
      updatedAt: now,
    );

    _latestSnapshot = snapshot;

    // Push snapshot to the native Android AppWidget if running on Android.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _platformChannel.invokeMethod<bool>(
          'updateHomeWidget',
          <String, Object?>{
            'petName': snapshot.petName,
            'headline': snapshot.headline,
            'subheadline': snapshot.subheadline,
            'isFed': snapshot.isFed,
            'mealPeriod': snapshot.mealPeriod.name,
            'householdId': household.id,
          },
        );
      } on MissingPluginException {
        // Ignored in unit/widget test environments.
      } on PlatformException {
        // Ignored if launcher widget service is unavailable.
      }
    }

    return snapshot;
  }

  static String _formatClockTime(DateTime time) {
    final local = time.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $suffix';
  }
}
