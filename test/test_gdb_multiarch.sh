#!/usr/bin/env bash
# Tests that gdb-multiarch is installed and supports ARM.
set -Eeuo pipefail

gdb-multiarch --version | head -n 1
gdb-multiarch -batch -ex "set architecture armv5te"
echo "gdb-multiarch OK"
