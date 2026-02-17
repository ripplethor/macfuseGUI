#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/macfuseGui.xcodeproj"
SCHEME="macfuseGui"
CONFIGURATION="${CONFIGURATION:-Debug}"
ARCH_OVERRIDE="${ARCH_OVERRIDE:-arm64}"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
OUTPUT_DIR="$ROOT_DIR/build"
OUTPUT_APP="$OUTPUT_DIR/macfuseGui.app"

mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_APP"

"$ROOT_DIR/scripts/build_libssh2.sh"

XCODEBUILD_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED"
  build
)

if [[ -n "$ARCH_OVERRIDE" ]]; then
  XCODEBUILD_ARGS+=( -destination "platform=macOS,arch=$ARCH_OVERRIDE" )
fi

xcodebuild "${XCODEBUILD_ARGS[@]}"

PRODUCT_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/macfuseGui.app"
if [[ ! -d "$PRODUCT_APP" ]]; then
  echo "Build succeeded but app bundle not found at: $PRODUCT_APP" >&2
  exit 1
fi

ditto "$PRODUCT_APP" "$OUTPUT_APP"
echo "Built: $OUTPUT_APP"
