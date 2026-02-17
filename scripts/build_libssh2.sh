#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBSSH2_VERSION="${LIBSSH2_VERSION:-1.11.1}"
OPENSSL_VERSION="${OPENSSL_VERSION:-3.0.17}"
MACOS_MIN_VERSION="${MACOS_MIN_VERSION:-13.0}"
ARCH_OVERRIDE_VALUE="${ARCH_OVERRIDE:-arm64}"

LIBSSH2_URL="https://www.libssh2.org/download/libssh2-${LIBSSH2_VERSION}.tar.gz"
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"

SOURCE_ROOT="$ROOT_DIR/third_party/src"
LIBSSH2_TARBALL="$SOURCE_ROOT/libssh2-${LIBSSH2_VERSION}.tar.gz"
OPENSSL_TARBALL="$SOURCE_ROOT/openssl-${OPENSSL_VERSION}.tar.gz"

LIBSSH2_OUTPUT_ROOT="$ROOT_DIR/build/third_party/libssh2"
LIBSSH2_OUTPUT_INCLUDE="$LIBSSH2_OUTPUT_ROOT/include"
LIBSSH2_OUTPUT_LIB="$LIBSSH2_OUTPUT_ROOT/lib"

OPENSSL_OUTPUT_ROOT="$ROOT_DIR/build/third_party/openssl"
OPENSSL_OUTPUT_INCLUDE="$OPENSSL_OUTPUT_ROOT/include"
OPENSSL_OUTPUT_LIB="$OPENSSL_OUTPUT_ROOT/lib"

BUILD_ROOT="$ROOT_DIR/build/third_party/source-build"
BUILD_INFO_FILE="$LIBSSH2_OUTPUT_ROOT/BUILD-INFO.txt"

mkdir -p "$SOURCE_ROOT" "$LIBSSH2_OUTPUT_INCLUDE" "$LIBSSH2_OUTPUT_LIB" "$OPENSSL_OUTPUT_INCLUDE" "$OPENSSL_OUTPUT_LIB"

normalize_arch() {
  case "$1" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64) echo "x86_64" ;;
    all|universal) echo "universal" ;;
    *) echo "$1" ;;
  esac
}

ARCH_OVERRIDE_VALUE="$(normalize_arch "$ARCH_OVERRIDE_VALUE")"
case "$ARCH_OVERRIDE_VALUE" in
  universal)
    ARCHES=(arm64 x86_64)
    ;;
  arm64|x86_64)
    ARCHES=("$ARCH_OVERRIDE_VALUE")
    ;;
  *)
    echo "Unsupported ARCH_OVERRIDE value: $ARCH_OVERRIDE_VALUE (expected arm64, x86_64, or universal)" >&2
    exit 1
    ;;
esac

ARCH_FINGERPRINT="$(IFS=,; echo "${ARCHES[*]}")"
EXPECTED_FINGERPRINT="libssh2=${LIBSSH2_VERSION};openssl=${OPENSSL_VERSION};min=${MACOS_MIN_VERSION};archs=${ARCH_FINGERPRINT}"

have_cached_outputs() {
  [[ -f "$BUILD_INFO_FILE" ]] &&
    grep -Fq "fingerprint=$EXPECTED_FINGERPRINT" "$BUILD_INFO_FILE" &&
    [[ -f "$LIBSSH2_OUTPUT_LIB/libssh2.a" ]] &&
    [[ -f "$OPENSSL_OUTPUT_LIB/libcrypto.a" ]] &&
    [[ -d "$LIBSSH2_OUTPUT_INCLUDE" ]] &&
    [[ -d "$OPENSSL_OUTPUT_INCLUDE" ]]
}

download_if_missing() {
  local tarball="$1"
  local url="$2"
  if [[ -f "$tarball" ]]; then
    return
  fi
  echo "Downloading $(basename "$tarball")..."
  curl -fsSL "$url" -o "$tarball"
}

openssl_target_for_arch() {
  case "$1" in
    arm64) echo "darwin64-arm64-cc" ;;
    x86_64) echo "darwin64-x86_64-cc" ;;
    *)
      echo "Unsupported OpenSSL arch: $1" >&2
      exit 1
      ;;
  esac
}

libssh2_host_for_arch() {
  case "$1" in
    arm64) echo "aarch64-apple-darwin" ;;
    x86_64) echo "x86_64-apple-darwin" ;;
    *)
      echo "Unsupported libssh2 arch: $1" >&2
      exit 1
      ;;
  esac
}

build_openssl_arch() {
  local arch="$1"
  local arch_build_root="$BUILD_ROOT/openssl-$arch"
  rm -rf "$arch_build_root"
  mkdir -p "$arch_build_root"

  tar -xzf "$OPENSSL_TARBALL" -C "$arch_build_root"
  local src_dir
  src_dir="$(find "$arch_build_root" -mindepth 1 -maxdepth 1 -type d -name "openssl-*" | head -n 1)"
  if [[ -z "$src_dir" ]]; then
    echo "Unable to find extracted OpenSSL source directory in $arch_build_root" >&2
    exit 1
  fi

  local openssl_target
  openssl_target="$(openssl_target_for_arch "$arch")"
  local configure_log="$arch_build_root/openssl-configure.log"
  local make_log="$arch_build_root/openssl-make.log"
  local install_log="$arch_build_root/openssl-install.log"
  pushd "$src_dir" >/dev/null
  run_logged "$configure_log" \
    env \
    CC="cc -arch $arch" \
    CFLAGS="-mmacosx-version-min=${MACOS_MIN_VERSION}" \
    LDFLAGS="-mmacosx-version-min=${MACOS_MIN_VERSION}" \
    ./Configure "$openssl_target" no-shared no-tests "--prefix=$arch_build_root/install"
  run_logged "$make_log" make -j"$(sysctl -n hw.ncpu)"
  run_logged "$install_log" make install_sw
  popd >/dev/null
}

build_libssh2_arch() {
  local arch="$1"
  local arch_build_root="$BUILD_ROOT/libssh2-$arch"
  rm -rf "$arch_build_root"
  mkdir -p "$arch_build_root"

  tar -xzf "$LIBSSH2_TARBALL" -C "$arch_build_root"
  local src_dir
  src_dir="$(find "$arch_build_root" -mindepth 1 -maxdepth 1 -type d -name "libssh2-*" | head -n 1)"
  if [[ -z "$src_dir" ]]; then
    echo "Unable to find extracted libssh2 source directory in $arch_build_root" >&2
    exit 1
  fi

  local host
  host="$(libssh2_host_for_arch "$arch")"
  local configure_log="$arch_build_root/libssh2-configure.log"
  local make_log="$arch_build_root/libssh2-make.log"
  pushd "$src_dir" >/dev/null
  run_logged "$configure_log" \
    env \
    CC="cc -arch $arch" \
    ./configure \
      --host="$host" \
      --disable-shared \
      --enable-static \
      --with-crypto=openssl \
      CPPFLAGS="-I$OPENSSL_OUTPUT_INCLUDE" \
      CFLAGS="-O2 -arch $arch -mmacosx-version-min=${MACOS_MIN_VERSION}" \
      LDFLAGS="-L$OPENSSL_OUTPUT_LIB -arch $arch -mmacosx-version-min=${MACOS_MIN_VERSION}"
  run_logged "$make_log" make -j"$(sysctl -n hw.ncpu)"
  popd >/dev/null
}

finalize_static_library() {
  local output="$1"
  shift
  local inputs=("$@")
  if [[ "${#inputs[@]}" -eq 1 ]]; then
    cp "${inputs[0]}" "$output"
  else
    lipo -create "${inputs[@]}" -output "$output"
  fi
}

run_logged() {
  local log_file="$1"
  shift
  if ! "$@" >"$log_file" 2>&1; then
    echo "Command failed. Full log: $log_file" >&2
    cat "$log_file" >&2
    exit 1
  fi
}

if have_cached_outputs; then
  echo "Using cached OpenSSL/libssh2 artifacts for: $EXPECTED_FINGERPRINT"
  echo "Prepared libssh2 artifacts in: $LIBSSH2_OUTPUT_ROOT"
  exit 0
fi

download_if_missing "$OPENSSL_TARBALL" "$OPENSSL_URL"
download_if_missing "$LIBSSH2_TARBALL" "$LIBSSH2_URL"

rm -rf "$BUILD_ROOT" "$OPENSSL_OUTPUT_INCLUDE" "$OPENSSL_OUTPUT_LIB" "$LIBSSH2_OUTPUT_INCLUDE" "$LIBSSH2_OUTPUT_LIB"
mkdir -p "$BUILD_ROOT" "$OPENSSL_OUTPUT_INCLUDE" "$OPENSSL_OUTPUT_LIB" "$LIBSSH2_OUTPUT_INCLUDE" "$LIBSSH2_OUTPUT_LIB"

for arch in "${ARCHES[@]}"; do
  echo "Building OpenSSL ($arch)..."
  build_openssl_arch "$arch"
done

FIRST_OPENSSL_ARCH="${ARCHES[0]}"
cp -R "$BUILD_ROOT/openssl-$FIRST_OPENSSL_ARCH/install/include/." "$OPENSSL_OUTPUT_INCLUDE/"

OPENSSL_CRYPTO_LIBS=()
OPENSSL_SSL_LIBS=()
for arch in "${ARCHES[@]}"; do
  OPENSSL_CRYPTO_LIBS+=("$BUILD_ROOT/openssl-$arch/install/lib/libcrypto.a")
  OPENSSL_SSL_LIBS+=("$BUILD_ROOT/openssl-$arch/install/lib/libssl.a")
done
finalize_static_library "$OPENSSL_OUTPUT_LIB/libcrypto.a" "${OPENSSL_CRYPTO_LIBS[@]}"
finalize_static_library "$OPENSSL_OUTPUT_LIB/libssl.a" "${OPENSSL_SSL_LIBS[@]}"

for arch in "${ARCHES[@]}"; do
  echo "Building libssh2 ($arch)..."
  build_libssh2_arch "$arch"
done

FIRST_LIBSSH2_ARCH="${ARCHES[0]}"
cp -R "$BUILD_ROOT/libssh2-$FIRST_LIBSSH2_ARCH/libssh2-$LIBSSH2_VERSION/include/." "$LIBSSH2_OUTPUT_INCLUDE/"

LIBSSH2_LIBS=()
for arch in "${ARCHES[@]}"; do
  LIBSSH2_LIBS+=("$BUILD_ROOT/libssh2-$arch/libssh2-$LIBSSH2_VERSION/src/.libs/libssh2.a")
done
finalize_static_library "$LIBSSH2_OUTPUT_LIB/libssh2.a" "${LIBSSH2_LIBS[@]}"

cat > "$BUILD_INFO_FILE" <<EOF
libssh2 build info
fingerprint=$EXPECTED_FINGERPRINT
generated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
openssl_tarball=$OPENSSL_TARBALL
libssh2_tarball=$LIBSSH2_TARBALL
EOF

echo "Prepared OpenSSL artifacts in: $OPENSSL_OUTPUT_ROOT"
echo "Prepared libssh2 artifacts in: $LIBSSH2_OUTPUT_ROOT"
