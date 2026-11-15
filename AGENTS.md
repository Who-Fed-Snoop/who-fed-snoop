# Who Fed Snoop? — Agent Rules

- **Verify:** `./scripts/verify.sh` (fast inner loop: `dart format lib test && flutter analyze --no-pub --fatal-infos && flutter test --no-pub -r failures-only`).
- **Run flags:** `--dart-define=USE_IN_MEMORY_REPO=true` (offline) | `--dart-define=USE_FIREBASE_EMULATOR=true` (Auth `:9099`, Firestore `:8080`).
- **UI invariants:** Finite animations only (`pumpAndSettle()` safe); zero `RenderFlex` overflow at `360×800` and height `<680`.
- **Firestore rules:** Delegate `firestore.rules` edits to `firestore-rules-author` subagent when available.
- **Feedback & Roadmap:** Track Keni/Ashley dogfood bugs & ideas in `docs/FEEDBACK_LOG.md` cross-linked to `docs/PRODUCTIZATION_GAPS_AND_ROADMAP.md` (use `feedback-triage` skill: log & triage first, propose *Dogfood Now* vs. *Phase 0–4*, and confirm before changing code).
- **Runbook & Living Docs:** Read `docs/DEVELOPMENT_LOOP.md` only when releasing, deploying, or changing stack/build setup. Update it in the same commit whenever dependencies, flags, Firebase/build configs, targets, scripts, or test files (`A/D/R`) change (enforced by `.agents/hooks.json`, `.githooks/pre-commit`, and `verify.sh`; set `SKIP_DEV_DOCS_SYNC=1` if N/A).
