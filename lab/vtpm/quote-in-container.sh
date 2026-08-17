#!/bin/sh
set -eu

: "${TPM2TOOLS_TCTI:?TPM2TOOLS_TCTI must select the isolated swtpm instance}"

cd /work
rm -f ak.ctx ak.name akpub.pem ek.ctx ek.pub nonce.txt quote.msg quote.pcrs quote.sig

tpm2_startup -c
tpm2_createek -c ek.ctx -G rsa -u ek.pub
tpm2_createak \
    -C ek.ctx \
    -c ak.ctx \
    -G rsa \
    -g sha256 \
    -s rsassa \
    -u akpub.pem \
    -f pem \
    -n ak.name
tpm2_flushcontext -t

nonce=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
printf '%s\n' "$nonce" > nonce.txt

tpm2_quote \
    -c ak.ctx \
    -l sha256:0,7 \
    -q "$nonce" \
    -m quote.msg \
    -s quote.sig \
    -o quote.pcrs \
    -g sha256

tpm2_checkquote \
    -u akpub.pem \
    -m quote.msg \
    -s quote.sig \
    -f quote.pcrs \
    -g sha256 \
    -q "$nonce"

wrong_nonce=$(printf '%064d' 0)
if tpm2_checkquote \
    -u akpub.pem \
    -m quote.msg \
    -s quote.sig \
    -f quote.pcrs \
    -g sha256 \
    -q "$wrong_nonce"; then
    printf 'quote unexpectedly verified with the wrong nonce\n' >&2
    exit 1
fi

tpm2_flushcontext -t
printf 'quote verified; changed-nonce verification rejected as expected\n'
