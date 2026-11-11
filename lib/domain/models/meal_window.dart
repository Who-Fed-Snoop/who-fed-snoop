import 'package:flutter/foundation.dart';

/// Represents standard or custom daily meal slots for Snoop (or any household pet).
enum MealPeriod {
  breakfast(label: 'Breakfast', emoji: '🥣', defaultHour: 4, defaultMinute: 0),
  lunch(label: 'Lunch', emoji: '🍲', defaultHour: 12, defaultMinute: 0),
  dinner(label: 'Dinner', emoji: '🍖', defaultHour: 14, defaultMinute: 0),
  lateSnack(label: 'Late Snack', emoji: '🌙', defaultHour: 20, defaultMinute: 30),
  custom(label: 'Meal', emoji: '🐾', defaultHour: 12, defaultMinute: 0);

  const MealPeriod({
    required this.label,
    required this.emoji,
    required this.defaultHour,
    required this.defaultMinute,
  });

  final String label;
  final String emoji;
  final int defaultHour;
  final int defaultMinute;

  static MealPeriod fromString(String value) {
    final normalized = value.trim();
    if (normalized == 'late_snack') {
      return MealPeriod.lateSnack;
    }
    return MealPeriod.values.firstWhere(
      (period) => period.name == normalized,
      orElse: () => MealPeriod.custom,
    );
  }
}

/// Configuration for an individual daily meal window within a [MealSchedule].
@immutable
class MealWindowConfig {
  const MealWindowConfig({
    required this.id,
    required this.period,
    required this.label,
    required this.emoji,
    required this.startHour,
    this.startMinute = 0,
    this.enabled = true,
  });

  /// Stable identifier (e.g. `'breakfast'`, `'lunch'`, `'dinner'`, `'lateSnack'`, `'custom_1'`).
  final String id;

  /// Associated [MealPeriod] slot.
  final MealPeriod period;

  /// Human-readable label shown in UI and notifications (1..24 chars).
  final String label;

  /// Display emoji badge (1..8 chars).
  final String emoji;

  /// Local 24-hour clock hour (`0..23`).
  final int startHour;

  /// Local clock minute (`0..59`).
  final int startMinute;

  /// Whether this window is active in the daily cycle.
  final bool enabled;

  /// Minutes elapsed since local `00:00` (`0..1439`).
  int get startMinutesOfDay => startHour * 60 + startMinute;

  /// Creates a preset [MealWindowConfig] from a standard [MealPeriod].
  factory MealWindowConfig.fromPreset(
    MealPeriod period, {
    int? startHour,
    int? startMinute,
    bool enabled = true,
  }) {
    return MealWindowConfig(
      id: period.name,
      period: period,
      label: period.label,
      emoji: period.emoji,
      startHour: startHour ?? period.defaultHour,
      startMinute: startMinute ?? period.defaultMinute,
      enabled: enabled,
    );
  }

  MealWindowConfig copyWith({
    String? id,
    MealPeriod? period,
    String? label,
    String? emoji,
    int? startHour,
    int? startMinute,
    bool? enabled,
  }) {
    return MealWindowConfig(
      id: id ?? this.id,
      period: period ?? this.period,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id.trim(),
        'period': period.name,
        'label': label.trim(),
        'emoji': emoji.trim(),
        'startHour': startHour,
        'startMinute': startMinute,
        'enabled': enabled,
      };

  factory MealWindowConfig.fromJson(Map<String, Object?> json) {
    final rawPeriod = (json['period'] as String?) ?? (json['id'] as String?) ?? 'breakfast';
    final period = MealPeriod.fromString(rawPeriod);
    final rawId = (json['id'] as String?)?.trim();
    final id = (rawId != null && rawId.isNotEmpty) ? rawId : period.name;
    final rawLabel = (json['label'] as String?)?.trim();
    final label = (rawLabel != null && rawLabel.isNotEmpty) ? rawLabel : period.label;
    final rawEmoji = (json['emoji'] as String?)?.trim();
    final emoji = (rawEmoji != null && rawEmoji.isNotEmpty) ? rawEmoji : period.emoji;

    return MealWindowConfig(
      id: id,
      period: period,
      label: label,
      emoji: emoji,
      startHour: (json['startHour'] as num?)?.toInt() ?? period.defaultHour,
      startMinute: (json['startMinute'] as num?)?.toInt() ?? 0,
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealWindowConfig &&
          id == other.id &&
          period == other.period &&
          label == other.label &&
          emoji == other.emoji &&
          startHour == other.startHour &&
          startMinute == other.startMinute &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
        id,
        period,
        label,
        emoji,
        startHour,
        startMinute,
        enabled,
      );
}

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

    MealWindowConfig? breakfastWin;
    MealWindowConfig? dinnerWin;
    for (final w in normalizedWindows) {
      if (w.period == MealPeriod.breakfast && breakfastWin == null) {
        breakfastWin = w;
      } else if (w.period == MealPeriod.dinner && dinnerWin == null) {
        dinnerWin = w;
      }
    }

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

  /// All configured meal windows (both enabled and disabled), in chronological order.
  List<MealWindowConfig> get allWindows {
    final explicit = _windows;
    if (explicit != null && explicit.isNotEmpty) {
      final copy = List<MealWindowConfig>.of(explicit)
        ..sort((a, b) => a.startMinutesOfDay.compareTo(b.startMinutesOfDay));
      return List<MealWindowConfig>.unmodifiable(copy);
    }

    return List<MealWindowConfig>.unmodifiable(<MealWindowConfig>[
      MealWindowConfig(
        id: MealPeriod.breakfast.name,
        period: MealPeriod.breakfast,
        label: MealPeriod.breakfast.label,
        emoji: MealPeriod.breakfast.emoji,
        startHour: breakfastStartHour,
      ),
      MealWindowConfig(
        id: MealPeriod.dinner.name,
        period: MealPeriod.dinner,
        label: MealPeriod.dinner.label,
        emoji: MealPeriod.dinner.emoji,
        startHour: dinnerStartHour,
      ),
    ]..sort((a, b) => a.startMinutesOfDay.compareTo(b.startMinutesOfDay)));
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
    MealWindowConfig? breakfastWin;
    MealWindowConfig? dinnerWin;
    for (final w in windowsList) {
      if (w.period == MealPeriod.breakfast && breakfastWin == null) {
        breakfastWin = w;
      } else if (w.period == MealPeriod.dinner && dinnerWin == null) {
        dinnerWin = w;
      }
    }

    final safeBreakfast =
        (breakfastWin?.startHour ?? breakfastStartHour).clamp(0, 23);
    final safeDinner =
        (dinnerWin?.startHour ?? dinnerStartHour).clamp(0, 23);

    return <String, Object?>{
      'breakfastStartHour': safeBreakfast,
      'dinnerStartHour': safeDinner,
      'windows': windowsList.map((w) => w.toJson()).toList(growable: false),
    };
  }

  factory MealSchedule.fromJson(Map<String, Object?> json) {
    final bHour = ((json['breakfastStartHour'] as num?)?.toInt() ?? 4).clamp(0, 23);
    final dHour = ((json['dinnerStartHour'] as num?)?.toInt() ?? 14).clamp(0, 23);

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

    return MealSchedule(
      breakfastStartHour: bHour,
      dinnerStartHour: dHour,
    );
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
        nextWindowLabel = nextWindowLabel ??
            (period == MealPeriod.breakfast ? 'Dinner' : 'Breakfast'),
        nextWindowEmoji = nextWindowEmoji ??
            (period == MealPeriod.breakfast ? '🍖' : '🥣');

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
      return ActiveMealWindow(
        period: activeConfig.period,
        windowId: activeConfig.id,
        label: activeConfig.label,
        emoji: activeConfig.emoji,
        windowDate: formatDate(yesterday),
        nextTransitionTime: nextTransition,
        nextWindowLabel: firstWindow.label,
        nextWindowEmoji: firstWindow.emoji,
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
      return ActiveMealWindow(
        period: activeConfig.period,
        windowId: activeConfig.id,
        label: activeConfig.label,
        emoji: activeConfig.emoji,
        windowDate: windowDate,
        nextTransitionTime: nextTransition,
        nextWindowLabel: nextConfig.label,
        nextWindowEmoji: nextConfig.emoji,
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
    return ActiveMealWindow(
      period: activeConfig.period,
      windowId: activeConfig.id,
      label: activeConfig.label,
      emoji: activeConfig.emoji,
      windowDate: windowDate,
      nextTransitionTime: nextTransition,
      nextWindowLabel: firstWindow.label,
      nextWindowEmoji: firstWindow.emoji,
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
