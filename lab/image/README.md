# Custom Fedora Image

This stage builds a directly booted, lab-signed Fedora UKI with an EROFS
dm-verity root and separate writable `/home` and `/var` partitions.

Image content is declarative. `mkosi.extra` provides sysusers, tmpfiles,
networkd, CIDATA SSH provisioning, host-key generation, and sudo configuration
before the immutable root is sealed. SSH host keys are generated into writable
`/var` on first boot rather than embedded in the image.

Lab PK, KEK, db, and verity keys are local development material. OVMF enrollment
contains no Microsoft keys and applies only to the copied VM variable store.
These keys must not be enrolled into development-host firmware or reused for a
hardware or qualified profile.

`build.sh` writes a checksum manifest only after both the raw image and split
UKI exist. `verify.sh` requires that manifest, checks raw format and GPT layout,
verifies the UKI certificate, and requires a dm-verity root hash in the UKI.
