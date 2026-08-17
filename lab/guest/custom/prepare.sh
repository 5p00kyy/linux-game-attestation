#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

"$ROOT/lab/image/verify.sh"
"$ROOT/lab/image/enroll-ovmf.sh"
"$ROOT/lab/guest/prepare.sh"
