#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

for command in curl gpg gpgv sha256sum; do
    command -v "$command" >/dev/null || {
        printf 'required command not found: %s\n' "$command" >&2
        exit 1
    }
done

mkdir -p "$DOWNLOAD_DIR"
CHECKSUM_FILE="$DOWNLOAD_DIR/$FEDORA_CHECKSUM_NAME"
VERIFIED_CHECKSUM="$DOWNLOAD_DIR/$FEDORA_CHECKSUM_NAME.verified"
KEYRING="$DOWNLOAD_DIR/fedora.gpg"

if [[ ! -f "$BASE_IMAGE" ]] || ! printf '%s  %s\n' "$FEDORA_IMAGE_SHA256" "$BASE_IMAGE" | sha256sum --check --status; then
    curl --fail --location --continue-at - --output "$BASE_IMAGE" "$FEDORA_IMAGE_URL"
fi

curl --fail --location --output "$CHECKSUM_FILE" "$FEDORA_CHECKSUM_URL"
curl --fail --location --output "$KEYRING" "$FEDORA_KEYRING_URL"

if ! gpg --batch --with-colons --show-keys "$KEYRING" 2>/dev/null \
    | grep -q "^fpr:::::::::$FEDORA_SIGNING_FINGERPRINT:"; then
    printf 'Fedora keyring does not contain expected Fedora %s key %s\n' \
        "$FEDORA_RELEASE" "$FEDORA_SIGNING_FINGERPRINT" >&2
    exit 1
fi

gpgv --keyring "$KEYRING" --output "$VERIFIED_CHECKSUM" "$CHECKSUM_FILE"
(
    cd "$DOWNLOAD_DIR"
    sha256sum --check --ignore-missing "$(basename -- "$VERIFIED_CHECKSUM")"
)
printf '%s  %s\n' "$FEDORA_IMAGE_SHA256" "$BASE_IMAGE" | sha256sum --check
