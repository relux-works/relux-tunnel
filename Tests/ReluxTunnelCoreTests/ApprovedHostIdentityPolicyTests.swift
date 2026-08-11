import CryptoKit
import Foundation
import ReluxTunnelCore
import ReluxTunnelMacOSAdapter
import Testing

@testable import ReluxTunnelCore

@Suite("Mandatory approved host identity policy")
struct ApprovedHostIdentityPolicyTests {
  private let observedDate = Date(timeIntervalSince1970: 1_786_447_200)

  @Test("first use returns full trust evidence and cannot authenticate")
  func firstUseRequiresExplicitTrust() async throws {
    let key = ed25519WireKey(repeating: 0x11)
    let policy = try fixturePolicy(records: [])
    let input = try fixtureInput(keyBytes: key)

    let decision = try await policy.evaluate(input)
    guard case .trustRequired(let evidence) = decision else {
      Issue.record("first use did not return trust-required evidence")
      return
    }
    #expect(evidence.canonicalHost == SSHProfileCanonicalHost(kind: .dns, value: "fixture.invalid"))
    #expect(evidence.port == 22)
    #expect(evidence.algorithm == .sshEd25519)
    #expect(evidence.fingerprintSHA256.rawValue == SSHHostKeyEvidence.sha256Fingerprint(for: key))
    #expect(evidence.observedAt == SSHProfileTimestamp("2026-08-11T11:20:00.000Z"))
    #expect(throws: SSHHostAcceptanceError.rejected(.trustRequired)) {
      _ = try decision.acceptance(for: input)
    }

    let error = try #require(SSHTransportError.hostDecisionFailure(decision, lane: input.lane))
    #expect(error.code == .hostTrustRequired)
    #expect(error.retryDisposition == .afterConfigurationChange)
    #expect(error.requiresTeardown)
  }

  @Test("same key matches while same bytes with an invalid label are unsupported")
  func exactTupleIncludesReviewedAlgorithm() async throws {
    let key = ed25519WireKey(repeating: 0x22)
    let record = approvedRecord(keyBytes: key, provenance: .firstUseApproval)
    let policy = try fixturePolicy(records: [record])

    let acceptedInput = try fixtureInput(keyBytes: key)
    let accepted = try await policy.evaluate(acceptedInput)
    guard case .acceptApproved(let match) = accepted else {
      Issue.record("approved tuple did not match")
      return
    }
    #expect(match.identity.algorithm == SSHHostKeyAlgorithm.sshEd25519.rawValue)
    #expect(match.identity.fingerprintSHA256 == record.fingerprintSHA256.rawValue)
    #expect(match.auditMetadata.provenance == .firstUseApproval)
    #expect(match.auditMetadata.firstSeenAt == record.firstSeenAt)
    #expect(match.auditMetadata.previousLastSeenAt == record.lastSeenAt)
    #expect(match.auditMetadata.observedAt == SSHProfileTimestamp("2026-08-11T11:20:00.000Z"))
    #expect(try accepted.acceptance(for: acceptedInput).identity == match.identity)

    let invalidLabel = try fixtureInput(algorithm: "SSH-ED25519", keyBytes: key)
    #expect(try await policy.evaluate(invalidLabel) == .rejectAlgorithm)
  }

  @Test("different changed and exact revoked keys fail with terminal classifications")
  func changedAndRevoked() async throws {
    let approvedKey = ed25519WireKey(repeating: 0x31)
    let changedKey = ed25519WireKey(repeating: 0x32)
    let changedPolicy = try fixturePolicy(records: [approvedRecord(keyBytes: approvedKey)])
    let changedDecision = try await changedPolicy.evaluate(
      fixtureInput(keyBytes: changedKey)
    )
    #expect(changedDecision == .rejectChanged)
    let changedError = try #require(
      SSHTransportError.hostDecisionFailure(
        changedDecision,
        lane: fixtureInput(keyBytes: changedKey).lane
      )
    )
    #expect(changedError.code == .hostKeyChanged)
    #expect(changedError.retryDisposition == .afterConfigurationChange)

    let revoked = revokedRecord(keyBytes: approvedKey)
    let revokedPolicy = try fixturePolicy(records: [revoked])
    let revokedDecision = try await revokedPolicy.evaluate(
      fixtureInput(keyBytes: approvedKey)
    )
    guard case .rejectRevoked(let metadata) = revokedDecision else {
      Issue.record("revoked tuple was not rejected as revoked")
      return
    }
    #expect(metadata.provenance == .changedKeyReplacement)
    let revokedError = try #require(
      SSHTransportError.hostDecisionFailure(
        revokedDecision,
        lane: fixtureInput(keyBytes: approvedKey).lane
      )
    )
    #expect(revokedError.code == .hostIdentityRevoked)
    #expect(revokedError.retryDisposition == .afterConfigurationChange)
  }

  @Test("malformed wire keys fail before fingerprint approval")
  func malformedKey() async throws {
    let malformed = wireString("ssh-ed25519") + wireString(Data(repeating: 0x41, count: 31))
    let policy = try fixturePolicy(records: [approvedRecord(keyBytes: malformed)])
    #expect(try await policy.evaluate(fixtureInput(keyBytes: malformed)) == .rejectMalformed)

    let error = try #require(
      SSHTransportError.hostDecisionFailure(
        .rejectMalformed,
        lane: fixtureInput(keyBytes: malformed).lane
      )
    )
    #expect(error.code == .hostKeyMalformed)
    #expect(error.retryDisposition == .afterConfigurationChange)
  }

  @Test("sequential rotation preserves ordered history with one active approval")
  func sequentialRotationHistory() async throws {
    let firstKey = ed25519WireKey(repeating: 0x51)
    let secondKey = ed25519WireKey(repeating: 0x52)

    let firstGeneration = fixtureSnapshot(
      generation: 7,
      records: [approvedRecord(keyBytes: firstKey, provenance: .firstUseApproval)]
    )
    let decodedFirstGeneration = try SSHProfileSnapshotCodec.decode(
      SSHProfileSnapshotCodec.encode(firstGeneration)
    )
    #expect(decodedFirstGeneration.configurationGeneration == 7)
    #expect(decodedFirstGeneration.hostPolicy.records.count == 1)
    #expect(decodedFirstGeneration.hostPolicy.records[0].state == .approved)

    let replacementRecords = canonicalRecords([
      revokedRecord(keyBytes: firstKey),
      approvedRecord(keyBytes: secondKey, provenance: .changedKeyReplacement),
    ])
    let replacementGeneration = fixtureSnapshot(
      generation: 8,
      records: replacementRecords
    )
    let decodedReplacement = try SSHProfileSnapshotCodec.decode(
      SSHProfileSnapshotCodec.encode(replacementGeneration)
    )
    #expect(decodedReplacement.configurationGeneration == 8)
    #expect(decodedReplacement.hostPolicy.records.count == 2)
    #expect(decodedReplacement.hostPolicy.records.filter { $0.state == .approved }.count == 1)
    #expect(decodedReplacement.hostPolicy.records.filter { $0.state == .revoked }.count == 1)

    let firstDecision = try await fixturePolicy(records: replacementRecords).evaluate(
      fixtureInput(keyBytes: firstKey)
    )
    guard case .rejectRevoked = firstDecision else {
      Issue.record("historical rotation key was not retained as revoked")
      return
    }

    let policy = try fixturePolicy(records: replacementRecords)
    let decision = try await policy.evaluate(fixtureInput(keyBytes: secondKey))
    guard case .acceptApproved(let match) = decision else {
      Issue.record("rotation key was not approved")
      return
    }
    let expectedIndex = try #require(
      replacementRecords.firstIndex {
        $0.fingerprintSHA256.rawValue == match.identity.fingerprintSHA256
      }
    )
    #expect(match.recordIndex == expectedIndex)
    #expect(match.auditMetadata.provenance == .changedKeyReplacement)

    #expect(throws: SSHApprovedHostIdentityPolicyError.invalidProfilePolicy) {
      try fixturePolicy(records: [
        approvedRecord(keyBytes: firstKey),
        approvedRecord(keyBytes: secondKey, provenance: .changedKeyReplacement),
      ])
    }
  }

  @Test("canonical host and port are bound before approval")
  func canonicalHostMismatch() async throws {
    let key = ed25519WireKey(repeating: 0x61)
    let policy = try fixturePolicy(records: [approvedRecord(keyBytes: key)])
    #expect(
      try await policy.evaluate(
        fixtureInput(canonicalHostname: "other.invalid", keyBytes: key)
      ) == .rejectHostMismatch
    )
    #expect(
      try await policy.evaluate(
        fixtureInput(endpointPort: 23, keyBytes: key)
      ) == .rejectHostMismatch
    )
  }

  @Test("unsupported algorithms precede host and record evaluation")
  func unsupportedAlgorithmPrecedence() async throws {
    let key = ed25519WireKey(repeating: 0x71)
    let policy = try fixturePolicy(
      records: [approvedRecord(keyBytes: key)],
      adapterAlgorithms: []
    )
    let input = try fixtureInput(canonicalHostname: "other.invalid", keyBytes: key)
    #expect(try await policy.evaluate(input) == .rejectAlgorithm)
  }

  @Test("production composition always builds the snapshot-backed mandatory policy")
  func productionCompositionHasNoFirstUseBypass() async throws {
    let snapshot = fixtureSnapshot(records: [])
    let policy = try MacOSProviderSSHConfiguration.makeHostKeyPolicy(snapshot: snapshot)
    let input = try fixtureInput(keyBytes: ed25519WireKey(repeating: 0x81))
    let decision = try await policy.evaluate(input)
    #expect(decision.outcome == .trustRequired)
  }

  @Test("raw key host fingerprint and timestamps are redacted from printable values")
  func loggingRedaction() async throws {
    let key = ed25519WireKey(repeating: 0x91)
    let input = try fixtureInput(keyBytes: key)
    let decision = try await fixturePolicy(records: []).evaluate(input)
    let approvedDecision = try await fixturePolicy(
      records: [approvedRecord(keyBytes: key)]
    ).evaluate(input)
    let acceptance = try approvedDecision.acceptance(for: input)
    let credentialRequest = SSHCredentialRequest(
      credentialReference: SSHCredentialReference(rawValue: "credential-fixture"),
      credentialGeneration: 1,
      username: "account-fixture",
      allowedPublicKeyAlgorithms: [SSHHostKeyAlgorithm.sshEd25519.rawValue],
      acceptedHost: acceptance
    )
    let rendered = [
      String(describing: input.evidence),
      String(reflecting: input),
      String(reflecting: decision),
      String(reflecting: acceptance),
      String(reflecting: credentialRequest),
    ].joined(separator: " ")

    #expect(!rendered.contains("fixture.invalid"))
    #expect(!rendered.contains(input.evidence.fingerprint))
    #expect(!rendered.contains(key.base64EncodedString()))
    #expect(!rendered.contains("2026-08-11"))
    #expect(rendered.contains("<redacted>"))
  }

  private func fixturePolicy(
    records: [SSHHostIdentityRecordV1],
    adapterAlgorithms: Set<String> = [SSHHostKeyAlgorithm.sshEd25519.rawValue]
  ) throws -> SSHApprovedHostIdentityPolicy {
    try SSHApprovedHostIdentityPolicy(
      snapshot: fixtureSnapshot(records: canonicalRecords(records)),
      adapterHostKeyAlgorithms: adapterAlgorithms,
      now: { observedDate }
    )
  }

  private func fixtureInput(
    canonicalHostname: String = "fixture.invalid",
    endpointPort: UInt16 = 22,
    algorithm: String = SSHHostKeyAlgorithm.sshEd25519.rawValue,
    keyBytes: Data
  ) throws -> SSHHostKeyPolicyInput {
    SSHHostKeyPolicyInput(
      canonicalHostname: canonicalHostname,
      connectedEndpoint: TunnelEndpoint(host: "192.0.2.1", port: endpointPort),
      evidence: try SSHHostKeyEvidence(algorithm: algorithm, keyBytes: keyBytes),
      lane: SSHLaneIdentity(
        rawValue: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
      ),
      trustRecordReference: nil
    )
  }
}

private func fixtureSnapshot(
  generation: UInt64 = 7,
  records: [SSHHostIdentityRecordV1]
) -> SSHProfileSnapshotV1 {
  SSHProfileSnapshotV1(
    configurationGeneration: generation,
    profileID: OpaqueProfileIdentifier(
      UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    ),
    createdAt: SSHProfileTimestamp("2026-08-11T10:00:00.000Z"),
    updatedAt: SSHProfileTimestamp("2026-08-11T10:00:01.000Z"),
    displayName: "Fixture",
    canonicalHost: SSHProfileCanonicalHost(kind: .dns, value: "fixture.invalid"),
    port: 22,
    account: "fixture-account",
    credential: SSHProfileCredentialReferenceV1(
      reference: OpaqueCredentialReference(
        UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
      ),
      generation: 3
    ),
    hostPolicy: SSHHostPolicyV1(
      allowedAlgorithms: [.sshEd25519],
      records: records
    )
  )
}

private func approvedRecord(
  keyBytes: Data,
  provenance: SSHHostIdentityProvenance = .firstUseApproval
) -> SSHHostIdentityRecordV1 {
  SSHHostIdentityRecordV1(
    algorithm: .sshEd25519,
    fingerprintSHA256: SSHHostKeyFingerprint(
      SSHHostKeyEvidence.sha256Fingerprint(for: keyBytes)
    ),
    state: .approved,
    provenance: provenance,
    firstSeenAt: SSHProfileTimestamp("2026-08-10T10:00:00.000Z"),
    lastSeenAt: SSHProfileTimestamp("2026-08-10T11:00:00.000Z"),
    approvedAt: SSHProfileTimestamp("2026-08-10T10:01:00.000Z"),
    revokedAt: nil,
    revocationReason: nil
  )
}

private func revokedRecord(keyBytes: Data) -> SSHHostIdentityRecordV1 {
  SSHHostIdentityRecordV1(
    algorithm: .sshEd25519,
    fingerprintSHA256: SSHHostKeyFingerprint(
      SSHHostKeyEvidence.sha256Fingerprint(for: keyBytes)
    ),
    state: .revoked,
    provenance: .changedKeyReplacement,
    firstSeenAt: SSHProfileTimestamp("2026-08-09T10:00:00.000Z"),
    lastSeenAt: SSHProfileTimestamp("2026-08-09T11:00:00.000Z"),
    approvedAt: SSHProfileTimestamp("2026-08-09T10:01:00.000Z"),
    revokedAt: SSHProfileTimestamp("2026-08-10T10:00:00.000Z"),
    revocationReason: .replaced
  )
}

private func canonicalRecords(
  _ records: [SSHHostIdentityRecordV1]
) -> [SSHHostIdentityRecordV1] {
  records.sorted { lhs, rhs in
    if lhs.algorithm.rawValue != rhs.algorithm.rawValue {
      return lhs.algorithm.rawValue.utf8.lexicographicallyPrecedes(rhs.algorithm.rawValue.utf8)
    }
    return fingerprintDigest(lhs.fingerprintSHA256.rawValue).lexicographicallyPrecedes(
      fingerprintDigest(rhs.fingerprintSHA256.rawValue)
    )
  }
}

private func fingerprintDigest(_ value: String) -> Data {
  Data(base64Encoded: String(value.dropFirst(7)) + "=")!
}

private func ed25519WireKey(repeating byte: UInt8) -> Data {
  wireString("ssh-ed25519") + wireString(Data(repeating: byte, count: 32))
}

private func wireString(_ value: String) -> Data {
  wireString(Data(value.utf8))
}

private func wireString(_ value: Data) -> Data {
  var length = UInt32(value.count).bigEndian
  return withUnsafeBytes(of: &length) { Data($0) } + value
}
