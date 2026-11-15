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
| `FB-003` | 2026-11-15 | **Keni & Ashley** · Android Home Widget | `Bug` · `S0 Blocker` | `Triaged` | **Home Widget stays stale until tapped/opened.** `WhoFedSnoopWidgetProvider` only reads local `SharedPreferences` pushed while the local Flutter UI is open—it never fetches remote Firestore updates when a partner feeds from *their* phone, and window transitions rely on coarse 30m OS ticks. **Fix:** (A) Add native Kotlin `FirebaseFirestore` single-doc `get()` (`households/{id}`, 1 read) on widget `onUpdate` + exact/inexact window-cutoff alarm (`nextTransitionEpochMs`); and/or (B) pull forward Phase 1.1/1.3 FCM silent data push so partner feeds update the widget in `<2s`. *(Overlaps Phase 1.3)* |

---

## 🗺️ Roadmap-Linked Backlog (`Phase 0` – `Phase 4` & `Parking Lot`)

*Feedback items that belong in a broader productization phase in [`PRODUCTIZATION_GAPS_AND_ROADMAP.md`](./PRODUCTIZATION_GAPS_AND_ROADMAP.md) or future exploration.*

| ID | Date | Source & Context | Type & Severity | Target Phase | Status | Summary & Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `FB-004` | 2026-11-15 | **Keni** · App (General) | `Idea` · `S3 Nice-to-Have` | `Phase 4 (End)` | `Triaged` | **Optional Poop / Potty Tracking.** Useful partner/sitter coordination signal (*"Did Snoop poop on the morning walk?"* / tummy health tracking). Keep opt-in in Household Settings so the primary 2-Second meal button stays uncluttered, with denormalized `lastPoop` / `todayPoopCount` inside `households/{id}` (`0` extra default Firestore reads) and optional `✅ Normal` / `⚠️ Soft` tag + 10s LIFO Undo. |
| `FB-005` | 2026-11-15 | **Keni** · Codebase (`lib/`, `test/`) | `Enhancement` · `S2 Polish` | `Pre-Phase 0 (Fast-Lane)` | `Triaged` | **Modularize large files, clean up code smells & apply pragmatic design patterns for token efficiency.** Six `lib/` files now span 788–1,268 lines (`feeder_view.dart` 1,268L, `feeder_view_model.dart` 1,157L, `household_settings_sheet.dart` 1,021L, `snoop_mascot.dart` 999L, `onboarding_sheet.dart` 863L, `treat_jar_card.dart` 788L) alongside 513–766L test files and 660L+ dual repositories—inflating agent token reads/edits and parallel-worker merge contention. **Proposed Plan (~150–350L target/file, zero boilerplate bloat):** (1) *God ViewModel → Thin Facade + Coordinators:* extract `UndoStackController` (Command/LIFO timer), `DeepLinkCoordinator` (Strategy/Router for `/tap`, `/join`, `/s`), and `PartnerActivityDetector` from `FeederViewModel`; (2) *Co-located UI Monoliths → Feature `widgets/` & Painters:* split hero card, belly-log history, banners/undo bar, custom treat sheet, settings cards/dialogs, and mascot painters (`snoop_cartoon_painter.dart`, `snoop_mini_avatar.dart`, `comic_speech_bubble.dart`) + shared Neo-Brutalist primitives; (3) *Duplicated Repo Logic → Shared Policy & Mapper:* split `HouseholdRepository` contract from `InMemoryHouseholdRepository` and centralize join-code, input validation, and `lastFeeding`/`todayMeals`/`todayTreats` state-transition rules shared with `FirestoreHouseholdRepository`; (4) split `meal_window.dart` (657L) and monolithic test suites by behavior slice (updating `docs/DEVELOPMENT_LOOP.md` when test files change). |

---

## ✅ Shipped & Verified

*Completed dogfood fixes and enhancements.*

| ID | Shipped | Source & Context | Type | Resolution & Verification |
| :--- | :--- | :--- | :--- | :--- |
| `FB-001` | 2026-11-15 | **Ashley & Keni** · Android App / Home Widget launch (+ NFC `/tap`) | `Bug` · `S1 Daily Pain` | **Shipped & Verified.** Added `ScoopHolderStore` (`shared_preferences`) to persist the device-bound Scoop Holder across cold starts, Widget launches, and NFC `/tap`; updated `FirestoreHouseholdRepository.ensureDefaultHousehold` and `updateMemberName` so Firestore `households/{id}.members[uid].name` syncs without clobbering on cold start; added one-time *"Who holds this phone?"* `ScoopHolderPromptDialog` on unbound devices; and moved Scoop Holder switching into Pack HQ (`OnboardingSheet`) for a cleaner main screen. Verified via `./scripts/verify.sh` (52/52 tests + web release build). |
| `FB-002` | 2026-11-15 | **Keni** · Android Home Widget (OS Dark Theme) | `UX Papercut` · `S1 Daily Pain` | **Shipped & Verified.** Updated `who_fed_snoop_widget_info.xml` to default to compact `2×1` (`targetCellWidth="2"`, `targetCellHeight="1"`, `minWidth="110dp"`, `minHeight="40dp"`) with `horizontal\|vertical` resize; added `onAppWidgetOptionsChanged` + `OPTION_APPWIDGET_MIN_WIDTH` sizing tiers (`COMPACT <190dp`, `MEDIUM 190–259dp`, `WIDE >=260dp`) in `WhoFedSnoopWidgetProvider.kt` and `who_fed_snoop_widget.xml` so status + 1-tap `Feed` pill expands cleanly to `3×1`/`4×1`; added `res/values/colors.xml`, `res/values-night/colors.xml`, and `res/drawable-night/` (`#1C1917` warm charcoal with amber/emerald Neo-Brutalist accents and API 31+ `RemoteViews.setColor` live theme sync). Verified via `./scripts/verify.sh` and Android Gradle (`testDebugUnitTest assembleDebug lintDebug`). |
