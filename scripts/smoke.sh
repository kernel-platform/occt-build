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
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    # MSVC (the job loads its environment). Dash-style flags and Windows paths:
    # MSYS would rewrite /-style flags as paths.
    win() { cygpath -w "$1"; }
    (cd "$tmp" && MSYS2_ARG_CONV_EXCL='*' cl -nologo -EHsc -std:c++17 -O1 \
      -I"$(win "$stage/include/opencascade")" "$(win "$ROOT/smoke/smoke.cc")" \
      -Fe:smoke.exe -link -LIBPATH:"$(win "$stage/lib")" "${libs[@]/%/.lib}")
    PATH="$stage/bin:$PATH" "$tmp/smoke.exe" "$(win "$tmp")"
    ;;
  *)
    "${CXX:-c++}" -std=c++17 -O1 "$ROOT/smoke/smoke.cc" -o "$tmp/smoke" \
      -I"$stage/include/opencascade" -L"$stage/lib" -Wl,-rpath,"$stage/lib" \
      "${libs[@]/#/-l}"
    "$tmp/smoke" "$tmp"
    ;;
esac
