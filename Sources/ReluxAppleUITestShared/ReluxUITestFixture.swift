public enum ReluxUITestFixtureCategory: String, CaseIterable, Sendable {
  case profile
  case trust
  case capability
  case failure
  case diagnostic
  case onboarding
  case migration
  case privacy
}

public enum ReluxUITestFixture: String, CaseIterable, Sendable {
  case profileEmpty = "profile-empty"
  case profileConfigured = "profile-configured"
  case trustUnknown = "trust-unknown"
  case trustApproved = "trust-approved"
  case trustChanged = "trust-changed"
  case trustRevoked = "trust-revoked"
  case capabilityAvailable = "capability-available"
  case capabilityUnavailable = "capability-unavailable"
  case failureAuthentication = "failure-authentication"
  case failureTransport = "failure-transport"
  case failureRelay = "failure-relay"
  case diagnosticEmpty = "diagnostic-empty"
  case diagnosticPopulated = "diagnostic-populated"
  case onboardingRequired = "onboarding-required"
  case onboardingComplete = "onboarding-complete"
  case migrationRequired = "migration-required"
  case migrationComplete = "migration-complete"
  case privacyRedacted = "privacy-redacted"

  public var category: ReluxUITestFixtureCategory {
    switch self {
    case .profileEmpty, .profileConfigured:
      .profile
    case .trustUnknown, .trustApproved, .trustChanged, .trustRevoked:
      .trust
    case .capabilityAvailable, .capabilityUnavailable:
      .capability
    case .failureAuthentication, .failureTransport, .failureRelay:
      .failure
    case .diagnosticEmpty, .diagnosticPopulated:
      .diagnostic
    case .onboardingRequired, .onboardingComplete:
      .onboarding
    case .migrationRequired, .migrationComplete:
      .migration
    case .privacyRedacted:
      .privacy
    }
  }

  public var displayName: String {
    rawValue.replacingOccurrences(of: "-", with: " ").capitalized
  }
}
