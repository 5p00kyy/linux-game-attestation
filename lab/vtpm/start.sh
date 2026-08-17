#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lab/lib/state.sh"
STATE_DIR=${LGA_VTPM_STATE_DIR:-"$LGA_STATE_HOME/vtpm"}
TPM_PORT=${LGA_VTPM_PORT:-2321}
CTRL_PORT=${LGA_VTPM_CTRL_PORT:-2322}
CTRL_SOCKET=${LGA_VTPM_CTRL_SOCKET:-}
PID_FILE="$STATE_DIR/swtpm.pid"
LOG_FILE="$STATE_DIR/swtpm.log"

lga_prepare_state_dir "$STATE_DIR"

if [[ -f "$PID_FILE" ]]; then
    pid=$(<"$PID_FILE")
    if lga_pid_is_process "$pid" swtpm; then
        printf 'swtpm already running with PID %s\n' "$pid"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

swtpm_setup \
    --tpm2 \
    --tpmstate "$STATE_DIR" \
    --createek \
    --decryption \
    --pcr-banks sha256 \
    --not-overwrite \
    --logfile "$STATE_DIR/setup.log"

if [[ -n "$CTRL_SOCKET" ]]; then
    rm -f -- "$CTRL_SOCKET"
    swtpm socket \
        --tpm2 \
        --tpmstate dir="$STATE_DIR" \
        --ctrl type=unixio,path="$CTRL_SOCKET" \
        --flags not-need-init \
        --pid file="$PID_FILE" \
        --log file="$LOG_FILE",level=1 \
        --daemon
else
    swtpm socket \
        --tpm2 \
        --tpmstate dir="$STATE_DIR" \
        --server type=tcp,port="$TPM_PORT",bindaddr=127.0.0.1 \
        --ctrl type=tcp,port="$CTRL_PORT",bindaddr=127.0.0.1 \
        --flags not-need-init \
        --pid file="$PID_FILE" \
        --log file="$LOG_FILE",level=1 \
        --daemon
fi

for _ in {1..50}; do
    if [[ -n "$CTRL_SOCKET" ]]; then
        ready_command=(swtpm_ioctl --unix "$CTRL_SOCKET" -c)
        ready_message="Unix control socket $CTRL_SOCKET"
    else
        ready_command=(swtpm_ioctl --tcp "127.0.0.1:$CTRL_PORT" -c)
        ready_message="TPM port $TPM_PORT and control port $CTRL_PORT"
    fi
    if "${ready_command[@]}" >/dev/null 2>&1; then
        printf 'swtpm ready on %s\n' "$ready_message"
        exit 0
    fi
    sleep 0.1
done

printf 'swtpm failed to become ready; see %s\n' "$LOG_FILE" >&2
exit 1
