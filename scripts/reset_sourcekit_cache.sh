#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Stopping SourceKit-LSP processes (if running)..."
pkill -f "[s]ourcekit-lsp" >/dev/null 2>&1 || true

echo "Stopping VS Code helper processes that may hold stale diagnostics..."
pkill -f "[C]ode Helper (Plugin)" >/dev/null 2>&1 || true

echo "Removing project SourceKit/SwiftPM index caches..."
rm -rf "$ROOT_DIR/.build/index-build"
rm -rf "$ROOT_DIR/.build/arm64-apple-macosx/debug/index"
rm -rf "$ROOT_DIR/.build/arm64-apple-macosx/debug/ModuleCache"
rm -rf "$ROOT_DIR/.build/x86_64-apple-macosx/debug/index"
rm -rf "$ROOT_DIR/.build/x86_64-apple-macosx/debug/ModuleCache"

echo "Removing project DerivedData index/module caches..."
rm -rf "$ROOT_DIR/build/DerivedData/Index.noindex"
rm -rf "$ROOT_DIR/build/DerivedData/ModuleCache.noindex"
rm -rf "$ROOT_DIR/build/DerivedData/SDKStatCaches.noindex"
rm -rf "$ROOT_DIR/build/DerivedData/Build/Intermediates.noindex"

for global_cache in \
  "$HOME/Library/Caches/org.swift.sourcekit-lsp" \
  "$HOME/Library/Caches/sourcekit-lsp" \
  "$HOME/.sourcekit-lsp"; do
  if [[ -e "$global_cache" ]]; then
    echo "Removing global SourceKit cache: $global_cache"
    rm -rf "$global_cache"
  fi
done

WORKSPACE_STORAGE="$HOME/Library/Application Support/Code/User/workspaceStorage"
ROOT_URI="file://$ROOT_DIR"
if [[ -d "$WORKSPACE_STORAGE" ]]; then
  while IFS= read -r workspace_json; do
    storage_dir="$(dirname "$workspace_json")"
    echo "Removing VS Code workspace storage for this repo: $storage_dir"
    rm -rf "$storage_dir"
  done < <(rg -l --fixed-strings "\"folder\": \"$ROOT_URI\"" "$WORKSPACE_STORAGE" --glob "**/workspace.json" 2>/dev/null || true)
fi

for extension_storage in \
  "$HOME/Library/Application Support/Code/User/globalStorage/swiftlang.swift-vscode" \
  "$HOME/Library/Application Support/Code/User/globalStorage/swift.sourcekit-lsp"; do
  if [[ -e "$extension_storage" ]]; then
    echo "Removing VS Code Swift extension storage: $extension_storage"
    rm -rf "$extension_storage"
  fi
done

echo "Repriming SwiftPM package graph..."
swift package describe >/dev/null

echo "SourceKit cache reset complete."
echo "Next in VS Code:"
echo "  1) Re-open folder: $ROOT_DIR"
echo "  2) Cmd+Shift+P -> Developer: Reload Window"
echo "  3) Cmd+Shift+P -> Swift: Restart LSP Server"
echo "  4) Cmd+Shift+P -> Swift: Re-Index Project"
