# Notice

## Open CASCADE Technology

This repository builds Open CASCADE Technology (OCCT), Copyright (c) Open Cascade SAS.
OCCT is licensed under the GNU Lesser General Public License version 2.1 (`LICENSE`) with
the Open CASCADE Exception version 1.0 (`OCCT_LGPL_EXCEPTION.txt`).

"Open CASCADE" is a trademark of Open Cascade SAS. This project is not affiliated with or
endorsed by Open Cascade SAS.

## What this repository adds

The build scripts, CMake option files, CI workflows and any files under `patches/` were
written by Kernel Platform. They are licensed under LGPL-2.1, the same license as OCCT.

## Third-party code inside OCCT

OCCT's source tree contains a few files under other licenses. They are listed in
`third_party/notices.tsv`, and `scripts/check_licenses.sh source` fails when the tree
contains one that is not listed. The files in toolkits we build are:

| Code | Toolkit | License | Copyright |
|---|---|---|---|
| Delabella Delaunay triangulation (`src/BRepMesh/delabella.*`) | TKMesh | MIT | (C) 2018 GUMIX - Marcin Sokalski |
| `FlexLexer.h` (`src/FlexLexer/`) | TKernel | BSD-3-Clause | (c) 1993 The Regents of the University of California |
| Bison parser skeletons (`src/ExprIntrp/*.tab.*`, `src/StepFile/step.tab.*`) | TKMath, TKDESTEP | GPL-3.0-or-later with the Bison exception, which allows distribution under any terms | Free Software Foundation, Inc. |
| DejaVu Sans font (`src/Font/Font_DejavuSans_Latin_woff.pxx`), only if TKService is built | TKService | Bitstream Vera font license | (c) 2003 Bitstream, Inc. |

Every release tarball contains the full license texts of these components under
`licenses/third_party/`.
