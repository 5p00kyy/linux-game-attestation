#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

all_running=1
for name in "$VERIFIER_CONTAINER" "$REGISTRAR_CONTAINER" "$AGENT_CONTAINER"; do
    if container_exists "$name"; then
        podman inspect --format '{{.Name}} running={{.State.Running}} status={{.State.Status}}' "$name"
        if [[ $(podman inspect -f '{{.State.Running}}' "$name") != true ]]; then
            all_running=0
        fi
    else
        printf '%s missing\n' "$name"
        all_running=0
    fi
done

if [[ $all_running -eq 1 && ${LGA_ALLOW_SOFTWARE_TPM_EK:-} == 1 ]]; then
    "$SCRIPT_DIR/tenant.sh" \
        -c cvstatus \
        -u "$AGENT_UUID" \
        -v 127.0.0.1
fi
