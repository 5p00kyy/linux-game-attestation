#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

if qemu_running; then
    pid=$(<"$QEMU_PID_FILE")
    ssh_guest_ephemeral sudo poweroff >/dev/null 2>&1 || kill -TERM "$pid" 2>/dev/null || true
    for _ in {1..60}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 0.5
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
    fi
fi
rm -f -- "$QEMU_PID_FILE"

LGA_VTPM_STATE_DIR="$VTPM_STATE" \
LGA_VTPM_CTRL_SOCKET="$VTPM_CTRL_SOCKET" \
    "$ROOT/lab/vtpm/stop.sh"
