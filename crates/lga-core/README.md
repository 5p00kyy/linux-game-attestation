# lga-core

`lga-core` defines protocol-neutral challenge, policy, assurance, and
attestation-result validation.

It intentionally does not decode CBOR, verify COSE signatures, call Keylime,
or manage durable replay state. Callers may pass claims to this crate only
after authenticating and structurally validating a supported EAT profile.
