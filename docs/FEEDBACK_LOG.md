# 🐾 Who Fed Snoop? — Dogfood Feedback & Bug Log

> **Purpose:** Canonical, git-versioned tracker for real-world bugs, UX papercuts, and enhancement ideas gathered while **Keni & Ashley** use **Who Fed Snoop?** (`household_snoop_01`) day-to-day.
>
> **Companion Roadmap:** [`docs/PRODUCTIZATION_GAPS_AND_ROADMAP.md`](./PRODUCTIZATION_GAPS_AND_ROADMAP.md)
> **Agent Workflow:** Managed via [`.agents/skills/feedback-triage/SKILL.md`](../.agents/skills/feedback-triage/SKILL.md) — **log & triage first, propose *Dogfood Now* vs. *Phase 0–4*, and confirm with Keni before changing code.**

---

## How Items Flow

1. **Capture (`FB-###`):** Keni relays feedback or a bug from himself or Ashley in chat. The agent assigns the next sequential `FB-###` ID (never reused) and records source, device/surface context, type/severity, and target track.
2. **Triage & Deduplicate:** The agent checks [`PRODUCTIZATION_GAPS_AND_ROADMAP.md`](./PRODUCTIZATION_GAPS_AND_ROADMAP.md) §2–§4 to flag whether the report hits an already-audited gap (e.g., unwired FCM push, stale partner widget) or a brand-new issue, and recommends either:
   - **🔥 Dogfood Now** — Fast-lane fix/enhancement for Keni & Ashley's live household without waiting on public launch Phases 0–4.
   - **🗺️ Phase 0–4 / Parking Lot** — Slotted into [`PRODUCTIZATION_GAPS_AND_ROADMAP.md`](./PRODUCTIZATION_GAPS_AND_ROADMAP.md) with an `[FB-###]` backlink.
3. **Confirm → Ship → Close Loop:** Once Keni approves implementing an item, it moves to `In Progress`, ships with tests (`./scripts/verify.sh`), and moves to **✅ Shipped & Verified** with its resolution note (plus live APK / Firebase deploy notes when applicable).

### Taxonomy Quick Reference
- **Source & Context:** Reporter (`Keni` | `Ashley` | `Both`) · Device/OS (e.g., `Pixel / Android`, `iPhone / iOS Safari`, `Desktop Chrome`) · Surface (`App` | `NFC Tap` | `Home Widget` | `Web` | `Push` | `Pack HQ`)
- **Type:** `Bug` | `UX Papercut` | `Enhancement` | `Idea`
- **Severity:** `S0 Blocker` (broken feeding/wrong state) · `S1 Daily Pain` (annoying in daily routine) · `S2 Polish` (visual/copy/minor friction) · `S3 Nice-to-Have`
- **Status:** `Triaged` | `Needs Info` | `In Progress` | `Deferred` | `Shipped`

---

## 🔥 Dogfood Queue (Live Household Fast-Lane)

*Items prioritized for immediate or near-term iteration on Keni & Ashley's daily experience, independent of public productization phases.*

| ID | Date | Source & Context | Type & Severity | Status | Summary & Proposed Fix |
| :--- | :--- | :--- | :--- | :--- | :--- |
| *(Empty)* | — | — | — | — | All current fast-lane dogfood items have shipped! |

---

## 🗺️ Roadmap-Linked Backlog (`Phase 0` – `Phase 4` & `Parking Lot`)

*Feedback items that belong in a broader productization phase in [`PRODUCTIZATION_GAPS_AND_ROADMAP.md`](./PRODUCTIZATION_GAPS_AND_ROADMAP.md) or future exploration.*

| ID | Date | Source & Context | Type & Severity | Target Phase | Status | Summary & Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `FB-004` | 2026-11-15 | **Keni** · App (General) | `Idea` · `S3 Nice-to-Have` | `Phase 4 (End)` | `Triaged` | **Optional Poop / Potty Tracking.** Useful partner/sitter coordination signal (*"Did Snoop poop on the morning walk?"* / tummy health tracking). Keep opt-in in Household Settings so the primary 2-Second meal button stays uncluttered, with denormalized `lastPoop` / `todayPoopCount` inside `households/{id}` (`0` extra default Firestore reads) and optional `✅ Normal` / `⚠️ Soft` tag + 10s LIFO Undo. |

---

## ✅ Shipped & Verified

*Completed dogfood fixes and enhancements.*

| ID | Shipped | Source & Context | Type | Resolution & Verification |
| :--- | :--- | :--- | :--- | :--- |
| `FB-001` | 2026-11-15 | **Ashley & Keni** · Android App / Home Widget launch (+ NFC `/tap`) | `Bug` · `S1 Daily Pain` | **Shipped & Verified.** Added `ScoopHolderStore` (`shared_preferences`) to persist the device-bound Scoop Holder across cold starts, Widget launches, and NFC `/tap`; updated `FirestoreHouseholdRepository.ensureDefaultHousehold` and `updateMemberName` so Firestore `households/{id}.members[uid].name` syncs without clobbering on cold start; added one-time *"Who holds this phone?"* `ScoopHolderPromptDialog` on unbound devices; and moved Scoop Holder switching into Pack HQ (`OnboardingSheet`) for a cleaner main screen. Verified via `./scripts/verify.sh` (52/52 tests + web release build). |
| `FB-002` | 2026-11-15 | **Keni** · Android Home Widget (OS Dark Theme) | `UX Papercut` · `S1 Daily Pain` | **Shipped & Verified.** Updated `who_fed_snoop_widget_info.xml` to default to compact `2×1` (`targetCellWidth="2"`, `targetCellHeight="1"`, `minWidth="110dp"`, `minHeight="40dp"`) with `horizontal\|vertical` resize; added `onAppWidgetOptionsChanged` + `OPTION_APPWIDGET_MIN_WIDTH` sizing tiers (`COMPACT <190dp`, `MEDIUM 190–259dp`, `WIDE >=260dp`) in `WhoFedSnoopWidgetProvider.kt` and `who_fed_snoop_widget.xml` so status + 1-tap `Feed` pill expands cleanly to `3×1`/`4×1`; added `res/values/colors.xml`, `res/values-night/colors.xml`, and `res/drawable-night/` (`#1C1917` warm charcoal with amber/emerald Neo-Brutalist accents and API 31+ `RemoteViews.setColor` live theme sync). Verified via `./scripts/verify.sh` and Android Gradle (`testDebugUnitTest assembleDebug lintDebug`). |
| `FB-003` | 2026-11-15 | **Keni & Ashley** · Android Home Widget | `Bug` · `S0 Blocker` | **Shipped & Verified.** Implemented Approach (A) with modular Android widget components: wired `com.google.gms.google-services` (`4.4.2`) + Firebase BOM `33.16.0` (`firebase-firestore`, `firebase-auth`) in Gradle; extended `WidgetSyncService` & `MainActivity.kt` to persist `scheduleJson`, `useEmulator`, and treat/window metadata in `WidgetPrefsStore` (`who_fed_snoop_widget_prefs`); added `MealScheduleModel` + `MealWindowResolver` for multi-rollover offline window/treat resolution; added `WidgetFirestoreSync` (`FirebaseApp` + `currentUser != null` guards, optional `10.0.2.2` emulator host, single-doc `households/{id}.get()` 1-read sync via `goAsync()` with 7s timeout); added `WidgetAlarmScheduler` (`AlarmManager.setAndAllowWhileIdle(RTC_WAKEUP, ...)` on `nextTransitionEpochMs`, cancelled in `onDisabled`) + `WidgetBootReceiver` (`BOOT_COMPLETED` / `MY_PACKAGE_REPLACED`); and split `WidgetContentFormatter` out of `WhoFedSnoopWidgetProvider`. Verified via `./scripts/verify.sh` and `./android/gradlew -p android --no-daemon testDebugUnitTest assembleDebug :app:lintDebug`. |
| `FB-005` | 2026-11-15 | **Keni** · Codebase (`lib/`, `test/`) | `Enhancement` · `S2 Polish` | **Shipped & Verified.** Modularized domain, data, ViewModel, UI, and test monoliths into focused ~100–395L single-responsibility files: (1) split `meal_window.dart` into `meal_period.dart`, `meal_schedule.dart`, and `active_meal_window.dart` (with barrel re-export); (2) separated `HouseholdRepository` from `InMemoryHouseholdRepository`, extracted `FirestoreHouseholdMapper` + shared `HouseholdStatePolicy` (deduplicating validation, pruning, join codes, member sync, and `resolveInMemoryUidForName`/`sanitizeName` across repos, `main.dart`, `HouseholdSessionController`, `OnboardingSheet`, and `ScoopHolderPromptDialog`); (3) decomposed `FeederViewModel` into `UndoStackController`, `PartnerActivityDetector`, `DeepLinkCoordinator`, `HouseholdSessionController`, and `FeedingActionsController`; (4) decomposed `snoop_mascot.dart`, `feeder_view.dart`, `onboarding_sheet.dart`, `household_settings_sheet.dart`, and `treat_jar_card.dart` into focused feature widgets and painters; and (5) split the 4 oversized test suites into 9 focused test files plus `test/data/household_state_policy_test.dart` and shared `test/helpers/`, updating `docs/DEVELOPMENT_LOOP.md` §3. Verified via `./scripts/verify.sh` and `./android/gradlew -p android --no-daemon testDebugUnitTest assembleDebug :app:lintDebug`. |
