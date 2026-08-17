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
    printf 'swtpm is not running\n'
    exit 0
fi

pid=$(<"$PID_FILE")
if lga_pid_is_process "$pid" swtpm; then
    if [[ -n "$CTRL_SOCKET" ]]; then
        swtpm_ioctl --unix "$CTRL_SOCKET" -s >/dev/null
    else
        swtpm_ioctl --tcp "127.0.0.1:$CTRL_PORT" -s >/dev/null
    fi
    for _ in {1..50}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
fi

if kill -0 "$pid" 2>/dev/null && ! lga_pid_is_process "$pid" swtpm; then
    printf 'refusing to stop unrelated process from stale PID file: %s\n' "$pid" >&2
    exit 1
fi

rm -f "$PID_FILE"
if [[ -n "$CTRL_SOCKET" ]]; then
    rm -f -- "$CTRL_SOCKET"
fi
printf 'swtpm stopped\n'
