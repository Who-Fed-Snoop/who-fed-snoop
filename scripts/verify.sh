#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f .dart_tool/package_config.json ]] || flutter pub get

echo "==> [1/5] Docs sync"
./scripts/check-dev-docs-sync.sh --check

echo "==> [2/5] Format"
dart format --output=none --set-exit-if-changed lib test

echo "==> [3/5] Analyze"
flutter analyze --no-pub --fatal-infos

echo "==> [4/5] Test"
flutter test --no-pub --reporter failures-only

echo "==> [5/5] Web release build"
flutter build web --release --no-pub --no-wasm-dry-run

echo "✅ Verify passed."
