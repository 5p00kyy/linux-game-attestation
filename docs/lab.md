# Lab Design

## Stage 1: software TPM quote

`lab/vtpm/smoke.sh` creates fresh state under the configured XDG state root, starts
`swtpm` on loopback ports 2321 and 2322, and runs pinned Debian `tpm2-tools`
inside rootless Podman. The test creates an EK and AK, quotes PCRs 0 and 7, and
checks the quote with both the correct and an incorrect nonce.

This stage validates TPM command flow and nonce binding only. PCR values from a
software TPM do not describe the host's boot state.

## Stage 2: Keylime transport

`lab/keylime/smoke.sh` runs digest-pinned Keylime verifier, registrar, tenant,
and Rust agent containers against an isolated swtpm instance. It uses pull-mode
API v2.6, mTLS for agent communication, and an empty TPM policy to isolate
identity and transport behavior. The test requires an explicit lab-only EK
certificate exception, waits for periodic attestation to pass, and verifies
both correct- and changed-nonce identity results.

The next step is moving the unchanged Rust agent and TPM into a disposable
QEMU guest. `lab/keylime/guest-smoke.sh` now performs that enrollment while
verifier and registrar services remain outside the guest. The agent runs as
`keylime:tss`, reads the guest TPM and event log, and passes periodic plus
changed-nonce verification through loopback QEMU forwarding.

## Stage 2b: measured guest boundary

`lab/guest/smoke.sh` verifies Fedora's signed checksum for the pinned Fedora 44
UEFI UKI cloud image, boots a disposable overlay with OVMF and its own swtpm,
and captures PCRs 0, 7, and 11 plus the firmware event-log digest. This creates
the VM boundary before the Keylime agent is moved into it. The test records
Secure Boot state but does not accept or reject it until the project owns the
image keys and enrollment policy.

Fedora currently labels this UKI cloud artifact beta. Its late
`systemd-tpm2-setup` unit cannot write an NvPCR anchor to the ESP under the
shipped SELinux policy, although early SRK creation succeeds. The smoke test
records that unit status and requires the persistent SRK handle instead of
disabling SELinux or weakening the image.

The passing guest Keylime enrollment still uses an empty TPM policy and no
measured-boot reference state. It isolates TPM identity, transport, freshness,
and VM-boundary behavior from measured-boot parser compatibility.

The measured-boot probe now proves fail-closed behavior but also identifies a
compatibility blocker. `tpm2_eventlog` replays PCR 9 from the firmware log, then
Fedora's direct UKI/EFI path extends the initrd into PCR 9 later. The live quote
therefore cannot match Keylime 7.14's replay and is rejected as
`measured_boot.invalid_pcr_9`, even when the policy was generated from that
boot's own event log.

## Stage 3: custom measured image

`lab/image/build.sh` creates a custom Fedora 44 disk with a lab-signed UKI,
EROFS dm-verity root, and separate writable `/home` and `/var` partitions.
`lab/guest/custom/smoke.sh` boots it with lab-enrolled OVMF Secure Boot keys and
requires a measured UKI, non-zero PCRs 0, 4, 7, 9, and 11, a firmware event
log, the expected persistent SRK, declaratively provisioned SSH access, and no
failed systemd units.

This is Virtual assurance evidence only. The next image milestone is IMA
measurement and appraisal with negative tests that modify a measured
executable and prove verifier rejection.

## Stage 4: hardware TPM

Move the unchanged protocol to an isolated hardware test system with a physical
TPM. Replace all software-TPM EK exceptions with a real endorsement trust
policy. Do not clear a TPM, replace firmware Secure Boot keys, or modify a
primary operating-system installation as part of a test.
