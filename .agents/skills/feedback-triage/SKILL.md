---
name: feedback-triage
description: >-
  Logs, triages, and tracks user/partner dogfooding bugs, UX papercuts, and feature ideas
  in docs/FEEDBACK_LOG.md and cross-links them to docs/PRODUCTIZATION_GAPS_AND_ROADMAP.md.
  Use whenever the user shares feedback or bug reports (e.g. from Keni or Ashley), asks to
  review what to fix next, or ships an item from the feedback backlog.
---

# Dogfood Feedback & Roadmap Triage Workflow

Follow this workflow whenever Keni relays real-world feedback, bugs, UX friction, or enhancement ideas from using **Who Fed Snoop?** with Ashley—or asks to groom/work through tracked items.

## 1. Read Current State & Deduplicate
1. Read [`docs/FEEDBACK_LOG.md`](../../../docs/FEEDBACK_LOG.md) to find the highest existing `FB-###` ID (never reuse IDs, even across shipped items) and check for duplicates.
2. Scan [`docs/PRODUCTIZATION_GAPS_AND_ROADMAP.md`](../../../docs/PRODUCTIZATION_GAPS_AND_ROADMAP.md) (§2–§4) and relevant source files to identify:
   - Whether the feedback is a **symptom of an already-documented gap** (e.g., missing client `firebase_messaging`, home screen widget not refreshing when partner feeds remotely, local device persistence on web reload, etc.) or a **newly discovered bug / UX issue**.
   - What root cause or code path is involved (`lib/`, `android/`, `functions/`, `web/`, `firestore.rules`).

## 2. Clarify Missing Context (Only If Needed)
If critical reproduction or UX intent is ambiguous, ask 1–2 brief clarifying questions—especially:
- **Who hit it & where:** `Keni` vs. `Ashley` vs. `Both`? Which device/OS and surface (`Android App`, `Home Widget`, `NFC Tap`, `Web`, `Push`, `Pack HQ`)?
- **Expected behavior** (if an enhancement has multiple reasonable UX shapes).

*(Do not block logging if enough context is already clear from the message.)*

## 3. Log & Cross-Link (`docs/FEEDBACK_LOG.md` ↔ Roadmap)
1. Assign the next sequential ID (`FB-001`, `FB-002`, ...) and classify:
   - **Type:** `Bug` | `UX Papercut` | `Enhancement` | `Idea`
   - **Severity:** `S0 Blocker` | `S1 Daily Pain` | `S2 Polish` | `S3 Nice-to-Have`
   - **Recommended Track:**
     - **Dogfood Now** (place in `🔥 Dogfood Queue`): Hurts Keni & Ashley's daily routine and can be fixed cleanly without waiting on full multi-tenant public launch work, *or* pulls forward a focused slice of a roadmap phase just for live household relief.
     - **Phase 0–4 / Parking Lot** (place in `🗺️ Roadmap-Linked Backlog`): Best bundled with an upcoming phase in `docs/PRODUCTIZATION_GAPS_AND_ROADMAP.md`. Add a concise `[FB-###]` bullet or annotation in the matching phase of `docs/PRODUCTIZATION_GAPS_AND_ROADMAP.md` so the roadmap stays complete.
2. Update `docs/FEEDBACK_LOG.md` (remove placeholder `(None yet)` row when adding the first item in a table).

## 4. Present Triage & Ask Before Changing Code (Mandatory Default)
Unless Keni explicitly instructed *"fix this right now"* in the same prompt, **stop before editing application code** and reply concisely with:
1. **Logged Item(s):** `FB-###` summary, severity, and root cause / overlap with known roadmap gaps.
2. **Recommendation:** **Fix Now (Dogfood Fast-Lane)** vs. **Queue in Phase X**, with a 1–2 sentence rationale and proposed modular approach (checking target `wc -l` per [`token-efficient-modularity`](../token-efficient-modularity/SKILL.md) to extend/extract focused modules & test slices while preserving the **2-Second Rule**, Neo-Brutalist `AppTheme`, finite animations, and near-\$0 Firebase guardrails).
3. **Decision Prompt:** Ask whether to **implement the fix now**, **adjust the plan/priority**, or **leave it queued**.

## 5. Ship & Close the Loop (Once Approved)
When Keni says go on an `FB-###` item:
1. Mark status `In Progress` (if multi-step) and implement the fix + behavior-sliced regression test(s) respecting [`AGENTS.md`](../../../AGENTS.md) and [`token-efficient-modularity`](../token-efficient-modularity/SKILL.md) (`150–350L` file budgets, shared policies/helpers, scoped `flutter test <slice> --no-pub -r failures-only` inner loop).
2. Run `./scripts/verify.sh` (and update `docs/DEVELOPMENT_LOOP.md` if stack/config/test files `A/D/R` changed).
3. Move the row from its active queue to **✅ Shipped & Verified** in `docs/FEEDBACK_LOG.md` with the date, summary of fix, and verification status, and update any `[FB-###]` reference in `docs/PRODUCTIZATION_GAPS_AND_ROADMAP.md`.
4. Note whether Keni & Ashley need a **Firebase deploy** (`firebase deploy --only hosting,firestore`) or **fresh APK install** (`flutter build apk --release --split-per-abi`) for the change to take effect on their phones.
