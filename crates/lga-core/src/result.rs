use core::fmt;

use crate::{AssuranceLevel, Challenge, ChallengeError};

/// One relying-party-approved evidence policy and workload manifest.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AcceptedPolicy {
    /// Stable policy identifier.
    pub id: String,
    /// Exact accepted policy version.
    pub version: u64,
    /// SHA-256 digest of the policy document.
    pub digest: [u8; 32],
    /// SHA-256 digest of the accepted workload manifest.
    pub workload_manifest_digest: [u8; 32],
    /// Oldest revocation epoch still accepted.
    pub minimum_revocation_epoch: u64,
}

/// Result-acceptance policy owned by the relying party.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RelyingPartyPolicy {
    /// Exact trusted verifier issuer identifier.
    pub trusted_issuer: String,
    /// Lowest assurance level accepted for the operation.
    pub minimum_assurance: AssuranceLevel,
    /// Accepted evidence and workload policies.
    pub accepted_policies: Vec<AcceptedPolicy>,
}

/// Authenticated claims decoded from a supported EAT/COSE result.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AttestationResult {
    /// Verifier issuer identifier.
    pub issuer: String,
    /// Relying-party audience.
    pub audience: String,
    /// Unique CWT identifier, 16 to 32 bytes.
    pub token_id: Vec<u8>,
    /// Result issuance time as Unix seconds.
    pub issued_at: u64,
    /// Exclusive result expiration time as Unix seconds.
    pub expires_at: u64,
    /// EAT nonce copied from freshly appraised evidence.
    pub nonce: Vec<u8>,
    /// Bound challenge identifier.
    pub challenge_id: Vec<u8>,
    /// Bound application identifier.
    pub application_id: String,
    /// Bound game-session identifier.
    pub session_id: Vec<u8>,
    /// SHA-256 thumbprint from the CWT confirmation claim.
    pub client_key_thumbprint: [u8; 32],
    /// Applied evidence policy identifier.
    pub policy_id: String,
    /// Applied policy version.
    pub policy_version: u64,
    /// SHA-256 digest of the applied policy document.
    pub policy_digest: [u8; 32],
    /// SHA-256 digest of the accepted workload manifest.
    pub workload_manifest_digest: [u8; 32],
    /// Assurance level justified by the appraised evidence.
    pub assurance: AssuranceLevel,
    /// Revocation epoch used for appraisal.
    pub revocation_epoch: u64,
}

/// Session context accepted after result validation.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct VerifiedSession {
    /// Unique consumed challenge identifier.
    pub challenge_id: Vec<u8>,
    /// Application authorized by the result.
    pub application_id: String,
    /// Session authorized by the result.
    pub session_id: Vec<u8>,
    /// Ephemeral key that must complete proof of possession.
    pub client_key_thumbprint: [u8; 32],
    /// Accepted evidence policy.
    pub policy_id: String,
    /// Accepted evidence assurance.
    pub assurance: AssuranceLevel,
    /// Time at which domain validation succeeded.
    pub verified_at: u64,
}

/// Validate authenticated result claims against challenge and relying-party policy.
///
/// Signature, protected-header, profile, CBOR, and duplicate-label validation
/// must succeed before this function is called. Challenge consumption and
/// proof of possession occur after this function and must be atomic with the
/// relying party's admission transition.
pub fn validate_result(
    result: &AttestationResult,
    challenge: &Challenge,
    policy: &RelyingPartyPolicy,
    now: u64,
) -> Result<VerifiedSession, ValidationError> {
    challenge
        .validate()
        .map_err(ValidationError::ChallengeInvalid)?;
    validate_result_shape(result)?;

    if now < challenge.issued_at {
        return Err(ValidationError::ChallengeNotYetValid);
    }
    if now >= challenge.expires_at {
        return Err(ValidationError::ChallengeExpired);
    }
    if result.issuer != policy.trusted_issuer {
        return Err(ValidationError::IssuerMismatch);
    }
    if result.audience != challenge.audience {
        return Err(ValidationError::AudienceMismatch);
    }
    if result.challenge_id != challenge.id {
        return Err(ValidationError::ChallengeIdMismatch);
    }
    if result.nonce != challenge.nonce {
        return Err(ValidationError::NonceMismatch);
    }
    if result.application_id != challenge.application_id {
        return Err(ValidationError::ApplicationIdMismatch);
    }
    if result.session_id != challenge.session_id {
        return Err(ValidationError::SessionIdMismatch);
    }
    if result.client_key_thumbprint != challenge.client_key_thumbprint {
        return Err(ValidationError::ClientKeyMismatch);
    }
    if result.issued_at < challenge.issued_at || result.expires_at > challenge.expires_at {
        return Err(ValidationError::ResultWindowOutsideChallenge);
    }
    if now < result.issued_at {
        return Err(ValidationError::ResultNotYetValid);
    }
    if now >= result.expires_at {
        return Err(ValidationError::ResultExpired);
    }
    if result.assurance < policy.minimum_assurance {
        return Err(ValidationError::AssuranceInsufficient);
    }
    if !challenge
        .accepted_policy_ids
        .iter()
        .any(|id| id == &result.policy_id)
    {
        return Err(ValidationError::PolicyNotOffered);
    }

    let accepted = policy
        .accepted_policies
        .iter()
        .find(|accepted| accepted.id == result.policy_id)
        .ok_or(ValidationError::PolicyRejected)?;
    if accepted.version != result.policy_version || accepted.digest != result.policy_digest {
        return Err(ValidationError::PolicyRejected);
    }
    if accepted.workload_manifest_digest != result.workload_manifest_digest {
        return Err(ValidationError::WorkloadRejected);
    }
    if result.revocation_epoch < accepted.minimum_revocation_epoch {
        return Err(ValidationError::RevocationStateStale);
    }

    Ok(VerifiedSession {
        challenge_id: challenge.id.clone(),
        application_id: challenge.application_id.clone(),
        session_id: challenge.session_id.clone(),
        client_key_thumbprint: challenge.client_key_thumbprint,
        policy_id: result.policy_id.clone(),
        assurance: result.assurance,
        verified_at: now,
    })
}

fn validate_result_shape(result: &AttestationResult) -> Result<(), ValidationError> {
    if result.issuer.is_empty()
        || result.audience.is_empty()
        || result.application_id.is_empty()
        || result.policy_id.is_empty()
    {
        return Err(ValidationError::ResultMalformed);
    }
    if !(16..=32).contains(&result.token_id.len())
        || !(16..=32).contains(&result.challenge_id.len())
        || result.nonce.len() != 32
        || !(16..=64).contains(&result.session_id.len())
        || result.issued_at >= result.expires_at
    {
        return Err(ValidationError::ResultMalformed);
    }
    Ok(())
}

/// A stable relying-party result-validation failure.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ValidationError {
    /// The stored challenge itself violates the active profile.
    ChallengeInvalid(ChallengeError),
    /// The challenge is not valid yet.
    ChallengeNotYetValid,
    /// The challenge has reached its exclusive expiration.
    ChallengeExpired,
    /// A required result field has invalid shape or length.
    ResultMalformed,
    /// The result issuer is not trusted by policy.
    IssuerMismatch,
    /// The result audience differs from the challenge audience.
    AudienceMismatch,
    /// The result refers to another challenge.
    ChallengeIdMismatch,
    /// The result nonce differs from the challenge nonce.
    NonceMismatch,
    /// The result refers to another application.
    ApplicationIdMismatch,
    /// The result refers to another session.
    SessionIdMismatch,
    /// The confirmation key differs from the challenged client key.
    ClientKeyMismatch,
    /// The result validity window is not contained by the challenge.
    ResultWindowOutsideChallenge,
    /// The result issuance time is in the future.
    ResultNotYetValid,
    /// The result has reached its exclusive expiration.
    ResultExpired,
    /// The result assurance is below relying-party policy.
    AssuranceInsufficient,
    /// The verifier used a policy not offered by the challenge.
    PolicyNotOffered,
    /// The policy identity, version, or digest is not accepted.
    PolicyRejected,
    /// The workload manifest is not accepted.
    WorkloadRejected,
    /// The result predates the required revocation state.
    RevocationStateStale,
}

impl fmt::Display for ValidationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let message = match self {
            Self::ChallengeInvalid(_) => "stored challenge is invalid",
            Self::ChallengeNotYetValid => "challenge is not valid yet",
            Self::ChallengeExpired => "challenge has expired",
            Self::ResultMalformed => "attestation result is malformed",
            Self::IssuerMismatch => "verifier issuer is not trusted",
            Self::AudienceMismatch => "result audience does not match challenge",
            Self::ChallengeIdMismatch => "result challenge ID does not match",
            Self::NonceMismatch => "result nonce does not match challenge",
            Self::ApplicationIdMismatch => "result application does not match challenge",
            Self::SessionIdMismatch => "result session does not match challenge",
            Self::ClientKeyMismatch => "result client key does not match challenge",
            Self::ResultWindowOutsideChallenge => "result window exceeds challenge window",
            Self::ResultNotYetValid => "result is not valid yet",
            Self::ResultExpired => "result has expired",
            Self::AssuranceInsufficient => "result assurance is insufficient",
            Self::PolicyNotOffered => "result policy was not offered by the challenge",
            Self::PolicyRejected => "result policy is not accepted",
            Self::WorkloadRejected => "result workload manifest is not accepted",
            Self::RevocationStateStale => "result revocation state is stale",
        };
        formatter.write_str(message)
    }
}

impl std::error::Error for ValidationError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::ChallengeInvalid(error) => Some(error),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        AcceptedPolicy, AttestationResult, RelyingPartyPolicy, ValidationError, validate_result,
    };
    use crate::{AssuranceLevel, Challenge};

    const NOW: u64 = 1_800_000_010;

    fn fixture() -> (Challenge, AttestationResult, RelyingPartyPolicy) {
        let challenge = Challenge {
            id: vec![1; 16],
            nonce: vec![2; 32],
            application_id: "org.example.synthetic-game".into(),
            session_id: vec![3; 16],
            audience: "https://game.example.invalid".into(),
            client_key_thumbprint: [4; 32],
            issued_at: 1_800_000_000,
            expires_at: 1_800_000_060,
            accepted_policy_ids: vec!["lga.example.virtual.1".into()],
        };
        let result = AttestationResult {
            issuer: "https://verifier.example.invalid".into(),
            audience: challenge.audience.clone(),
            token_id: vec![5; 16],
            issued_at: 1_800_000_001,
            expires_at: 1_800_000_050,
            nonce: challenge.nonce.clone(),
            challenge_id: challenge.id.clone(),
            application_id: challenge.application_id.clone(),
            session_id: challenge.session_id.clone(),
            client_key_thumbprint: challenge.client_key_thumbprint,
            policy_id: "lga.example.virtual.1".into(),
            policy_version: 1,
            policy_digest: [6; 32],
            workload_manifest_digest: [7; 32],
            assurance: AssuranceLevel::Virtual,
            revocation_epoch: 2,
        };
        let policy = RelyingPartyPolicy {
            trusted_issuer: result.issuer.clone(),
            minimum_assurance: AssuranceLevel::Virtual,
            accepted_policies: vec![AcceptedPolicy {
                id: result.policy_id.clone(),
                version: result.policy_version,
                digest: result.policy_digest,
                workload_manifest_digest: result.workload_manifest_digest,
                minimum_revocation_epoch: 2,
            }],
        };
        (challenge, result, policy)
    }

    #[test]
    fn accepts_exactly_bound_authenticated_claims() {
        let (challenge, result, policy) = fixture();
        let session = validate_result(&result, &challenge, &policy, NOW).unwrap();
        assert_eq!(session.challenge_id, challenge.id);
        assert_eq!(session.assurance, AssuranceLevel::Virtual);
    }

    #[test]
    fn rejects_wrong_nonce() {
        let (challenge, mut result, policy) = fixture();
        result.nonce = vec![8; 32];
        assert_eq!(
            validate_result(&result, &challenge, &policy, NOW),
            Err(ValidationError::NonceMismatch)
        );
    }

    #[test]
    fn rejects_wrong_client_key() {
        let (challenge, mut result, policy) = fixture();
        result.client_key_thumbprint = [9; 32];
        assert_eq!(
            validate_result(&result, &challenge, &policy, NOW),
            Err(ValidationError::ClientKeyMismatch)
        );
    }

    #[test]
    fn expiration_is_exclusive() {
        let (challenge, result, policy) = fixture();
        assert_eq!(
            validate_result(&result, &challenge, &policy, result.expires_at),
            Err(ValidationError::ResultExpired)
        );
    }

    #[test]
    fn rejects_insufficient_assurance() {
        let (challenge, mut result, mut policy) = fixture();
        result.assurance = AssuranceLevel::Development;
        policy.minimum_assurance = AssuranceLevel::Hardware;
        assert_eq!(
            validate_result(&result, &challenge, &policy, NOW),
            Err(ValidationError::AssuranceInsufficient)
        );
    }

    #[test]
    fn rejects_changed_workload_manifest() {
        let (challenge, mut result, policy) = fixture();
        result.workload_manifest_digest = [10; 32];
        assert_eq!(
            validate_result(&result, &challenge, &policy, NOW),
            Err(ValidationError::WorkloadRejected)
        );
    }

    #[test]
    fn rejects_stale_revocation_state() {
        let (challenge, mut result, policy) = fixture();
        result.revocation_epoch = 1;
        assert_eq!(
            validate_result(&result, &challenge, &policy, NOW),
            Err(ValidationError::RevocationStateStale)
        );
    }

    #[test]
    fn rejects_result_window_outside_challenge() {
        let (challenge, mut result, policy) = fixture();
        result.expires_at = challenge.expires_at + 1;
        assert_eq!(
            validate_result(&result, &challenge, &policy, NOW),
            Err(ValidationError::ResultWindowOutsideChallenge)
        );
    }
}
