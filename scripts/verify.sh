#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> 1/5 Checking dev-loop documentation sync..."
./scripts/check-dev-docs-sync.sh --check

echo "==> 2/5 Checking Dart formatting (lib/ and test/)..."
dart format --output=none --set-exit-if-changed lib test

echo "==> 3/5 Running Flutter static analysis (--fatal-infos)..."
flutter analyze --fatal-infos

echo "==> 4/5 Running unit and widget test suite..."
flutter test

echo "==> 5/5 Building release web bundle for whofedsnoop.com..."
flutter build web --release

echo "✅ All verification checks passed!"
