import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'feeding_event.dart';
import 'meal_window.dart';
import 'treat_event.dart';

/// Represents a human member in the household (e.g., Keni or Ashley).
@immutable
class HouseholdMember {
  const HouseholdMember({
    required this.uid,
    required this.name,
    required this.joinedAt,
    this.fcmToken,
  });

  final String uid;
  final String name;
  final DateTime joinedAt;
  final String? fcmToken;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'fcmToken': fcmToken,
        'joinedAt': joinedAt.toUtc().toIso8601String(),
      };

  factory HouseholdMember.fromJson(String uid, Map<String, Object?> json) {
    final rawJoinedAt = json['joinedAt'];
    DateTime joinedAt;
    if (rawJoinedAt is Timestamp) {
      joinedAt = rawJoinedAt.toDate().toLocal();
    } else if (rawJoinedAt is DateTime) {
      joinedAt = rawJoinedAt.toLocal();
    } else if (rawJoinedAt is String) {
      joinedAt = DateTime.tryParse(rawJoinedAt)?.toLocal() ?? DateTime.now();
    } else {
      joinedAt = DateTime.now();
    }

    return HouseholdMember(
      uid: uid,
      name: (json['name'] as String?) ?? 'Member',
      fcmToken: json['fcmToken'] as String?,
      joinedAt: joinedAt,
    );
  }
}

/// Aggregate root for a pet household (e.g. Keni, Ashley & Snoop).
@immutable
class Household {
  const Household({
    required this.id,
    required this.joinCode,
    required this.petName,
    required this.createdAt,
    required this.members,
    this.isPro = false,
    this.schedule = const MealSchedule(),
    this.lastFeeding,
    this.dailyTreatLimit = 4,
    this.todayMeals = const <String, FeedingEvent>{},
    this.todayTreats = const <TreatEvent>[],
  });

  final String id;

  /// 6-character uppercase code used by a partner to join the household in seconds.
  final String joinCode;

  /// Defaults to "Snoop", customizable for any household pet.
  final String petName;

  final bool isPro;
  final DateTime createdAt;
  final MealSchedule schedule;
  final Map<String, HouseholdMember> members;
  final FeedingEvent? lastFeeding;

  /// Daily household treat allowance before showing a soft warning badge (default `4`).
  final int dailyTreatLimit;

  /// Bounded map of recent regular meals keyed by `deterministicId` (`YYYY-MM-DD_windowId`),
  /// pruned to the last 48 hours so multi-window schedules and window edits stay accurate
  /// within the single-document `households/{id}` stream.
  final Map<String, FeedingEvent> todayMeals;

  /// Bounded list of treats for the active logical day (pruned to <= 50 entries),
  /// orthogonal to `lastFeeding` and `todayMeals`.
  final List<TreatEvent> todayTreats;

  /// Returns the [FeedingEvent] if the pet has already been fed during [window].
  ///
  /// Checks `todayMeals[window.deterministicId]` first so multi-window schedules
  /// and schedule edits never lose an earlier window's fed status, then falls back
  /// to [lastFeeding] for backward compatibility.
  FeedingEvent? feedingForWindow(ActiveMealWindow window) {
    final fromMap = todayMeals[window.deterministicId];
    if (fromMap != null && fromMap.matchesWindow(window)) {
      return fromMap;
    }
    final latest = lastFeeding;
    if (latest != null && latest.matchesWindow(window)) {
      return latest;
    }
    return null;
  }

  /// True when a regular meal has already been logged for [window].
  bool isFedForWindow(ActiveMealWindow window) => feedingForWindow(window) != null;

  /// Set of `windowId`s that already have a regular meal logged on [windowDate].
  Set<String> fedWindowIdsForDate(String windowDate) {
    final result = <String>{};
    for (final meal in todayMeals.values) {
      if (!meal.isExtraMeal && meal.windowDate == windowDate) {
        result.add(meal.effectiveWindowId);
      }
    }
    final latest = lastFeeding;
    if (latest != null && !latest.isExtraMeal && latest.windowDate == windowDate) {
      result.add(latest.effectiveWindowId);
    }
    return result;
  }

  /// Returns treats logged on [logicalDate], sorted newest-first.
  List<TreatEvent> treatsForDate(String logicalDate) {
    final filtered = todayTreats.where((t) => t.logicalDate == logicalDate).toList();
    filtered.sort((a, b) => b.givenAt.compareTo(a.givenAt));
    return List<TreatEvent>.unmodifiable(filtered);
  }

  /// Total treat unit count (`sum(quantity)`) for [logicalDate].
  int treatCountForDate(String logicalDate) {
    return treatsForDate(logicalDate).fold<int>(
      0,
      (total, treat) => total + treat.quantity,
    );
  }

  /// Total estimated treat calories (`sum(totalCalories)`) for [logicalDate].
  int treatCaloriesForDate(String logicalDate) {
    return treatsForDate(logicalDate).fold<int>(
      0,
      (total, treat) => total + treat.totalCalories,
    );
  }

  /// True when total treat units on [logicalDate] strictly exceed [dailyTreatLimit].
  bool isOverTreatLimit(String logicalDate) {
    return treatCountForDate(logicalDate) > dailyTreatLimit;
  }

  Household copyWith({
    String? id,
    String? joinCode,
    String? petName,
    bool? isPro,
    DateTime? createdAt,
    MealSchedule? schedule,
    Map<String, HouseholdMember>? members,
    FeedingEvent? lastFeeding,
    bool clearLastFeeding = false,
    int? dailyTreatLimit,
    Map<String, FeedingEvent>? todayMeals,
    List<TreatEvent>? todayTreats,
  }) {
    return Household(
      id: id ?? this.id,
      joinCode: joinCode ?? this.joinCode,
      petName: petName ?? this.petName,
      isPro: isPro ?? this.isPro,
      createdAt: createdAt ?? this.createdAt,
      schedule: schedule ?? this.schedule,
      members: members ?? this.members,
      lastFeeding: clearLastFeeding ? null : (lastFeeding ?? this.lastFeeding),
      dailyTreatLimit: dailyTreatLimit ?? this.dailyTreatLimit,
      todayMeals: todayMeals ?? this.todayMeals,
      todayTreats: todayTreats ?? this.todayTreats,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'joinCode': joinCode,
        'petName': petName,
        'isPro': isPro,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'schedule': schedule.toJson(),
        'members': members.map(
          (uid, member) => MapEntry<String, Object?>(uid, member.toJson()),
        ),
        'lastFeeding': lastFeeding?.toJson(),
        'dailyTreatLimit': dailyTreatLimit,
        'todayMeals': todayMeals.map(
          (key, event) => MapEntry<String, Object?>(key, event.toJson()),
        ),
        'todayTreats': todayTreats.map((t) => t.toJson()).toList(growable: false),
      };
}
