import Foundation
@preconcurrency import NetworkExtension
import ReluxTunnelCore
import ReluxTunnelMacOSAdapter
import Testing

@Suite("Versioned non-secret SSH profile snapshot loader")
struct SSHProfileSnapshotLoaderTests {
  @Test("valid canonical DNS IPv4 IPv6 and IDNA A-label hosts round-trip")
  func validCanonicalHosts() throws {
    let hosts: [SSHProfileCanonicalHost] = [
      .init(kind: .dns, value: "example.com"),
      .init(kind: .dns, value: "xn--bcher-kva.example"),
      .init(kind: .ipv4, value: "192.0.2.10"),
      .init(kind: .ipv6, value: "2001:db8::1"),
      .init(kind: .ipv6, value: "::1"),
    ]

    for host in hosts {
      let snapshot = fixture(host: host)
      let data = try SSHProfileSnapshotCodec.encode(snapshot)
      let decoded = try SSHProfileSnapshotCodec.decode(data)
      #expect(decoded == snapshot)
      #expect(try SSHProfileSnapshotCodec.encode(decoded) == data)
    }
  }

  @Test("Unicode and noncanonical or malformed stored host names fail closed")
  func invalidHostNames() throws {
    let invalidHosts: [SSHProfileCanonicalHost] = [
      .init(kind: .dns, value: "bücher.example"),
      .init(kind: .dns, value: "Example.com"),
      .init(kind: .dns, value: "example.com."),
      .init(kind: .dns, value: "example..com"),
      .init(kind: .dns, value: "_ssh.example.com"),
      .init(kind: .dns, value: "192.168.001.1"),
      .init(kind: .dns, value: "999.999.999.999"),
      .init(kind: .dns, value: "ssh://example.com"),
      .init(kind: .dns, value: "example.com:22"),
      .init(kind: .ipv4, value: "192.168.001.1"),
      .init(kind: .ipv4, value: "192.0.2.1:22"),
      .init(kind: .ipv6, value: "2001:0DB8:0:0:0:0:0:1"),
      .init(kind: .ipv6, value: "[2001:db8::1]"),
      .init(kind: .ipv6, value: "fe80::1%en0"),
    ]

    for host in invalidHosts {
      #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.canonicalHost)) {
        try SSHProfileSnapshotCodec.encode(fixture(host: host))
      }
    }
  }

  @Test("ports account names timestamps IDs and generations validate exhaustively")
  func scalarFieldValidation() throws {
    let validData = try SSHProfileSnapshotCodec.encode(fixture())
    let maximumGeneration = fixture(generation: .max)
    #expect(
      try SSHProfileSnapshotCodec.decode(
        SSHProfileSnapshotCodec.encode(maximumGeneration)
      ) == maximumGeneration
    )

    for port: UInt64 in [0, 65_536] {
      let data = try mutateJSON(validData) { object in object["port"] = port }
      #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.port)) {
        try SSHProfileSnapshotCodec.decode(data)
      }
    }

    for account in ["", " account", "account\n", String(repeating: "a", count: 65)] {
      let data = try mutateJSON(validData) { object in object["account"] = account }
      #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.account)) {
        try SSHProfileSnapshotCodec.decode(data)
      }
    }

    let decomposedName = "Cafe\u{301}"
    let invalidDisplay = try mutateJSON(validData) { object in
      object["displayName"] = decomposedName
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.displayName)) {
      try SSHProfileSnapshotCodec.decode(invalidDisplay)
    }

    let zeroGeneration = try mutateJSON(validData) { object in
      object["configurationGeneration"] = 0
    }
    #expect(
      throws: SSHProfileSnapshotLoaderError.profileInvalidField(.configurationGeneration)
    ) {
      try SSHProfileSnapshotCodec.decode(zeroGeneration)
    }

    let uppercaseProfileID = try mutateJSON(validData) { object in
      object["profileID"] = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa".uppercased()
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.profileID)) {
      try SSHProfileSnapshotCodec.decode(uppercaseProfileID)
    }

    let zeroCredentialGeneration = try mutateJSON(validData) { object in
      var credential = try #require(object["credential"] as? [String: Any])
      credential["generation"] = 0
      object["credential"] = credential
    }
    #expect(
      throws: SSHProfileSnapshotLoaderError.profileInvalidField(.credentialGeneration)
    ) {
      try SSHProfileSnapshotCodec.decode(zeroCredentialGeneration)
    }

    let invalidTimestamp = try mutateJSON(validData) { object in
      object["updatedAt"] = "2026-08-11T10:00:00Z"
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.updatedAt)) {
      try SSHProfileSnapshotCodec.decode(invalidTimestamp)
    }
  }

  @Test("missing trust and credential structures are corrupt")
  func missingRequiredStructures() throws {
    let validData = try SSHProfileSnapshotCodec.encode(fixture())
    for key in ["credential", "hostPolicy"] {
      let data = try mutateJSON(validData) { object in object.removeValue(forKey: key) }
      #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
        try SSHProfileSnapshotCodec.decode(data)
      }
    }

    let missingCredentialReference = try mutateJSON(validData) { object in
      var credential = try #require(object["credential"] as? [String: Any])
      credential.removeValue(forKey: "ref")
      object["credential"] = credential
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileSnapshotCodec.decode(missingCredentialReference)
    }

    let missingRecords = try mutateJSON(validData) { object in
      var policy = try #require(object["hostPolicy"] as? [String: Any])
      policy.removeValue(forKey: "records")
      object["hostPolicy"] = policy
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileSnapshotCodec.decode(missingRecords)
    }
  }

  @Test("trust algorithms records fingerprints states and ordering fail closed")
  func trustRecordValidation() throws {
    let validData = try SSHProfileSnapshotCodec.encode(fixture())

    let reversedAlgorithms = try mutatePolicy(validData) { policy in
      policy["allowedAlgorithms"] = ["rsa-sha2-256", "ssh-ed25519"]
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.allowedAlgorithms)) {
      try SSHProfileSnapshotCodec.decode(reversedAlgorithms)
    }

    let duplicateAlgorithms = try mutatePolicy(validData) { policy in
      policy["allowedAlgorithms"] = ["ssh-ed25519", "ssh-ed25519"]
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.allowedAlgorithms)) {
      try SSHProfileSnapshotCodec.decode(duplicateAlgorithms)
    }

    let badFingerprint = try mutateFirstRecord(validData) { record in
      record["fingerprintSHA256"] = "SHA256:not-canonical"
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)) {
      try SSHProfileSnapshotCodec.decode(badFingerprint)
    }

    let unlistedAlgorithm = try mutateFirstRecord(validData) { record in
      record["algorithm"] = "ecdsa-sha2-nistp256"
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)) {
      try SSHProfileSnapshotCodec.decode(unlistedAlgorithm)
    }

    let revokedWithoutReason = try mutateFirstRecord(validData) { record in
      record["state"] = "revoked"
      record["revokedAt"] = "2026-08-11T10:00:02.000Z"
      record["revocationReason"] = NSNull()
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileInvalidField(.trustRecords)) {
      try SSHProfileSnapshotCodec.decode(revokedWithoutReason)
    }

    let missingNullableRecordField = try mutateFirstRecord(validData) { record in
      record.removeValue(forKey: "revokedAt")
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileSnapshotCodec.decode(missingNullableRecordField)
    }
  }

  @Test("UTF-8 corruption duplicates depth whitespace ordering and trailing bytes reject")
  func deterministicJSONValidation() throws {
    let validData = try SSHProfileSnapshotCodec.encode(fixture())

    let invalidUTF8 = Data([0x7B, 0x22, 0xFF, 0x22, 0x3A, 0x31, 0x7D])
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileSnapshotCodec.decode(invalidUTF8)
    }

    var duplicate = String(decoding: validData, as: UTF8.self)
    duplicate.insert(
      contentsOf: #""account":"other","#, at: duplicate.index(after: duplicate.startIndex))
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileSnapshotCodec.decode(Data(duplicate.utf8))
    }

    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileSnapshotCodec.decode(
        Data(" \(String(decoding: validData, as: UTF8.self))".utf8))
    }

    let trailing = validData + Data([UInt8(ascii: "x")])
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileSnapshotCodec.decode(trailing)
    }

    let excessive = try mutateJSON(validData) { object in
      object["future"] = [[[[[[[[true]]]]]]]]
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileSnapshotCodec.decode(excessive)
    }

    let noncanonicalNumber = Data(
      String(decoding: validData, as: UTF8.self)
        .replacingOccurrences(
          of: #""configurationGeneration":7"#,
          with: #""configurationGeneration":7e0"#
        ).utf8
    )
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileSnapshotCodec.decode(noncanonicalNumber)
    }

    let unsorted = Data(
      String(decoding: validData, as: UTF8.self)
        .replacingOccurrences(
          of: #""account":"fixture-account","canonicalHost"#,
          with: #""canonicalHost"#
        )
        .replacingOccurrences(
          of: #""value":"example.com"}"#,
          with: #""value":"example.com"},"account":"fixture-account""#
        ).utf8
    )
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileSnapshotCodec.decode(unsorted)
    }
  }

  @Test("canonical unknown fields are ignored and dropped when re-encoded")
  func unknownFieldCompatibility() throws {
    let canonical = try SSHProfileSnapshotCodec.encode(fixture())
    let withUnknown = try mutateJSON(canonical) { object in
      object["future"] = ["enabled": true, "version": 1]
    }
    let decoded = try SSHProfileSnapshotCodec.decode(withUnknown)
    #expect(try SSHProfileSnapshotCodec.encode(decoded) == canonical)
  }

  @Test("old future protocol schema and kind transitions are unsupported")
  func versionTransitions() throws {
    let validData = try SSHProfileSnapshotCodec.encode(fixture())
    for key in ["protocolVersion", "schemaVersion"] {
      for version in [0, 2] {
        let data = try mutateJSON(validData) { object in object[key] = version }
        #expect(throws: SSHProfileSnapshotLoaderError.profileVersionUnsupported) {
          try SSHProfileSnapshotCodec.decode(data)
        }
      }
    }
    let futureKind = try mutateJSON(validData) { object in
      object["kind"] = "sshProfileSnapshotV2"
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileVersionUnsupported) {
      try SSHProfileSnapshotCodec.decode(futureKind)
    }
  }

  @Test("recursive prohibited fields reject and secret bytes are unrepresentable")
  func prohibitedFieldsAndPrivacy() throws {
    let snapshot = fixture()
    let validData = try SSHProfileSnapshotCodec.encode(snapshot)
    let validText = String(decoding: validData, as: UTF8.self).lowercased()
    for prohibited in ["privatekey", "private_key", "passphrase", "password", "rawhostkey"] {
      #expect(!validText.contains(prohibited))
    }
    #expect(!containsData(snapshot))

    let prohibitedFixtures = [
      "privateKeyMaterial",
      "PASSWORD-VALUE",
      "passphraseBytes",
      "privateKeyData",
      "Seed.Bytes",
      "decrypted_private-key",
      "rawHostKeyData",
      "STAGING.CREDENTIAL_payload",
      "key-bytes-payload",
    ]
    for (index, field) in prohibitedFixtures.enumerated() {
      let data = try mutateJSON(validData) { object in
        switch index % 3 {
        case 0:
          object[field] = "redacted-fixture"
        case 1:
          object["future"] = ["nested": [field: "redacted-fixture"]]
        default:
          object["future"] = [["nested": [[field: "redacted-fixture"]]]]
        }
      }
      #expect(throws: SSHProfileSnapshotLoaderError.profileContainsProhibitedField) {
        try SSHProfileSnapshotCodec.decode(data)
      }
    }

    let error = SSHProfileSnapshotLoaderError.profileContainsProhibitedField
    #expect(
      String(reflecting: error)
        == "ReluxTunnelCore.SSHProfileSnapshotLoaderError.profileContainsProhibitedField")
  }

  @Test("providerConfiguration markers types extra keys and complete envelope are strict")
  func providerConfigurationEnvelope() throws {
    let snapshot = fixture()
    let configuration = try SSHProfileProviderConfigurationCodec.encode(snapshot)
    #expect(
      Set(configuration.keys) == [
        OwnedVPNManagerRepository.ownerKey,
        OwnedVPNManagerRepository.managerContractKey,
        OwnedVPNManagerRepository.configurationReferenceKey,
      ])
    #expect(
      try SSHProfileProviderConfigurationCodec.envelopeSize(configuration)
        <= SSHProfileProviderConfigurationCodec.maximumEnvelopeBytes
    )
    #expect(try SSHProfileProviderConfigurationCodec.decode(configuration) == snapshot)

    var wrongOwner = configuration
    wrongOwner[OwnedVPNManagerRepository.ownerKey] = .string("other")
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileProviderConfigurationCodec.decode(wrongOwner)
    }

    var wrongVersionType = configuration
    wrongVersionType[OwnedVPNManagerRepository.managerContractKey] = .unsignedInteger(1)
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileProviderConfigurationCodec.decode(wrongVersionType)
    }

    var futureManagerVersion = configuration
    futureManagerVersion[OwnedVPNManagerRepository.managerContractKey] = .integer(2)
    #expect(throws: SSHProfileSnapshotLoaderError.profileVersionUnsupported) {
      try SSHProfileProviderConfigurationCodec.decode(futureManagerVersion)
    }

    var extra = configuration
    extra["unexpected"] = .string("value")
    #expect(throws: SSHProfileSnapshotLoaderError.profileCorrupt) {
      try SSHProfileProviderConfigurationCodec.decode(extra)
    }

    let oversizedData = Data(repeating: UInt8(ascii: "x"), count: 4_000)
    var oversizedEnvelope = configuration
    oversizedEnvelope[OwnedVPNManagerRepository.configurationReferenceKey] = .data(oversizedData)
    #expect(oversizedData.count < SSHProfileProviderConfigurationCodec.maximumEnvelopeBytes)
    #expect(
      try SSHProfileProviderConfigurationCodec.envelopeSize(oversizedEnvelope)
        > SSHProfileProviderConfigurationCodec.maximumEnvelopeBytes
    )
    #expect(throws: SSHProfileSnapshotLoaderError.profileOversize) {
      try SSHProfileProviderConfigurationCodec.decode(oversizedEnvelope)
    }
  }

  @Test("one immutable generation rejects stale start requests and replacements")
  func immutableGenerationCapture() throws {
    let first = fixture(generation: 7)
    let firstConfiguration = try SSHProfileProviderConfigurationCodec.encode(first)
    let loader = SSHProfileRuntimeSnapshotLoader()
    let startRequest = try SSHProfileProviderConfigurationCodec.startRequest(
      for: firstConfiguration
    )

    let captured = try loader.capture(from: firstConfiguration, startRequest: startRequest)
    #expect(captured == first)
    #expect(try loader.capture(from: firstConfiguration, startRequest: startRequest) == captured)

    let staleRequest = RuntimeStartRequest(
      configurationGeneration: 8,
      snapshotDigestSHA256: startRequest.snapshotDigestSHA256
    )
    #expect(throws: SSHProfileSnapshotLoaderError.profileGenerationMismatch) {
      try SSHProfileRuntimeSnapshotLoader().capture(
        from: firstConfiguration,
        startRequest: staleRequest
      )
    }

    let newerConfiguration = try SSHProfileProviderConfigurationCodec.encode(
      fixture(generation: 8)
    )
    #expect(throws: SSHProfileSnapshotLoaderError.profileGenerationMismatch) {
      try loader.capture(from: newerConfiguration)
    }

    let sameGenerationReplacement = try SSHProfileProviderConfigurationCodec.encode(
      fixture(generation: 7, account: "changed-account")
    )
    #expect(throws: SSHProfileSnapshotLoaderError.profileGenerationMismatch) {
      try loader.capture(from: sameGenerationReplacement)
    }
    #expect(throws: SSHProfileSnapshotLoaderError.profileGenerationMismatch) {
      try SSHProfileRuntimeSnapshotLoader().capture(
        from: sameGenerationReplacement,
        startRequest: startRequest
      )
    }
  }

  @Test("concurrent replacement permits exactly one complete atomic capture")
  func concurrentCapture() async throws {
    let loader = SSHProfileRuntimeSnapshotLoader()
    let first = try SSHProfileProviderConfigurationCodec.encode(fixture(generation: 11))
    let second = try SSHProfileProviderConfigurationCodec.encode(fixture(generation: 12))

    let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
      for configuration in [first, second] {
        group.addTask {
          do {
            _ = try loader.capture(from: configuration)
            return true
          } catch SSHProfileSnapshotLoaderError.profileGenerationMismatch {
            return false
          } catch {
            return false
          }
        }
      }
      var values: [Bool] = []
      for await value in group { values.append(value) }
      return values
    }
    #expect(results.filter { $0 }.count == 1)
    #expect(results.filter { !$0 }.count == 1)
  }

  @Test("macOS adapter consumes NETunnelProviderProtocol providerConfiguration")
  func macOSProviderConfigurationIntegration() throws {
    let expected = fixture(generation: 19)
    let configuration = try SSHProfileProviderConfigurationCodec.encode(expected)
    let tunnelProtocol = NETunnelProviderProtocol()
    tunnelProtocol.providerConfiguration = configuration.compactMapValues(platformValue)
    let providerProtocol: NEVPNProtocol = tunnelProtocol

    let loader = MacOSSSHProfileSnapshotLoader()
    let captured = try loader.capture(
      from: providerProtocol,
      startRequest: SSHProfileProviderConfigurationCodec.startRequest(for: configuration)
    )
    #expect(captured == expected)
  }
}

private func fixture(
  generation: UInt64 = 7,
  account: String = "fixture-account",
  host: SSHProfileCanonicalHost = .init(kind: .dns, value: "example.com")
) -> SSHProfileSnapshotV1 {
  let digest = Data(repeating: 0x01, count: 32).base64EncodedString().dropLast()
  let record = SSHHostIdentityRecordV1(
    algorithm: .sshEd25519,
    fingerprintSHA256: SSHHostKeyFingerprint("SHA256:\(digest)"),
    state: .approved,
    provenance: .firstUseApproval,
    firstSeenAt: SSHProfileTimestamp("2026-08-11T10:00:00.000Z"),
    lastSeenAt: SSHProfileTimestamp("2026-08-11T10:00:01.000Z"),
    approvedAt: SSHProfileTimestamp("2026-08-11T10:00:01.000Z"),
    revokedAt: nil,
    revocationReason: nil
  )
  return SSHProfileSnapshotV1(
    configurationGeneration: generation,
    profileID: OpaqueProfileIdentifier(
      UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    ),
    createdAt: SSHProfileTimestamp("2026-08-11T09:00:00.000Z"),
    updatedAt: SSHProfileTimestamp("2026-08-11T10:00:01.000Z"),
    displayName: "Fixture Profile",
    canonicalHost: host,
    port: 22,
    account: account,
    credential: SSHProfileCredentialReferenceV1(
      reference: OpaqueCredentialReference(
        UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
      ),
      generation: 3
    ),
    hostPolicy: SSHHostPolicyV1(
      allowedAlgorithms: [.sshEd25519, .rsaSHA2256],
      records: [record]
    )
  )
}

private func mutateJSON(
  _ data: Data,
  mutation: (inout [String: Any]) throws -> Void
) throws -> Data {
  var object = try #require(
    JSONSerialization.jsonObject(with: data) as? [String: Any]
  )
  try mutation(&object)
  return try JSONSerialization.data(
    withJSONObject: object,
    options: [.sortedKeys, .withoutEscapingSlashes]
  )
}

private func mutatePolicy(
  _ data: Data,
  mutation: (inout [String: Any]) throws -> Void
) throws -> Data {
  try mutateJSON(data) { object in
    var policy = try #require(object["hostPolicy"] as? [String: Any])
    try mutation(&policy)
    object["hostPolicy"] = policy
  }
}

private func mutateFirstRecord(
  _ data: Data,
  mutation: (inout [String: Any]) throws -> Void
) throws -> Data {
  try mutatePolicy(data) { policy in
    var records = try #require(policy["records"] as? [[String: Any]])
    var first = try #require(records.first)
    try mutation(&first)
    records[0] = first
    policy["records"] = records
  }
}

private func containsData(_ value: Any) -> Bool {
  if value is Data { return true }
  return Mirror(reflecting: value).children.contains { containsData($0.value) }
}

private func platformValue(_ value: VPNProviderConfigurationValue) -> Any? {
  switch value {
  case .string(let value): value
  case .integer(let value): NSNumber(value: value)
  case .unsignedInteger(let value): NSNumber(value: value)
  case .data(let value): value
  case .unsupported: nil
  }
}
