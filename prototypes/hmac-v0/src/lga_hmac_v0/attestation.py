"""Frozen mock-first session binding for a future attestation result.

The HMAC envelope in this module is deliberately lab-only. A production
implementation consumes a token signed by an independently operated
attestation verifier, using a standardized asymmetric format such as EAT/COSE.
This module is retained as a mechanics fixture. It is not an earlier wire
version and must never be accepted by the reference protocol.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
from dataclasses import asdict, dataclass
from typing import Callable, Mapping


PROTOCOL_VERSION = "lga-lab-v0"


class VerificationError(ValueError):
    """A stable verification failure suitable for tests and API translation."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class Challenge:
    challenge_id: str
    nonce: str
    app_id: str
    session_id: str
    issued_at: int
    expires_at: int


@dataclass(frozen=True)
class VerifiedSession:
    challenge_id: str
    app_id: str
    session_id: str
    policy_digest: str
    verified_at: int


class ChallengeStore:
    """In-memory one-time challenge store for protocol development."""

    def __init__(
        self,
        *,
        id_factory: Callable[[], str] | None = None,
        nonce_factory: Callable[[], str] | None = None,
    ) -> None:
        self._id_factory = id_factory or (lambda: secrets.token_urlsafe(18))
        self._nonce_factory = nonce_factory or (lambda: secrets.token_hex(32))
        self._active: dict[str, Challenge] = {}

    def issue(
        self,
        *,
        app_id: str,
        session_id: str,
        now: int,
        ttl_seconds: int = 60,
    ) -> Challenge:
        if not app_id or not session_id:
            raise ValueError("app_id and session_id must be non-empty")
        if ttl_seconds <= 0:
            raise ValueError("ttl_seconds must be positive")

        challenge = Challenge(
            challenge_id=self._id_factory(),
            nonce=self._nonce_factory(),
            app_id=app_id,
            session_id=session_id,
            issued_at=now,
            expires_at=now + ttl_seconds,
        )
        if challenge.challenge_id in self._active:
            raise RuntimeError("challenge ID collision")
        self._active[challenge.challenge_id] = challenge
        return challenge

    def get(self, challenge_id: str) -> Challenge:
        try:
            return self._active[challenge_id]
        except KeyError as error:
            raise VerificationError(
                "challenge_unknown",
                "challenge is unknown, expired, or already consumed",
            ) from error

    def consume(self, challenge_id: str) -> None:
        del self._active[challenge_id]


class LabTokenSigner:
    """HMAC signer used only to exercise verifier-side binding logic."""

    def __init__(self, secret: bytes) -> None:
        if len(secret) < 32:
            raise ValueError("lab signing secret must be at least 32 bytes")
        self._secret = secret

    @staticmethod
    def _canonical_claims(claims: Mapping[str, object]) -> bytes:
        return json.dumps(
            claims,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        ).encode("ascii")

    def sign(self, claims: Mapping[str, object]) -> dict[str, object]:
        copied_claims = dict(claims)
        signature = hmac.new(
            self._secret,
            self._canonical_claims(copied_claims),
            hashlib.sha256,
        ).digest()
        return {
            "claims": copied_claims,
            "signature": base64.urlsafe_b64encode(signature)
            .rstrip(b"=")
            .decode("ascii"),
        }

    def verify(self, envelope: Mapping[str, object]) -> dict[str, object]:
        claims = envelope.get("claims")
        signature = envelope.get("signature")
        if not isinstance(claims, dict) or not isinstance(signature, str):
            raise VerificationError("envelope_invalid", "invalid evidence envelope")

        try:
            encoded_signature = signature + "=" * (-len(signature) % 4)
            supplied = base64.b64decode(
                encoded_signature,
                altchars=b"-_",
                validate=True,
            )
        except (ValueError, TypeError) as error:
            raise VerificationError("signature_invalid", "malformed signature") from error

        expected = hmac.new(
            self._secret,
            self._canonical_claims(claims),
            hashlib.sha256,
        ).digest()
        if not hmac.compare_digest(supplied, expected):
            raise VerificationError("signature_invalid", "evidence signature did not verify")
        return dict(claims)


def make_lab_claims(
    challenge: Challenge,
    *,
    policy_digest: str,
) -> dict[str, object]:
    """Create claims as if a trusted verifier accepted platform evidence."""

    if not policy_digest:
        raise ValueError("policy_digest must be non-empty")
    return {
        "protocol": PROTOCOL_VERSION,
        **asdict(challenge),
        "policy_digest": policy_digest,
    }


class AttestationVerifier:
    """Verify a signed result and atomically consume its bound challenge."""

    _REQUIRED_STRING_CLAIMS = (
        "protocol",
        "challenge_id",
        "nonce",
        "app_id",
        "session_id",
        "policy_digest",
    )

    def __init__(
        self,
        *,
        challenges: ChallengeStore,
        signer: LabTokenSigner,
        accepted_policy_digests: set[str],
    ) -> None:
        if not accepted_policy_digests:
            raise ValueError("at least one policy digest must be accepted")
        self._challenges = challenges
        self._signer = signer
        self._accepted_policy_digests = frozenset(accepted_policy_digests)

    def verify(self, envelope: Mapping[str, object], *, now: int) -> VerifiedSession:
        claims = self._signer.verify(envelope)
        for name in self._REQUIRED_STRING_CLAIMS:
            if not isinstance(claims.get(name), str) or not claims[name]:
                raise VerificationError("claims_invalid", f"missing or invalid claim: {name}")
        issued_at = claims.get("issued_at")
        expires_at = claims.get("expires_at")
        if type(issued_at) is not int or type(expires_at) is not int:
            raise VerificationError("claims_invalid", "invalid claim timestamps")
        if claims["protocol"] != PROTOCOL_VERSION:
            raise VerificationError("protocol_unsupported", "unsupported protocol version")

        challenge = self._challenges.get(str(claims["challenge_id"]))
        comparisons = (
            ("nonce", "nonce_mismatch"),
            ("app_id", "app_id_mismatch"),
            ("session_id", "session_id_mismatch"),
            ("issued_at", "timestamp_mismatch"),
            ("expires_at", "timestamp_mismatch"),
        )
        for field, code in comparisons:
            if claims[field] != getattr(challenge, field):
                raise VerificationError(code, f"{field} is not bound to the challenge")

        if now < challenge.issued_at:
            raise VerificationError(
                "challenge_not_yet_valid",
                "challenge issue time is in the future",
            )
        if now > challenge.expires_at:
            raise VerificationError("challenge_expired", "challenge has expired")
        policy_digest = str(claims["policy_digest"])
        if policy_digest not in self._accepted_policy_digests:
            raise VerificationError("policy_rejected", "platform policy is not accepted")

        self._challenges.consume(challenge.challenge_id)
        return VerifiedSession(
            challenge_id=challenge.challenge_id,
            app_id=challenge.app_id,
            session_id=challenge.session_id,
            policy_digest=policy_digest,
            verified_at=now,
        )
