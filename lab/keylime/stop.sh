#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

remove_container "$AGENT_CONTAINER"
remove_container "$REGISTRAR_CONTAINER"
remove_container "$VERIFIER_CONTAINER"

LGA_VTPM_STATE_DIR="$VTPM_STATE" \
LGA_VTPM_CTRL_PORT="$VTPM_CTRL_PORT" \
    "$ROOT/lab/vtpm/stop.sh"
