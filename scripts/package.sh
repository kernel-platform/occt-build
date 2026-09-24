#!/usr/bin/env bash
# package.sh <version> — tar the staged build of this platform into
# dist/occt-<release>-<platform>.tar.gz and write its CycloneDX SBOM. The
# release workflow gathers every platform's assets and writes SHA256SUMS.
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"
[ $# -eq 1 ] || { echo "usage: $0 <version>" >&2; exit 2; }
load_version "$1"
detect_platform
[ -d "$STAGE_DIR" ] || { echo "no staged build in $STAGE_DIR; run scripts/build.sh $1" >&2; exit 1; }
"$ROOT/scripts/check_licenses.sh" package "$1" "$STAGE_DIR"

mkdir -p "$DIST_DIR"
tarball="$DIST_DIR/${PKG_NAME}.tar.gz"
# Stable member order and metadata, so a rebuild with identical binaries gives
# an identical archive.
(cd "$(dirname "$STAGE_DIR")" && find "$PKG_NAME" -print | LC_ALL=C sort) > "$ROOT/work/${PKG_NAME}.list"
tar_flags=(--no-recursion)
if [ "$(uname -s)" = Linux ]; then
  tar_flags+=(--owner=0 --group=0 --numeric-owner --mtime=@0)
fi
tar -C "$(dirname "$STAGE_DIR")" -cf - "${tar_flags[@]}" -T "$ROOT/work/${PKG_NAME}.list" \
  | gzip -n -9 > "$tarball"

sha="$(sha256 "$tarball")"
"$PY" - "$DIST_DIR/${PKG_NAME}.cdx.json" <<PY
import json, sys
bom = {
    "bomFormat": "CycloneDX",
    "specVersion": "1.5",
    "version": 1,
    "metadata": {"component": {"type": "library", "name": "${PKG_NAME}",
                               "version": "${RELEASE}"}},
    "components": [{
        "type": "library",
        "name": "Open CASCADE Technology",
        "version": "${OCCT_VERSION}",
        "supplier": {"name": "Open Cascade SAS"},
        "licenses": [{"expression": "LGPL-2.1-only WITH OCCT-exception-1.0"}],
        "purl": "pkg:github/Open-Cascade-SAS/OCCT@${OCCT_TAG}",
        "externalReferences": [{"type": "vcs", "url": "${OCCT_REPO}"}],
        "properties": [{"name": "occt:commit", "value": "${OCCT_COMMIT}"},
                       {"name": "occt-build:platform", "value": "${PLATFORM}"}],
        "hashes": [{"alg": "SHA-256", "content": "${sha}"}],
    }],
}
json.dump(bom, open(sys.argv[1], "w"), indent=2)
PY
echo "package: $tarball ($sha)"
