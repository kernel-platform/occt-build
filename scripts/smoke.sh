#!/usr/bin/env bash
# smoke.sh <stage-dir> — compile smoke/smoke.cc against a staged build, linking
# only the staged libraries, and run it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
stage="$(cd "$1" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

libs=(TKernel TKMath TKG2d TKG3d TKGeomBase TKGeomAlgo TKBRep TKTopAlgo TKPrim TKBO
      TKShHealing TKMesh TKCDF TKLCAF TKCAF TKBinL TKBin TKBinXCAF TKXCAF TKXSBase TKDE
      TKDESTEP TKVCAF TKService TKV3d)
"${CXX:-c++}" -std=c++17 -O1 "$ROOT/smoke/smoke.cc" -o "$tmp/smoke" \
  -I"$stage/include/opencascade" -L"$stage/lib" -Wl,-rpath,"$stage/lib" \
  "${libs[@]/#/-l}"
"$tmp/smoke" "$tmp"
