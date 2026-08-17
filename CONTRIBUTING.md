# Contributing

Linux Game Attestation welcomes contributions to the public specification,
reference implementation, synthetic fixtures, platform lab, and conformance
suite.

## Ground Rules

- Use only project-owned, openly licensed, or explicitly authorized targets.
- Do not submit proprietary binaries, vendor SDKs, credentials, protected
  telemetry, or instructions for bypassing an anti-cheat system.
- Keep publisher-specific adapters and policies outside this repository.
- State exactly which assurance level a test exercises.
- Add a negative test for every security property introduced.
- Do not weaken a fail-closed policy merely to make an integration test pass.

## Development Workflow

Before proposing a change, run:

```bash
make test
make static-check
```

Changes to CDDL, claims, protocol flow, cryptographic algorithms, key lifecycle,
privacy behavior, or assurance semantics require corresponding specification
text and vectors. Changes to lab integrations require a report describing what
the test proves and what it does not prove.

## Commit And Review Scope

Keep changes reviewable. Separate behavior-preserving moves from protocol or
security changes. Never commit generated state, private keys, VM images, or
publisher material.

Substantial protocol changes should begin with an architecture decision or a
focused proposal under `spec/` before implementation.
