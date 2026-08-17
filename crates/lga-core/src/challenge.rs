use core::fmt;

/// Relying-party context that an attestation result must match exactly.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Challenge {
    /// Unique opaque challenge identifier, 16 to 32 bytes.
    pub id: Vec<u8>,
    /// EAT nonce, exactly 32 bytes in profile 0.1.
    pub nonce: Vec<u8>,
    /// Application identifier selected by the relying party.
    pub application_id: String,
    /// Opaque game-session identifier, 16 to 64 bytes.
    pub session_id: Vec<u8>,
    /// Exact result audience.
    pub audience: String,
    /// SHA-256 thumbprint of the ephemeral client key.
    pub client_key_thumbprint: [u8; 32],
    /// Challenge issuance time as Unix seconds.
    pub issued_at: u64,
    /// Exclusive challenge expiration time as Unix seconds.
    pub expires_at: u64,
    /// Policy identifiers offered for this challenge.
    pub accepted_policy_ids: Vec<String>,
}

impl Challenge {
    /// Validate profile-level challenge constraints.
    pub fn validate(&self) -> Result<(), ChallengeError> {
        if !(16..=32).contains(&self.id.len()) {
            return Err(ChallengeError::InvalidIdLength);
        }
        if self.nonce.len() != 32 {
            return Err(ChallengeError::InvalidNonceLength);
        }
        if self.application_id.is_empty() {
            return Err(ChallengeError::ApplicationIdEmpty);
        }
        if !(16..=64).contains(&self.session_id.len()) {
            return Err(ChallengeError::InvalidSessionIdLength);
        }
        if self.audience.is_empty() {
            return Err(ChallengeError::AudienceEmpty);
        }
        if self.issued_at >= self.expires_at {
            return Err(ChallengeError::InvalidTimeWindow);
        }
        if self.accepted_policy_ids.is_empty()
            || self.accepted_policy_ids.iter().any(String::is_empty)
        {
            return Err(ChallengeError::AcceptedPoliciesEmpty);
        }
        Ok(())
    }
}

/// A malformed relying-party challenge.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ChallengeError {
    /// Challenge ID is outside the profile's 16 to 32 byte range.
    InvalidIdLength,
    /// Profile 0.1 requires a 32 byte EAT nonce.
    InvalidNonceLength,
    /// Application ID is empty.
    ApplicationIdEmpty,
    /// Session ID is outside the profile's 16 to 64 byte range.
    InvalidSessionIdLength,
    /// Audience is empty.
    AudienceEmpty,
    /// Issuance is not earlier than expiration.
    InvalidTimeWindow,
    /// No non-empty policy identifiers were offered.
    AcceptedPoliciesEmpty,
}

impl fmt::Display for ChallengeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::InvalidIdLength => "challenge ID must be 16 to 32 bytes",
            Self::InvalidNonceLength => "challenge nonce must be 32 bytes",
            Self::ApplicationIdEmpty => "application ID must be non-empty",
            Self::InvalidSessionIdLength => "session ID must be 16 to 64 bytes",
            Self::AudienceEmpty => "audience must be non-empty",
            Self::InvalidTimeWindow => "challenge time window is invalid",
            Self::AcceptedPoliciesEmpty => "accepted policies must be non-empty",
        })
    }
}

impl std::error::Error for ChallengeError {}

#[cfg(test)]
mod tests {
    use super::{Challenge, ChallengeError};

    fn valid_challenge() -> Challenge {
        Challenge {
            id: vec![1; 16],
            nonce: vec![2; 32],
            application_id: "org.example.game".into(),
            session_id: vec![3; 16],
            audience: "https://game.example.invalid".into(),
            client_key_thumbprint: [4; 32],
            issued_at: 100,
            expires_at: 160,
            accepted_policy_ids: vec!["policy.example.1".into()],
        }
    }

    #[test]
    fn accepts_a_well_formed_challenge() {
        assert_eq!(valid_challenge().validate(), Ok(()));
    }

    #[test]
    fn rejects_an_invalid_time_window() {
        let mut challenge = valid_challenge();
        challenge.expires_at = challenge.issued_at;
        assert_eq!(challenge.validate(), Err(ChallengeError::InvalidTimeWindow));
    }
}
