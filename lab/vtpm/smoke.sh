#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lab/lib/state.sh"
STATE_DIR="$LGA_STATE_HOME/vtpm-smoke"
QUOTE_DIR="$LGA_STATE_HOME/quote-smoke"
IMAGE=${LGA_TPM2_TOOLS_IMAGE:-localhost/lga-tpm2-tools:bookworm}
TPM_PORT=${LGA_VTPM_PORT:-2321}
CTRL_PORT=${LGA_VTPM_CTRL_PORT:-2322}

lga_require_state_path "$STATE_DIR"
lga_require_state_path "$QUOTE_DIR"

export LGA_VTPM_STATE_DIR="$STATE_DIR"
export LGA_VTPM_PORT="$TPM_PORT"
export LGA_VTPM_CTRL_PORT="$CTRL_PORT"

cleanup() {
    "$ROOT/lab/vtpm/stop.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
rm -rf -- "$STATE_DIR" "$QUOTE_DIR"
lga_prepare_state_dir "$STATE_DIR"
lga_prepare_state_dir "$QUOTE_DIR"

podman build \
    --file "$ROOT/containers/tpm2-tools/Containerfile" \
    --tag "$IMAGE" \
    "$ROOT"

"$ROOT/lab/vtpm/start.sh"

podman run \
    --rm \
    --network host \
    --userns keep-id \
    --env "TPM2TOOLS_TCTI=swtpm:host=127.0.0.1,port=$TPM_PORT" \
    --volume "$QUOTE_DIR:/work" \
    "$IMAGE" \
    /usr/local/bin/lga-quote-smoke

test -s "$QUOTE_DIR/quote.msg"
test -s "$QUOTE_DIR/quote.sig"
test -s "$QUOTE_DIR/quote.pcrs"
test -s "$QUOTE_DIR/akpub.pem"

printf 'vTPM quote artifacts: %s\n' "$QUOTE_DIR"
