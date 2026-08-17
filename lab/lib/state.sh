#!/usr/bin/env bash

if [[ -z ${LGA_STATE_HOME:-} ]]; then
    : "${HOME:?HOME must be set when LGA_STATE_HOME is unset}"
    LGA_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/linux-game-attestation"
fi
LGA_STATE_HOME=$(realpath --canonicalize-missing -- "$LGA_STATE_HOME")
export LGA_STATE_HOME

# Private state is the safe default; individual public reports may relax this.
umask 077

lga_require_state_path() {
    local requested=$1
    local canonical
    canonical=$(realpath --canonicalize-missing -- "$requested")
    case "$canonical" in
        "$LGA_STATE_HOME"/*) ;;
        *)
            printf 'refusing path outside LGA_STATE_HOME: %s\n' "$requested" >&2
            return 1
            ;;
    esac
}

lga_prepare_state_dir() {
    lga_require_state_path "$1"
    mkdir -p "$1"
    chmod 0700 "$1"
}

lga_pid_is_process() {
    local pid=$1
    local expected=$2
    local executable

    [[ $pid =~ ^[1-9][0-9]*$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    executable=$(readlink -f -- "/proc/$pid/exe" 2>/dev/null) || return 1
    [[ ${executable##*/} == "$expected" ]]
}
