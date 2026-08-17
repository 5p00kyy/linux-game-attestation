#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

for command in genisoimage qemu-img ssh-keygen; do
    command -v "$command" >/dev/null || {
        printf 'required command not found: %s\n' "$command" >&2
        exit 1
    }
done
[[ -r "$OVMF_CODE" ]] || { printf 'OVMF code not found: %s\n' "$OVMF_CODE" >&2; exit 1; }
[[ -r "$OVMF_VARS_TEMPLATE" ]] || { printf 'OVMF vars not found: %s\n' "$OVMF_VARS_TEMPLATE" >&2; exit 1; }

if [[ ${LGA_GUEST_SKIP_FETCH:-0} != 1 ]]; then
    "$SCRIPT_DIR/fetch.sh"
fi
[[ -f "$BASE_IMAGE" ]] || { printf 'guest base image not found: %s\n' "$BASE_IMAGE" >&2; exit 1; }
mkdir -p "$RUNTIME_DIR" "$REPORT_DIR" "$(dirname -- "$SSH_KEY")"
rm -rf -- "$REPORT_DIR"
mkdir -p "$REPORT_DIR"

if [[ ! -f "$SSH_KEY" ]]; then
    ssh-keygen -q -t ed25519 -N '' -C lga-fedora-guest -f "$SSH_KEY"
fi

rm -f -- "$GUEST_IMAGE" "$SEED_IMAGE" "$OVMF_VARS" "$SSH_KNOWN_HOSTS"
rm -rf -- "$VTPM_STATE"
qemu-img create -q -f qcow2 -F "$BASE_IMAGE_FORMAT" -b "$BASE_IMAGE" "$GUEST_IMAGE" 16G
cp --reflink=auto "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"

SEED_DIR="$RUNTIME_DIR/seed"
rm -rf -- "$SEED_DIR"
mkdir -p "$SEED_DIR"
PUBLIC_KEY=$(<"$SSH_KEY.pub")
printf '%s\n' "$PUBLIC_KEY" >"$SEED_DIR/authorized_keys"

cat >"$SEED_DIR/meta-data" <<EOF
instance-id: lga-fedora-$FEDORA_RELEASE
EOF

if [[ ${LGA_GUEST_CLOUD_INIT_PROFILE:-mutable} == immutable ]]; then
    cat >"$SEED_DIR/user-data" <<EOF
#cloud-config
network:
  config: disabled
write_files:
  - path: /home/lga/.ssh/authorized_keys
    owner: lga:lga
    permissions: '0600'
    content: |
      $PUBLIC_KEY
ssh_pwauth: false
disable_root: true
runcmd:
  - [sh, -c, 'mountpoint -q /sys/kernel/security || mount -t securityfs securityfs /sys/kernel/security']
  - [sh, -c, 'test -c /dev/tpmrm0']
  - [sh, -c, 'test "\$(wc -c < /sys/kernel/security/tpm0/binary_bios_measurements)" -gt 0']
final_message: Linux Game Attestation immutable guest ready after \$UPTIME seconds
EOF
else
    cat >"$SEED_DIR/user-data" <<EOF
#cloud-config
users:
  - name: lga
    gecos: Linux Game Attestation Lab
    groups: [wheel]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - $PUBLIC_KEY
ssh_pwauth: false
disable_root: true
package_update: true
packages:
  - mokutil
  - tpm2-tools
runcmd:
  - [sh, -c, 'mountpoint -q /sys/kernel/security || mount -t securityfs securityfs /sys/kernel/security']
  - [sh, -c, 'test -c /dev/tpmrm0']
  - [sh, -c, 'test "\$(wc -c < /sys/kernel/security/tpm0/binary_bios_measurements)" -gt 0']
  - [sh, -c, 'tpm2_pcrread sha256:0,7,11 > /var/tmp/lga-pcrs.txt']
final_message: Linux Game Attestation guest ready after \$UPTIME seconds
EOF
fi

genisoimage \
    -quiet \
    -output "$SEED_IMAGE" \
    -volid CIDATA \
    -joliet \
    -rock \
    "$SEED_DIR/user-data" "$SEED_DIR/meta-data" "$SEED_DIR/authorized_keys"

printf 'prepared Fedora %s guest overlay: %s\n' "$FEDORA_RELEASE" "$GUEST_IMAGE"
