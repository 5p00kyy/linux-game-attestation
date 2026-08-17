#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lab/lib/state.sh"

LGA_KEYLIME_STATE_DIR="$LGA_STATE_HOME/keylime-mb-probe" \
LGA_ENABLE_MB_POLICY=1 \
LGA_EXPECT_MB_FAILURE=1 \
    exec "$SCRIPT_DIR/guest-smoke.sh"
