#!/usr/bin/env bash
set -euo pipefail

# scripts/build.sh
# Run from repo root: ./scripts/build.sh
#
# ARCH_OVERRIDE supports arm64|x86_64|both|universal.
# Build both arch apps: ARCH_OVERRIDE=both CONFIGURATION=Release ./scripts/build.sh
# Build x86_64 app only: ARCH_OVERRIDE=x86_64 CONFIGURATION=Debug ./scripts/build.sh
# Dry-run dual-arch release: ARCH_OVERRIDE=both ./scripts/release.sh --dry-run
#
# DerivedData cleanup:
# - By default, this script removes build/DerivedData* after a successful build.
# - Set CLEAN_DERIVED_DATA=0 to keep DerivedData for debugging/incremental investigation.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/macfuseGui.xcodeproj"
SCHEME="macfuseGui"
CONFIGURATION="${CONFIGURATION:-Debug}"
ARCH_OVERRIDE="${ARCH_OVERRIDE:-arm64}"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"
STRIP_RELEASE_BINARY="${STRIP_RELEASE_BINARY:-1}"
CLEAN_DERIVED_DATA="${CLEAN_DERIVED_DATA:-1}"
APP_MARKETING_VERSION="${APP_MARKETING_VERSION:-}"
APP_BUILD_VERSION="${APP_BUILD_VERSION:-}"
OUTPUT_DIR="$ROOT_DIR/build"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-${SCHEME}.app}"
APP_BUNDLE_BASENAME="${APP_BUNDLE_NAME%.app}"
DEFAULT_OUTPUT_APP="$OUTPUT_DIR/$APP_BUNDLE_NAME"
VERSION_FILE="$ROOT_DIR/VERSION"
VERSION_LIB="$ROOT_DIR/scripts/lib/version.sh"

[[ -f "$VERSION_LIB" ]] || {
  echo "Missing version helpers: $VERSION_LIB" >&2
  exit 1
}
# shellcheck source=scripts/lib/version.sh
source "$VERSION_LIB"

normalize_arch() {
  case "$1" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64) echo "x86_64" ;;
    all|universal) echo "universal" ;;
    both) echo "both" ;;
    *)
      echo "Unsupported ARCH_OVERRIDE value: $1 (expected arm64, x86_64, both, or universal)" >&2
      exit 1
      ;;
  esac
}

is_valid_build_version() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]
}

resolve_marketing_version_from_repo() {
  if command -v git >/dev/null 2>&1; then
    local version_from_tag=""
    # Uses local tags only; run `git fetch --tags origin` first if tags may be stale.
    version_from_tag="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null | sed 's/^v//' | sort -V | tail -n 1 || true)"
    if [[ -n "$version_from_tag" ]]; then
      is_valid_semver "$version_from_tag" || {
        echo "Invalid local tag version: $version_from_tag (expected X.Y.Z)" >&2
        exit 1
      }
      echo "$version_from_tag"
      return
    fi
  fi

  local version_from_file=""
  if [[ -f "$VERSION_FILE" ]]; then
    version_from_file="$(tr -d '[:space:]' < "$VERSION_FILE" || true)"
    if [[ -n "$version_from_file" ]]; then
      is_valid_semver "$version_from_file" || {
        echo "Invalid VERSION file value: $version_from_file (expected X.Y.Z)" >&2
        exit 1
      }
      echo "$version_from_file"
      return
    fi
  fi

  echo ""
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

cleanup_derived_data_dirs() {
  local derived_data_paths=("$ROOT_DIR"/build/DerivedData*)
  if [[ ! -e "${derived_data_paths[0]}" ]]; then
    return
  fi

  rm -rf "${derived_data_paths[@]}"
  echo "Removed temporary DerivedData directories under: $ROOT_DIR/build"
}

resolve_bundle_executable_name() {
  local app_bundle="$1"
  local info_plist="$app_bundle/Contents/Info.plist"
  local executable_name=""

  if [[ -f "$info_plist" ]]; then
    executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info_plist" 2>/dev/null || true)"
  fi

  if [[ -z "$executable_name" ]]; then
    executable_name="$(basename "$app_bundle" .app)"
  fi

  echo "$executable_name"
}

verify_app_executable_arch() {
  local app_bundle="$1"
  local expected_arch="$2"
  local executable_name executable_path lipo_info

  executable_name="$(resolve_bundle_executable_name "$app_bundle")"
  executable_path="$app_bundle/Contents/MacOS/$executable_name"

  [[ -f "$executable_path" ]] || {
    echo "App executable not found for arch verification: $executable_path" >&2
    exit 1
  }

  lipo_info="$(lipo -info "$executable_path" 2>&1 || true)"
  if [[ -z "$lipo_info" ]]; then
    lipo_info="$(file "$executable_path" 2>&1 || true)"
  fi

  case "$expected_arch" in
    arm64)
      if [[ "$lipo_info" != *"arm64"* || "$lipo_info" == *"x86_64"* ]]; then
        echo "Arch verification failed for $app_bundle. Expected arm64-only executable, got: $lipo_info" >&2
        exit 1
      fi
      ;;
    x86_64)
      if [[ "$lipo_info" != *"x86_64"* || "$lipo_info" == *"arm64"* ]]; then
        echo "Arch verification failed for $app_bundle. Expected x86_64-only executable, got: $lipo_info" >&2
        exit 1
      fi
      ;;
    universal)
      if [[ "$lipo_info" != *"arm64"* || "$lipo_info" != *"x86_64"* ]]; then
        echo "Arch verification failed for $app_bundle. Expected universal executable with arm64 and x86_64, got: $lipo_info" >&2
        exit 1
      fi
      ;;
    *)
      echo "Unsupported arch verification target: $expected_arch" >&2
      exit 1
      ;;
  esac
}

strip_app_executable_if_enabled() {
  local app_bundle="$1"
  local executable_name executable_path

  if [[ "$CONFIGURATION" != "Release" || "$STRIP_RELEASE_BINARY" != "1" ]]; then
    return
  fi
  if [[ "$CODE_SIGNING_ALLOWED" == "YES" ]]; then
    echo "Skipping release strip for signed build: $app_bundle"
    return
  fi

  executable_name="$(resolve_bundle_executable_name "$app_bundle")"
  executable_path="$app_bundle/Contents/MacOS/$executable_name"
  [[ -f "$executable_path" ]] || {
    echo "App executable not found for strip step: $executable_path" >&2
    exit 1
  }

  # Strip before sign: safe here because unsigned build paths use CODE_SIGNING_ALLOWED=NO.
  # Signed builds skip this step entirely (see guard above).
  local strip_output=""
  if ! strip_output="$(strip -Sx "$executable_path" 2>&1)"; then
    echo "Warning: strip failed for $app_bundle; continuing with unstripped binary."
    echo "$strip_output"
  fi
}

ad_hoc_sign_app_if_needed() {
  local app_bundle="$1"

  if [[ "$CODE_SIGNING_ALLOWED" == "YES" ]]; then
    return
  fi

  codesign --force --deep --sign - "$app_bundle"
  if ! codesign --verify --deep --strict --verbose=2 "$app_bundle" >/dev/null 2>&1; then
    echo "Ad-hoc signing verification failed: $app_bundle" >&2
    exit 1
  fi
}

run_xcodebuild_for_arch() {
  local arch="$1"
  shift

  # Requires Rosetta 2 on Apple Silicon for x86_64 builds.
  if [[ "$arch" == "x86_64" && "$(uname -m)" == "arm64" ]]; then
    arch -x86_64 xcodebuild "$@"
  else
    xcodebuild "$@"
  fi
}

sync_legacy_third_party_paths() {
  local third_party_suffix="$1"
  local openssl_arch_root="$ROOT_DIR/build/third_party/openssl-$third_party_suffix"
  local libssh2_arch_root="$ROOT_DIR/build/third_party/libssh2-$third_party_suffix"
  local openssl_legacy_root="$ROOT_DIR/build/third_party/openssl"
  local libssh2_legacy_root="$ROOT_DIR/build/third_party/libssh2"

  if [[ ! -d "$openssl_arch_root" || ! -d "$libssh2_arch_root" ]]; then
    echo "Expected arch-specific third-party roots were not found: $openssl_arch_root and $libssh2_arch_root" >&2
    exit 1
  fi

  rm -rf "$openssl_legacy_root" "$libssh2_legacy_root"
  ln -s "$openssl_arch_root" "$openssl_legacy_root"
  ln -s "$libssh2_arch_root" "$libssh2_legacy_root"
}

build_single_variant() {
  local build_arch="$1"
  local output_app="$2"
  local derived_data="$3"
  local third_party_suffix="$4"
  local product_app
  local openssl_include openssl_lib libssh2_include libssh2_lib

  openssl_include="$ROOT_DIR/build/third_party/openssl-$third_party_suffix/include"
  openssl_lib="$ROOT_DIR/build/third_party/openssl-$third_party_suffix/lib"
  libssh2_include="$ROOT_DIR/build/third_party/libssh2-$third_party_suffix/include"
  libssh2_lib="$ROOT_DIR/build/third_party/libssh2-$third_party_suffix/lib"

  ARCH_OVERRIDE="$build_arch" "$ROOT_DIR/scripts/build_libssh2.sh"
  sync_legacy_third_party_paths "$third_party_suffix"

  local xcodebuild_args=(
    -project "$PROJECT_PATH"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -derivedDataPath "$derived_data"
    HEADER_SEARCH_PATHS="\$(inherited) $openssl_include $libssh2_include"
    LIBRARY_SEARCH_PATHS="\$(inherited) $openssl_lib $libssh2_lib"
    CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED"
    build
  )

  if [[ -n "$APP_MARKETING_VERSION" ]]; then
    is_valid_semver "$APP_MARKETING_VERSION" || {
      echo "Invalid APP_MARKETING_VERSION: $APP_MARKETING_VERSION (expected X.Y.Z)" >&2
      exit 1
    }
    xcodebuild_args+=( "MARKETING_VERSION=$APP_MARKETING_VERSION" )
  fi

  if [[ -n "$APP_BUILD_VERSION" ]]; then
    is_valid_build_version "$APP_BUILD_VERSION" || {
      echo "Invalid APP_BUILD_VERSION: $APP_BUILD_VERSION (expected digits or dot-separated digits)" >&2
      exit 1
    }
    xcodebuild_args+=( "CURRENT_PROJECT_VERSION=$APP_BUILD_VERSION" )
  fi

  case "$build_arch" in
    arm64|x86_64)
      xcodebuild_args+=( ARCHS="$build_arch" ONLY_ACTIVE_ARCH=YES )
      xcodebuild_args+=( -destination "platform=macOS,arch=$build_arch" )
      ;;
    universal)
      xcodebuild_args+=( ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO )
      xcodebuild_args+=( -destination "generic/platform=macOS" )
      ;;
    *)
      echo "Unsupported build arch: $build_arch" >&2
      exit 1
      ;;
  esac

  run_xcodebuild_for_arch "$build_arch" "${xcodebuild_args[@]}"

  product_app="$derived_data/Build/Products/$CONFIGURATION/$APP_BUNDLE_NAME"
  if [[ ! -d "$product_app" ]]; then
    echo "Build succeeded but app bundle not found at: $product_app" >&2
    exit 1
  fi

  rm -rf "$output_app"
  ditto "$product_app" "$output_app"
  strip_app_executable_if_enabled "$output_app"
  ad_hoc_sign_app_if_needed "$output_app"
  verify_app_executable_arch "$output_app" "$build_arch"
  echo "Built: $output_app"
}

ARCH_OVERRIDE="$(normalize_arch "$ARCH_OVERRIDE")"

for cmd in xcodebuild codesign ditto lipo strip stat awk sed sort tail find xargs; do
  require_cmd "$cmd"
done
[[ -x /usr/libexec/PlistBuddy ]] || {
  echo "Missing required command: /usr/libexec/PlistBuddy" >&2
  exit 1
}

build_started_at="$(date)"
build_started_epoch="$(date +%s)"
echo "Build started: $build_started_at"

if [[ -z "$APP_MARKETING_VERSION" ]]; then
  APP_MARKETING_VERSION="$(resolve_marketing_version_from_repo)"
fi
if [[ -n "$APP_MARKETING_VERSION" && -z "$APP_BUILD_VERSION" ]]; then
  APP_BUILD_VERSION="$(semver_to_build_number "$APP_MARKETING_VERSION")"
fi

mkdir -p "$OUTPUT_DIR"

if [[ -n "$APP_MARKETING_VERSION" ]]; then
  echo "Using app version: $APP_MARKETING_VERSION"
fi
if [[ -n "$APP_BUILD_VERSION" ]]; then
  echo "Using build number: $APP_BUILD_VERSION"
fi

case "$ARCH_OVERRIDE" in
  arm64)
    build_single_variant "arm64" "$DEFAULT_OUTPUT_APP" "$ROOT_DIR/build/DerivedData-arm64" "arm64"
    ;;
  x86_64)
    build_single_variant "x86_64" "$DEFAULT_OUTPUT_APP" "$ROOT_DIR/build/DerivedData-x86_64" "x86_64"
    ;;
  universal)
    build_single_variant "universal" "$DEFAULT_OUTPUT_APP" "$ROOT_DIR/build/DerivedData-universal" "universal"
    ;;
  both)
    rm -rf "$OUTPUT_DIR/$APP_BUNDLE_BASENAME-arm64.app" "$OUTPUT_DIR/$APP_BUNDLE_BASENAME-x86_64.app"
    # Note: both builds are intentionally sequential. sync_legacy_third_party_paths
    # rewrites shared compatibility symlinks and would race in parallel.
    build_single_variant "arm64" "$OUTPUT_DIR/$APP_BUNDLE_BASENAME-arm64.app" "$ROOT_DIR/build/DerivedData-arm64" "arm64"
    build_single_variant "x86_64" "$OUTPUT_DIR/$APP_BUNDLE_BASENAME-x86_64.app" "$ROOT_DIR/build/DerivedData-x86_64" "x86_64"
    ;;
  *)
    echo "Unsupported ARCH_OVERRIDE value: $ARCH_OVERRIDE" >&2
    exit 1
    ;;
esac

build_finished_at="$(date)"
build_finished_epoch="$(date +%s)"
echo "Build finished: $build_finished_at (elapsed $((build_finished_epoch - build_started_epoch))s)"

if [[ "$CLEAN_DERIVED_DATA" == "1" ]]; then
  cleanup_derived_data_dirs
fi
