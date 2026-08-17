# Protocol Overview

The normative work-in-progress profile is maintained in
[`spec/profile.md`](../spec/profile.md) and
[`spec/profile.cddl`](../spec/profile.cddl). This document describes how the
profile relates to the existing lab.

## Distinct Freshness Checks

TPM nonce binding proves that evidence was generated for a verifier challenge.
`make vtpm-smoke` exercises correct- and changed-nonce verification.

One-time challenge consumption prevents reuse of an otherwise valid result.
The frozen HMAC prototype exercises this property in one process; the reference
implementation still needs durable atomic consumption across restarts and
concurrent requests.

Proof of possession demonstrates that the result presenter controls the
ephemeral key bound into the challenge and result. It is a separate operation
and is not implemented by the HMAC prototype.

## Cryptographic Boundary

The target result is a CWT/EAT payload protected by `COSE_Sign1`. The algorithm
identifier must be protected, verifier keys must be selected from an explicit
trust store, and issuer, audience, key ID, expiry, policy, and revocation must
be validated before domain claims are accepted.

The existing Python envelope is a mechanics fixture. It must never be accepted
by the future COSE validator or exposed as a compatibility mode.

## Authorization Boundary

The verifier appraises evidence and signs a result. The game server is the
relying party and independently applies admission policy. Attestation failure,
transport failure, and policy rejection are not by themselves evidence of
cheating and must not automatically produce punitive enforcement.
