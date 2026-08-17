# HMAC Prototype V0

This frozen Python package tests challenge, nonce, application, session,
expiry, policy, signature, and one-time-use mechanics with an in-memory store
and shared HMAC key.

It is not EAT, COSE, hardware attestation, durable replay protection, or a
supported compatibility format. The reference implementation must never parse
or accept this envelope.

Run it from the repository root with:

```bash
make prototype-test
```
