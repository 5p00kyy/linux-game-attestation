# Profile Vectors

`valid-claims.diag` is an unsigned CBOR diagnostic claims example. It exercises
the draft schema but is not evidence that COSE signing is implemented.

Signed ES256 vectors will be added with fixed public keys after the Rust COSE
implementation is selected and independently checked. The project will not
publish placeholder signatures that appear valid.

Future negative vectors must include duplicate labels, wrong profile, wrong
audience, malformed nonce, unsupported assurance, expired result, client-key
substitution, stale policy, stale revocation epoch, and algorithm substitution.
