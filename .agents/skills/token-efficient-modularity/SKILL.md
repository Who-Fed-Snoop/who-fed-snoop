---
name: token-efficient-modularity
description: >-
  Enforces modular file budgets (~150-350L), clean layer boundaries (Domain, Repository
  policies/mappers, thin ViewModel facades, UI views/widgets/painters, native Kotlin
  resolvers, behavior-sliced tests), token-lean read/edit/test loops, and conflict-free
  multi-agent slicing. Use when fixing bugs, adding features, touching files near or over
  350 lines, refactoring modules or tests, or partitioning parallel/swarm work.
---

# Token-Efficient Modularity Playbook

Keep every feature, bugfix, and refactor small in context cost, clean in responsibility boundaries,
and fast to verify.

## 1. File Budgets & Anti-Bloat Rules

| Layer / Surface | Target | Split Trigger / Ceiling | Extraction Unit |
| :--- | :--- | :--- | :--- |
| **Domain (`lib/domain/models/`)** | `85–300L` | `~350L` | Value object, schedule/window math, route parser |
| **Data (`lib/data/{repositories,services}/`)** | `90–350L` | `~400L` (`<=475L` stream/tx repos) | Pure policy class, payload mapper, platform bridge |
| **ViewModels (`.../view_models/`)** | `150–350L` | `~375L` | Session/action/undo controller, pure diff detector |
| **UI (`.../{views,widgets}/`, `ui/core/`)** | `100–350L` | `~400L` (`<=550L` vector `CustomPainter`) | Sub-card, row, banner, dialog, or custom painter |
| **Tests (`test/`, `android/app/src/test/`)** | `150–350L` | `~400L` | Behavior-sliced `*_test.dart` + `test/helpers/` |
| **Native Kotlin (`android/.../kotlin/`)** | `90–320L` | `~350L` | Pure-JVM model/resolver/formatter, prefs store, sync |

- **Pre-edit `wc -l` check:** Before adding code or tests during any bugfix or feature, run `wc -l`
  on touched files. If an edit pushes a file past `~400L` or mixes a second responsibility, extract
  a cohesive collaborator, widget, policy method, or test slice immediately—never let files silently
  creep to `800–1200L`.
- **Zero ceremony:** Never introduce 1-method pass-through wrappers, single-implementation interfaces
  (except true IO/test seams like repositories or preference stores), or speculative registries.
  Every extracted file must own real state, layout, pure policy logic, or serialization.

## 2. Generalized Layer Patterns

### Domain (`lib/domain/models/`)
- Keep value models, cutoff/rollover math, and route parsers immutable and pure (`meal_period.dart`,
  `meal_schedule.dart`, `active_meal_window.dart`, `deep_link_route.dart`).
- When splitting a widely imported model file, keep a minimal barrel (`export '...';`, e.g.,
  `meal_window.dart`) when preserving stable caller imports avoids noisy repo-wide churn.

### Data & Cross-Target Parity (`lib/data/`, `android/.../kotlin/`)
- **Pure repository contract:** Keep `HouseholdRepository` (`household_repository.dart`) free of
  backend details; keep `InMemory` and `Firestore` implementations separate.
- **Shared stateless policy:** Centralize validation, sanitization, member binding, deterministic
  event IDs, daily meal/treat pruning, and undo-candidate ranking in a pure stateless policy
  (`HouseholdStatePolicy` in `household_state_policy.dart`) shared by *both*
  `InMemoryHouseholdRepository` and `FirestoreHouseholdRepository`. Never duplicate business rules.
- **Dedicated mappers & bridges:** Isolate Firestore document/transaction serialization in a mapper
  (`FirestoreHouseholdMapper`) and keep local/platform persistence in focused `lib/data/services/`
  stores (`ScoopHolderStore`, `WidgetSyncService`).
- **Dart <-> Native parity:** When native surfaces (Android `AppWidgetProvider`, `AlarmManager`
  cutoffs, boot receivers, background sync) evaluate schedules or rollover offline:
  1. Sync serialized config + runtime flags from Dart through one bridge (`WidgetSyncService`).
  2. Centralize native `SharedPreferences` keys and reads/writes in one store (`WidgetPrefsStore`).
  3. Keep schedule/window resolution and responsive text formatting in pure-JVM classes
     (`MealScheduleModel`, `MealWindowResolver`, `WidgetContentFormatter`) free of `android.*` UI
     types so fast JUnit tests lock parity with Dart.

### ViewModels (`lib/ui/features/<feature>/view_models/`)
- Keep the `ChangeNotifier` (`FeederViewModel`) as a thin reactive facade (`~250–350L`) exposing
  read-only state + user commands while delegating orthogonal mechanics to focused collaborators:
  - **Session & streams:** `HouseholdSessionController` (subscriptions, lazy history streams,
    rollover timers, local store hydration).
  - **Mutations:** `FeedingActionsController` (in-flight guards, repository writes, widget sync,
    error capture).
  - **Timers & LIFO undo:** `UndoStackController` (10s meal/treat countdown stack without clobbering
    concurrent actions).
  - **Pure diff detection:** `PartnerActivityDetector` (snapshot comparison for partner banners).
  - **Route coordination:** `DeepLinkCoordinator` (cold-start & live `/join`, `/tap`, `/s` flows).
- Always guard async continuations and timer callbacks against `dispose()` before `notifyListeners()`.

### UI (`lib/ui/features/<feature>/{views,widgets}/`, `lib/ui/core/`)
- **`views/`:** Top-level screen, sheet, and dialog scaffolds (`FeederView`, `OnboardingSheet`,
  `HouseholdSettingsSheet`) wiring ViewModel state to child sections. Preserve or re-export public
  `Key` constants and callback typedefs on entry views so widget tests stay decoupled from splits.
- **`widgets/`:** Self-contained cards, rows, banners, and sub-dialogs (`100–350L`) parameterized
  via explicit constructor inputs and callbacks rather than coupling leaf widgets to full ViewModels.
- **`core/`:** Design tokens (`AppTheme`), shared comic chrome (`ComicSpeechBubble`), mascot shells
  (`SnoopMascot`, `SnoopMiniAvatar`), and cohesive vector painters (`SnoopCartoonPainter`).
- **UI invariants:** Finite animations only (`AnimatedSwitcher`/`AnimatedContainer`—never unbounded
  repeaters that hang `pumpAndSettle()`); verify zero `RenderFlex` overflow at `360×800` and `<680`.

### Tests (`test/{domain,data,ui,helpers}/`, `android/app/src/test/`)
- **Behavior-sliced suites (`150–350L`):** Split tests by user workflow or subsystem (e.g., undo &
  treats vs. partner banners & timers vs. links & scoop holder) instead of growing monoliths.
- **Shared harnesses (`test/helpers/`):** Centralize controllable fakes
  (`ControllableHouseholdRepository`) and pump helpers (`onboarding_test_harness.dart`)—never
  copy-paste fake classes across suites.
- **Test at the lowest honest layer:** Cover policies, mappers, undo stacks, diff detectors, and
  Kotlin resolvers with direct unit tests; reserve full widget pumps for composition, gesture/key
  wiring, and `360×800` / `<680` layout checks.
- **Living docs sync:** Any `A/D/R` change to `test/*_test.dart` requires updating §3 of
  [`docs/DEVELOPMENT_LOOP.md`](../../../docs/DEVELOPMENT_LOOP.md) in the same commit (enforced by
  [`scripts/check-dev-docs-sync.sh`](../../../scripts/check-dev-docs-sync.sh)).

## 3. Token-Conscious Execution Loop
1. **Locate before reading:** Use ripgrep/symbol search and `wc -l` to pinpoint target definitions
   and line counts before opening files.
2. **Bounded reads & surgical edits:** Read narrow line ranges (`StartLine`..`EndLine`) around
   target symbols and imports; apply minimal localized edits.
3. **Scoped inner-loop verification:** Run only the affected test slice with quiet output:
   - Dart/Flutter: `flutter test test/ui/<slice>_test.dart --no-pub -r failures-only` (or
     `--plain-name "<case>"`).
   - Static checks: `dart format lib test && flutter analyze --no-pub --fatal-infos`.
   - Android JVM (when touching `android/.../*.kt`):
     `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./android/gradlew -p android --no-daemon testDebugUnitTest`.
4. **Single full gate before commit:** Run `./scripts/verify.sh` once when code and docs sync finish.
5. **Protect always-on context:** Keep [`AGENTS.md`](../../../AGENTS.md) `<=12` lines; place
   detailed workflows in `.agents/skills/*` and stack/test catalogs in
   [`docs/DEVELOPMENT_LOOP.md`](../../../docs/DEVELOPMENT_LOOP.md).

## 4. Multi-Agent & Refactor Slicing
- **Wave 1 — Disjoint ownership + barrel `export`s:** Assign each agent an exclusive directory/file
  slice (zero overlapping edits, including shared docs). When splitting a module imported outside
  the slice, keep its entrypoint stable via `export` barrels and preserved `Key`/typedef symbols so
  each worker compiles and verifies independently without touching `test/` or other slices.
- **Wave 2 — Callers, test splits & single-pass docs sync:** After Wave 1 merges, tighten direct
  imports if needed, split/add `test/*_test.dart` behavior slices with `test/helpers/`, update
  [`docs/DEVELOPMENT_LOOP.md`](../../../docs/DEVELOPMENT_LOOP.md) and
  [`docs/FEEDBACK_LOG.md`](../../../docs/FEEDBACK_LOG.md) once in a single pass, and run
  `./scripts/verify.sh`.
