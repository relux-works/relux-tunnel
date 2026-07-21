import Foundation

/// The signed host/provider identity consumed by host-side VPN configuration code.
///
/// Production values intentionally remain unavailable until the release-binding task
/// accepts all four identifiers. Tests and generated host targets inject validated
/// fixtures instead of guessing production identifiers.
public struct PlatformVPNIdentity: Equatable, Sendable {
  public enum Platform: String, Equatable, Sendable {
    case iOS
    case macOS
  }

  public let platform: Platform
  public let hostBundleIdentifier: String
  public let providerBundleIdentifier: String
  public let appGroupIdentifier: String
  public let keychainAccessGroup: String

  public init(
    platform: Platform,
    hostBundleIdentifier: String,
    providerBundleIdentifier: String,
    appGroupIdentifier: String,
    keychainAccessGroup: String
  ) throws {
    let values = [
      hostBundleIdentifier,
      providerBundleIdentifier,
      appGroupIdentifier,
      keychainAccessGroup,
    ]
    guard values.allSatisfy(Self.isValidInjectedIdentifier) else {
      throw VPNManagerRepositoryError.invalidPlatformIdentity
    }

    self.platform = platform
    self.hostBundleIdentifier = hostBundleIdentifier
    self.providerBundleIdentifier = providerBundleIdentifier
    self.appGroupIdentifier = appGroupIdentifier
    self.keychainAccessGroup = keychainAccessGroup
  }

  public static func production(for platform: Platform) throws -> PlatformVPNIdentity {
    throw VPNManagerRepositoryError.productionIdentityUnavailable(platform)
  }

  private static func isValidInjectedIdentifier(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.contains(".") else { return false }
    let lowered = trimmed.lowercased()
    return !lowered.contains("placeholder")
      && !lowered.contains("replace-me")
      && !lowered.contains("todo")
  }
}

public enum VPNProviderConfigurationValue: Equatable, Sendable {
  case string(String)
  case integer(Int)
  case unsignedInteger(UInt64)
  case data(Data)
  case unsupported
}

public enum VPNManagerContractVersion: Equatable, Sendable {
  case integer(Int)
  case unsignedInteger(UInt64)
}

public enum VPNManagerProtocolKind: Equatable, Sendable {
  case tunnelProvider
  case other
  case none
}

public enum VPNManagerSessionStatus: Equatable, Sendable {
  case invalid
  case disconnected
  case connecting
  case connected
  case reasserting
  case disconnecting

  public var isTerminal: Bool {
    self == .invalid || self == .disconnected
  }

  public var isTransitioning: Bool {
    self == .connecting || self == .reasserting || self == .disconnecting
  }
}

public struct VPNManagerSnapshot: Equatable, Sendable {
  public let protocolKind: VPNManagerProtocolKind
  public let providerBundleIdentifier: String?
  public let serverAddress: String?
  public let disconnectOnSleep: Bool
  public let includeAllNetworks: Bool
  public let excludeLocalNetworks: Bool
  public let enforceRoutes: Bool
  public let providerConfiguration: [String: VPNProviderConfigurationValue]?
  public let localizedDescription: String?
  public let isEnabled: Bool
  public let isOnDemandEnabled: Bool
  public let hasOnDemandRules: Bool
  public let hasAppRules: Bool
  public let sessionStatus: VPNManagerSessionStatus

  public init(
    protocolKind: VPNManagerProtocolKind,
    providerBundleIdentifier: String? = nil,
    serverAddress: String? = nil,
    disconnectOnSleep: Bool = false,
    includeAllNetworks: Bool = false,
    excludeLocalNetworks: Bool = false,
    enforceRoutes: Bool = false,
    providerConfiguration: [String: VPNProviderConfigurationValue]? = nil,
    localizedDescription: String? = nil,
    isEnabled: Bool = false,
    isOnDemandEnabled: Bool = false,
    hasOnDemandRules: Bool = false,
    hasAppRules: Bool = false,
    sessionStatus: VPNManagerSessionStatus = .disconnected
  ) {
    self.protocolKind = protocolKind
    self.providerBundleIdentifier = providerBundleIdentifier
    self.serverAddress = serverAddress
    self.disconnectOnSleep = disconnectOnSleep
    self.includeAllNetworks = includeAllNetworks
    self.excludeLocalNetworks = excludeLocalNetworks
    self.enforceRoutes = enforceRoutes
    self.providerConfiguration = providerConfiguration
    self.localizedDescription = localizedDescription
    self.isEnabled = isEnabled
    self.isOnDemandEnabled = isOnDemandEnabled
    self.hasOnDemandRules = hasOnDemandRules
    self.hasAppRules = hasAppRules
    self.sessionStatus = sessionStatus
  }
}

public struct CanonicalVPNManagerConfiguration: Equatable, Sendable {
  public let providerBundleIdentifier: String
  public let serverAddress: String
  public let disconnectOnSleep: Bool
  public let includeAllNetworks: Bool
  public let excludeLocalNetworks: Bool
  public let enforceRoutes: Bool
  public let providerConfiguration: [String: VPNProviderConfigurationValue]
  public let localizedDescription: String

  public init(
    providerBundleIdentifier: String,
    serverAddress: String,
    disconnectOnSleep: Bool,
    includeAllNetworks: Bool,
    excludeLocalNetworks: Bool,
    enforceRoutes: Bool,
    providerConfiguration: [String: VPNProviderConfigurationValue],
    localizedDescription: String
  ) {
    self.providerBundleIdentifier = providerBundleIdentifier
    self.serverAddress = serverAddress
    self.disconnectOnSleep = disconnectOnSleep
    self.includeAllNetworks = includeAllNetworks
    self.excludeLocalNetworks = excludeLocalNetworks
    self.enforceRoutes = enforceRoutes
    self.providerConfiguration = providerConfiguration
    self.localizedDescription = localizedDescription
  }
}

public struct VPNPreferencePlatformError: Error, Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    case configurationInvalid
    case configurationDisabled
    case connectionFailed
    case configurationStale
    case readWriteFailed
    case unknown
    case other
  }

  public let kind: Kind
  public let domain: String
  public let code: Int

  public init(kind: Kind, domain: String, code: Int) {
    self.kind = kind
    self.domain = domain
    self.code = code
  }
}

public protocol VPNPreferenceObservation: Sendable {
  func cancel()
}

public protocol VPNPreferencesManager: AnyObject, Sendable {
  var snapshot: VPNManagerSnapshot { get }

  func applyCanonicalConfiguration(_ configuration: CanonicalVPNManagerConfiguration)
  func setEnabled(_ enabled: Bool)
  func saveToPreferences(
    completion: @escaping @Sendable (VPNPreferencePlatformError?) -> Void
  )
  func removeFromPreferences(
    completion: @escaping @Sendable (VPNPreferencePlatformError?) -> Void
  )
  func stopTunnel()
  func observeTerminalStatus(
    completion: @escaping @Sendable (VPNManagerSessionStatus) -> Void
  ) -> any VPNPreferenceObservation
}

public protocol VPNPreferencesClient: Sendable {
  func loadAllFromPreferences(
    completion:
      @escaping @Sendable (
        Result<[any VPNPreferencesManager]?, VPNPreferencePlatformError>
      ) -> Void
  )
  func makeManager() -> any VPNPreferencesManager
}

public enum VPNManagerSystemEffect: Equatable, Sendable {
  case none
  case mayDisableAnotherEnterpriseVPN
}

public struct VPNManagerRepositoryResult: Equatable, Sendable {
  public let snapshot: VPNManagerSnapshot
  public let systemEffect: VPNManagerSystemEffect

  public init(snapshot: VPNManagerSnapshot, systemEffect: VPNManagerSystemEffect = .none) {
    self.snapshot = snapshot
    self.systemEffect = systemEffect
  }
}

public enum VPNManagerRepositoryError: Error, Equatable, Sendable {
  case invalidPlatformIdentity
  case productionIdentityUnavailable(PlatformVPNIdentity.Platform)
  case preferencesLoadReturnedNoCollection
  case preferencesTimedOut
  case operationCancelled
  case configurationInvalid
  case configurationDisabled
  case connectionFailed
  case preferencesReadWriteFailed
  case preferencesUnknown
  case authorizationFailed(domain: String, code: Int)
  case platformRejected(domain: String, code: Int)
  case duplicateOwnedManagers(Int)
  case duplicateOwnedManagersActive
  case legacyOrForeignCandidate
  case ownedConfigurationCorrupt
  case updateRequired(VPNManagerContractVersion)
  case futureOwnedConfigurationConflict
  case concurrentModification
  case savedButReloadFailed
  case removedButReloadFailed
  case ownedManagerNotFound
  case sessionTransitionInProgress(VPNManagerSessionStatus)
  case stopTimedOut
}

/// Serialized repository for the one app-owned `NETunnelProviderManager`.
///
/// Every public operation starts with a fresh preference load. A successful
/// write is followed by another load, and no manager object is cached across
/// calls, timeouts, cancellation, or stale-configuration retries.
public actor OwnedVPNManagerRepository {
  public static let ownerKey = "works.relux.tunnel.owner"
  public static let ownerValue = "relux-tunnel"
  public static let managerContractKey = "works.relux.tunnel.manager-contract-version"
  public static let managerContractVersion = 1
  public static let configurationReferenceKey =
    "works.relux.tunnel.configuration-reference"
  public static let serverAddressSentinel = "relux.invalid"

  private let identity: PlatformVPNIdentity
  private let client: any VPNPreferencesClient
  private let clock: any TunnelClock
  private let operationTimeout: Duration
  private var operationInProgress = false
  private var operationWaiters: [CheckedContinuation<Void, Never>] = []

  public init(
    identity: PlatformVPNIdentity,
    client: any VPNPreferencesClient,
    clock: any TunnelClock = ContinuousTunnelClock(),
    operationTimeout: Duration = .seconds(15)
  ) {
    self.identity = identity
    self.client = client
    self.clock = clock
    self.operationTimeout = operationTimeout
  }

  public func ensure(
    profileIdentifier: OpaqueProfileIdentifier,
    localizedDescription: String
  ) async throws -> VPNManagerRepositoryResult {
    await acquireOperation()
    defer { releaseOperation() }
    return try await ensureWhileHoldingOperation(
      profileIdentifier: profileIdentifier,
      localizedDescription: localizedDescription
    )
  }

  private func ensureWhileHoldingOperation(
    profileIdentifier: OpaqueProfileIdentifier,
    localizedDescription: String
  ) async throws -> VPNManagerRepositoryResult {
    let canonical = try makeCanonicalConfiguration(
      profileIdentifier: profileIdentifier,
      localizedDescription: localizedDescription
    )
    var staleRetryUsed = false

    while true {
      let managers = try await loadManagers()
      let partition = partition(managers)
      guard partition.legacyCandidates.isEmpty else {
        throw VPNManagerRepositoryError.legacyOrForeignCandidate
      }
      guard partition.owned.count <= 1 else {
        throw VPNManagerRepositoryError.duplicateOwnedManagers(partition.owned.count)
      }

      let manager: any VPNPreferencesManager
      let expectedEnabled: Bool
      if let existing = partition.owned.first {
        switch inspectOwned(existing.snapshot) {
        case .future(let version):
          throw VPNManagerRepositoryError.updateRequired(version)
        case .typeConfusedVersion:
          throw VPNManagerRepositoryError.ownedConfigurationCorrupt
        case .current, .corrupt:
          break
        }
        expectedEnabled = existing.snapshot.isEnabled
        if isCanonical(existing.snapshot, configuration: canonical) {
          return VPNManagerRepositoryResult(snapshot: existing.snapshot)
        }
        manager = existing
      } else {
        manager = client.makeManager()
        expectedEnabled = false
      }

      manager.applyCanonicalConfiguration(canonical)
      manager.setEnabled(expectedEnabled)
      do {
        try await save(manager)
      } catch let error as CallbackOperationError
        where error.platformError?.kind == .configurationStale
      {
        guard !staleRetryUsed else {
          throw VPNManagerRepositoryError.concurrentModification
        }
        staleRetryUsed = true
        continue
      } catch {
        throw mapOperationError(error, context: .write)
      }

      return try await verifySaved(
        canonical: canonical,
        expectedEnabled: expectedEnabled,
        systemEffect: .none
      )
    }
  }

  public func enableOwnedManager() async throws -> VPNManagerRepositoryResult {
    await acquireOperation()
    defer { releaseOperation() }
    return try await setEnabledWhileHoldingOperation(true)
  }

  public func disableOwnedManager() async throws -> VPNManagerRepositoryResult {
    await acquireOperation()
    defer { releaseOperation() }
    return try await setEnabledWhileHoldingOperation(false)
  }

  private func setEnabledWhileHoldingOperation(_ enabled: Bool) async throws
    -> VPNManagerRepositoryResult
  {
    var staleRetryUsed = false
    while true {
      let manager = try await loadSingleCurrentOwned()
      if !enabled {
        try await stopIfNeeded(manager)
      }
      let revalidated = manager.snapshot
      guard isOwned(revalidated) else {
        throw VPNManagerRepositoryError.ownedManagerNotFound
      }
      _ = try requireCurrent(revalidated)
      if enabled, revalidated.sessionStatus.isTransitioning {
        throw VPNManagerRepositoryError.sessionTransitionInProgress(
          revalidated.sessionStatus
        )
      }
      if !enabled, !revalidated.isEnabled {
        return VPNManagerRepositoryResult(
          snapshot: revalidated,
          systemEffect: .none
        )
      }

      manager.setEnabled(enabled)
      do {
        try await save(manager)
      } catch let error as CallbackOperationError
        where error.platformError?.kind == .configurationStale
      {
        guard !staleRetryUsed else {
          throw VPNManagerRepositoryError.concurrentModification
        }
        staleRetryUsed = true
        continue
      } catch {
        throw mapOperationError(error, context: .write)
      }

      return try await verifyCurrentSaved(
        expectedEnabled: enabled,
        systemEffect: enabled ? .mayDisableAnotherEnterpriseVPN : .none
      )
    }
  }

  public func removeOwnedManager() async throws {
    await acquireOperation()
    defer { releaseOperation() }
    try await removeOwnedManagerWhileHoldingOperation()
  }

  private func removeOwnedManagerWhileHoldingOperation() async throws {
    var staleRetryUsed = false
    while true {
      let manager = try await loadSingleCurrentOwned()
      try await stopIfNeeded(manager)
      guard isOwned(manager.snapshot) else {
        throw VPNManagerRepositoryError.ownedManagerNotFound
      }
      _ = try requireCurrent(manager.snapshot)

      do {
        try await remove(manager)
      } catch let error as CallbackOperationError
        where error.platformError?.kind == .configurationStale
      {
        guard !staleRetryUsed else {
          throw VPNManagerRepositoryError.concurrentModification
        }
        staleRetryUsed = true
        continue
      } catch {
        throw mapOperationError(error, context: .write)
      }

      do {
        let reloaded = try await loadManagers()
        guard partition(reloaded).owned.isEmpty else {
          throw VPNManagerRepositoryError.removedButReloadFailed
        }
        return
      } catch is VPNManagerRepositoryError {
        throw VPNManagerRepositoryError.removedButReloadFailed
      } catch {
        throw VPNManagerRepositoryError.removedButReloadFailed
      }
    }
  }

  public func repairDuplicateOwnedManagers(
    profileIdentifier: OpaqueProfileIdentifier,
    localizedDescription: String
  ) async throws -> VPNManagerRepositoryResult {
    await acquireOperation()
    defer { releaseOperation() }
    return try await repairDuplicateOwnedManagersWhileHoldingOperation(
      profileIdentifier: profileIdentifier,
      localizedDescription: localizedDescription
    )
  }

  private func repairDuplicateOwnedManagersWhileHoldingOperation(
    profileIdentifier: OpaqueProfileIdentifier,
    localizedDescription: String
  ) async throws -> VPNManagerRepositoryResult {
    var repairingDuplicates = false
    var staleRetryUsed = false
    while true {
      let managers = try await loadManagers()
      let partition = partition(managers)
      guard partition.legacyCandidates.isEmpty else {
        throw VPNManagerRepositoryError.legacyOrForeignCandidate
      }
      if partition.owned.isEmpty {
        return try await ensureWhileHoldingOperation(
          profileIdentifier: profileIdentifier,
          localizedDescription: localizedDescription
        )
      }
      if !repairingDuplicates, partition.owned.count <= 1 {
        return try await ensureWhileHoldingOperation(
          profileIdentifier: profileIdentifier,
          localizedDescription: localizedDescription
        )
      }
      repairingDuplicates = true

      for manager in partition.owned {
        switch inspectOwned(manager.snapshot) {
        case .future:
          throw VPNManagerRepositoryError.futureOwnedConfigurationConflict
        case .typeConfusedVersion:
          throw VPNManagerRepositoryError.ownedConfigurationCorrupt
        case .corrupt:
          throw VPNManagerRepositoryError.ownedConfigurationCorrupt
        case .current:
          guard manager.snapshot.sessionStatus.isTerminal else {
            throw VPNManagerRepositoryError.duplicateOwnedManagersActive
          }
        }
      }

      let manager = partition.owned[0]
      guard isOwned(manager.snapshot), manager.snapshot.sessionStatus.isTerminal else {
        throw VPNManagerRepositoryError.duplicateOwnedManagersActive
      }
      _ = try requireCurrent(manager.snapshot)

      do {
        try await remove(manager)
        staleRetryUsed = false
      } catch let error as CallbackOperationError
        where error.platformError?.kind == .configurationStale
      {
        guard !staleRetryUsed else {
          throw VPNManagerRepositoryError.concurrentModification
        }
        staleRetryUsed = true
        // The stale object is retired. Re-enter through a fresh load.
        continue
      } catch {
        throw mapOperationError(error, context: .write)
      }

      do {
        _ = try await loadManagers()
      } catch {
        throw VPNManagerRepositoryError.removedButReloadFailed
      }
    }
  }

  private func makeCanonicalConfiguration(
    profileIdentifier: OpaqueProfileIdentifier,
    localizedDescription: String
  ) throws -> CanonicalVPNManagerConfiguration {
    let reference = TunnelConfigurationReference(profileIdentifier: profileIdentifier)
    let referenceData = try RuntimeConfigurationCodec.encode(reference)
    guard referenceData.count <= TunnelConfigurationReference.maximumEncodedSize else {
      throw VPNManagerRepositoryError.ownedConfigurationCorrupt
    }
    return CanonicalVPNManagerConfiguration(
      providerBundleIdentifier: identity.providerBundleIdentifier,
      serverAddress: Self.serverAddressSentinel,
      disconnectOnSleep: false,
      includeAllNetworks: false,
      excludeLocalNetworks: false,
      enforceRoutes: false,
      providerConfiguration: [
        Self.ownerKey: .string(Self.ownerValue),
        Self.managerContractKey: .integer(Self.managerContractVersion),
        Self.configurationReferenceKey: .data(referenceData),
      ],
      localizedDescription: localizedDescription
    )
  }

  private func loadManagers() async throws -> [any VPNPreferencesManager] {
    do {
      let managers: [any VPNPreferencesManager]? = try await awaitCallback { completion in
        client.loadAllFromPreferences(completion: completion)
        return nil
      }
      guard let managers else {
        throw VPNManagerRepositoryError.preferencesLoadReturnedNoCollection
      }
      return managers
    } catch let error as VPNManagerRepositoryError {
      throw error
    } catch {
      throw mapOperationError(error, context: .read)
    }
  }

  private func save(_ manager: any VPNPreferencesManager) async throws {
    let _: Void = try await awaitCallback { completion in
      manager.saveToPreferences { error in
        completion(error.map(Result.failure) ?? .success(()))
      }
      return nil
    }
  }

  private func remove(_ manager: any VPNPreferencesManager) async throws {
    let _: Void = try await awaitCallback { completion in
      manager.removeFromPreferences { error in
        completion(error.map(Result.failure) ?? .success(()))
      }
      return nil
    }
  }

  private func stopIfNeeded(_ manager: any VPNPreferencesManager) async throws {
    let status = manager.snapshot.sessionStatus
    guard !status.isTerminal else { return }
    if status != .disconnecting {
      manager.stopTunnel()
    }
    do {
      let terminal: VPNManagerSessionStatus = try await awaitCallback { completion in
        manager.observeTerminalStatus { status in
          completion(.success(status))
        }
      }
      guard terminal.isTerminal else {
        throw VPNManagerRepositoryError.stopTimedOut
      }
    } catch let error as CallbackOperationError {
      switch error {
      case .timeout:
        throw VPNManagerRepositoryError.stopTimedOut
      case .cancelled:
        throw VPNManagerRepositoryError.operationCancelled
      case .platform:
        throw mapOperationError(error, context: .read)
      }
    }
  }

  private func loadSingleCurrentOwned() async throws -> any VPNPreferencesManager {
    let partition = partition(try await loadManagers())
    guard partition.legacyCandidates.isEmpty else {
      throw VPNManagerRepositoryError.legacyOrForeignCandidate
    }
    guard partition.owned.count <= 1 else {
      throw VPNManagerRepositoryError.duplicateOwnedManagers(partition.owned.count)
    }
    guard let manager = partition.owned.first else {
      throw VPNManagerRepositoryError.ownedManagerNotFound
    }
    _ = try requireCurrent(manager.snapshot)
    return manager
  }

  private func verifySaved(
    canonical: CanonicalVPNManagerConfiguration,
    expectedEnabled: Bool,
    systemEffect: VPNManagerSystemEffect
  ) async throws -> VPNManagerRepositoryResult {
    do {
      let partition = partition(try await loadManagers())
      guard partition.legacyCandidates.isEmpty,
        partition.owned.count == 1,
        let manager = partition.owned.first,
        manager.snapshot.isEnabled == expectedEnabled,
        isCanonical(manager.snapshot, configuration: canonical)
      else {
        throw VPNManagerRepositoryError.savedButReloadFailed
      }
      return VPNManagerRepositoryResult(snapshot: manager.snapshot, systemEffect: systemEffect)
    } catch {
      throw VPNManagerRepositoryError.savedButReloadFailed
    }
  }

  private func verifyCurrentSaved(
    expectedEnabled: Bool,
    systemEffect: VPNManagerSystemEffect
  ) async throws -> VPNManagerRepositoryResult {
    do {
      let manager = try await loadSingleCurrentOwned()
      guard manager.snapshot.isEnabled == expectedEnabled else {
        throw VPNManagerRepositoryError.savedButReloadFailed
      }
      return VPNManagerRepositoryResult(snapshot: manager.snapshot, systemEffect: systemEffect)
    } catch {
      throw VPNManagerRepositoryError.savedButReloadFailed
    }
  }

  private struct Partition {
    let owned: [any VPNPreferencesManager]
    let legacyCandidates: [any VPNPreferencesManager]
  }

  private func partition(_ managers: [any VPNPreferencesManager]) -> Partition {
    var owned: [any VPNPreferencesManager] = []
    var legacy: [any VPNPreferencesManager] = []
    for manager in managers {
      let snapshot = manager.snapshot
      if isOwned(snapshot) {
        owned.append(manager)
      } else if snapshot.protocolKind == .tunnelProvider
        && snapshot.providerBundleIdentifier == identity.providerBundleIdentifier
      {
        legacy.append(manager)
      }
    }
    return Partition(owned: owned, legacyCandidates: legacy)
  }

  private func isOwned(_ snapshot: VPNManagerSnapshot) -> Bool {
    snapshot.protocolKind == .tunnelProvider
      && snapshot.providerBundleIdentifier == identity.providerBundleIdentifier
      && snapshot.providerConfiguration?[Self.ownerKey] == .string(Self.ownerValue)
  }

  private enum OwnedInspection {
    case current(TunnelConfigurationReference)
    case corrupt
    case typeConfusedVersion
    case future(VPNManagerContractVersion)
  }

  private func inspectOwned(_ snapshot: VPNManagerSnapshot) -> OwnedInspection {
    let managerVersionValue = snapshot.providerConfiguration?[Self.managerContractKey]
    guard
      case .integer(let managerVersion)? = managerVersionValue,
      managerVersion == Self.managerContractVersion,
      case .data(let referenceData)? = snapshot.providerConfiguration?[
        Self.configurationReferenceKey
      ],
      referenceData.count <= TunnelConfigurationReference.maximumEncodedSize
    else {
      switch managerVersionValue {
      case .integer(let version) where version > Self.managerContractVersion:
        return .future(.integer(version))
      case .unsignedInteger(let version) where version > UInt64(Self.managerContractVersion):
        return .future(.unsignedInteger(version))
      case .string, .data, .unsupported, .unsignedInteger:
        return .typeConfusedVersion
      case .integer, .none:
        break
      }
      return .corrupt
    }

    do {
      return .current(try RuntimeConfigurationCodec.decodeReference(referenceData))
    } catch RuntimeMessageCodecError.unsupportedSchemaVersion(let version) {
      return version > TunnelConfigurationReference.currentSchemaVersion
        ? .future(.integer(Int(version))) : .corrupt
    } catch {
      return .corrupt
    }
  }

  private func requireCurrent(_ snapshot: VPNManagerSnapshot) throws
    -> TunnelConfigurationReference
  {
    switch inspectOwned(snapshot) {
    case .current(let reference):
      return reference
    case .corrupt:
      throw VPNManagerRepositoryError.ownedConfigurationCorrupt
    case .typeConfusedVersion:
      throw VPNManagerRepositoryError.ownedConfigurationCorrupt
    case .future(let version):
      throw VPNManagerRepositoryError.updateRequired(version)
    }
  }

  private func acquireOperation() async {
    if !operationInProgress {
      operationInProgress = true
      return
    }
    await withCheckedContinuation { continuation in
      operationWaiters.append(continuation)
    }
  }

  private func releaseOperation() {
    guard !operationWaiters.isEmpty else {
      operationInProgress = false
      return
    }
    operationWaiters.removeFirst().resume()
  }

  private func isCanonical(
    _ snapshot: VPNManagerSnapshot,
    configuration: CanonicalVPNManagerConfiguration
  ) -> Bool {
    snapshot.protocolKind == .tunnelProvider
      && snapshot.providerBundleIdentifier == configuration.providerBundleIdentifier
      && snapshot.serverAddress == configuration.serverAddress
      && snapshot.disconnectOnSleep == configuration.disconnectOnSleep
      && snapshot.includeAllNetworks == configuration.includeAllNetworks
      && snapshot.excludeLocalNetworks == configuration.excludeLocalNetworks
      && snapshot.enforceRoutes == configuration.enforceRoutes
      && snapshot.providerConfiguration == configuration.providerConfiguration
      && snapshot.localizedDescription == configuration.localizedDescription
      && !snapshot.isOnDemandEnabled
      && !snapshot.hasOnDemandRules
      && !snapshot.hasAppRules
  }

  private enum OperationContext {
    case read
    case write
  }

  private func mapOperationError(_ error: any Error, context: OperationContext)
    -> VPNManagerRepositoryError
  {
    guard let callbackError = error as? CallbackOperationError else {
      return .platformRejected(
        domain: String(reflecting: type(of: error)),
        code: 0
      )
    }
    switch callbackError {
    case .timeout:
      return .preferencesTimedOut
    case .cancelled:
      return .operationCancelled
    case .platform(let platform):
      switch platform.kind {
      case .configurationInvalid:
        return .configurationInvalid
      case .configurationDisabled:
        return .configurationDisabled
      case .connectionFailed:
        return .connectionFailed
      case .readWriteFailed:
        return .preferencesReadWriteFailed
      case .unknown:
        return .preferencesUnknown
      case .configurationStale:
        return .concurrentModification
      case .other:
        return context == .write
          ? .authorizationFailed(domain: platform.domain, code: platform.code)
          : .platformRejected(domain: platform.domain, code: platform.code)
      }
    }
  }

  private func awaitCallback<Value: Sendable>(
    _ start: (@escaping @Sendable (Result<Value, VPNPreferencePlatformError>) -> Void)
      -> (any VPNPreferenceObservation)?
  ) async throws -> Value {
    let token = PreferenceOperationToken<Value>()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        token.install(continuation)
        let observation = start { result in
          switch result {
          case .success(let value):
            token.resolve(.success(value))
          case .failure(let error):
            token.resolve(.failure(.platform(error)))
          }
        }
        token.setObservation(observation)
        let timeoutTask = Task { [clock, operationTimeout] in
          do {
            try await clock.sleep(for: operationTimeout)
            token.resolve(.failure(.timeout))
          } catch {
            // Resolution cancels the deadline task; no second result is emitted.
          }
        }
        token.setTimeoutTask(timeoutTask)
      }
    } onCancel: {
      token.resolve(.failure(.cancelled))
    }
  }
}

private enum CallbackOperationError: Error, Sendable {
  case timeout
  case cancelled
  case platform(VPNPreferencePlatformError)

  var platformError: VPNPreferencePlatformError? {
    if case .platform(let error) = self { return error }
    return nil
  }
}

private final class PreferenceOperationToken<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Value, any Error>?
  private var pendingResult: Result<Value, CallbackOperationError>?
  private var observation: (any VPNPreferenceObservation)?
  private var timeoutTask: Task<Void, Never>?
  private var resolved = false

  func install(_ continuation: CheckedContinuation<Value, any Error>) {
    lock.lock()
    if let pendingResult {
      self.pendingResult = nil
      lock.unlock()
      continuation.resume(with: pendingResult.mapError { $0 as any Error })
      return
    }
    self.continuation = continuation
    lock.unlock()
  }

  func setObservation(_ observation: (any VPNPreferenceObservation)?) {
    lock.lock()
    if resolved {
      lock.unlock()
      observation?.cancel()
      return
    }
    self.observation = observation
    lock.unlock()
  }

  func setTimeoutTask(_ task: Task<Void, Never>) {
    lock.lock()
    if resolved {
      lock.unlock()
      task.cancel()
      return
    }
    timeoutTask = task
    lock.unlock()
  }

  func resolve(_ result: Result<Value, CallbackOperationError>) {
    let continuation: CheckedContinuation<Value, any Error>?
    let observation: (any VPNPreferenceObservation)?
    let timeoutTask: Task<Void, Never>?

    lock.lock()
    guard !resolved else {
      lock.unlock()
      return
    }
    resolved = true
    continuation = self.continuation
    self.continuation = nil
    if continuation == nil {
      pendingResult = result
    }
    observation = self.observation
    self.observation = nil
    timeoutTask = self.timeoutTask
    self.timeoutTask = nil
    lock.unlock()

    observation?.cancel()
    timeoutTask?.cancel()
    continuation?.resume(with: result.mapError { $0 as any Error })
  }
}
