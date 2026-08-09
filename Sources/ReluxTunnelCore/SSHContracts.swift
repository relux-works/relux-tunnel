import CryptoKit
import Foundation

// MARK: - Identities and validation

/// Opaque runtime identity for one immutable SSH lane.
///
/// Callers must generate this value independently of profile, host, user,
/// destination, fingerprint, and credential data.
public struct SSHLaneIdentity: Hashable, Sendable {
  public let rawValue: UUID

  public init(rawValue: UUID) {
    self.rawValue = rawValue
  }
}

/// Opaque connection-local channel correlation identity with no routing meaning.
public struct SSHChannelIdentity: Hashable, Sendable {
  public let rawValue: UUID

  public init(rawValue: UUID) {
    self.rawValue = rawValue
  }
}

/// Opaque identity for one authenticated SSH session.
public struct SSHSessionIdentity: Hashable, Sendable {
  public let rawValue: UUID

  public init(rawValue: UUID) {
    self.rawValue = rawValue
  }
}

public struct SSHCredentialReference: Hashable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct SSHTrustRecordReference: Hashable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum SSHValidationField: String, Equatable, Sendable {
  case canonicalHostname
  case endpointHost
  case endpointPort
  case username
  case profileReference
  case credentialReference
  case trustRecordReference
  case keyExchangeAlgorithms
  case hostKeyAlgorithms
  case cipherAlgorithms
  case macAlgorithms
  case hostKeyAlgorithm
  case hostKeyBytes
  case execCommand
  case maximumReadBytes
  case initialReceiveWindowBytes
  case maximumAdvertisedReceiveWindowBytes
  case windowAdjustThresholdBytes
  case maximumBufferedReadBytes
  case maximumQueuedWriteBytes
  case maximumWriteCallBytes
  case uploadChunkBytes
  case protectedByteThresholdPerDirection
  case rekeyElapsedTimeThreshold
  case rekeyTimeout
  case keepaliveInterval
  case keepaliveReplyTimeout
  case allowedConsecutiveKeepaliveMisses
  case resolutionTimeout
  case tcpConnectTimeout
  case initialKeyExchangeTimeout
  case hostDecisionTimeout
  case credentialLookupTimeout
  case authenticationTimeout
  case channelOpenTimeout
  case writeCreditWaitTimeout
  case explicitRekeyTimeout
  case keepaliveReplyPolicyTimeout
  case execExitTimeout
  case uploadTimeout
  case channelCloseTimeout
  case transportCloseTimeout
}

public enum SSHContractValidationError: Error, Equatable, Sendable {
  case empty(SSHValidationField)
  case nonPositive(SSHValidationField)
  case negative(SSHValidationField)
  case initialReceiveWindowExceedsCap
  case windowAdjustThresholdExceedsCap
  case uploadChunkExceedsWriteCallLimit
  case invalidAddressByteCount(expected: Int, actual: Int)
  case invalidWindowSnapshot
  case invalidWindowAdjustment
  case initialReceiveWindowPolicyMismatch
  case channelOpenReasonRequired
  case channelOpenReasonUnexpected
}

// MARK: - Conformance tiers and deferred evidence

public enum SSHConformanceTier: Equatable, Sendable {
  case m0ViabilityMandatory
  case m3Deferred(ownerTaskID: String)
}

/// Exhaustive candidate-neutral classification of the SSH transport contract.
///
/// M3 entries remain binding obligations. Their evidence may be unavailable at
/// M0, but adapters must report that state instead of inventing a value.
public enum SSHConformanceRequirement: String, CaseIterable, Hashable, Sendable {
  case appleTargetIntegration
  case candidateNeutralInjection
  case hostKeyBeforeAuthentication
  case approvedPublicKeyAuthentication
  case approvedAlgorithmPolicy
  case directTCPIP
  case execAndStdinUpload
  case clientInitiatedRekey
  case serverInitiatedRekeyHandling
  case boundedBuffersAndBackpressure
  case deterministicCancellation
  case boundedLifecycle
  case keychainOnlySecrets
  case privacySafeErrors
  case connectionKeepalive
  case availableObservability
  case consumerDrivenReceiveWindowCredit
  case rfcChannelOpenFailureReasons
  case exactExecExitMetadata
  case deepRekeyAndKeepaliveObservability

  public var tier: SSHConformanceTier {
    switch self {
    case .consumerDrivenReceiveWindowCredit,
      .rfcChannelOpenFailureReasons,
      .exactExecExitMetadata,
      .deepRekeyAndKeepaliveObservability:
      .m3Deferred(ownerTaskID: "TASK-260728-3cveay")
    default:
      .m0ViabilityMandatory
    }
  }
}

/// Evidence state for a semantic whose exact reporting is deferred to M3.
public enum SSHDeferredSemanticReport<Value: Sendable>: Sendable {
  case reported(Value)
  case notReported
  case unsupported
}

extension SSHDeferredSemanticReport: Equatable where Value: Equatable {}

public enum SSHDeferredSemanticAvailability: String, Equatable, Sendable {
  case reported
  case notReported
  case unsupported
}

/// Factory-level disclosure for all four M3-deferred semantics.
public struct SSHDeferredSemanticCapabilities: Equatable, Sendable {
  public let consumerDrivenReceiveWindowCredit: SSHDeferredSemanticAvailability
  public let rfcChannelOpenFailureReasons: SSHDeferredSemanticAvailability
  public let exactExecExitMetadata: SSHDeferredSemanticAvailability
  public let deepRekeyAndKeepaliveObservability: SSHDeferredSemanticAvailability

  public init(
    consumerDrivenReceiveWindowCredit: SSHDeferredSemanticAvailability,
    rfcChannelOpenFailureReasons: SSHDeferredSemanticAvailability,
    exactExecExitMetadata: SSHDeferredSemanticAvailability,
    deepRekeyAndKeepaliveObservability: SSHDeferredSemanticAvailability
  ) {
    self.consumerDrivenReceiveWindowCredit = consumerDrivenReceiveWindowCredit
    self.rfcChannelOpenFailureReasons = rfcChannelOpenFailureReasons
    self.exactExecExitMetadata = exactExecExitMetadata
    self.deepRekeyAndKeepaliveObservability = deepRekeyAndKeepaliveObservability
  }
}

// MARK: - Network and injected dependencies

public enum SSHNetworkAddressFamily: Equatable, Sendable {
  case ipv4
  case ipv6
}

/// A resolved network address. This value is input to the network seam only and
/// must never be copied into default diagnostics.
public struct SSHResolvedEndpoint: Equatable, Sendable {
  public let addressFamily: SSHNetworkAddressFamily
  public let addressBytes: Data
  public let port: UInt16

  public init(
    addressFamily: SSHNetworkAddressFamily,
    addressBytes: Data,
    port: UInt16
  ) throws {
    let expectedCount = addressFamily == .ipv4 ? 4 : 16
    guard addressBytes.count == expectedCount else {
      throw SSHContractValidationError.invalidAddressByteCount(
        expected: expectedCount,
        actual: addressBytes.count
      )
    }
    guard port > 0 else {
      throw SSHContractValidationError.nonPositive(.endpointPort)
    }
    self.addressFamily = addressFamily
    self.addressBytes = addressBytes
    self.port = port
  }
}

public protocol SSHNetworkResolver: Sendable {
  func resolve(hostname: String, port: UInt16) async throws -> [SSHResolvedEndpoint]
}

public enum SSHTCPReadiness: Hashable, Sendable {
  case readable
  case writable
}

/// Candidate-neutral nonblocking TCP connection used by an SSH adapter.
public protocol SSHTCPConnection: AnyObject, Sendable {
  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  func readSome(maximumBytes: Int) async throws -> Data?
  func writeSome(_ bytes: Data) async throws -> Int
  func close() async
}

public protocol SSHTCPConnector: Sendable {
  func connect(to endpoint: SSHResolvedEndpoint) async throws -> any SSHTCPConnection
}

public protocol SSHIdentityGenerator: Sendable {
  func makeLaneIdentity() -> SSHLaneIdentity
  func makeSessionIdentity() -> SSHSessionIdentity
  func makeChannelIdentity() -> SSHChannelIdentity
}

public protocol SSHPublicKeyCredential: Sendable {
  var algorithm: String { get }
  var publicKeyBytes: Data { get }
  func sign(_ payload: Data) async throws -> Data
}

public protocol SSHCredentialProvider: Sendable {
  func credential(for request: SSHCredentialRequest) async throws
    -> any SSHPublicKeyCredential
}

public protocol SSHTransportObserver: Sendable {
  func observe(_ event: SSHTransportEvent) async
}

/// A privacy-safe logger: callers can emit only the typed event schema.
public protocol SSHTransportLogger: Sendable {
  func log(level: TunnelLogLevel, event: SSHTransportEvent) async
}

public protocol SSHTransportMetricsSink: Sendable {
  func record(_ update: SSHMetricUpdate) async
}

/// Optional harness sink. Candidate labels belong to the recorder's harness
/// registration and are deliberately absent from this runtime record.
public protocol SSHExperimentRecorder: Sendable {
  func record(_ observation: SSHExperimentObservation) async
}

public struct SSHTransportDependencies: Sendable {
  public let resolver: any SSHNetworkResolver
  public let connector: any SSHTCPConnector
  public let hostKeyPolicy: any SSHHostKeyPolicy
  public let credentialProvider: any SSHCredentialProvider
  public let clock: any TunnelClock
  public let cancellation: any TunnelCancellationChecking
  public let logger: any SSHTransportLogger
  public let observer: any SSHTransportObserver
  public let metrics: any SSHTransportMetricsSink
  public let identityGenerator: any SSHIdentityGenerator
  public let experimentRecorder: (any SSHExperimentRecorder)?

  public init(
    resolver: any SSHNetworkResolver,
    connector: any SSHTCPConnector,
    hostKeyPolicy: any SSHHostKeyPolicy,
    credentialProvider: any SSHCredentialProvider,
    clock: any TunnelClock,
    cancellation: any TunnelCancellationChecking,
    logger: any SSHTransportLogger,
    observer: any SSHTransportObserver,
    metrics: any SSHTransportMetricsSink,
    identityGenerator: any SSHIdentityGenerator,
    experimentRecorder: (any SSHExperimentRecorder)? = nil
  ) {
    self.resolver = resolver
    self.connector = connector
    self.hostKeyPolicy = hostKeyPolicy
    self.credentialProvider = credentialProvider
    self.clock = clock
    self.cancellation = cancellation
    self.logger = logger
    self.observer = observer
    self.metrics = metrics
    self.identityGenerator = identityGenerator
    self.experimentRecorder = experimentRecorder
  }
}

// MARK: - Host verification and credentials

public struct SSHHostKeyEvidence: Equatable, Sendable {
  public let algorithm: String
  public let keyBytes: Data
  public let fingerprint: String

  public init(algorithm: String, keyBytes: Data) throws {
    guard !algorithm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw SSHContractValidationError.empty(.hostKeyAlgorithm)
    }
    guard !keyBytes.isEmpty else {
      throw SSHContractValidationError.empty(.hostKeyBytes)
    }
    self.algorithm = algorithm
    self.keyBytes = keyBytes
    self.fingerprint = Self.sha256Fingerprint(for: keyBytes)
  }

  public static func sha256Fingerprint(for keyBytes: Data) -> String {
    let digest = SHA256.hash(data: keyBytes)
    let encoded = Data(digest).base64EncodedString().replacingOccurrences(of: "=", with: "")
    return "SHA256:\(encoded)"
  }
}

public struct SSHHostKeyPolicyInput: Equatable, Sendable {
  public let canonicalHostname: String
  public let connectedEndpoint: TunnelEndpoint
  public let evidence: SSHHostKeyEvidence
  public let lane: SSHLaneIdentity
  public let trustRecordReference: SSHTrustRecordReference?

  public init(
    canonicalHostname: String,
    connectedEndpoint: TunnelEndpoint,
    evidence: SSHHostKeyEvidence,
    lane: SSHLaneIdentity,
    trustRecordReference: SSHTrustRecordReference?
  ) {
    self.canonicalHostname = canonicalHostname
    self.connectedEndpoint = connectedEndpoint
    self.evidence = evidence
    self.lane = lane
    self.trustRecordReference = trustRecordReference
  }
}

public enum SSHHostKeyDecision: Equatable, Sendable {
  case acceptFirstUse(SSHTrustRecordReference)
  case acceptMatch(SSHTrustRecordReference)
  case rejectUnknown
  case rejectChanged
  case rejectAlgorithm
  case rejectPolicy
}

public enum SSHHostDecisionOutcome: String, Equatable, Sendable {
  case firstUseAccepted
  case matchAccepted
  case unknownRejected
  case changedRejected
  case algorithmRejected
  case policyRejected
}

public protocol SSHHostKeyPolicy: Sendable {
  func evaluate(_ input: SSHHostKeyPolicyInput) async throws -> SSHHostKeyDecision
}

/// Proof that the host policy returned an accepting decision for exact evidence.
/// Credential requests require this value, making rejection an invalid typed path.
public struct SSHHostKeyAcceptance: Equatable, Sendable {
  public let evidence: SSHHostKeyEvidence
  public let lane: SSHLaneIdentity
  public let outcome: SSHHostDecisionOutcome
  public let trustRecordReference: SSHTrustRecordReference

  fileprivate init(
    evidence: SSHHostKeyEvidence,
    lane: SSHLaneIdentity,
    outcome: SSHHostDecisionOutcome,
    trustRecordReference: SSHTrustRecordReference
  ) {
    self.evidence = evidence
    self.lane = lane
    self.outcome = outcome
    self.trustRecordReference = trustRecordReference
  }
}

public enum SSHHostAcceptanceError: Error, Equatable, Sendable {
  case rejected(SSHHostDecisionOutcome)
}

extension SSHHostKeyDecision {
  public var outcome: SSHHostDecisionOutcome {
    switch self {
    case .acceptFirstUse:
      .firstUseAccepted
    case .acceptMatch:
      .matchAccepted
    case .rejectUnknown:
      .unknownRejected
    case .rejectChanged:
      .changedRejected
    case .rejectAlgorithm:
      .algorithmRejected
    case .rejectPolicy:
      .policyRejected
    }
  }

  public func acceptance(for input: SSHHostKeyPolicyInput) throws -> SSHHostKeyAcceptance {
    switch self {
    case .acceptFirstUse(let reference):
      guard !reference.rawValue.isEmpty else {
        throw SSHContractValidationError.empty(.trustRecordReference)
      }
      return SSHHostKeyAcceptance(
        evidence: input.evidence,
        lane: input.lane,
        outcome: .firstUseAccepted,
        trustRecordReference: reference
      )
    case .acceptMatch(let reference):
      guard !reference.rawValue.isEmpty else {
        throw SSHContractValidationError.empty(.trustRecordReference)
      }
      return SSHHostKeyAcceptance(
        evidence: input.evidence,
        lane: input.lane,
        outcome: .matchAccepted,
        trustRecordReference: reference
      )
    case .rejectUnknown, .rejectChanged, .rejectAlgorithm, .rejectPolicy:
      throw SSHHostAcceptanceError.rejected(outcome)
    }
  }
}

public struct SSHCredentialRequest: Equatable, Sendable {
  public let credentialReference: SSHCredentialReference
  public let username: String
  public let allowedPublicKeyAlgorithms: [String]
  public let acceptedHost: SSHHostKeyAcceptance

  public init(
    credentialReference: SSHCredentialReference,
    username: String,
    allowedPublicKeyAlgorithms: [String],
    acceptedHost: SSHHostKeyAcceptance
  ) {
    self.credentialReference = credentialReference
    self.username = username
    self.allowedPublicKeyAlgorithms = allowedPublicKeyAlgorithms
    self.acceptedHost = acceptedHost
  }
}

public enum SSHAuthenticationOutcome: String, CaseIterable, Equatable, Sendable {
  case success
  case rejectedByServer
  case methodUnavailable
  case keyAlgorithmUnavailable
  case credentialUnavailable
  case credentialInteractionRequired
  case signatureFailed
  case cancelled
  case timedOut
}

// MARK: - Configuration and capability report

public struct SSHAlgorithmPolicy: Equatable, Sendable {
  public let keyExchange: [String]
  public let hostKey: [String]
  public let cipher: [String]
  public let mac: [String]

  public init(
    keyExchange: [String],
    hostKey: [String],
    cipher: [String],
    mac: [String]
  ) throws {
    try Self.requireAlgorithms(keyExchange, field: .keyExchangeAlgorithms)
    try Self.requireAlgorithms(hostKey, field: .hostKeyAlgorithms)
    try Self.requireAlgorithms(cipher, field: .cipherAlgorithms)
    try Self.requireAlgorithms(mac, field: .macAlgorithms)
    self.keyExchange = keyExchange
    self.hostKey = hostKey
    self.cipher = cipher
    self.mac = mac
  }

  private static func requireAlgorithms(
    _ algorithms: [String],
    field: SSHValidationField
  ) throws {
    guard !algorithms.isEmpty,
      algorithms.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    else {
      throw SSHContractValidationError.empty(field)
    }
  }
}

public struct SSHTimeoutPolicy: Equatable, Sendable {
  public let resolution: Duration
  public let tcpConnect: Duration
  public let initialKeyExchange: Duration
  public let hostDecision: Duration
  public let credentialLookup: Duration
  public let authentication: Duration
  public let channelOpen: Duration
  public let writeCreditWait: Duration
  public let explicitRekey: Duration
  public let keepaliveReply: Duration
  public let execExit: Duration
  public let upload: Duration
  public let channelClose: Duration
  public let transportClose: Duration

  public init(
    resolution: Duration,
    tcpConnect: Duration,
    initialKeyExchange: Duration,
    hostDecision: Duration,
    credentialLookup: Duration,
    authentication: Duration,
    channelOpen: Duration,
    writeCreditWait: Duration,
    explicitRekey: Duration,
    keepaliveReply: Duration,
    execExit: Duration,
    upload: Duration,
    channelClose: Duration,
    transportClose: Duration
  ) throws {
    let values: [(Duration, SSHValidationField)] = [
      (resolution, .resolutionTimeout),
      (tcpConnect, .tcpConnectTimeout),
      (initialKeyExchange, .initialKeyExchangeTimeout),
      (hostDecision, .hostDecisionTimeout),
      (credentialLookup, .credentialLookupTimeout),
      (authentication, .authenticationTimeout),
      (channelOpen, .channelOpenTimeout),
      (writeCreditWait, .writeCreditWaitTimeout),
      (explicitRekey, .explicitRekeyTimeout),
      (keepaliveReply, .keepaliveReplyPolicyTimeout),
      (execExit, .execExitTimeout),
      (upload, .uploadTimeout),
      (channelClose, .channelCloseTimeout),
      (transportClose, .transportCloseTimeout),
    ]
    for (duration, field) in values where duration <= .zero {
      throw SSHContractValidationError.nonPositive(field)
    }
    self.resolution = resolution
    self.tcpConnect = tcpConnect
    self.initialKeyExchange = initialKeyExchange
    self.hostDecision = hostDecision
    self.credentialLookup = credentialLookup
    self.authentication = authentication
    self.channelOpen = channelOpen
    self.writeCreditWait = writeCreditWait
    self.explicitRekey = explicitRekey
    self.keepaliveReply = keepaliveReply
    self.execExit = execExit
    self.upload = upload
    self.channelClose = channelClose
    self.transportClose = transportClose
  }
}

public struct SSHRekeyPolicy: Equatable, Sendable {
  public let protectedByteThresholdPerDirection: UInt64
  public let elapsedTimeThreshold: Duration
  public let timeout: Duration

  public init(
    protectedByteThresholdPerDirection: UInt64,
    elapsedTimeThreshold: Duration,
    timeout: Duration
  ) throws {
    guard protectedByteThresholdPerDirection > 0 else {
      throw SSHContractValidationError.nonPositive(.protectedByteThresholdPerDirection)
    }
    guard elapsedTimeThreshold > .zero else {
      throw SSHContractValidationError.nonPositive(.rekeyElapsedTimeThreshold)
    }
    guard timeout > .zero else {
      throw SSHContractValidationError.nonPositive(.rekeyTimeout)
    }
    self.protectedByteThresholdPerDirection = protectedByteThresholdPerDirection
    self.elapsedTimeThreshold = elapsedTimeThreshold
    self.timeout = timeout
  }
}

public struct SSHKeepalivePolicy: Equatable, Sendable {
  public let interval: Duration
  public let replyTimeout: Duration
  public let allowedConsecutiveMisses: Int

  public init(
    interval: Duration,
    replyTimeout: Duration,
    allowedConsecutiveMisses: Int
  ) throws {
    guard interval > .zero else {
      throw SSHContractValidationError.nonPositive(.keepaliveInterval)
    }
    guard replyTimeout > .zero else {
      throw SSHContractValidationError.nonPositive(.keepaliveReplyTimeout)
    }
    guard allowedConsecutiveMisses >= 0 else {
      throw SSHContractValidationError.negative(.allowedConsecutiveKeepaliveMisses)
    }
    self.interval = interval
    self.replyTimeout = replyTimeout
    self.allowedConsecutiveMisses = allowedConsecutiveMisses
  }
}

public struct SSHConnectionConfiguration: Equatable, Sendable {
  public let canonicalHostname: String
  public let endpoint: TunnelEndpoint
  public let username: String
  public let profileReference: TunnelConfigurationReference
  public let credentialReference: SSHCredentialReference
  public let trustRecordReference: SSHTrustRecordReference?
  public let algorithms: SSHAlgorithmPolicy
  public let timeouts: SSHTimeoutPolicy
  public let rekey: SSHRekeyPolicy
  public let keepalive: SSHKeepalivePolicy

  public init(
    canonicalHostname: String,
    endpoint: TunnelEndpoint,
    username: String,
    profileReference: TunnelConfigurationReference,
    credentialReference: SSHCredentialReference,
    trustRecordReference: SSHTrustRecordReference?,
    algorithms: SSHAlgorithmPolicy,
    timeouts: SSHTimeoutPolicy,
    rekey: SSHRekeyPolicy,
    keepalive: SSHKeepalivePolicy
  ) throws {
    guard !canonicalHostname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw SSHContractValidationError.empty(.canonicalHostname)
    }
    guard !endpoint.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw SSHContractValidationError.empty(.endpointHost)
    }
    guard endpoint.port > 0 else {
      throw SSHContractValidationError.nonPositive(.endpointPort)
    }
    guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw SSHContractValidationError.empty(.username)
    }
    guard !credentialReference.rawValue.isEmpty else {
      throw SSHContractValidationError.empty(.credentialReference)
    }
    if let trustRecordReference, trustRecordReference.rawValue.isEmpty {
      throw SSHContractValidationError.empty(.trustRecordReference)
    }
    self.canonicalHostname = canonicalHostname
    self.endpoint = endpoint
    self.username = username
    self.profileReference = profileReference
    self.credentialReference = credentialReference
    self.trustRecordReference = trustRecordReference
    self.algorithms = algorithms
    self.timeouts = timeouts
    self.rekey = rekey
    self.keepalive = keepalive
  }
}

public enum SSHAdapterFeature: String, CaseIterable, Hashable, Sendable {
  case hostKeyBeforeAuthentication
  case publicKeyAuthentication
  case directTCPIP
  case exec
  case execStdinUpload
  case boundedPartialWrites
  case boundedReceiveBuffers
  case clientByteRekey
  case clientTimeRekey
  case explicitRekey
  case serverRekey
  case keepalive
}

/// Common, harness-facing capability data with no adapter identity or handles.
public struct SSHAdapterCapabilities: Equatable, Sendable {
  public let features: Set<SSHAdapterFeature>
  public let deferredSemantics: SSHDeferredSemanticCapabilities
  public let keyExchangeAlgorithms: Set<String>
  public let hostKeyAlgorithms: Set<String>
  public let cipherAlgorithms: Set<String>
  public let macAlgorithms: Set<String>
  public let publicKeyAuthenticationAlgorithms: Set<String>

  public init(
    features: Set<SSHAdapterFeature>,
    deferredSemantics: SSHDeferredSemanticCapabilities,
    keyExchangeAlgorithms: Set<String>,
    hostKeyAlgorithms: Set<String>,
    cipherAlgorithms: Set<String>,
    macAlgorithms: Set<String>,
    publicKeyAuthenticationAlgorithms: Set<String>
  ) {
    self.features = features
    self.deferredSemantics = deferredSemantics
    self.keyExchangeAlgorithms = keyExchangeAlgorithms
    self.hostKeyAlgorithms = hostKeyAlgorithms
    self.cipherAlgorithms = cipherAlgorithms
    self.macAlgorithms = macAlgorithms
    self.publicKeyAuthenticationAlgorithms = publicKeyAuthenticationAlgorithms
  }
}

// MARK: - Connection and channel values

public enum SSHConnectionState: String, CaseIterable, Equatable, Sendable {
  case idle
  case resolving
  case tcpConnecting
  case keyExchange
  case awaitingHostDecision
  case authenticating
  case ready
  case rekeying
  case failed
  case closing
  case closed

  public var permitsConnect: Bool { self == .idle }

  public var permitsChannelOpen: Bool { self == .ready }

  public var isTerminal: Bool { self == .closed }

  public func permitsTransition(to next: SSHConnectionState) -> Bool {
    if self == next {
      return false
    }
    if self != .closed, self != .closing, self != .failed,
      next == .failed || next == .closing
    {
      return true
    }
    return switch (self, next) {
    case (.idle, .resolving),
      (.resolving, .tcpConnecting),
      (.tcpConnecting, .keyExchange),
      (.keyExchange, .awaitingHostDecision),
      (.awaitingHostDecision, .authenticating),
      (.authenticating, .ready),
      (.ready, .rekeying),
      (.rekeying, .ready),
      (.failed, .closing),
      (.closing, .closed):
      true
    default:
      false
    }
  }
}

public enum SSHChannelKind: String, Equatable, Sendable {
  case directTCPIP
  case exec
}

public enum SSHChannelReadState: String, Equatable, Sendable {
  case open
  case eofObserved
  case closed
}

public enum SSHChannelWriteState: String, Equatable, Sendable {
  case open
  case eofSent
  case closed
}

public enum SSHChannelState: String, Equatable, Sendable {
  case opening
  case open
  case closing
  case reset
  case closed
}

public struct SSHNegotiatedAlgorithms: Equatable, Sendable {
  public let keyExchange: String
  public let hostKey: String
  public let cipherClientToServer: String
  public let cipherServerToClient: String
  public let macClientToServer: String
  public let macServerToClient: String

  public init(
    keyExchange: String,
    hostKey: String,
    cipherClientToServer: String,
    cipherServerToClient: String,
    macClientToServer: String,
    macServerToClient: String
  ) {
    self.keyExchange = keyExchange
    self.hostKey = hostKey
    self.cipherClientToServer = cipherClientToServer
    self.cipherServerToClient = cipherServerToClient
    self.macClientToServer = macClientToServer
    self.macServerToClient = macServerToClient
  }
}

public struct SSHSession: Equatable, Sendable {
  public let identity: SSHSessionIdentity
  public let lane: SSHLaneIdentity
  public let acceptedHostKey: SSHHostKeyEvidence
  public let hostDecision: SSHHostDecisionOutcome
  public let negotiatedAlgorithms: SSHNegotiatedAlgorithms
  public let keyExchangeGeneration: SSHDeferredSemanticReport<UInt64>

  public init(
    identity: SSHSessionIdentity,
    acceptedHost: SSHHostKeyAcceptance,
    negotiatedAlgorithms: SSHNegotiatedAlgorithms,
    keyExchangeGeneration: SSHDeferredSemanticReport<UInt64>
  ) {
    self.identity = identity
    self.lane = acceptedHost.lane
    self.acceptedHostKey = acceptedHost.evidence
    self.hostDecision = acceptedHost.outcome
    self.negotiatedAlgorithms = negotiatedAlgorithms
    self.keyExchangeGeneration = keyExchangeGeneration
  }
}

public struct SSHChannelPolicy: Equatable, Sendable {
  public let initialReceiveWindowBytes: Int
  public let consumerReceiveWindowCredit: SSHDeferredSemanticReport<SSHConsumerReceiveWindowPolicy>
  public let maximumBufferedReadBytes: Int
  public let maximumQueuedWriteBytes: Int
  public let maximumWriteCallBytes: Int

  public init(
    initialReceiveWindowBytes: Int,
    consumerReceiveWindowCredit: SSHDeferredSemanticReport<SSHConsumerReceiveWindowPolicy>,
    maximumBufferedReadBytes: Int,
    maximumQueuedWriteBytes: Int,
    maximumWriteCallBytes: Int
  ) throws {
    let positiveValues: [(Int, SSHValidationField)] = [
      (initialReceiveWindowBytes, .initialReceiveWindowBytes),
      (maximumBufferedReadBytes, .maximumBufferedReadBytes),
      (maximumQueuedWriteBytes, .maximumQueuedWriteBytes),
      (maximumWriteCallBytes, .maximumWriteCallBytes),
    ]
    for (value, field) in positiveValues where value <= 0 {
      throw SSHContractValidationError.nonPositive(field)
    }
    if case .reported(let policy) = consumerReceiveWindowCredit,
      policy.initialReceiveWindowBytes != initialReceiveWindowBytes
    {
      throw SSHContractValidationError.initialReceiveWindowPolicyMismatch
    }
    self.initialReceiveWindowBytes = initialReceiveWindowBytes
    self.consumerReceiveWindowCredit = consumerReceiveWindowCredit
    self.maximumBufferedReadBytes = maximumBufferedReadBytes
    self.maximumQueuedWriteBytes = maximumQueuedWriteBytes
    self.maximumWriteCallBytes = maximumWriteCallBytes
  }
}

/// Exact consumer-earned receive-credit policy. Adapters that cannot suppress
/// engine-owned automatic adjustment use an explicit deferred state instead.
public struct SSHConsumerReceiveWindowPolicy: Equatable, Sendable {
  public let initialReceiveWindowBytes: Int
  public let maximumAdvertisedReceiveWindowBytes: Int
  public let windowAdjustThresholdBytes: Int

  public init(
    initialReceiveWindowBytes: Int,
    maximumAdvertisedReceiveWindowBytes: Int,
    windowAdjustThresholdBytes: Int
  ) throws {
    let positiveValues: [(Int, SSHValidationField)] = [
      (initialReceiveWindowBytes, .initialReceiveWindowBytes),
      (maximumAdvertisedReceiveWindowBytes, .maximumAdvertisedReceiveWindowBytes),
      (windowAdjustThresholdBytes, .windowAdjustThresholdBytes),
    ]
    for (value, field) in positiveValues where value <= 0 {
      throw SSHContractValidationError.nonPositive(field)
    }
    guard initialReceiveWindowBytes <= maximumAdvertisedReceiveWindowBytes else {
      throw SSHContractValidationError.initialReceiveWindowExceedsCap
    }
    guard windowAdjustThresholdBytes <= maximumAdvertisedReceiveWindowBytes else {
      throw SSHContractValidationError.windowAdjustThresholdExceedsCap
    }
    self.initialReceiveWindowBytes = initialReceiveWindowBytes
    self.maximumAdvertisedReceiveWindowBytes = maximumAdvertisedReceiveWindowBytes
    self.windowAdjustThresholdBytes = windowAdjustThresholdBytes
  }
}

public struct SSHReceiveWindowSnapshot: Equatable, Sendable {
  public let initialReceiveWindowBytes: Int
  public let maximumAdvertisedReceiveWindowBytes: Int
  public let remainingProtocolCreditBytes: Int
  public let bufferedUnreadBytes: Int
  public let deliveredButNotYetReturnedCreditBytes: Int
  public let adjustmentCount: UInt64
  public let cumulativeAdjustmentBytes: UInt64

  public init(
    initialReceiveWindowBytes: Int,
    maximumAdvertisedReceiveWindowBytes: Int,
    remainingProtocolCreditBytes: Int,
    bufferedUnreadBytes: Int,
    deliveredButNotYetReturnedCreditBytes: Int,
    adjustmentCount: UInt64,
    cumulativeAdjustmentBytes: UInt64
  ) throws {
    let (creditAndBuffered, firstOverflow) =
      remainingProtocolCreditBytes.addingReportingOverflow(bufferedUnreadBytes)
    let (accountedBytes, secondOverflow) =
      creditAndBuffered.addingReportingOverflow(deliveredButNotYetReturnedCreditBytes)
    guard initialReceiveWindowBytes > 0,
      maximumAdvertisedReceiveWindowBytes > 0,
      initialReceiveWindowBytes <= maximumAdvertisedReceiveWindowBytes,
      remainingProtocolCreditBytes >= 0,
      remainingProtocolCreditBytes <= maximumAdvertisedReceiveWindowBytes,
      bufferedUnreadBytes >= 0,
      deliveredButNotYetReturnedCreditBytes >= 0,
      !firstOverflow,
      !secondOverflow,
      accountedBytes <= maximumAdvertisedReceiveWindowBytes
    else {
      throw SSHContractValidationError.invalidWindowSnapshot
    }
    self.initialReceiveWindowBytes = initialReceiveWindowBytes
    self.maximumAdvertisedReceiveWindowBytes = maximumAdvertisedReceiveWindowBytes
    self.remainingProtocolCreditBytes = remainingProtocolCreditBytes
    self.bufferedUnreadBytes = bufferedUnreadBytes
    self.deliveredButNotYetReturnedCreditBytes = deliveredButNotYetReturnedCreditBytes
    self.adjustmentCount = adjustmentCount
    self.cumulativeAdjustmentBytes = cumulativeAdjustmentBytes
  }
}

public struct SSHWindowAdjustment: Equatable, Sendable {
  public let channel: SSHChannelIdentity
  public let before: Int
  public let amount: Int
  public let after: Int
  public let cap: Int

  public init(
    channel: SSHChannelIdentity,
    before: Int,
    amount: Int,
    after: Int,
    cap: Int
  ) throws {
    let (expectedAfter, overflow) = before.addingReportingOverflow(amount)
    guard before >= 0, amount > 0, !overflow, after == expectedAfter, after <= cap else {
      throw SSHContractValidationError.invalidWindowAdjustment
    }
    self.channel = channel
    self.before = before
    self.amount = amount
    self.after = after
    self.cap = cap
  }
}

public struct SSHExecRequest: Equatable, Sendable {
  public let command: String

  public init(command: String) throws {
    guard !command.isEmpty else {
      throw SSHContractValidationError.empty(.execCommand)
    }
    self.command = command
  }
}

public enum SSHExecSignalName: Equatable, Sendable {
  case hangup
  case interrupt
  case quit
  case illegalInstruction
  case abort
  case floatingPointException
  case kill
  case segmentationFault
  case pipe
  case alarm
  case terminate
  case other(String)
}

public struct SSHExecSignal: Equatable, Sendable {
  public let name: SSHExecSignalName
  public let coreDumped: SSHDeferredSemanticReport<Bool>

  public init(name: SSHExecSignalName, coreDumped: SSHDeferredSemanticReport<Bool>) {
    self.name = name
    self.coreDumped = coreDumped
  }
}

public enum SSHExecExit: Equatable, Sendable {
  case status(Int32)
  case signal(SSHExecSignal)
  case notReported
  case unsupported
}

public protocol SSHUploadSource: Sendable {
  func read(maximumBytes: Int) async throws -> Data?
}

public struct SSHExecUploadRequest: Sendable {
  public let exec: SSHExecRequest
  public let source: any SSHUploadSource
  public let channelPolicy: SSHChannelPolicy
  public let chunkBytes: Int

  public init(
    exec: SSHExecRequest,
    source: any SSHUploadSource,
    channelPolicy: SSHChannelPolicy,
    chunkBytes: Int
  ) throws {
    guard chunkBytes > 0 else {
      throw SSHContractValidationError.nonPositive(.uploadChunkBytes)
    }
    guard chunkBytes <= channelPolicy.maximumWriteCallBytes else {
      throw SSHContractValidationError.uploadChunkExceedsWriteCallLimit
    }
    self.exec = exec
    self.source = source
    self.channelPolicy = channelPolicy
    self.chunkBytes = chunkBytes
  }
}

// MARK: - Rekey, keepalive, errors, and diagnostics

public enum SSHClientRekeyReason: String, CaseIterable, Hashable, Sendable {
  case byteThreshold
  case timeThreshold
  case test
  case manual
}

public enum SSHRekeyReason: Hashable, Sendable {
  case client(SSHClientRekeyReason)
  case serverInitiated
}

public enum SSHChannelOpenFailureReason: String, Equatable, Sendable {
  case administrativelyProhibited
  case connectFailed
  case unknownChannelType
  case resourceShortage
  case other
}

/// Evidence for the RFC channel-open rejection reason, including the explicit
/// not-applicable state used by every other transport error code.
public enum SSHChannelOpenReasonReport: Equatable, Sendable {
  case notApplicable
  case reported(SSHChannelOpenFailureReason)
  case notReported
  case unsupported
}

public enum SSHTransportErrorCode: String, CaseIterable, Equatable, Sendable {
  case cancelled
  case timedOut
  case invalidArgument
  case invalidState
  case operationInProgress
  case unsupportedCapability
  case resolutionFailed
  case networkUnavailable
  case connectionLost
  case connectionClosed
  case hostKeyUnknown
  case hostKeyChanged
  case hostKeyRejected
  case hostKeyAlgorithmRejected
  case algorithmNegotiationFailed
  case authenticationRejected
  case authenticationMethodUnavailable
  case authenticationKeyAlgorithmUnavailable
  case credentialUnavailable
  case credentialInteractionRequired
  case signatureFailed
  case channelOpenRejected
  case channelLimitReached
  case channelClosed
  case peerReset
  case channelReset
  case writeAfterEOF
  case backpressureTimedOut
  case execRejected
  case rekeyFailed
  case keepaliveFailed
  case protocolViolation
  case resourceLimitExceeded
  case adapterFailure
}

public enum SSHTransportPhase: String, CaseIterable, Equatable, Sendable {
  case configuration
  case resolution
  case tcpConnect
  case initialKeyExchange
  case hostDecision
  case credentialLookup
  case authentication
  case channelOpen
  case channelRead
  case channelWrite
  case channelEOF
  case channelClose
  case execRequest
  case execExit
  case uploadSource
  case rekey
  case keepalive
  case transportClose
  case protocolProcessing
}

public enum SSHTransportErrorScope: Equatable, Sendable {
  case operation
  case channel(SSHChannelIdentity)
  case lane(SSHLaneIdentity)
}

public enum SSHRetryDisposition: String, CaseIterable, Equatable, Sendable {
  case never
  case afterConfigurationChange
  case newConnection
  case sameChannelOperation
}

public struct SSHTransportError: Error, Equatable, Sendable {
  public let code: SSHTransportErrorCode
  public let phase: SSHTransportPhase
  public let scope: SSHTransportErrorScope
  public let retryDisposition: SSHRetryDisposition
  public let requiresTeardown: Bool
  public let channelOpenReason: SSHChannelOpenReasonReport

  public init(
    code: SSHTransportErrorCode,
    phase: SSHTransportPhase,
    scope: SSHTransportErrorScope,
    retryDisposition: SSHRetryDisposition,
    requiresTeardown: Bool,
    channelOpenReason: SSHChannelOpenReasonReport
  ) throws {
    switch (code == .channelOpenRejected, channelOpenReason) {
    case (true, .notApplicable):
      throw SSHContractValidationError.channelOpenReasonRequired
    case (false, .reported), (false, .notReported), (false, .unsupported):
      throw SSHContractValidationError.channelOpenReasonUnexpected
    default:
      break
    }
    self.init(
      validatedCode: code,
      phase: phase,
      scope: scope,
      retryDisposition: retryDisposition,
      requiresTeardown: requiresTeardown,
      channelOpenReason: channelOpenReason
    )
  }

  private init(
    validatedCode code: SSHTransportErrorCode,
    phase: SSHTransportPhase,
    scope: SSHTransportErrorScope,
    retryDisposition: SSHRetryDisposition,
    requiresTeardown: Bool,
    channelOpenReason: SSHChannelOpenReasonReport
  ) {
    self.code = code
    self.phase = phase
    self.scope = scope
    self.retryDisposition = retryDisposition
    self.requiresTeardown = requiresTeardown
    self.channelOpenReason = channelOpenReason
  }

  public static func hostDecisionFailure(
    _ decision: SSHHostKeyDecision,
    lane: SSHLaneIdentity
  ) -> SSHTransportError? {
    let code: SSHTransportErrorCode
    switch decision {
    case .acceptFirstUse, .acceptMatch:
      return nil
    case .rejectUnknown:
      code = .hostKeyUnknown
    case .rejectChanged:
      code = .hostKeyChanged
    case .rejectAlgorithm:
      code = .hostKeyAlgorithmRejected
    case .rejectPolicy:
      code = .hostKeyRejected
    }
    return SSHTransportError(
      validatedCode: code,
      phase: .hostDecision,
      scope: .lane(lane),
      retryDisposition: .afterConfigurationChange,
      requiresTeardown: true,
      channelOpenReason: .notApplicable
    )
  }

  public static func authenticationFailure(
    _ outcome: SSHAuthenticationOutcome,
    lane: SSHLaneIdentity,
    cancellationPhase: SSHTransportPhase = .authentication
  ) -> SSHTransportError? {
    let code: SSHTransportErrorCode
    let phase: SSHTransportPhase
    let retry: SSHRetryDisposition
    switch outcome {
    case .success:
      return nil
    case .rejectedByServer:
      (code, phase, retry) = (.authenticationRejected, .authentication, .never)
    case .methodUnavailable:
      (code, phase, retry) = (
        .authenticationMethodUnavailable,
        .authentication,
        .afterConfigurationChange
      )
    case .keyAlgorithmUnavailable:
      (code, phase, retry) = (
        .authenticationKeyAlgorithmUnavailable,
        .authentication,
        .afterConfigurationChange
      )
    case .credentialUnavailable:
      (code, phase, retry) = (
        .credentialUnavailable,
        .credentialLookup,
        .afterConfigurationChange
      )
    case .credentialInteractionRequired:
      (code, phase, retry) = (
        .credentialInteractionRequired,
        .credentialLookup,
        .afterConfigurationChange
      )
    case .signatureFailed:
      (code, phase, retry) = (.signatureFailed, .authentication, .never)
    case .cancelled:
      (code, phase, retry) = (.cancelled, cancellationPhase, .newConnection)
    case .timedOut:
      (code, phase, retry) = (.timedOut, cancellationPhase, .newConnection)
    }
    return SSHTransportError(
      validatedCode: code,
      phase: phase,
      scope: .lane(lane),
      retryDisposition: retry,
      requiresTeardown: true,
      channelOpenReason: .notApplicable
    )
  }
}

public enum SSHMetricCounter: String, CaseIterable, Equatable, Sendable {
  case connectAttempts
  case connectSucceeded
  case connectFailed
  case operationsCancelled
  case operationsTimedOut
  case hostFirstUseAccepted
  case hostMatchAccepted
  case hostUnknownRejected
  case hostChangedRejected
  case hostAlgorithmRejected
  case authenticationAttempts
  case authenticationSucceeded
  case authenticationRejected
  case directChannelsOpened
  case execChannelsOpened
  case channelOpenFailed
  case channelsClosedGracefully
  case channelsReset
  case channelsCancelled
  case payloadBytesSent
  case payloadBytesReceived
  case protectedBytesSent
  case protectedBytesReceived
  case writeBackpressureWaits
  case windowAdjustments
  case windowAdjustmentBytes
  case clientByteRekeys
  case clientTimeRekeys
  case explicitRekeys
  case serverRekeys
  case rekeysSucceeded
  case rekeysFailed
  case keepalivesSent
  case keepalivesAcknowledged
  case keepalivesTimedOut
}

public enum SSHMetricGauge: String, CaseIterable, Equatable, Sendable {
  case openDirectChannels
  case openExecChannels
  case pendingChannelOpens
  case pendingReads
  case pendingWrites
  case queuedWriteBytes
  case bufferedReadBytes
  case remainingReceiveWindowBytes
  case activeKeyExchange
  case consecutiveKeepaliveMisses
  case lastKeepaliveRTTNanoseconds
}

public enum SSHMetricUpdate: Equatable, Sendable {
  case increment(SSHMetricCounter, by: UInt64)
  case set(SSHMetricGauge, to: Int64)
}

public struct SSHTransportCounters: Equatable, Sendable {
  public var connectAttempts: UInt64
  public var connectSucceeded: UInt64
  public var connectFailed: UInt64
  public var operationsCancelled: UInt64
  public var operationsTimedOut: UInt64
  public var hostFirstUseAccepted: UInt64
  public var hostMatchAccepted: UInt64
  public var hostUnknownRejected: UInt64
  public var hostChangedRejected: UInt64
  public var hostAlgorithmRejected: UInt64
  public var authenticationAttempts: UInt64
  public var authenticationSucceeded: UInt64
  public var authenticationRejected: UInt64
  public var directChannelsOpened: UInt64
  public var execChannelsOpened: UInt64
  public var channelOpenFailed: UInt64
  public var channelsClosedGracefully: UInt64
  public var channelsReset: UInt64
  public var channelsCancelled: UInt64
  public var payloadBytesSent: UInt64
  public var payloadBytesReceived: UInt64
  public var protectedBytesSent: UInt64
  public var protectedBytesReceived: UInt64
  public var writeBackpressureWaits: UInt64
  public var windowAdjustments: SSHDeferredSemanticReport<UInt64>
  public var windowAdjustmentBytes: SSHDeferredSemanticReport<UInt64>
  public var clientByteRekeys: UInt64
  public var clientTimeRekeys: UInt64
  public var explicitRekeys: UInt64
  public var serverRekeys: SSHDeferredSemanticReport<UInt64>
  public var rekeysSucceeded: UInt64
  public var rekeysFailed: UInt64
  public var keepalivesSent: UInt64
  public var keepalivesAcknowledged: SSHDeferredSemanticReport<UInt64>
  public var keepalivesTimedOut: SSHDeferredSemanticReport<UInt64>

  public init(
    connectAttempts: UInt64 = 0,
    connectSucceeded: UInt64 = 0,
    connectFailed: UInt64 = 0,
    operationsCancelled: UInt64 = 0,
    operationsTimedOut: UInt64 = 0,
    hostFirstUseAccepted: UInt64 = 0,
    hostMatchAccepted: UInt64 = 0,
    hostUnknownRejected: UInt64 = 0,
    hostChangedRejected: UInt64 = 0,
    hostAlgorithmRejected: UInt64 = 0,
    authenticationAttempts: UInt64 = 0,
    authenticationSucceeded: UInt64 = 0,
    authenticationRejected: UInt64 = 0,
    directChannelsOpened: UInt64 = 0,
    execChannelsOpened: UInt64 = 0,
    channelOpenFailed: UInt64 = 0,
    channelsClosedGracefully: UInt64 = 0,
    channelsReset: UInt64 = 0,
    channelsCancelled: UInt64 = 0,
    payloadBytesSent: UInt64 = 0,
    payloadBytesReceived: UInt64 = 0,
    protectedBytesSent: UInt64 = 0,
    protectedBytesReceived: UInt64 = 0,
    writeBackpressureWaits: UInt64 = 0,
    windowAdjustments: SSHDeferredSemanticReport<UInt64>,
    windowAdjustmentBytes: SSHDeferredSemanticReport<UInt64>,
    clientByteRekeys: UInt64 = 0,
    clientTimeRekeys: UInt64 = 0,
    explicitRekeys: UInt64 = 0,
    serverRekeys: SSHDeferredSemanticReport<UInt64>,
    rekeysSucceeded: UInt64 = 0,
    rekeysFailed: UInt64 = 0,
    keepalivesSent: UInt64 = 0,
    keepalivesAcknowledged: SSHDeferredSemanticReport<UInt64>,
    keepalivesTimedOut: SSHDeferredSemanticReport<UInt64>
  ) {
    self.connectAttempts = connectAttempts
    self.connectSucceeded = connectSucceeded
    self.connectFailed = connectFailed
    self.operationsCancelled = operationsCancelled
    self.operationsTimedOut = operationsTimedOut
    self.hostFirstUseAccepted = hostFirstUseAccepted
    self.hostMatchAccepted = hostMatchAccepted
    self.hostUnknownRejected = hostUnknownRejected
    self.hostChangedRejected = hostChangedRejected
    self.hostAlgorithmRejected = hostAlgorithmRejected
    self.authenticationAttempts = authenticationAttempts
    self.authenticationSucceeded = authenticationSucceeded
    self.authenticationRejected = authenticationRejected
    self.directChannelsOpened = directChannelsOpened
    self.execChannelsOpened = execChannelsOpened
    self.channelOpenFailed = channelOpenFailed
    self.channelsClosedGracefully = channelsClosedGracefully
    self.channelsReset = channelsReset
    self.channelsCancelled = channelsCancelled
    self.payloadBytesSent = payloadBytesSent
    self.payloadBytesReceived = payloadBytesReceived
    self.protectedBytesSent = protectedBytesSent
    self.protectedBytesReceived = protectedBytesReceived
    self.writeBackpressureWaits = writeBackpressureWaits
    self.windowAdjustments = windowAdjustments
    self.windowAdjustmentBytes = windowAdjustmentBytes
    self.clientByteRekeys = clientByteRekeys
    self.clientTimeRekeys = clientTimeRekeys
    self.explicitRekeys = explicitRekeys
    self.serverRekeys = serverRekeys
    self.rekeysSucceeded = rekeysSucceeded
    self.rekeysFailed = rekeysFailed
    self.keepalivesSent = keepalivesSent
    self.keepalivesAcknowledged = keepalivesAcknowledged
    self.keepalivesTimedOut = keepalivesTimedOut
  }
}

public struct SSHTransportGauges: Equatable, Sendable {
  public var openDirectChannels: Int64
  public var openExecChannels: Int64
  public var pendingChannelOpens: Int64
  public var pendingReads: Int64
  public var pendingWrites: Int64
  public var queuedWriteBytes: Int64
  public var bufferedReadBytes: Int64
  public var remainingReceiveWindowBytes: SSHDeferredSemanticReport<Int64>
  public var activeKeyExchange: SSHDeferredSemanticReport<Int64>
  public var consecutiveKeepaliveMisses: SSHDeferredSemanticReport<Int64>
  public var lastKeepaliveRTTNanoseconds: SSHDeferredSemanticReport<Int64>

  public init(
    openDirectChannels: Int64 = 0,
    openExecChannels: Int64 = 0,
    pendingChannelOpens: Int64 = 0,
    pendingReads: Int64 = 0,
    pendingWrites: Int64 = 0,
    queuedWriteBytes: Int64 = 0,
    bufferedReadBytes: Int64 = 0,
    remainingReceiveWindowBytes: SSHDeferredSemanticReport<Int64>,
    activeKeyExchange: SSHDeferredSemanticReport<Int64>,
    consecutiveKeepaliveMisses: SSHDeferredSemanticReport<Int64>,
    lastKeepaliveRTTNanoseconds: SSHDeferredSemanticReport<Int64>
  ) {
    self.openDirectChannels = openDirectChannels
    self.openExecChannels = openExecChannels
    self.pendingChannelOpens = pendingChannelOpens
    self.pendingReads = pendingReads
    self.pendingWrites = pendingWrites
    self.queuedWriteBytes = queuedWriteBytes
    self.bufferedReadBytes = bufferedReadBytes
    self.remainingReceiveWindowBytes = remainingReceiveWindowBytes
    self.activeKeyExchange = activeKeyExchange
    self.consecutiveKeepaliveMisses = consecutiveKeepaliveMisses
    self.lastKeepaliveRTTNanoseconds = lastKeepaliveRTTNanoseconds
  }
}

public enum SSHChannelEOFDirection: String, Equatable, Sendable {
  case localWrite
  case remoteRead
}

public enum SSHTransportEventKind: Equatable, Sendable {
  case connectionTransition(from: SSHConnectionState, to: SSHConnectionState)
  case hostDecision(SSHHostDecisionOutcome)
  case authentication(SSHAuthenticationOutcome)
  case channelOpened(channel: SSHChannelIdentity, kind: SSHChannelKind)
  case channelEOF(channel: SSHChannelIdentity, direction: SSHChannelEOFDirection)
  case channelClosed(SSHChannelIdentity)
  case channelReset(SSHChannelIdentity)
  case channelCancelled(SSHChannelIdentity)
  case writeBackpressureBegan(SSHChannelIdentity)
  case writeBackpressureEnded(channel: SSHChannelIdentity, waitDuration: Duration)
  case windowAdjusted(SSHWindowAdjustment)
  case rekeyTriggered(Set<SSHRekeyReason>)
  case rekeyStarted(reasons: Set<SSHRekeyReason>, generation: UInt64)
  case rekeySucceeded(reasons: Set<SSHRekeyReason>, generation: UInt64)
  case rekeyFailed(
    reasons: Set<SSHRekeyReason>,
    generation: UInt64,
    code: SSHTransportErrorCode
  )
  case keepaliveSent
  case keepaliveAcknowledged(roundTripTime: Duration)
  case keepaliveTimedOut(consecutiveMisses: Int)
  case error(code: SSHTransportErrorCode, phase: SSHTransportPhase, scope: SSHTransportErrorScope)
}

public struct SSHTransportEvent: Equatable, Sendable {
  public let schemaVersion: UInt16
  public let timestamp: ContinuousClock.Instant
  public let kind: SSHTransportEventKind

  public init(timestamp: ContinuousClock.Instant, kind: SSHTransportEventKind) {
    self.schemaVersion = 1
    self.timestamp = timestamp
    self.kind = kind
  }
}

public struct SSHTransportSnapshot: Equatable, Sendable {
  public let schemaVersion: UInt16
  public let lane: SSHLaneIdentity
  public let connectionState: SSHConnectionState
  public let negotiatedAlgorithms: SSHNegotiatedAlgorithms?
  public let keyExchangeGeneration: SSHDeferredSemanticReport<UInt64>
  public let counters: SSHTransportCounters
  public let gauges: SSHTransportGauges

  public init(
    lane: SSHLaneIdentity,
    connectionState: SSHConnectionState,
    negotiatedAlgorithms: SSHNegotiatedAlgorithms?,
    keyExchangeGeneration: SSHDeferredSemanticReport<UInt64>,
    counters: SSHTransportCounters,
    gauges: SSHTransportGauges
  ) {
    self.schemaVersion = 1
    self.lane = lane
    self.connectionState = connectionState
    self.negotiatedAlgorithms = negotiatedAlgorithms
    self.keyExchangeGeneration = keyExchangeGeneration
    self.counters = counters
    self.gauges = gauges
  }
}

public enum SSHExperimentObservation: Equatable, Sendable {
  case event(SSHTransportEvent)
  case snapshot(SSHTransportSnapshot)
  case capabilities(SSHAdapterCapabilities)
}

// MARK: - Candidate-neutral transport protocols

public protocol SSHTransportFactory: Sendable {
  /// Harness capability matrix input. It contains no candidate label.
  var capabilities: SSHAdapterCapabilities { get }

  func makeTransport(
    lane: SSHLaneIdentity,
    dependencies: SSHTransportDependencies
  ) async throws -> any SSHTransport
}

public protocol SSHTransport: AnyObject, Sendable {
  /// Valid only while the transport is idle. Returns after host acceptance and
  /// public-key authentication have moved the connection to `ready`.
  func connect(configuration: SSHConnectionConfiguration) async throws -> SSHSession

  /// Opens an RFC 4254 direct-tcpip channel with the supplied endpoints verbatim.
  func openDirectTCPIP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint,
    policy: SSHChannelPolicy
  ) async throws -> any SSHByteChannel

  /// Opens one session channel, sends exactly one exec request, and returns only
  /// after the peer accepts that request.
  func openExecChannel(
    request: SSHExecRequest,
    policy: SSHChannelPolicy
  ) async throws -> any SSHExecChannel

  /// Performs bounded exec-stdin upload while draining stdout and stderr.
  func upload(_ request: SSHExecUploadRequest) async throws -> SSHExecExit

  /// Uses the same production rekey path as automatic and server triggers.
  func requestRekey(reason: SSHClientRekeyReason) async throws

  /// Sends through the configured keepalive path. Exact reply RTT is explicitly
  /// reported only when the adapter exposes the M3 observability semantic.
  func sendKeepalive() async throws -> SSHDeferredSemanticReport<Duration>
  func snapshot() async -> SSHTransportSnapshot

  /// Idempotent, non-cancellable cleanup of channels, engine session, and socket.
  func close() async
}

public protocol SSHByteChannel: AnyObject, Sendable {
  var identity: SSHChannelIdentity { get }

  /// Returns at most `maximumBytes`, and `nil` only after buffered bytes drain
  /// following remote EOF or close. Only one read may be pending per stream.
  func read(maximumBytes: Int) async throws -> Data?

  /// Accepts a positive prefix without exceeding policy bounds. Acceptance
  /// transfers ownership to the transport; zero is never a successful result.
  func writeSome(_ bytes: Data) async throws -> Int

  /// Idempotently sends EOF after accepted bytes and preserves the read half.
  func finishWriting() async throws
  /// Exact consumer-credit accounting is an M3 semantic and must never be
  /// synthesized from engine intake or auto-adjust behavior.
  func receiveWindow() async -> SSHDeferredSemanticReport<SSHReceiveWindowSnapshot>

  /// Cancels this channel only and fails its pending operations as cancelled.
  func cancel() async

  /// Abruptly discards channel buffers without promising a destination TCP RST.
  func reset() async

  /// Idempotent bounded graceful teardown that never expands channel buffers.
  func close() async
}

public protocol SSHExecChannel: SSHByteChannel {
  func readStandardError(maximumBytes: Int) async throws -> Data?
  func waitForExit() async throws -> SSHExecExit
}
