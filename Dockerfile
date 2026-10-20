# Insight 7.3.50.20110803-cvs (the version of the Windows BMDE, built from its original sources) and gdb-multiarch, to
# debug NDS programs running in DeSmuME. The installation is done by the scripts in src/ (with the assets downloaded
# into assets/ by scripts/download_assets.sh), the same ones used to install them in a host (see README.md).

# STAGE 1: Build, from the sources in assets/. The 2011 code needs a toolchain of its time; the result runs in newer
# systems. The tarball is the one published in the releases, used by install_insight.sh in hosts
# Base image of the BMDE images (docker-bake.hcl of bmde replaces this stage by the base image being built)
FROM aleixmt/bmde-base:latest AS bmde-base

FROM ubuntu:14.04 AS build

RUN --mount=type=bind,target=/component \
    /component/src/build_insight.sh --tarball /insight-7.3.50.20110803-cvs-linux-x86_64.tar.xz


# STAGE 2: Runtime. install_insight.sh finds Insight already built, and installs its runtime dependencies only
FROM bmde-base

RUN bmde-install-display

COPY --from=build /URV/bmde/insight /URV/bmde/insight
COPY --from=build /insight-7.3.50.20110803-cvs-linux-x86_64.tar.xz /URV/bmde/insight/share/bmde/
RUN --mount=type=bind,target=/component \
    /component/src/install_insight.sh \
    && /component/src/install_gdb_multiarch.sh \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 src/entrypoint.sh /entrypoint.sh

RUN useradd --create-home --uid 1000 --shell /bin/bash insight \
    && mkdir -p /input
USER insight
WORKDIR /input

ENTRYPOINT ["/entrypoint.sh"]
CMD []
