import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/feeding_event.dart';
import '../../domain/models/household.dart';
import '../../domain/models/meal_window.dart';
import 'household_repository.dart';

/// Production Cloud Firestore implementation of [HouseholdRepository] designed
/// around strict cost guardrails and the deployed `firestore.rules` schema:
/// - Streams only the single `households/{id}` document by default (1 read per change).
/// - Uses atomic [WriteBatch] writes so `feedings/{deterministicId}` and
///   `households/{id}.lastFeeding` stay in sync without Cloud Functions overhead.
class FirestoreHouseholdRepository implements HouseholdRepository {
  FirestoreHouseholdRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, Object?>> get _householdsRef =>
      _firestore.collection('households');

  /// Ensures the default `household_snoop_01` (`joinCode: SNOOP4`) exists in Firestore
  /// and that the authenticated [memberUid] is registered in `members`.
  Future<void> ensureDefaultHousehold({
    required String memberUid,
    required String memberName,
  }) async {
    final docRef = _householdsRef.doc(
      InMemoryHouseholdRepository.defaultHouseholdId,
    );
    final snap = await docRef.get();
    final now = DateTime.now();

    if (!snap.exists || snap.data() == null) {
      await docRef.set(<String, Object?>{
        'joinCode': InMemoryHouseholdRepository.defaultJoinCode,
        'petName': 'Snoop',
        'isPro': false,
        'createdAt': Timestamp.fromDate(now),
        'schedule': const MealSchedule().toJson(),
        'members': <String, Object?>{
          memberUid: <String, Object?>{
            'name': memberName,
            'fcmToken': null,
            'joinedAt': Timestamp.fromDate(now),
          },
        },
        'lastFeeding': null,
      });
      return;
    }

    final data = snap.data()!;
    final members = data['members'];
    if (members is Map<String, Object?> && !members.containsKey(memberUid)) {
      await docRef.update(<String, Object?>{
        'members.$memberUid': <String, Object?>{
          'name': memberName,
          'fcmToken': null,
          'joinedAt': Timestamp.fromDate(now),
        },
      });
    }
  }

  @override
  Stream<Household?> watchHousehold(String householdId) {
    return _householdsRef.doc(householdId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return _householdFromFirestore(snapshot.id, snapshot.data()!);
    });
  }

  @override
  Stream<List<FeedingEvent>> watchRecentFeedings(
    String householdId, {
    int limit = 14,
  }) {
    return _householdsRef
        .doc(householdId)
        .collection('feedings')
        .limit(limit)
        .snapshots()
        .map((query) {
      final events = query.docs.map((doc) => _feedingFromFirestore(doc.id, doc.data())).toList();
      // Client-side sort avoids requiring a custom composite index.
      events.sort((a, b) => b.fedAt.compareTo(a.fedAt));
      return events;
    });
  }

  @override
  Future<Household> createHousehold({
    required String memberUid,
    required String memberName,
    required String petName,
  }) async {
    final now = DateTime.now();
    final cleanPet = petName.trim().isEmpty ? 'Snoop' : petName.trim();
    final cleanMember = memberName.trim().isEmpty ? 'Keni' : memberName.trim();
    final joinCode = _generateJoinCode(cleanPet);

    final docRef = _householdsRef.doc();
    const schedule = MealSchedule();
    final member = HouseholdMember(
      uid: memberUid,
      name: cleanMember,
      joinedAt: now,
    );

    final payload = <String, Object?>{
      'joinCode': joinCode,
      'petName': cleanPet,
      'isPro': false, // Required by firestore.rules on client creation
      'createdAt': Timestamp.fromDate(now),
      'schedule': schedule.toJson(),
      'members': <String, Object?>{
        memberUid: <String, Object?>{
          'name': member.name,
          'fcmToken': member.fcmToken,
          'joinedAt': Timestamp.fromDate(member.joinedAt),
        },
      },
      'lastFeeding': null,
    };

    await docRef.set(payload);

    return Household(
      id: docRef.id,
      joinCode: joinCode,
      petName: cleanPet,
      createdAt: now,
      schedule: schedule,
      members: <String, HouseholdMember>{memberUid: member},
    );
  }

  @override
  Future<Household> joinHouseholdByCode({
    required String joinCode,
    required String memberUid,
    required String memberName,
  }) async {
    final normalizedCode = joinCode.trim().toUpperCase();
    final query = await _householdsRef.where('joinCode', isEqualTo: normalizedCode).limit(1).get();

    if (query.docs.isEmpty) {
      throw StateError('No household found with code "$normalizedCode".');
    }

    final doc = query.docs.first;
    final existing = _householdFromFirestore(doc.id, doc.data());
    final cleanName = memberName.trim().isEmpty ? 'Ashley' : memberName.trim();
    final now = DateTime.now();

    final newMember = HouseholdMember(
      uid: memberUid,
      name: cleanName,
      joinedAt: now,
    );

    // Update only `members.<uid>` to satisfy `isValidMemberJoinUpdate` in firestore.rules.
    await doc.reference.update(<String, Object?>{
      'members.$memberUid': <String, Object?>{
        'name': newMember.name,
        'fcmToken': newMember.fcmToken,
        'joinedAt': Timestamp.fromDate(now),
      },
    });

    final updatedMembers = Map<String, HouseholdMember>.of(existing.members)
      ..[memberUid] = newMember;

    return existing.copyWith(members: updatedMembers);
  }

  @override
  Future<FeedingEvent> logFeeding({
    required String householdId,
    required String fedByUid,
    required String fedByName,
    required DateTime now,
    bool isExtraMeal = false,
  }) async {
    final householdDocRef = _householdsRef.doc(householdId);
    final householdSnap = await householdDocRef.get();
    if (!householdSnap.exists || householdSnap.data() == null) {
      throw StateError('Household $householdId not found.');
    }

    final household = _householdFromFirestore(
      householdSnap.id,
      householdSnap.data()!,
    );
    final window = ActiveMealWindow.forTime(now, schedule: household.schedule);

    if (!isExtraMeal && household.isFedForWindow(window)) {
      return household.feedingForWindow(window)!;
    }

    final eventId = isExtraMeal
        ? '${window.deterministicId}_extra_${now.millisecondsSinceEpoch}'
        : window.deterministicId;

    final newEvent = FeedingEvent(
      id: eventId,
      mealPeriod: window.period,
      windowDate: window.windowDate,
      fedByUid: fedByUid,
      fedByName: fedByName,
      fedAt: now,
      isExtraMeal: isExtraMeal,
    );

    final feedingDocRef = householdDocRef.collection('feedings').doc(eventId);
    final batch = _firestore.batch();

    batch.set(feedingDocRef, <String, Object?>{
      'mealPeriod': newEvent.mealPeriod.name,
      'windowDate': newEvent.windowDate,
      'fedByUid': newEvent.fedByUid,
      'fedByName': newEvent.fedByName,
      'fedAt': Timestamp.fromDate(newEvent.fedAt),
      'isExtraMeal': newEvent.isExtraMeal,
    });

    batch.update(householdDocRef, <String, Object?>{
      'lastFeeding': <String, Object?>{
        'id': newEvent.id,
        'mealPeriod': newEvent.mealPeriod.name,
        'windowDate': newEvent.windowDate,
        'fedByUid': newEvent.fedByUid,
        'fedByName': newEvent.fedByName,
        'fedAt': Timestamp.fromDate(newEvent.fedAt),
      },
    });

    await batch.commit();
    return newEvent;
  }

  @override
  Future<void> undoFeeding({
    required String householdId,
    required String feedingId,
    required String requestingUid,
  }) async {
    final householdDocRef = _householdsRef.doc(householdId);
    final feedingDocRef = householdDocRef.collection('feedings').doc(feedingId);

    final batch = _firestore.batch();
    batch.delete(feedingDocRef);
    batch.update(householdDocRef, <String, Object?>{'lastFeeding': null});
    await batch.commit();
  }

  Household _householdFromFirestore(String id, Map<String, Object?> data) {
    final rawSchedule = data['schedule'];
    final schedule = rawSchedule is Map<String, Object?>
        ? MealSchedule.fromJson(rawSchedule)
        : const MealSchedule();

    final membersMap = <String, HouseholdMember>{};
    final rawMembers = data['members'];
    if (rawMembers is Map<String, Object?>) {
      for (final entry in rawMembers.entries) {
        final val = entry.value;
        if (val is Map<String, Object?>) {
          membersMap[entry.key] = HouseholdMember(
            uid: entry.key,
            name: (val['name'] as String?) ?? 'Member',
            fcmToken: val['fcmToken'] as String?,
            joinedAt: _parseTimestamp(val['joinedAt']),
          );
        }
      }
    }

    FeedingEvent? lastFeeding;
    final rawLast = data['lastFeeding'];
    if (rawLast is Map<String, Object?>) {
      lastFeeding = _feedingFromFirestore(
        (rawLast['id'] as String?) ?? '',
        rawLast,
      );
    }

    return Household(
      id: id,
      joinCode: (data['joinCode'] as String?) ?? 'SNOOP4',
      petName: (data['petName'] as String?) ?? 'Snoop',
      isPro: (data['isPro'] as bool?) ?? false,
      createdAt: _parseTimestamp(data['createdAt']),
      schedule: schedule,
      members: membersMap,
      lastFeeding: lastFeeding,
    );
  }

  FeedingEvent _feedingFromFirestore(String id, Map<String, Object?> data) {
    return FeedingEvent(
      id: id,
      mealPeriod: MealPeriod.fromString(
        (data['mealPeriod'] as String?) ?? 'breakfast',
      ),
      windowDate: (data['windowDate'] as String?) ?? '',
      fedByUid: (data['fedByUid'] as String?) ?? '',
      fedByName: (data['fedByName'] as String?) ?? 'Someone',
      fedAt: _parseTimestamp(data['fedAt']),
      isExtraMeal: (data['isExtraMeal'] as bool?) ?? false,
    );
  }

  DateTime _parseTimestamp(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _generateJoinCode(String petName) {
    final letters =
        petName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '').padRight(4, 'X').substring(0, 4);
    final digits = (Random().nextInt(90) + 10).toString();
    return '$letters$digits';
  }
}
