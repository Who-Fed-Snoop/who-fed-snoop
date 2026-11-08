import 'package:flutter/foundation.dart';

import 'feeding_event.dart';
import 'meal_window.dart';

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
    return HouseholdMember(
      uid: uid,
      name: (json['name'] as String?) ?? 'Member',
      fcmToken: json['fcmToken'] as String?,
      joinedAt: rawJoinedAt is String
          ? DateTime.parse(rawJoinedAt).toLocal()
          : DateTime.now(),
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

  /// Returns the [FeedingEvent] if the pet has already been fed during [window].
  FeedingEvent? feedingForWindow(ActiveMealWindow window) {
    final latest = lastFeeding;
    if (latest != null && latest.matchesWindow(window)) {
      return latest;
    }
    return null;
  }

  /// True when a meal has already been logged for [window].
  bool isFedForWindow(ActiveMealWindow window) => feedingForWindow(window) != null;

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
      };
}

