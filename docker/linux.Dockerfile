# Linux build environment for occt-build: ubuntu:24.04 pinned by digest, so the
# glibc and toolchain of a release are fixed; BUILDINFO.json records the digest.
#
#   docker build -f docker/linux.Dockerfile -t occt-build-linux .
#   docker run --rm -v "$PWD:/w" -w /w occt-build-linux \
#     sh -c 'scripts/fetch_source.sh 7.8.1 && scripts/build.sh 7.8.1 && scripts/package.sh 7.8.1'
FROM ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3

ARG DEBIAN_FRONTEND=noninteractive
# libgl-dev/libegl-dev: upstream OCCT 7.8 puts GL/EGL on TKV3d's Linux link line
# even with USE_OPENGL=OFF. They are needed to link only; the toolchain's
# --as-needed drops them, and check_licenses.sh package fails if TKV3d keeps them.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake ninja-build git ca-certificates curl python3 \
      libgl-dev libegl-dev \
    && rm -rf /var/lib/apt/lists/*
RUN git config --system --add safe.directory '*'
ENV OCCT_BUILD_IMAGE="ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3"
