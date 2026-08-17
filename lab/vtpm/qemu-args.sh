#!/usr/bin/env bash
set -euo pipefail

CTRL_PORT=${LGA_VTPM_CTRL_PORT:-2322}
CTRL_SOCKET=${LGA_VTPM_CTRL_SOCKET:-}

if [[ -n "$CTRL_SOCKET" ]]; then
    CHRDEV="-chardev socket,id=chrtpm,path=$CTRL_SOCKET"
else
    CHRDEV="-chardev socket,id=chrtpm,host=127.0.0.1,port=$CTRL_PORT"
fi

cat <<EOF
$CHRDEV
-tpmdev emulator,id=tpm0,chardev=chrtpm
-device tpm-tis,tpmdev=tpm0
EOF
