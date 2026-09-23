# occt-options.cmake — the ONE place the OCCT configuration lives.
# Used as an initial cache: cmake -C cmake/occt-options.cmake -S <occt-src> ...
#
# Shared libraries, upstream's Production optimization profile, the modelling,
# data-exchange and application-framework modules (no Draw, no DETools), no
# optional third-party products, no OpenGL/X11, and -ffp-model=strict on macOS.

# OCCT 7.8 declares cmake_minimum_required(3.1), which CMake >= 4 rejects;
# older CMake ignores this variable.
set(CMAKE_POLICY_VERSION_MINIMUM "3.5" CACHE STRING "")

set(BUILD_LIBRARY_TYPE "Shared" CACHE STRING "")
set(CMAKE_BUILD_TYPE "Release" CACHE STRING "")
set(BUILD_OPT_PROFILE "Production" CACHE STRING "")  # -O3 -flto -ffunction-sections ...
set(BUILD_RELEASE_DISABLE_EXCEPTIONS ON CACHE BOOL "")  # upstream default
set(BUILD_YACCLEX OFF CACHE BOOL "")  # use the parsers shipped in the source tree
set(BUILD_USE_PCH OFF CACHE BOOL "")
set(BUILD_DOC_Overview OFF CACHE BOOL "")
set(BUILD_Inspector OFF CACHE BOOL "")
set(BUILD_SAMPLES_QT OFF CACHE BOOL "")
set(INSTALL_DIR_LAYOUT "Unix" CACHE STRING "")
set(INSTALL_SAMPLES OFF CACHE BOOL "")
set(INSTALL_TEST_CASES OFF CACHE BOOL "")

# Modules. Toolkits other modules depend on (TKService, TKV3d for TKXCAF) are
# pulled in by OCCT's own dependency resolution.
set(BUILD_MODULE_FoundationClasses ON CACHE BOOL "")
set(BUILD_MODULE_ModelingData ON CACHE BOOL "")
set(BUILD_MODULE_ModelingAlgorithms ON CACHE BOOL "")
set(BUILD_MODULE_ApplicationFramework ON CACHE BOOL "")
set(BUILD_MODULE_DataExchange ON CACHE BOOL "")
set(BUILD_MODULE_Visualization OFF CACHE BOOL "")
set(BUILD_MODULE_DETools OFF CACHE BOOL "")
set(BUILD_MODULE_Draw OFF CACHE BOOL "")

# No optional products: the libraries link system libraries only.
foreach(product TK FREETYPE FREEIMAGE FFMPEG OPENVR RAPIDJSON DRACO TBB VTK EIGEN
                OPENGL GLES2 XLIB D3D)
  set(USE_${product} OFF CACHE BOOL "")
endforeach()

# Libraries find each other next to themselves; consumers use @rpath / RUNPATH.
if(APPLE)
  set(CMAKE_INSTALL_NAME_DIR "@rpath" CACHE STRING "")
  set(CMAKE_INSTALL_RPATH "@loader_path" CACHE STRING "")
  # No FP contraction, strict IEEE semantics.
  set(CMAKE_CXX_FLAGS "-ffp-model=strict" CACHE STRING "")
  set(CMAKE_C_FLAGS "-ffp-model=strict" CACHE STRING "")
else()
  set(CMAKE_INSTALL_RPATH "\$ORIGIN" CACHE STRING "")
endif()
