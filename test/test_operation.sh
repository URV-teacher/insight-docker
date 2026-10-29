#!/usr/bin/env bash
# Tests the debug operation: builds the hello world project of the course, runs it in DeSmuME with its GDB stub as
# make debug does, and debugs it with arm-eabi-gdb (the GDB of Insight) and gdb-multiarch: connects, stops at main and
# steps. Needs devkitARM, libnds and DeSmuME. Without a display (e.g. in a container) it uses a virtual one.
set -Eeuo pipefail

work_dir="$(mktemp -d)"
# Hello world project of the course, downloaded by scripts/download_assets.sh
mkdir "${work_dir}/hello-world-nds"
tar -xzf "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/../assets/hello-world-nds.tar.gz" \
  -C "${work_dir}/hello-world-nds" --strip-components=1
make -C "${work_dir}/hello-world-nds"
display=(); if [ -z "${DISPLAY:-}" ]; then display=(xvfb-run -a); fi

status=0
# Each debugger with its own DeSmuME and port, so the previous one has not to release it first. Ports under 1024 need
# root out of containers
port=1024
for gdb in arm-eabi-gdb gdb-multiarch; do
  port=$((port + 1))
  "${display[@]}" desmume --disable-sound --arm9gdb="${port}" "${work_dir}"/hello-world-nds/*.nds > /dev/null 2>&1 &
  desmume_pid=$!
  sleep 5
  timeout 60 "${gdb}" -batch -ex "target remote localhost:${port}" -ex "break main" -ex "continue" -ex "next" \
    "${work_dir}"/hello-world-nds/*.elf | tee "${work_dir}/gdb.log" || true
  grep -q "Breakpoint 1, main" "${work_dir}/gdb.log" || { echo "${gdb} did not stop at main"; status=1; }
  kill "${desmume_pid}" 2>/dev/null || true
  pkill -x desmume 2>/dev/null || true
  wait "${desmume_pid}" 2>/dev/null || true
done
rm -rf "${work_dir}"
[ "${status}" -eq 0 ]
echo "debug operation OK"
