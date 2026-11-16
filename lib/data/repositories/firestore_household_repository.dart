import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/active_meal_window.dart';
import '../../domain/models/feeding_event.dart';
import '../../domain/models/household.dart';
import '../../domain/models/meal_schedule.dart';
import '../../domain/models/treat_event.dart';
import 'firestore_household_mapper.dart';
import 'household_repository.dart';
import 'household_state_policy.dart';

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
  /// and, when [memberName] is bound, registers [memberUid] if not already present.
  ///
  /// Never clobbers an existing `members[memberUid]` entry on cold start.
  Future<void> ensureDefaultHousehold({
    required String memberUid,
    String? memberName,
  }) async {
    final docRef = _householdsRef.doc(HouseholdStatePolicy.defaultHouseholdId);
    final snap = await docRef.get();
    final now = DateTime.now();
    final boundMemberName = HouseholdStatePolicy.resolveBoundMemberName(memberName);

    if (!snap.exists || snap.data() == null) {
      final creator = HouseholdMember(
        uid: memberUid,
        name: boundMemberName ?? 'Keni',
        joinedAt: now,
      );
      await docRef.set(
        FirestoreHouseholdMapper.newHouseholdPayload(
          joinCode: HouseholdStatePolicy.defaultJoinCode,
          petName: HouseholdStatePolicy.defaultPetName,
          createdAt: now,
          schedule: const MealSchedule(),
          creator: creator,
        ),
      );
      return;
    }

    final data = snap.data()!;
    if (HouseholdStatePolicy.shouldRegisterMemberOnColdStart(
      rawMembers: data['members'],
      memberUid: memberUid,
      boundMemberName: boundMemberName,
    )) {
      final member = HouseholdMember(uid: memberUid, name: boundMemberName!, joinedAt: now);
      await docRef.update(<String, Object?>{
        'members.$memberUid': FirestoreHouseholdMapper.memberToFirestoreMap(member),
      });
    }
  }

  @override
  Stream<Household?> watchHousehold(String householdId) {
    return _householdsRef.doc(householdId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return FirestoreHouseholdMapper.householdFromFirestore(snapshot.id, snapshot.data()!);
    });
  }

  @override
  Stream<List<FeedingEvent>> watchRecentFeedings(String householdId, {int limit = 50}) {
    return _householdsRef
        .doc(householdId)
        .collection('feedings')
        .orderBy('fedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((query) {
      final events = query.docs
          .map((doc) => FirestoreHouseholdMapper.feedingFromFirestore(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.fedAt.compareTo(a.fedAt));
      return events;
    });
  }

  @override
  Stream<List<TreatEvent>> watchRecentTreats(String householdId, {int limit = 50}) {
    return _householdsRef
        .doc(householdId)
        .collection('treats')
        .orderBy('givenAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((query) {
      final treats = query.docs
          .map((doc) => TreatEvent.fromJson(doc.data(), fallbackId: doc.id))
          .toList()
        ..sort((a, b) => b.givenAt.compareTo(a.givenAt));
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
    final cleanPet = HouseholdStatePolicy.sanitizeName(
      petName,
      fallback: HouseholdStatePolicy.defaultPetName,
      maxLength: 40,
    );
    final cleanMember =
        HouseholdStatePolicy.sanitizeName(memberName, fallback: 'Keni', maxLength: 50);
    final joinCode = HouseholdStatePolicy.generateJoinCode(cleanPet);

    final docRef = _householdsRef.doc();
    const schedule = MealSchedule();
    final member = HouseholdMember(uid: memberUid, name: cleanMember, joinedAt: now);

    await docRef.set(
      FirestoreHouseholdMapper.newHouseholdPayload(
        joinCode: joinCode,
        petName: cleanPet,
        createdAt: now,
        schedule: schedule,
        creator: member,
      ),
    );

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
    final existing = FirestoreHouseholdMapper.householdFromFirestore(doc.id, doc.data());
    final cleanName =
        HouseholdStatePolicy.sanitizeName(memberName, fallback: 'Ashley', maxLength: 50);
    final newMember = HouseholdMember(
      uid: memberUid,
      name: cleanName,
      fcmToken: existing.members[memberUid]?.fcmToken,
      joinedAt: DateTime.now(),
    );

    // Update only `members.<uid>` to satisfy `isValidMemberJoinUpdate` in firestore.rules.
    await doc.reference.update(<String, Object?>{
      'members.$memberUid': FirestoreHouseholdMapper.memberToFirestoreMap(newMember),
    });

    final updatedMembers = Map<String, HouseholdMember>.of(existing.members)
      ..[memberUid] = newMember;
    return existing.copyWith(members: updatedMembers);
  }

  @override
  Future<Household> updateMemberName({
    required String householdId,
    required String memberUid,
    required String memberName,
  }) async {
    final docRef = _householdsRef.doc(householdId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Household $householdId not found.');
    }

    final existing = FirestoreHouseholdMapper.householdFromFirestore(snap.id, snap.data()!);
    final result = HouseholdStatePolicy.applyMemberNameUpdate(
      existing,
      memberUid: memberUid,
      memberName: memberName,
      now: DateTime.now(),
    );
    if (!result.changed) return existing;

    await docRef.update(
      result.isNewMember
          ? <String, Object?>{
              'members.$memberUid': FirestoreHouseholdMapper.memberToFirestoreMap(result.member),
            }
          : <String, Object?>{'members.$memberUid.name': result.member.name},
    );
    return result.household;
  }

  @override
  Future<Household> updateHouseholdSettings({
    required String householdId,
    required String requestingUid,
    MealSchedule? schedule,
    int? dailyTreatLimit,
    String? petName,
  }) async {
    final cleanPetName = HouseholdStatePolicy.validateSettingsInputs(
      schedule: schedule,
      dailyTreatLimit: dailyTreatLimit,
      petName: petName,
    );

    final householdDocRef = _householdsRef.doc(householdId);
    return _firestore.runTransaction<Household>((transaction) async {
      final snap = await transaction.get(householdDocRef);
      if (!snap.exists || snap.data() == null) {
        throw StateError('Household $householdId not found.');
      }

      final existing = FirestoreHouseholdMapper.householdFromFirestore(snap.id, snap.data()!);
      if (!existing.members.containsKey(requestingUid)) {
        throw StateError('Only household members can update settings.');
      }

      final updates = <String, Object?>{
        if (schedule != null) 'schedule': schedule.toJson(),
        if (dailyTreatLimit != null) 'dailyTreatLimit': dailyTreatLimit,
        if (cleanPetName != null) 'petName': cleanPetName,
      };
      if (updates.isNotEmpty) transaction.update(householdDocRef, updates);

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
    return _firestore.runTransaction<FeedingEvent>((transaction) async {
      final householdSnap = await transaction.get(householdDocRef);
      if (!householdSnap.exists || householdSnap.data() == null) {
        throw StateError('Household $householdId not found.');
      }

      final household = FirestoreHouseholdMapper.householdFromFirestore(
        householdSnap.id,
        householdSnap.data()!,
      );
      final window = ActiveMealWindow.forTime(now, schedule: household.schedule);

      if (!isExtraMeal) {
        final deterministicDocRef =
            householdDocRef.collection('feedings').doc(window.deterministicId);
        final existingFeedingSnap = await transaction.get(deterministicDocRef);
        if (existingFeedingSnap.exists && existingFeedingSnap.data() != null) {
          return FirestoreHouseholdMapper.feedingFromFirestore(
            existingFeedingSnap.id,
            existingFeedingSnap.data()!,
          );
        }
        final cached = household.feedingForWindow(window);
        if (cached != null) return cached;
      }

      final newEvent = HouseholdStatePolicy.buildFeedingEvent(
        window: window,
        fedByUid: fedByUid,
        fedByName: fedByName,
        now: now,
        isExtraMeal: isExtraMeal,
      );

      final updatedTodayMeals = Map<String, FeedingEvent>.of(household.todayMeals);
      if (!isExtraMeal) updatedTodayMeals[newEvent.id] = newEvent;
      final prunedTodayMeals = HouseholdStatePolicy.pruneTodayMeals(updatedTodayMeals, now);

      final eventPayload = FirestoreHouseholdMapper.feedingToFirestoreMap(newEvent);
      transaction.set(householdDocRef.collection('feedings').doc(newEvent.id), eventPayload);
      transaction.update(householdDocRef, <String, Object?>{
        'lastFeeding': eventPayload,
        'todayMeals': FirestoreHouseholdMapper.todayMealsToFirestoreMap(prunedTodayMeals),
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
    if (!householdSnap.exists || householdSnap.data() == null) return;

    final household = FirestoreHouseholdMapper.householdFromFirestore(
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
        if (doc.id != feedingId) FirestoreHouseholdMapper.feedingFromFirestore(doc.id, doc.data()),
    ];

    final sortedCandidates = HouseholdStatePolicy.rankPreviousFeedingCandidates(
      updatedTodayMeals: updatedTodayMeals,
      historyMeals: verifiedSubcollectionMeals,
      preferHistoryWhenPresent: true,
    );
    final previousLatest = sortedCandidates.isNotEmpty ? sortedCandidates.first : null;
    final todayMealsPayload = FirestoreHouseholdMapper.todayMealsToFirestoreMap(updatedTodayMeals);

    Future<void> commitUndo(FeedingEvent? restoredLastFeeding) {
      final batch = _firestore.batch()
        ..delete(feedingDocRef)
        ..update(householdDocRef, <String, Object?>{
          'lastFeeding': restoredLastFeeding != null
              ? FirestoreHouseholdMapper.feedingToFirestoreMap(restoredLastFeeding)
              : null,
          'todayMeals': todayMealsPayload,
        });
      return batch.commit();
    }

    try {
      await commitUndo(previousLatest);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' ||
          previousLatest == null ||
          previousLatest.fedByUid == requestingUid) {
        rethrow;
      }
      // Fallback if security rules enforce `lastFeeding.fedByUid == request.auth.uid`:
      // keep `todayMeals` intact while restoring `lastFeeding` to caller's latest meal or null.
      await commitUndo(sortedCandidates.where((m) => m.fedByUid == requestingUid).firstOrNull);
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
    HouseholdStatePolicy.validateTreatInputs(
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

      final household = FirestoreHouseholdMapper.householdFromFirestore(snap.id, snap.data()!);
      if (!household.members.containsKey(givenByUid)) {
        throw StateError('Only household members can log treats.');
      }
      final newTreat = HouseholdStatePolicy.buildTreatEvent(
        household: household,
        givenByUid: givenByUid,
        givenByName: givenByName,
        now: now,
        preset: preset,
        customLabel: customLabel,
        quantity: quantity,
        caloriesPerUnit: caloriesPerUnit,
        note: note,
      );
      final prunedTreats = HouseholdStatePolicy.pruneTodayTreats(
        <TreatEvent>[newTreat, ...household.todayTreats],
        newTreat.logicalDate,
      );

      transaction.set(
        householdDocRef.collection('treats').doc(newTreat.id),
        FirestoreHouseholdMapper.treatToFirestoreMap(newTreat),
      );
      transaction.update(householdDocRef, <String, Object?>{
        'todayTreats':
            prunedTreats.map(FirestoreHouseholdMapper.treatToFirestoreMap).toList(growable: false),
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
      if (!snap.exists || snap.data() == null) return;

      final household = FirestoreHouseholdMapper.householdFromFirestore(snap.id, snap.data()!);
      if (!household.members.containsKey(requestingUid)) {
        throw StateError('Only household members can delete treats.');
      }

      transaction.delete(treatDocRef);
      transaction.update(householdDocRef, <String, Object?>{
        'todayTreats': household.todayTreats
            .where((t) => t.id != treatId)
            .map(FirestoreHouseholdMapper.treatToFirestoreMap)
            .toList(growable: false),
      });
    });
  }
}
