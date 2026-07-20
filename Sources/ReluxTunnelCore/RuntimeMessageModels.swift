import Foundation

/// Fixed protocol and validation bounds for M1 runtime payloads.
public enum RuntimeMessageProtocol {
  public static let currentProtocolVersion: UInt16 = 1
  public static let minimumProtocolVersion: UInt16 = 1
  public static let maximumProtocolVersion: UInt16 = 1
  public static let currentSchemaVersion: UInt16 = 1
  public static let maximumNestingDepth = 16
}

/// Encoded JSON limits from the accepted M1 runtime contract.
public enum RuntimeMessageSizeLimit {
  public static let legacyVersion = 4 * 1_024
  public static let providerConfiguration = 4 * 1_024
  public static let startRequest = 4 * 1_024
  public static let configurationSnapshot = 64 * 1_024
  public static let command = 4 * 1_024
  public static let protocolCapabilities = 4 * 1_024
  public static let runtimeSnapshot = 16 * 1_024
  public static let capabilitySnapshot = 16 * 1_024
  public static let diagnosticsSnapshot = 64 * 1_024
  public static let protocolError = 4 * 1_024
}

public enum RuntimeMessageKind: String, Codable, CaseIterable, Sendable {
  case configurationSnapshot
  case getProtocolCapabilities
  case getRuntimeSnapshot
  case getCapabilities
  case getDiagnostics
  case protocolCapabilities
  case runtimeSnapshot
  case capabilitySnapshot
  case diagnosticsSnapshot
  case protocolError
}

public enum RuntimeCommandKind: String, Codable, CaseIterable, Sendable {
  case getProtocolCapabilities
  case getRuntimeSnapshot
  case getCapabilities
  case getDiagnostics
}

public struct RuntimeVersionRange: Codable, Equatable, Sendable {
  public let minimum: UInt16
  public let maximum: UInt16

  public init(minimum: UInt16, maximum: UInt16) {
    self.minimum = minimum
    self.maximum = maximum
  }

  public static let currentProtocol = RuntimeVersionRange(
    minimum: RuntimeMessageProtocol.minimumProtocolVersion,
    maximum: RuntimeMessageProtocol.maximumProtocolVersion
  )
  public static let currentSchema = RuntimeVersionRange(
    minimum: RuntimeMessageProtocol.currentSchemaVersion,
    maximum: RuntimeMessageProtocol.currentSchemaVersion
  )
}

/// Ordering key for immutable runtime snapshots.
///
/// A consumer accepts a position only when its generation is newer, or when it
/// has a strictly higher sequence in the same generation.
public struct RuntimeSnapshotPosition: Codable, Equatable, Sendable {
  public let runtimeGeneration: UInt64
  public let snapshotSequence: UInt64

  public init(runtimeGeneration: UInt64, snapshotSequence: UInt64) {
    self.runtimeGeneration = runtimeGeneration
    self.snapshotSequence = snapshotSequence
  }

  public func isNewer(than previous: RuntimeSnapshotPosition?) -> Bool {
    guard let previous else { return true }
    if runtimeGeneration != previous.runtimeGeneration {
      return runtimeGeneration > previous.runtimeGeneration
    }
    return snapshotSequence > previous.snapshotSequence
  }
}

/// UUID-backed profile identity. It cannot carry profile JSON or credential bytes.
public struct OpaqueProfileIdentifier: Codable, Hashable, Sendable {
  public let rawValue: UUID

  public init(_ rawValue: UUID) {
    self.rawValue = rawValue
  }

  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(UUID.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

/// UUID-backed immutable revision of one non-secret profile snapshot.
public struct OpaqueProfileRevision: Codable, Hashable, Sendable {
  public let rawValue: UUID

  public init(_ rawValue: UUID) {
    self.rawValue = rawValue
  }

  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(UUID.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

/// UUID-backed lookup token for a credential stored outside shared JSON.
public struct OpaqueCredentialReference: Codable, Hashable, Sendable {
  public let rawValue: UUID

  public init(_ rawValue: UUID) {
    self.rawValue = rawValue
  }

  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(UUID.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

/// UUID-backed lookup token for an approved host-trust record.
public struct OpaqueTrustReference: Codable, Hashable, Sendable {
  public let rawValue: UUID

  public init(_ rawValue: UUID) {
    self.rawValue = rawValue
  }

  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(UUID.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

/// UUID-backed request correlation identifier. Request payloads carry no free-form text.
public struct OpaqueRuntimeRequestIdentifier: Codable, Hashable, Sendable {
  public let rawValue: UUID

  public init(_ rawValue: UUID) {
    self.rawValue = rawValue
  }

  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(UUID.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

/// Non-secret reference persisted in `providerConfiguration`.
///
/// Required fields: `schemaVersion`, `profileIdentifier`. There are no optional
/// fields or defaults other than the producer-supplied current schema version.
public struct TunnelConfigurationReference: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = RuntimeMessageProtocol.currentSchemaVersion
  public static let maximumEncodedSize = RuntimeMessageSizeLimit.providerConfiguration

  public let schemaVersion: UInt16
  public let profileIdentifier: OpaqueProfileIdentifier

  public init(profileIdentifier: OpaqueProfileIdentifier) {
    schemaVersion = Self.currentSchemaVersion
    self.profileIdentifier = profileIdentifier
  }
}

/// Provider start input decoded from system-owned start options.
///
/// This is not an app-message command. Required fields are `schemaVersion` and
/// `configurationReference`; no fields default when decoding.
public struct RuntimeStartRequest: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = RuntimeMessageProtocol.currentSchemaVersion
  public static let maximumEncodedSize = RuntimeMessageSizeLimit.startRequest

  public let schemaVersion: UInt16
  public let configurationReference: TunnelConfigurationReference

  public init(configurationReference: TunnelConfigurationReference) {
    schemaVersion = Self.currentSchemaVersion
    self.configurationReference = configurationReference
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decode(UInt16.self, forKey: .schemaVersion)
    configurationReference = try container.decode(
      TunnelConfigurationReference.self,
      forKey: .configurationReference
    )
    guard configurationReference.schemaVersion == TunnelConfigurationReference.currentSchemaVersion
    else {
      throw RuntimeMessageCodecError.unsupportedSchemaVersion(
        configurationReference.schemaVersion
      )
    }
  }

  public var tunnelConfiguration: TunnelConfiguration {
    TunnelConfiguration(profileReference: configurationReference)
  }
}

/// M1 accepts only compatible routing. Unknown output modes project to `unknown`.
public enum RuntimeRouteMode: String, Codable, Sendable {
  case compatible
  case unknown

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    self = RuntimeRouteMode(rawValue: value) ?? .unknown
  }
}

public enum RuntimeRouteState: String, Codable, Sendable {
  case notInstalled
  case installed
  case clearFailed
  case unknown

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    self = RuntimeRouteState(rawValue: value) ?? .unknown
  }
}

/// Atomic, non-secret configuration loaded before any M1 side effect.
///
/// All fields except `requestID` are required. The request ID defaults to nil
/// for storage-driven loads. Credential and trust values are lookup identifiers,
/// never Keychain data or host-key evidence.
public struct RuntimeConfigurationSnapshot: Codable, Equatable, Sendable {
  public static let maximumEncodedSize = RuntimeMessageSizeLimit.configurationSnapshot

  public let protocolVersion: UInt16
  public let kind: RuntimeMessageKind
  public let schemaVersion: UInt16
  public let requestID: OpaqueRuntimeRequestIdentifier?
  public let configurationGeneration: UInt64
  public let profileIdentifier: OpaqueProfileIdentifier
  public let profileRevision: OpaqueProfileRevision
  public let credentialReference: OpaqueCredentialReference
  public let trustReference: OpaqueTrustReference
  public let routeMode: RuntimeRouteMode

  public init(
    requestID: OpaqueRuntimeRequestIdentifier? = nil,
    configurationGeneration: UInt64,
    profileIdentifier: OpaqueProfileIdentifier,
    profileRevision: OpaqueProfileRevision,
    credentialReference: OpaqueCredentialReference,
    trustReference: OpaqueTrustReference
  ) {
    protocolVersion = RuntimeMessageProtocol.currentProtocolVersion
    kind = .configurationSnapshot
    schemaVersion = RuntimeMessageProtocol.currentSchemaVersion
    self.requestID = requestID
    self.configurationGeneration = configurationGeneration
    self.profileIdentifier = profileIdentifier
    self.profileRevision = profileRevision
    self.credentialReference = credentialReference
    self.trustReference = trustReference
    routeMode = .compatible
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    protocolVersion = try container.decode(UInt16.self, forKey: .protocolVersion)
    kind = try container.decode(RuntimeMessageKind.self, forKey: .kind)
    schemaVersion = try container.decode(UInt16.self, forKey: .schemaVersion)
    requestID = try container.decodeIfPresent(
      OpaqueRuntimeRequestIdentifier.self,
      forKey: .requestID
    )
    configurationGeneration = try container.decode(
      UInt64.self,
      forKey: .configurationGeneration
    )
    profileIdentifier = try container.decode(
      OpaqueProfileIdentifier.self,
      forKey: .profileIdentifier
    )
    profileRevision = try container.decode(OpaqueProfileRevision.self, forKey: .profileRevision)
    credentialReference = try container.decode(
      OpaqueCredentialReference.self,
      forKey: .credentialReference
    )
    trustReference = try container.decode(OpaqueTrustReference.self, forKey: .trustReference)
    let routeModeValue = try container.decode(String.self, forKey: .routeMode)
    guard routeModeValue == RuntimeRouteMode.compatible.rawValue else {
      throw RuntimeMessageCodecError.unsupportedValue
    }
    routeMode = .compatible
  }
}

/// Read-only provider command. All envelope fields are required except request ID.
public struct RuntimeCommand: Codable, Equatable, Sendable {
  public static let maximumEncodedSize = RuntimeMessageSizeLimit.command

  public let protocolVersion: UInt16
  public let kind: RuntimeCommandKind
  public let schemaVersion: UInt16
  public let requestID: OpaqueRuntimeRequestIdentifier?

  public init(kind: RuntimeCommandKind, requestID: OpaqueRuntimeRequestIdentifier? = nil) {
    protocolVersion = RuntimeMessageProtocol.currentProtocolVersion
    self.kind = kind
    schemaVersion = RuntimeMessageProtocol.currentSchemaVersion
    self.requestID = requestID
  }
}

public struct RuntimeKindCapability: Codable, Equatable, Sendable {
  public let kind: RuntimeMessageKind
  public let schemaVersions: RuntimeVersionRange

  public init(kind: RuntimeMessageKind, schemaVersions: RuntimeVersionRange) {
    self.kind = kind
    self.schemaVersions = schemaVersions
  }
}

/// Response to `getProtocolCapabilities`; all fields except request ID are required.
public struct RuntimeProtocolCapabilitiesSnapshot: Codable, Equatable, Sendable {
  public static let maximumEncodedSize = RuntimeMessageSizeLimit.protocolCapabilities

  public let protocolVersion: UInt16
  public let kind: RuntimeMessageKind
  public let schemaVersion: UInt16
  public let requestID: OpaqueRuntimeRequestIdentifier?
  public let protocolVersions: RuntimeVersionRange
  public let kinds: [RuntimeKindCapability]

  public init(
    requestID: OpaqueRuntimeRequestIdentifier? = nil,
    protocolVersions: RuntimeVersionRange = .currentProtocol,
    kinds: [RuntimeKindCapability]
  ) {
    protocolVersion = RuntimeMessageProtocol.currentProtocolVersion
    kind = .protocolCapabilities
    schemaVersion = RuntimeMessageProtocol.currentSchemaVersion
    self.requestID = requestID
    self.protocolVersions = protocolVersions
    self.kinds = kinds
  }
}

/// Independent M1 capability facts. No aggregate `full` bit exists in this schema.
public struct RuntimeCapabilitySnapshot: Codable, Equatable, Sendable {
  public static let maximumEncodedSize = RuntimeMessageSizeLimit.capabilitySnapshot

  public let protocolVersion: UInt16
  public let kind: RuntimeMessageKind
  public let schemaVersion: UInt16
  public let requestID: OpaqueRuntimeRequestIdentifier?
  public let runtimeGeneration: UInt64
  public let snapshotSequence: UInt64
  public let tcp: Bool
  public let safeDNS: Bool
  public let udp: Bool
  public let routeMode: RuntimeRouteMode
  public let routesInstalled: Bool
  public let healthy: Bool

  public init(
    requestID: OpaqueRuntimeRequestIdentifier? = nil,
    runtimeGeneration: UInt64,
    snapshotSequence: UInt64,
    tcp: Bool,
    safeDNS: Bool,
    udp: Bool,
    routeMode: RuntimeRouteMode,
    routesInstalled: Bool,
    healthy: Bool
  ) {
    protocolVersion = RuntimeMessageProtocol.currentProtocolVersion
    kind = .capabilitySnapshot
    schemaVersion = RuntimeMessageProtocol.currentSchemaVersion
    self.requestID = requestID
    self.runtimeGeneration = runtimeGeneration
    self.snapshotSequence = snapshotSequence
    self.tcp = tcp
    self.safeDNS = safeDNS
    self.udp = udp
    self.routeMode = routeMode
    self.routesInstalled = routesInstalled
    self.healthy = healthy
  }

  public init(from decoder: any Decoder) throws {
    let values = try RuntimeSnapshotValues(from: decoder, expectedKind: .capabilitySnapshot)
    protocolVersion = values.protocolVersion
    kind = .capabilitySnapshot
    schemaVersion = values.schemaVersion
    requestID = values.requestID
    runtimeGeneration = values.runtimeGeneration
    snapshotSequence = values.snapshotSequence
    routeMode = values.routeMode
    let capabilities = values.projectedCapabilities
    tcp = capabilities.tcp
    safeDNS = capabilities.safeDNS
    udp = capabilities.udp
    routesInstalled = capabilities.routesInstalled
    healthy = capabilities.healthy
  }

  public var position: RuntimeSnapshotPosition {
    RuntimeSnapshotPosition(
      runtimeGeneration: runtimeGeneration,
      snapshotSequence: snapshotSequence
    )
  }
}

/// Immutable lifecycle projection. Unknown output state disables all capabilities.
public struct RuntimeLifecycleSnapshot: Codable, Equatable, Sendable {
  public static let maximumEncodedSize = RuntimeMessageSizeLimit.runtimeSnapshot

  public let protocolVersion: UInt16
  public let kind: RuntimeMessageKind
  public let schemaVersion: UInt16
  public let requestID: OpaqueRuntimeRequestIdentifier?
  public let runtimeGeneration: UInt64
  public let snapshotSequence: UInt64
  public let lifecycleState: TunnelLifecycleState
  public let routeState: RuntimeRouteState
  public let tcp: Bool
  public let safeDNS: Bool
  public let udp: Bool
  public let routeMode: RuntimeRouteMode
  public let routesInstalled: Bool
  public let healthy: Bool
  public let error: RedactedRuntimeError?

  public init(
    requestID: OpaqueRuntimeRequestIdentifier? = nil,
    runtimeGeneration: UInt64,
    snapshotSequence: UInt64,
    lifecycleState: TunnelLifecycleState,
    routeState: RuntimeRouteState,
    tcp: Bool,
    safeDNS: Bool,
    udp: Bool,
    routeMode: RuntimeRouteMode,
    routesInstalled: Bool,
    healthy: Bool,
    error: RedactedRuntimeError? = nil
  ) {
    protocolVersion = RuntimeMessageProtocol.currentProtocolVersion
    kind = .runtimeSnapshot
    schemaVersion = RuntimeMessageProtocol.currentSchemaVersion
    self.requestID = requestID
    self.runtimeGeneration = runtimeGeneration
    self.snapshotSequence = snapshotSequence
    self.lifecycleState = lifecycleState
    self.routeState = routeState
    let capabilities = RuntimeCapabilityProjection(
      tcp: tcp,
      safeDNS: safeDNS,
      udp: udp,
      routesInstalled: routesInstalled,
      healthy: healthy
    ).projected(
      routeMode: routeMode,
      lifecycleState: lifecycleState,
      routeState: routeState
    )
    self.tcp = capabilities.tcp
    self.safeDNS = capabilities.safeDNS
    self.udp = capabilities.udp
    self.routeMode = routeMode
    self.routesInstalled = capabilities.routesInstalled
    self.healthy = capabilities.healthy
    self.error = error
  }

  public init(from decoder: any Decoder) throws {
    let values = try RuntimeSnapshotValues(from: decoder, expectedKind: .runtimeSnapshot)
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let decodedLifecycle = try container.decode(TunnelLifecycleState.self, forKey: .lifecycleState)
    protocolVersion = values.protocolVersion
    kind = .runtimeSnapshot
    schemaVersion = values.schemaVersion
    requestID = values.requestID
    runtimeGeneration = values.runtimeGeneration
    snapshotSequence = values.snapshotSequence
    lifecycleState = decodedLifecycle
    let decodedRouteState = try container.decode(RuntimeRouteState.self, forKey: .routeState)
    routeState = decodedRouteState
    routeMode = values.routeMode
    let capabilities = values.projectedCapabilities.projected(
      routeMode: values.routeMode,
      lifecycleState: decodedLifecycle,
      routeState: decodedRouteState
    )
    tcp = capabilities.tcp
    safeDNS = capabilities.safeDNS
    udp = capabilities.udp
    routesInstalled = capabilities.routesInstalled
    healthy = capabilities.healthy
    error = try container.decodeIfPresent(RedactedRuntimeError.self, forKey: .error)
  }

  public var position: RuntimeSnapshotPosition {
    RuntimeSnapshotPosition(
      runtimeGeneration: runtimeGeneration,
      snapshotSequence: snapshotSequence
    )
  }
}

public enum RuntimeErrorDomain: String, Codable, CaseIterable, Hashable, Sendable {
  case configuration
  case sshTrust
  case sshCredential
  case sshTransport
  case tcp
  case dns
  case packetPlane
  case networkSettings
  case runtimeInvariant
  case `protocol`
}

/// Validated finite-token error code. It cannot contain endpoints or error text.
public struct RedactedRuntimeErrorCode: Codable, Hashable, Sendable {
  public static let maximumUTF8Bytes = 64
  public let rawValue: String

  public init(_ rawValue: String) throws {
    guard Self.isValid(rawValue) else {
      throw RuntimeMessageCodecError.unsupportedValue
    }
    self.rawValue = rawValue
  }

  public init(from decoder: any Decoder) throws {
    try self.init(try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  private static func isValid(_ value: String) -> Bool {
    guard !value.isEmpty, value.utf8.count <= maximumUTF8Bytes else { return false }
    return value.utf8.allSatisfy {
      (UInt8(ascii: "a")...UInt8(ascii: "z")).contains($0)
        || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0)
        || $0 == UInt8(ascii: "_")
    }
  }
}

/// Runtime error projection with no message, underlying error, or raw context.
public struct RedactedRuntimeError: Codable, Equatable, Sendable {
  public let domain: RuntimeErrorDomain
  public let code: RedactedRuntimeErrorCode

  public init(domain: RuntimeErrorDomain, code: RedactedRuntimeErrorCode) {
    self.domain = domain
    self.code = code
  }
}

public enum RuntimeDiagnosticUnit: String, Codable, Sendable {
  case count
  case bytes
  case milliseconds
}

public struct RuntimeDiagnosticBucket: Codable, Equatable, Sendable {
  public let upperBound: UInt64
  public let count: UInt64

  public init(upperBound: UInt64, count: UInt64) {
    self.upperBound = upperBound
    self.count = count
  }
}

public struct RuntimeDiagnosticHistogram: Codable, Equatable, Sendable {
  public let unit: RuntimeDiagnosticUnit
  /// Cumulative buckets ordered by increasing upper bound.
  /// `UInt64.max` is the finite wire representation of the catch-all bucket.
  public let buckets: [RuntimeDiagnosticBucket]

  public init(unit: RuntimeDiagnosticUnit, buckets: [RuntimeDiagnosticBucket]) {
    self.unit = unit
    self.buckets = buckets
  }
}

/// Bounded aggregate diagnostics. Empty collections are the only payload defaults.
public struct RuntimeDiagnosticsSnapshot: Codable, Equatable, Sendable {
  public static let maximumEncodedSize = RuntimeMessageSizeLimit.diagnosticsSnapshot
  public static let maximumMetricNameUTF8Bytes = 64

  public let protocolVersion: UInt16
  public let kind: RuntimeMessageKind
  public let schemaVersion: UInt16
  public let requestID: OpaqueRuntimeRequestIdentifier?
  public let runtimeGeneration: UInt64
  public let snapshotSequence: UInt64
  public let counters: [String: UInt64]
  public let gauges: [String: Int64]
  public let histograms: [String: RuntimeDiagnosticHistogram]
  public let errors: [RedactedRuntimeError]

  public init(
    requestID: OpaqueRuntimeRequestIdentifier? = nil,
    runtimeGeneration: UInt64,
    snapshotSequence: UInt64,
    counters: [String: UInt64] = [:],
    gauges: [String: Int64] = [:],
    histograms: [String: RuntimeDiagnosticHistogram] = [:],
    errors: [RedactedRuntimeError] = []
  ) {
    protocolVersion = RuntimeMessageProtocol.currentProtocolVersion
    kind = .diagnosticsSnapshot
    schemaVersion = RuntimeMessageProtocol.currentSchemaVersion
    self.requestID = requestID
    self.runtimeGeneration = runtimeGeneration
    self.snapshotSequence = snapshotSequence
    self.counters = counters
    self.gauges = gauges
    self.histograms = histograms
    self.errors = errors
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    protocolVersion = try container.decode(UInt16.self, forKey: .protocolVersion)
    kind = try container.decode(RuntimeMessageKind.self, forKey: .kind)
    schemaVersion = try container.decode(UInt16.self, forKey: .schemaVersion)
    requestID = try container.decodeIfPresent(
      OpaqueRuntimeRequestIdentifier.self,
      forKey: .requestID
    )
    runtimeGeneration = try container.decode(UInt64.self, forKey: .runtimeGeneration)
    snapshotSequence = try container.decode(UInt64.self, forKey: .snapshotSequence)
    counters =
      if container.contains(.counters) {
        try container.decode([String: UInt64].self, forKey: .counters)
      } else {
        [:]
      }
    gauges =
      if container.contains(.gauges) {
        try container.decode([String: Int64].self, forKey: .gauges)
      } else {
        [:]
      }
    histograms =
      if container.contains(.histograms) {
        try container.decode([String: RuntimeDiagnosticHistogram].self, forKey: .histograms)
      } else {
        [:]
      }
    errors =
      if container.contains(.errors) {
        try container.decode([RedactedRuntimeError].self, forKey: .errors)
      } else {
        []
      }
    try Self.validateMetricNames(counters.keys)
    try Self.validateMetricNames(gauges.keys)
    try Self.validateMetricNames(histograms.keys)
  }

  public func encode(to encoder: any Encoder) throws {
    try Self.validateMetricNames(counters.keys)
    try Self.validateMetricNames(gauges.keys)
    try Self.validateMetricNames(histograms.keys)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(protocolVersion, forKey: .protocolVersion)
    try container.encode(kind, forKey: .kind)
    try container.encode(schemaVersion, forKey: .schemaVersion)
    try container.encodeIfPresent(requestID, forKey: .requestID)
    try container.encode(runtimeGeneration, forKey: .runtimeGeneration)
    try container.encode(snapshotSequence, forKey: .snapshotSequence)
    try container.encode(counters, forKey: .counters)
    try container.encode(gauges, forKey: .gauges)
    try container.encode(histograms, forKey: .histograms)
    try container.encode(errors, forKey: .errors)
  }

  public var position: RuntimeSnapshotPosition {
    RuntimeSnapshotPosition(
      runtimeGeneration: runtimeGeneration,
      snapshotSequence: snapshotSequence
    )
  }

  private static func validateMetricNames<S: Sequence>(_ names: S) throws
  where S.Element == String {
    for name in names {
      guard !name.isEmpty, name.utf8.count <= maximumMetricNameUTF8Bytes,
        name.utf8.allSatisfy({
          (UInt8(ascii: "a")...UInt8(ascii: "z")).contains($0)
            || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0)
            || $0 == UInt8(ascii: "_")
        })
      else {
        throw RuntimeMessageCodecError.unsupportedValue
      }
    }
  }

  private enum CodingKeys: String, CodingKey {
    case protocolVersion
    case kind
    case schemaVersion
    case requestID
    case runtimeGeneration
    case snapshotSequence
    case counters
    case gauges
    case histograms
    case errors
  }
}

public enum RuntimeProtocolErrorCode: String, Codable, Sendable {
  case payloadTooLarge
  case invalidUTF8
  case corruptPayload
  case excessiveNesting
  case duplicateKey
  case unsupportedProtocolVersion
  case unsupportedSchemaVersion
  case unsupportedKind
  case unsupportedValue
}

/// Stable protocol error response. It contains no raw parser or platform error text.
public struct RuntimeProtocolError: Codable, Equatable, Sendable {
  public static let maximumEncodedSize = RuntimeMessageSizeLimit.protocolError

  public let protocolVersion: UInt16
  public let kind: RuntimeMessageKind
  public let schemaVersion: UInt16
  public let requestID: OpaqueRuntimeRequestIdentifier?
  public let domain: RuntimeErrorDomain
  public let code: RuntimeProtocolErrorCode
  public let supportedProtocolVersions: RuntimeVersionRange
  public let supportedSchemaVersions: RuntimeVersionRange

  public init(
    requestID: OpaqueRuntimeRequestIdentifier? = nil,
    code: RuntimeProtocolErrorCode,
    supportedProtocolVersions: RuntimeVersionRange = .currentProtocol,
    supportedSchemaVersions: RuntimeVersionRange = .currentSchema
  ) {
    protocolVersion = RuntimeMessageProtocol.currentProtocolVersion
    kind = .protocolError
    schemaVersion = RuntimeMessageProtocol.currentSchemaVersion
    self.requestID = requestID
    domain = .protocol
    self.code = code
    self.supportedProtocolVersions = supportedProtocolVersions
    self.supportedSchemaVersions = supportedSchemaVersions
  }
}

public enum RuntimeMessageCodecError: Error, Equatable, Sendable {
  case payloadTooLarge(maximumBytes: Int, actualBytes: Int)
  case invalidUTF8
  case corruptPayload
  case excessiveNesting(maximumDepth: Int)
  case duplicateKey
  case unsupportedProtocolVersion(UInt16)
  case unsupportedSchemaVersion(UInt16)
  case unsupportedKind
  case unsupportedValue

  public var protocolErrorCode: RuntimeProtocolErrorCode {
    switch self {
    case .payloadTooLarge: .payloadTooLarge
    case .invalidUTF8: .invalidUTF8
    case .corruptPayload: .corruptPayload
    case .excessiveNesting: .excessiveNesting
    case .duplicateKey: .duplicateKey
    case .unsupportedProtocolVersion: .unsupportedProtocolVersion
    case .unsupportedSchemaVersion: .unsupportedSchemaVersion
    case .unsupportedKind: .unsupportedKind
    case .unsupportedValue: .unsupportedValue
    }
  }
}

public enum RuntimeConfigurationCodec {
  public static func encode(_ reference: TunnelConfigurationReference) throws -> Data {
    try RuntimeJSONCodec.encode(
      reference, maximumBytes: TunnelConfigurationReference.maximumEncodedSize)
  }

  public static func decodeReference(_ data: Data) throws -> TunnelConfigurationReference {
    try RuntimeJSONCodec.decodeVersioned(
      TunnelConfigurationReference.self,
      from: data,
      maximumBytes: TunnelConfigurationReference.maximumEncodedSize
    )
  }

  public static func encode(_ request: RuntimeStartRequest) throws -> Data {
    try RuntimeJSONCodec.encode(request, maximumBytes: RuntimeStartRequest.maximumEncodedSize)
  }

  public static func decodeStartRequest(_ data: Data) throws -> RuntimeStartRequest {
    try RuntimeJSONCodec.decodeVersioned(
      RuntimeStartRequest.self,
      from: data,
      maximumBytes: RuntimeStartRequest.maximumEncodedSize
    )
  }
}

public enum RuntimeMessageCodec {
  public static func encode(_ message: RuntimeConfigurationSnapshot) throws -> Data {
    try RuntimeJSONCodec.encode(
      message, maximumBytes: RuntimeConfigurationSnapshot.maximumEncodedSize)
  }

  public static func decodeConfigurationSnapshot(_ data: Data) throws
    -> RuntimeConfigurationSnapshot
  {
    try RuntimeJSONCodec.decodeMessage(
      RuntimeConfigurationSnapshot.self,
      from: data,
      maximumBytes: RuntimeConfigurationSnapshot.maximumEncodedSize,
      acceptedKinds: [RuntimeMessageKind.configurationSnapshot.rawValue]
    )
  }

  public static func encode(_ command: RuntimeCommand) throws -> Data {
    try RuntimeJSONCodec.encode(command, maximumBytes: RuntimeCommand.maximumEncodedSize)
  }

  public static func decodeCommand(_ data: Data) throws -> RuntimeCommand {
    try RuntimeJSONCodec.decodeMessage(
      RuntimeCommand.self,
      from: data,
      maximumBytes: RuntimeCommand.maximumEncodedSize,
      acceptedKinds: Set(RuntimeCommandKind.allCases.map(\.rawValue))
    )
  }

  public static func encode(_ snapshot: RuntimeProtocolCapabilitiesSnapshot) throws -> Data {
    try RuntimeJSONCodec.encode(
      snapshot,
      maximumBytes: RuntimeProtocolCapabilitiesSnapshot.maximumEncodedSize
    )
  }

  public static func decodeProtocolCapabilities(
    _ data: Data
  ) throws -> RuntimeProtocolCapabilitiesSnapshot {
    try RuntimeJSONCodec.decodeMessage(
      RuntimeProtocolCapabilitiesSnapshot.self,
      from: data,
      maximumBytes: RuntimeProtocolCapabilitiesSnapshot.maximumEncodedSize,
      acceptedKinds: [RuntimeMessageKind.protocolCapabilities.rawValue]
    )
  }

  public static func encode(_ snapshot: RuntimeCapabilitySnapshot) throws -> Data {
    try RuntimeJSONCodec.encode(
      snapshot, maximumBytes: RuntimeCapabilitySnapshot.maximumEncodedSize)
  }

  public static func decodeCapabilitySnapshot(_ data: Data) throws -> RuntimeCapabilitySnapshot {
    try RuntimeJSONCodec.decodeMessage(
      RuntimeCapabilitySnapshot.self,
      from: data,
      maximumBytes: RuntimeCapabilitySnapshot.maximumEncodedSize,
      acceptedKinds: [RuntimeMessageKind.capabilitySnapshot.rawValue]
    )
  }

  public static func encode(_ snapshot: RuntimeLifecycleSnapshot) throws -> Data {
    try RuntimeJSONCodec.encode(snapshot, maximumBytes: RuntimeLifecycleSnapshot.maximumEncodedSize)
  }

  public static func decodeLifecycleSnapshot(_ data: Data) throws -> RuntimeLifecycleSnapshot {
    try RuntimeJSONCodec.decodeMessage(
      RuntimeLifecycleSnapshot.self,
      from: data,
      maximumBytes: RuntimeLifecycleSnapshot.maximumEncodedSize,
      acceptedKinds: [RuntimeMessageKind.runtimeSnapshot.rawValue]
    )
  }

  public static func encode(_ snapshot: RuntimeDiagnosticsSnapshot) throws -> Data {
    try RuntimeJSONCodec.encode(
      snapshot, maximumBytes: RuntimeDiagnosticsSnapshot.maximumEncodedSize)
  }

  public static func decodeDiagnosticsSnapshot(_ data: Data) throws -> RuntimeDiagnosticsSnapshot {
    try RuntimeJSONCodec.decodeMessage(
      RuntimeDiagnosticsSnapshot.self,
      from: data,
      maximumBytes: RuntimeDiagnosticsSnapshot.maximumEncodedSize,
      acceptedKinds: [RuntimeMessageKind.diagnosticsSnapshot.rawValue]
    )
  }

  public static func encode(_ error: RuntimeProtocolError) throws -> Data {
    try RuntimeJSONCodec.encode(error, maximumBytes: RuntimeProtocolError.maximumEncodedSize)
  }

  public static func decodeProtocolError(_ data: Data) throws -> RuntimeProtocolError {
    try RuntimeJSONCodec.decodeMessage(
      RuntimeProtocolError.self,
      from: data,
      maximumBytes: RuntimeProtocolError.maximumEncodedSize,
      acceptedKinds: [RuntimeMessageKind.protocolError.rawValue]
    )
  }
}

private struct RuntimeSnapshotValues {
  let protocolVersion: UInt16
  let schemaVersion: UInt16
  let requestID: OpaqueRuntimeRequestIdentifier?
  let runtimeGeneration: UInt64
  let snapshotSequence: UInt64
  let routeMode: RuntimeRouteMode
  let projectedCapabilities: RuntimeCapabilityProjection

  init(from decoder: any Decoder, expectedKind: RuntimeMessageKind) throws {
    let container = try decoder.container(keyedBy: RuntimeSnapshotCodingKey.self)
    protocolVersion = try container.decode(UInt16.self, forKey: .protocolVersion)
    let kind = try container.decode(RuntimeMessageKind.self, forKey: .kind)
    guard kind == expectedKind else { throw RuntimeMessageCodecError.unsupportedKind }
    schemaVersion = try container.decode(UInt16.self, forKey: .schemaVersion)
    requestID = try container.decodeIfPresent(
      OpaqueRuntimeRequestIdentifier.self, forKey: .requestID)
    runtimeGeneration = try container.decode(UInt64.self, forKey: .runtimeGeneration)
    snapshotSequence = try container.decode(UInt64.self, forKey: .snapshotSequence)
    let decodedRouteMode = try container.decode(RuntimeRouteMode.self, forKey: .routeMode)
    routeMode = decodedRouteMode
    projectedCapabilities = RuntimeCapabilityProjection(
      tcp: try container.decode(Bool.self, forKey: .tcp),
      safeDNS: try container.decode(Bool.self, forKey: .safeDNS),
      udp: try container.decode(Bool.self, forKey: .udp),
      routesInstalled: try container.decode(Bool.self, forKey: .routesInstalled),
      healthy: try container.decode(Bool.self, forKey: .healthy)
    ).projected(routeMode: decodedRouteMode, lifecycleState: nil)
  }
}

private enum RuntimeSnapshotCodingKey: String, CodingKey {
  case protocolVersion
  case kind
  case schemaVersion
  case requestID
  case runtimeGeneration
  case snapshotSequence
  case tcp
  case safeDNS
  case udp
  case routeMode
  case routesInstalled
  case healthy
}

private struct RuntimeCapabilityProjection {
  let tcp: Bool
  let safeDNS: Bool
  let udp: Bool
  let routesInstalled: Bool
  let healthy: Bool

  func projected(
    routeMode: RuntimeRouteMode,
    lifecycleState: TunnelLifecycleState?,
    routeState: RuntimeRouteState? = nil
  ) -> RuntimeCapabilityProjection {
    guard routeMode != .unknown, lifecycleState != .unknown, routeState != .unknown else {
      return RuntimeCapabilityProjection(
        tcp: false,
        safeDNS: false,
        udp: false,
        routesInstalled: false,
        healthy: false
      )
    }
    return self
  }
}

private struct RuntimeMessageHeader: Decodable {
  let protocolVersion: UInt16
  let kind: String
  let schemaVersion: UInt16
}

private struct RuntimeSchemaHeader: Decodable {
  let schemaVersion: UInt16
}

enum RuntimeJSONCodec {
  static func encode<T: Encodable>(_ value: T, maximumBytes: Int) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    do {
      let data = try encoder.encode(value)
      guard data.count <= maximumBytes else {
        throw RuntimeMessageCodecError.payloadTooLarge(
          maximumBytes: maximumBytes,
          actualBytes: data.count
        )
      }
      return data
    } catch let error as RuntimeMessageCodecError {
      throw error
    } catch {
      throw RuntimeMessageCodecError.corruptPayload
    }
  }

  static func decodeVersioned<T: Decodable>(
    _ type: T.Type,
    from data: Data,
    maximumBytes: Int
  ) throws -> T {
    try StrictJSONValidator.validate(data, maximumBytes: maximumBytes)
    let header: RuntimeSchemaHeader = try decodeJSON(RuntimeSchemaHeader.self, from: data)
    guard header.schemaVersion == RuntimeMessageProtocol.currentSchemaVersion else {
      throw RuntimeMessageCodecError.unsupportedSchemaVersion(header.schemaVersion)
    }
    return try decodeJSON(type, from: data)
  }

  static func decodeMessage<T: Decodable>(
    _ type: T.Type,
    from data: Data,
    maximumBytes: Int,
    acceptedKinds: Set<String>
  ) throws -> T {
    try StrictJSONValidator.validate(data, maximumBytes: maximumBytes)
    let header: RuntimeMessageHeader = try decodeJSON(RuntimeMessageHeader.self, from: data)
    guard header.protocolVersion >= RuntimeMessageProtocol.minimumProtocolVersion,
      header.protocolVersion <= RuntimeMessageProtocol.maximumProtocolVersion
    else {
      throw RuntimeMessageCodecError.unsupportedProtocolVersion(header.protocolVersion)
    }
    guard header.schemaVersion == RuntimeMessageProtocol.currentSchemaVersion else {
      throw RuntimeMessageCodecError.unsupportedSchemaVersion(header.schemaVersion)
    }
    guard acceptedKinds.contains(header.kind) else {
      throw RuntimeMessageCodecError.unsupportedKind
    }
    return try decodeJSON(type, from: data)
  }

  private static func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch let error as RuntimeMessageCodecError {
      throw error
    } catch {
      throw RuntimeMessageCodecError.corruptPayload
    }
  }
}

enum StrictJSONValidator {
  @discardableResult
  static func validate(_ data: Data, maximumBytes: Int) throws -> Set<String> {
    guard data.count <= maximumBytes else {
      throw RuntimeMessageCodecError.payloadTooLarge(
        maximumBytes: maximumBytes,
        actualBytes: data.count
      )
    }
    guard String(data: data, encoding: .utf8) != nil else {
      throw RuntimeMessageCodecError.invalidUTF8
    }
    var parser = StrictJSONParser(bytes: Array(data))
    return try parser.parseDocument()
  }
}

private struct StrictJSONParser {
  private let bytes: [UInt8]
  private var index = 0

  init(bytes: [UInt8]) {
    self.bytes = bytes
  }

  mutating func parseDocument() throws -> Set<String> {
    skipWhitespace()
    guard peek == UInt8(ascii: "{") else { throw RuntimeMessageCodecError.corruptPayload }
    let keys = try parseObject(depth: 1)
    skipWhitespace()
    guard index == bytes.count else { throw RuntimeMessageCodecError.corruptPayload }
    return keys
  }

  private mutating func parseValue(depth: Int) throws {
    guard depth <= RuntimeMessageProtocol.maximumNestingDepth else {
      throw RuntimeMessageCodecError.excessiveNesting(
        maximumDepth: RuntimeMessageProtocol.maximumNestingDepth
      )
    }
    guard let current = peek else { throw RuntimeMessageCodecError.corruptPayload }
    switch current {
    case UInt8(ascii: "{"):
      _ = try parseObject(depth: depth)
    case UInt8(ascii: "["):
      try parseArray(depth: depth)
    case UInt8(ascii: "\""):
      _ = try parseString()
    case UInt8(ascii: "t"):
      try consumeLiteral("true")
    case UInt8(ascii: "f"):
      try consumeLiteral("false")
    case UInt8(ascii: "n"):
      try consumeLiteral("null")
    case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
      try parseNumber()
    default:
      throw RuntimeMessageCodecError.corruptPayload
    }
  }

  private mutating func parseObject(depth: Int) throws -> Set<String> {
    guard depth <= RuntimeMessageProtocol.maximumNestingDepth else {
      throw RuntimeMessageCodecError.excessiveNesting(
        maximumDepth: RuntimeMessageProtocol.maximumNestingDepth
      )
    }
    try consume(UInt8(ascii: "{"))
    skipWhitespace()
    var keys: Set<String> = []
    if consumeIf(UInt8(ascii: "}")) { return keys }

    while true {
      guard peek == UInt8(ascii: "\"") else { throw RuntimeMessageCodecError.corruptPayload }
      let key = try parseString()
      guard keys.insert(key).inserted else { throw RuntimeMessageCodecError.duplicateKey }
      skipWhitespace()
      try consume(UInt8(ascii: ":"))
      skipWhitespace()
      try parseValue(depth: depth + 1)
      skipWhitespace()
      if consumeIf(UInt8(ascii: "}")) { return keys }
      try consume(UInt8(ascii: ","))
      skipWhitespace()
    }
  }

  private mutating func parseArray(depth: Int) throws {
    guard depth <= RuntimeMessageProtocol.maximumNestingDepth else {
      throw RuntimeMessageCodecError.excessiveNesting(
        maximumDepth: RuntimeMessageProtocol.maximumNestingDepth
      )
    }
    try consume(UInt8(ascii: "["))
    skipWhitespace()
    if consumeIf(UInt8(ascii: "]")) { return }
    while true {
      try parseValue(depth: depth + 1)
      skipWhitespace()
      if consumeIf(UInt8(ascii: "]")) { return }
      try consume(UInt8(ascii: ","))
      skipWhitespace()
    }
  }

  private mutating func parseString() throws -> String {
    let start = index
    try consume(UInt8(ascii: "\""))
    while let byte = peek {
      index += 1
      if byte == UInt8(ascii: "\"") {
        let token = Data(bytes[start..<index])
        guard let decoded = try? JSONDecoder().decode(String.self, from: token) else {
          throw RuntimeMessageCodecError.corruptPayload
        }
        return decoded
      }
      if byte < 0x20 { throw RuntimeMessageCodecError.corruptPayload }
      if byte == UInt8(ascii: "\\") {
        guard let escaped = peek else { throw RuntimeMessageCodecError.corruptPayload }
        index += 1
        if escaped == UInt8(ascii: "u") {
          for _ in 0..<4 {
            guard let hex = peek, isHex(hex) else {
              throw RuntimeMessageCodecError.corruptPayload
            }
            index += 1
          }
        } else if ![
          UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"),
          UInt8(ascii: "b"), UInt8(ascii: "f"), UInt8(ascii: "n"),
          UInt8(ascii: "r"), UInt8(ascii: "t"),
        ].contains(escaped) {
          throw RuntimeMessageCodecError.corruptPayload
        }
      }
    }
    throw RuntimeMessageCodecError.corruptPayload
  }

  private mutating func parseNumber() throws {
    _ = consumeIf(UInt8(ascii: "-"))
    if consumeIf(UInt8(ascii: "0")) {
      if let next = peek, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(next) {
        throw RuntimeMessageCodecError.corruptPayload
      }
    } else {
      guard let first = peek, (UInt8(ascii: "1")...UInt8(ascii: "9")).contains(first) else {
        throw RuntimeMessageCodecError.corruptPayload
      }
      consumeDigits()
    }
    if consumeIf(UInt8(ascii: ".")) {
      guard let first = peek, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(first) else {
        throw RuntimeMessageCodecError.corruptPayload
      }
      consumeDigits()
    }
    if peek == UInt8(ascii: "e") || peek == UInt8(ascii: "E") {
      index += 1
      if peek == UInt8(ascii: "+") || peek == UInt8(ascii: "-") { index += 1 }
      guard let first = peek, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(first) else {
        throw RuntimeMessageCodecError.corruptPayload
      }
      consumeDigits()
    }
  }

  private mutating func consumeDigits() {
    while let byte = peek, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) {
      index += 1
    }
  }

  private mutating func consumeLiteral(_ literal: StaticString) throws {
    for byte in String(describing: literal).utf8 {
      try consume(byte)
    }
  }

  private mutating func consume(_ expected: UInt8) throws {
    guard peek == expected else { throw RuntimeMessageCodecError.corruptPayload }
    index += 1
  }

  private mutating func consumeIf(_ expected: UInt8) -> Bool {
    guard peek == expected else { return false }
    index += 1
    return true
  }

  private mutating func skipWhitespace() {
    while let byte = peek,
      byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\n")
        || byte == UInt8(ascii: "\r") || byte == UInt8(ascii: "\t")
    {
      index += 1
    }
  }

  private var peek: UInt8? {
    index < bytes.count ? bytes[index] : nil
  }

  private func isHex(_ byte: UInt8) -> Bool {
    (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
      || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
      || (UInt8(ascii: "A")...UInt8(ascii: "F")).contains(byte)
  }
}
