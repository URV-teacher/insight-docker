#!/usr/bin/env bash
set -Eeuo pipefail

# Logging, validation and graphical output (MODE, VNC_*) shared by the BMDE images (from the base image)
# shellcheck source=/dev/null
source /usr/local/lib/bmde/entrypoint.sh

# -------------------- Defaults (image-level) --------------------
: "${DEBUGGER:=insight}"              # 'insight' | 'arm-eabi-gdb' | 'gdb-multiarch'
: "${GDB_TARGET:=}"                   # HOST:PORT of the GDB stub to debug (e.g. DeSmuME's); empty => do not connect
: "${WAIT_FOR_TARGET:=60}"            # seconds to wait for GDB_TARGET to accept connections; 0 => do not wait
# The ELF to debug (and other debugger arguments) are expected in "$@"
CONNECT_TCL="${BMDE_ROOT:-/URV/bmde}/insight/share/bmde/connect.tcl"

# -------------------- Validate inputs --------------------
case "${DEBUGGER}" in
  insight) DEBUGGER_BIN=arm-eabi-insight ;;
  arm-eabi-gdb|gdb-multiarch) DEBUGGER_BIN="${DEBUGGER}" ;;
  *) die "Invalid DEBUGGER='${DEBUGGER}'. Use DEBUGGER=insight, DEBUGGER=arm-eabi-gdb or DEBUGGER=gdb-multiarch." ;;
esac
require_bin "${DEBUGGER_BIN}"

validate_int "${WAIT_FOR_TARGET}" "WAIT_FOR_TARGET"
if [[ -n "${GDB_TARGET}" && ! "${GDB_TARGET}" =~ ^.+:[0-9]+$ ]]; then
  die "Expected HOST:PORT, got GDB_TARGET='${GDB_TARGET}'"
fi

# -------------------- Graphical output --------------------
setup_display

# -------------------- ELF selection --------------------
user_args=( "$@" )

elf_given=0
for arg in "${user_args[@]}"; do
  [[ "${arg}" == *.elf ]] && elf_given=1
done

elf_args=()
if (( ! elf_given )); then
  mapfile -t elf_files < <(find . -maxdepth 1 -type f -name '*.elf' | sort)
  if (( ${#elf_files[@]} == 0 )); then
    die "No .elf files found in ${PWD}. Pass the ELF to debug as an argument."
  fi
  elf_args=( "${elf_files[0]#./}" )
  log "Using ELF found in ${PWD}: ${elf_args[0]}"
fi

# -------------------- Wait for the GDB stub --------------------
if [[ -n "${GDB_TARGET}" && "${WAIT_FOR_TARGET}" != "0" ]]; then
  host="${GDB_TARGET%:*}"
  port="${GDB_TARGET##*:}"
  log "Waiting up to ${WAIT_FOR_TARGET}s for the GDB stub at ${GDB_TARGET}"
  if ! wait_for_port "${host}" "${port}" "${WAIT_FOR_TARGET}"; then
    log "WARNING: ${GDB_TARGET} is not accepting connections; starting the debugger anyway"
  fi
fi

# -------------------- Build debugger command --------------------
cmd=( "${DEBUGGER_BIN}" )
if [[ "${DEBUGGER}" == "insight" ]]; then
  # Insight saves its preferences in the working directory unless they already exist in HOME
  if [[ ! -f "${HOME}/.gdbtkinit" ]]; then
    printf '# GDBtk Init file\n# GDBtkInitVersion: 1\n' > "${HOME}/.gdbtkinit"
  fi
  if [[ -n "${GDB_TARGET}" ]]; then
    log "Press the Run button of Insight to connect to ${GDB_TARGET}"
    cmd+=( "--tclcommand=${CONNECT_TCL}" )
  fi
elif [[ -n "${GDB_TARGET}" ]]; then
  cmd+=( -ex "target remote ${GDB_TARGET}" )
fi
cmd+=( "${elf_args[@]}" "${user_args[@]}" )

log "Starting debugger: ${cmd[*]}"
# Not exec'd, so the X / VNC stack is cleaned up on exit
"${cmd[@]}"
