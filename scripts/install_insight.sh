#!/usr/bin/env bash
# Installs Insight 7.3.50.20110803-cvs (the version of the Windows BMDE, with arm-eabi-insight and arm-eabi-gdb) into
# /URV/bmde/insight, and its environment (PATH) into /etc/profile.d/bmde-insight.sh. Standalone: can be run in an
# Ubuntu / Debian host, and is also used by the BMDE Docker images. Set BMDE_ROOT to install into another directory.
#
# Insight is installed from the tarball built by build_insight.sh, given in INSIGHT_TARBALL (a file or a URL; the one
# published in the releases of insight-docker by default). Also installs the script that connects the Run button of
# Insight to the GDB stub in GDB_TARGET (used by the Docker image).
set -Eeuo pipefail

BMDE_ROOT="${BMDE_ROOT:-/URV/bmde}"
SUDO=""; if [ "$(id -u)" -ne 0 ]; then SUDO=sudo; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_URL="https://raw.githubusercontent.com/URV-teacher/insight-docker/master"
INSIGHT_DIR="${BMDE_ROOT}/insight"
INSIGHT_TARBALL="${INSIGHT_TARBALL:-https://github.com/URV-teacher/insight-docker/releases/latest/download/insight-7.3.50.20110803-cvs-linux-x86_64.tar.xz}"

${SUDO} apt-get update
${SUDO} apt-get install -y --no-install-recommends ca-certificates wget xz-utils libx11-6 libexpat1 zlib1g

if [ ! -x "${INSIGHT_DIR}/bin/arm-eabi-insight" ]; then
  if [ -f "${INSIGHT_TARBALL}" ]; then
    cp "${INSIGHT_TARBALL}" /tmp/insight.tar.xz
  else
    wget "${INSIGHT_TARBALL}" -O /tmp/insight.tar.xz
  fi
  ${SUDO} mkdir -p "${BMDE_ROOT}"
  ${SUDO} tar -xJf /tmp/insight.tar.xz -C "${BMDE_ROOT}"
  rm -f /tmp/insight.tar.xz
fi

# Not a symlink: Tcl finds its library relative to the path of the executable
${SUDO} tee "${INSIGHT_DIR}/bin/insight" > /dev/null <<WRAPPER
#!/usr/bin/env sh
exec "${INSIGHT_DIR}/bin/arm-eabi-insight" "\$@"
WRAPPER
${SUDO} chmod +x "${INSIGHT_DIR}/bin/insight"

${SUDO} mkdir -p "${INSIGHT_DIR}/share/bmde"
if [ -f "${SCRIPT_DIR}/../tcl/connect.tcl" ]; then
  ${SUDO} cp "${SCRIPT_DIR}/../tcl/connect.tcl" "${INSIGHT_DIR}/share/bmde/connect.tcl"
else
  wget -q "${REPO_URL}/tcl/connect.tcl" -O /tmp/connect.tcl
  ${SUDO} mv /tmp/connect.tcl "${INSIGHT_DIR}/share/bmde/connect.tcl"
fi

${SUDO} tee /etc/profile.d/bmde-insight.sh > /dev/null <<PROFILE
case ":\${PATH}:" in
  *":${INSIGHT_DIR}/bin:"*) ;;
  *) export PATH="${INSIGHT_DIR}/bin:\${PATH}" ;;
esac
PROFILE

echo "Insight installed in ${INSIGHT_DIR}. Open a new session or run: . /etc/profile.d/bmde-insight.sh"
