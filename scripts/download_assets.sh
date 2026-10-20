#!/usr/bin/env bash
# Downloads the assets of insight-docker.
#
# Downloads the assets needed to build and test the component into assets/, the only place from where its install
# scripts (src/) and its tests (test/) take them: building never accesses external systems. For each asset: if it is
# already in assets/, checks its SHA-256; if it is not, downloads it and then checks its SHA-256. The assets that are
# always the latest version of their source have no pinned SHA-256, so they are downloaded but not checked. Fails if
# any asset could not be downloaded or does not match its SHA-256. The external resources are listed in the
# documentation of bmde (docs/development/external-resources.md).
#
#   scripts/download_assets.sh [ASSET...]    (every asset by default)
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/../assets"
SELECTED=" $* "
failed=0

# Downloads the URL $1 into the file $2
download() {
  if command -v wget > /dev/null; then
    wget -q "$1" -O "$2"
  else
    curl -fsSL "$1" -o "$2"
  fi
}

# Obtains the source $1 into the file $2: a URL, or function:NAME to make it with the function NAME (given the file)
obtain() {
  case "$1" in
    function:*) "${1#function:}" "$2" ;;
    *) download "$1" "$2" ;;
  esac
}

# SHA-256 of the file $1 (replaced below for the sources of Insight)
# shellcheck disable=SC2329
checksum() {
  sha256sum "$1" | cut -d ' ' -f 1
}

# asset NAME SHA256 SOURCE...: makes sure that assets/NAME is there and has the SHA-256 SHA256 (empty if it is not
# pinned). If it is not there, it is obtained from the first SOURCE that works. An asset without SOURCE is stored in
# the repository, so it is only checked
asset() {
  local name="$1" sha256="$2" file="${ASSETS_DIR}/$1" source actual
  shift 2
  if [ "${SELECTED}" != "  " ] && [[ "${SELECTED}" != *" ${name} "* ]]; then
    return 0
  fi
  if [ -f "${file}" ]; then
    echo "${name}: present"
  else
    mkdir -p "$(dirname "${file}")"
    for source in "$@"; do
      echo "${name}: downloading from ${source}"
      if obtain "${source}" "${file}.part"; then
        mv "${file}.part" "${file}"
        break
      fi
      rm -f "${file}.part"
      echo "${name}: could not be downloaded from ${source}" >&2
    done
    if [ ! -f "${file}" ] && [ "$#" -eq 0 ]; then
      echo "${name}: ERROR, missing (it is stored in the repository: restore it with git)" >&2
      failed=1
      return 0
    elif [ ! -f "${file}" ]; then
      echo "${name}: ERROR, could not be downloaded" >&2
      failed=1
      return 0
    fi
  fi
  if [ -z "${sha256}" ]; then
    echo "${name}: not checked (latest version, without pinned SHA-256)"
    return 0
  fi
  actual="$(checksum "${file}")"
  if [ "${actual}" = "${sha256}" ]; then
    echo "${name}: OK, the SHA-256 matches"
  else
    echo "${name}: ERROR, the SHA-256 does not match (expected ${sha256}, got ${actual}). Delete it to download it" \
      "again" >&2
    failed=1
  fi
}

# Reconstructs the sources of Insight from the CVS repository of sourceware.org into the file $1 (~900 MB download)
# shellcheck disable=SC2329  # Called through a function: source of asset
fetch_insight_source() {
  bash "${SCRIPT_DIR}/fetch_source.sh" "$1"
}

# The sources of Insight are checked by the SHA-256 of their files (of the list of the SHA-256 of every file, sorted by
# path) instead of the tarball, so the check does not depend on the versions of tar and xz that packed it
# shellcheck disable=SC2329  # Replaces the checksum function above
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
