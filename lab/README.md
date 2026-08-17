# Platform Lab

The lab validates individual trust and integration boundaries. It is not the
reference result protocol and does not use protected games.

- `vtpm/` validates TPM command flow and nonce binding with `swtpm`.
- `keylime/` validates pinned Keylime transport, identity, and guest boundaries.
- `guest/` validates disposable Fedora/OVMF measured guests.
- `image/` builds a lab-signed EROFS and dm-verity Fedora image.

Generated state defaults to
`${XDG_STATE_HOME:-~/.local/state}/linux-game-attestation`. Set
`LGA_STATE_HOME` to override the base directory. Private lab keys and software
TPM state must not be reused as production trust material.

See [`docs/lab.md`](../docs/lab.md) for what each stage proves and does not
prove.
