#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

if [[ ${LGA_ALLOW_SOFTWARE_TPM_EK:-} != 1 ]]; then
    printf '%s\n' 'Refusing to disable EK certificate validation.' >&2
    printf '%s\n' 'Set LGA_ALLOW_SOFTWARE_TPM_EK=1 only for this isolated swtpm lab.' >&2
    exit 1
fi

exec podman run --rm --network host \
    --volume "$SERVER_STATE:/var/lib/keylime" \
    --env KEYLIME_TENANT_REQUIRE_EK_CERT=false \
    "$KEYLIME_TENANT_IMAGE" \
    "$@"
