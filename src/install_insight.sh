#!/usr/bin/env bash
# Installs Insight 7.3.50.20110803-cvs (the version of the Windows BMDE, with arm-eabi-insight and arm-eabi-gdb) into
# /URV/bmde/insight, and its environment (PATH) into /etc/profile.d/bmde-insight.sh. Can be run in an Ubuntu / Debian
# host from a checkout of the repository (after scripts/download_assets.sh), and is also used by the BMDE Docker
# images. Set BMDE_ROOT to install into another directory.
#
# Insight is installed from the tarball built by build_insight.sh, given in INSIGHT_TARBALL (by default the one
# published in the releases of insight-docker, in assets/). Also installs the script that connects the Run button of
# Insight to the GDB stub in GDB_TARGET (used by the Docker image).
set -Eeuo pipefail

BMDE_ROOT="${BMDE_ROOT:-/URV/bmde}"
SUDO=""; if [ "$(id -u)" -ne 0 ]; then SUDO=sudo; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
INSIGHT_DIR="${BMDE_ROOT}/insight"
INSIGHT_TARBALL="${INSIGHT_TARBALL:-${SCRIPT_DIR}/../assets/insight-7.3.50.20110803-cvs-linux-x86_64.tar.xz}"

${SUDO} apt-get update
${SUDO} apt-get install -y --no-install-recommends xz-utils libx11-6 libexpat1 zlib1g

if [ ! -x "${INSIGHT_DIR}/bin/arm-eabi-insight" ]; then
  if [ ! -f "${INSIGHT_TARBALL}" ]; then
    echo "${INSIGHT_TARBALL} not found: download it with scripts/download_assets.sh" >&2
    exit 1
  fi
  ${SUDO} mkdir -p "${BMDE_ROOT}"
  ${SUDO} tar -xJf "${INSIGHT_TARBALL}" -C "${BMDE_ROOT}"
fi

# Not a symlink: Tcl finds its library relative to the path of the executable
${SUDO} tee "${INSIGHT_DIR}/bin/insight" > /dev/null <<WRAPPER
#!/usr/bin/env sh
exec "${INSIGHT_DIR}/bin/arm-eabi-insight" "\$@"
WRAPPER
${SUDO} chmod +x "${INSIGHT_DIR}/bin/insight"

${SUDO} mkdir -p "${INSIGHT_DIR}/share/bmde"
${SUDO} install -m 644 "${SCRIPT_DIR}/connect.tcl" "${INSIGHT_DIR}/share/bmde/connect.tcl"

${SUDO} tee /etc/profile.d/bmde-insight.sh > /dev/null <<PROFILE
case ":\${PATH}:" in
  *":${INSIGHT_DIR}/bin:"*) ;;
  *) export PATH="${INSIGHT_DIR}/bin:\${PATH}" ;;
esac
PROFILE

echo "Insight installed in ${INSIGHT_DIR}. Open a new session or run: . /etc/profile.d/bmde-insight.sh"
