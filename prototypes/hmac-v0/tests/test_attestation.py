import unittest

from lga_hmac_v0 import (
    AttestationVerifier,
    ChallengeStore,
    LabTokenSigner,
    VerificationError,
    make_lab_claims,
)


class AttestationVerifierTests(unittest.TestCase):
    NOW = 1_800_000_000
    POLICY = "sha256:known-good-policy"

    def setUp(self) -> None:
        sequence = iter(("challenge-1", "challenge-2", "challenge-3"))
        nonces = iter(("a" * 64, "b" * 64, "c" * 64))
        self.challenges = ChallengeStore(
            id_factory=lambda: next(sequence),
            nonce_factory=lambda: next(nonces),
        )
        self.signer = LabTokenSigner(b"test-only-secret".ljust(32, b"!"))
        self.verifier = AttestationVerifier(
            challenges=self.challenges,
            signer=self.signer,
            accepted_policy_digests={self.POLICY},
        )

    def issue(self, *, ttl_seconds: int = 60):
        return self.challenges.issue(
            app_id="example.app",
            session_id="session-123",
            now=self.NOW,
            ttl_seconds=ttl_seconds,
        )

    def envelope(self, challenge, **overrides):
        claims = make_lab_claims(challenge, policy_digest=self.POLICY)
        claims.update(overrides)
        return self.signer.sign(claims)

    def assert_error(self, code, envelope, *, now=None):
        with self.assertRaises(VerificationError) as raised:
            self.verifier.verify(envelope, now=self.NOW if now is None else now)
        self.assertEqual(code, raised.exception.code)

    def test_valid_result_is_accepted_once(self):
        challenge = self.issue()
        envelope = self.envelope(challenge)

        result = self.verifier.verify(envelope, now=self.NOW + 1)

        self.assertEqual("example.app", result.app_id)
        self.assertEqual("session-123", result.session_id)
        self.assertEqual(self.POLICY, result.policy_digest)
        self.assert_error("challenge_unknown", envelope, now=self.NOW + 2)

    def test_wrong_nonce_is_rejected_without_consuming_challenge(self):
        challenge = self.issue()
        self.assert_error("nonce_mismatch", self.envelope(challenge, nonce="d" * 64))

        result = self.verifier.verify(self.envelope(challenge), now=self.NOW)
        self.assertEqual(challenge.challenge_id, result.challenge_id)

    def test_wrong_app_id_is_rejected(self):
        challenge = self.issue()
        self.assert_error(
            "app_id_mismatch",
            self.envelope(challenge, app_id="different.app"),
        )

    def test_wrong_session_is_rejected(self):
        challenge = self.issue()
        self.assert_error(
            "session_id_mismatch",
            self.envelope(challenge, session_id="different-session"),
        )

    def test_expired_challenge_is_rejected(self):
        challenge = self.issue(ttl_seconds=5)
        self.assert_error(
            "challenge_expired",
            self.envelope(challenge),
            now=self.NOW + 6,
        )

    def test_challenge_from_the_future_is_rejected(self):
        challenge = self.issue()
        self.assert_error(
            "challenge_not_yet_valid",
            self.envelope(challenge),
            now=self.NOW - 1,
        )

    def test_unaccepted_policy_is_rejected(self):
        challenge = self.issue()
        claims = make_lab_claims(challenge, policy_digest="sha256:unknown-policy")
        self.assert_error("policy_rejected", self.signer.sign(claims))

    def test_tampered_claims_fail_signature_verification(self):
        challenge = self.issue()
        envelope = self.envelope(challenge)
        envelope["claims"]["session_id"] = "tampered-session"
        self.assert_error("signature_invalid", envelope)

    def test_timestamps_must_match_challenge(self):
        challenge = self.issue()
        self.assert_error(
            "timestamp_mismatch",
            self.envelope(challenge, expires_at=challenge.expires_at + 30),
        )

    def test_boolean_timestamps_are_rejected(self):
        challenge = self.issue()
        self.assert_error(
            "claims_invalid",
            self.envelope(challenge, issued_at=True),
        )


if __name__ == "__main__":
    unittest.main()
