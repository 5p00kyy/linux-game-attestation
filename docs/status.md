# Project Status

This document records what has been demonstrated and what remains incomplete.
A test passing at one layer does not imply that higher assurance layers pass.

## Demonstrated

- Reproducible `swtpm` quote generation and signature verification.
- Rejection of a valid quote checked with a different nonce.
- Pinned Keylime verifier, registrar, tenant, and Rust agent transport.
- Keylime mTLS and positive/negative identity quote checks.
- Fedora 44 UEFI UKI guest boot with OVMF, event log, and non-zero PCRs.
- Guest Keylime agent access to its vTPM and firmware event log.
- Fail-closed handling of the known Fedora UKI PCR 9 replay mismatch.
- Lab-only challenge, AppID, session, expiry, policy, HMAC, and replay tests.
- A reproducibly built custom Fedora 44 image with a lab-signed UKI, EROFS
  dm-verity root, and separate writable `/home` and `/var` partitions.
- Custom-image boot under OVMF Secure Boot with a measured UKI, non-zero PCRs
  0, 4, 7, 9, and 11, a firmware event log, and the expected persistent SRK.
- Declarative network and SSH provisioning on the immutable image, with
  generated host keys stored in writable `/var` and no failed systemd units.

## Incomplete Or Blocked

- Keylime measured-boot acceptance is blocked by late Fedora UKI PCR 9
  measurement that Keylime 7.14 cannot replay from the firmware event log.
- Keylime transport smoke tests intentionally use empty TPM policy.
- IMA runtime measurement and appraisal are not configured.
- The Python HMAC prototype is not EAT, COSE, or production cryptography.
- No synthetic Windows client, game server, Linux broker, or end-to-end result
  flow exists yet.
- No hardware TPM evidence has been integrated.
- The custom-image result is virtual-lab evidence and does not establish a
  hardware or qualified assurance level.
