import 'package:flutter/foundation.dart';

import 'meal_period.dart';
import 'meal_schedule.dart';

/// Snapshot of the currently active meal window for a given point in time.
@immutable
class ActiveMealWindow {
  const ActiveMealWindow({
    required this.period,
    required this.windowDate,
    required this.nextTransitionTime,
    String? windowId,
    String? label,
    String? emoji,
    String? nextWindowLabel,
    String? nextWindowEmoji,
  })  : windowId = windowId ??
            (period == MealPeriod.breakfast
                ? 'breakfast'
                : period == MealPeriod.lunch
                    ? 'lunch'
                    : period == MealPeriod.dinner
                        ? 'dinner'
                        : period == MealPeriod.lateSnack
                            ? 'lateSnack'
                            : 'custom'),
        label = label ??
            (period == MealPeriod.breakfast
                ? 'Breakfast'
                : period == MealPeriod.lunch
                    ? 'Lunch'
                    : period == MealPeriod.dinner
                        ? 'Dinner'
                        : period == MealPeriod.lateSnack
                            ? 'Late Snack'
                            : 'Meal'),
        emoji = emoji ??
            (period == MealPeriod.breakfast
                ? '🥣'
                : period == MealPeriod.lunch
                    ? '🍲'
                    : period == MealPeriod.dinner
                        ? '🍖'
                        : period == MealPeriod.lateSnack
                            ? '🌙'
                            : '🐾'),
        nextWindowLabel =
            nextWindowLabel ?? (period == MealPeriod.breakfast ? 'Dinner' : 'Breakfast'),
        nextWindowEmoji = nextWindowEmoji ?? (period == MealPeriod.breakfast ? '🍖' : '🥣');

  final MealPeriod period;

  /// Stable window config ID (e.g. `'breakfast'`, `'dinner'`, `'lunch'`, `'custom_1'`).
  final String windowId;

  /// Human-readable label for this window (e.g. `'Breakfast'`, `'Second Breakfast'`).
  final String label;

  /// Display emoji for this window (e.g. `'🥣'`, `'🍖'`).
  final String emoji;

  /// Local calendar date string (`YYYY-MM-DD`) that owns this meal window.
  ///
  /// Between midnight (`00:00`) and the first morning window, the active window
  /// still belongs to yesterday's last meal window so late-night checks or feedings
  /// attach to the right logical day.
  final String windowDate;

  /// When this window automatically resets to the next meal window.
  final DateTime nextTransitionTime;

  /// Human-readable label of the upcoming meal window at [nextTransitionTime].
  final String nextWindowLabel;

  /// Emoji of the upcoming meal window at [nextTransitionTime].
  final String nextWindowEmoji;

  /// Deterministic document ID (`{windowDate}_{windowId}`) used in Firestore
  /// to prevent duplicate logs if Keni and Ashley tap at the exact same second.
  String get deterministicId => '${windowDate}_$windowId';

  /// Calculates the active meal window for [now] using [schedule].
  factory ActiveMealWindow.forTime(
    DateTime now, {
    MealSchedule schedule = const MealSchedule(),
  }) {
    final local = now.toLocal();
    final nowMinutes = local.hour * 60 + local.minute;
    final enabled = schedule.enabledWindows;
    final firstWindow = enabled.first;

    // Pre-morning wrap-around (00:00 .. before firstWindow):
    // Still belongs to yesterday's final meal window!
    // Uses local calendar DateTime(y, m, d - 1) so 23h/25h DST transitions never skew the date.
    if (nowMinutes < firstWindow.startMinutesOfDay) {
      final activeConfig = enabled.last;
      final yesterday = DateTime(local.year, local.month, local.day - 1);
      final nextTransition = DateTime(
        local.year,
        local.month,
        local.day,
        firstWindow.startHour,
        firstWindow.startMinute,
      );
      return ActiveMealWindow._fromConfigs(
        activeConfig: activeConfig,
        nextConfig: firstWindow,
        windowDate: formatDate(yesterday),
        nextTransitionTime: nextTransition,
      );
    }

    // Intra-day: find the latest enabled window whose start time <= nowMinutes.
    var activeIndex = 0;
    for (var i = 0; i < enabled.length; i++) {
      if (nowMinutes >= enabled[i].startMinutesOfDay) {
        activeIndex = i;
      } else {
        break;
      }
    }

    final activeConfig = enabled[activeIndex];
    final windowDate = formatDate(local);

    if (activeIndex + 1 < enabled.length) {
      final nextConfig = enabled[activeIndex + 1];
      final nextTransition = DateTime(
        local.year,
        local.month,
        local.day,
        nextConfig.startHour,
        nextConfig.startMinute,
      );
      return ActiveMealWindow._fromConfigs(
        activeConfig: activeConfig,
        nextConfig: nextConfig,
        windowDate: windowDate,
        nextTransitionTime: nextTransition,
      );
    }

    // Final window of today wraps to tomorrow's first morning window.
    final tomorrow = DateTime(local.year, local.month, local.day + 1);
    final nextTransition = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      firstWindow.startHour,
      firstWindow.startMinute,
    );
    return ActiveMealWindow._fromConfigs(
      activeConfig: activeConfig,
      nextConfig: firstWindow,
      windowDate: windowDate,
      nextTransitionTime: nextTransition,
    );
  }

  factory ActiveMealWindow._fromConfigs({
    required MealWindowConfig activeConfig,
    required MealWindowConfig nextConfig,
    required String windowDate,
    required DateTime nextTransitionTime,
  }) {
    return ActiveMealWindow(
      period: activeConfig.period,
      windowId: activeConfig.id,
      label: activeConfig.label,
      emoji: activeConfig.emoji,
      windowDate: windowDate,
      nextTransitionTime: nextTransitionTime,
      nextWindowLabel: nextConfig.label,
      nextWindowEmoji: nextConfig.emoji,
    );
  }

  /// Formats [date] as `YYYY-MM-DD` in local calendar components.
  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveMealWindow &&
          period == other.period &&
          windowId == other.windowId &&
          label == other.label &&
          emoji == other.emoji &&
          windowDate == other.windowDate &&
          nextTransitionTime == other.nextTransitionTime;

  @override
  int get hashCode => Object.hash(
        period,
        windowId,
        label,
        emoji,
        windowDate,
        nextTransitionTime,
      );
}
