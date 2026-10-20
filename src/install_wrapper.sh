#!/usr/bin/env bash
# Installs the wrappers $DEVKITPRO/insight/bin/arm-eabi-insight(.exe), which the Makefiles of the course use to debug
# (make debug) the projects as in the Windows BMDE, where Insight is installed in devkitPro. Needs Insight
# (install_insight.sh). Standalone: can be run in an Ubuntu / Debian host, and is also used by the BMDE Docker images.
set -Eeuo pipefail

BMDE_ROOT="${BMDE_ROOT:-/URV/bmde}"
SUDO=""; if [ "$(id -u)" -ne 0 ]; then SUDO=sudo; fi
WRAPPER_DIR="${DEVKITPRO:-${BMDE_ROOT}/devkitPro}/insight/bin"

${SUDO} mkdir -p "${WRAPPER_DIR}"
for wrapper in arm-eabi-insight arm-eabi-insight.exe; do
  ${SUDO} tee "${WRAPPER_DIR}/${wrapper}" > /dev/null <<WRAPPER
#!/usr/bin/env sh
exec "${BMDE_ROOT}/insight/bin/arm-eabi-insight" "\$@"
WRAPPER
  ${SUDO} chmod +x "${WRAPPER_DIR}/${wrapper}"
done

echo "Wrappers installed in ${WRAPPER_DIR}"
