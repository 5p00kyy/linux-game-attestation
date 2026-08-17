#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

export LGA_ALLOW_SOFTWARE_TPM_EK=1

cleanup() {
    "$SCRIPT_DIR/stop.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
reclaim_state_ownership
rm -rf -- "$STATE_ROOT"
mkdir -p "$STATE_ROOT"

"$SCRIPT_DIR/start.sh"

"$SCRIPT_DIR/tenant.sh" \
    -c regstatus \
    -u "$AGENT_UUID" \
    -r 127.0.0.1 \
    -rp 8891 >"$REPORT_DIR/registrar-status.log" 2>&1

"$SCRIPT_DIR/tenant.sh" \
    -c add \
    -t 127.0.0.1 \
    -tp 9002 \
    -v 127.0.0.1 \
    -u "$AGENT_UUID" \
    --tpm_policy '{}' >"$REPORT_DIR/tenant-add.log" 2>&1

for _ in {1..30}; do
    if "$SCRIPT_DIR/tenant.sh" \
        -c cvstatus \
        -u "$AGENT_UUID" \
        -v 127.0.0.1 >"$REPORT_DIR/verifier-status.log" 2>&1; then
        if grep -q '"attestation_status": "PASS"' "$REPORT_DIR/verifier-status.log"; then
            break
        fi
    fi
    sleep 1
done

if ! grep -q '"attestation_status": "PASS"' "$REPORT_DIR/verifier-status.log"; then
    cat "$REPORT_DIR/verifier-status.log" >&2
    printf 'Keylime verifier did not reach PASS\n' >&2
    exit 1
fi

python "$SCRIPT_DIR/identity_check.py" "$STATE_ROOT" "$AGENT_UUID" "$KEYLIME_API_VERSION"
printf 'Keylime transport smoke test passed; reports: %s\n' "$REPORT_DIR"
