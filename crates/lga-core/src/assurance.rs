use core::fmt;

/// The evidence root and appraisal environment represented by a result.
#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
#[repr(u8)]
pub enum AssuranceLevel {
    /// Deterministic fixtures, mocks, or a software TPM.
    Development = 0,
    /// A measured virtual machine with a privileged host outside the trust boundary.
    Virtual = 1,
    /// A physical TPM and controlled measured-boot and runtime policy.
    Hardware = 2,
    /// A hardware profile approved by the relying-party owner.
    Qualified = 3,
}

impl From<AssuranceLevel> for u8 {
    fn from(value: AssuranceLevel) -> Self {
        value as Self
    }
}

impl TryFrom<u8> for AssuranceLevel {
    type Error = UnknownAssuranceLevel;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::Development),
            1 => Ok(Self::Virtual),
            2 => Ok(Self::Hardware),
            3 => Ok(Self::Qualified),
            unknown => Err(UnknownAssuranceLevel(unknown)),
        }
    }
}

/// An assurance value not defined by the active profile.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct UnknownAssuranceLevel(pub u8);

impl fmt::Display for UnknownAssuranceLevel {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "unknown assurance level: {}", self.0)
    }
}

impl std::error::Error for UnknownAssuranceLevel {}

#[cfg(test)]
mod tests {
    use super::{AssuranceLevel, UnknownAssuranceLevel};

    #[test]
    fn assurance_values_match_the_profile() {
        assert_eq!(AssuranceLevel::try_from(0), Ok(AssuranceLevel::Development));
        assert_eq!(AssuranceLevel::try_from(3), Ok(AssuranceLevel::Qualified));
        assert_eq!(AssuranceLevel::try_from(4), Err(UnknownAssuranceLevel(4)));
    }
}
