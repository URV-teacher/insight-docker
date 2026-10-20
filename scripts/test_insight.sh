#!/usr/bin/env bash
# Tests that Insight is installed, with the version of the Windows BMDE.
set -Eeuo pipefail

insight --version | tee /dev/stderr | grep -q "7.3.50.20110803-cvs"
