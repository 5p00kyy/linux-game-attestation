#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lab/guest/versions.env"
# shellcheck disable=SC1091
source "$ROOT/lab/lib/state.sh"

STATE_ROOT=${LGA_GUEST_STATE_DIR:-"$LGA_STATE_HOME/fedora-guest"}
DOWNLOAD_DIR="$STATE_ROOT/downloads"
RUNTIME_DIR="$STATE_ROOT/runtime"
REPORT_DIR="$STATE_ROOT/reports"
VTPM_STATE="$STATE_ROOT/vtpm"
VTPM_CTRL_SOCKET="$VTPM_STATE/swtpm.sock"

BASE_IMAGE=${LGA_GUEST_BASE_IMAGE:-"$DOWNLOAD_DIR/$FEDORA_IMAGE_NAME"}
BASE_IMAGE_FORMAT=${LGA_GUEST_BASE_IMAGE_FORMAT:-qcow2}
GUEST_IMAGE="$RUNTIME_DIR/guest.qcow2"
SEED_IMAGE="$RUNTIME_DIR/seed.iso"
OVMF_VARS="$RUNTIME_DIR/OVMF_VARS.4m.fd"
SSH_KEY="$STATE_ROOT/ssh/id_ed25519"
SSH_KNOWN_HOSTS="$STATE_ROOT/ssh/known_hosts"
QEMU_PID_FILE="$RUNTIME_DIR/qemu.pid"
QEMU_LOG="$RUNTIME_DIR/qemu.log"

OVMF_CODE=${LGA_OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd}
OVMF_VARS_TEMPLATE=${LGA_OVMF_VARS:-/usr/share/edk2/x64/OVMF_VARS.4m.fd}
SSH_PORT=${LGA_GUEST_SSH_PORT:-2222}
AGENT_PORT=${LGA_GUEST_AGENT_PORT:-9002}
VTPM_PORT=${LGA_GUEST_VTPM_PORT:-2333}

lga_require_state_path "$STATE_ROOT"

qemu_running() {
    [[ -f "$QEMU_PID_FILE" ]] || return 1
    local pid
    pid=$(<"$QEMU_PID_FILE")
    lga_pid_is_process "$pid" qemu-system-x86_64
}

ssh_guest() {
    ssh \
        -i "$SSH_KEY" \
        -p "$SSH_PORT" \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=accept-new \
        -o "UserKnownHostsFile=$SSH_KNOWN_HOSTS" \
        lga@127.0.0.1 \
        "$@"
}

ssh_guest_ephemeral() {
    ssh \
        -i "$SSH_KEY" \
        -p "$SSH_PORT" \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o LogLevel=ERROR \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        lga@127.0.0.1 \
        "$@"
}

scp_guest_to() {
    scp \
        -i "$SSH_KEY" \
        -P "$SSH_PORT" \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o LogLevel=ERROR \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$1" "lga@127.0.0.1:$2"
}

scp_guest_from() {
    scp \
        -i "$SSH_KEY" \
        -P "$SSH_PORT" \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o LogLevel=ERROR \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "lga@127.0.0.1:$1" "$2"
}
