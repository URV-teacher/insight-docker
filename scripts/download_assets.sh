#!/usr/bin/env bash
# Downloads the assets of insight-docker into assets/.
#
# The download logic is the one shared by every component of the BMDE (download_lib.sh, copied from bmde: see it for
# the details). The external resources are listed in the documentation of bmde (docs/development/external-resources.md).
#
#   scripts/download_assets.sh [ASSET...]    (every asset by default)
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=download_lib.sh
source "${SCRIPT_DIR}/download_lib.sh" "$@"

# Reconstructs the sources of Insight from the CVS repository of sourceware.org into the file $1 (~900 MB download)
# shellcheck disable=SC2329  # Called through a function: source of asset
fetch_insight_source() {
  bash "${SCRIPT_DIR}/fetch_source.sh" "$1"
}

# The sources of Insight are checked by the SHA-256 of their files (of the list of the SHA-256 of every file, sorted by
# path) instead of the tarball, so the check does not depend on the versions of tar and xz that packed it
# shellcheck disable=SC2329  # Replaces the checksum function of download_lib.sh
checksum() {
  if [[ "$1" != *-cvs.tar.xz* ]]; then
    sha256sum "$1" | cut -d ' ' -f 1
    return
  fi
  local tree_dir
  tree_dir="$(mktemp -d)"
  tar -xJf "$1" -C "${tree_dir}"
  (cd "${tree_dir}"/insight-* && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) \
    | sha256sum | cut -d ' ' -f 1
  rm -rf "${tree_dir}"
}

# Sources of Insight 7.3.50.20110803-cvs (the version of the Windows BMDE), built by the image. It was never released
# as a tarball, so it is reconstructed from the CVS history of sourceware.org (needs rsync and cvs)
asset insight-7.3.50.20110803-cvs.tar.xz 1ce1b5ef3c254e0e28bc7d5ec32d1423a0a50c806c5439e04036ebecdc28c6fb \
  function:fetch_insight_source
# Hello world project of the course, built and debugged by test_operation.sh (latest version)
asset hello-world-nds.tar.gz "" "https://github.com/URV-teacher/hello-world-nds/archive/refs/heads/master.tar.gz"

exit "${failed}"
