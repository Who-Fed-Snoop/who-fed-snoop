# Who Fed Snoop? — Developer Loop

Canonical build, test, release, and deploy reference. Auto-synced with stack changes via `AGENTS.md`, `.agents/hooks.json`, `.githooks/pre-commit`, and `scripts/verify.sh`.

## Quick Reference

| Task | Command |
| :--- | :--- |
| **Bootstrap** | `flutter pub get && ./scripts/install-git-hooks.sh` |
| **Run (offline $0)** | `flutter run -d chrome --dart-define=USE_IN_MEMORY_REPO=true` |
| **Run (emulators $0)** | `firebase emulators:start` then `flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true` |
| **Run (live Firebase)** | `flutter run -d chrome` or `flutter run` (Android) |
| **Format & analyze** | `dart format lib test && flutter analyze --no-pub --fatal-infos` |
| **Fast test run** | `flutter test --no-pub -r failures-only` |
| **Full pre-push gate** | `./scripts/verify.sh` |
| **Build Web / APK** | `flutter build web --release` / `flutter build apk --release --split-per-abi` |
| **Deploy Firebase** | `firebase deploy --only firestore,hosting --project who-fed-snoop` |

## 1. Stack & Toolchain
- **App:** Flutter (Stable), Dart `^3.5.0` (`pubspec.yaml`, `lib/main.dart`), local device persistence via `shared_preferences` (`ScoopHolderStore`)
- **Lint/Format:** `flutter_lints: ^5.0.0`, strict casts/inference/raw-types, `page_width: 100`, `trailing_commas: preserve` (`analysis_options.yaml`)
- **Firebase (`who-fed-snoop`):** Anonymous Auth, Firestore (`nam5`, `firestore.rules`, `firestore.indexes.json`), Hosting (`build/web`, `firebase.json`)
- **Functions (`functions/`):** Firebase Functions v2, Node 20, TypeScript `^5.6.0` (`cd functions && npm install && npm run build`)
- **Targets:** Web (`web/`), Android Kotlin JVM 17 + `AppWidgetProvider` (`WidgetFirestoreSync` via `com.google.gms.google-services:4.4.2` & Firebase BOM `33.16.0` `firebase-firestore`/`firebase-auth`, `AlarmManager.setAndAllowWhileIdle` window-cutoff alarm + `RECEIVE_BOOT_COMPLETED`, `WidgetSyncService` `scheduleJson`/`useEmulator` prefs sync) + NFC/App Links (`android/`), macOS (`macos/`)
- **CLIs:** `flutter`, `dart`, `firebase`, `gh`, `node` (v20)

## 2. Local Run & Deep Links
- **Emulators (`firebase.json`):** Auth `:9099`, Firestore `:8080`, Hosting `:5000`, UI `http://localhost:4000`.
- **Fallback:** Live mode falls back to `InMemoryHouseholdRepository` if offline or on an unconfigured platform.
- **Smart-link routes (`whofedsnoop.com`):**
  - `/join/{CODE}` — Partner invite (e.g. `/join/SNOOP4`)
  - `/tap/{ID}` — NFC kibble-bin auto-feed (e.g. `/tap/household_snoop_01`)
  - `/s/{TOKEN}` — Dog sitter web pass (e.g. `/s/SNOOP4`)
  - Android intent test: `adb shell am start -a android.intent.action.VIEW -d "https://whofedsnoop.com/tap/household_snoop_01" com.whofedsnoop.who_fed_snoop`

## 3. Test Suite (`flutter test`)
Targeted runs: `flutter test test/domain/`, `flutter test test/data/`, `flutter test test/ui/`, or `--plain-name "<filter>"`.

| File | Coverage |
| :--- | :--- |
| `test/domain/meal_window_test.dart` | Default/custom schedules, overnight cutoffs, logical dates, `/join`, `/tap`, `/s` deep links |
| `test/data/household_repository_test.dart` | Household CRUD, deterministic meal IDs, custom schedules, treat tracking, member name sync |
| `test/data/feeder_view_model_test.dart` | Non-clobbering 10s LIFO Undo across meals & treats, Scoop Holder persistence & non-clobbering sync, optimistic state, errors |
| `test/ui/feeder_view_test.dart` | 1-tap feed, Undo, unbound *"Who holds this phone?"* prompt & cold-restart persistence, partner banner, 7-day filters, schedule edits, `360×640`–`412×915` layout |
| `test/ui/onboarding_sheet_test.dart` | Pack HQ modal, Scoop Holder switching, persona init, `50/40/6` bounds, double-tap guards, overflow checks |
| `test/ui/treats_and_schedule_ui_test.dart` | `TreatJarCard`, `CustomTreatSheet`, Chonk Alert, treat drawer delete, `HouseholdSettingsSheet` |

**Android JVM Unit Tests (`android/app/src/test/`):** `junit:junit:4.13.2` + `org.json:json:20240303` covering `MealScheduleModel`, `MealWindowResolver` (overnight/pre-first-window wrap-around, multi-rollover offline resolution, treat date rollover, ISO-8601 parsing), `WidgetFirestoreSync.parseAndResolve`, and `WidgetContentFormatter` responsive tiers.

**UI invariants:** Finite animations only (`AnimatedSwitcher`/`AnimatedContainer` so `pumpAndSettle()` never hangs); zero `RenderFlex` overflow at `360×800` and compact height `<680`.

## 4. Verification & Builds
- **Gate (`./scripts/verify.sh`):** Runs (1) `check-dev-docs-sync.sh --check`, (2) `dart format` check, (3) `flutter analyze --no-pub --fatal-infos`, (4) `flutter test --no-pub -r failures-only`, (5) `flutter build web --release --no-pub --no-wasm-dry-run`. *(CI template: `scripts/github-ci-workflow.yml` -> move to `.github/workflows/ci.yml` to activate.)*
- **Android Gradle Gate:** `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./android/gradlew -p android --no-daemon testDebugUnitTest assembleDebug :app:lintDebug` (uses `android/app/google-services.json` when present locally for Google Services resource generation; conditionally skipped in `android/app/build.gradle.kts` if absent).
- **Android APKs:** `flutter build apk --release --split-per-abi` -> `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (currently debug-signed in `android/app/build.gradle.kts` for sideloading; add upload keystore before Play Store release).
- **macOS:** `flutter build macos --release` -> `build/macos/Build/Products/Release/`.

## 5. Release & Deploy (`build → push → release → deploy`)
1. Bump `version: X.Y.Z+N` in `pubspec.yaml`.
2. Verify & build: `dart format lib test && ./scripts/verify.sh && flutter build apk --release --split-per-abi`
3. Commit, tag & push: `git commit -am "chore(release): bump version to X.Y.Z+N" && git tag vX.Y.Z && git push origin main vX.Y.Z`
4. GitHub Release: `gh release create vX.Y.Z build/app/outputs/flutter-apk/app-arm64-v8a-release.apk --title "Who Fed Snoop vX.Y.Z (...)" --notes "..."`
5. Firebase Deploy: `firebase deploy --only firestore,hosting --project who-fed-snoop` (`whofedsnoop.com` / `who-fed-snoop.web.app`).
   - *Functions (`onMealLogged`, `onTreatLogged`):* Requires upgrading `who-fed-snoop` from Spark to Blaze, then `cd functions && npm run build && firebase deploy --only functions --project who-fed-snoop`.

## 6. Auto-Sync Guardrails
`scripts/check-dev-docs-sync.sh` runs in `.agents/hooks.json` (`Stop`), `.githooks/pre-commit`, and `scripts/verify.sh`. It requires `docs/DEVELOPMENT_LOOP.md` updates whenever stack/build/Firebase/script configs or test suite files (`A/D/R`) change (ignoring pure `version:` bumps in `pubspec.yaml`). Bypass non-dev-loop tweaks with `SKIP_DEV_DOCS_SYNC=1`.
