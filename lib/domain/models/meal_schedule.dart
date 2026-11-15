import 'package:flutter/foundation.dart';

import 'active_meal_window.dart';
import 'meal_period.dart';

/// Configurable daily feeding schedule for a household.
///
/// Defaults to 4:00 AM Breakfast and 2:00 PM (14:00) Dinner while supporting
/// 1..6 customizable meal windows with minute-level precision.
@immutable
class MealSchedule {
  const MealSchedule({
    this.breakfastStartHour = 4,
    this.dinnerStartHour = 14,
    List<MealWindowConfig>? windows,
  }) : _windows = windows;

  /// Legacy / default Breakfast cutoff hour (`0..23`), default `4` (4:00 AM).
  final int breakfastStartHour;

  /// Legacy / default Dinner cutoff hour (`0..23`), default `14` (2:00 PM).
  final int dinnerStartHour;

  final List<MealWindowConfig>? _windows;

  static final RegExp _validIdPattern = RegExp(r'^[a-zA-Z0-9_]{1,32}$');
  static const int minWindowGapMinutes = 15;
  static const int maxWindowCount = 6;

  /// Builds a [MealSchedule] from an explicit list of [MealWindowConfig] entries,
  /// deriving backward-compatible `breakfastStartHour` and `dinnerStartHour` values.
  factory MealSchedule.fromWindows(List<MealWindowConfig> windows) {
    final normalizedWindows = windows
        .map(
          (w) => w.copyWith(
            id: w.id.trim(),
            label: w.label.trim(),
            emoji: w.emoji.trim(),
          ),
        )
        .toList(growable: false);

    final sortedEnabled = normalizedWindows.where((w) => w.enabled).toList()
      ..sort((a, b) => a.startMinutesOfDay.compareTo(b.startMinutesOfDay));

    final (:breakfastWin, :dinnerWin) = _findPrimaryMealWindows(
      normalizedWindows,
    );

    final derivedBreakfastHour =
        (breakfastWin?.startHour ?? (sortedEnabled.isNotEmpty ? sortedEnabled.first.startHour : 4))
            .clamp(0, 23);
    final derivedDinnerHour =
        (dinnerWin?.startHour ?? (sortedEnabled.length > 1 ? sortedEnabled.last.startHour : 14))
            .clamp(0, 23);

    return MealSchedule(
      breakfastStartHour: derivedBreakfastHour,
      dinnerStartHour: derivedDinnerHour,
      windows: List<MealWindowConfig>.unmodifiable(normalizedWindows),
    );
  }

  static ({MealWindowConfig? breakfastWin, MealWindowConfig? dinnerWin}) _findPrimaryMealWindows(
      List<MealWindowConfig> windows) {
    MealWindowConfig? breakfastWin;
    MealWindowConfig? dinnerWin;
    for (final w in windows) {
      if (w.period == MealPeriod.breakfast && breakfastWin == null) {
        breakfastWin = w;
      } else if (w.period == MealPeriod.dinner && dinnerWin == null) {
        dinnerWin = w;
      }
    }
    return (breakfastWin: breakfastWin, dinnerWin: dinnerWin);
  }

  /// All configured meal windows (both enabled and disabled), in chronological order.
  List<MealWindowConfig> get allWindows {
    final explicit = _windows;
    if (explicit != null && explicit.isNotEmpty) {
      final copy = List<MealWindowConfig>.of(explicit)
        ..sort((a, b) => a.startMinutesOfDay.compareTo(b.startMinutesOfDay));
      return List<MealWindowConfig>.unmodifiable(copy);
    }

    return List<MealWindowConfig>.unmodifiable(
      <MealWindowConfig>[
        MealWindowConfig.fromPreset(
          MealPeriod.breakfast,
          startHour: breakfastStartHour,
        ),
        MealWindowConfig.fromPreset(
          MealPeriod.dinner,
          startHour: dinnerStartHour,
        ),
      ]..sort((a, b) => a.startMinutesOfDay.compareTo(b.startMinutesOfDay)),
    );
  }

  /// Enabled meal windows sorted ascending by `startMinutesOfDay`, sanitized so
  /// runtime schedule resolution never crashes even on malformed external JSON.
  List<MealWindowConfig> get enabledWindows {
    final candidates = allWindows.where((w) => w.enabled).map((w) {
      final safeHour = w.startHour.clamp(0, 23);
      final safeMinute = w.startMinute.clamp(0, 59);
      final cleanId = w.id.trim().isEmpty ? w.period.name : w.id.trim();
      final cleanLabel = w.label.trim().isEmpty ? w.period.label : w.label.trim();
      final cleanEmoji = w.emoji.trim().isEmpty ? w.period.emoji : w.emoji.trim();
      if (safeHour == w.startHour &&
          safeMinute == w.startMinute &&
          cleanId == w.id &&
          cleanLabel == w.label &&
          cleanEmoji == w.emoji) {
        return w;
      }
      return w.copyWith(
        id: cleanId,
        label: cleanLabel,
        emoji: cleanEmoji,
        startHour: safeHour,
        startMinute: safeMinute,
      );
    }).toList()
      ..sort((a, b) => a.startMinutesOfDay.compareTo(b.startMinutesOfDay));

    // Deduplicate identical start minutes if malformed external JSON was loaded.
    final deduped = <MealWindowConfig>[];
    for (final win in candidates) {
      if (deduped.isEmpty || deduped.last.startMinutesOfDay != win.startMinutesOfDay) {
        deduped.add(win);
      }
    }

    if (deduped.isEmpty) {
      return const <MealWindowConfig>[
        MealWindowConfig(
          id: 'breakfast',
          period: MealPeriod.breakfast,
          label: 'Breakfast',
          emoji: '🥣',
          startHour: 4,
        ),
        MealWindowConfig(
          id: 'dinner',
          period: MealPeriod.dinner,
          label: 'Dinner',
          emoji: '🍖',
          startHour: 14,
        ),
      ];
    }

    return List<MealWindowConfig>.unmodifiable(deduped);
  }

  /// Validates this schedule for saving in Household Settings.
  /// Returns `null` when valid, or a human-readable error message otherwise.
  String? validate() {
    final rawWindows = _windows;
    if (rawWindows != null) {
      if (rawWindows.isEmpty) {
        return 'Schedule must define at least 1 meal window.';
      }
      if (rawWindows.length > maxWindowCount) {
        return 'Maximum $maxWindowCount meal windows allowed.';
      }
    } else {
      if (breakfastStartHour < 0 || breakfastStartHour > 23) {
        return 'Breakfast start hour must be between 0 and 23.';
      }
      if (dinnerStartHour < 0 || dinnerStartHour > 23) {
        return 'Dinner start hour must be between 0 and 23.';
      }
      if (breakfastStartHour >= dinnerStartHour) {
        return 'Breakfast start time must be earlier than Dinner start time.';
      }
    }

    final listToCheck = rawWindows ?? allWindows;
    final seenIds = <String>{};
    final enabled = <MealWindowConfig>[];

    for (final w in listToCheck) {
      final cleanId = w.id.trim();
      if (!_validIdPattern.hasMatch(cleanId)) {
        return 'Window ID "$cleanId" must be 1..32 alphanumeric/underscore characters.';
      }
      if (!seenIds.add(cleanId)) {
        return 'Duplicate meal window ID "$cleanId".';
      }

      final cleanLabel = w.label.trim();
      if (cleanLabel.isEmpty || cleanLabel.length > 24) {
        return 'Meal window label must be 1..24 characters.';
      }

      final cleanEmoji = w.emoji.trim();
      if (cleanEmoji.isEmpty || cleanEmoji.length > 8) {
        return 'Meal window emoji must be 1..8 characters.';
      }

      if (w.startHour < 0 || w.startHour > 23) {
        return 'Start hour for "${w.label}" must be between 0 and 23.';
      }
      if (w.startMinute < 0 || w.startMinute > 59) {
        return 'Start minute for "${w.label}" must be between 0 and 59.';
      }

      if (w.enabled) {
        enabled.add(w);
      }
    }

    if (enabled.isEmpty) {
      return 'At least 1 meal window must stay enabled.';
    }

    enabled.sort((a, b) => a.startMinutesOfDay.compareTo(b.startMinutesOfDay));
    for (var i = 0; i < enabled.length - 1; i++) {
      final gap = enabled[i + 1].startMinutesOfDay - enabled[i].startMinutesOfDay;
      if (gap < minWindowGapMinutes) {
        return 'Enabled meal windows must be at least $minWindowGapMinutes minutes apart.';
      }
    }

    if (enabled.length >= 2) {
      final wrapGap = (1440 - enabled.last.startMinutesOfDay) + enabled.first.startMinutesOfDay;
      if (wrapGap < minWindowGapMinutes) {
        return 'Enabled meal windows must be at least $minWindowGapMinutes minutes apart across midnight.';
      }
    }

    return null;
  }

  /// Returns the household's logical calendar date (`YYYY-MM-DD`) for [now],
  /// rolling over at the earliest enabled morning window rather than `00:00`.
  String logicalDateFor(DateTime now) {
    return ActiveMealWindow.forTime(now, schedule: this).windowDate;
  }

  Map<String, Object?> toJson() {
    final windowsList = allWindows;
    final (:breakfastWin, :dinnerWin) = _findPrimaryMealWindows(windowsList);

    final safeBreakfast = (breakfastWin?.startHour ?? breakfastStartHour).clamp(
      0,
      23,
    );
    final safeDinner = (dinnerWin?.startHour ?? dinnerStartHour).clamp(0, 23);

    return <String, Object?>{
      'breakfastStartHour': safeBreakfast,
      'dinnerStartHour': safeDinner,
      'windows': windowsList.map((w) => w.toJson()).toList(growable: false),
    };
  }

  factory MealSchedule.fromJson(Map<String, Object?> json) {
    final bHour = ((json['breakfastStartHour'] as num?)?.toInt() ?? 4).clamp(
      0,
      23,
    );
    final dHour = ((json['dinnerStartHour'] as num?)?.toInt() ?? 14).clamp(
      0,
      23,
    );

    final rawWindows = json['windows'];
    if (rawWindows is List && rawWindows.isNotEmpty) {
      final parsedWindows = <MealWindowConfig>[];
      for (final item in rawWindows) {
        if (item is Map<String, Object?>) {
          parsedWindows.add(MealWindowConfig.fromJson(item));
        } else if (item is Map) {
          parsedWindows.add(
            MealWindowConfig.fromJson(Map<String, Object?>.from(item)),
          );
        }
      }
      if (parsedWindows.isNotEmpty) {
        return MealSchedule(
          breakfastStartHour: bHour,
          dinnerStartHour: dHour,
          windows: List<MealWindowConfig>.unmodifiable(parsedWindows),
        );
      }
    }

    return MealSchedule(breakfastStartHour: bHour, dinnerStartHour: dHour);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MealSchedule) return false;
    return listEquals(allWindows, other.allWindows);
  }

  @override
  int get hashCode => Object.hashAll(allWindows);
}
