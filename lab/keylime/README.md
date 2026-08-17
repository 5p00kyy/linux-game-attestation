# Keylime integration stage

The transport lab connects these digest-pinned components:

- Keylime verifier and registrar `v7.14.3`.
- rust-keylime agent `v0.2.10`.
- Keylime pull-model API `v2.6`.
- An isolated swtpm instance on loopback. A disposable Fedora-family QEMU guest
  is the next boundary.

Run `make keylime-smoke` for the complete transport test. It verifies registrar
enrollment, initial tenant quote validation, periodic verifier status, a valid
on-demand identity quote, and rejection of that quote with a different nonce.
Run `make verify-pins` to confirm that upstream tags still resolve to the
commits recorded in `versions.env`.

Run `make keylime-guest-smoke` to move the Rust agent and TPM behind the
Fedora/OVMF VM boundary while keeping verifier and registrar on the host. The
test forwards only SSH and the agent API to loopback, provisions the verifier
CA over SSH, checks that the dropped-privilege agent identity can read the
firmware event log, and repeats periodic plus on-demand nonce verification.

The first Keylime enrollment should use an empty TPM policy (`{}`) to validate
transport and quote flow. PCR 16 must not be listed because Keylime reserves it
for data binding. Measured-boot and IMA policies are added only after the basic
flow passes.

Software TPM endorsement material is lab-only. `tenant.sh` refuses to disable
EK certificate validation unless `LGA_ALLOW_SOFTWARE_TPM_EK=1` is explicitly
set. `smoke.sh` sets it only for its isolated state. That exception must never
carry into hardware or publisher testing.

The container-only agent has no measured-boot or IMA logs. The VM agent has a
measured-boot log but is still enrolled with an empty TPM policy and no
measured-boot reference state. Fedora records an IMA boot aggregate, but no
runtime measurement policy is configured. The next policy stage must make
event-log validation, rather than mere readability, an acceptance condition.

`make keylime-mb-probe` exercises that next policy without pretending it works:
the generated reference state causes Keylime 7.14 to reject the Fedora UKI
boot with `measured_boot.invalid_pcr_9`. The firmware log replay and live TPM
PCR 9 differ because the EFI path performs a later initrd measurement. This is
a fail-closed compatibility finding, not an accepted exception.
