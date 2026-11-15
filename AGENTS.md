# Who Fed Snoop? — Workspace Agent Rules (`AGENTS.md`)

## 1. Canonical Developer Loop & Verification
- Read [`docs/DEVELOPMENT_LOOP.md`](docs/DEVELOPMENT_LOOP.md) for the authoritative commands to bootstrap, run locally (in-memory, Firebase Emulator, or live), format, lint, test, build, release, and deploy.
- Before finishing code changes, run `./scripts/verify.sh` (or at minimum `dart format lib test`, `flutter analyze --fatal-infos`, and `flutter test`).
- Preserve UI & widget-test invariants:
  - Keep animations finite (`AnimatedSwitcher`, `AnimatedContainer`) so `WidgetTester.pumpAndSettle()` never hangs.
  - Ensure zero `RenderFlex` overflows down to `360×800` portrait and `isCompactHeight` (`< 680`).
- When modifying Cloud Firestore Security Rules ([`firestore.rules`](firestore.rules)), delegate rule authoring to the `firestore-rules-author` subagent when available.

## 2. Mandatory Living Documentation Rule (Auto-Update Dev Loop Docs)
Whenever your changes evolve the project's stack, dependencies, targets, environment flags, test layout, scripts, CI, or Firebase/deployment configuration, you **MUST** update [`docs/DEVELOPMENT_LOOP.md`](docs/DEVELOPMENT_LOOP.md) (and [`README.md`](README.md) if quickstart commands or top-level architecture changed) in the **same task and commit**.

Specifically, update [`docs/DEVELOPMENT_LOOP.md`](docs/DEVELOPMENT_LOOP.md) whenever modifying:
- **Dependencies, SDKs, or Flutter config:** `pubspec.yaml` *(excluding pure `version:` release bumps)*, `analysis_options.yaml`
- **Runtime `--dart-define` / emulator flags:** `String.fromEnvironment` / `bool.fromEnvironment` or emulator ports in `lib/main.dart`
- **Firebase & Backend stack:** `firebase.json`, `.firebaserc`, `firestore.indexes.json`, `functions/package.json`, `functions/tsconfig.json`, or Blaze/Functions deployment state
- **Platform build configs or new targets:** `android/**/build.gradle*`, `android/settings.gradle*`, `ios/**`, `macos/**`, `web/**`
- **Test suites & tooling scripts:** adding/renaming test files under `test/`, editing `scripts/**`, `.githooks/**`, or `.github/workflows/**`

> **Enforcement:** [`.agents/hooks.json`](.agents/hooks.json) (`Stop` hook), [`scripts/verify.sh`](scripts/verify.sh), and [`.githooks/pre-commit`](.githooks/pre-commit) automatically run [`scripts/check-dev-docs-sync.sh`](scripts/check-dev-docs-sync.sh) to verify that stack changes are accompanied by an update to `docs/DEVELOPMENT_LOOP.md`. If a stack manifest change genuinely has zero impact on the developer loop, set `SKIP_DEV_DOCS_SYNC=1` when running `verify.sh` or `git commit`.
