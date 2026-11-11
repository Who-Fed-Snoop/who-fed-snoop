import 'package:flutter/foundation.dart';

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

/// Keeps the Android Home Screen Widget synchronized whenever a meal is logged
/// or the meal window transitions.
class WidgetSyncService {
  HomeWidgetSnapshot? _latestSnapshot;

  HomeWidgetSnapshot? get latestSnapshot => _latestSnapshot;

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
