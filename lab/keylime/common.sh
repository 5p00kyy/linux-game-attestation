#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lab/keylime/versions.env"
# shellcheck disable=SC1091
source "$ROOT/lab/lib/state.sh"

STATE_ROOT=${LGA_KEYLIME_STATE_DIR:-"$LGA_STATE_HOME/keylime-transport"}
SERVER_STATE="$STATE_ROOT/server"
AGENT_STATE="$STATE_ROOT/agent"
VTPM_STATE="$STATE_ROOT/vtpm"
REPORT_DIR="$STATE_ROOT/reports"

AGENT_UUID=${LGA_KEYLIME_AGENT_UUID:-d432fbb3-d2f1-4a97-9ef7-75bd81c00000}
VTPM_PORT=${LGA_KEYLIME_VTPM_PORT:-2323}
VTPM_CTRL_PORT=${LGA_KEYLIME_VTPM_CTRL_PORT:-2324}

VERIFIER_CONTAINER=lga-keylime-verifier
REGISTRAR_CONTAINER=lga-keylime-registrar
AGENT_CONTAINER=lga-keylime-agent
TPM2_TOOLS_IMAGE=${LGA_TPM2_TOOLS_IMAGE:-localhost/lga-tpm2-tools:bookworm}

lga_require_state_path "$STATE_ROOT"

container_exists() {
    podman container exists "$1"
}

remove_container() {
    local name=$1
    if container_exists "$name"; then
        podman stop --time 10 "$name" >/dev/null 2>&1 || true
        podman rm --force "$name" >/dev/null 2>&1 || true
    fi
}

ensure_tpm2_tools_image() {
    if ! podman image exists "$TPM2_TOOLS_IMAGE"; then
        podman build \
            --file "$ROOT/containers/tpm2-tools/Containerfile" \
            --tag "$TPM2_TOOLS_IMAGE" \
            "$ROOT"
    fi
}

reclaim_state_ownership() {
    if [[ -d "$STATE_ROOT" ]]; then
        podman unshare chown -R 0:0 "$STATE_ROOT"
        chmod -R u+rwX "$STATE_ROOT"
    fi
}

wait_for_url() {
    local url=$1
    local scheme=${2:-http}
    local ca=${3:-}
    local attempt
    local -a curl_args=(--silent --show-error --fail)

    if [[ "$scheme" == https ]]; then
        if [[ -n "$ca" ]]; then
            curl_args+=(--cacert "$ca")
        else
            curl_args+=(--insecure)
        fi
    fi

    for attempt in {1..60}; do
        if curl "${curl_args[@]}" "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.5
    done
    return 1
}
