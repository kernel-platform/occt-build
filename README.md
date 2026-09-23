# occt-build

Reproducible builds of the Open CASCADE Technology (OCCT) shared libraries. This
repository holds the pinned upstream source reference, the build scripts, and the prebuilt
shared libraries for Linux x86_64/aarch64 and macOS arm64. OCCT is distributed under LGPL-2.1 with the Open CASCADE
Exception.

The OCCT we build is unmodified. `patches/<version>/` is empty until a release says
otherwise.

## Current version

| | |
|---|---|
| OCCT | 7.8.1: upstream tag [`V7_8_1`](https://github.com/Open-Cascade-SAS/OCCT/tree/V7_8_1), commit `bd2a789f15235755ce4d1a3b07379a2e062fdc2e` |
| Build | `kernel.1` (`versions/7.8.1.env`) |
| Library type | Shared only. A release never contains a static `.a` library. |

**Status:** the build scripts are in place and have been checked locally on macOS arm64
and in the Linux container on aarch64. The release workflow comes next. No release has
been published yet.

## Releases

Each tag `v<occt-version>-kernel.<n>` publishes a GitHub Release with these assets:

| Asset | Contents |
|---|---|
| `occt-<v>-kernel.<n>-linux-x86_64.tar.gz` | `lib/` (shared `libTK*`), `include/`, `licenses/`, `BUILDINFO.json` |
| `occt-<v>-kernel.<n>-linux-aarch64.tar.gz` | same layout |
| `occt-<v>-kernel.<n>-macos-arm64.tar.gz` | same layout |
| `occt-<v>-kernel.<n>-src.tar.gz` | the exact source the binaries were built from, with any patches applied, plus this repository's scripts |
| `SHA256SUMS` | checksums of every asset |
| `sbom.cdx.json` | CycloneDX software bill of materials |

`BUILDINFO.json` records the OCCT commit, the build number, the compiler, the CMake cache,
the container digest (Linux) and the deployment target (macOS).

Releases are never deleted or overwritten. Immutable releases are enabled.

## Build configuration

- The library type is shared.
- Modules built: FoundationClasses, ModelingData, ModelingAlgorithms, DataExchange and
  ApplicationFramework.
- Not built: Draw, DETools, Visualization/OpenGL, and the samples. OCCT's dependency
  resolution still builds TKService and TKV3d, because TKXCAF needs them. They are built
  without OpenGL, X11 or FreeType.
- Optional dependencies are all off: Tcl/Tk, FreeType, FreeImage, VTK, TBB, RapidJSON and
  Draco. The libraries therefore link only system libraries.
- The optimization profile is upstream's `Production` (`-O3 -flto`); macOS also uses
  `-ffp-model=strict`.

The exact options live in `cmake/occt-options.cmake`. The toolkit list a release must contain is in
`versions/<version>.env`, and `scripts/check_licenses.sh package` enforces it.

## Rebuilding a release

```bash
scripts/fetch_source.sh 7.8.1   # pinned upstream commit + patches -> source tarball
scripts/build.sh 7.8.1          # configure, build and install into stage/
scripts/package.sh 7.8.1        # tarball, SHA256SUMS, SBOM
```

On Linux, run the same commands inside `docker/linux.Dockerfile`, which uses the same
`ubuntu:24.04` base as the CI build.

## Replacing the libraries in an application

An application that links these libraries dynamically can run with a replacement build,
modified or not, as LGPL-2.1 section 6 allows. Build OCCT of the same minor version as
shared libraries (for example with the scripts above plus your changes), then replace the
`libTK*` files the application ships with. On macOS, re-sign the application ad hoc after
the swap (`codesign --force --deep --sign - <App>.app`) if the system refuses to load the
modified libraries.

## Using a release

Download the platform tarball and verify it against the release's `SHA256SUMS`. The
tarball's `lib/` and `include/opencascade/` can be used directly or repackaged, for
example as a Conan or CMake package.

## Licenses

- OCCT is © Open Cascade SAS, licensed under LGPL-2.1 (`LICENSE`) with the Open CASCADE
  Exception (`OCCT_LGPL_EXCEPTION.txt`).
- This repository's scripts and patches are licensed under LGPL-2.1.
- Third-party code inside OCCT is listed in `NOTICE.md`.

"Open CASCADE" is a trademark of Open Cascade SAS. This project is not affiliated with or
endorsed by Open Cascade SAS.

## Checks

`scripts/check_licenses.sh` runs on every pull request and before every release:

- `root <version>`: `LICENSE` and `OCCT_LGPL_EXCEPTION.txt` match upstream at the pinned
  commit.
- `source <dir>`: every file under a non-OCCT license in the source tree is listed in
  `third_party/notices.tsv`.
- `package <version> <stage>`: a staged build has its license texts, including the
  third-party notices of every toolkit it contains, plus `BUILDINFO.json`. It contains
  only shared libraries, exactly the expected toolkits, and links nothing but system
  libraries.

`scripts/smoke.sh <stage>` compiles and runs `smoke/smoke.cc` against a staged build. It
covers booleans, healing, an XCAF document written to STEP and read back with names, a
BinXCAF save and reopen, and BRepMesh tessellation. `scripts/fetch_source.sh` produces a
byte-reproducible source tarball.

## Source requests

Every release carries its own source tarball, and releases are never deleted. To ask
about the source, open an issue in this repository.
