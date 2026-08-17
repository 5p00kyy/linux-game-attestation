#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck disable=SC1091
source "$ROOT/lab/keylime/versions.env"

verify_tag() {
    local repository=$1
    local tag=$2
    local expected=$3
    local actual

    actual=$(git ls-remote "$repository" "refs/tags/$tag" | cut -f1)
    if [[ "$actual" != "$expected" ]]; then
        printf '%s %s resolved to %s, expected %s\n' "$repository" "$tag" "$actual" "$expected" >&2
        return 1
    fi
    printf 'verified %s %s at %s\n' "$repository" "$tag" "$expected"
}

verify_tag https://github.com/keylime/keylime.git "$KEYLIME_VERSION" "$KEYLIME_COMMIT"
verify_tag https://github.com/keylime/rust-keylime.git "$RUST_KEYLIME_VERSION" "$RUST_KEYLIME_COMMIT"
