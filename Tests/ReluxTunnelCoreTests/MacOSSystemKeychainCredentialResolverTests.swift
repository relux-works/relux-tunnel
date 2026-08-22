import CryptoKit
import Foundation
import Network
import ReluxTunnelCore
import Security
import Testing

@testable import ReluxTunnelMacOSAdapter

@Suite("macOS system-domain Keychain credential resolver")
struct MacOSSystemKeychainCredentialResolverTests {
  @Test("exact opaque reference and fixed service shape the only lookup")
  func exactQueryShapeAndSuccess() async throws {
    let reference = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    let handle = fixtureKeychainHandle()
    let security = FixtureSystemKeychainClient(
      keychain: handle,
      item: fixtureItem(reference: reference, generation: 7, format: 1)
    )
    let provider = MacOSProviderSSHConfiguration.makeCredentialProvider(
      securityClient: security,
      formatRegistry: FixtureFormatRegistry()
    )

    let credential = try await provider.credential(for: try request(reference, generation: 7))
    #expect(credential.algorithm == "ssh-ed25519")
    #expect(try await credential.sign(Data([1, 2, 3])) == Data([3, 2, 1]))

    let query = try #require(await security.recordedQuery())
    let dictionary = query.dictionary
    #expect(query.keychain === handle)
    #expect(query.service == MacOSSystemKeychainCredentialResolver.service)
    #expect(query.account == reference.uuidString.lowercased())
    #expect(dictionary[kSecClass as String] as? String == kSecClassGenericPassword as String)
    #expect(dictionary[kSecAttrService as String] as? String == Self.service)
    #expect(dictionary[kSecAttrAccount as String] as? String == reference.uuidString.lowercased())
    #expect(dictionary[kSecUseDataProtectionKeychain as String] as? Bool == false)
    #expect((dictionary[kSecMatchSearchList as String] as? [AnyObject])?.count == 1)
    #expect(dictionary[kSecMatchLimit as String] as? String == kSecMatchLimitOne as String)
    #expect(dictionary[kSecReturnAttributes as String] as? Bool == true)
    #expect(dictionary[kSecReturnData as String] as? Bool == true)
    #expect(dictionary[kSecUseKeychain as String] == nil)
    #expect(dictionary[kSecAttrAccessGroup as String] == nil)
    #expect(dictionary[kSecAttrAccessible as String] == nil)
    #expect(Set(dictionary.keys) == Self.expectedQueryKeys)
  }

  @Test("wrong class and mismatched identity fail distinctly")
  func identityAndClassValidation() async throws {
    let reference = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    let handle = fixtureKeychainHandle()

    let wrongClass = FixtureSystemKeychainClient(
      keychain: handle,
      item: fixtureItem(
        reference: reference,
        generation: 2,
        itemClass: kSecClassInternetPassword as String
      )
    )
    await #expect(throws: MacOSCredentialResolverError.credentialWrongClass) {
      try await resolver(security: wrongClass).credential(for: request(reference, generation: 2))
    }

    let wrongIdentity = FixtureSystemKeychainClient(
      keychain: handle,
      item: fixtureItem(reference: reference, generation: 2, account: "not-the-reference")
    )
    await #expect(throws: MacOSCredentialResolverError.credentialMalformed) {
      try await resolver(security: wrongIdentity).credential(for: request(reference, generation: 2))
    }
  }

  @Test("not found inaccessible malformed and platform cancellation remain distinct")
  func statusMapping() async throws {
    let reference = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
    let handle = fixtureKeychainHandle()
    let cases: [(OSStatus, MacOSCredentialResolverError)] = [
      (errSecItemNotFound, .credentialNotProvisioned),
      (errSecAuthFailed, .credentialAccessDenied),
      (errSecDecode, .credentialMalformed),
      (errSecUserCanceled, .operationCancelled),
    ]

    for (status, expected) in cases {
      let security = FixtureSystemKeychainClient(keychain: handle, status: status)
      await #expect(throws: expected) {
        try await resolver(security: security).credential(
          for: request(reference, generation: 1)
        )
      }
    }
  }

  @Test("OSStatus bootstrap projection is stable and contains no platform status")
  func osStatusBootstrapProjection() {
    let cases: [(OSStatus, Bool, SSHBootstrapErrorCode, SSHBootstrapRetryDisposition)] = [
      (errSecItemNotFound, true, .credentialNotProvisioned, .terminal),
      (errSecAuthFailed, true, .credentialAccessDenied, .terminal),
      (errSecDecode, true, .credentialMalformed, .terminal),
      (errSecUserCanceled, true, .operationCancelled, .cancelled),
    ]

    for (status, itemLookup, code, retry) in cases {
      let error = MacOSSSHBootstrapErrorMapper.credential(
        status: status,
        itemLookup: itemLookup,
        configurationGeneration: 12
      )
      #expect(error.diagnostic.code == code)
      #expect(error.diagnostic.retryDisposition == retry)
      #expect(error.diagnostic.configurationGeneration == 12)
      #expect(
        !(error as NSError).userInfo.values.contains { String(describing: $0) == "\(status)" })
    }
  }

  @Test("every credential resolver error has one bounded bootstrap projection")
  func credentialBootstrapProjectionCoverage() {
    let cases: [(MacOSCredentialResolverError, SSHBootstrapErrorCode)] = [
      (.credentialNotProvisioned, .credentialNotProvisioned),
      (.credentialAccessDenied, .credentialAccessDenied),
      (.credentialWrongClass, .credentialMalformed),
      (.credentialGenerationMismatch, .credentialGenerationMismatch),
      (.credentialMalformed, .credentialMalformed),
      (.credentialPassphraseRequired, .credentialPassphraseRequired),
      (.credentialPassphraseInvalid, .credentialPassphraseInvalid),
      (.credentialKeyUnsupported, .credentialKeyUnsupported),
      (.operationCancelled, .operationCancelled),
    ]

    #expect(Set(cases.map(\.0)) == Set(MacOSCredentialResolverError.allCases))
    for (source, expectedCode) in cases {
      let error = MacOSSSHBootstrapErrorMapper.credential(
        source,
        configurationGeneration: 13
      )
      #expect(error.diagnostic.code == expectedCode)
      #expect(error.diagnostic.configurationGeneration == 13)
      #expect(
        error.diagnostic.retryDisposition
          == (source == .operationCancelled ? .cancelled : .terminal)
      )
    }
  }

  @Test("NW and POSIX classes map without endpoint or underlying prose")
  func networkFrameworkBootstrapProjection() {
    let context = SSHBootstrapDiagnosticContext(endpointFamily: .ipv6)
    let unavailable = MacOSSSHBootstrapErrorMapper.network(
      NWError.posix(.ENETUNREACH),
      stage: .physicalPathResolution,
      configurationGeneration: 5,
      context: context
    )
    let reset = MacOSSSHBootstrapErrorMapper.network(
      NWError.posix(.ECONNRESET),
      stage: .endpointConnect,
      configurationGeneration: 5,
      context: context
    )
    let dns = MacOSSSHBootstrapErrorMapper.network(
      NWError.dns(-65_537),
      stage: .endpointConnect,
      configurationGeneration: 5,
      context: context
    )
    let tls = MacOSSSHBootstrapErrorMapper.network(
      NWError.tls(-9_800),
      stage: .algorithmNegotiation,
      configurationGeneration: 5,
      context: context
    )

    #expect(unavailable.diagnostic.code == .pathUnavailable)
    #expect(unavailable.diagnostic.retryDisposition == .retryableLater)
    #expect(reset.diagnostic.code == .endpointConnectFailed)
    #expect(reset.diagnostic.retryDisposition == .retryableLater)
    #expect(reset.diagnostic.context.endpointFamily == .ipv6)
    #expect(dns.diagnostic.code == .endpointConnectFailed)
    #expect(dns.diagnostic.retryDisposition == .retryableLater)
    #expect(tls.diagnostic.code == .negotiationFailed)
    #expect(tls.diagnostic.retryDisposition == .terminal)
  }

  @Test("record generation digest truncation and trailing bytes fail closed")
  func strictRecordFormat() async throws {
    let reference = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    let handle = fixtureKeychainHandle()
    var records = [
      credentialRecord(reference: reference, generation: 7, format: 1),
      credentialRecord(reference: reference, generation: 7, format: 1) + [0],
    ]
    records[0][records[0].count - 1] ^= 0xFF

    for record in records {
      let security = FixtureSystemKeychainClient(
        keychain: handle,
        item: fixtureItem(reference: reference, generation: 7, data: record)
      )
      await #expect(throws: MacOSCredentialResolverError.credentialMalformed) {
        try await resolver(security: security).credential(
          for: request(reference, generation: 7)
        )
      }
    }

    let generationMismatch = FixtureSystemKeychainClient(
      keychain: handle,
      item: fixtureItem(reference: reference, generation: 8)
    )
    await #expect(throws: MacOSCredentialResolverError.credentialGenerationMismatch) {
      try await resolver(security: generationMismatch).credential(
        for: request(reference, generation: 7)
      )
    }
  }

  @Test(
    "imported and generated registry representations produce libssh2 credentials",
    arguments: [UInt16(1), UInt16(2)]
  )
  func importedAndGeneratedRepresentations(format: UInt16) async throws {
    let reference = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
    let security = FixtureSystemKeychainClient(
      keychain: fixtureKeychainHandle(),
      item: fixtureItem(reference: reference, generation: 3, format: format)
    )
    let credential = try await resolver(security: security).credential(
      for: request(reference, generation: 3)
    )
    #expect(["ssh-ed25519", "ecdsa-sha2-nistp256"].contains(credential.algorithm))
  }

  @Test(
    "optional passphrase preserves absent empty and present states",
    arguments: [
      PassphraseCase(bytes: nil, expectedCount: nil, label: "absent"),
      PassphraseCase(bytes: [], expectedCount: 0, label: "empty"),
      PassphraseCase(bytes: [7, 8], expectedCount: 2, label: "present"),
    ]
  )
  func optionalPassphrase(testCase: PassphraseCase) async throws {
    let reference = UUID(uuidString: "abababab-abab-abab-abab-abababababab")!
    let registry = PassphraseObservingRegistry()
    let security = FixtureSystemKeychainClient(
      keychain: fixtureKeychainHandle(),
      item: fixtureItem(
        reference: reference,
        generation: 9,
        passphrase: testCase.bytes
      )
    )
    _ = try await MacOSSystemKeychainCredentialResolver(
      securityClient: security,
      formatRegistry: registry
    ).credential(for: request(reference, generation: 9))
    #expect(registry.observedCount == testCase.expectedCount)
  }

  @Test(
    "passphrase and key-format outcomes stay stable",
    arguments: [
      FormatFailureCase(error: .passphraseRequired, expected: .credentialPassphraseRequired),
      FormatFailureCase(error: .passphraseInvalid, expected: .credentialPassphraseInvalid),
      FormatFailureCase(error: .unsupportedKey, expected: .credentialKeyUnsupported),
      FormatFailureCase(error: .malformed, expected: .credentialMalformed),
    ]
  )
  func formatErrors(testCase: FormatFailureCase) async throws {
    let reference = UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
    let security = FixtureSystemKeychainClient(
      keychain: fixtureKeychainHandle(),
      item: fixtureItem(reference: reference, generation: 4, format: 9, passphrase: [4, 5])
    )
    await #expect(throws: testCase.expected) {
      try await MacOSSystemKeychainCredentialResolver(
        securityClient: security,
        formatRegistry: FixtureFormatRegistry(failure: testCase.error)
      ).credential(for: request(reference, generation: 4))
    }
  }

  @Test("cancellation after a Security call clears and releases returned bytes")
  func cancellationClearsReturnedSecret() async throws {
    let reference = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    let lifecycle = SecretLifecycleProbe()
    let gate = ResolverTestGate()
    let item = fixtureItem(
      reference: reference,
      generation: 5,
      observer: lifecycle
    )
    let security = FixtureSystemKeychainClient(
      keychain: fixtureKeychainHandle(),
      item: item,
      gate: gate
    )
    let candidate = MacOSSystemKeychainCredentialResolver(
      securityClient: security,
      formatRegistry: FixtureFormatRegistry(),
      lifecycleObserver: lifecycle
    )
    let task = Task {
      try await candidate.credential(for: request(reference, generation: 5))
    }
    await gate.waitUntilEntered()
    task.cancel()
    await gate.open()

    await #expect(throws: MacOSCredentialResolverError.operationCancelled) {
      try await task.value
    }
    #expect(lifecycle.activeSecretCount == 0)
    #expect(lifecycle.clearedSecretCount == 1)
    #expect(item.secretData.count == 0)
  }

  @Test("decoded buffers clear before return and signer retirement releases parsed state")
  func boundedCredentialLifetime() async throws {
    let reference = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
    let lifecycle = SecretLifecycleProbe()
    let retirement = RetirementProbe()
    let security = FixtureSystemKeychainClient(
      keychain: fixtureKeychainHandle(),
      item: fixtureItem(reference: reference, generation: 10, passphrase: [1])
    )
    let credential = try await MacOSSystemKeychainCredentialResolver(
      securityClient: security,
      formatRegistry: RetiringFormatRegistry(probe: retirement),
      lifecycleObserver: lifecycle
    ).credential(for: request(reference, generation: 10))

    #expect(lifecycle.activeSecretCount == 0)
    #expect(lifecycle.clearedSecretCount == 2)
    #expect(!retirement.isRetired)
    credential.retire()
    #expect(retirement.isRetired)
  }

  @Test("errors and credential reflection are redacted")
  func redaction() async throws {
    let referenceText = "99999999-8888-7777-6666-555555555555"
    let reference = UUID(uuidString: referenceText)!
    let marker = "fixture-sensitive-marker"
    let security = FixtureSystemKeychainClient(
      keychain: fixtureKeychainHandle(),
      item: fixtureItem(
        reference: reference,
        generation: 1,
        data: Array(marker.utf8)
      )
    )
    let error = await #expect(throws: MacOSCredentialResolverError.self) {
      try await resolver(security: security).credential(for: request(reference, generation: 1))
    }
    let rendered = String(describing: error)
    #expect(!rendered.contains(referenceText))
    #expect(!rendered.contains(marker))

    let success = FixtureSystemKeychainClient(
      keychain: fixtureKeychainHandle(),
      item: fixtureItem(reference: reference, generation: 1)
    )
    let credential = try await resolver(security: success).credential(
      for: request(reference, generation: 1)
    )
    let reflected = String(reflecting: credential)
    #expect(reflected.contains("redacted"))
    #expect(!reflected.contains(referenceText))
    #expect(!reflected.contains(marker))
  }

  @Test("one fake-only scoped query performs no enumeration or fallback")
  func scopedQueryHasNoEnumerationOrFallback() async throws {
    let reference = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!
    let handle = fixtureKeychainHandle()
    let security = FixtureSystemKeychainClient(
      keychain: handle,
      status: errSecItemNotFound
    )
    await #expect(throws: MacOSCredentialResolverError.credentialNotProvisioned) {
      try await resolver(security: security).credential(
        for: request(reference, generation: 6)
      )
    }
    #expect(await security.domainResolutionCount() == 1)
    #expect(await security.matchingQueryCount() == 1)
    let query = try #require(await security.recordedQuery())
    #expect(query.keychain === handle)
    #expect(query.account == reference.uuidString.lowercased())
    #expect(query.service == Self.service)
  }

  @Test("live client rejects fixture query before the Security matcher")
  func liveClientRejectsFixtureBeforeMatcher() async throws {
    let matcher = SecurityMatcherSpy()
    let client = LiveMacOSSystemKeychainSecurityClient(
      domainResolver: {
        MacOSSystemKeychainResolution(
          status: errSecSuccess,
          keychain: fixtureKeychainHandle()
        )
      },
      itemMatcher: matcher.copyMatching
    )

    await #expect(throws: MacOSCredentialResolverError.credentialAccessDenied) {
      try await resolver(security: client).credential(
        for: request(
          UUID(uuidString: "22345678-1234-1234-1234-123456789abc")!,
          generation: 1
        )
      )
    }
    #expect(matcher.callCount == 0)
  }

  @Test("malformed references stop before any Keychain client call")
  func malformedReferenceStopsBeforeKeychain() async throws {
    let security = FixtureSystemKeychainClient(keychain: fixtureKeychainHandle())
    let valid = try request(
      UUID(uuidString: "23456789-2345-2345-2345-23456789abcd")!,
      generation: 1
    )
    let malformed = SSHCredentialRequest(
      credentialReference: SSHCredentialReference(rawValue: "not-a-canonical-reference"),
      credentialGeneration: valid.credentialGeneration,
      username: valid.username,
      allowedPublicKeyAlgorithms: valid.allowedPublicKeyAlgorithms,
      acceptedHost: valid.acceptedHost
    )

    await #expect(throws: MacOSCredentialResolverError.credentialMalformed) {
      try await resolver(security: security).credential(for: malformed)
    }
    #expect(await security.domainResolutionCount() == 0)
    #expect(await security.matchingQueryCount() == 0)
  }

  @Test("bounded repetitions leave no secret or query-count growth")
  func repeatedResolutionReturnsToBaseline() async throws {
    let reference = UUID(uuidString: "34567890-3456-3456-3456-34567890abcd")!
    let lifecycle = SecretLifecycleProbe()
    let iterations = 16

    for iteration in 0..<iterations {
      let security = FixtureSystemKeychainClient(
        keychain: fixtureKeychainHandle(iteration),
        item: fixtureItem(
          reference: reference,
          generation: UInt64(iteration + 1),
          passphrase: [0xA5],
          observer: lifecycle
        )
      )
      let credential = try await MacOSSystemKeychainCredentialResolver(
        securityClient: security,
        formatRegistry: FixtureFormatRegistry(),
        lifecycleObserver: lifecycle
      ).credential(for: request(reference, generation: UInt64(iteration + 1)))
      credential.retire()

      #expect(lifecycle.activeSecretCount == 0, "iteration \(iteration)")
      #expect(await security.domainResolutionCount() == 1, "iteration \(iteration)")
      #expect(await security.matchingQueryCount() == 1, "iteration \(iteration)")
    }
  }

  private static let service = MacOSSystemKeychainCredentialResolver.service
  private static let expectedQueryKeys: Set<String> = [
    kSecClass as String,
    kSecAttrService as String,
    kSecAttrAccount as String,
    kSecUseDataProtectionKeychain as String,
    kSecMatchSearchList as String,
    kSecReturnAttributes as String,
    kSecReturnData as String,
    kSecMatchLimit as String,
  ]
}

struct FormatFailureCase: Sendable, CustomTestStringConvertible {
  let error: MacOSCredentialFormatError
  let expected: MacOSCredentialResolverError
  var testDescription: String { expected.rawValue }
}

struct PassphraseCase: Sendable, CustomTestStringConvertible {
  let bytes: [UInt8]?
  let expectedCount: Int?
  let label: String
  var testDescription: String { label }
}

private actor FixtureSystemKeychainClient: MacOSSystemKeychainSecurityClient {
  let keychain: MacOSSystemKeychainHandle
  let status: OSStatus
  let item: MacOSKeychainLookupItem?
  let gate: ResolverTestGate?
  private var query: MacOSSystemKeychainLookupQuery?
  private var domainResolutions = 0
  private var matchingQueries = 0

  init(
    keychain: MacOSSystemKeychainHandle,
    status: OSStatus = errSecSuccess,
    item: MacOSKeychainLookupItem? = nil,
    gate: ResolverTestGate? = nil
  ) {
    self.keychain = keychain
    self.status = status
    self.item = item
    self.gate = gate
  }

  func copySystemDomainDefault() -> MacOSSystemKeychainResolution {
    domainResolutions += 1
    return MacOSSystemKeychainResolution(status: errSecSuccess, keychain: keychain)
  }

  func copyMatching(_ query: MacOSSystemKeychainLookupQuery) async
    -> MacOSSystemKeychainLookupResult
  {
    matchingQueries += 1
    self.query = query
    if let gate { await gate.enter() }
    return MacOSSystemKeychainLookupResult(status: status, item: item)
  }

  func recordedQuery() -> MacOSSystemKeychainLookupQuery? { query }
  func domainResolutionCount() -> Int { domainResolutions }
  func matchingQueryCount() -> Int { matchingQueries }
}

private final class SecurityMatcherSpy: @unchecked Sendable {
  private let lock = NSLock()
  private var calls = 0

  var callCount: Int {
    lock.withLock { calls }
  }

  func copyMatching(
    _ query: CFDictionary,
    _ result: UnsafeMutablePointer<CFTypeRef?>
  ) -> OSStatus {
    lock.withLock { calls += 1 }
    return errSecInternalError
  }
}

private struct FixtureFormatRegistry: MacOSCredentialFormatRegistry {
  let failure: MacOSCredentialFormatError?

  init(failure: MacOSCredentialFormatError? = nil) {
    self.failure = failure
  }

  func makeCredential(
    formatIdentifier: UInt16,
    privateKey: ScopedSecretBytes,
    passphrase: ScopedSecretBytes?,
    allowedAlgorithms: [String]
  ) throws -> any SSHPublicKeyCredential {
    if let failure { throw failure }
    guard privateKey.count > 0 else { throw MacOSCredentialFormatError.malformed }
    switch formatIdentifier {
    case 1:
      return FixtureResolvedCredential(algorithm: "ssh-ed25519")
    case 2:
      return FixtureResolvedCredential(algorithm: "ecdsa-sha2-nistp256")
    default:
      throw MacOSCredentialFormatError.unsupportedKey
    }
  }
}

private final class PassphraseObservingRegistry: MacOSCredentialFormatRegistry,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var count: Int??

  var observedCount: Int? { lock.withLock { count ?? nil } }

  func makeCredential(
    formatIdentifier: UInt16,
    privateKey: ScopedSecretBytes,
    passphrase: ScopedSecretBytes?,
    allowedAlgorithms: [String]
  ) throws -> any SSHPublicKeyCredential {
    lock.withLock { count = .some(passphrase?.count) }
    return FixtureResolvedCredential(algorithm: "ssh-ed25519")
  }
}

private struct RetiringFormatRegistry: MacOSCredentialFormatRegistry {
  let probe: RetirementProbe

  func makeCredential(
    formatIdentifier: UInt16,
    privateKey: ScopedSecretBytes,
    passphrase: ScopedSecretBytes?,
    allowedAlgorithms: [String]
  ) throws -> any SSHPublicKeyCredential {
    RetiringFixtureCredential(probe: probe)
  }
}

private final class RetiringFixtureCredential: SSHPublicKeyCredential, @unchecked Sendable {
  let algorithm = "ssh-ed25519"
  let publicKeyBytes = Data([0, 0, 0, 1])
  private let probe: RetirementProbe

  init(probe: RetirementProbe) {
    self.probe = probe
  }

  func sign(_ payload: Data) async throws -> Data { payload }
  func retire() { probe.retire() }
}

private final class RetirementProbe: @unchecked Sendable {
  private let lock = NSLock()
  private var retired = false

  var isRetired: Bool { lock.withLock { retired } }
  func retire() { lock.withLock { retired = true } }
}

private final class FixtureResolvedCredential: SSHPublicKeyCredential, @unchecked Sendable {
  let algorithm: String
  let publicKeyBytes = Data([0, 0, 0, 1])

  init(algorithm: String) {
    self.algorithm = algorithm
  }

  func sign(_ payload: Data) async throws -> Data {
    Data(payload.reversed())
  }
}

private final class SecretLifecycleProbe: MacOSCredentialSecretLifecycleObserver,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var created = 0
  private var cleared = 0

  var activeSecretCount: Int { lock.withLock { created - cleared } }
  var clearedSecretCount: Int { lock.withLock { cleared } }

  func secretCreated(byteCount: Int) {
    lock.withLock { created += 1 }
  }

  func secretCleared(byteCount: Int) {
    lock.withLock { cleared += 1 }
  }
}

private actor ResolverTestGate {
  private var entered = false
  private var isOpen = false
  private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
  private var openWaiters: [CheckedContinuation<Void, Never>] = []

  func enter() async {
    entered = true
    for waiter in enteredWaiters { waiter.resume() }
    enteredWaiters.removeAll()
    guard !isOpen else { return }
    await withCheckedContinuation { openWaiters.append($0) }
  }

  func waitUntilEntered() async {
    guard !entered else { return }
    await withCheckedContinuation { enteredWaiters.append($0) }
  }

  func open() {
    isOpen = true
    for waiter in openWaiters { waiter.resume() }
    openWaiters.removeAll()
  }
}

private func resolver(
  security: any MacOSSystemKeychainSecurityClient
) -> MacOSSystemKeychainCredentialResolver {
  MacOSSystemKeychainCredentialResolver(
    securityClient: security,
    formatRegistry: FixtureFormatRegistry()
  )
}

private func fixtureKeychainHandle(_ discriminator: Int = 0) -> MacOSSystemKeychainHandle {
  MacOSSystemKeychainHandle(
    fixtureIdentity: UUID(
      uuidString: String(format: "40000000-0000-0000-0000-%012d", discriminator)
    )!
  )
}

private func request(_ reference: UUID, generation: UInt64) throws -> SSHCredentialRequest {
  let lane = SSHLaneIdentity(rawValue: UUID())
  let evidence = try SSHHostKeyEvidence(algorithm: "ssh-ed25519", keyBytes: Data([1]))
  let input = SSHHostKeyPolicyInput(
    canonicalHostname: "fixture.invalid",
    connectedEndpoint: TunnelEndpoint(host: "192.0.2.1", port: 22),
    evidence: evidence,
    lane: lane,
    trustRecordReference: nil
  )
  let accepted = try SSHHostKeyDecision.acceptMatch(
    SSHTrustRecordReference(rawValue: "fixture-trust")
  ).acceptance(for: input)
  return SSHCredentialRequest(
    credentialReference: SSHCredentialReference(rawValue: reference.uuidString.lowercased()),
    credentialGeneration: generation,
    username: "fixture",
    allowedPublicKeyAlgorithms: ["ssh-ed25519", "ecdsa-sha2-nistp256"],
    acceptedHost: accepted
  )
}

private func fixtureItem(
  reference: UUID,
  generation: UInt64,
  format: UInt16 = 1,
  passphrase: [UInt8]? = nil,
  itemClass: String = kSecClassGenericPassword as String,
  account: String? = nil,
  data: [UInt8]? = nil,
  observer: (any MacOSCredentialSecretLifecycleObserver)? = nil
) -> MacOSKeychainLookupItem {
  MacOSKeychainLookupItem(
    itemClass: itemClass,
    service: MacOSSystemKeychainCredentialResolver.service,
    account: account ?? reference.uuidString.lowercased(),
    secretData: ScopedSecretBytes(
      data
        ?? credentialRecord(
          reference: reference,
          generation: generation,
          format: format,
          passphrase: passphrase
        ),
      observer: observer
    )
  )
}

private func credentialRecord(
  reference: UUID,
  generation: UInt64,
  format: UInt16,
  passphrase: [UInt8]? = nil
) -> [UInt8] {
  var record: [UInt8] = [0x52, 0x4C, 0x58, 0x43, 0x52, 0x44, 0x31, 0]
  append(format: UInt16(1), to: &record)
  append(uuid: reference, to: &record)
  append(format: generation, to: &record)
  append(uuid: UUID(uuidString: "01010101-0202-0303-0404-050505050505")!, to: &record)
  let payloadStart = record.count
  append(format: format, to: &record)
  let keyBytes: [UInt8] = [10, 20, 30, 40]
  append(format: UInt32(keyBytes.count), to: &record)
  record += keyBytes
  if let passphrase {
    record.append(1)
    append(format: UInt32(passphrase.count), to: &record)
    record += passphrase
  } else {
    record.append(0)
  }
  record += SHA256.hash(data: Data(record[payloadStart...]))
  return record
}

private func append<Integer: FixedWidthInteger>(format value: Integer, to bytes: inout [UInt8]) {
  let byteCount = Integer.bitWidth / 8
  for index in (0..<byteCount).reversed() {
    bytes.append(UInt8(truncatingIfNeeded: value >> (index * 8)))
  }
}

private func append(uuid value: UUID, to bytes: inout [UInt8]) {
  var uuid = value.uuid
  withUnsafeBytes(of: &uuid) { bytes += $0 }
}
