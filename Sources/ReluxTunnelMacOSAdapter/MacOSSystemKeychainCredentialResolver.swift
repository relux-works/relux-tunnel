import CryptoKit
import Foundation
import ReluxTunnelCore
import Security

/// Stable, non-identifying failures produced before SSH authentication begins.
public enum MacOSCredentialResolverError: String, Error, CaseIterable, Equatable, Sendable {
  case credentialNotProvisioned
  case credentialAccessDenied
  case credentialWrongClass
  case credentialGenerationMismatch
  case credentialMalformed
  case credentialPassphraseRequired
  case credentialPassphraseInvalid
  case credentialKeyUnsupported
  case operationCancelled
}

extension MacOSCredentialResolverError: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String { rawValue }
  public var debugDescription: String { rawValue }
}

/// Read-only resolver for one credential in the file-based system-domain Keychain.
///
/// The production format registry deliberately remains fail-closed until the
/// separately reviewed key-format owner assigns concrete format identifiers.
public final class MacOSSystemKeychainCredentialResolver: SSHCredentialProvider,
  @unchecked Sendable
{
  public static let service = "works.relux.tunnel.credential.v1"

  private let securityClient: any MacOSSystemKeychainSecurityClient
  private let formatRegistry: any MacOSCredentialFormatRegistry
  private let lifecycleObserver: any MacOSCredentialSecretLifecycleObserver

  public convenience init() {
    self.init(
      securityClient: LiveMacOSSystemKeychainSecurityClient(),
      formatRegistry: UnavailableMacOSCredentialFormatRegistry(),
      lifecycleObserver: NullMacOSCredentialSecretLifecycleObserver()
    )
  }

  init(
    securityClient: any MacOSSystemKeychainSecurityClient,
    formatRegistry: any MacOSCredentialFormatRegistry,
    lifecycleObserver: any MacOSCredentialSecretLifecycleObserver =
      NullMacOSCredentialSecretLifecycleObserver()
  ) {
    self.securityClient = securityClient
    self.formatRegistry = formatRegistry
    self.lifecycleObserver = lifecycleObserver
  }

  public func credential(for request: SSHCredentialRequest) async throws
    -> any SSHPublicKeyCredential
  {
    try checkCancellation()
    guard
      let reference = UUID(uuidString: request.credentialReference.rawValue),
      reference.uuidString.lowercased() == request.credentialReference.rawValue,
      request.credentialGeneration > 0
    else {
      throw MacOSCredentialResolverError.credentialMalformed
    }

    let resolution = await securityClient.copySystemDomainDefault()
    guard resolution.status == errSecSuccess, let keychain = resolution.keychain else {
      throw mapStatus(resolution.status, itemLookup: false)
    }
    try checkCancellation()

    let query = MacOSSystemKeychainLookupQuery(
      keychain: keychain,
      service: Self.service,
      account: request.credentialReference.rawValue
    )
    let result = await securityClient.copyMatching(query)
    defer { result.item?.secretData.clear() }
    guard result.status == errSecSuccess, let item = result.item else {
      throw mapStatus(result.status, itemLookup: true)
    }
    try checkCancellation()

    guard item.itemClass == kSecClassGenericPassword as String else {
      throw MacOSCredentialResolverError.credentialWrongClass
    }
    guard item.service == Self.service,
      item.account == request.credentialReference.rawValue
    else {
      throw MacOSCredentialResolverError.credentialMalformed
    }

    let decoded = try MacOSCredentialRecordDecoder.decode(
      item.secretData,
      expectedReference: reference,
      expectedGeneration: request.credentialGeneration,
      lifecycleObserver: lifecycleObserver
    )
    defer { decoded.clear() }
    try checkCancellation()

    let credential: any SSHPublicKeyCredential
    do {
      credential = try formatRegistry.makeCredential(
        formatIdentifier: decoded.formatIdentifier,
        privateKey: decoded.privateKey,
        passphrase: decoded.passphrase,
        allowedAlgorithms: request.allowedPublicKeyAlgorithms
      )
    } catch let error as MacOSCredentialFormatError {
      throw mapFormatError(error)
    } catch is CancellationError {
      throw MacOSCredentialResolverError.operationCancelled
    } catch {
      throw MacOSCredentialResolverError.credentialMalformed
    }

    let bounded = LifetimeBoundPublicKeyCredential(credential)
    do {
      try checkCancellation()
      return bounded
    } catch {
      bounded.retire()
      throw error
    }
  }

  private func checkCancellation() throws {
    do {
      try Task.checkCancellation()
    } catch {
      throw MacOSCredentialResolverError.operationCancelled
    }
  }

  private func mapStatus(_ status: OSStatus, itemLookup: Bool) -> MacOSCredentialResolverError {
    if itemLookup, status == errSecItemNotFound {
      return .credentialNotProvisioned
    }
    if status == errSecUserCanceled {
      return .operationCancelled
    }
    if status == errSecDecode {
      return .credentialMalformed
    }
    return .credentialAccessDenied
  }

  private func mapFormatError(_ error: MacOSCredentialFormatError)
    -> MacOSCredentialResolverError
  {
    switch error {
    case .malformed:
      .credentialMalformed
    case .passphraseRequired:
      .credentialPassphraseRequired
    case .passphraseInvalid:
      .credentialPassphraseInvalid
    case .unsupportedKey:
      .credentialKeyUnsupported
    }
  }
}

final class MacOSSystemKeychainHandle: @unchecked Sendable {
  let rawValue: SecKeychain

  init(_ rawValue: SecKeychain) {
    self.rawValue = rawValue
  }
}

struct MacOSSystemKeychainResolution: @unchecked Sendable {
  let status: OSStatus
  let keychain: MacOSSystemKeychainHandle?
}

struct MacOSSystemKeychainLookupQuery: @unchecked Sendable {
  let keychain: MacOSSystemKeychainHandle
  let service: String
  let account: String

  var dictionary: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecUseDataProtectionKeychain as String: false,
      kSecMatchSearchList as String: [keychain.rawValue],
      kSecReturnAttributes as String: true,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
  }
}

final class MacOSKeychainLookupItem: @unchecked Sendable {
  let itemClass: String
  let service: String
  let account: String
  let secretData: ScopedSecretBytes

  init(itemClass: String, service: String, account: String, secretData: ScopedSecretBytes) {
    self.itemClass = itemClass
    self.service = service
    self.account = account
    self.secretData = secretData
  }

  deinit {
    secretData.clear()
  }
}

struct MacOSSystemKeychainLookupResult: @unchecked Sendable {
  let status: OSStatus
  let item: MacOSKeychainLookupItem?
}

protocol MacOSSystemKeychainSecurityClient: Sendable {
  func copySystemDomainDefault() async -> MacOSSystemKeychainResolution
  func copyMatching(_ query: MacOSSystemKeychainLookupQuery) async
    -> MacOSSystemKeychainLookupResult
}

final class LiveMacOSSystemKeychainSecurityClient: MacOSSystemKeychainSecurityClient,
  @unchecked Sendable
{
  typealias DomainResolver = @Sendable () -> MacOSSystemKeychainResolution

  private let domainResolver: DomainResolver

  convenience init() {
    self.init(domainResolver: LiveMacOSSystemKeychainSecurityClient.resolveSystemDomain)
  }

  init(domainResolver: @escaping DomainResolver) {
    self.domainResolver = domainResolver
  }

  func copySystemDomainDefault() async -> MacOSSystemKeychainResolution {
    domainResolver()
  }

  func copyMatching(_ query: MacOSSystemKeychainLookupQuery) async
    -> MacOSSystemKeychainLookupResult
  {
    var output: CFTypeRef?
    let status = SecItemCopyMatching(query.dictionary as CFDictionary, &output)
    guard status == errSecSuccess, let attributes = output as? [String: Any],
      let itemClass = attributes[kSecClass as String] as? String,
      let service = attributes[kSecAttrService as String] as? String,
      let account = attributes[kSecAttrAccount as String] as? String,
      let data = attributes[kSecValueData as String] as? Data
    else {
      return MacOSSystemKeychainLookupResult(
        status: status == errSecSuccess ? errSecDecode : status,
        item: nil
      )
    }
    return MacOSSystemKeychainLookupResult(
      status: status,
      item: MacOSKeychainLookupItem(
        itemClass: itemClass,
        service: service,
        account: account,
        secretData: ScopedSecretBytes(Array(data), observer: nil)
      )
    )
  }

  private static func resolveSystemDomain() -> MacOSSystemKeychainResolution {
    var keychain: SecKeychain?
    let status = SecKeychainCopyDomainDefault(.system, &keychain)
    return MacOSSystemKeychainResolution(
      status: status,
      keychain: keychain.map(MacOSSystemKeychainHandle.init)
    )
  }
}

protocol MacOSCredentialSecretLifecycleObserver: Sendable {
  func secretCreated(byteCount: Int)
  func secretCleared(byteCount: Int)
}

struct NullMacOSCredentialSecretLifecycleObserver: MacOSCredentialSecretLifecycleObserver {
  func secretCreated(byteCount: Int) {}
  func secretCleared(byteCount: Int) {}
}

final class ScopedSecretBytes: @unchecked Sendable {
  private let lock = NSLock()
  private let observer: (any MacOSCredentialSecretLifecycleObserver)?
  private var storage: [UInt8]?

  init(_ bytes: [UInt8], observer: (any MacOSCredentialSecretLifecycleObserver)?) {
    storage = bytes
    self.observer = observer
    observer?.secretCreated(byteCount: bytes.count)
  }

  deinit {
    clear()
  }

  var count: Int {
    lock.withLock { storage?.count ?? 0 }
  }

  func withUnsafeBytes<Result>(_ body: (UnsafeRawBufferPointer) throws -> Result) rethrows
    -> Result?
  {
    try lock.withLock {
      guard let storage else { return nil }
      return try storage.withUnsafeBytes(body)
    }
  }

  func clear() {
    let clearedCount = lock.withLock { () -> Int in
      guard storage != nil else { return 0 }
      let count = storage!.count
      storage!.withUnsafeMutableBytes { rawBuffer in
        guard let address = rawBuffer.baseAddress else { return }
        memset(address, 0, rawBuffer.count)
      }
      storage = nil
      return count
    }
    if clearedCount > 0 {
      observer?.secretCleared(byteCount: clearedCount)
    }
  }
}

enum MacOSCredentialFormatError: Error, Equatable, Sendable {
  case malformed
  case passphraseRequired
  case passphraseInvalid
  case unsupportedKey
}

protocol MacOSCredentialFormatRegistry: Sendable {
  func makeCredential(
    formatIdentifier: UInt16,
    privateKey: ScopedSecretBytes,
    passphrase: ScopedSecretBytes?,
    allowedAlgorithms: [String]
  ) throws -> any SSHPublicKeyCredential
}

struct UnavailableMacOSCredentialFormatRegistry: MacOSCredentialFormatRegistry {
  func makeCredential(
    formatIdentifier: UInt16,
    privateKey: ScopedSecretBytes,
    passphrase: ScopedSecretBytes?,
    allowedAlgorithms: [String]
  ) throws -> any SSHPublicKeyCredential {
    throw MacOSCredentialFormatError.unsupportedKey
  }
}

private final class LifetimeBoundPublicKeyCredential: SSHPublicKeyCredential,
  @unchecked Sendable, CustomStringConvertible, CustomDebugStringConvertible
{
  private let lock = NSLock()
  private let fixedAlgorithm: String
  private let fixedPublicKeyBytes: Data
  private var underlying: (any SSHPublicKeyCredential)?

  init(_ underlying: any SSHPublicKeyCredential) {
    fixedAlgorithm = underlying.algorithm
    fixedPublicKeyBytes = underlying.publicKeyBytes
    self.underlying = underlying
  }

  deinit {
    retire()
  }

  var algorithm: String { fixedAlgorithm }
  var publicKeyBytes: Data { fixedPublicKeyBytes }
  var description: String { "MacOSSystemKeychainCredential(redacted)" }
  var debugDescription: String { description }

  func sign(_ payload: Data) async throws -> Data {
    guard let underlying = lock.withLock({ underlying }) else {
      throw MacOSCredentialResolverError.operationCancelled
    }
    return try await underlying.sign(payload)
  }

  func retire() {
    let credential = lock.withLock { () -> (any SSHPublicKeyCredential)? in
      defer { underlying = nil }
      return underlying
    }
    credential?.retire()
  }
}

private final class DecodedMacOSCredentialRecord: @unchecked Sendable {
  let formatIdentifier: UInt16
  let privateKey: ScopedSecretBytes
  let passphrase: ScopedSecretBytes?

  init(formatIdentifier: UInt16, privateKey: ScopedSecretBytes, passphrase: ScopedSecretBytes?) {
    self.formatIdentifier = formatIdentifier
    self.privateKey = privateKey
    self.passphrase = passphrase
  }

  deinit {
    clear()
  }

  func clear() {
    privateKey.clear()
    passphrase?.clear()
  }
}

private enum MacOSCredentialRecordDecoder {
  static let maximumRecordBytes = 57_344
  static let maximumPrivateKeyBytes = 49_152
  static let maximumPassphraseBytes = 4_096
  static let magic: [UInt8] = [0x52, 0x4C, 0x58, 0x43, 0x52, 0x44, 0x31, 0]

  static func decode(
    _ source: ScopedSecretBytes,
    expectedReference: UUID,
    expectedGeneration: UInt64,
    lifecycleObserver: any MacOSCredentialSecretLifecycleObserver
  ) throws -> DecodedMacOSCredentialRecord {
    guard source.count <= maximumRecordBytes,
      let decoded = try source.withUnsafeBytes({ bytes in
        try decode(
          bytes,
          expectedReference: expectedReference,
          expectedGeneration: expectedGeneration,
          lifecycleObserver: lifecycleObserver
        )
      })
    else {
      throw MacOSCredentialResolverError.credentialMalformed
    }
    return decoded
  }

  private static func decode(
    _ bytes: UnsafeRawBufferPointer,
    expectedReference: UUID,
    expectedGeneration: UInt64,
    lifecycleObserver: any MacOSCredentialSecretLifecycleObserver
  ) throws -> DecodedMacOSCredentialRecord {
    var reader = SecretRecordReader(bytes)
    guard try reader.readBytes(count: magic.count).elementsEqual(magic),
      try reader.readUInt16() == 1,
      try reader.readUUID() == expectedReference
    else {
      throw MacOSCredentialResolverError.credentialMalformed
    }
    guard try reader.readUInt64() == expectedGeneration else {
      throw MacOSCredentialResolverError.credentialGenerationMismatch
    }
    _ = try reader.readUUID()

    let payloadStart = reader.offset
    let formatIdentifier = try reader.readUInt16()
    let privateKeyCount = try reader.readUInt32AsInt()
    guard (1...maximumPrivateKeyBytes).contains(privateKeyCount) else {
      throw MacOSCredentialResolverError.credentialMalformed
    }
    let privateKeyBytes = Array(try reader.readBytes(count: privateKeyCount))

    let presence = try reader.readUInt8()
    let passphraseBytes: [UInt8]?
    switch presence {
    case 0:
      passphraseBytes = nil
    case 1:
      let count = try reader.readUInt32AsInt()
      guard count <= maximumPassphraseBytes else {
        throw MacOSCredentialResolverError.credentialMalformed
      }
      passphraseBytes = Array(try reader.readBytes(count: count))
    default:
      throw MacOSCredentialResolverError.credentialMalformed
    }

    let digestStart = reader.offset
    let expectedDigest = try reader.readBytes(count: SHA256.byteCount)
    guard reader.isAtEnd else {
      throw MacOSCredentialResolverError.credentialMalformed
    }
    var hasher = SHA256()
    hasher.update(
      bufferPointer: UnsafeRawBufferPointer(rebasing: bytes[payloadStart..<digestStart])
    )
    var actualDigest = Array(hasher.finalize())
    defer {
      actualDigest.withUnsafeMutableBytes { rawBuffer in
        guard let address = rawBuffer.baseAddress else { return }
        memset(address, 0, rawBuffer.count)
      }
    }
    guard constantTimeEqual(actualDigest, expectedDigest) else {
      throw MacOSCredentialResolverError.credentialMalformed
    }

    return DecodedMacOSCredentialRecord(
      formatIdentifier: formatIdentifier,
      privateKey: ScopedSecretBytes(privateKeyBytes, observer: lifecycleObserver),
      passphrase: passphraseBytes.map {
        ScopedSecretBytes($0, observer: lifecycleObserver)
      }
    )
  }

  private static func constantTimeEqual(
    _ lhs: [UInt8],
    _ rhs: UnsafeRawBufferPointer.SubSequence
  ) -> Bool {
    guard lhs.count == rhs.count else { return false }
    var difference: UInt8 = 0
    for index in lhs.indices {
      difference |= lhs[index] ^ rhs[rhs.startIndex + index]
    }
    return difference == 0
  }
}

private struct SecretRecordReader {
  let bytes: UnsafeRawBufferPointer
  private(set) var offset = 0

  init(_ bytes: UnsafeRawBufferPointer) {
    self.bytes = bytes
  }

  var isAtEnd: Bool { offset == bytes.count }

  mutating func readUInt8() throws -> UInt8 {
    let value = try readBytes(count: 1)
    return value[value.startIndex]
  }

  mutating func readUInt16() throws -> UInt16 {
    let value = try readBytes(count: 2)
    return (UInt16(value[value.startIndex]) << 8) | UInt16(value[value.startIndex + 1])
  }

  mutating func readUInt32AsInt() throws -> Int {
    let value = try readBytes(count: 4)
    var result: UInt32 = 0
    for byte in value { result = (result << 8) | UInt32(byte) }
    return Int(result)
  }

  mutating func readUInt64() throws -> UInt64 {
    let value = try readBytes(count: 8)
    var result: UInt64 = 0
    for byte in value { result = (result << 8) | UInt64(byte) }
    return result
  }

  mutating func readUUID() throws -> UUID {
    let value = try readBytes(count: 16)
    let byte = Array(value)
    return UUID(
      uuid: (
        byte[0], byte[1], byte[2], byte[3], byte[4], byte[5], byte[6], byte[7],
        byte[8], byte[9], byte[10], byte[11], byte[12], byte[13], byte[14], byte[15]
      )
    )
  }

  mutating func readBytes(count: Int) throws -> UnsafeRawBufferPointer.SubSequence {
    guard count >= 0, offset <= bytes.count, count <= bytes.count - offset else {
      throw MacOSCredentialResolverError.credentialMalformed
    }
    defer { offset += count }
    return bytes[offset..<(offset + count)]
  }
}
