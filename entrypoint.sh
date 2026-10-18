#!/usr/bin/env bash
set -Eeuo pipefail

# -------------------- Defaults (image-level) --------------------
: "${MODE:=none}"                     # 'host' | 'vnc' | 'none'
: "${DISPLAY:=:0}"                    # host X (used in host mode)
export X11_DISPLAY="${DISPLAY}"

: "${VNC_XVFB_DISPLAY:=:99}"          # used only in vnc mode
export XVFB_DISPLAY="${VNC_XVFB_DISPLAY}"

: "${VNC_GEOMETRY:=1024x768x24}"      # WIDTHxHEIGHTxDEPTH (24 or 32)
export GEOMETRY="${VNC_GEOMETRY}"

: "${VNC_PORT:=5900}"
: "${VNC_LISTEN:=0.0.0.0}"
: "${VNC_PASSWORD:=}"                 # optional; empty => no auth

: "${DEBUGGER:=insight}"              # 'insight' | 'arm-eabi-gdb' | 'gdb-multiarch'
: "${GDB_TARGET:=}"                   # HOST:PORT of the GDB stub to debug (e.g. DeSmuME's); empty => do not connect
: "${WAIT_FOR_TARGET:=60}"            # seconds to wait for GDB_TARGET to accept connections; 0 => do not wait
# The ELF to debug (and other debugger arguments) are expected in "$@"

# -------------------- Helpers --------------------
log() { printf '[entrypoint] %s\n' "$*"; }
die() { printf '[entrypoint][ERROR] %s\n' "$*" >&2; exit 2; }

require_bin() { command -v "$1" >/dev/null 2>&1 || die "Missing required binary: $1"; }

validate_int() {
  [[ "$1" =~ ^[0-9]+$ ]] || die "Expected integer, got '$1' for $2"
}

cleanup() {
  set +e
  if [[ -n "${X11VNC_PID:-}" ]]; then kill "${X11VNC_PID}" 2>/dev/null; fi
  if [[ -n "${XVFB_PID:-}" ]]; then kill "${XVFB_PID}" 2>/dev/null; fi
}
trap cleanup EXIT

# -------------------- Validate inputs --------------------
case "${MODE}" in
  vnc|host|none) ;;
  *) die "Invalid MODE='${MODE}'. Use MODE=host, MODE=vnc or MODE=none." ;;
esac

case "${DEBUGGER}" in
  insight) DEBUGGER_BIN=arm-eabi-insight ;;
  arm-eabi-gdb|gdb-multiarch) DEBUGGER_BIN="${DEBUGGER}" ;;
  *) die "Invalid DEBUGGER='${DEBUGGER}'. Use DEBUGGER=insight, DEBUGGER=arm-eabi-gdb or DEBUGGER=gdb-multiarch." ;;
esac
require_bin "${DEBUGGER_BIN}"

if [[ "${MODE}" == "vnc" ]]; then
  validate_int "${VNC_PORT}" "VNC_PORT"
fi
validate_int "${WAIT_FOR_TARGET}" "WAIT_FOR_TARGET"
if [[ -n "${GDB_TARGET}" && ! "${GDB_TARGET}" =~ ^.+:[0-9]+$ ]]; then
  die "Expected HOST:PORT, got GDB_TARGET='${GDB_TARGET}'"
fi

# -------------------- Prepare X / VNC stack --------------------
start_vnc_stack() {
  require_bin Xvfb
  require_bin x11vnc

  log "Starting Xvfb on ${XVFB_DISPLAY} with geometry ${GEOMETRY}"
  Xvfb "${XVFB_DISPLAY}" -screen 0 "${GEOMETRY}" -nolisten tcp &
  XVFB_PID=$!
  export DISPLAY="${XVFB_DISPLAY}"

  local VNC_AUTH_ARG=()
  if [[ -n "${VNC_PASSWORD}" ]]; then
    mkdir -p "${HOME}/.vnc"
    x11vnc -storepasswd "${VNC_PASSWORD}" "${HOME}/.vnc/passwd" >/dev/null
    VNC_AUTH_ARG=(-rfbauth "${HOME}/.vnc/passwd")
  else
    log "WARNING: x11vnc running without password (set VNC_PASSWORD to secure)"
  fi

  mkdir -p "${HOME}/logs"
  log "Starting x11vnc on ${VNC_LISTEN}:${VNC_PORT} (DISPLAY=${DISPLAY})"
  x11vnc \
    -display "${DISPLAY}" \
    -listen "${VNC_LISTEN}" \
    -rfbport "${VNC_PORT}" \
    -forever -shared \
    -noshm -noxdamage \
    -o "${HOME}/logs/x11vnc.log" \
    "${VNC_AUTH_ARG[@]}" &
  X11VNC_PID=$!
}

case "${MODE}" in
  vnc)
    start_vnc_stack
    ;;
  host)
    export DISPLAY="${X11_DISPLAY}"
    log "Using host X DISPLAY=${DISPLAY} (no VNC in this mode)"
    if [[ -z "${XAUTHORITY:-}" || ! -r "${XAUTHORITY}" ]]; then
      log "WARNING: no readable XAUTHORITY; the host X server (e.g. Xwayland) may refuse the connection."
      log "WARNING: mount the host cookie and set XAUTHORITY, or run 'xhost +SI:localuser:\$USER' on the host."
    fi
    ;;
  none)
    # Do not touch DISPLAY or start any X/VNC services.
    log "MODE=none: no X/VNC will be started."
    ;;
esac

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
  for (( i = 0; i < WAIT_FOR_TARGET; i++ )); do
    if timeout 1 bash -c "</dev/tcp/${host}/${port}" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  if (( i == WAIT_FOR_TARGET )); then
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
    cmd+=( --tclcommand=/opt/insight-docker/connect.tcl )
  fi
elif [[ -n "${GDB_TARGET}" ]]; then
  cmd+=( -ex "target remote ${GDB_TARGET}" )
fi
cmd+=( "${elf_args[@]}" "${user_args[@]}" )

log "Starting debugger: ${cmd[*]}"
# Not exec'd, so the X / VNC stack is cleaned up on exit
"${cmd[@]}"
