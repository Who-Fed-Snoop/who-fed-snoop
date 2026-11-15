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
| `FB-001` | 2026-11-15 | **Ashley & Keni** · Android App / Home Widget launch (+ NFC `/tap`) | `Bug` · `S1 Daily Pain` | `Triaged` | **Default Scoop Holder resets to Keni on Ashley's phone.** `main.dart` hardcodes `ensureDefaultHousehold(..., memberName: 'Keni')` and `FeederViewModel(initialMemberName: 'Keni')`, while `switchActiveMember` only mutates RAM. **Agreed UX & Fix:** Prompt *"Who holds this phone?"* once on unbound devices, persist locally (`shared_preferences`) + sync `households/{id}.members[uid].name` in Firestore (never clobbering on cold start), and move Scoop Holder switching into **Pack HQ** for a cleaner main screen with no accidental taps. *(Overlaps Phase 0.1)* |
| `FB-002` | 2026-11-15 | **Keni** · Android Home Widget (OS Dark Theme) | `UX Papercut` · `S1 Daily Pain` | `Triaged` | **Home Widget uses too much real estate (`4×1`) & clashes with OS Dark Theme.** `who_fed_snoop_widget_info.xml` forces `targetCellWidth="4"` (`250dp` wide) and `widget_background_*.xml` hardcodes bright light pastels (`#FFFBEB` / `#ECFDF5`) with dark ink. **Agreed UX & Fix:** Default to a **compact `2×1` pill** (status + 1-tap Feed pill) that smoothly expands details when resized wider (`3×1` / `4×1`), plus `res/values-night` + `res/drawable-night` OS Dark Theme surfaces (`#1C1917` warm charcoal with amber/emerald Neo-Brutalist accents). |
| `FB-003` | 2026-11-15 | **Keni & Ashley** · Android Home Widget | `Bug` · `S0 Blocker` | `Triaged` | **Home Widget stays stale until tapped/opened.** `WhoFedSnoopWidgetProvider` only reads local `SharedPreferences` pushed while the local Flutter UI is open—it never fetches remote Firestore updates when a partner feeds from *their* phone, and window transitions rely on coarse 30m OS ticks. **Fix:** (A) Add native Kotlin `FirebaseFirestore` single-doc `get()` (`households/{id}`, 1 read) on widget `onUpdate` + exact/inexact window-cutoff alarm (`nextTransitionEpochMs`); and/or (B) pull forward Phase 1.1/1.3 FCM silent data push so partner feeds update the widget in `<2s`. *(Overlaps Phase 1.3)* |

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
| *(None yet)* | — | — | — | — |
