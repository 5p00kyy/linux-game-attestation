#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

for command in curl podman; do
    command -v "$command" >/dev/null || {
        printf 'required command not found: %s\n' "$command" >&2
        exit 1
    }
done

started=0
cleanup_failed_start() {
    if [[ $started -eq 0 ]]; then
        remove_container "$REGISTRAR_CONTAINER"
        remove_container "$VERIFIER_CONTAINER"
    fi
}
trap cleanup_failed_start EXIT

mkdir -p "$SERVER_STATE" "$REPORT_DIR"
remove_container "$REGISTRAR_CONTAINER"
remove_container "$VERIFIER_CONTAINER"

podman run --detach --name "$VERIFIER_CONTAINER" --network host \
    --volume "$SERVER_STATE:/var/lib/keylime" \
    --env KEYLIME_VERIFIER_NUM_WORKERS=1 \
    --env KEYLIME_VERIFIER_MAX_WORKERS=1 \
    "$KEYLIME_VERIFIER_IMAGE" >/dev/null

if ! wait_for_url https://127.0.0.1:8881/version https; then
    podman logs "$VERIFIER_CONTAINER" >&2 || true
    printf 'Keylime verifier failed to become ready\n' >&2
    exit 1
fi

podman run --detach --name "$REGISTRAR_CONTAINER" --network host \
    --volume "$SERVER_STATE:/var/lib/keylime" \
    --env KEYLIME_REGISTRAR_MAX_WORKERS=1 \
    "$KEYLIME_REGISTRAR_IMAGE" >/dev/null

if ! wait_for_url http://127.0.0.1:8890/version; then
    podman logs "$REGISTRAR_CONTAINER" >&2 || true
    printf 'Keylime registrar failed to become ready\n' >&2
    exit 1
fi

started=1
printf 'Keylime verifier and registrar ready on 8881 and 8890/8891\n'
