import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/repositories/firestore_household_repository.dart';
import 'data/repositories/household_repository.dart';
import 'data/services/widget_sync_service.dart';
import 'firebase_options.dart';
import 'ui/core/app_theme.dart';
import 'ui/features/feeder/view_models/feeder_view_model.dart';
import 'ui/features/feeder/views/feeder_view.dart';

/// Pass `--dart-define=USE_FIREBASE_EMULATOR=true` to connect to local emulators
/// (`localhost:8080` and `localhost:9099`) at $0 cloud cost during development.
const bool _useFirebaseEmulator = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: false,
);

/// Pass `--dart-define=USE_IN_MEMORY_REPO=true` to force the offline in-memory repo.
const bool _forceInMemoryRepo = bool.fromEnvironment(
  'USE_IN_MEMORY_REPO',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final widgetSyncService = WidgetSyncService();
  HouseholdRepository repository;
  var initialMemberUid = InMemoryHouseholdRepository.keniUid;

  if (_forceInMemoryRepo) {
    repository = InMemoryHouseholdRepository();
  } else {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (_useFirebaseEmulator) {
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      }

      final credential = await FirebaseAuth.instance.signInAnonymously();
      final uid = credential.user?.uid;
      if (uid != null) {
        initialMemberUid = uid;
      }

      final firestoreRepo = FirestoreHouseholdRepository();
      await firestoreRepo.ensureDefaultHousehold(
        memberUid: initialMemberUid,
        memberName: 'Keni',
      );
      repository = firestoreRepo;
    } on Object {
      // Fallback to in-memory repository if running offline or without Firebase platform support
      repository = InMemoryHouseholdRepository();
    }
  }

  final viewModel = FeederViewModel(
    repository: repository,
    widgetSyncService: widgetSyncService,
    initialMemberUid: initialMemberUid,
  );

  // Connect Android App Links / NFC / Home Screen Widget button & Web URL routing
  final initialUri = await widgetSyncService.initDeepLinkBridge(
    onDeepLinkReceived: viewModel.handleIncomingUri,
  );

  runApp(WhoFedSnoopApp(viewModel: viewModel));

  if (initialUri != null) {
    unawaited(viewModel.handleIncomingUri(initialUri));
  }
}

class WhoFedSnoopApp extends StatefulWidget {
  const WhoFedSnoopApp({super.key, required this.viewModel});

  final FeederViewModel viewModel;

  @override
  State<WhoFedSnoopApp> createState() => _WhoFedSnoopAppState();
}

class _WhoFedSnoopAppState extends State<WhoFedSnoopApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.viewModel.ensureWindowTransitionTimer();
  }

  @override
  void didUpdateWidget(covariant WhoFedSnoopApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.cancelWindowTransitionTimer();
      widget.viewModel.ensureWindowTransitionTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.viewModel.cancelWindowTransitionTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.viewModel.refreshForClockChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Who Fed Snoop?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FeederView(viewModel: widget.viewModel),
    );
  }
}
