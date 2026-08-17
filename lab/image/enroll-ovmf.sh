#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

command -v virt-fw-vars >/dev/null || { printf 'virt-fw-vars is required\n' >&2; exit 1; }
[[ -r "$OVMF_VARS_TEMPLATE" ]] || { printf 'OVMF vars template not found: %s\n' "$OVMF_VARS_TEMPLATE" >&2; exit 1; }
require_keys
# shellcheck disable=SC1090
source "$KEY_METADATA"

mkdir -p "$OVMF_DIR" "$REPORT_DIR"
rm -f -- "$OVMF_ENROLLED"

virt-fw-vars \
    --input "$OVMF_VARS_TEMPLATE" \
    --no-microsoft \
    --set-pk "$OWNER_GUID" "$KEY_DIR/PK.crt" \
    --add-kek "$OWNER_GUID" "$KEY_DIR/KEK.crt" \
    --add-db "$OWNER_GUID" "$KEY_DIR/db.crt" \
    --secure-boot \
    --output "$OVMF_ENROLLED"

virt-fw-vars --input "$OVMF_ENROLLED" --print --hashes >"$REPORT_DIR/ovmf-variables.txt"
sha256sum "$OVMF_ENROLLED" >"$REPORT_DIR/ovmf-variables.sha256"

printf 'enrolled lab-only PK, KEK, and db in %s\n' "$OVMF_ENROLLED"
