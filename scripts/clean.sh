#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rm -rf "$ROOT_DIR/build"

xcodebuild \
  -project "$ROOT_DIR/macfuseGui.xcodeproj" \
  -scheme macfuseGui \
  clean || true

echo "Clean complete"
