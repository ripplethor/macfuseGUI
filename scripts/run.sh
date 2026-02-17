#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/build/macfuseGui.app"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  "$ROOT_DIR/scripts/build.sh"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at $APP_PATH" >&2
  exit 1
fi

# Ensure we run the freshly built binary, not a previously running process.
pkill -x "macfuseGui" >/dev/null 2>&1 || true
sleep 0.4

open "$APP_PATH"
echo "Launched: $APP_PATH"
