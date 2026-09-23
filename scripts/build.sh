#!/usr/bin/env bash
# build.sh <version> — configure, build and install OCCT from work/src-<version>
# (scripts/fetch_source.sh) into stage/occt-<release>-<platform>/, then add
# licenses/, BUILDINFO.json, run the smoke test and the package checks.
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"
[ $# -eq 1 ] || { echo "usage: $0 <version>" >&2; exit 2; }
load_version "$1"
detect_platform
[ -d "$SRC_DIR/src" ] || { echo "no source in $SRC_DIR; run scripts/fetch_source.sh $1" >&2; exit 1; }

extra=()
if [ "${PLATFORM%%-*}" = macos ]; then
  extra+=(-DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET")
fi

rm -rf "${STAGE_DIR:?}"
cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
  -C "$ROOT/cmake/occt-options.cmake" \
  -DCMAKE_INSTALL_PREFIX="$STAGE_DIR" \
  ${extra[@]+"${extra[@]}"}
cmake --build "$BUILD_DIR" --parallel "$(jobs)"
cmake --install "$BUILD_DIR"

# Keep lib/, include/, lib/cmake and the runtime resources. bin/ holds only
# environment scripts with build-machine paths.
rm -rf "${STAGE_DIR:?}/bin" "${STAGE_DIR:?}/share/doc"

# License texts, from the source tree that was built (never from this repo's root).
lic="$STAGE_DIR/licenses"
mkdir -p "$lic/third_party"
cp "$SRC_DIR/LICENSE_LGPL_21.txt" "$SRC_DIR/OCCT_LGPL_EXCEPTION.txt" "$lic/"
cp "$ROOT/NOTICE.md" "$lic/"
# The leading license comment of every third-party file in a toolkit we built.
while IFS=$'\t' read -r path toolkit license _built _; do
  case "$path" in '#'* | '') continue ;; esac
  [ "$toolkit" != - ] || continue
  ls "$STAGE_DIR/lib/lib${toolkit}."* >/dev/null 2>&1 || continue
  out="$lic/third_party/$(basename "$path").txt"
  {
    echo "From $path (OCCT toolkit $toolkit), license: $license"
    echo
    awk '
      NR == 1 && /^[[:space:]]*$/ { next }
      /^[[:space:]]*\/\*/ { inblock = 1 }
      inblock { print; if (/\*\//) { inblock = 0; seen = 1 }; next }
      /^[[:space:]]*\/\// { print; seen = 1; next }
      /^[[:space:]]*$/ && !seen { next }
      /^[[:space:]]*$/ { print; next }
      { exit }
    ' "$SRC_DIR/$path"
  } > "$out"
done < "$ROOT/third_party/notices.tsv"

cxx_id="$(sed -n 's/^set(CMAKE_CXX_COMPILER_ID "\(.*\)")$/\1/p' "$BUILD_DIR"/CMakeFiles/*/CMakeCXXCompiler.cmake | head -1)"
cxx="$(sed -n 's/^CMAKE_CXX_COMPILER:[A-Z]*=//p' "$BUILD_DIR/CMakeCache.txt")"
cxx_version="$("$cxx" --version | head -1)"
cxx_flags="$(sed -n 's/^CMAKE_CXX_FLAGS:[A-Z]*=//p' "$BUILD_DIR/CMakeCache.txt")"
python3 - "$STAGE_DIR/BUILDINFO.json" <<PY
import json, sys
info = {
    "release": "${RELEASE}",
    "platform": "${PLATFORM}",
    "occt_version": "${OCCT_VERSION}",
    "occt_repo": "${OCCT_REPO}",
    "occt_tag": "${OCCT_TAG}",
    "occt_commit": "${OCCT_COMMIT}",
    "patches": sorted(f for f in __import__("os").listdir("${ROOT}/patches/${OCCT_VERSION}") if f.endswith(".patch")),
    "occt_build_commit": "$(git -C "$ROOT" rev-parse HEAD)",
    "occt_build_dirty": $([ -z "$(git -C "$ROOT" status --porcelain)" ] && echo False || echo True),
    "compiler": "${cxx_id}",
    "compiler_version": "${cxx_version}",
    "cxx_flags_cache": "${cxx_flags}",
    "options_file": "cmake/occt-options.cmake",
    "macos_deployment_target": "${MACOS_DEPLOYMENT_TARGET}" if "${PLATFORM}".startswith("macos") else None,
    "build_image": "${OCCT_BUILD_IMAGE:-}" or None,
}
json.dump(info, open(sys.argv[1], "w"), indent=2)
PY

"$ROOT/scripts/smoke.sh" "$STAGE_DIR"
"$ROOT/scripts/check_licenses.sh" package "$1" "$STAGE_DIR"
echo "staged: $STAGE_DIR"
