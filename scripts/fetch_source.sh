#!/usr/bin/env bash
# fetch_source.sh <version> — check out the pinned OCCT commit into work/,
# apply patches/<version>/*.patch, audit the tree, and write the release source
# tarball dist/occt-<release>-src.tar.gz (upstream tree + patches, exactly as
# built). The build scripts ship separately as occt-build-<release>.tar.gz.
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "$0")/common.sh"
[ $# -eq 1 ] || { echo "usage: $0 <version>" >&2; exit 2; }
load_version "$1"

rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR" "$DIST_DIR"
git -C "$SRC_DIR" init -q
# Upstream bytes on every platform: no CRLF conversion on Windows checkouts.
git -C "$SRC_DIR" config core.autocrlf false
git -C "$SRC_DIR" fetch -q --depth 1 "$OCCT_REPO" "$OCCT_COMMIT"
git -C "$SRC_DIR" checkout -q FETCH_HEAD
head="$(git -C "$SRC_DIR" rev-parse HEAD)"
[ "$head" = "$OCCT_COMMIT" ] || { echo "fetched $head, pinned $OCCT_COMMIT" >&2; exit 1; }

# Patches, in file-name order, committed with a fixed identity and date so the
# archive below is byte-reproducible.
shopt -s nullglob
patches=("$ROOT/patches/$OCCT_VERSION"/*.patch)
for p in ${patches[@]+"${patches[@]}"}; do
  git -C "$SRC_DIR" apply --index "$p"
  echo "applied $(basename "$p")"
done
if [ -n "${patches[*]-}" ]; then
  GIT_AUTHOR_DATE="1970-01-01T00:00:00Z" GIT_COMMITTER_DATE="1970-01-01T00:00:00Z" \
    git -C "$SRC_DIR" -c user.name=occt-build -c user.email=occt-build@invalid \
    commit -q -m "occt-build patches for ${RELEASE}"
fi

"$ROOT/scripts/check_licenses.sh" source "$SRC_DIR"

tarball="$DIST_DIR/occt-${RELEASE}-src.tar.gz"
git -C "$SRC_DIR" archive --format=tar --prefix="occt-${RELEASE}-src/" HEAD | gzip -n -9 > "$tarball"
git -C "$ROOT" archive --format=tar --prefix="occt-build-${RELEASE}/" HEAD \
  | gzip -n -9 > "$DIST_DIR/occt-build-${RELEASE}.tar.gz"
echo "source: $tarball"
