#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

command -v mkosi >/dev/null || { printf 'mkosi is required\n' >&2; exit 1; }
command -v qemu-img >/dev/null || { printf 'qemu-img is required\n' >&2; exit 1; }
require_keys
lga_prepare_state_dir "$STATE_ROOT"
lga_prepare_state_dir "$OUTPUT_DIR"
rm -rf -- "$REPORT_DIR"
lga_prepare_state_dir "$REPORT_DIR"

mkosi_args=(
    --directory "$IMAGE_DIR"
    --force
    --output-directory "$OUTPUT_DIR"
    --secure-boot-key "$KEY_DIR/db.key"
    --secure-boot-certificate "$KEY_DIR/db.crt"
    --verity-key "$KEY_DIR/verity.key"
    --verity-certificate "$KEY_DIR/verity.crt"
)

mkosi "${mkosi_args[@]}" summary >"$REPORT_DIR/mkosi-summary.txt"
mkosi "${mkosi_args[@]}" build

UKI_FILE="$OUTPUT_DIR/lga-fedora.efi"
for artifact in "$IMAGE_FILE" "$UKI_FILE"; do
    [[ -f "$artifact" ]] || {
        printf 'mkosi did not create expected artifact: %s\n' "$artifact" >&2
        exit 1
    }
done

sha256sum "$IMAGE_FILE" "$UKI_FILE" >"$REPORT_DIR/artifacts.sha256"
qemu-img info --output=json "$IMAGE_FILE" >"$REPORT_DIR/qemu-image-info.json"
printf 'built signed Fedora image and UKI under %s\n' "$OUTPUT_DIR"
