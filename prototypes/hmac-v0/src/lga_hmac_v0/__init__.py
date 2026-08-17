"""Frozen HMAC mechanics prototype; not the reference protocol."""

from .attestation import (
    AttestationVerifier,
    Challenge,
    ChallengeStore,
    LabTokenSigner,
    VerificationError,
    VerifiedSession,
    make_lab_claims,
)

__all__ = [
    "AttestationVerifier",
    "Challenge",
    "ChallengeStore",
    "LabTokenSigner",
    "VerificationError",
    "VerifiedSession",
    "make_lab_claims",
]
