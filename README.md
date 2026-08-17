# Linux Game Attestation

Linux Game Attestation is an experimental, vendor-neutral project defining a
publisher-consumable integrity profile for Linux and Proton game sessions.

The target design combines TPM-backed platform evidence, measured boot, Linux
runtime integrity, Proton workload measurement, and cryptographic session
binding. A project-owned synthetic Windows client and dedicated server will
provide an independently testable reference integration without using
protected retail games or proprietary anti-cheat components.

**Status:** pre-specification research prototype. The repository currently
contains working TPM, Keylime, measured-VM, and protocol-mechanics experiments.
It does not yet implement the complete EAT profile, IMA runtime policy,
synthetic Proton workload, or hardware-backed end-to-end demonstration.

## Project Scope

This project is:

- A draft RATS/EAT profile for game-session attestation.
- A Rust reference implementation of verifier and relying-party boundaries.
- A controlled Linux platform and Keylime integration lab.
- A synthetic Proton client/server and adversarial conformance suite.
- A basis for review by Linux, Valve, anti-cheat, and publisher engineers.

This project is not:

- A complete cheat-detection product.
- A compatibility shim for Windows kernel anti-cheat drivers.
- A generator or emulator of vendor trust signals.
- A claim that arbitrary user-controlled Linux systems are trustworthy.
- Authorization to test protected retail games or production services.

## Architecture

The first profile uses the RFC 9334 Passport model:

```text
game server       Linux/Proton client       verifier
(relying party)       (attester)          (Keylime adapter)
      |                    |                      |
      |---- challenge ---->|                      |
      |                    |------ evidence ---->|
      |                    |<-- signed result ---|
      |<--- result + proof of possession --------|
      |                    |                      |
      `---- admission decision                   |
```

The verifier appraises evidence. The game server independently decides whether
the signed result satisfies its admission policy. Passing attestation is never
itself a ban or enforcement decision.

See [the architecture](docs/architecture.md), [threat model](docs/threat-model.md),
and [draft profile](spec/profile.md).

## Assurance Levels

| Level | Meaning |
| --- | --- |
| Development | Mock evidence or software TPM; protocol mechanics only |
| Virtual | Measured QEMU guest with OVMF and a vTPM |
| Hardware | Physical TPM with endorsement and controlled boot policy |
| Qualified | Hardware profile and policy reviewed by an authorized relying party |

An implementation must not present development or virtual evidence as
hardware-rooted. See [assurance levels](docs/assurance-levels.md).

## Current Capabilities

| Capability | Status |
| --- | --- |
| Software TPM quote and changed-nonce rejection | Implemented |
| Keylime transport and identity quote | Implemented |
| Measured Fedora VM | Implemented |
| Custom signed dm-verity image | Implemented in the virtual lab |
| Validated measured-boot policy | Blocked by Fedora UKI PCR 9 replay gap |
| IMA runtime appraisal | Not implemented |
| RATS/EAT result profile | Drafting |
| Asymmetric verifier result | Not implemented |
| Synthetic Proton client and server | Not implemented |
| Hardware TPM demonstration | Planned |
| Publisher integration | Requires written authorization |

Detailed evidence and known blockers are maintained in
[project status](docs/status.md), not inferred from a generic `PASS` label.

## Repository Layout

- `spec/`: draft profile, CDDL schemas, and interoperability vectors.
- `crates/`: Rust reference implementation.
- `apps/`: synthetic client, server, and reference services as they are added.
- `adapters/`: vendor-neutral evidence adapters; publisher adapters stay private.
- `conformance/`: protocol, platform, Proton, and adversarial scenarios.
- `lab/`: software TPM, Keylime, VM, and custom-image experiments.
- `prototypes/`: frozen experiments that are not production APIs.
- `docs/`: architecture, threat model, privacy, authorization, and roadmap.

## Development Checks

The fast checks do not require a VM or privileged host access:

```bash
make test
make static-check
```

Disposable integration stages are explicit:

```bash
make vtpm-smoke
make keylime-smoke
make guest-smoke
make keylime-guest-smoke
make keylime-mb-probe
```

The custom-image stage requires mkosi, QEMU/KVM, OVMF, Secure Boot tooling,
and Fedora repository keys:

```bash
make mkosi-keys
make mkosi-build
make mkosi-verify
make ovmf-enroll
make guest-custom-smoke
```

Generated keys, TPM state, images, logs, and reports default to
`${XDG_STATE_HOME:-~/.local/state}/linux-game-attestation`. They must never be
committed or used as production trust material.

## Authorized Testing Boundary

No proprietary game executable, anti-cheat driver, player account, vendor
runtime, or production enforcement endpoint is used by this project. All
public adversarial testing uses project-owned synthetic workloads and servers.

Publisher-specific SDKs, credentials, policies, and adapters must remain
outside this repository. Any non-synthetic integration requires written
authorization, a staging environment, test accounts, diagnostic access, and a
documented enforcement-remediation path.

Read [the authorized-testing policy](docs/authorized-testing.md) before adding
targets or integrations.

## Security And Privacy

Raw EK certificates, stable hardware identifiers, complete event logs, private
keys, and protected telemetry must not be sent to relying parties or published.
The verifier should disclose only the minimum short-lived result needed for an
admission decision.

See [SECURITY.md](SECURITY.md), [privacy requirements](docs/privacy.md), and
[CONTRIBUTING.md](CONTRIBUTING.md).
