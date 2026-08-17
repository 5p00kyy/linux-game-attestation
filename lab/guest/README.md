# Fedora measured guest

This stage boots Fedora Cloud 44's official UEFI UKI image under QEMU/KVM,
OVMF, and a dedicated software TPM. `fetch.sh` pins the image SHA-256, verifies
Fedora's signed checksum, and requires the published Fedora 44 signing-key
fingerprint.

Run `make guest-smoke` to create a disposable overlay, provision `tpm2-tools`
through cloud-init, boot the guest, and require:

- UEFI boot.
- A TPM 2.0 resource-manager device.
- A non-empty firmware TPM event log.
- Non-zero SHA-256 PCRs 0, 7, and 11.

Reports are retained under the configured XDG state root; the VM and swtpm are
stopped after the test. This proves a measured virtual boot boundary, not a
trusted hardware identity. Secure Boot state is recorded but is not yet an
acceptance condition because custom key enrollment belongs to the mkosi image
stage.

The Fedora UKI cloud variant is currently labelled beta by Fedora. Its late
`systemd-tpm2-setup.service` also fails under SELinux when writing an NvPCR
anchor to the ESP. The early SRK setup succeeds, and this lab records the late
unit status while requiring the persistent SRK handle needed for attestation.
The custom mkosi image must resolve that policy issue rather than inheriting an
exception.

`make keylime-guest-smoke` builds on this stage by running the pinned Rust
Keylime agent against the guest TPM and event log. The Keylime verifier and
registrar remain outside the VM so the boundary matches a remote-attestation
deployment rather than trusting the guest to judge itself.
