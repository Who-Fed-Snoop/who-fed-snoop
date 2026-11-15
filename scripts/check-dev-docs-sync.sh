#!/usr/bin/env bash
# Ensures docs/DEVELOPMENT_LOOP.md stays synced when stack/build/test/deploy configs change.
# Modes: --check (default) | --staged | --agy-stop-hook. Bypass: SKIP_DEV_DOCS_SYNC=1.
set -euo pipefail

MODE="${1:---check}"
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC_FILE="docs/DEVELOPMENT_LOOP.md"

only_pubspec_version_changed() {
  local lines
  lines="$(git diff "$@" -- pubspec.yaml | grep -E '^[+-][^+-]' || true)"
  [[ -z "$lines" ]] || [[ -z "$(printf '%s\n' "$lines" | grep -Ev '^[+-]version:[[:space:]]' || true)" ]]
}

main_env_flags_changed() {
  [[ -n "$(git diff "$@" -- lib/main.dart | grep -E '^[+-][^+-].*(fromEnvironment|useFirestoreEmulator|useAuthEmulator)' || true)" ]]
}

collect_drift() {
  local scope="$1" candidates=() diff_args=("HEAD")
  if [[ "$scope" == "staged" ]]; then
    diff_args=("--cached")
    while IFS= read -r f; do [[ -n "$f" ]] && candidates+=("$f"); done < <(git diff --cached --name-only)
  else
    while IFS= read -r f; do [[ -n "$f" ]] && candidates+=("$f"); done < <(
      { git diff --name-only HEAD 2>/dev/null || true; git ls-files --others --exclude-standard 2>/dev/null || true; } | sort -u
    )
  fi

  local f triggered=()
  for f in "${candidates[@]+"${candidates[@]}"}"; do [[ "$f" == "$DOC_FILE" ]] && return 0; done

  for f in "${candidates[@]+"${candidates[@]}"}"; do
    case "$f" in
      pubspec.yaml)
        if ! only_pubspec_version_changed "${diff_args[@]}"; then triggered+=("$f"); fi ;;
      lib/main.dart)
        if main_env_flags_changed "${diff_args[@]}"; then triggered+=("$f"); fi ;;
      analysis_options.yaml|firebase.json|.firebaserc|firestore.indexes.json|\
      functions/package.json|functions/tsconfig.json|\
      android/build.gradle*|android/settings.gradle*|android/gradle.properties|android/app/build.gradle*|\
      ios/Podfile|ios/Runner.xcodeproj/project.pbxproj|macos/Podfile|macos/Runner.xcodeproj/project.pbxproj|\
      scripts/*|.githooks/*|.github/workflows/*)
        triggered+=("$f") ;;
      test/*_test.dart)
        if [[ "$scope" == "staged" ]]; then
          if git diff --cached --name-status -- "$f" | grep -Eq '^[ADR]'; then triggered+=("$f"); fi
        elif ! git ls-files --error-unmatch "$f" >/dev/null 2>&1 || git diff --name-status HEAD -- "$f" | grep -Eq '^[ADR]'; then
          triggered+=("$f")
        fi ;;
    esac
  done
  if [[ "${#triggered[@]}" -gt 0 ]]; then local IFS=", "; printf '%s' "${triggered[*]}"; fi
}

if [[ "$MODE" == "--agy-stop-hook" ]]; then
  PAYLOAD="$(cat || true)"
  [[ "${SKIP_DEV_DOCS_SYNC:-0}" == "1" ]] && { printf '{"decision":"allow"}\n'; exit 0; }
  ACTIVE="$(python3 -c 'import json,sys; d=json.loads(sys.stdin.read() or "{}"); print("1" if not d.get("continuationActive") and d.get("terminationReason")=="NO_TOOL_CALL" else "0")' <<<"$PAYLOAD" 2>/dev/null || echo 0)"
  [[ "$ACTIVE" != "1" ]] && { printf '{"decision":"allow"}\n'; exit 0; }
  DRIFT="$(collect_drift worktree)"
  if [[ -n "$DRIFT" ]]; then
    python3 -c 'import json,sys; print(json.dumps({"decision":"continue","reason":f"Stack files changed ({sys.argv[1]}) without updating docs/DEVELOPMENT_LOOP.md. Update it (or set SKIP_DEV_DOCS_SYNC=1 if N/A) before finishing."}))' "$DRIFT"
  else
    printf '{"decision":"allow"}\n'
  fi
  exit 0
fi

[[ "${SKIP_DEV_DOCS_SYNC:-0}" == "1" ]] && exit 0
DRIFT="$(collect_drift "$([[ "$MODE" == "--staged" ]] && echo staged || echo worktree)")"
if [[ -n "$DRIFT" ]]; then
  echo "❌ Update $DOC_FILE for changed stack files ($DRIFT), or set SKIP_DEV_DOCS_SYNC=1." >&2
  exit 1
fi
