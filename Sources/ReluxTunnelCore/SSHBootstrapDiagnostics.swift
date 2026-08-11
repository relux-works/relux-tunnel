import Darwin
import Foundation

/// The sole public error domain for profile-driven SSH bootstrap failures.
public enum SSHBootstrapErrorDomain: String, Codable, Sendable {
  case sshProfileBootstrap
}

/// Stable bootstrap stages. Values are diagnostic wire tokens and contain no instance data.
public enum SSHBootstrapStage: String, Codable, CaseIterable, Sendable {
  case profileLoad
  case physicalPathResolution
  case endpointConnect
  case algorithmNegotiation
  case hostVerification
  case credentialAccess
  case publicKeyAuthentication
  case cancellation
  case sessionClose
}

/// Stable public codes for the macOS profile-driven bootstrap boundary.
///
/// Raw engine, Network.framework, socket, Security.framework, and parser descriptions never
/// cross this catalog. Integer values exposed through `NSError` are assigned by `providerCode`.
public enum SSHBootstrapErrorCode: String, Codable, CaseIterable, Sendable {
  case profileOversize
  case profileCorrupt
  case profileVersionUnsupported
  case profileInvalidField
  case profileGenerationMismatch
  case profileContainsProhibitedField
  case profilePublicationReconciliationRequired

  case pathUnavailable
  case endpointConnectFailed
  case negotiationFailed

  case hostTrustRequired
  case hostKeyChanged
  case hostKeyAlgorithmUnsupported
  case hostIdentityRevoked
  case hostPolicyRejected
  case trustChallengeExpired
  case trustChallengeMismatch
  case trustHistoryFull

  case credentialNotProvisioned
  case credentialAccessDenied
  case credentialGenerationMismatch
  case credentialMalformed
  case credentialPassphraseRequired
  case credentialPassphraseInvalid
  case credentialKeyUnsupported
  case credentialMutationConflict
  case credentialReferenceCollision
  case credentialFormatRegistryUnavailable
  case credentialReconciliationProfileSetUnavailable
  case credentialReconciliationLimitExceeded
  case credentialReconciliationFailed

  case authenticationRejected
  case operationCancelled
  case userStopped
  case operationTimedOut
  case transportInterrupted
  case sessionCloseFailed
  case internalInvariant

  /// Stable integer used when the error crosses an `NSError` provider boundary.
  public var providerCode: Int {
    switch self {
    case .profileOversize: 1_001
    case .profileCorrupt: 1_002
    case .profileVersionUnsupported: 1_003
    case .profileInvalidField: 1_004
    case .profileGenerationMismatch: 1_005
    case .profileContainsProhibitedField: 1_006
    case .profilePublicationReconciliationRequired: 1_007
    case .pathUnavailable: 2_001
    case .endpointConnectFailed: 3_001
    case .negotiationFailed: 4_001
    case .hostTrustRequired: 5_001
    case .hostKeyChanged: 5_002
    case .hostKeyAlgorithmUnsupported: 5_003
    case .hostIdentityRevoked: 5_004
    case .hostPolicyRejected: 5_005
    case .trustChallengeExpired: 5_006
    case .trustChallengeMismatch: 5_007
    case .trustHistoryFull: 5_008
    case .credentialNotProvisioned: 6_001
    case .credentialAccessDenied: 6_002
    case .credentialGenerationMismatch: 6_003
    case .credentialMalformed: 6_004
    case .credentialPassphraseRequired: 6_005
    case .credentialPassphraseInvalid: 6_006
    case .credentialKeyUnsupported: 6_007
    case .credentialMutationConflict: 6_008
    case .credentialReferenceCollision: 6_009
    case .credentialFormatRegistryUnavailable: 6_010
    case .credentialReconciliationProfileSetUnavailable: 6_011
    case .credentialReconciliationLimitExceeded: 6_012
    case .credentialReconciliationFailed: 6_013
    case .authenticationRejected: 7_001
    case .operationCancelled: 8_001
    case .userStopped: 8_002
    case .operationTimedOut: 8_003
    case .transportInterrupted: 8_004
    case .sessionCloseFailed: 9_001
    case .internalInvariant: 9_999
    }
  }
}

/// Finite user-action category. Presentation text belongs to a later UI task.
public enum SSHBootstrapUserActionCategory: String, Codable, CaseIterable, Sendable {
  case none
  case retryLater
  case reviewProfile
  case checkNetwork
  case approveHost
  case replaceHostTrust
  case reviewHostTrust
  case restoreCredential
  case reviewCredential
  case contactSupport
}

/// Classification recorded for later lifecycle policy. This type does not perform a retry.
public enum SSHBootstrapRetryDisposition: String, Codable, CaseIterable, Sendable {
  case terminal
  case retryableLater
  case cancelled

  public var isRetryable: Bool { self == .retryableLater }
}

/// Numeric endpoint family only; an address and port cannot be represented here.
public enum SSHBootstrapEndpointFamily: String, Codable, CaseIterable, Sendable {
  case ipv4
  case ipv6

  public init(_ family: SSHNetworkAddressFamily) {
    self = family == .ipv4 ? .ipv4 : .ipv6
  }
}

/// Reviewed algorithm context. Unknown or hostile algorithm names collapse to `unsupported`.
public enum SSHBootstrapAlgorithmContext: String, Codable, CaseIterable, Sendable {
  case sshEd25519 = "ssh-ed25519"
  case ecdsaNISTP256 = "ecdsa-sha2-nistp256"
  case ecdsaNISTP384 = "ecdsa-sha2-nistp384"
  case ecdsaNISTP521 = "ecdsa-sha2-nistp521"
  case rsaSHA2512 = "rsa-sha2-512"
  case rsaSHA2256 = "rsa-sha2-256"
  case unsupported

  public init(hostKeyAlgorithm: String) {
    self = Self(rawValue: hostKeyAlgorithm) ?? .unsupported
  }

  public init(_ algorithm: SSHHostKeyAlgorithm) {
    self.init(hostKeyAlgorithm: algorithm.rawValue)
  }
}

/// Bounded, non-identifying context allowed in provider diagnostics.
public struct SSHBootstrapDiagnosticContext: Codable, Equatable, Sendable {
  public let endpointFamily: SSHBootstrapEndpointFamily?
  public let algorithm: SSHBootstrapAlgorithmContext?

  public init(
    endpointFamily: SSHBootstrapEndpointFamily? = nil,
    algorithm: SSHBootstrapAlgorithmContext? = nil
  ) {
    self.endpointFamily = endpointFamily
    self.algorithm = algorithm
  }

  public static let none = SSHBootstrapDiagnosticContext()
}

/// Privacy-safe snapshot projection. Its schema admits no underlying error or free-form string.
public struct SSHBootstrapDiagnostic: Codable, Equatable, Sendable {
  public let domain: SSHBootstrapErrorDomain
  public let code: SSHBootstrapErrorCode
  public let stage: SSHBootstrapStage
  public let configurationGeneration: UInt64
  public let userAction: SSHBootstrapUserActionCategory
  public let retryDisposition: SSHBootstrapRetryDisposition
  public let context: SSHBootstrapDiagnosticContext

  public init(
    code: SSHBootstrapErrorCode,
    stage: SSHBootstrapStage,
    configurationGeneration: UInt64,
    userAction: SSHBootstrapUserActionCategory,
    retryDisposition: SSHBootstrapRetryDisposition,
    context: SSHBootstrapDiagnosticContext = .none
  ) {
    domain = .sshProfileBootstrap
    self.code = code
    self.stage = stage
    self.configurationGeneration = configurationGeneration
    self.userAction = userAction
    self.retryDisposition = retryDisposition
    self.context = context
  }
}

/// Public provider error. The `NSError` bridge includes only stable finite fields.
public struct SSHBootstrapProviderError: Error, Equatable, Sendable, CustomNSError,
  CustomStringConvertible, CustomDebugStringConvertible
{
  public static let errorDomain = SSHBootstrapErrorDomain.sshProfileBootstrap.rawValue

  public let diagnostic: SSHBootstrapDiagnostic

  public init(diagnostic: SSHBootstrapDiagnostic) {
    self.diagnostic = diagnostic
  }

  public var errorCode: Int { diagnostic.code.providerCode }

  public var errorUserInfo: [String: Any] {
    var result: [String: Any] = [
      "stage": diagnostic.stage.rawValue,
      "code": diagnostic.code.rawValue,
      "configurationGeneration": diagnostic.configurationGeneration,
      "userAction": diagnostic.userAction.rawValue,
      "retryDisposition": diagnostic.retryDisposition.rawValue,
    ]
    if let endpointFamily = diagnostic.context.endpointFamily {
      result["endpointFamily"] = endpointFamily.rawValue
    }
    if let algorithm = diagnostic.context.algorithm {
      result["algorithm"] = algorithm.rawValue
    }
    return result
  }

  public var description: String {
    "\(Self.errorDomain).\(diagnostic.code.rawValue)"
  }

  public var debugDescription: String { description }
}

/// Typed, privacy-safe platform transport causes retained behind the public projection.
public enum SSHBootstrapTransportCause: Hashable, Sendable {
  case unavailable
  case timedOut
  case connectionRefused
  case connectionReset
  case connectionAborted
  case temporaryResourceExhaustion
  case cancelled
  case unexpected
}

public enum SSHBootstrapHostCause: Equatable, Sendable {
  case trustRequired
  case changed
  case algorithmUnsupported
  case revoked
  case policyRejected
}

public enum SSHBootstrapCredentialCause: Equatable, Sendable {
  case notProvisioned
  case accessDenied
  case generationMismatch
  case malformed
  case passphraseRequired
  case passphraseInvalid
  case keyUnsupported
  case mutationConflict
  case referenceCollision
  case formatRegistryUnavailable
  case reconciliationProfileSetUnavailable
  case reconciliationLimitExceeded
  case reconciliationFailed
}

public enum SSHBootstrapAuthenticationCause: Equatable, Sendable {
  case rejected
  case methodUnavailable
  case keyAlgorithmUnavailable
  case signatureFailed
}

public enum SSHBootstrapCancellationCause: Equatable, Sendable {
  case taskCancelled
  case userStopped
}

public enum SSHBootstrapSessionCloseCause: Equatable, Sendable {
  case timedOut
  case transportFailure
  case invariantViolation
}

/// Internal mapping evidence is deliberately typed and contains no source description.
public enum SSHBootstrapInternalCause: Equatable, Sendable {
  case profile(SSHProfileSnapshotLoaderError)
  case physicalPath(SSHBootstrapTransportCause)
  case endpointConnect(SSHBootstrapTransportCause)
  case negotiation(SSHBootstrapTransportCause)
  case host(SSHBootstrapHostCause)
  case credential(SSHBootstrapCredentialCause)
  case authentication(SSHBootstrapAuthenticationCause)
  case cancellation(SSHBootstrapCancellationCause)
  case operationTimedOut(SSHBootstrapStage)
  case transportInterrupted(SSHBootstrapStage, SSHBootstrapTransportCause)
  case sessionClose(SSHBootstrapSessionCloseCause)
  case invariantViolation(SSHBootstrapStage)
}

/// Testable mapping result. Provider consumers should expose `providerError`, not `cause`.
struct SSHBootstrapMappedFailure: Equatable, Sendable {
  let cause: SSHBootstrapInternalCause
  let providerError: SSHBootstrapProviderError
}

/// Stable bootstrap mapping. It classifies only; it never schedules a retry.
public enum SSHBootstrapErrorMapper {
  public static func profile(
    _ error: SSHProfileSnapshotLoaderError,
    configurationGeneration: UInt64 = 0
  ) -> SSHBootstrapProviderError {
    map(.profile(error), configurationGeneration: configurationGeneration).providerError
  }

  public static func transport(
    _ error: SSHTransportError,
    configurationGeneration: UInt64,
    context: SSHBootstrapDiagnosticContext = .none
  ) -> SSHBootstrapProviderError {
    map(transportCause(error), configurationGeneration: configurationGeneration, context: context)
      .providerError
  }

  /// Maps an untrusted platform error without retaining its domain, userInfo, or description.
  public static func transport(
    _ error: any Error,
    stage: SSHBootstrapStage,
    configurationGeneration: UInt64,
    context: SSHBootstrapDiagnosticContext = .none
  ) -> SSHBootstrapProviderError {
    let normalized: SSHBootstrapTransportCause
    if error is CancellationError {
      normalized = .cancelled
    } else {
      let nsError = error as NSError
      if nsError.domain == NSPOSIXErrorDomain {
        normalized = posixCause(Int32(clamping: nsError.code))
      } else if nsError.domain == NSURLErrorDomain {
        normalized = urlCause(nsError.code)
      } else {
        normalized = .unexpected
      }
    }
    return transport(
      normalized,
      stage: stage,
      configurationGeneration: configurationGeneration,
      context: context
    )
  }

  public static func transport(
    posixCode: Int32,
    stage: SSHBootstrapStage,
    configurationGeneration: UInt64,
    context: SSHBootstrapDiagnosticContext = .none
  ) -> SSHBootstrapProviderError {
    transport(
      posixCause(posixCode),
      stage: stage,
      configurationGeneration: configurationGeneration,
      context: context
    )
  }

  public static func transport(
    _ cause: SSHBootstrapTransportCause,
    stage: SSHBootstrapStage,
    configurationGeneration: UInt64,
    context: SSHBootstrapDiagnosticContext = .none
  ) -> SSHBootstrapProviderError {
    let internalCause: SSHBootstrapInternalCause
    switch stage {
    case .physicalPathResolution:
      internalCause = .physicalPath(cause)
    case .endpointConnect:
      internalCause = .endpointConnect(cause)
    case .algorithmNegotiation:
      internalCause = .negotiation(cause)
    case .cancellation:
      internalCause = .cancellation(.taskCancelled)
    default:
      internalCause = .invariantViolation(stage)
    }
    return map(
      internalCause,
      configurationGeneration: configurationGeneration,
      context: context
    ).providerError
  }

  public static func host(
    _ cause: SSHBootstrapHostCause,
    configurationGeneration: UInt64,
    context: SSHBootstrapDiagnosticContext = .none
  ) -> SSHBootstrapProviderError {
    map(.host(cause), configurationGeneration: configurationGeneration, context: context)
      .providerError
  }

  public static func credential(
    _ cause: SSHBootstrapCredentialCause,
    configurationGeneration: UInt64
  ) -> SSHBootstrapProviderError {
    map(.credential(cause), configurationGeneration: configurationGeneration).providerError
  }

  public static func authentication(
    _ cause: SSHBootstrapAuthenticationCause,
    configurationGeneration: UInt64,
    context: SSHBootstrapDiagnosticContext = .none
  ) -> SSHBootstrapProviderError {
    map(
      .authentication(cause),
      configurationGeneration: configurationGeneration,
      context: context
    ).providerError
  }

  public static func cancellation(
    _ cause: SSHBootstrapCancellationCause,
    configurationGeneration: UInt64
  ) -> SSHBootstrapProviderError {
    map(.cancellation(cause), configurationGeneration: configurationGeneration).providerError
  }

  public static func sessionClose(
    _ cause: SSHBootstrapSessionCloseCause,
    configurationGeneration: UInt64
  ) -> SSHBootstrapProviderError {
    map(.sessionClose(cause), configurationGeneration: configurationGeneration).providerError
  }

  static func map(
    _ cause: SSHBootstrapInternalCause,
    configurationGeneration: UInt64,
    context: SSHBootstrapDiagnosticContext = .none
  ) -> SSHBootstrapMappedFailure {
    let values = projection(for: cause)
    return SSHBootstrapMappedFailure(
      cause: cause,
      providerError: SSHBootstrapProviderError(
        diagnostic: SSHBootstrapDiagnostic(
          code: values.code,
          stage: values.stage,
          configurationGeneration: configurationGeneration,
          userAction: values.action,
          retryDisposition: values.retry,
          context: context
        )
      )
    )
  }

  private static func projection(
    for cause: SSHBootstrapInternalCause
  ) -> (
    code: SSHBootstrapErrorCode,
    stage: SSHBootstrapStage,
    action: SSHBootstrapUserActionCategory,
    retry: SSHBootstrapRetryDisposition
  ) {
    switch cause {
    case .profile(let error):
      let code: SSHBootstrapErrorCode =
        switch error {
        case .profileOversize: .profileOversize
        case .profileCorrupt: .profileCorrupt
        case .profileVersionUnsupported: .profileVersionUnsupported
        case .profileInvalidField: .profileInvalidField
        case .profileGenerationMismatch: .profileGenerationMismatch
        case .profileContainsProhibitedField: .profileContainsProhibitedField
        }
      return (code, .profileLoad, .reviewProfile, .terminal)

    case .physicalPath(let cause):
      return transportProjection(cause, stage: .physicalPathResolution)
    case .endpointConnect(let cause):
      return transportProjection(cause, stage: .endpointConnect)
    case .negotiation(let cause):
      return transportProjection(cause, stage: .algorithmNegotiation)

    case .host(let cause):
      switch cause {
      case .trustRequired:
        return (.hostTrustRequired, .hostVerification, .approveHost, .terminal)
      case .changed:
        return (.hostKeyChanged, .hostVerification, .replaceHostTrust, .terminal)
      case .algorithmUnsupported:
        return (.hostKeyAlgorithmUnsupported, .hostVerification, .reviewProfile, .terminal)
      case .revoked:
        return (.hostIdentityRevoked, .hostVerification, .reviewHostTrust, .terminal)
      case .policyRejected:
        return (.hostPolicyRejected, .hostVerification, .reviewHostTrust, .terminal)
      }

    case .credential(let cause):
      let code: SSHBootstrapErrorCode
      let action: SSHBootstrapUserActionCategory
      switch cause {
      case .notProvisioned:
        (code, action) = (.credentialNotProvisioned, .restoreCredential)
      case .accessDenied:
        (code, action) = (.credentialAccessDenied, .reviewCredential)
      case .generationMismatch:
        (code, action) = (.credentialGenerationMismatch, .restoreCredential)
      case .malformed:
        (code, action) = (.credentialMalformed, .restoreCredential)
      case .passphraseRequired:
        (code, action) = (.credentialPassphraseRequired, .reviewCredential)
      case .passphraseInvalid:
        (code, action) = (.credentialPassphraseInvalid, .reviewCredential)
      case .keyUnsupported:
        (code, action) = (.credentialKeyUnsupported, .reviewCredential)
      case .mutationConflict:
        (code, action) = (.credentialMutationConflict, .reviewCredential)
      case .referenceCollision:
        (code, action) = (.credentialReferenceCollision, .contactSupport)
      case .formatRegistryUnavailable:
        (code, action) = (.credentialFormatRegistryUnavailable, .contactSupport)
      case .reconciliationProfileSetUnavailable:
        (code, action) = (.credentialReconciliationProfileSetUnavailable, .retryLater)
      case .reconciliationLimitExceeded:
        (code, action) = (.credentialReconciliationLimitExceeded, .reviewCredential)
      case .reconciliationFailed:
        (code, action) = (.credentialReconciliationFailed, .reviewCredential)
      }
      return (code, .credentialAccess, action, .terminal)

    case .authentication(let cause):
      let action: SSHBootstrapUserActionCategory =
        cause == .rejected ? .reviewCredential : .reviewProfile
      return (.authenticationRejected, .publicKeyAuthentication, action, .terminal)

    case .cancellation(let cause):
      let code: SSHBootstrapErrorCode = cause == .userStopped ? .userStopped : .operationCancelled
      return (code, .cancellation, .none, .cancelled)

    case .operationTimedOut(let stage):
      return (.operationTimedOut, stage, .retryLater, .retryableLater)

    case .transportInterrupted(let stage, _):
      return (.transportInterrupted, stage, .retryLater, .retryableLater)

    case .sessionClose(let cause):
      switch cause {
      case .timedOut:
        return (.operationTimedOut, .sessionClose, .retryLater, .retryableLater)
      case .transportFailure:
        return (.sessionCloseFailed, .sessionClose, .contactSupport, .terminal)
      case .invariantViolation:
        return (.internalInvariant, .sessionClose, .contactSupport, .terminal)
      }

    case .invariantViolation(let stage):
      return (.internalInvariant, stage, .contactSupport, .terminal)
    }
  }

  private static func transportProjection(
    _ cause: SSHBootstrapTransportCause,
    stage: SSHBootstrapStage
  ) -> (
    code: SSHBootstrapErrorCode,
    stage: SSHBootstrapStage,
    action: SSHBootstrapUserActionCategory,
    retry: SSHBootstrapRetryDisposition
  ) {
    if cause == .cancelled {
      return (.operationCancelled, .cancellation, .none, .cancelled)
    }
    if cause == .timedOut {
      return (.operationTimedOut, stage, .retryLater, .retryableLater)
    }
    switch stage {
    case .physicalPathResolution:
      let retry: SSHBootstrapRetryDisposition =
        cause == .unexpected || cause == .connectionRefused ? .terminal : .retryableLater
      return (
        .pathUnavailable,
        stage,
        retry.isRetryable ? .checkNetwork : .reviewProfile,
        retry
      )
    case .endpointConnect:
      let retryable: Set<SSHBootstrapTransportCause> = [
        .unavailable, .connectionReset, .connectionAborted, .temporaryResourceExhaustion,
      ]
      let retry: SSHBootstrapRetryDisposition =
        retryable.contains(cause) ? .retryableLater : .terminal
      return (
        .endpointConnectFailed,
        stage,
        retry.isRetryable ? .checkNetwork : .reviewProfile,
        retry
      )
    case .algorithmNegotiation:
      let retryable: Set<SSHBootstrapTransportCause> = [
        .unavailable, .connectionReset, .connectionAborted,
      ]
      let retry: SSHBootstrapRetryDisposition =
        retryable.contains(cause) ? .retryableLater : .terminal
      return (
        .negotiationFailed,
        stage,
        retry.isRetryable ? .retryLater : .reviewProfile,
        retry
      )
    default:
      return (.internalInvariant, stage, .contactSupport, .terminal)
    }
  }

  private static func transportCause(_ error: SSHTransportError) -> SSHBootstrapInternalCause {
    if error.code == .cancelled {
      return .cancellation(.taskCancelled)
    }
    if error.code == .timedOut {
      return .operationTimedOut(bootstrapStage(for: error.phase))
    }
    if [.connectionLost, .connectionClosed, .networkUnavailable, .peerReset].contains(error.code),
      ![.resolution, .tcpConnect, .initialKeyExchange, .transportClose].contains(error.phase)
    {
      return .transportInterrupted(
        bootstrapStage(for: error.phase), normalizedTransportCause(error.code))
    }
    switch error.phase {
    case .resolution:
      return .physicalPath(normalizedTransportCause(error.code))
    case .tcpConnect:
      return .endpointConnect(normalizedTransportCause(error.code))
    case .configuration, .initialKeyExchange:
      return .negotiation(normalizedTransportCause(error.code))
    case .hostDecision:
      return .host(hostCause(error.code))
    case .credentialLookup:
      return .credential(credentialCause(error.code))
    case .authentication:
      return .authentication(authenticationCause(error.code))
    case .transportClose:
      let closeCause: SSHBootstrapSessionCloseCause =
        error.code == .timedOut ? .timedOut : .transportFailure
      return .sessionClose(closeCause)
    case .channelOpen, .channelRead, .channelWrite, .channelEOF, .channelClose,
      .execRequest, .execExit, .uploadSource, .rekey, .keepalive, .protocolProcessing:
      return .invariantViolation(
        error.phase == .protocolProcessing ? .algorithmNegotiation : .sessionClose)
    }
  }

  private static func bootstrapStage(for phase: SSHTransportPhase) -> SSHBootstrapStage {
    switch phase {
    case .configuration:
      .profileLoad
    case .resolution:
      .physicalPathResolution
    case .tcpConnect:
      .endpointConnect
    case .initialKeyExchange, .protocolProcessing:
      .algorithmNegotiation
    case .hostDecision:
      .hostVerification
    case .credentialLookup:
      .credentialAccess
    case .authentication:
      .publicKeyAuthentication
    case .transportClose, .channelOpen, .channelRead, .channelWrite, .channelEOF,
      .channelClose, .execRequest, .execExit, .uploadSource, .rekey, .keepalive:
      .sessionClose
    }
  }

  private static func normalizedTransportCause(
    _ code: SSHTransportErrorCode
  ) -> SSHBootstrapTransportCause {
    switch code {
    case .cancelled: .cancelled
    case .timedOut: .timedOut
    case .resolutionFailed, .networkUnavailable: .unavailable
    case .connectionLost, .peerReset, .connectionClosed: .connectionReset
    case .resourceLimitExceeded: .temporaryResourceExhaustion
    default: .unexpected
    }
  }

  private static func hostCause(_ code: SSHTransportErrorCode) -> SSHBootstrapHostCause {
    switch code {
    case .hostTrustRequired, .hostKeyUnknown: .trustRequired
    case .hostKeyChanged: .changed
    case .hostKeyAlgorithmRejected, .algorithmNegotiationFailed: .algorithmUnsupported
    case .hostIdentityRevoked: .revoked
    default: .policyRejected
    }
  }

  private static func credentialCause(
    _ code: SSHTransportErrorCode
  ) -> SSHBootstrapCredentialCause {
    switch code {
    case .credentialUnavailable: .notProvisioned
    case .credentialInteractionRequired: .accessDenied
    default: .malformed
    }
  }

  private static func authenticationCause(
    _ code: SSHTransportErrorCode
  ) -> SSHBootstrapAuthenticationCause {
    switch code {
    case .authenticationMethodUnavailable: .methodUnavailable
    case .authenticationKeyAlgorithmUnavailable: .keyAlgorithmUnavailable
    case .signatureFailed: .signatureFailed
    default: .rejected
    }
  }

  private static func posixCause(_ code: Int32) -> SSHBootstrapTransportCause {
    switch code {
    case ENETDOWN, ENETUNREACH, EHOSTUNREACH, EADDRNOTAVAIL:
      .unavailable
    case ETIMEDOUT:
      .timedOut
    case ECONNREFUSED:
      .connectionRefused
    case ECONNRESET, ENOTCONN, EPIPE:
      .connectionReset
    case ECONNABORTED:
      .connectionAborted
    case EAGAIN, ENOBUFS:
      .temporaryResourceExhaustion
    default:
      .unexpected
    }
  }

  private static func urlCause(_ code: Int) -> SSHBootstrapTransportCause {
    switch code {
    case NSURLErrorTimedOut:
      .timedOut
    case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
      NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
      .unavailable
    case NSURLErrorCancelled:
      .cancelled
    default:
      .unexpected
    }
  }
}
