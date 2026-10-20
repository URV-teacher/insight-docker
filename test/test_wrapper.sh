#!/usr/bin/env bash
# Tests the wrappers $DEVKITPRO/insight/bin/arm-eabi-insight(.exe) used by the Makefiles of the course.
set -Eeuo pipefail

for wrapper in arm-eabi-insight arm-eabi-insight.exe; do
  "${DEVKITPRO:-/URV/bmde/devkitPro}/insight/bin/${wrapper}" --version | head -n 1
done
