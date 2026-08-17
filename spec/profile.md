# Linux Game Attestation EAT Profile 0.1

Status: early draft, not suitable for production deployment.

## Conventions And References

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD NOT,
RECOMMENDED, NOT RECOMMENDED, MAY, and OPTIONAL are interpreted as described by
BCP 14 when written in uppercase.

This profile builds on:

- RFC 9334, Remote ATtestation procedureS Architecture.
- RFC 8392, CBOR Web Token.
- RFC 8747, CWT Confirmation Methods.
- RFC 9052 and RFC 9053, COSE structures and algorithms.
- RFC 9679, COSE key thumbprints.
- RFC 9711, Entity Attestation Token.

## Scope

This profile conveys a verifier-issued attestation result to a game server. It
does not define TPM evidence encoding, Keylime APIs, anti-cheat detection, or
publisher enforcement.

The profile identifier is:

```text
https://github.com/5p00kyy/linux-game-attestation/profile/0.1
```

Until this draft is published at that location, the identifier is provisional
and MUST NOT be treated as a stable production profile.

## RATS Topology

Version 0.1 uses the RFC 9334 Passport model:

- The Linux client and its evidence-producing components are the Attester.
- The independent appraisal service is the Verifier.
- The game server is the Relying Party.
- Image builders and workload publishers provide reference values.
- Hardware and software manufacturers provide endorsements.

The Verifier returns an attestation result to the client. The client presents
the result to the Relying Party with proof of possession of the bound ephemeral
key.

## Encoding

The result MUST be a CWT containing an EAT claims set. It MUST be protected by
`COSE_Sign1` and transported with the CWT tag 61 followed by the COSE Sign1 tag
18.

The `alg` and `kid` headers MUST be in the protected header map. The unprotected
header map MUST be empty. Detached payloads, multiple signatures, encryption,
and nested tokens are not supported in version 0.1.

The initial mandatory-to-implement algorithm is ES256, COSE algorithm `-7`.
Implementations MUST reject algorithm substitution and MUST NOT infer an
algorithm from the key. This selection remains subject to external review
before the profile is considered stable.

The relying party MUST select verifier keys from an explicit trust store using
the authenticated issuer and protected key ID. A key ID is a lookup hint, not
proof of trust. Unknown, revoked, expired, or issuer-mismatched keys MUST be
rejected.

CBOR maps MUST NOT contain duplicate labels. Decoders MUST reject malformed,
indefinitely large, excessively nested, or unsupported input before policy
evaluation.

## Required Claims

The required CWT and EAT claims are defined in `profile.cddl`.

| Key | Claim | Requirement |
| --- | --- | --- |
| `1` | `iss` | Verifier identifier trusted by the relying party |
| `3` | `aud` | Exact relying-party audience from the challenge |
| `4` | `exp` | Exclusive integer expiration time |
| `6` | `iat` | Integer issuance time |
| `7` | `cti` | Unique 16 to 32 byte result identifier |
| `8` | `cnf` | SHA-256 thumbprint of the ephemeral client key |
| `10` | `eat_nonce` | Exact 32 byte challenge nonce |
| `265` | `eat_profile` | Exact profile identifier |
| `-70000` | LGA private map | Application, session, policy, and assurance claims |

The optional `sub` claim, key `2`, may contain only a pairwise pseudonymous
identifier scoped to the relying party. A raw EK digest, machine serial, MAC
address, global user identifier, or cross-publisher identifier MUST NOT be
used.

## Private Claim Map

Claim key `-70000` is in the CWT private-use range. Its value is a map with this
profile-local namespace:

| Key | Meaning |
| --- | --- |
| `1` | Challenge ID, 16 to 32 bytes |
| `2` | Application identifier |
| `3` | Session identifier, 16 to 64 bytes |
| `4` | Evidence-appraisal policy identifier |
| `5` | Policy version |
| `6` | SHA-256 policy document digest |
| `7` | SHA-256 workload manifest digest |
| `8` | Assurance level from 0 through 3 |
| `9` | Revocation epoch applied by the verifier |

Private-use labels are suitable only while this profile is experimental. A
stable public profile must seek collision-resistant or registered claim
identifiers before interoperable deployment.

## Freshness And Session Binding

The relying party MUST create at least 32 random nonce bytes and a unique
challenge ID. The challenge MUST bind audience, application, session,
client-key thumbprint, accepted policies, issuance time, and expiration.

The verifier MUST ensure that the EAT nonce reached the fresh hardware or
development evidence operation. Copying a nonce into a result without evidence
binding is insufficient.

The result `iat` MUST NOT precede challenge issuance. Result `exp` MUST NOT
exceed challenge expiration. Expiration is exclusive: a result is invalid when
the relying party time is greater than or equal to `exp`.

The result presenter MUST prove possession of the key identified by `cnf` using
a new relying-party nonce. The proof protocol will be specified separately and
must bind the result ID, challenge ID, session, audience, and server nonce.

Challenge consumption MUST be atomic and durable. A valid result may authorize
at most one initial session transition unless an explicitly defined renewal
flow issues a new challenge.

## Policy Evaluation

Before admission, a relying party MUST verify:

1. CBOR and COSE structure and resource limits.
2. Protected algorithm and key ID.
3. Signature, trusted issuer, and key status.
4. Exact profile identifier and supported profile version.
5. Exact audience, nonce, challenge, application, and session binding.
6. Token and challenge time windows.
7. Client-key thumbprint and proof of possession.
8. Accepted policy ID, version, digest, workload manifest, and revocation epoch.
9. Minimum assurance level.
10. Atomic challenge consumption.

Unknown assurance values, unknown required private-map keys, or conflicting
duplicate claims MUST be rejected. Unknown non-critical extension claims MAY be
ignored only after signature verification and profile-required validation.

## Failure Semantics

Malformed, unverifiable, stale, replayed, unsupported, or policy-rejected
results deny admission. The reference implementation MUST NOT classify an
attestation failure as cheating or automatically request punitive enforcement.

Externally visible errors SHOULD be coarse. Detailed evidence-appraisal and
parser diagnostics belong in access-controlled verifier logs.

## Privacy

The result MUST NOT contain raw TPM quotes, EK certificates, complete firmware
or IMA logs, stable cross-publisher identifiers, or local usernames. The
verifier SHOULD minimize claims and retention according to `docs/privacy.md`.

## Open Issues

- Final profile URI and stable claim registration strategy.
- External review of mandatory algorithms and key lifecycle.
- Exact proof-of-possession message and transport binding.
- Reference-value distribution, expiry, rollback, and revocation formats.
- Runtime workload-to-process binding strong enough for hardware assurance.
- Renewal and continuous-session appraisal.
