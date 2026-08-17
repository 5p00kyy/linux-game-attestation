//! Protocol-neutral domain validation for Linux Game Attestation.
//!
//! This crate receives claims only after an outer codec has authenticated a
//! supported EAT/COSE result. It does not parse bytes or verify signatures.

#![forbid(unsafe_code)]
#![warn(missing_docs)]

mod assurance;
mod challenge;
mod result;

pub use assurance::{AssuranceLevel, UnknownAssuranceLevel};
pub use challenge::{Challenge, ChallengeError};
pub use result::{
    AcceptedPolicy, AttestationResult, RelyingPartyPolicy, ValidationError, VerifiedSession,
    validate_result,
};
