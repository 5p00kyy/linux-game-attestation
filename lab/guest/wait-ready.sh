#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

cloud_init_ready=0
for _ in {1..300}; do
    if ssh_guest_ephemeral 'cloud-init status --format json' \
        >"$REPORT_DIR/cloud-init-status.json" 2>/dev/null; then
        if grep -q '"status": "done"' "$REPORT_DIR/cloud-init-status.json"; then
            cloud_init_ready=1
            break
        fi
    fi
    sleep 1
done

if [[ $cloud_init_ready -ne 1 ]]; then
    printf 'cloud-init did not finish within 300 seconds\n' >&2
    exit 1
fi

python - "$REPORT_DIR/cloud-init-status.json" <<'PY'
import json
import sys

status = json.load(open(sys.argv[1], encoding="utf-8"))
if status["status"] != "done" or status["errors"] or status["recoverable_errors"]:
    raise SystemExit(f"cloud-init did not finish cleanly: {status}")
PY
