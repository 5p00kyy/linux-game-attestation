# Threat Model

## Security Goal

Give an authorized relying party a fresh, independently signed result stating
that one Linux and Proton game session satisfied a recognized platform,
runtime, and workload policy at a declared assurance level.

Bind that result to one issuer, audience, challenge, nonce, AppID, session,
ephemeral client key, policy version, reference-value set, and short validity
window.

## Trust Boundaries

- The relying-party owner chooses accepted results and admission outcomes.
- The verifier validates evidence and cannot delegate health decisions to the
  untrusted local broker.
- The relying party trusts only configured verifier keys and issuers.
- Endorsers establish hardware and software provenance.
- Reference-value providers publish accepted platform and workload manifests.
- The local user controls the machine but cannot create accepted hardware TPM
  quotes or signed verifier results without compromising a trust boundary.

## In-Scope Failures

- Replayed evidence, results, or proofs from another challenge or session.
- Evidence copied across applications, audiences, devices, or client keys.
- Expired, not-yet-valid, revoked, downgraded, or ambiguously encoded results.
- Unrecognized boot, kernel, runtime, Proton, Wine, client, DLL, or policy
  measurements.
- Disabled Secure Boot, changed kernel command line, unsigned modules, or
  unauthorized debugging when the selected policy claims to prevent them.
- Verifier-key rotation, reference-value update, and policy revocation.
- Privacy leakage from unnecessary stable identifiers or raw evidence.

## Out Of Scope For Current Work

- Production trust from a software TPM or privileged VM host.
- Firmware, SMM, physical, DMA, and hardware supply-chain compromise.
- Unknown kernel vulnerabilities or a malicious verifier/backend.
- Detecting every cheat or proving arbitrary Linux installations trustworthy.
- Authoritative game simulation and behavioral cheat detection.
- Emulating Windows kernel drivers or vendor-specific trust responses.
- Bypassing anti-cheat, reverse engineering protected binaries, or testing
  protected games without written authorization.

## Enforcement Safety

An attestation failure can result from incompatibility, outage, stale policy,
hardware failure, or configuration drift. The reference implementation treats
failure as admission denial or reduced trust, not proof of malicious behavior.
Punitive enforcement remains outside this project and requires independent
publisher policy and evidence.

## Privacy

Publisher-facing results should use short-lived, pairwise identifiers. Raw EK
certificates, complete measurement logs, and stable hardware identifiers remain
at the verifier unless disclosure is explicitly required, authorized, and
documented. See [`privacy.md`](privacy.md).
