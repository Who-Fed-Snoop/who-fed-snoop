import 'package:cloud_firestore/cloud_firestore.dart';
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
    this.windowId,
    this.windowLabel,
    this.windowEmoji,
  });

  /// Deterministic ID (`YYYY-MM-DD_windowId`) for regular meals, or a unique
  /// sequence-suffixed ID when logging an explicit bonus scoop (`isExtraMeal: true`).
  final String id;
  final MealPeriod mealPeriod;
  final String windowDate;
  final String fedByUid;
  final String fedByName;
  final DateTime fedAt;
  final bool isExtraMeal;

  /// Optional custom/explicit meal window ID (defaults to `mealPeriod.name`).
  final String? windowId;

  /// Optional human-readable window label at log time (defaults to `mealPeriod.label`).
  final String? windowLabel;

  /// Optional window emoji at log time (defaults to `mealPeriod.emoji`).
  final String? windowEmoji;

  /// Resolved window identifier (`windowId ?? mealPeriod.name`).
  String get effectiveWindowId =>
      (windowId != null && windowId!.isNotEmpty) ? windowId! : mealPeriod.name;

  /// Resolved human-readable label (`windowLabel ?? mealPeriod.label`).
  String get effectiveLabel =>
      (windowLabel != null && windowLabel!.isNotEmpty)
          ? windowLabel!
          : mealPeriod.label;

  /// Resolved display emoji (`windowEmoji ?? mealPeriod.emoji`).
  String get effectiveEmoji =>
      (windowEmoji != null && windowEmoji!.isNotEmpty)
          ? windowEmoji!
          : mealPeriod.emoji;

  /// Matches whether this feeding satisfies the given [window].
  ///
  /// Bonus scoops (`isExtraMeal == true`) never satisfy a regular meal window.
  bool matchesWindow(ActiveMealWindow window) {
    if (isExtraMeal) return false;
    return windowDate == window.windowDate &&
        effectiveWindowId == window.windowId;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'mealPeriod': mealPeriod.name,
        'windowDate': windowDate,
        'fedByUid': fedByUid,
        'fedByName': fedByName,
        'fedAt': fedAt.toUtc().toIso8601String(),
        'isExtraMeal': isExtraMeal,
        if (windowId != null) 'windowId': windowId,
        if (windowLabel != null) 'windowLabel': windowLabel,
        if (windowEmoji != null) 'windowEmoji': windowEmoji,
      };

  factory FeedingEvent.fromJson(Map<String, Object?> json, {String? fallbackId}) {
    final parsedFedAt = _parseDateTime(json['fedAt']);
    final rawWindowId = (json['windowId'] as String?)?.trim();
    final rawWindowLabel = (json['windowLabel'] as String?)?.trim();
    final rawWindowEmoji = (json['windowEmoji'] as String?)?.trim();

    return FeedingEvent(
      id: (json['id'] as String?) ?? fallbackId ?? '',
      mealPeriod: MealPeriod.fromString(
        (json['mealPeriod'] as String?) ?? 'breakfast',
      ),
      windowDate: (json['windowDate'] as String?) ?? '',
      fedByUid: (json['fedByUid'] as String?) ?? '',
      fedByName: (json['fedByName'] as String?) ?? 'Someone',
      fedAt: parsedFedAt,
      isExtraMeal: (json['isExtraMeal'] as bool?) ?? false,
      windowId: (rawWindowId != null && rawWindowId.isNotEmpty)
          ? rawWindowId
          : null,
      windowLabel: (rawWindowLabel != null && rawWindowLabel.isNotEmpty)
          ? rawWindowLabel
          : null,
      windowEmoji: (rawWindowEmoji != null && rawWindowEmoji.isNotEmpty)
          ? rawWindowEmoji
          : null,
    );
  }

  static DateTime _parseDateTime(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate().toLocal();
    }
    if (raw is DateTime) {
      return raw.toLocal();
    }
    if (raw is String) {
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
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
          isExtraMeal == other.isExtraMeal &&
          windowId == other.windowId &&
          windowLabel == other.windowLabel &&
          windowEmoji == other.windowEmoji;

  @override
  int get hashCode => Object.hash(
        id,
        mealPeriod,
        windowDate,
        fedByUid,
        fedByName,
        fedAt,
        isExtraMeal,
        windowId,
        windowLabel,
        windowEmoji,
      );
}
