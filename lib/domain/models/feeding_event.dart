import 'package:flutter/foundation.dart';

import 'meal_window.dart';

/// A single logged feeding event for Snoop (or any household pet).
@immutable
class FeedingEvent {
  const FeedingEvent({
    required this.id,
    required this.mealPeriod,
    required this.windowDate,
    required this.fedByUid,
    required this.fedByName,
    required this.fedAt,
    this.isExtraMeal = false,
  });

  /// Deterministic ID (`YYYY-MM-DD_breakfast`) for regular meals, or a unique
  /// timestamped ID when logging an explicit extra meal/treat override.
  final String id;
  final MealPeriod mealPeriod;
  final String windowDate;
  final String fedByUid;
  final String fedByName;
  final DateTime fedAt;
  final bool isExtraMeal;

  /// Matches whether this feeding satisfies the given [window].
  bool matchesWindow(ActiveMealWindow window) {
    return windowDate == window.windowDate && mealPeriod == window.period;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'mealPeriod': mealPeriod.name,
        'windowDate': windowDate,
        'fedByUid': fedByUid,
        'fedByName': fedByName,
        'fedAt': fedAt.toUtc().toIso8601String(),
        'isExtraMeal': isExtraMeal,
      };

  factory FeedingEvent.fromJson(Map<String, Object?> json) {
    final rawFedAt = json['fedAt'];
    final parsedFedAt = rawFedAt is String
        ? DateTime.parse(rawFedAt).toLocal()
        : DateTime.now();

    return FeedingEvent(
      id: (json['id'] as String?) ?? '',
      mealPeriod: MealPeriod.fromString((json['mealPeriod'] as String?) ?? 'breakfast'),
      windowDate: (json['windowDate'] as String?) ?? '',
      fedByUid: (json['fedByUid'] as String?) ?? '',
      fedByName: (json['fedByName'] as String?) ?? 'Someone',
      fedAt: parsedFedAt,
      isExtraMeal: (json['isExtraMeal'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedingEvent &&
          id == other.id &&
          mealPeriod == other.mealPeriod &&
          windowDate == other.windowDate &&
          fedByUid == other.fedByUid &&
          fedByName == other.fedByName &&
          fedAt == other.fedAt &&
          isExtraMeal == other.isExtraMeal;

  @override
  int get hashCode => Object.hash(
        id,
        mealPeriod,
        windowDate,
        fedByUid,
        fedByName,
        fedAt,
        isExtraMeal,
      );
}

