#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
IMAGE_DIR="$ROOT/lab/image"
# shellcheck disable=SC1091
source "$ROOT/lab/lib/state.sh"
STATE_ROOT=${LGA_MKOSI_STATE_DIR:-"$LGA_STATE_HOME/fedora-mkosi"}
KEY_DIR="$STATE_ROOT/keys"
OUTPUT_DIR="$STATE_ROOT/output"
REPORT_DIR="$STATE_ROOT/reports"
OVMF_DIR="$STATE_ROOT/ovmf"
OVMF_ENROLLED="$OVMF_DIR/OVMF_VARS.lga.fd"
KEY_METADATA="$KEY_DIR/metadata.env"
IMAGE_FILE="$OUTPUT_DIR/lga-fedora.raw"

OVMF_VARS_TEMPLATE=${LGA_IMAGE_OVMF_VARS_TEMPLATE:-/usr/share/edk2/x64/OVMF_VARS.4m.fd}

lga_require_state_path "$STATE_ROOT"

require_keys() {
    local file
    for file in PK.key PK.crt KEK.key KEK.crt db.key db.crt verity.key verity.crt metadata.env; do
        [[ -f "$KEY_DIR/$file" ]] || {
            printf 'missing lab key material; run make mkosi-keys\n' >&2
            exit 1
        }
    done
}
