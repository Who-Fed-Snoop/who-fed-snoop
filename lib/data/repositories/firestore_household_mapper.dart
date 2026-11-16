import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/feeding_event.dart';
import '../../domain/models/household.dart';
import '../../domain/models/meal_schedule.dart';
import '../../domain/models/treat_event.dart';
import 'household_state_policy.dart';

/// Pure Cloud Firestore document/map serialization helpers for [Household],
/// [HouseholdMember], [FeedingEvent], and [TreatEvent].
abstract final class FirestoreHouseholdMapper {
  static Map<String, Object?> memberToFirestoreMap(HouseholdMember member) {
    return <String, Object?>{
      'name': member.name,
      'fcmToken': member.fcmToken,
      'joinedAt': Timestamp.fromDate(member.joinedAt),
    };
  }

  static Map<String, Object?> newHouseholdPayload({
    required String joinCode,
    required String petName,
    required DateTime createdAt,
    required MealSchedule schedule,
    required HouseholdMember creator,
    bool isPro = false,
    int dailyTreatLimit = HouseholdStatePolicy.defaultDailyTreatLimit,
  }) {
    return <String, Object?>{
      'joinCode': joinCode,
      'petName': petName,
      'isPro': isPro, // Required by firestore.rules on client creation
      'createdAt': Timestamp.fromDate(createdAt),
      'schedule': schedule.toJson(),
      'members': <String, Object?>{creator.uid: memberToFirestoreMap(creator)},
      'lastFeeding': null,
      'dailyTreatLimit': dailyTreatLimit,
      'todayMeals': <String, Object?>{},
      'todayTreats': <Object?>[],
    };
  }

  static Map<String, Object?> feedingToFirestoreMap(FeedingEvent event) {
    final trimmedId = event.id.trim();
    final trimmedWindowId = event.effectiveWindowId.trim();
    final trimmedWindowLabel = event.effectiveLabel.trim();
    final trimmedWindowEmoji = event.effectiveEmoji.trim();
    return <String, Object?>{
      if (trimmedId.isNotEmpty) 'id': trimmedId,
      'mealPeriod': event.mealPeriod.name,
      if (trimmedWindowId.isNotEmpty) 'windowId': trimmedWindowId,
      if (trimmedWindowLabel.isNotEmpty) 'windowLabel': trimmedWindowLabel,
      if (trimmedWindowEmoji.isNotEmpty) 'windowEmoji': trimmedWindowEmoji,
      'windowDate': event.windowDate,
      'fedByUid': event.fedByUid,
      'fedByName': event.fedByName,
      'fedAt': Timestamp.fromDate(event.fedAt),
      'isExtraMeal': event.isExtraMeal,
    };
  }

  static Map<String, Object?> todayMealsToFirestoreMap(
    Map<String, FeedingEvent> todayMeals,
  ) {
    return todayMeals.map(
      (key, event) => MapEntry<String, Object?>(key, feedingToFirestoreMap(event)),
    );
  }

  static Map<String, Object?> treatToFirestoreMap(TreatEvent treat) {
    final trimmedId = treat.id.trim();
    final trimmedNote = treat.note?.trim();
    return <String, Object?>{
      if (trimmedId.isNotEmpty) 'id': trimmedId,
      'preset': treat.preset.id,
      'label': treat.label,
      'emoji': treat.emoji,
      'quantity': treat.quantity,
      'caloriesPerUnit': treat.caloriesPerUnit,
      'logicalDate': treat.logicalDate,
      'givenByUid': treat.givenByUid,
      'givenByName': treat.givenByName,
      'givenAt': Timestamp.fromDate(treat.givenAt),
      if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
    };
  }

  static FeedingEvent feedingFromFirestore(
    String id,
    Map<String, Object?> data,
  ) {
    return FeedingEvent.fromJson(data, fallbackId: id);
  }

  static Household householdFromFirestore(
    String id,
    Map<String, Object?> data,
  ) {
    final rawSchedule = data['schedule'];
    final schedule = rawSchedule is Map<String, Object?>
        ? MealSchedule.fromJson(rawSchedule)
        : rawSchedule is Map
            ? MealSchedule.fromJson(Map<String, Object?>.from(rawSchedule))
            : const MealSchedule();

    final membersMap = <String, HouseholdMember>{};
    final rawMembers = data['members'];
    if (rawMembers is Map) {
      for (final entry in rawMembers.entries) {
        final key = entry.key;
        final val = entry.value;
        if (key is String && val is Map) {
          membersMap[key] = HouseholdMember.fromJson(
            key,
            Map<String, Object?>.from(val),
          );
        }
      }
    }

    FeedingEvent? lastFeeding;
    final rawLast = data['lastFeeding'];
    if (rawLast is Map) {
      final castLast = Map<String, Object?>.from(rawLast);
      lastFeeding = feedingFromFirestore(
        (castLast['id'] as String?) ?? '',
        castLast,
      );
    }

    final todayMealsMap = <String, FeedingEvent>{};
    final rawTodayMeals = data['todayMeals'];
    if (rawTodayMeals is Map) {
      for (final entry in rawTodayMeals.entries) {
        final key = entry.key;
        final val = entry.value;
        if (key is String && val is Map) {
          todayMealsMap[key] = feedingFromFirestore(
            key,
            Map<String, Object?>.from(val),
          );
        }
      }
    }

    final todayTreatsList = <TreatEvent>[];
    final rawTodayTreats = data['todayTreats'];
    if (rawTodayTreats is List) {
      for (final item in rawTodayTreats) {
        if (item is Map) {
          todayTreatsList.add(
            TreatEvent.fromJson(Map<String, Object?>.from(item)),
          );
        }
      }
    }

    final dailyTreatLimit =
        ((data['dailyTreatLimit'] as num?)?.toInt() ?? HouseholdStatePolicy.defaultDailyTreatLimit)
            .clamp(1, 50);

    return Household(
      id: id,
      joinCode: (data['joinCode'] as String?) ?? HouseholdStatePolicy.defaultJoinCode,
      petName: (data['petName'] as String?) ?? HouseholdStatePolicy.defaultPetName,
      isPro: (data['isPro'] as bool?) ?? false,
      createdAt: parseTimestamp(data['createdAt']),
      schedule: schedule,
      members: membersMap,
      lastFeeding: lastFeeding,
      dailyTreatLimit: dailyTreatLimit,
      todayMeals: Map<String, FeedingEvent>.unmodifiable(todayMealsMap),
      todayTreats: List<TreatEvent>.unmodifiable(todayTreatsList),
    );
  }

  static DateTime parseTimestamp(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }
}
