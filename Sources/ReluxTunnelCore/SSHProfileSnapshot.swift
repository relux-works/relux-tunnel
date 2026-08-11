import CryptoKit
import Darwin
import Foundation

public enum SSHProfileHostKind: String, Codable, CaseIterable, Sendable {
  case dns
  case ipv4
  case ipv6
}

public struct SSHProfileCanonicalHost: Equatable, Sendable {
  public let kind: SSHProfileHostKind
  public let value: String

  public init(kind: SSHProfileHostKind, value: String) {
    self.kind = kind
    self.value = value
  }
}

public struct SSHProfileCredentialReferenceV1: Equatable, Sendable {
  public let reference: OpaqueCredentialReference
  public let generation: UInt64

  public init(reference: OpaqueCredentialReference, generation: UInt64) {
    self.reference = reference
    self.generation = generation
  }
}

public enum SSHHostKeyAlgorithm: String, Codable, CaseIterable, Sendable {
  case sshEd25519 = "ssh-ed25519"
  case ecdsaNISTP256 = "ecdsa-sha2-nistp256"
  case ecdsaNISTP384 = "ecdsa-sha2-nistp384"
  case ecdsaNISTP521 = "ecdsa-sha2-nistp521"
  case rsaSHA2512 = "rsa-sha2-512"
  case rsaSHA2256 = "rsa-sha2-256"

  public static let canonicalPreferenceOrder: [SSHHostKeyAlgorithm] = [
    .sshEd25519,
    .ecdsaNISTP256,
    .ecdsaNISTP384,
    .ecdsaNISTP521,
    .rsaSHA2512,
    .rsaSHA2256,
  ]
}

public enum SSHHostIdentityState: String, Codable, Sendable {
  case approved
  case revoked
}

public enum SSHHostIdentityProvenance: String, Codable, Sendable {
  case firstUseApproval
  case changedKeyReplacement
}

public enum SSHHostIdentityRevocationReason: String, Codable, Sendable {
  case replaced
  case userRevoked
}

public struct SSHProfileTimestamp: Equatable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct SSHHostKeyFingerprint: Equatable, Hashable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

/// Lowercase hexadecimal SHA-256 of the exact canonical snapshot bytes.
public struct SSHProfileSnapshotDigestSHA256: Codable, Equatable, Sendable {
  public let rawValue: String

  fileprivate init(validatedRawValue: String) {
    rawValue = validatedRawValue
  }

  public init(_ rawValue: String) throws {
    guard rawValue.utf8.count == 64,
      rawValue.utf8.allSatisfy({ byte in
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
          || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
      })
    else {
      throw RuntimeMessageCodecError.corruptPayload
    }
    self.rawValue = rawValue
  }

  public init(from decoder: any Decoder) throws {
    try self.init(decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct SSHHostIdentityRecordV1: Equatable, Sendable {
  public let algorithm: SSHHostKeyAlgorithm
  public let fingerprintSHA256: SSHHostKeyFingerprint
  public let state: SSHHostIdentityState
  public let provenance: SSHHostIdentityProvenance
  public let firstSeenAt: SSHProfileTimestamp
  public let lastSeenAt: SSHProfileTimestamp
  public let approvedAt: SSHProfileTimestamp?
  public let revokedAt: SSHProfileTimestamp?
  public let revocationReason: SSHHostIdentityRevocationReason?

  public init(
    algorithm: SSHHostKeyAlgorithm,
    fingerprintSHA256: SSHHostKeyFingerprint,
    state: SSHHostIdentityState,
    provenance: SSHHostIdentityProvenance,
    firstSeenAt: SSHProfileTimestamp,
    lastSeenAt: SSHProfileTimestamp,
    approvedAt: SSHProfileTimestamp?,
    revokedAt: SSHProfileTimestamp?,
    revocationReason: SSHHostIdentityRevocationReason?
  ) {
    self.algorithm = algorithm
    self.fingerprintSHA256 = fingerprintSHA256
    self.state = state
    self.provenance = provenance
    self.firstSeenAt = firstSeenAt
    self.lastSeenAt = lastSeenAt
    self.approvedAt = approvedAt
    self.revokedAt = revokedAt
    self.revocationReason = revocationReason
  }
}

public struct SSHHostPolicyV1: Equatable, Sendable {
  public let allowedAlgorithms: [SSHHostKeyAlgorithm]
  public let records: [SSHHostIdentityRecordV1]

  public init(
    allowedAlgorithms: [SSHHostKeyAlgorithm],
    records: [SSHHostIdentityRecordV1]
  ) {
    self.allowedAlgorithms = allowedAlgorithms
    self.records = records
  }
}

/// The complete bounded non-secret profile value captured by a macOS provider start.
///
/// The model deliberately has no raw byte fields and no printable description.
/// Credential material and raw observed host keys cannot be represented here.
public struct SSHProfileSnapshotV1: Equatable, Sendable {
  public static let currentProtocolVersion: UInt16 = 1
  public static let currentSchemaVersion: UInt16 = 1
  public static let kind = "sshProfileSnapshot"
  public static let maximumNestingDepth = 8

  public let protocolVersion: UInt16
  public let schemaVersion: UInt16
  public let configurationGeneration: UInt64
  public let profileID: OpaqueProfileIdentifier
  public let createdAt: SSHProfileTimestamp
  public let updatedAt: SSHProfileTimestamp
  public let displayName: String
  public let canonicalHost: SSHProfileCanonicalHost
  public let port: UInt16
  public let account: String
  public let credential: SSHProfileCredentialReferenceV1
  public let hostPolicy: SSHHostPolicyV1

  public init(
    configurationGeneration: UInt64,
    profileID: OpaqueProfileIdentifier,
    createdAt: SSHProfileTimestamp,
    updatedAt: SSHProfileTimestamp,
    displayName: String,
    canonicalHost: SSHProfileCanonicalHost,
    port: UInt16,
    account: String,
    credential: SSHProfileCredentialReferenceV1,
    hostPolicy: SSHHostPolicyV1
  ) {
    protocolVersion = Self.currentProtocolVersion
    schemaVersion = Self.currentSchemaVersion
    self.configurationGeneration = configurationGeneration
    self.profileID = profileID
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.displayName = displayName
    self.canonicalHost = canonicalHost
    self.port = port
    self.account = account
    self.credential = credential
    self.hostPolicy = hostPolicy
  }
}

public enum SSHProfileSnapshotField: String, Equatable, Sendable {
  case providerConfiguration
  case configurationGeneration
  case profileID
  case createdAt
  case updatedAt
  case displayName
  case canonicalHost
  case port
  case account
  case credentialReference
  case credentialGeneration
  case allowedAlgorithms
  case trustRecords
}

public enum SSHProfileSnapshotErrorCode: String, Equatable, Sendable {
  case profileOversize
  case profileCorrupt
  case profileVersionUnsupported
  case profileInvalidField
  case profileGenerationMismatch
  case profileContainsProhibitedField
}

/// Stable errors that expose only a fixed code and, where safe, a fixed field token.
public enum SSHProfileSnapshotLoaderError: Error, Equatable, Sendable {
  case profileOversize
  case profileCorrupt
  case profileVersionUnsupported
  case profileInvalidField(SSHProfileSnapshotField)
  case profileGenerationMismatch
  case profileContainsProhibitedField

  public var code: SSHProfileSnapshotErrorCode {
    switch self {
    case .profileOversize: .profileOversize
    case .profileCorrupt: .profileCorrupt
    case .profileVersionUnsupported: .profileVersionUnsupported
    case .profileInvalidField: .profileInvalidField
    case .profileGenerationMismatch: .profileGenerationMismatch
    case .profileContainsProhibitedField: .profileContainsProhibitedField
    }
  }
}

public enum SSHProfileSnapshotCodec {
  public static let maximumSnapshotBytes = RuntimeMessageSizeLimit.providerConfiguration

  public static func encode(_ snapshot: SSHProfileSnapshotV1) throws -> Data {
    let wire = SSHProfileSnapshotWire(snapshot)
    _ = try validate(wire)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    do {
      let data = try encoder.encode(wire)
      guard data.count <= maximumSnapshotBytes else {
        throw SSHProfileSnapshotLoaderError.profileOversize
      }
      return data
    } catch let error as SSHProfileSnapshotLoaderError {
      throw error
    } catch {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
  }

  public static func decode(_ data: Data) throws -> SSHProfileSnapshotV1 {
    let validation: StrictJSONValidator.ValidationResult
    do {
      validation = try StrictJSONValidator.validate(
        data,
        maximumBytes: maximumSnapshotBytes,
        maximumDepth: SSHProfileSnapshotV1.maximumNestingDepth,
        requiresSortedKeys: true,
        allowsInsignificantWhitespace: false,
        requiresCanonicalStrings: true,
        requiresCanonicalNumbers: true
      )
    } catch RuntimeMessageCodecError.payloadTooLarge {
      throw SSHProfileSnapshotLoaderError.profileOversize
    } catch {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }

    guard !validation.allObjectKeys.contains(where: isProhibitedFieldName) else {
      throw SSHProfileSnapshotLoaderError.profileContainsProhibitedField
    }

    let header: SSHProfileSnapshotHeader
    do {
      header = try JSONDecoder().decode(SSHProfileSnapshotHeader.self, from: data)
    } catch {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
    guard header.protocolVersion == UInt64(SSHProfileSnapshotV1.currentProtocolVersion),
      header.schemaVersion == UInt64(SSHProfileSnapshotV1.currentSchemaVersion),
      header.kind == SSHProfileSnapshotV1.kind
    else {
      throw SSHProfileSnapshotLoaderError.profileVersionUnsupported
    }

    do {
      return try validate(JSONDecoder().decode(SSHProfileSnapshotWire.self, from: data))
    } catch let error as SSHProfileSnapshotLoaderError {
      throw error
    } catch {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
  }

  /// Validates and hashes the exact canonical bytes that will be stored in the manager.
  public static func digest(
    ofEncodedSnapshot data: Data
  ) throws -> SSHProfileSnapshotDigestSHA256 {
    _ = try decode(data)
    return digestOfValidatedBytes(data)
  }

  public static func digest(
    of snapshot: SSHProfileSnapshotV1
  ) throws -> SSHProfileSnapshotDigestSHA256 {
    digestOfValidatedBytes(try encode(snapshot))
  }

  private static func validate(_ wire: SSHProfileSnapshotWire) throws -> SSHProfileSnapshotV1 {
    guard wire.protocolVersion == UInt64(SSHProfileSnapshotV1.currentProtocolVersion),
      wire.schemaVersion == UInt64(SSHProfileSnapshotV1.currentSchemaVersion),
      wire.kind == SSHProfileSnapshotV1.kind
    else {
      throw SSHProfileSnapshotLoaderError.profileVersionUnsupported
    }
    guard wire.configurationGeneration >= 1 else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.configurationGeneration)
    }
    let profileID = try canonicalUUID(wire.profileID, field: .profileID)
    let createdAt = try timestamp(wire.createdAt, field: .createdAt)
    let updatedAt = try timestamp(wire.updatedAt, field: .updatedAt)
    guard createdAt.date <= updatedAt.date else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.updatedAt)
    }
    try validateDisplayName(wire.displayName)
    let canonicalHost = try validateHost(wire.canonicalHost)
    guard (1...65_535).contains(wire.port), let port = UInt16(exactly: wire.port) else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.port)
    }
    try validateAccount(wire.account)
    let credentialReference = try canonicalUUID(
      wire.credential.ref,
      field: .credentialReference
    )
    guard wire.credential.generation >= 1 else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.credentialGeneration)
    }
    let hostPolicy = try validateHostPolicy(wire.hostPolicy)

    return SSHProfileSnapshotV1(
      configurationGeneration: wire.configurationGeneration,
      profileID: OpaqueProfileIdentifier(profileID),
      createdAt: SSHProfileTimestamp(createdAt.rawValue),
      updatedAt: SSHProfileTimestamp(updatedAt.rawValue),
      displayName: wire.displayName,
      canonicalHost: canonicalHost,
      port: port,
      account: wire.account,
      credential: SSHProfileCredentialReferenceV1(
        reference: OpaqueCredentialReference(credentialReference),
        generation: wire.credential.generation
      ),
      hostPolicy: hostPolicy
    )
  }

  private static func validateHostPolicy(
    _ wire: SSHProfileHostPolicyWire
  ) throws -> SSHHostPolicyV1 {
    guard
      (1...SSHHostKeyAlgorithm.canonicalPreferenceOrder.count).contains(
        wire.allowedAlgorithms.count
      )
    else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.allowedAlgorithms)
    }

    let algorithms: [SSHHostKeyAlgorithm] = try wire.allowedAlgorithms.map { value in
      guard let algorithm = SSHHostKeyAlgorithm(rawValue: value) else {
        throw SSHProfileSnapshotLoaderError.profileInvalidField(.allowedAlgorithms)
      }
      return algorithm
    }
    let canonicalIndexes = algorithms.compactMap {
      SSHHostKeyAlgorithm.canonicalPreferenceOrder.firstIndex(of: $0)
    }
    guard zip(canonicalIndexes, canonicalIndexes.dropFirst()).allSatisfy(<) else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.allowedAlgorithms)
    }
    guard wire.records.count <= 8 else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)
    }

    var tuples: Set<SSHHostIdentityTuple> = []
    var approvedCount = 0
    var records: [SSHHostIdentityRecordV1] = []
    for record in wire.records {
      guard let algorithm = SSHHostKeyAlgorithm(rawValue: record.algorithm),
        algorithms.contains(algorithm),
        let state = SSHHostIdentityState(rawValue: record.state),
        let provenance = SSHHostIdentityProvenance(rawValue: record.provenance)
      else {
        throw SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)
      }
      let fingerprint = try fingerprint(record.fingerprintSHA256)
      let tuple = SSHHostIdentityTuple(algorithm: algorithm, digest: fingerprint.digest)
      guard tuples.insert(tuple).inserted else {
        throw SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)
      }
      let firstSeenAt = try timestamp(record.firstSeenAt, field: .trustRecords)
      let lastSeenAt = try timestamp(record.lastSeenAt, field: .trustRecords)
      guard firstSeenAt.date <= lastSeenAt.date else {
        throw SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)
      }
      let approvedAt = try record.approvedAt.map { value in
        let parsed = try timestamp(value, field: .trustRecords)
        return SSHProfileTimestamp(parsed.rawValue)
      }
      let revokedAt = try record.revokedAt.map { value in
        let parsed = try timestamp(value, field: .trustRecords)
        return SSHProfileTimestamp(parsed.rawValue)
      }
      let revocationReason = record.revocationReason.flatMap(
        SSHHostIdentityRevocationReason.init(rawValue:)
      )

      switch state {
      case .approved:
        approvedCount += 1
        guard approvedAt != nil, revokedAt == nil, record.revocationReason == nil else {
          throw SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)
        }
      case .revoked:
        guard revokedAt != nil, revocationReason != nil else {
          throw SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)
        }
      }
      if record.revocationReason != nil, revocationReason == nil {
        throw SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)
      }

      records.append(
        SSHHostIdentityRecordV1(
          algorithm: algorithm,
          fingerprintSHA256: SSHHostKeyFingerprint(fingerprint.rawValue),
          state: state,
          provenance: provenance,
          firstSeenAt: SSHProfileTimestamp(firstSeenAt.rawValue),
          lastSeenAt: SSHProfileTimestamp(lastSeenAt.rawValue),
          approvedAt: approvedAt,
          revokedAt: revokedAt,
          revocationReason: revocationReason
        )
      )
    }
    guard approvedCount <= 1 else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)
    }

    let sortedTuples = tuples.sorted(by: SSHHostIdentityTuple.isOrderedBefore)
    let actualTuples = records.map {
      SSHHostIdentityTuple(
        algorithm: $0.algorithm,
        digest: fingerprintDigest($0.fingerprintSHA256.rawValue)!
      )
    }
    guard actualTuples == sortedTuples else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)
    }
    return SSHHostPolicyV1(allowedAlgorithms: algorithms, records: records)
  }

  private static func validateDisplayName(_ value: String) throws {
    guard value.utf8.elementsEqual(value.precomposedStringWithCanonicalMapping.utf8),
      value == value.trimmingCharacters(in: .whitespacesAndNewlines),
      (1...128).contains(value.unicodeScalars.count),
      !value.unicodeScalars.contains(where: isRejectedDisplayScalar)
    else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.displayName)
    }
  }

  private static func validateAccount(_ value: String) throws {
    guard value.utf8.elementsEqual(value.precomposedStringWithCanonicalMapping.utf8),
      value == value.trimmingCharacters(in: .whitespacesAndNewlines),
      (1...64).contains(value.utf8.count),
      !value.unicodeScalars.contains(where: isRejectedAccountScalar)
    else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.account)
    }
  }

  private static func validateHost(
    _ wire: SSHProfileCanonicalHostWire
  ) throws -> SSHProfileCanonicalHost {
    guard let kind = SSHProfileHostKind(rawValue: wire.kind) else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.canonicalHost)
    }
    let value = wire.value
    guard !value.isEmpty,
      value == value.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n")),
      !value.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }),
      !value.contains(where: { $0.isWhitespace }),
      !value.contains("@"), !value.contains("/"), !value.contains("?"),
      !value.contains("#"), !value.contains("["), !value.contains("]"),
      !value.contains("%"), !value.contains("://")
    else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.canonicalHost)
    }

    let isCanonical: Bool
    switch kind {
    case .dns:
      isCanonical = isCanonicalDNS(value)
    case .ipv4:
      isCanonical = canonicalNumericAddress(value, family: AF_INET) == value
    case .ipv6:
      isCanonical = canonicalNumericAddress(value, family: AF_INET6) == value
    }
    guard isCanonical else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.canonicalHost)
    }
    return SSHProfileCanonicalHost(kind: kind, value: value)
  }

  private static func isCanonicalDNS(_ value: String) -> Bool {
    guard value.utf8.count <= 253,
      value.unicodeScalars.allSatisfy({ $0.isASCII }),
      value == value.lowercased(),
      !value.hasSuffix("."),
      canonicalNumericAddress(value, family: AF_INET) == nil,
      canonicalNumericAddress(value, family: AF_INET6) == nil
    else { return false }

    let labels = value.split(separator: ".", omittingEmptySubsequences: false)
    guard !labels.isEmpty else { return false }
    if labels.count == 4,
      labels.allSatisfy({ label in
        !label.isEmpty && label.allSatisfy(\.isNumber)
      })
    {
      return false
    }
    for label in labels {
      guard (1...63).contains(label.utf8.count),
        label.first != "-", label.last != "-",
        label.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
      else { return false }
      if label.count >= 4,
        label[label.index(label.startIndex, offsetBy: 2)] == "-",
        label[label.index(label.startIndex, offsetBy: 3)] == "-",
        !label.hasPrefix("xn--")
      {
        return false
      }
    }

    var components = URLComponents()
    components.scheme = "ssh"
    components.host = value
    guard let unicodeHost = components.host,
      let encodedHost = components.url?.host()?.lowercased(),
      encodedHost == value
    else { return false }
    var roundTrip = URLComponents()
    roundTrip.scheme = "ssh"
    roundTrip.host = unicodeHost
    return roundTrip.url?.host()?.lowercased() == value
  }

  private static func canonicalNumericAddress(_ value: String, family: Int32) -> String? {
    if family == AF_INET {
      var address = in_addr()
      guard value.withCString({ inet_pton(AF_INET, $0, &address) }) == 1 else { return nil }
      var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
      guard inet_ntop(AF_INET, &address, &buffer, socklen_t(buffer.count)) != nil else {
        return nil
      }
      return String(
        decoding: buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
        as: UTF8.self
      )
    }
    var address = in6_addr()
    guard value.withCString({ inet_pton(AF_INET6, $0, &address) }) == 1 else { return nil }
    var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
    guard inet_ntop(AF_INET6, &address, &buffer, socklen_t(buffer.count)) != nil else {
      return nil
    }
    return String(
      decoding: buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
      as: UTF8.self
    )
  }

  private static func canonicalUUID(
    _ value: String,
    field: SSHProfileSnapshotField
  ) throws -> UUID {
    guard let uuid = UUID(uuidString: value), uuid.uuidString.lowercased() == value else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(field)
    }
    return uuid
  }

  private static func timestamp(
    _ value: String,
    field: SSHProfileSnapshotField
  ) throws -> (rawValue: String, date: Date) {
    let bytes = Array(value.utf8)
    guard bytes.count == 24,
      bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-"),
      bytes[10] == UInt8(ascii: "T"), bytes[13] == UInt8(ascii: ":"),
      bytes[16] == UInt8(ascii: ":"), bytes[19] == UInt8(ascii: "."),
      bytes[23] == UInt8(ascii: "Z"),
      bytes.enumerated().allSatisfy({ index, byte in
        [4, 7, 10, 13, 16, 19, 23].contains(index)
          || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
      })
    else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(field)
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(field)
    }
    return (value, date)
  }

  private static func fingerprint(
    _ value: String
  ) throws -> (rawValue: String, digest: Data) {
    guard let digest = fingerprintDigest(value) else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)
    }
    return (value, digest)
  }

  private static func fingerprintDigest(_ value: String) -> Data? {
    guard value.hasPrefix("SHA256:"), value.utf8.count == 50 else { return nil }
    let encoded = String(value.dropFirst(7))
    guard encoded.utf8.count == 43,
      encoded.unicodeScalars.allSatisfy({ scalar in
        scalar.isASCII
          && (("A"..."Z").contains(Character(scalar))
            || ("a"..."z").contains(Character(scalar))
            || ("0"..."9").contains(Character(scalar))
            || scalar == "+" || scalar == "/")
      }),
      let data = Data(base64Encoded: encoded + "="), data.count == 32,
      data.base64EncodedString().dropLast() == encoded
    else { return nil }
    return data
  }

  private static func isRejectedDisplayScalar(_ scalar: Unicode.Scalar) -> Bool {
    CharacterSet.controlCharacters.contains(scalar)
      || scalar.value == 0x2028 || scalar.value == 0x2029
      || (0x202A...0x202E).contains(scalar.value)
      || (0x2066...0x2069).contains(scalar.value)
  }

  private static func isRejectedAccountScalar(_ scalar: Unicode.Scalar) -> Bool {
    scalar.value == 0 || CharacterSet.controlCharacters.contains(scalar)
      || scalar.value == 0x2028 || scalar.value == 0x2029
  }

  private static func isProhibitedFieldName(_ name: String) -> Bool {
    let normalized = name.lowercased().unicodeScalars.filter {
      CharacterSet.alphanumerics.contains($0)
    }.map(String.init).joined()
    let prohibitedRoots = [
      "privatekey", "seed", "passphrase", "decryptedkey", "decryptedprivatekey",
      "keybyte", "keybytes", "rawhostkey", "password", "stagingcredential",
    ]
    let prohibitedSuffixes: Set<String> = [
      "", "byte", "bytes", "content", "data", "material", "payload", "value",
    ]
    return prohibitedRoots.contains { root in
      guard normalized.hasPrefix(root) else { return false }
      return prohibitedSuffixes.contains(String(normalized.dropFirst(root.count)))
    }
  }

  fileprivate static func digestOfValidatedBytes(
    _ data: Data
  ) -> SSHProfileSnapshotDigestSHA256 {
    let value = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    return SSHProfileSnapshotDigestSHA256(validatedRawValue: value)
  }
}

public enum SSHProfileProviderConfigurationCodec {
  public static let maximumEnvelopeBytes = RuntimeMessageSizeLimit.providerConfiguration

  public static func encode(
    _ snapshot: SSHProfileSnapshotV1
  ) throws -> [String: VPNProviderConfigurationValue] {
    let data = try SSHProfileSnapshotCodec.encode(snapshot)
    let configuration: [String: VPNProviderConfigurationValue] = [
      OwnedVPNManagerRepository.ownerKey: .string(OwnedVPNManagerRepository.ownerValue),
      OwnedVPNManagerRepository.managerContractKey: .integer(
        OwnedVPNManagerRepository.managerContractVersion
      ),
      OwnedVPNManagerRepository.configurationReferenceKey: .data(data),
    ]
    guard try envelopeSize(configuration) <= maximumEnvelopeBytes else {
      throw SSHProfileSnapshotLoaderError.profileOversize
    }
    return configuration
  }

  public static func decode(
    _ configuration: [String: VPNProviderConfigurationValue]?
  ) throws -> SSHProfileSnapshotV1 {
    try decodeCapture(configuration).snapshot
  }

  public static func startRequest(
    for configuration: [String: VPNProviderConfigurationValue]?
  ) throws -> RuntimeStartRequest {
    let candidate = try decodeCapture(configuration)
    return RuntimeStartRequest(
      configurationGeneration: candidate.snapshot.configurationGeneration,
      snapshotDigestSHA256: SSHProfileSnapshotCodec.digestOfValidatedBytes(candidate.data)
    )
  }

  public static func envelopeSize(
    _ configuration: [String: VPNProviderConfigurationValue]
  ) throws -> Int {
    let propertyList = try exactPropertyList(configuration)
    do {
      return try PropertyListSerialization.data(
        fromPropertyList: propertyList,
        format: .binary,
        options: 0
      ).count
    } catch {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
  }

  static func decodeCapture(
    _ configuration: [String: VPNProviderConfigurationValue]?
  ) throws -> (snapshot: SSHProfileSnapshotV1, data: Data) {
    guard let configuration else {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
    let propertyList = try exactPropertyList(configuration)
    guard
      case .data(let data) = configuration[
        OwnedVPNManagerRepository.configurationReferenceKey
      ]
    else {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
    guard data.count <= maximumEnvelopeBytes else {
      throw SSHProfileSnapshotLoaderError.profileOversize
    }
    do {
      let envelope = try PropertyListSerialization.data(
        fromPropertyList: propertyList,
        format: .binary,
        options: 0
      )
      guard envelope.count <= maximumEnvelopeBytes else {
        throw SSHProfileSnapshotLoaderError.profileOversize
      }
    } catch let error as SSHProfileSnapshotLoaderError {
      throw error
    } catch {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
    return (try SSHProfileSnapshotCodec.decode(data), data)
  }

  private static func exactPropertyList(
    _ configuration: [String: VPNProviderConfigurationValue]
  ) throws -> [String: Any] {
    let requiredKeys: Set<String> = [
      OwnedVPNManagerRepository.ownerKey,
      OwnedVPNManagerRepository.managerContractKey,
      OwnedVPNManagerRepository.configurationReferenceKey,
    ]
    guard Set(configuration.keys) == requiredKeys,
      configuration[OwnedVPNManagerRepository.ownerKey]
        == .string(OwnedVPNManagerRepository.ownerValue)
    else {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
    guard
      case .integer(let managerVersion)? = configuration[
        OwnedVPNManagerRepository.managerContractKey
      ]
    else {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
    guard managerVersion == OwnedVPNManagerRepository.managerContractVersion else {
      throw SSHProfileSnapshotLoaderError.profileVersionUnsupported
    }
    guard
      case .data(let data)? = configuration[
        OwnedVPNManagerRepository.configurationReferenceKey
      ]
    else {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
    return [
      OwnedVPNManagerRepository.ownerKey: OwnedVPNManagerRepository.ownerValue,
      OwnedVPNManagerRepository.managerContractKey: NSNumber(
        value: OwnedVPNManagerRepository.managerContractVersion
      ),
      OwnedVPNManagerRepository.configurationReferenceKey: data,
    ]
  }
}

/// A once-only, thread-safe capture for one provider runtime start.
///
/// Construct a fresh loader for each start. It never consults storage, performs
/// credential work, or mutates a profile. Concurrent candidates race only for
/// the first complete validated capture; all differing candidates fail closed.
public final class SSHProfileRuntimeSnapshotLoader: @unchecked Sendable {
  private struct Capture {
    let data: Data
    let snapshot: SSHProfileSnapshotV1
  }

  private let lock = NSLock()
  private var capture: Capture?

  public init() {}

  public func capture(
    from providerConfiguration: [String: VPNProviderConfigurationValue]?,
    startRequest: RuntimeStartRequest? = nil
  ) throws -> SSHProfileSnapshotV1 {
    let candidate = try SSHProfileProviderConfigurationCodec.decodeCapture(
      providerConfiguration
    )
    if let startRequest {
      guard candidate.snapshot.configurationGeneration == startRequest.configurationGeneration,
        SSHProfileSnapshotCodec.digestOfValidatedBytes(candidate.data)
          == startRequest.snapshotDigestSHA256
      else {
        throw SSHProfileSnapshotLoaderError.profileGenerationMismatch
      }
    }

    return try lock.withLock {
      if let capture {
        guard capture.data == candidate.data else {
          throw SSHProfileSnapshotLoaderError.profileGenerationMismatch
        }
        return capture.snapshot
      }
      let immutableCapture = Capture(data: candidate.data, snapshot: candidate.snapshot)
      capture = immutableCapture
      return immutableCapture.snapshot
    }
  }
}

private struct SSHProfileSnapshotHeader: Decodable {
  let protocolVersion: UInt64
  let kind: String
  let schemaVersion: UInt64
}

private struct SSHProfileSnapshotWire: Codable {
  let protocolVersion: UInt64
  let kind: String
  let schemaVersion: UInt64
  let configurationGeneration: UInt64
  let profileID: String
  let createdAt: String
  let updatedAt: String
  let displayName: String
  let canonicalHost: SSHProfileCanonicalHostWire
  let port: UInt64
  let account: String
  let credential: SSHProfileCredentialWire
  let hostPolicy: SSHProfileHostPolicyWire

  init(_ snapshot: SSHProfileSnapshotV1) {
    protocolVersion = UInt64(snapshot.protocolVersion)
    kind = SSHProfileSnapshotV1.kind
    schemaVersion = UInt64(snapshot.schemaVersion)
    configurationGeneration = snapshot.configurationGeneration
    profileID = snapshot.profileID.rawValue.uuidString.lowercased()
    createdAt = snapshot.createdAt.rawValue
    updatedAt = snapshot.updatedAt.rawValue
    displayName = snapshot.displayName
    canonicalHost = SSHProfileCanonicalHostWire(snapshot.canonicalHost)
    port = UInt64(snapshot.port)
    account = snapshot.account
    credential = SSHProfileCredentialWire(snapshot.credential)
    hostPolicy = SSHProfileHostPolicyWire(snapshot.hostPolicy)
  }
}

private struct SSHProfileCanonicalHostWire: Codable {
  let kind: String
  let value: String

  init(_ host: SSHProfileCanonicalHost) {
    kind = host.kind.rawValue
    value = host.value
  }
}

private struct SSHProfileCredentialWire: Codable {
  let ref: String
  let generation: UInt64

  init(_ credential: SSHProfileCredentialReferenceV1) {
    ref = credential.reference.rawValue.uuidString.lowercased()
    generation = credential.generation
  }
}

private struct SSHProfileHostPolicyWire: Codable {
  let allowedAlgorithms: [String]
  let records: [SSHProfileHostIdentityRecordWire]

  init(_ policy: SSHHostPolicyV1) {
    allowedAlgorithms = policy.allowedAlgorithms.map(\.rawValue)
    records = policy.records.map(SSHProfileHostIdentityRecordWire.init)
  }
}

private struct SSHProfileHostIdentityRecordWire: Codable {
  let algorithm: String
  let fingerprintSHA256: String
  let state: String
  let provenance: String
  let firstSeenAt: String
  let lastSeenAt: String
  let approvedAt: String?
  let revokedAt: String?
  let revocationReason: String?

  init(_ record: SSHHostIdentityRecordV1) {
    algorithm = record.algorithm.rawValue
    fingerprintSHA256 = record.fingerprintSHA256.rawValue
    state = record.state.rawValue
    provenance = record.provenance.rawValue
    firstSeenAt = record.firstSeenAt.rawValue
    lastSeenAt = record.lastSeenAt.rawValue
    approvedAt = record.approvedAt?.rawValue
    revokedAt = record.revokedAt?.rawValue
    revocationReason = record.revocationReason?.rawValue
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    guard CodingKeys.allCases.allSatisfy(container.contains) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "missing required field")
      )
    }
    algorithm = try container.decode(String.self, forKey: .algorithm)
    fingerprintSHA256 = try container.decode(String.self, forKey: .fingerprintSHA256)
    state = try container.decode(String.self, forKey: .state)
    provenance = try container.decode(String.self, forKey: .provenance)
    firstSeenAt = try container.decode(String.self, forKey: .firstSeenAt)
    lastSeenAt = try container.decode(String.self, forKey: .lastSeenAt)
    approvedAt = try container.decodeIfPresent(String.self, forKey: .approvedAt)
    revokedAt = try container.decodeIfPresent(String.self, forKey: .revokedAt)
    revocationReason = try container.decodeIfPresent(String.self, forKey: .revocationReason)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(algorithm, forKey: .algorithm)
    try container.encode(fingerprintSHA256, forKey: .fingerprintSHA256)
    try container.encode(state, forKey: .state)
    try container.encode(provenance, forKey: .provenance)
    try container.encode(firstSeenAt, forKey: .firstSeenAt)
    try container.encode(lastSeenAt, forKey: .lastSeenAt)
    if let approvedAt {
      try container.encode(approvedAt, forKey: .approvedAt)
    } else {
      try container.encodeNil(forKey: .approvedAt)
    }
    if let revokedAt {
      try container.encode(revokedAt, forKey: .revokedAt)
    } else {
      try container.encodeNil(forKey: .revokedAt)
    }
    if let revocationReason {
      try container.encode(revocationReason, forKey: .revocationReason)
    } else {
      try container.encodeNil(forKey: .revocationReason)
    }
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case algorithm
    case fingerprintSHA256
    case state
    case provenance
    case firstSeenAt
    case lastSeenAt
    case approvedAt
    case revokedAt
    case revocationReason
  }
}

private struct SSHHostIdentityTuple: Hashable {
  let algorithm: SSHHostKeyAlgorithm
  let digest: Data

  static func isOrderedBefore(_ lhs: Self, _ rhs: Self) -> Bool {
    if lhs.algorithm.rawValue != rhs.algorithm.rawValue {
      return lhs.algorithm.rawValue.utf8.lexicographicallyPrecedes(rhs.algorithm.rawValue.utf8)
    }
    return lhs.digest.lexicographicallyPrecedes(rhs.digest)
  }
}
