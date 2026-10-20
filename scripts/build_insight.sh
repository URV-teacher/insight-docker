#!/usr/bin/env bash
# Builds Insight 7.3.50.20110803-cvs (the version of the Windows BMDE) for the arm-eabi target into /URV/bmde/insight,
# from the sources in src/ (see fetch_source.sh). The 2011 code needs a toolchain of its time: run it in Ubuntu 14.04,
# as the Dockerfile does. The result does not depend on the libraries of Ubuntu 14.04 (ncurses is linked statically),
# so it runs in newer systems: pack it with --tarball FILE and install it with install_insight.sh.
# Set BMDE_ROOT to build into another directory.
set -Eeuo pipefail

BMDE_ROOT="${BMDE_ROOT:-/URV/bmde}"
SUDO=""; if [ "$(id -u)" -ne 0 ]; then SUDO=sudo; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_URL="https://raw.githubusercontent.com/URV-teacher/insight-docker/master"
SOURCE=insight-7.3.50.20110803-cvs
INSIGHT_DIR="${BMDE_ROOT}/insight"
TARBALL=""
if [ "${1:-}" = "--tarball" ]; then
  TARBALL="$(readlink -m "$2")"
fi

${SUDO} apt-get update
${SUDO} apt-get install -y --no-install-recommends \
  build-essential bison flex m4 texinfo libncurses5-dev libexpat1-dev zlib1g-dev libx11-dev xz-utils wget

build_dir="$(mktemp -d)"
# Use the sources of the repository if the script is run from it, or download them otherwise
if [ -f "${SCRIPT_DIR}/../src/${SOURCE}.tar.xz" ]; then
  cp "${SCRIPT_DIR}/../src/${SOURCE}.tar.xz" "${build_dir}"
else
  wget -q "${REPO_URL}/src/${SOURCE}.tar.xz" -O "${build_dir}/${SOURCE}.tar.xz"
fi
tar -xJf "${build_dir}/${SOURCE}.tar.xz" -C "${build_dir}"

# Only the static ncurses libraries in the search path, so they are linked statically: newer systems lack ncurses 5
# (also under the other names configure looks for: curses, termcap)
mkdir -p "${build_dir}/static-libs"
for lib in ncurses curses; do
  cp /usr/lib/x86_64-linux-gnu/libncurses.a "${build_dir}/static-libs/lib${lib}.a"
done
for lib in tinfo termcap; do
  cp /usr/lib/x86_64-linux-gnu/libtinfo.a "${build_dir}/static-libs/lib${lib}.a"
done

mkdir -p "${build_dir}/build"
(
  cd "${build_dir}/build"
  # Same target as the Windows build (arm-eabi-insight, arm-eabi-gdb, arm-eabi-run). Docs are skipped (MAKEINFO=true)
  # because the texinfo of this toolchain is newer than the one of the sources
  LDFLAGS="-L${build_dir}/static-libs" "../${SOURCE}/configure" \
    --prefix="${INSIGHT_DIR}" \
    --target=arm-eabi \
    --disable-werror \
    --disable-nls \
    --with-expat \
    --without-python
  make -j"$(nproc)" MAKEINFO=true
  # Tcl 8.4 ignores DESTDIR, so it installs directly in the prefix
  ${SUDO} make install MAKEINFO=true
)
${SUDO} strip --strip-unneeded "${INSIGHT_DIR}"/bin/*
rm -rf "${build_dir}"

if [ -n "${TARBALL}" ]; then
  tar -C "${BMDE_ROOT}" -cJf "${TARBALL}" insight
  echo "Insight packed into ${TARBALL}"
fi
echo "Insight built into ${INSIGHT_DIR}"
