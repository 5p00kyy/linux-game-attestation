# Security Policy

## Project Maturity

This repository is an experimental research project, not a production
attestation or anti-cheat service. Do not use it to protect real accounts,
secrets, game sessions, or enforcement decisions.

Development and virtual assurance levels do not provide a hardware root of
trust. A software TPM proves protocol mechanics only.

## Reporting A Vulnerability

Do not open a public issue containing an exploitable vulnerability, private
key, credential, TPM endorsement material, publisher SDK, proprietary binary,
or protected telemetry. Submit sensitive reports through
[GitHub private vulnerability reporting](https://github.com/5p00kyy/linux-game-attestation/security/advisories/new).

A useful report includes affected revisions, impact, reproduction steps using
project-owned fixtures, and suggested remediation. Do not test the issue
against protected games, third-party accounts, or production services.

## Sensitive State

The following data is generated locally and must remain outside version
control:

- Secure Boot, verity, verifier, SSH, and TLS private keys.
- TPM state, contexts, endorsement material, and quote artifacts.
- VM images, firmware variable stores, databases, logs, and reports.
- Publisher credentials, private policies, SDKs, and staging data.

Generated state defaults to
`${XDG_STATE_HOME:-~/.local/state}/linux-game-attestation` and should be mode
`0700` where possible. Repository ignore rules are not a substitute for access
control, backup policy, secret scanning, or secure deletion.

## Release Security

No release may claim hardware-backed or qualified assurance unless the matching
hardware test report, reference values, verifier policy, and negative tests are
published or independently reviewed. Release signing, SBOM generation,
provenance, key rotation, and incident response remain release blockers.
