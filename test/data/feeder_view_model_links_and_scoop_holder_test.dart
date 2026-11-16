import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:who_fed_snoop/data/repositories/household_repository.dart';
import 'package:who_fed_snoop/data/services/scoop_holder_store.dart';
import 'package:who_fed_snoop/data/services/widget_sync_service.dart';
import 'package:who_fed_snoop/ui/features/feeder/view_models/feeder_view_model.dart';

import '../helpers/controllable_household_repository.dart';

void main() {
  group('FeederViewModel — Deep Links (/tap, /join, /s), Web Hash & Stream Errors', () {
    test(
      'cold-start /tap waits for household load, rejects wrong householdId, and suppresses banner on error (#12 Bug 6B)',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 8, 30);
        final inner = InMemoryHouseholdRepository(initialClock: fixedNow);
        final controlled = ControllableHouseholdRepository(inner)
          ..watchHouseholdGate = Completer<void>();
        final vm = FeederViewModel(
          repository: controlled,
          widgetSyncService: WidgetSyncService(),
          clock: () => fixedNow,
        );
        addTearDown(() {
          vm.dispose();
          inner.dispose();
        });

        // Trigger /tap BEFORE watchHousehold has emitted its first snapshot
        final tapFuture = vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/tap/household_snoop_01'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(vm.isLoading, isTrue);

        // Release initial household snapshot -> /tap now logs Breakfast cleanly!
        controlled.watchHouseholdGate!.complete();
        await tapFuture;
        await flushMicrotasks();

        expect(vm.isCurrentWindowFed, isTrue);
        expect(
          vm.partnerNotificationBanner,
          contains('Instant Tap-to-Feed: Logged Breakfast for Snoop!'),
        );

        // Wrong household ID -> sets errorMessage and does NOT overwrite banner with fake success
        vm.dismissPartnerBanner();
        await vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/tap/nonexistent_household_99'),
        );
        expect(vm.errorMessage, contains('nonexistent_household_99'));
        expect(vm.partnerNotificationBanner, isNull);
      },
    );

    test(
      'invalid /join and /s links populate errorMessage without crashing or falsely activating Dog Sitter mode (#12 Bug 6A & 6C)',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 8, 30);
        final repo = InMemoryHouseholdRepository(initialClock: fixedNow);
        final vm = FeederViewModel(
          repository: repo,
          widgetSyncService: WidgetSyncService(),
          clock: () => fixedNow,
        );
        addTearDown(() {
          vm.dispose();
          repo.dispose();
        });
        await flushMicrotasks();

        // Invalid /join/TYPO99 does not throw unhandled StateError
        await vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/join/TYPO99'),
        );
        expect(vm.errorMessage, contains('TYPO99'));
        expect(vm.currentMemberName, equals('Keni'));

        // Invalid /s/sitter_xyz does NOT switch persona to Dog Sitter or show active banner
        vm.dismissError();
        await vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/s/sitter_xyz'),
        );
        expect(vm.errorMessage, isNotNull);
        expect(vm.currentMemberName, equals('Keni'));
        expect(vm.isSitterMode, isFalse);
        expect(vm.partnerNotificationBanner, isNull);

        // Valid /s/SNOOP4 activates Dog Sitter mode cleanly
        await vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/s/SNOOP4'),
        );
        expect(vm.errorMessage, isNull);
        expect(vm.currentMemberName, equals('Dog Sitter'));
        expect(vm.isSitterMode, isTrue);
        expect(
          vm.partnerNotificationBanner,
          contains('Dog Sitter Guest Pass active'),
        );
      },
    );

    test(
      'WidgetSyncService.extractWebInitialUri supports standard paths and hash-routed URLs (#12 Bug 6D)',
      () {
        expect(
          WidgetSyncService.extractWebInitialUri(
            Uri.parse('https://whofedsnoop.com/'),
          ),
          isNull,
        );
        expect(
          WidgetSyncService.extractWebInitialUri(
            Uri.parse('https://whofedsnoop.com/join/SNOOP4'),
          ),
          equals(Uri.parse('https://whofedsnoop.com/join/SNOOP4')),
        );
        expect(
          WidgetSyncService.extractWebInitialUri(
            Uri.parse('https://whofedsnoop.com/#/join/SNOOP4'),
          ),
          equals(Uri.parse('https://whofedsnoop.com/join/SNOOP4')),
        );
        expect(
          WidgetSyncService.extractWebInitialUri(
            Uri.parse('https://whofedsnoop.com/#s/SNOOP4'),
          ),
          equals(Uri.parse('https://whofedsnoop.com/s/SNOOP4')),
        );
      },
    );

    test(
      'non-InMemory repository guards simulatePartnerFeed and captures history stream errors (#12 Bug 7B & 8B)',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 10, 0);
        final inner = InMemoryHouseholdRepository(initialClock: fixedNow);
        final controlled = ControllableHouseholdRepository(inner)..failHistoryStreams = true;
        final vm = FeederViewModel(
          repository: controlled,
          widgetSyncService: WidgetSyncService(),
          clock: () => fixedNow,
        );
        addTearDown(() {
          vm.dispose();
          inner.dispose();
        });
        await flushMicrotasks();

        expect(vm.canSimulatePartner, isFalse);
        await vm.simulatePartnerFeed();
        expect(vm.errorMessage, contains('demo mode'));

        vm.dismissError();
        vm.toggleHistoryExpanded();
        await flushMicrotasks();

        expect(vm.isHistoryExpanded, isTrue);
        expect(vm.errorMessage, contains('permission error'));
      },
    );
  });

  group('FeederViewModel — Scoop Holder Persistence & Non-Clobbering Sync (FB-001)', () {
    test(
      'unbound SharedPreferences store prompts once, persists Ashley across cold start, and never clobbers on restart',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final store1 = SharedPreferencesScoopHolderStore(prefs);
        final fixedNow = DateTime(2026, 11, 8, 9, 0);
        final repo = InMemoryHouseholdRepository(initialClock: fixedNow);
        addTearDown(repo.dispose);

        // Cold start #1 on an unbound device
        final vm1 = FeederViewModel(
          repository: repo,
          widgetSyncService: WidgetSyncService(),
          scoopHolderStore: store1,
          clock: () => fixedNow,
        );
        await flushMicrotasks();

        expect(vm1.isDeviceBound, isFalse);
        expect(vm1.needsScoopHolderPrompt, isTrue);

        // User picks Ashley in the prompt
        await vm1.bindScoopHolder(
          uid: InMemoryHouseholdRepository.ashleyUid,
          name: 'Ashley',
        );
        await flushMicrotasks();

        expect(vm1.isDeviceBound, isTrue);
        expect(vm1.needsScoopHolderPrompt, isFalse);
        expect(vm1.currentMemberName, equals('Ashley'));
        expect(vm1.currentMemberUid, equals(InMemoryHouseholdRepository.ashleyUid));
        expect(store1.getMemberName(), equals('Ashley'));
        vm1.dispose();

        // Cold start #2 with fresh SharedPreferencesScoopHolderStore & ViewModel
        final store2 = SharedPreferencesScoopHolderStore(prefs);
        final vm2 = FeederViewModel(
          repository: repo,
          widgetSyncService: WidgetSyncService(),
          scoopHolderStore: store2,
          clock: () => fixedNow,
        );
        await flushMicrotasks();

        expect(vm2.isDeviceBound, isTrue);
        expect(vm2.needsScoopHolderPrompt, isFalse);
        expect(vm2.currentMemberName, equals('Ashley'));
        expect(vm2.currentMemberUid, equals(InMemoryHouseholdRepository.ashleyUid));

        // Feeding logs as Ashley, NOT reset to Keni
        await vm2.markPetFed();
        await flushMicrotasks();
        expect(vm2.currentWindowFeeding?.fedByName, equals('Ashley'));
        vm2.dispose();
      },
    );

    test(
      'non-InMemory repository keeps auth UID anchored, syncs members[uid].name, and never clobbers on cold start',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 9, 30);
        final inner = InMemoryHouseholdRepository(initialClock: fixedNow);
        final controlled = ControllableHouseholdRepository(inner);
        final store = InMemoryScoopHolderStore();
        addTearDown(inner.dispose);

        const deviceAuthUid = 'firebase_anon_ashley_uid';

        // Cold start #1 on unbound device with Firebase-like repository
        final vm1 = FeederViewModel(
          repository: controlled,
          widgetSyncService: WidgetSyncService(),
          scoopHolderStore: store,
          initialMemberUid: deviceAuthUid,
          clock: () => fixedNow,
        );
        await flushMicrotasks();
        expect(vm1.needsScoopHolderPrompt, isTrue);
        expect(controlled.updateMemberNameCalls, equals(0));

        // Bind to Ashley -> syncs households/{id}.members[deviceAuthUid].name = 'Ashley'
        await vm1.bindScoopHolder(
          uid: InMemoryHouseholdRepository.ashleyUid,
          name: 'Ashley',
        );
        await flushMicrotasks();

        expect(vm1.currentMemberUid, equals(deviceAuthUid));
        expect(vm1.currentMemberName, equals('Ashley'));
        expect(controlled.updateMemberNameCalls, equals(1));
        expect(
          vm1.household?.members[deviceAuthUid]?.name,
          equals('Ashley'),
        );
        vm1.dispose();

        // Cold start #2: member already exists in household; NO cold-start clobber write!
        final callsBeforeRestart = controlled.updateMemberNameCalls;
        final vm2 = FeederViewModel(
          repository: controlled,
          widgetSyncService: WidgetSyncService(),
          scoopHolderStore: store,
          initialMemberUid: deviceAuthUid,
          clock: () => fixedNow,
        );
        await flushMicrotasks();

        expect(vm2.isDeviceBound, isTrue);
        expect(vm2.currentMemberName, equals('Ashley'));
        expect(vm2.currentMemberUid, equals(deviceAuthUid));
        expect(controlled.updateMemberNameCalls, equals(callsBeforeRestart));
        expect(
          vm2.household?.members[deviceAuthUid]?.name,
          equals('Ashley'),
        );
        vm2.dispose();
      },
    );

    test(
      'cold-start NFC /tap on unbound device waits for Scoop Holder binding before logging meal',
      () async {
        final fixedNow = DateTime(2026, 11, 8, 8, 30);
        final repo = InMemoryHouseholdRepository(initialClock: fixedNow);
        final store = InMemoryScoopHolderStore();
        final vm = FeederViewModel(
          repository: repo,
          widgetSyncService: WidgetSyncService(),
          scoopHolderStore: store,
          clock: () => fixedNow,
        );
        addTearDown(() {
          vm.dispose();
          repo.dispose();
        });
        await flushMicrotasks();

        // Launch via NFC /tap while unbound -> waits for binding rather than logging as Keni
        final tapFuture = vm.handleIncomingUri(
          Uri.parse('https://whofedsnoop.com/tap/household_snoop_01'),
        );
        await flushMicrotasks();
        expect(vm.isCurrentWindowFed, isFalse);

        // User answers prompt as Ashley -> /tap immediately logs Breakfast as Ashley!
        await vm.bindScoopHolder(
          uid: InMemoryHouseholdRepository.ashleyUid,
          name: 'Ashley',
        );
        await tapFuture;
        await flushMicrotasks();

        expect(vm.isCurrentWindowFed, isTrue);
        expect(vm.currentWindowFeeding?.fedByName, equals('Ashley'));
      },
    );
  });
}
