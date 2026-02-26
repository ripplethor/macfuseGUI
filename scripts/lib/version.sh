#!/usr/bin/env bash

# Shared semantic-version helpers for build/release scripts.

is_valid_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

semver_to_build_number() {
  local ver="$1"
  local major minor patch

  is_valid_semver "$ver" || {
    echo "Invalid semantic version: $ver (expected X.Y.Z)" >&2
    return 1
  }

  major="${ver%%.*}"
  minor="${ver#*.}"; minor="${minor%%.*}"
  patch="${ver##*.}"

  ((10#$minor <= 999)) || {
    echo "Invalid semantic version segment (minor > 999): $ver" >&2
    return 1
  }
  ((10#$patch <= 999)) || {
    echo "Invalid semantic version segment (patch > 999): $ver" >&2
    return 1
  }

  # Keep CURRENT_PROJECT_VERSION numeric and collision-free for minor/patch <= 999.
  echo $((10#$major * 1000000 + 10#$minor * 1000 + 10#$patch))
}
