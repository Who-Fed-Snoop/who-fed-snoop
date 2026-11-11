#!/usr/bin/env bash
set -euo pipefail

echo "==> 1/4 Checking Dart formatting (lib/ and test/)..."
dart format --output=none --set-exit-if-changed lib test

echo "==> 2/4 Running Flutter static analysis (--fatal-infos)..."
flutter analyze --fatal-infos

echo "==> 3/4 Running unit and widget test suite..."
flutter test

echo "==> 4/4 Building release web bundle for whofedsnoop.com..."
flutter build web --release

echo "✅ All verification checks passed!"
