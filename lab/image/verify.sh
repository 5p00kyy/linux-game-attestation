#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

for command in python qemu-img sbverify sfdisk sha256sum ukify; do
    command -v "$command" >/dev/null || {
        printf 'required command not found: %s\n' "$command" >&2
        exit 1
    }
done
require_keys
UKI_FILE="$OUTPUT_DIR/lga-fedora.efi"
MANIFEST="$REPORT_DIR/artifacts.sha256"

for artifact in "$IMAGE_FILE" "$UKI_FILE" "$MANIFEST"; do
    [[ -f "$artifact" ]] || {
        printf 'current image artifact is missing; run make mkosi-build: %s\n' "$artifact" >&2
        exit 1
    }
done

sha256sum --check "$MANIFEST"
qemu-img info --output=json "$IMAGE_FILE" >"$REPORT_DIR/qemu-image-info.json"
python - "$REPORT_DIR/qemu-image-info.json" <<'PY'
import json
from pathlib import Path
import sys

info = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if info.get("format") != "raw":
    raise SystemExit("mkosi output is not a raw disk image")
PY

sfdisk --json "$IMAGE_FILE" >"$REPORT_DIR/disk-layout.json"
python - "$REPORT_DIR/disk-layout.json" <<'PY'
import json
from pathlib import Path
import sys

layout = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
names = [entry.get("name", "") for entry in layout["partitiontable"]["partitions"]]
for required in ("esp", "verity_sig", "verity", "root", "home", "var"):
    if not any(required in name for name in names):
        raise SystemExit(f"expected {required} partition is absent from disk layout: {names}")
PY

sbverify --cert "$KEY_DIR/db.crt" "$UKI_FILE" >"$REPORT_DIR/uki-signature.txt"
ukify inspect "$UKI_FILE" >"$REPORT_DIR/uki-inspect.txt"
if ! grep -q 'roothash=[0-9a-f]\{64\}' "$REPORT_DIR/uki-inspect.txt"; then
    printf 'signed UKI command line does not bind a dm-verity root hash\n' >&2
    exit 1
fi

printf 'custom Fedora image artifact verification passed; reports: %s\n' "$REPORT_DIR"
