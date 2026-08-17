#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lab/lib/state.sh"
STATE_DIR=${LGA_VTPM_STATE_DIR:-"$LGA_STATE_HOME/vtpm"}
CTRL_PORT=${LGA_VTPM_CTRL_PORT:-2322}
CTRL_SOCKET=${LGA_VTPM_CTRL_SOCKET:-}
PID_FILE="$STATE_DIR/swtpm.pid"

if [[ ! -f "$PID_FILE" ]]; then
    printf 'stopped\n'
    exit 1
fi

pid=$(<"$PID_FILE")
if ! lga_pid_is_process "$pid" swtpm; then
    printf 'stale PID file: %s\n' "$pid" >&2
    exit 1
fi

if [[ -n "$CTRL_SOCKET" ]]; then
    swtpm_ioctl --unix "$CTRL_SOCKET" -c >/dev/null
    printf 'running: pid=%s control_socket=%s\n' "$pid" "$CTRL_SOCKET"
else
    swtpm_ioctl --tcp "127.0.0.1:$CTRL_PORT" -c >/dev/null
    printf 'running: pid=%s control_port=%s\n' "$pid" "$CTRL_PORT"
fi
