import 'package:flutter/foundation.dart';

/// Represents the two daily meal windows for Snoop.
enum MealPeriod {
  breakfast(label: 'Breakfast', emoji: '🥣'),
  dinner(label: 'Dinner', emoji: '🍖');

  const MealPeriod({required this.label, required this.emoji});

  final String label;
  final String emoji;

  static MealPeriod fromString(String value) {
    return MealPeriod.values.firstWhere(
      (period) => period.name == value,
      orElse: () => MealPeriod.breakfast,
    );
  }
}

/// Configurable daily cutoff hours (in 24-hour local time) for Breakfast and Dinner.
@immutable
class MealSchedule {
  const MealSchedule({
    this.breakfastStartHour = 4,
    this.dinnerStartHour = 14,
  }) : assert(
          breakfastStartHour >= 0 &&
              breakfastStartHour < dinnerStartHour &&
              dinnerStartHour <= 23,
          'breakfastStartHour must be earlier than dinnerStartHour (0..23)',
        );

  /// Default: 4:00 AM local time transitions to Breakfast.
  final int breakfastStartHour;

  /// Default: 2:00 PM (14:00) local time transitions to Dinner.
  final int dinnerStartHour;

  Map<String, Object?> toJson() => <String, Object?>{
        'breakfastStartHour': breakfastStartHour,
        'dinnerStartHour': dinnerStartHour,
      };

  factory MealSchedule.fromJson(Map<String, Object?> json) {
    return MealSchedule(
      breakfastStartHour: (json['breakfastStartHour'] as num?)?.toInt() ?? 4,
      dinnerStartHour: (json['dinnerStartHour'] as num?)?.toInt() ?? 14,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealSchedule &&
          breakfastStartHour == other.breakfastStartHour &&
          dinnerStartHour == other.dinnerStartHour;

  @override
  int get hashCode => Object.hash(breakfastStartHour, dinnerStartHour);
}

/// Snapshot of the currently active meal window for a given point in time.
@immutable
class ActiveMealWindow {
  const ActiveMealWindow({
    required this.period,
    required this.windowDate,
    required this.nextTransitionTime,
  });

  final MealPeriod period;

  /// Local calendar date string (`YYYY-MM-DD`) that owns this meal window.
  ///
  /// Note: Between midnight (`00:00`) and `breakfastStartHour` (`03:59`),
  /// the active window is still the previous evening's Dinner window so late-night
  /// checks or feedings attach to the right day.
  final String windowDate;

  /// When this window automatically resets to the next meal window.
  final DateTime nextTransitionTime;

  /// Deterministic document ID (`{windowDate}_{period}`) used in Firestore
  /// to prevent duplicate logs if Keni and Ashley tap at the exact same second.
  String get deterministicId => '${windowDate}_${period.name}';

  /// Calculates the active meal window for [now] using [schedule].
  factory ActiveMealWindow.forTime(
    DateTime now, {
    MealSchedule schedule = const MealSchedule(),
  }) {
    final local = now.toLocal();
    final hour = local.hour;

    if (hour >= schedule.breakfastStartHour && hour < schedule.dinnerStartHour) {
      // Morning / midday -> Breakfast window for today.
      final windowDate = _formatDate(local);
      final nextTransition = DateTime(
        local.year,
        local.month,
        local.day,
        schedule.dinnerStartHour,
      );
      return ActiveMealWindow(
        period: MealPeriod.breakfast,
        windowDate: windowDate,
        nextTransitionTime: nextTransition,
      );
    }

    if (hour >= schedule.dinnerStartHour) {
      // Afternoon / evening -> Dinner window for today, resets tomorrow at breakfastStartHour.
      final windowDate = _formatDate(local);
      final tomorrow = DateTime(local.year, local.month, local.day + 1);
      final nextTransition = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        schedule.breakfastStartHour,
      );
      return ActiveMealWindow(
        period: MealPeriod.dinner,
        windowDate: windowDate,
        nextTransitionTime: nextTransition,
      );
    }

    // After midnight but before breakfastStartHour (00:00..03:59) ->
    // Still belongs to yesterday's Dinner window!
    final yesterday = DateTime(local.year, local.month, local.day - 1);
    final windowDate = _formatDate(yesterday);
    final nextTransition = DateTime(
      local.year,
      local.month,
      local.day,
      schedule.breakfastStartHour,
    );
    return ActiveMealWindow(
      period: MealPeriod.dinner,
      windowDate: windowDate,
      nextTransitionTime: nextTransition,
    );
  }

  static String _formatDate(DateTime date) {
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
          windowDate == other.windowDate &&
          nextTransitionTime == other.nextTransitionTime;

  @override
  int get hashCode => Object.hash(period, windowDate, nextTransitionTime);
}

