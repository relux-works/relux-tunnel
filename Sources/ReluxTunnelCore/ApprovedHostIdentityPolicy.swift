import CryptoKit
import Foundation

/// The approved identity that may leave the raw host-key policy scope.
public struct SSHVerifiedHostIdentity: Equatable, Sendable, CustomStringConvertible,
  CustomDebugStringConvertible
{
  public let algorithm: String
  public let fingerprintSHA256: String

  public init(algorithm: String, fingerprintSHA256: String) {
    self.algorithm = algorithm
    self.fingerprintSHA256 = fingerprintSHA256
  }

  public var description: String { "SSHVerifiedHostIdentity(<redacted>)" }
  public var debugDescription: String { description }
}

/// Non-secret record state returned to the containing-app repository boundary.
/// It contains no host-key bytes, host, profile, credential, or endpoint value.
public struct SSHHostIdentityAuditMetadata: Equatable, Sendable, CustomStringConvertible,
  CustomDebugStringConvertible
{
  public let provenance: SSHHostIdentityProvenance
  public let firstSeenAt: SSHProfileTimestamp
  public let previousLastSeenAt: SSHProfileTimestamp
  public let observedAt: SSHProfileTimestamp

  public init(
    provenance: SSHHostIdentityProvenance,
    firstSeenAt: SSHProfileTimestamp,
    previousLastSeenAt: SSHProfileTimestamp,
    observedAt: SSHProfileTimestamp
  ) {
    self.provenance = provenance
    self.firstSeenAt = firstSeenAt
    self.previousLastSeenAt = previousLastSeenAt
    self.observedAt = observedAt
  }

  public var description: String { "SSHHostIdentityAuditMetadata(<redacted>)" }
  public var debugDescription: String { description }
}

/// Full first-use evidence for one explicit containing-app trust action.
/// This value is security-sensitive and deliberately redacts printable output.
public struct SSHHostTrustRequiredEvidence: Equatable, Sendable, CustomStringConvertible,
  CustomDebugStringConvertible
{
  public let canonicalHost: SSHProfileCanonicalHost
  public let port: UInt16
  public let algorithm: SSHHostKeyAlgorithm
  public let fingerprintSHA256: SSHHostKeyFingerprint
  public let observedAt: SSHProfileTimestamp

  public init(
    canonicalHost: SSHProfileCanonicalHost,
    port: UInt16,
    algorithm: SSHHostKeyAlgorithm,
    fingerprintSHA256: SSHHostKeyFingerprint,
    observedAt: SSHProfileTimestamp
  ) {
    self.canonicalHost = canonicalHost
    self.port = port
    self.algorithm = algorithm
    self.fingerprintSHA256 = fingerprintSHA256
    self.observedAt = observedAt
  }

  public var description: String { "SSHHostTrustRequiredEvidence(<redacted>)" }
  public var debugDescription: String { description }
}

/// An exact approved-record match. Record index is stable because validated
/// snapshots use deterministic algorithm/fingerprint ordering.
public struct SSHApprovedHostIdentityMatch: Equatable, Sendable, CustomStringConvertible,
  CustomDebugStringConvertible
{
  public let identity: SSHVerifiedHostIdentity
  public let trustRecordReference: SSHTrustRecordReference
  public let recordIndex: Int
  public let auditMetadata: SSHHostIdentityAuditMetadata

  public init(
    identity: SSHVerifiedHostIdentity,
    trustRecordReference: SSHTrustRecordReference,
    recordIndex: Int,
    auditMetadata: SSHHostIdentityAuditMetadata
  ) {
    self.identity = identity
    self.trustRecordReference = trustRecordReference
    self.recordIndex = recordIndex
    self.auditMetadata = auditMetadata
  }

  public var description: String { "SSHApprovedHostIdentityMatch(<redacted>)" }
  public var debugDescription: String { description }
}

public enum SSHApprovedHostIdentityPolicyError: Error, Equatable, Sendable {
  case invalidProfilePolicy
}

/// Mandatory snapshot-backed host identity policy for production SSH composition.
///
/// The policy has no accepting first-use mode. Only an exact approved tuple can
/// produce an acceptance; every other result stops before credential lookup.
public struct SSHApprovedHostIdentityPolicy: SSHHostKeyPolicy {
  private let canonicalHost: SSHProfileCanonicalHost
  private let port: UInt16
  private let allowedAlgorithms: [SSHHostKeyAlgorithm]
  private let records: [SSHHostIdentityRecordV1]
  private let adapterHostKeyAlgorithms: Set<String>
  private let now: @Sendable () -> Date

  public init(
    snapshot: SSHProfileSnapshotV1,
    adapterHostKeyAlgorithms: Set<String>
  ) throws {
    try self.init(
      snapshot: snapshot,
      adapterHostKeyAlgorithms: adapterHostKeyAlgorithms,
      now: { Date() }
    )
  }

  init(
    snapshot: SSHProfileSnapshotV1,
    adapterHostKeyAlgorithms: Set<String>,
    now: @escaping @Sendable () -> Date
  ) throws {
    guard Self.isCanonical(snapshot.hostPolicy.allowedAlgorithms),
      Self.hasCanonicalRecords(snapshot.hostPolicy.records)
    else {
      throw SSHApprovedHostIdentityPolicyError.invalidProfilePolicy
    }
    canonicalHost = snapshot.canonicalHost
    port = snapshot.port
    allowedAlgorithms = snapshot.hostPolicy.allowedAlgorithms
    records = snapshot.hostPolicy.records
    self.adapterHostKeyAlgorithms = adapterHostKeyAlgorithms
    self.now = now
  }

  public func evaluate(_ input: SSHHostKeyPolicyInput) async throws -> SSHHostKeyDecision {
    guard let algorithm = SSHHostKeyAlgorithm(rawValue: input.evidence.algorithm),
      allowedAlgorithms.contains(algorithm),
      adapterHostKeyAlgorithms.contains(algorithm.rawValue)
    else {
      return .rejectAlgorithm
    }

    guard input.canonicalHostname == canonicalHost.value,
      input.connectedEndpoint.port == port
    else {
      return .rejectHostMismatch
    }

    guard SSHWireHostKeyValidator.isValid(input.evidence.keyBytes, for: algorithm) else {
      return .rejectMalformed
    }

    let observedDigest = Data(SHA256.hash(data: input.evidence.keyBytes))
    let observedAt = Self.timestamp(now())
    let matchingRecords = records.enumerated().filter { _, record in
      guard record.algorithm == algorithm,
        let approvedDigest = Self.fingerprintDigest(record.fingerprintSHA256.rawValue)
      else { return false }
      return Self.constantTimeEqual(observedDigest, approvedDigest)
    }

    if let (_, record) = matchingRecords.first(where: { $0.element.state == .revoked }) {
      return .rejectRevoked(Self.auditMetadata(for: record, observedAt: observedAt))
    }

    if let (index, record) = matchingRecords.first(where: { $0.element.state == .approved }) {
      return .acceptApproved(
        SSHApprovedHostIdentityMatch(
          identity: SSHVerifiedHostIdentity(
            algorithm: algorithm.rawValue,
            fingerprintSHA256: input.evidence.fingerprint
          ),
          trustRecordReference: input.trustRecordReference
            ?? SSHTrustRecordReference(rawValue: "snapshot-record-\(index)"),
          recordIndex: index,
          auditMetadata: Self.auditMetadata(for: record, observedAt: observedAt)
        )
      )
    }

    guard records.isEmpty else { return .rejectChanged }
    return .trustRequired(
      SSHHostTrustRequiredEvidence(
        canonicalHost: canonicalHost,
        port: port,
        algorithm: algorithm,
        fingerprintSHA256: SSHHostKeyFingerprint(input.evidence.fingerprint),
        observedAt: observedAt
      )
    )
  }

  private static func auditMetadata(
    for record: SSHHostIdentityRecordV1,
    observedAt: SSHProfileTimestamp
  ) -> SSHHostIdentityAuditMetadata {
    SSHHostIdentityAuditMetadata(
      provenance: record.provenance,
      firstSeenAt: record.firstSeenAt,
      previousLastSeenAt: record.lastSeenAt,
      observedAt: observedAt
    )
  }

  private static func isCanonical(_ algorithms: [SSHHostKeyAlgorithm]) -> Bool {
    guard !algorithms.isEmpty else { return false }
    let indexes = algorithms.compactMap(SSHHostKeyAlgorithm.canonicalPreferenceOrder.firstIndex)
    return indexes.count == algorithms.count
      && zip(indexes, indexes.dropFirst()).allSatisfy(<)
  }

  private static func hasCanonicalRecords(_ records: [SSHHostIdentityRecordV1]) -> Bool {
    guard records.count <= 8,
      records.lazy.filter({ $0.state == .approved }).count <= 1
    else { return false }
    var tuples = Set<String>()
    var previous: (algorithm: String, digest: Data)?
    for record in records {
      guard let digest = fingerprintDigest(record.fingerprintSHA256.rawValue) else { return false }
      let tuple = "\(record.algorithm.rawValue)\u{0}\(digest.base64EncodedString())"
      guard tuples.insert(tuple).inserted else { return false }
      if let previous {
        let algorithmComparison = previous.algorithm.utf8.lexicographicallyPrecedes(
          record.algorithm.rawValue.utf8
        )
        let sameAlgorithm = previous.algorithm == record.algorithm.rawValue
        let digestComparison = previous.digest.lexicographicallyPrecedes(digest)
        guard algorithmComparison || (sameAlgorithm && digestComparison) else { return false }
      }
      previous = (record.algorithm.rawValue, digest)
    }
    return true
  }

  private static func fingerprintDigest(_ value: String) -> Data? {
    guard value.hasPrefix("SHA256:"), value.utf8.count == 50 else { return nil }
    let encoded = String(value.dropFirst(7))
    guard encoded.utf8.count == 43,
      let digest = Data(base64Encoded: encoded + "="), digest.count == 32,
      digest.base64EncodedString().dropLast() == encoded
    else { return nil }
    return digest
  }

  private static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
    let count = max(lhs.count, rhs.count)
    var difference = UInt64(lhs.count ^ rhs.count)
    for index in 0..<count {
      let left = index < lhs.count ? lhs[lhs.startIndex + index] : 0
      let right = index < rhs.count ? rhs[rhs.startIndex + index] : 0
      difference |= UInt64(left ^ right)
    }
    return difference == 0
  }

  private static func timestamp(_ date: Date) -> SSHProfileTimestamp {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return SSHProfileTimestamp(formatter.string(from: date))
  }
}

private enum SSHWireHostKeyValidator {
  static func isValid(_ bytes: Data, for algorithm: SSHHostKeyAlgorithm) -> Bool {
    var reader = SSHWireReader(bytes)
    guard let embeddedAlgorithm = reader.readString() else { return false }

    switch algorithm {
    case .sshEd25519:
      guard embeddedAlgorithm == Data(algorithm.rawValue.utf8),
        reader.readString()?.count == 32
      else { return false }
    case .ecdsaNISTP256:
      guard validateECDSA(&reader, algorithm: algorithm, curve: "nistp256", pointBytes: 65)
      else { return false }
    case .ecdsaNISTP384:
      guard validateECDSA(&reader, algorithm: algorithm, curve: "nistp384", pointBytes: 97)
      else { return false }
    case .ecdsaNISTP521:
      guard validateECDSA(&reader, algorithm: algorithm, curve: "nistp521", pointBytes: 133)
      else { return false }
    case .rsaSHA2512, .rsaSHA2256:
      guard embeddedAlgorithm == Data("ssh-rsa".utf8),
        let exponent = reader.readString(), isCanonicalPositiveMPInt(exponent),
        let modulus = reader.readString(), isCanonicalPositiveMPInt(modulus)
      else { return false }
    }
    return reader.isAtEnd
  }

  private static func validateECDSA(
    _ reader: inout SSHWireReader,
    algorithm: SSHHostKeyAlgorithm,
    curve: String,
    pointBytes: Int
  ) -> Bool {
    guard reader.consumedString == Data(algorithm.rawValue.utf8),
      reader.readString() == Data(curve.utf8),
      let point = reader.readString(), point.count == pointBytes,
      point.first == 0x04
    else { return false }
    return true
  }

  private static func isCanonicalPositiveMPInt(_ value: Data) -> Bool {
    guard !value.isEmpty, value.contains(where: { $0 != 0 }), value.first! & 0x80 == 0 else {
      return false
    }
    if value.count > 1, value.first == 0, value[value.startIndex + 1] & 0x80 == 0 {
      return false
    }
    return true
  }
}

private struct SSHWireReader {
  private let bytes: Data
  private var offset = 0
  private(set) var consumedString: Data?

  init(_ bytes: Data) {
    self.bytes = bytes
  }

  var isAtEnd: Bool { offset == bytes.count }

  mutating func readString() -> Data? {
    guard bytes.count - offset >= 4 else { return nil }
    let length = bytes[offset..<(offset + 4)].reduce(UInt32(0)) { value, byte in
      (value << 8) | UInt32(byte)
    }
    offset += 4
    guard let count = Int(exactly: length), count <= bytes.count - offset else { return nil }
    let value = Data(bytes[offset..<(offset + count)])
    offset += count
    consumedString = value
    return value
  }
}
