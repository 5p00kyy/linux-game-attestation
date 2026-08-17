#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ssh_guest_ephemeral 'test -f /run/lga-provisioned'
ssh_guest_ephemeral 'sudo systemctl is-active --quiet lga-provision-ssh.service sshd.service systemd-networkd.service'
