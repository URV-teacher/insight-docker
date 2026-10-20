#!/usr/bin/env bash
# Installs gdb-multiarch, a terminal debugger alternative to Insight. Standalone: can be run in an Ubuntu / Debian host,
# and is also used by the BMDE Docker images.
set -Eeuo pipefail

SUDO=""; if [ "$(id -u)" -ne 0 ]; then SUDO=sudo; fi

${SUDO} apt-get update
${SUDO} apt-get install -y --no-install-recommends gdb-multiarch
