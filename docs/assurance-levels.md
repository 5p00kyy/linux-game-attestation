# Assurance Levels

An assurance level describes the evidence root and appraisal environment. It
does not describe how aggressively a relying party should enforce a failure.

## Development

Development evidence uses deterministic fixtures, mocks, or a software TPM. It
can validate encoding, cryptography, freshness, session binding, and failure
handling. It cannot establish hardware identity or host boot state.

Development results must not contain claims that imply hardware backing.

## Virtual

Virtual evidence comes from a measured guest with OVMF, a dedicated vTPM, and
an independently operated verifier. It can validate measured-boot and runtime
policy composition across a VM boundary.

A privileged host can replace the VM, firmware, vTPM, or evidence. Virtual
assurance therefore cannot be promoted to hardware assurance.

## Hardware

Hardware evidence uses a physical TPM 2.0, validated endorsement policy,
controlled UEFI boot, measured kernel command line, protected runtime
measurement policy, and reviewed reference values.

Hardware assurance does not include firmware, SMM, DMA, physical, hardware
supply-chain, or unknown kernel-exploit resistance unless a profile explicitly
adds and tests those properties.

## Qualified

Qualified evidence satisfies a relying-party-approved hardware profile and
policy. Qualification requires written authorization, reviewed integration,
staging tests, operational key management, revocation, privacy review, and
negative-test evidence.

No public reference implementation can unilaterally declare itself qualified.

## Representation

The draft profile encodes assurance as an integer:

| Value | Level |
| --- | --- |
| `0` | Development |
| `1` | Virtual |
| `2` | Hardware |
| `3` | Qualified |

A relying party must set a minimum accepted level and must reject unknown
values. It must also validate policy identity and measurements; the level alone
is never sufficient for admission.
