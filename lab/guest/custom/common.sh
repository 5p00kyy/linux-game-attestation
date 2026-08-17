#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lab/image/common.sh"

export LGA_GUEST_STATE_DIR=${LGA_CUSTOM_GUEST_STATE_DIR:-"$LGA_STATE_HOME/fedora-mkosi-guest"}
export LGA_GUEST_BASE_IMAGE="$IMAGE_FILE"
export LGA_GUEST_BASE_IMAGE_FORMAT=raw
export LGA_GUEST_SKIP_FETCH=1
export LGA_GUEST_CLOUD_INIT_PROFILE=immutable
export LGA_OVMF_VARS="$OVMF_ENROLLED"
export LGA_GUEST_SSH_PORT=${LGA_CUSTOM_GUEST_SSH_PORT:-2223}
export LGA_GUEST_AGENT_PORT=${LGA_CUSTOM_GUEST_AGENT_PORT:-9003}
export LGA_GUEST_VTPM_PORT=${LGA_CUSTOM_GUEST_VTPM_PORT:-2334}

# shellcheck disable=SC1091
source "$ROOT/lab/guest/common.sh"
