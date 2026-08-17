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
ssh_guest_ephemeral 'sudo mokutil --sb-state' | tee "$REPORT_DIR/secure-boot.txt"
ssh_guest_ephemeral 'sudo mokutil --db' | tee "$REPORT_DIR/secure-boot-db.txt"
ssh_guest_ephemeral 'sudo bootctl status --no-pager' | tee "$REPORT_DIR/boot-status.txt"
ssh_guest_ephemeral 'sudo tpm2_pcrread sha256:0,4,7,9,11' | tee "$REPORT_DIR/pcrs.txt"
ssh_guest_ephemeral 'sudo tpm2_getcap handles-persistent' | tee "$REPORT_DIR/persistent-handles.txt"
ssh_guest_ephemeral 'sudo sha256sum /sys/kernel/security/tpm0/binary_bios_measurements' \
    | tee "$REPORT_DIR/event-log.sha256"
ssh_guest_ephemeral 'findmnt -no FSTYPE /' | tee "$REPORT_DIR/root-fstype.txt"
ssh_guest_ephemeral 'findmnt -no SOURCE /' | tee "$REPORT_DIR/root-source.txt"
ssh_guest_ephemeral 'sudo dmsetup ls --target verity' | tee "$REPORT_DIR/verity-devices.txt"
ssh_guest_ephemeral "stat -c '%U:%G:%a' /home/lga /home/lga/.ssh /home/lga/.ssh/authorized_keys" \
    | tee "$REPORT_DIR/home-permissions.txt"
ssh_guest_ephemeral "sudo stat -c '%U:%G:%a' /var/lib/lga-ssh/ssh_host_ed25519_key" \
    | tee "$REPORT_DIR/ssh-host-key-permissions.txt"
ssh_guest_ephemeral 'sudo systemctl --failed --no-legend --plain' \
    | tee "$REPORT_DIR/failed-units.txt"

grep -qi 'SecureBoot enabled' "$REPORT_DIR/secure-boot.txt"
grep -q 'Measured UKI: yes' "$REPORT_DIR/boot-status.txt"
grep -qx 'erofs' "$REPORT_DIR/root-fstype.txt"
grep -q '^/dev/mapper/' "$REPORT_DIR/root-source.txt"
grep -q . "$REPORT_DIR/verity-devices.txt"
grep -qx 'root:root:600' "$REPORT_DIR/ssh-host-key-permissions.txt"
test ! -s "$REPORT_DIR/failed-units.txt"
python - "$REPORT_DIR/home-permissions.txt" <<'PY'
from pathlib import Path
import sys

actual = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
expected = ["lga:lga:700", "lga:lga:700", "lga:lga:600"]
if actual != expected:
    raise SystemExit(f"unexpected home permissions: {actual!r}")
PY

if grep -q '0x0000000000000000000000000000000000000000000000000000000000000000' "$REPORT_DIR/pcrs.txt"; then
    printf 'one or more selected boot PCRs remained zero\n' >&2
    exit 1
fi
if ! grep -q '0x81000001' "$REPORT_DIR/persistent-handles.txt"; then
    printf 'guest TPM does not contain the expected persistent SRK handle\n' >&2
    exit 1
fi

printf 'custom signed and verity-protected Fedora guest smoke test passed; reports: %s\n' "$REPORT_DIR"
