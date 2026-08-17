# Roadmap

## Milestone 0: Stabilize The Research Lab

- Isolate generated state outside the repository.
- Restore the custom immutable image build and smoke test.
- Keep the Fedora UKI PCR 9 incompatibility fail-closed and reproducible.
- Distinguish transport, virtual, hardware, and qualified results.
- Add static validation for Rust, Python, shell, pins, and schemas.

## Milestone 1: Draft The Profile

- Map all RFC 9334 roles and choose the Passport topology.
- Define the CWT/EAT claims set and `COSE_Sign1` requirements.
- Define freshness, audience, policy, assurance, revocation, and privacy rules.
- Publish valid and invalid semantic vectors.
- Complete algorithm and key-lifecycle review before implementing crypto.

## Milestone 2: Rust Reference Protocol

- Implement protocol-neutral domain validation in `lga-core`.
- Add vetted CBOR/COSE parsing and asymmetric verification.
- Add durable atomic challenge consumption and replay cleanup.
- Implement ephemeral client-key proof of possession.
- Add cross-process, malformed-input, rotation, and revocation tests.

## Milestone 3: Synthetic End-To-End Workload

- Build a project-owned Windows client for stock Proton.
- Build a dedicated relying-party server and independent verifier service.
- Build the Linux broker and deterministic mock evidence adapter.
- Complete challenge, result, proof-of-possession, and admission flow.

## Milestone 4: Measured Runtime

- Connect the Keylime adapter to normalized evidence assessments.
- Require a non-empty measured-boot policy.
- Add IMA measurement/appraisal and reference-value manifests.
- Measure broker, Proton, Wine, client, DLL, assets, prefix policy, and graphics
  layers.
- Add modified-file, injected-library, debug, stale-policy, and replay tests.

## Milestone 5: Hardware Demonstration

- Install an isolated profile on dedicated test storage.
- Validate TPM endorsement and hardware-rooted evidence.
- Preserve firmware keys, TPM ownership, and primary-system storage.
- Repeat every positive and negative synthetic scenario.

## Milestone 6: Public Review And Authorized Pilot

- Publish specification, vectors, code, SBOM, provenance, and limitations.
- Seek Keylime, Linux security, Valve, and anti-cheat design review.
- Keep publisher adapters and credentials in separate private repositories.
- Test a protected game only with written authorization and staging safeguards.
