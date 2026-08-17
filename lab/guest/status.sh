#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

if qemu_running; then
    printf 'guest running pid=%s ssh=127.0.0.1:%s\n' "$(<"$QEMU_PID_FILE")" "$SSH_PORT"
    ssh_guest_ephemeral 'printf "cloud-init="; cloud-init status 2>/dev/null || true'
else
    printf 'guest stopped\n'
fi
