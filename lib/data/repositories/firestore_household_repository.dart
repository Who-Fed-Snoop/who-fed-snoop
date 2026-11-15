import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/feeding_event.dart';
import '../../domain/models/household.dart';
import '../../domain/models/meal_window.dart';
import '../../domain/models/treat_event.dart';
import 'household_repository.dart';

/// Production Cloud Firestore implementation of [HouseholdRepository] designed
/// around strict cost guardrails and the deployed `firestore.rules` schema:
/// - Streams only the single `households/{id}` document by default (1 read per change).
/// - Uses Firestore transactions and atomic batches so `feedings/{deterministicId}`,
///   `treats/{treatId}`, `todayMeals`, `todayTreats`, and `lastFeeding` stay in sync
///   without race-condition `PERMISSION_DENIED` errors.
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
    final cleanMember = _truncate(
      memberName.trim().isEmpty ? 'Keni' : memberName.trim(),
      50,
    );

    if (!snap.exists || snap.data() == null) {
      await docRef.set(<String, Object?>{
        'joinCode': InMemoryHouseholdRepository.defaultJoinCode,
        'petName': 'Snoop',
        'isPro': false,
        'createdAt': Timestamp.fromDate(now),
        'schedule': const MealSchedule().toJson(),
        'members': <String, Object?>{
          memberUid: <String, Object?>{
            'name': cleanMember,
            'fcmToken': null,
            'joinedAt': Timestamp.fromDate(now),
          },
        },
        'lastFeeding': null,
        'dailyTreatLimit': 4,
        'todayMeals': <String, Object?>{},
        'todayTreats': <Object?>[],
      });
      return;
    }

    final data = snap.data()!;
    final members = data['members'];
    if (members is Map && !members.containsKey(memberUid)) {
      await docRef.update(<String, Object?>{
        'members.$memberUid': <String, Object?>{
          'name': cleanMember,
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
    int limit = 50,
  }) {
    return _householdsRef
        .doc(householdId)
        .collection('feedings')
        .orderBy('fedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((query) {
      final events = query.docs.map((doc) => _feedingFromFirestore(doc.id, doc.data())).toList();
      events.sort((a, b) => b.fedAt.compareTo(a.fedAt));
      return events;
    });
  }

  @override
  Stream<List<TreatEvent>> watchRecentTreats(
    String householdId, {
    int limit = 50,
  }) {
    return _householdsRef
        .doc(householdId)
        .collection('treats')
        .orderBy('givenAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((query) {
      final treats =
          query.docs.map((doc) => TreatEvent.fromJson(doc.data(), fallbackId: doc.id)).toList();
      treats.sort((a, b) => b.givenAt.compareTo(a.givenAt));
      return treats;
    });
  }

  @override
  Future<Household> createHousehold({
    required String memberUid,
    required String memberName,
    required String petName,
  }) async {
    final now = DateTime.now();
    final cleanPet = _truncate(
      petName.trim().isEmpty ? 'Snoop' : petName.trim(),
      40,
    );
    final cleanMember = _truncate(
      memberName.trim().isEmpty ? 'Keni' : memberName.trim(),
      50,
    );
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
      'dailyTreatLimit': 4,
      'todayMeals': <String, Object?>{},
      'todayTreats': <Object?>[],
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
    final cleanName = _truncate(
      memberName.trim().isEmpty ? 'Ashley' : memberName.trim(),
      50,
    );
    final now = DateTime.now();

    final existingMember = existing.members[memberUid];
    final newMember = HouseholdMember(
      uid: memberUid,
      name: cleanName,
      fcmToken: existingMember?.fcmToken,
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
  Future<Household> updateHouseholdSettings({
    required String householdId,
    required String requestingUid,
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  }) async {
    if (schedule != null) {
      final validationError = schedule.validate();
      if (validationError != null) {
        throw ArgumentError(validationError);
      }
    }

    if (dailyTreatLimit != null && (dailyTreatLimit < 1 || dailyTreatLimit > 50)) {
      throw ArgumentError('Daily treat limit must be between 1 and 50.');
    }

    String? cleanPetName;
    if (petName != null) {
      final trimmed = petName.trim();
      if (trimmed.isEmpty || trimmed.length > 40) {
        throw ArgumentError('Pet name must be between 1 and 40 characters.');
      }
      cleanPetName = trimmed;
    }

    final householdDocRef = _householdsRef.doc(householdId);
    return _firestore.runTransaction<Household>((transaction) async {
      final snap = await transaction.get(householdDocRef);
      if (!snap.exists || snap.data() == null) {
        throw StateError('Household $householdId not found.');
      }

      final existing = _householdFromFirestore(snap.id, snap.data()!);
      if (!existing.members.containsKey(requestingUid)) {
        throw StateError('Only household members can update settings.');
      }

      final updates = <String, Object?>{};
      if (schedule != null) {
        updates['schedule'] = schedule.toJson();
      }
      if (dailyTreatLimit != null) {
        updates['dailyTreatLimit'] = dailyTreatLimit;
      }
      if (cleanPetName != null) {
        updates['petName'] = cleanPetName;
      }

      if (updates.isNotEmpty) {
        transaction.update(householdDocRef, updates);
      }

      return existing.copyWith(
        schedule: schedule,
        dailyTreatLimit: dailyTreatLimit,
        petName: cleanPetName,
      );
    });
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
    final cleanFedByName = _truncate(
      fedByName.trim().isEmpty ? 'Someone' : fedByName.trim(),
      50,
    );

    return _firestore.runTransaction<FeedingEvent>((transaction) async {
      final householdSnap = await transaction.get(householdDocRef);
      if (!householdSnap.exists || householdSnap.data() == null) {
        throw StateError('Household $householdId not found.');
      }

      final household = _householdFromFirestore(
        householdSnap.id,
        householdSnap.data()!,
      );
      final window = ActiveMealWindow.forTime(now, schedule: household.schedule);

      if (!isExtraMeal) {
        final deterministicDocRef =
            householdDocRef.collection('feedings').doc(window.deterministicId);
        final existingFeedingSnap = await transaction.get(deterministicDocRef);
        if (existingFeedingSnap.exists && existingFeedingSnap.data() != null) {
          return _feedingFromFirestore(
            existingFeedingSnap.id,
            existingFeedingSnap.data()!,
          );
        }

        final cached = household.feedingForWindow(window);
        if (cached != null) {
          return cached;
        }
      }

      final eventId = isExtraMeal
          ? '${window.deterministicId}_extra_${now.millisecondsSinceEpoch}_${InMemoryHouseholdRepository.nextUniqueSuffix()}'
          : window.deterministicId;

      final newEvent = FeedingEvent(
        id: eventId,
        mealPeriod: window.period,
        windowId: window.windowId,
        windowLabel: window.label,
        windowEmoji: window.emoji,
        windowDate: window.windowDate,
        fedByUid: fedByUid,
        fedByName: cleanFedByName,
        fedAt: now,
        isExtraMeal: isExtraMeal,
      );

      final feedingDocRef = householdDocRef.collection('feedings').doc(eventId);
      final updatedTodayMeals = Map<String, FeedingEvent>.of(household.todayMeals);
      if (!isExtraMeal) {
        updatedTodayMeals[newEvent.id] = newEvent;
      }
      final prunedTodayMeals = InMemoryHouseholdRepository.pruneTodayMeals(
        updatedTodayMeals,
        now,
      );

      final eventPayload = _feedingToFirestoreMap(newEvent);
      transaction.set(feedingDocRef, eventPayload);
      transaction.update(householdDocRef, <String, Object?>{
        'lastFeeding': eventPayload,
        'todayMeals': _todayMealsToFirestoreMap(prunedTodayMeals),
      });

      return newEvent;
    });
  }

  @override
  Future<void> undoFeeding({
    required String householdId,
    required String feedingId,
    required String requestingUid,
  }) async {
    final householdDocRef = _householdsRef.doc(householdId);
    final feedingDocRef = householdDocRef.collection('feedings').doc(feedingId);

    final householdSnap = await householdDocRef.get();
    if (!householdSnap.exists || householdSnap.data() == null) {
      return;
    }

    final household = _householdFromFirestore(
      householdSnap.id,
      householdSnap.data()!,
    );
    if (!household.members.containsKey(requestingUid)) {
      throw StateError('Only household members can undo a meal log.');
    }

    final recentSnap = await householdDocRef
        .collection('feedings')
        .orderBy('fedAt', descending: true)
        .limit(6)
        .get();

    final updatedTodayMeals = Map<String, FeedingEvent>.of(household.todayMeals)..remove(feedingId);

    final verifiedSubcollectionMeals = <FeedingEvent>[
      for (final doc in recentSnap.docs)
        if (doc.id != feedingId) _feedingFromFirestore(doc.id, doc.data()),
    ]..sort((a, b) => b.fedAt.compareTo(a.fedAt));

    final sortedCandidates = verifiedSubcollectionMeals.isNotEmpty
        ? verifiedSubcollectionMeals
        : (updatedTodayMeals.values.toList()..sort((a, b) => b.fedAt.compareTo(a.fedAt)));

    final previousLatest = sortedCandidates.isNotEmpty ? sortedCandidates.first : null;
    final todayMealsPayload = _todayMealsToFirestoreMap(updatedTodayMeals);

    try {
      final batch = _firestore.batch();
      batch.delete(feedingDocRef);
      batch.update(householdDocRef, <String, Object?>{
        'lastFeeding': previousLatest != null ? _feedingToFirestoreMap(previousLatest) : null,
        'todayMeals': todayMealsPayload,
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' ||
          previousLatest == null ||
          previousLatest.fedByUid == requestingUid) {
        rethrow;
      }
      // Fallback if security rules enforce `lastFeeding.fedByUid == request.auth.uid`:
      // keep `todayMeals` intact while restoring `lastFeeding` to caller's latest meal or null.
      final ownPrevious = sortedCandidates.where((m) => m.fedByUid == requestingUid).firstOrNull;
      final fallbackBatch = _firestore.batch();
      fallbackBatch.delete(feedingDocRef);
      fallbackBatch.update(householdDocRef, <String, Object?>{
        'lastFeeding': ownPrevious != null ? _feedingToFirestoreMap(ownPrevious) : null,
        'todayMeals': todayMealsPayload,
      });
      await fallbackBatch.commit();
    }
  }

  @override
  Future<TreatEvent> logTreat({
    required String householdId,
    required String givenByUid,
    required String givenByName,
    required DateTime now,
    required TreatPreset preset,
    String? customLabel,
    int quantity = 1,
    int? caloriesPerUnit,
    String? note,
  }) async {
    final validated = InMemoryHouseholdRepository.validateTreatInputs(
      preset: preset,
      givenByName: givenByName,
      customLabel: customLabel,
      quantity: quantity,
      caloriesPerUnit: caloriesPerUnit,
      note: note,
    );

    final householdDocRef = _householdsRef.doc(householdId);

    return _firestore.runTransaction<TreatEvent>((transaction) async {
      final snap = await transaction.get(householdDocRef);
      if (!snap.exists || snap.data() == null) {
        throw StateError('Household $householdId not found.');
      }

      final household = _householdFromFirestore(snap.id, snap.data()!);
      final logicalDate = household.schedule.logicalDateFor(now);
      final treatId =
          'treat_${logicalDate}_${now.millisecondsSinceEpoch}_${InMemoryHouseholdRepository.nextUniqueSuffix()}';

      final newTreat = TreatEvent(
        id: treatId,
        preset: preset,
        label: validated.label,
        emoji: preset.emoji,
        quantity: validated.quantity,
        caloriesPerUnit: validated.caloriesPerUnit,
        logicalDate: logicalDate,
        givenByUid: givenByUid,
        givenByName: validated.givenByName,
        givenAt: now,
        note: validated.note,
      );

      final treatDocRef = householdDocRef.collection('treats').doc(treatId);
      final prunedTreats = InMemoryHouseholdRepository.pruneTodayTreats(
        <TreatEvent>[newTreat, ...household.todayTreats],
        logicalDate,
      );

      transaction.set(treatDocRef, _treatToFirestoreMap(newTreat));
      transaction.update(householdDocRef, <String, Object?>{
        'todayTreats': prunedTreats.map(_treatToFirestoreMap).toList(growable: false),
      });

      return newTreat;
    });
  }

  @override
  Future<void> deleteTreat({
    required String householdId,
    required String treatId,
    required String requestingUid,
  }) async {
    final householdDocRef = _householdsRef.doc(householdId);
    final treatDocRef = householdDocRef.collection('treats').doc(treatId);

    await _firestore.runTransaction<void>((transaction) async {
      final snap = await transaction.get(householdDocRef);
      if (!snap.exists || snap.data() == null) {
        return;
      }

      final household = _householdFromFirestore(snap.id, snap.data()!);
      if (!household.members.containsKey(requestingUid)) {
        throw StateError('Only household members can delete treats.');
      }

      final updatedTreats = household.todayTreats
          .where((t) => t.id != treatId)
          .map(_treatToFirestoreMap)
          .toList(growable: false);

      transaction.delete(treatDocRef);
      transaction.update(householdDocRef, <String, Object?>{
        'todayTreats': updatedTreats,
      });
    });
  }

  Map<String, Object?> _feedingToFirestoreMap(FeedingEvent event) {
    return <String, Object?>{
      'id': event.id,
      'mealPeriod': event.mealPeriod.name,
      'windowId': event.effectiveWindowId,
      'windowLabel': event.effectiveLabel,
      'windowEmoji': event.effectiveEmoji,
      'windowDate': event.windowDate,
      'fedByUid': event.fedByUid,
      'fedByName': event.fedByName,
      'fedAt': Timestamp.fromDate(event.fedAt),
      'isExtraMeal': event.isExtraMeal,
    };
  }

  Map<String, Object?> _todayMealsToFirestoreMap(
    Map<String, FeedingEvent> todayMeals,
  ) {
    return todayMeals.map(
      (key, event) => MapEntry<String, Object?>(key, _feedingToFirestoreMap(event)),
    );
  }

  Map<String, Object?> _treatToFirestoreMap(TreatEvent treat) {
    return <String, Object?>{
      'id': treat.id,
      'preset': treat.preset.id,
      'label': treat.label,
      'emoji': treat.emoji,
      'quantity': treat.quantity,
      'caloriesPerUnit': treat.caloriesPerUnit,
      'logicalDate': treat.logicalDate,
      'givenByUid': treat.givenByUid,
      'givenByName': treat.givenByName,
      'givenAt': Timestamp.fromDate(treat.givenAt),
      if (treat.note != null) 'note': treat.note,
    };
  }

  Household _householdFromFirestore(String id, Map<String, Object?> data) {
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
      lastFeeding = _feedingFromFirestore(
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
          todayMealsMap[key] = _feedingFromFirestore(
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

    final dailyTreatLimit = ((data['dailyTreatLimit'] as num?)?.toInt() ?? 4).clamp(1, 50);

    return Household(
      id: id,
      joinCode: (data['joinCode'] as String?) ?? 'SNOOP4',
      petName: (data['petName'] as String?) ?? 'Snoop',
      isPro: (data['isPro'] as bool?) ?? false,
      createdAt: _parseTimestamp(data['createdAt']),
      schedule: schedule,
      members: membersMap,
      lastFeeding: lastFeeding,
      dailyTreatLimit: dailyTreatLimit,
      todayMeals: Map<String, FeedingEvent>.unmodifiable(todayMealsMap),
      todayTreats: List<TreatEvent>.unmodifiable(todayTreatsList),
    );
  }

  FeedingEvent _feedingFromFirestore(String id, Map<String, Object?> data) {
    return FeedingEvent.fromJson(data, fallbackId: id);
  }

  DateTime _parseTimestamp(Object? value) {
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

  static String _truncate(String input, int maxLength) {
    if (input.length <= maxLength) return input;
    return input.substring(0, maxLength);
  }

  String _generateJoinCode(String petName) {
    final letters =
        petName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '').padRight(4, 'X').substring(0, 4);
    final digits = (Random().nextInt(90) + 10).toString();
    return '$letters$digits';
  }
}
