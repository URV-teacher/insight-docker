#!/usr/bin/env bash
# Builds Insight into a tarball to install it in hosts with src/install_insight.sh (build/ by default). Insight needs
# the toolchain of Ubuntu 14.04, so it is built by the build stage of the Dockerfile, from the sources downloaded into
# assets/ by scripts/download_assets.sh, and the tarball is copied out of it. Needs Docker.
#
#   scripts/build_tarball.sh [TARBALL]
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
TARBALL_NAME=insight-7.3.50.20110803-cvs-linux-x86_64.tar.xz
OUTPUT="$(readlink -m "${1:-${REPO_DIR}/build/${TARBALL_NAME}}")"

image="$(docker build -q --target build "${REPO_DIR}")"
mkdir -p "$(dirname "${OUTPUT}")"
docker run --rm --entrypoint cat "${image}" "/${TARBALL_NAME}" > "${OUTPUT}"
docker rmi "${image}" > /dev/null
echo "Insight built into ${OUTPUT}"
