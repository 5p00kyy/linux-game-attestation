#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

for command in openssl sha256sum; do
    command -v "$command" >/dev/null || {
        printf 'required command not found: %s\n' "$command" >&2
        exit 1
    }
done

if [[ -e "$KEY_DIR" && ${LGA_REGENERATE_MKOSI_KEYS:-0} != 1 ]]; then
    printf 'lab keys already exist at %s; set LGA_REGENERATE_MKOSI_KEYS=1 to replace them\n' "$KEY_DIR" >&2
    exit 1
fi

if [[ ${LGA_REGENERATE_MKOSI_KEYS:-0} == 1 ]]; then
    rm -rf -- "$KEY_DIR"
fi

umask 077
mkdir -p "$KEY_DIR"
chmod 0700 "$KEY_DIR"

generate_certificate() {
    local name=$1
    local subject=$2
    openssl req -new -x509 -newkey rsa:3072 -nodes -sha256 -days 365 \
        -subj "/CN=$subject/" \
        -keyout "$KEY_DIR/$name.key" \
        -out "$KEY_DIR/$name.crt" >/dev/null 2>&1
    chmod 0600 "$KEY_DIR/$name.key"
    chmod 0644 "$KEY_DIR/$name.crt"
}

generate_certificate PK 'LGA Lab Platform Key'
generate_certificate KEK 'LGA Lab Key Exchange Key'
generate_certificate db 'LGA Lab Secure Boot Signing Key'
generate_certificate verity 'LGA Lab Verity Signing Key'

owner_guid=$(< /proc/sys/kernel/random/uuid)
{
    printf 'OWNER_GUID=%q\n' "$owner_guid"
    for name in PK KEK db verity; do
        fingerprint=$(openssl x509 -in "$KEY_DIR/$name.crt" -noout -fingerprint -sha256 | cut -d= -f2)
        subject=$(openssl x509 -in "$KEY_DIR/$name.crt" -noout -subject | cut -d= -f2-)
        serial=$(openssl x509 -in "$KEY_DIR/$name.crt" -noout -serial | cut -d= -f2)
        printf '%s_FINGERPRINT=%q\n' "${name}_SHA256" "$fingerprint"
        printf '%s_SUBJECT=%q\n' "${name}_SUBJECT" "$subject"
        printf '%s_SERIAL=%q\n' "${name}_SERIAL" "$serial"
    done
} >"$KEY_METADATA"
chmod 0600 "$KEY_METADATA"

printf 'generated lab-only PK, KEK, db, and verity keys under %s\n' "$KEY_DIR"
