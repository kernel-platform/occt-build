#!/usr/bin/env bash
# check_licenses.sh — license audit for occt-build.
#
#   check_licenses.sh root <version>
#       The repository's LICENSE matches upstream LICENSE_LGPL_21.txt (ignoring
#       whitespace) and OCCT_LGPL_EXCEPTION.txt is byte-identical to upstream,
#       both read at the commit pinned in versions/<version>.env.
#   check_licenses.sh source <occt-source-dir>
#       Every file in the source tree that carries a license other than OCCT's
#       own is listed in third_party/notices.tsv, and every listed file exists.
#       A built toolkit may not contain a GPL file without the Bison exception.
#   check_licenses.sh package <version> <stage-dir>
#       A staged build carries its license texts (OCCT's and the third-party
#       notices of every toolkit it contains) and BUILDINFO.json, contains only
#       shared libraries, exactly the toolkits of versions/<version>.env, and
#       links nothing but system libraries.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { echo "check_licenses: $*" >&2; exit 1; }

check_root() {
  local env="versions/$1.env"
  [ -f "$env" ] || die "no $env"
  # shellcheck disable=SC1090
  source "$env"
  local raw="https://raw.githubusercontent.com/Open-Cascade-SAS/OCCT/${OCCT_COMMIT}"
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL "$raw/LICENSE_LGPL_21.txt" -o "$tmp/LICENSE_LGPL_21.txt"
  curl -fsSL "$raw/OCCT_LGPL_EXCEPTION.txt" -o "$tmp/OCCT_LGPL_EXCEPTION.txt"
  cmp -s OCCT_LGPL_EXCEPTION.txt "$tmp/OCCT_LGPL_EXCEPTION.txt" \
    || die "OCCT_LGPL_EXCEPTION.txt differs from upstream ${OCCT_TAG}"
  [ "$(tr -s '[:space:]' ' ' < LICENSE)" = "$(tr -s '[:space:]' ' ' < "$tmp/LICENSE_LGPL_21.txt")" ] \
    || die "LICENSE differs from upstream ${OCCT_TAG} LICENSE_LGPL_21.txt beyond whitespace"
  echo "OK: LICENSE and OCCT_LGPL_EXCEPTION.txt match OCCT ${OCCT_TAG} (${OCCT_COMMIT:0:12})."
}

# Files under src/ whose license differs from OCCT's: a copyright line without
# the OCCT header, or a well-known third-party license phrase.
scan_source() {
  local src="$1/src"
  {
    grep -rlI "Copyright" "$src" \
      | xargs grep -LI -i -E "open cascade|opencascade|matra datavision" || true
    grep -rlI -E "Permission is hereby granted|Redistribution and use in source and binary|GNU General Public License|Apache License|Boost Software License|public domain" "$src" || true
  } | sed "s|^$1/||" | sort -u
}

check_source() {
  local dir="$1"
  [ -d "$dir/src" ] || die "$dir is not an OCCT source tree"
  local listed found status=0
  listed="$(grep -v '^#' third_party/notices.tsv | cut -f1 | sort -u)"
  found="$(scan_source "$dir")"
  while read -r f; do
    [ -n "$f" ] || continue
    grep -qxF "$f" <<<"$listed" || { echo "UNLISTED third-party file: $f"; status=1; }
  done <<<"$found"
  while IFS=$'\t' read -r path toolkit license built _; do
    case "$path" in '#'*|'') continue ;; esac
    [ -f "$dir/$path" ] || { echo "LISTED but missing: $path"; status=1; }
    if [ "$built" != "no" ] && [[ "$license" == *GPL* ]] && [[ "$license" != *LGPL* ]] \
       && [[ "$license" != *Bison-exception* ]]; then
      echo "GPL file in built toolkit $toolkit: $path ($license)"; status=1
    fi
  done < third_party/notices.tsv
  [ "$status" -eq 0 ] || die "third_party/notices.tsv is out of date for $dir"
  echo "OK: every third-party file in $dir is listed in third_party/notices.tsv."
}

check_package() {
  local env="versions/$1.env" stage="$2" status=0
  [ -f "$env" ] || die "no $env"
  # shellcheck disable=SC1090
  source "$env"
  [ -d "$stage/lib" ] || die "$stage has no lib/"

  local f
  for f in LICENSE_LGPL_21.txt OCCT_LGPL_EXCEPTION.txt NOTICE.md; do
    [ -s "$stage/licenses/$f" ] || { echo "missing licenses/$f"; status=1; }
  done
  [ -s "$stage/BUILDINFO.json" ] || { echo "missing BUILDINFO.json"; status=1; }
  while IFS=$'\t' read -r path toolkit _license _built _; do
    case "$path" in '#'* | '') continue ;; esac
    ls "$stage/lib/lib${toolkit}."* "$stage/bin/${toolkit}.dll" >/dev/null 2>&1 || continue
    [ -s "$stage/licenses/third_party/$(basename "$path").txt" ] \
      || { echo "missing third-party notice for $path ($toolkit)"; status=1; }
  done < third_party/notices.tsv

  local windows=0
  [ -n "$(find "$stage/bin" -maxdepth 1 -name 'TK*.dll' 2>/dev/null)" ] && windows=1

  if find "$stage" -name '*.a' | grep -q .; then
    echo "static libraries present:"; find "$stage" -name '*.a'; status=1
  fi
  if [ "$windows" = 1 ]; then
    # On Windows a .lib is either an import library or a static one. Every
    # lib/TK*.lib must be the import library of a bin/TK*.dll.
    local implib
    while read -r implib; do
      [ -f "$stage/bin/$(basename "$implib" .lib).dll" ] \
        || { echo "$(basename "$implib") has no matching DLL (static library?)"; status=1; }
    done < <(find "$stage/lib" -maxdepth 1 -name '*.lib')
  fi

  local got want
  if [ "$windows" = 1 ]; then
    got="$(find "$stage/bin" -maxdepth 1 -name 'TK*.dll' | sed -E 's%.*/(TK[A-Za-z0-9]+)[.]dll$%\1%' \
            | sort -u | tr '\n' ' ')"
  else
    got="$(find "$stage/lib" -maxdepth 1 \( -name 'libTK*.so' -o -name 'libTK*.dylib' \) \
            | grep -E '/libTK[A-Za-z0-9]+[.](so|dylib)$' \
            | sed -E 's%.*/lib(TK[A-Za-z0-9]+)[.](so|dylib)$%\1%' | sort -u | tr '\n' ' ')"
  fi
  want="$(tr ' ' '\n' <<<"$OCCT_TOOLKITS" | grep . | sort -u | tr '\n' ' ')"
  [ "$got" = "$want" ] || { echo "toolkits differ from versions/$1.env"; \
    diff <(tr ' ' '\n' <<<"$want") <(tr ' ' '\n' <<<"$got") || true; status=1; }

  # Dependencies of every real library file: other TK libraries and the system.
  local lib deps
  while read -r lib; do
    if [ "$windows" = 1 ]; then
      # System DLLs (Windows API sets included) and the MSVC runtime, which the
      # application ships through Microsoft's redistributable.
      deps="$(dumpbin -nologo -dependents "$lib" | tr -d '\r' | grep -i -E '^ +[^ ]+\.dll$' \
        | awk '{print $1}' \
        | grep -v -i -E '^TK[A-Za-z0-9]+\.dll$|^(kernel32|user32|gdi32|advapi32|shell32|ole32|oleaut32|ws2_32|winmm|psapi|dbghelp|comdlg32|shlwapi|version|bcrypt|crypt32|secur32|imm32|opengl32|ucrtbase|vcruntime140|vcruntime140_1|msvcp140|msvcp140_1|msvcp140_2|concrt140)\.dll$|^api-ms-win-' || true)"
    elif [ "$(uname -s)" = Darwin ]; then
      deps="$(otool -L "$lib" | tail -n +2 | awk '{print $1}' \
        | grep -v -E '^@rpath/libTK|^/usr/lib/lib(System\.B|c\+\+\.1|objc\.A)\.dylib$|^/System/Library/Frameworks/' || true)"
    else
      deps="$(readelf -d "$lib" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' \
        | grep -v -E '^libTK|^lib(c|m|dl|rt|pthread|stdc\+\+|gcc_s)\.so|^ld-linux' || true)"
    fi
    [ -z "$deps" ] || { echo "$(basename "$lib") links non-system libraries: $deps"; status=1; }
  done < <(find "$stage/lib" "$stage/bin" -maxdepth 1 -type f \
             \( -name 'libTK*.so.*' -o -name 'libTK*.dylib' -o -name 'TK*.dll' \) 2>/dev/null)

  [ "$status" -eq 0 ] || die "package check failed for $stage"
  echo "OK: $stage has its licenses, only shared system-linked libraries, and the expected toolkits."
}

case "${1:-}" in
  root)   [ $# -eq 2 ] || die "usage: $0 root <version>"; check_root "$2" ;;
  source) [ $# -eq 2 ] || die "usage: $0 source <occt-source-dir>"; check_source "$2" ;;
  package) [ $# -eq 3 ] || die "usage: $0 package <version> <stage-dir>"; check_package "$2" "$3" ;;
  *)      die "usage: $0 {root <version>|source <occt-source-dir>|package <version> <stage-dir>}" ;;
esac
