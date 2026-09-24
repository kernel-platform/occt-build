# common.sh — sourced by the build scripts: version pin, platform, directories.
# shellcheck shell=bash
# The variables set here are read by the scripts that source this file.
# shellcheck disable=SC2034

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_version() {
  local env="$ROOT/versions/$1.env"
  [ -f "$env" ] || { echo "no $env" >&2; exit 1; }
  # shellcheck disable=SC1090
  source "$env"
  RELEASE="${OCCT_VERSION}-kernel.${KERNEL_BUILD}"
  SRC_DIR="$ROOT/work/src-${OCCT_VERSION}"
  DIST_DIR="$ROOT/dist"
}

detect_platform() {
  local os arch
  case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=macos ;;
    MINGW* | MSYS* | CYGWIN*) os=windows ;;
    *) echo "unsupported OS $(uname -s)" >&2; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64 | amd64) arch=x86_64 ;;
    arm64 | aarch64) arch=$([ "$os" = macos ] && echo arm64 || echo aarch64) ;;
    *) echo "unsupported arch $(uname -m)" >&2; exit 1 ;;
  esac
  PLATFORM="$os-$arch"
  PKG_NAME="occt-${RELEASE}-${PLATFORM}"
  BUILD_DIR="$ROOT/work/build-${RELEASE}-${PLATFORM}"
  STAGE_DIR="$ROOT/stage/${PKG_NAME}"
}

jobs() {
  if command -v nproc >/dev/null; then nproc; else sysctl -n hw.ncpu; fi
}

# The Python interpreter: python3, or python on Windows runners.
PY="$(command -v python3 || command -v python || true)"

sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1
}

is_windows() { [ "${PLATFORM%%-*}" = windows ]; }

# has_toolkit <stage> <toolkit>: the stage contains that toolkit's shared
# library (lib/libTK*.so|dylib on Unix, bin/TK*.dll on Windows).
has_toolkit() {
  local f
  for f in "$1/lib/lib$2."* "$1/bin/$2.dll"; do
    [ -e "$f" ] && return 0
  done
  return 1
}
