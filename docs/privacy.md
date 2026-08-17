# Privacy Requirements

## Principle

The relying party should learn only whether a fresh session satisfies an
accepted policy and the minimum context needed to validate that result. Raw
hardware identity and measurement evidence remain at the verifier.

## Data Classification

| Data | Default handling |
| --- | --- |
| EK certificate and manufacturer identity | Verifier only |
| TPM quote and firmware event log | Verifier only |
| Complete IMA log | Verifier only |
| Stable machine identifiers | Do not issue to relying parties |
| Pairwise pseudonymous identifier | Optional, scoped to one relying party |
| AppID, session, nonce, policy, assurance | Short-lived result |
| Workload and policy digests | Result or reference-value service |
| Private keys and credentials | Local secret storage only |

## Identifier Rules

If a relying party requires continuity, the verifier should derive a pairwise
identifier scoped to that relying party and purpose. It must not expose a raw
EK digest, serial number, MAC address, global UEID, or identifier reusable by
unrelated publishers.

Development and conformance vectors use deterministic fictional identifiers.

## Retention

Challenges and replay records should be retained only for their validity and
abuse-investigation windows. Raw evidence retention must be documented,
access-controlled, and minimized. The verifier should support deletion of
expired evidence without breaking key-revocation or audit records.

## User Visibility

A production integration must disclose the verifier operator, categories of
evidence collected, recipients, retention period, purposes, and mechanisms for
support or deletion requests. Qualification requires an explicit privacy
review.
