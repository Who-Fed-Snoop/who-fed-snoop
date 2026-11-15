#!/usr/bin/env bash
# Verifies that docs/DEVELOPMENT_LOOP.md is updated whenever stack, build, test-suite,
# script, CI, or Firebase/platform configuration files evolve.
#
# Modes:
#   ./scripts/check-dev-docs-sync.sh --check          (working tree + index vs HEAD; used by verify.sh)
#   ./scripts/check-dev-docs-sync.sh --staged         (staged index vs HEAD; used by .githooks/pre-commit)
#   ./scripts/check-dev-docs-sync.sh --agy-stop-hook  (Antigravity Stop hook JSON stdin/stdout contract)
#
# Bypass for genuine non-dev-loop tweaks:
#   SKIP_DEV_DOCS_SYNC=1 ./scripts/verify.sh
#   SKIP_DEV_DOCS_SYNC=1 git commit ...

set -euo pipefail

MODE="${1:---check}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DOC_FILE="docs/DEVELOPMENT_LOOP.md"

is_only_pubspec_version_bump() {
  local diff_args=("$@")
  local changed_lines
  changed_lines="$(git diff "${diff_args[@]}" -- pubspec.yaml | grep -E '^[+-][^+-]' || true)"
  if [[ -z "$changed_lines" ]]; then
    return 0
  fi
  local non_version_lines
  non_version_lines="$(printf '%s\n' "$changed_lines" | grep -Ev '^[+-]version:[[:space:]]' || true)"
  [[ -z "$non_version_lines" ]]
}

has_main_env_flag_change() {
  local diff_args=("$@")
  local env_lines
  env_lines="$(git diff "${diff_args[@]}" -- lib/main.dart | grep -E '^[+-][^+-].*(fromEnvironment|useFirestoreEmulator|useAuthEmulator)' || true)"
  [[ -n "$env_lines" ]]
}

collect_changed_stack_files() {
  local scope="$1"
  local candidates=()
  local diff_args=()

  if [[ "$scope" == "staged" ]]; then
    diff_args=("--cached")
    while IFS= read -r line; do
      [[ -n "$line" ]] && candidates+=("$line")
    done < <(git diff --cached --name-only)
  else
    diff_args=("HEAD")
    while IFS= read -r line; do
      [[ -n "$line" ]] && candidates+=("$line")
    done < <(
      {
        git diff --name-only HEAD 2>/dev/null || true
        git ls-files --others --exclude-standard 2>/dev/null || true
      } | sort -u
    )
  fi

  # If docs/DEVELOPMENT_LOOP.md itself is already modified/staged, sync is satisfied.
  local f
  for f in "${candidates[@]+"${candidates[@]}"}"; do
    if [[ "$f" == "$DOC_FILE" ]]; then
      return 0
    fi
  done

  local triggered=()
  for f in "${candidates[@]+"${candidates[@]}"}"; do
    case "$f" in
      pubspec.yaml)
        if ! is_only_pubspec_version_bump "${diff_args[@]}"; then
          triggered+=("$f")
        fi
        ;;
      lib/main.dart)
        if has_main_env_flag_change "${diff_args[@]}"; then
          triggered+=("$f (--dart-define/emulator)")
        fi
        ;;
      analysis_options.yaml|\
      firebase.json|.firebaserc|firestore.indexes.json|\
      functions/package.json|functions/tsconfig.json|\
      android/build.gradle*|android/settings.gradle*|android/gradle.properties|android/app/build.gradle*|\
      ios/Podfile|ios/Runner.xcodeproj/project.pbxproj|\
      macos/Podfile|macos/Runner.xcodeproj/project.pbxproj|\
      scripts/*|.githooks/*|.github/workflows/*)
        triggered+=("$f")
        ;;
      test/*_test.dart)
        # Only trigger on added/deleted/renamed test suite files (which affect the Test Suite Map).
        if [[ "$scope" == "staged" ]]; then
          if git diff --cached --name-status -- "$f" | grep -Eq '^[ADR]'; then
            triggered+=("$f (suite added/removed)")
          fi
        else
          if ! git ls-files --error-unmatch "$f" >/dev/null 2>&1 || \
             git diff --name-status HEAD -- "$f" | grep -Eq '^[ADR]'; then
            triggered+=("$f (suite added/removed)")
          fi
        fi
        ;;
    esac
  done

  if [[ "${#triggered[@]}" -gt 0 ]]; then
    local IFS=", "
    printf '%s' "${triggered[*]}"
  fi
}

if [[ "$MODE" == "--agy-stop-hook" ]]; then
  PAYLOAD="$(cat || true)"

  if [[ "${SKIP_DEV_DOCS_SYNC:-0}" == "1" ]]; then
    printf '{"decision":"allow"}\n'
    exit 0
  fi

  SHOULD_CHECK="$(
    python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("no")
    sys.exit(0)
try:
    data = json.loads(raw)
except Exception:
    print("no")
    sys.exit(0)
if data.get("continuationActive", False):
    print("no")
elif data.get("terminationReason", "") != "NO_TOOL_CALL":
    print("no")
else:
    print("yes")
' <<<"$PAYLOAD"
  )"

  if [[ "$SHOULD_CHECK" != "yes" ]]; then
    printf '{"decision":"allow"}\n'
    exit 0
  fi

  DRIFT_FILES="$(collect_changed_stack_files "worktree")"
  if [[ -n "$DRIFT_FILES" ]]; then
    python3 -c '
import json, sys
files = sys.argv[1]
msg = (
    f"Stack/build/tooling files changed ({files}) without updating docs/DEVELOPMENT_LOOP.md. "
    "Please review docs/DEVELOPMENT_LOOP.md (and README.md if quickstart commands changed), "
    "update any affected sections so our dev-loop documentation stays synchronized with the stack, "
    "and then finish."
)
print(json.dumps({"decision": "continue", "reason": msg}))
' "$DRIFT_FILES"
    exit 0
  fi

  printf '{"decision":"allow"}\n'
  exit 0
fi

if [[ "${SKIP_DEV_DOCS_SYNC:-0}" == "1" ]]; then
  echo "ℹ️  Skipping dev-loop docs sync check (SKIP_DEV_DOCS_SYNC=1)."
  exit 0
fi

SCOPE="worktree"
if [[ "$MODE" == "--staged" ]]; then
  SCOPE="staged"
fi

DRIFT_FILES="$(collect_changed_stack_files "$SCOPE")"
if [[ -n "$DRIFT_FILES" ]]; then
  echo "❌ Dev-loop documentation drift detected!" >&2
  echo "   Changed stack/tooling files: $DRIFT_FILES" >&2
  echo "   Update $DOC_FILE (and README.md if applicable) to reflect stack changes," >&2
  echo "   or bypass with SKIP_DEV_DOCS_SYNC=1 if no dev-loop commands/configs changed." >&2
  exit 1
fi

echo "✅ Dev-loop documentation ($DOC_FILE) is in sync with stack configs."
