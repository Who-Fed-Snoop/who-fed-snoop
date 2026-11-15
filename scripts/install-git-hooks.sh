#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

chmod +x scripts/*.sh .githooks/pre-commit
git config core.hooksPath .githooks
echo "✅ Installed repository git hooks (core.hooksPath -> .githooks)."
