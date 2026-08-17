#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

cleanup() {
    "$SCRIPT_DIR/stop.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
"$SCRIPT_DIR/prepare.sh"
"$SCRIPT_DIR/start.sh"

"$SCRIPT_DIR/wait-ready.sh"

ssh_guest_ephemeral 'test -c /dev/tpmrm0'
ssh_guest_ephemeral 'test -d /sys/firmware/efi'
ssh_guest_ephemeral "sudo sh -c 'test \"\$(wc -c < /sys/kernel/security/tpm0/binary_bios_measurements)\" -gt 0'"
ssh_guest_ephemeral 'sudo tpm2_pcrread sha256:0,7,11' | tee "$REPORT_DIR/pcrs.txt"
ssh_guest_ephemeral 'sudo tpm2_getcap handles-persistent' | tee "$REPORT_DIR/persistent-handles.txt"
ssh_guest_ephemeral 'sudo sha256sum /sys/kernel/security/tpm0/binary_bios_measurements' \
    | tee "$REPORT_DIR/event-log.sha256"
ssh_guest_ephemeral 'sudo mokutil --sb-state || true' | tee "$REPORT_DIR/secure-boot.txt"
ssh_guest_ephemeral 'sudo bootctl status --no-pager || true' | tee "$REPORT_DIR/boot-status.txt"
ssh_guest_ephemeral 'systemctl status systemd-tpm2-setup.service --no-pager --full || true' \
    | tee "$REPORT_DIR/tpm-setup-status.txt"

if ! grep -q 'Measured UKI: yes' "$REPORT_DIR/boot-status.txt"; then
    printf 'guest did not report a measured UKI boot\n' >&2
    exit 1
fi

if grep -q '0x0000000000000000000000000000000000000000000000000000000000000000' "$REPORT_DIR/pcrs.txt"; then
    printf 'one or more selected boot PCRs remained zero\n' >&2
    exit 1
fi

if ! grep -q '0x81000001' "$REPORT_DIR/persistent-handles.txt"; then
    printf 'guest TPM does not contain the expected persistent SRK handle\n' >&2
    exit 1
fi

printf 'measured Fedora guest smoke test passed; reports: %s\n' "$REPORT_DIR"
