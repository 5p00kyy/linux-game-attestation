#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

command -v qemu-system-x86_64 >/dev/null || { printf 'qemu-system-x86_64 is required\n' >&2; exit 1; }
[[ -r /dev/kvm && -w /dev/kvm ]] || { printf '/dev/kvm is unavailable\n' >&2; exit 1; }
[[ -f "$GUEST_IMAGE" && -f "$SEED_IMAGE" && -f "$OVMF_VARS" ]] || {
    printf 'guest is not prepared; run make guest-prepare\n' >&2
    exit 1
}

if qemu_running; then
    printf 'guest already running with PID %s\n' "$(<"$QEMU_PID_FILE")"
    exit 0
fi
rm -f -- "$QEMU_PID_FILE" "$QEMU_LOG"

LGA_VTPM_STATE_DIR="$VTPM_STATE" \
LGA_VTPM_PORT="$VTPM_PORT" \
LGA_VTPM_CTRL_SOCKET="$VTPM_CTRL_SOCKET" \
    "$ROOT/lab/vtpm/start.sh"

qemu-system-x86_64 \
    -name lga-fedora-guest \
    -machine q35,accel=kvm,smm=on \
    -cpu host \
    -smp 2 \
    -m 3072 \
    -global driver=cfi.pflash01,property=secure,value=on \
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_CODE" \
    -drive "if=pflash,format=raw,unit=1,file=$OVMF_VARS" \
    -drive "if=virtio,format=qcow2,file=$GUEST_IMAGE" \
    -drive "if=none,id=seed,format=raw,readonly=on,file=$SEED_IMAGE" \
    -device ide-cd,drive=seed \
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22,hostfwd=tcp:127.0.0.1:$AGENT_PORT-:$AGENT_PORT" \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-rng-pci \
    -chardev "socket,id=chrtpm,path=$VTPM_CTRL_SOCKET" \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-crb,tpmdev=tpm0 \
    -display none \
    -serial "file:$QEMU_LOG" \
    -monitor none \
    -pidfile "$QEMU_PID_FILE" \
    -daemonize

deadline=$((SECONDS + 180))
while ((SECONDS < deadline)); do
    if ssh_guest_ephemeral true >/dev/null 2>&1; then
        printf 'Fedora guest ready for SSH on 127.0.0.1:%s\n' "$SSH_PORT"
        exit 0
    fi
    if ! qemu_running; then
        printf 'QEMU exited before SSH became ready; see %s\n' "$QEMU_LOG" >&2
        exit 1
    fi
    sleep 1
done

printf 'guest SSH did not become ready; see %s\n' "$QEMU_LOG" >&2
exit 1
