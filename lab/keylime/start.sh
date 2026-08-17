#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

started=0
cleanup_failed_start() {
    if [[ $started -eq 0 ]]; then
        remove_container "$AGENT_CONTAINER"
        remove_container "$REGISTRAR_CONTAINER"
        remove_container "$VERIFIER_CONTAINER"
        LGA_VTPM_STATE_DIR="$VTPM_STATE" \
        LGA_VTPM_CTRL_PORT="$VTPM_CTRL_PORT" \
            "$ROOT/lab/vtpm/stop.sh" >/dev/null 2>&1 || true
    fi
}
trap cleanup_failed_start EXIT

for command in curl install podman swtpm swtpm_ioctl swtpm_setup; do
    command -v "$command" >/dev/null || {
        printf 'required command not found: %s\n' "$command" >&2
        exit 1
    }
done

mkdir -p "$SERVER_STATE" "$AGENT_STATE" "$REPORT_DIR"
ensure_tpm2_tools_image

remove_container "$AGENT_CONTAINER"

"$SCRIPT_DIR/server-start.sh"

LGA_VTPM_STATE_DIR="$VTPM_STATE" \
LGA_VTPM_PORT="$VTPM_PORT" \
LGA_VTPM_CTRL_PORT="$VTPM_CTRL_PORT" \
    "$ROOT/lab/vtpm/start.sh"

podman run --rm --network host \
    --env "TPM2TOOLS_TCTI=swtpm:host=127.0.0.1,port=$VTPM_PORT" \
    "$TPM2_TOOLS_IMAGE" \
    tpm2_startup -c

podman unshare chown -R 0:0 "$AGENT_STATE"
chmod -R u+rwX "$AGENT_STATE"
mkdir -p "$AGENT_STATE/cv_ca"
install -m 0444 "$SERVER_STATE/cv_ca/cacert.crt" "$AGENT_STATE/cv_ca/cacert.crt"

# The image drops from root to keylime:tss. Map its state to that user without
# making the generated key material world-writable on the host.
podman unshare chown -R 999:999 "$AGENT_STATE"

podman run --detach --name "$AGENT_CONTAINER" --network host \
    --volume "$AGENT_STATE:/var/lib/keylime" \
    --tmpfs /var/lib/keylime/secure:rw,size=1m,mode=0700 \
    --env "TCTI=swtpm:host=127.0.0.1,port=$VTPM_PORT" \
    --env KEYLIME_AGENT_IP=127.0.0.1 \
    --env KEYLIME_AGENT_CONTACT_IP=127.0.0.1 \
    --env KEYLIME_AGENT_REGISTRAR_IP=127.0.0.1 \
    --env KEYLIME_AGENT_REGISTRAR_PORT=8890 \
    --env KEYLIME_AGENT_ENABLE_AGENT_MTLS=true \
    --env RUST_LOG=keylime_agent=info \
    "$KEYLIME_AGENT_IMAGE" >/dev/null

for _ in {1..60}; do
    if podman logs "$AGENT_CONTAINER" 2>&1 | grep -q 'Listening on https://127.0.0.1:9002'; then
        started=1
        printf 'Keylime transport ready: verifier=8881 registrar=8890/8891 agent=9002\n'
        exit 0
    fi
    if ! container_exists "$AGENT_CONTAINER" || [[ $(podman inspect -f '{{.State.Running}}' "$AGENT_CONTAINER") != true ]]; then
        podman logs "$AGENT_CONTAINER" >&2 || true
        printf 'Keylime agent exited before becoming ready\n' >&2
        exit 1
    fi
    sleep 0.5
done

podman logs "$AGENT_CONTAINER" >&2 || true
printf 'Keylime agent failed to become ready\n' >&2
exit 1
