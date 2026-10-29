#!/usr/bin/env bash
# Tests arm-eabi-gdb, the terminal GDB of the same build of Insight, debugging ARM programs.
set -Eeuo pipefail

arm-eabi-gdb --version | head -n 1
arm-eabi-gdb -batch -ex "show architecture" | grep -q "arm"
echo "arm-eabi-gdb OK"
