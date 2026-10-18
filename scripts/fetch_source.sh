#!/usr/bin/env bash
# Reconstructs the source tree of the Insight shipped with the Windows BMDE (devkitPro's arm-eabi-insight.exe,
# reporting GDB 7.3.50.20110803-cvs and BFD 2.21.53.20110801) from the CVS repository of sourceware.org, and packs
# it into a tarball.
#
# devkitPro built it from a CVS checkout of the "insight" module (linked on 2011-08-04 01:13 UTC). GDB's version.in
# and BFD's version.h are bumped daily at 00:00 UTC, so the version strings mean that src/gdb was checked out on
# 2011-08-03 and bfd on 2011-08-01. The only changes outside src/gdb between both dates are in bfd, opcodes and
# include (ppc64, mips, mach-o and i386 code, irrelevant for ARM), so those are taken from 2011-08-01 to reproduce
# both version strings exactly.
#
# Usage: [CVS_MIRROR=DIR] fetch_source.sh [OUTPUT_TARBALL]
# Requires: rsync, cvs, tar, xz. Downloads ~900 MB of RCS files into CVS_MIRROR (a temporary directory by default),
# so a mirror can be reused between runs.
set -Eeuo pipefail

OUTPUT="$(realpath -m "${1:-insight-7.3.50.20110803-cvs.tar.xz}")"
GDB_DATE="2011-08-03 23:59:59 UTC"
SUPPORT_DATE="2011-08-01 23:59:59 UTC"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT
MIRROR="$(realpath -m "${CVS_MIRROR:-${WORK_DIR}/cvsroot}")"

echo "Mirroring sourceware src CVS repository into ${MIRROR}"
mkdir -p "${MIRROR}"
# history is a huge (several GB) access log, not needed for checkouts
rsync -a --exclude='history*' rsync://sourceware.org/src-cvs/CVSROOT/ "${MIRROR}/CVSROOT/"
rsync -a \
  --exclude='newlib/' --exclude='libgloss/' --exclude='gold/' --exclude='sid/' --exclude='cgen/' \
  --exclude='ld/' --exclude='gas/' --exclude='binutils/' --exclude='gprof/' --exclude='elfcpp/' \
  rsync://sourceware.org/src-cvs/src/ "${MIRROR}/src/"
# The repository config points to the lock directory of the sourceware server
chmod u+w "${MIRROR}/CVSROOT/config"
sed -i 's|^LockDir=|#LockDir=|' "${MIRROR}/CVSROOT/config"

export CVSROOT="${MIRROR}"
cd "${WORK_DIR}"
echo "Checking out insight module as of ${GDB_DATE}"
cvs -Q checkout -D "${GDB_DATE}" insight
(
  cd src
  echo "Updating bfd, opcodes and include to ${SUPPORT_DATE}"
  cvs -Q update -D "${SUPPORT_DATE}" bfd opcodes include
)

grep -qx '7.3.50.20110803-cvs' src/gdb/version.in
grep -q 'BFD_VERSION_DATE 20110801' src/bfd/version.h

find src -type d -name CVS -prune -exec rm -rf {} +
mv src insight-7.3.50.20110803-cvs
echo "Packing ${OUTPUT}"
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime="${GDB_DATE}" \
  -cJf "${OUTPUT}" insight-7.3.50.20110803-cvs
sha256sum "${OUTPUT}"
