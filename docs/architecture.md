# Architecture

## Objective

Linux Game Attestation provides a vendor-neutral way for a game server to make
an admission decision from fresh, independently appraised evidence about a
Linux platform and one Proton game session.

The project follows RFC 9334 terminology and initially uses its Passport model.
EAT defines the verifier's signed result; it does not replace the underlying
TPM, measured-boot, IMA, or Keylime evidence protocols.

## RATS Roles

| RATS role | Project component | Responsibility |
| --- | --- | --- |
| Attester | Linux broker, Keylime agent, TPM | Produce fresh platform and workload evidence |
| Verifier | Reference verifier and Keylime adapter | Appraise evidence and issue an attestation result |
| Relying Party | Synthetic or publisher game server | Apply admission policy to a verified result |
| Endorser | Hardware and software manufacturers | Supply endorsement statements and trust anchors |
| Reference Value Provider | Image builder and workload publisher | Publish accepted measurements and manifests |
| Verifier Owner | Verifier operator | Set evidence-appraisal policy |
| Relying Party Owner | Game publisher or server operator | Set result-acceptance and enforcement policy |

The local broker transports and correlates evidence. It is not trusted to
declare the platform healthy.

## Passport Flow

1. The relying party creates a one-time challenge containing an EAT nonce,
   application identifier, session identifier, audience, expiry, accepted
   policy set, and client-key thumbprint.
2. The client proves possession of the ephemeral key and asks the verifier to
   appraise evidence for the challenge.
3. The verifier validates TPM freshness, endorsement policy, measured boot,
   runtime measurements, workload identity, policy version, and revocation.
4. The verifier returns a short-lived COSE-signed EAT result.
5. The client presents the result and a fresh proof of possession to the
   relying party.
6. The relying party verifies the signature and claims, atomically consumes the
   challenge, and applies its own admission policy.

The challenge nonce must reach the TPM quote. A separate server nonce must be
used for proof of possession so that presenting the result also demonstrates
control of the bound client key.

## Evidence Boundaries

Platform evidence includes the hardware endorsement, TPM quote, selected PCRs,
firmware event log, boot policy, Secure Boot state, kernel command line, and
runtime measurement log.

Workload evidence includes the accepted broker, Proton, Wine, Windows client,
DLL, asset, prefix-policy, and graphics-layer manifests. File measurements are
useful only when the kernel policy protects their collection and appraises
modification attempts.

Raw evidence remains at the verifier. The relying party receives a minimized
attestation result that identifies the policy and reference-value set that
passed.

## Trust Limitations

Attestation establishes selected claims under a stated policy. It does not
prove that cheating is impossible, eliminate kernel vulnerabilities, or
replace authoritative server simulation and behavioral detection.

A privileged attacker who compromises trusted firmware or the running kernel
can invalidate assumptions below the broker. Each assurance level therefore
states the root of trust and excluded attacks explicitly.

## Component Boundaries

- `lga-core` defines protocol-neutral domain types and relying-party checks.
- The EAT codec will authenticate and decode bytes before domain validation.
- The verifier appraises normalized evidence and issues signed results.
- The Keylime adapter translates Keylime-specific responses into normalized
  assessments; no Keylime HTTP or database type crosses into `lga-core`.
- The Linux broker identifies a workload and requests evidence but cannot mark
  its own evidence as accepted.
- Synthetic applications exercise the complete flow without a protected game.
- Publisher-specific adapters, policies, SDKs, and credentials are external.
