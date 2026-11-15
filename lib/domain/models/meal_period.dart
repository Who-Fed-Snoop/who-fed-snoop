import 'package:flutter/foundation.dart';

/// Represents standard or custom daily meal slots for Snoop (or any household pet).
enum MealPeriod {
  breakfast(label: 'Breakfast', emoji: '🥣', defaultHour: 4, defaultMinute: 0),
  lunch(label: 'Lunch', emoji: '🍲', defaultHour: 12, defaultMinute: 0),
  dinner(label: 'Dinner', emoji: '🍖', defaultHour: 14, defaultMinute: 0),
  lateSnack(
    label: 'Late Snack',
    emoji: '🌙',
    defaultHour: 20,
    defaultMinute: 30,
  ),
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
  int get hashCode => Object.hash(id, period, label, emoji, startHour, startMinute, enabled);
}
