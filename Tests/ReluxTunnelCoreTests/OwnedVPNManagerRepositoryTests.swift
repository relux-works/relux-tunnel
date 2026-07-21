import Foundation
@preconcurrency import NetworkExtension
import ReluxTunnelCore
import Testing

@testable import ReluxTunnelIOSAdapter
@testable import ReluxTunnelMacOSAdapter

@Suite("Owned VPN manager repository")
struct OwnedVPNManagerRepositoryTests {
  private let profileID = OpaqueProfileIdentifier(
    UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  )

  @Test("zero and one owned ensure converge without enabling")
  func ensureConvergesIdempotently() async throws {
    let client = FakeVPNPreferencesClient()
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    let first = try await repository.ensure(
      profileIdentifier: profileID,
      localizedDescription: "Relux Tunnel"
    )
    let created = try #require(client.createdManagers.first)
    #expect(!first.snapshot.isEnabled)
    #expect(created.applyCount == 1)
    #expect(created.saveCount == 1)

    let second = try await repository.ensure(
      profileIdentifier: profileID,
      localizedDescription: "Relux Tunnel"
    )
    #expect(second.snapshot == first.snapshot)
    #expect(created.applyCount == 1)
    #expect(created.saveCount == 1)
  }

  @Test("ensure preserves an existing enabled state while replacing all noncanonical fields")
  func ensurePreservesEnabledState() async throws {
    let manager = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(
        profileID: profileID,
        enabled: true,
        serverAddress: "wrong.example",
        extraConfiguration: ["secret": .string("must-be-erased")]
      )
    )
    let client = FakeVPNPreferencesClient(managers: [manager])
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    let result = try await repository.ensure(
      profileIdentifier: profileID,
      localizedDescription: "Relux Tunnel"
    )

    #expect(result.snapshot.isEnabled)
    #expect(result.snapshot.serverAddress == OwnedVPNManagerRepository.serverAddressSentinel)
    #expect(result.snapshot.providerConfiguration?.count == 3)
    #expect(result.snapshot.providerConfiguration?["secret"] == nil)
    #expect(manager.applyCount == 1)
    #expect(manager.saveCount == 1)
  }

  @Test("nil manager collection fails closed without constructing or writing")
  func nilCollectionFailsClosed() async throws {
    let client = FakeVPNPreferencesClient()
    client.loadBehaviors = [.noCollection]
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    await #expect(throws: VPNManagerRepositoryError.preferencesLoadReturnedNoCollection) {
      try await repository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
    #expect(client.makeManagerCount == 0)
  }

  @Test("exact ownership predicate never mutates unrelated or wrong-type managers")
  func mixedManagerOwnershipTruthTable() async throws {
    let unrelated = [
      FakeVPNPreferencesManager(snapshot: .init(protocolKind: .none)),
      FakeVPNPreferencesManager(
        snapshot: .init(
          protocolKind: .other,
          localizedDescription: "Relux Tunnel"
        )
      ),
      FakeVPNPreferencesManager(
        snapshot: .init(
          protocolKind: .tunnelProvider,
          providerBundleIdentifier: "works.other.provider",
          providerConfiguration: [
            OwnedVPNManagerRepository.ownerKey: .string(
              OwnedVPNManagerRepository.ownerValue
            )
          ],
          localizedDescription: "Relux Tunnel"
        )
      ),
    ]
    let client = FakeVPNPreferencesClient(managers: unrelated)
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    _ = try await repository.ensure(
      profileIdentifier: profileID,
      localizedDescription: "Relux Tunnel"
    )

    for manager in unrelated {
      #expect(manager.applyCount == 0)
      #expect(manager.enabledSetterCount == 0)
      #expect(manager.saveCount == 0)
      #expect(manager.removeCount == 0)
    }
  }

  @Test("unmarked and type-confused provider lookalikes are zero-write conflicts")
  func unmarkedLookalikesConflict() async throws {
    for marker: VPNProviderConfigurationValue? in [nil, .integer(1), .string("RELUX-TUNNEL")] {
      var configuration: [String: VPNProviderConfigurationValue] = [:]
      configuration[OwnedVPNManagerRepository.ownerKey] = marker
      let lookalike = FakeVPNPreferencesManager(
        snapshot: .init(
          protocolKind: .tunnelProvider,
          providerBundleIdentifier: try identity().providerBundleIdentifier,
          providerConfiguration: configuration
        )
      )
      let client = FakeVPNPreferencesClient(managers: [lookalike])
      let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

      await #expect(throws: VPNManagerRepositoryError.legacyOrForeignCandidate) {
        try await repository.ensure(
          profileIdentifier: profileID,
          localizedDescription: "Relux Tunnel"
        )
      }
      #expect(lookalike.totalMutationCount == 0)
      #expect(client.makeManagerCount == 0)
    }
  }

  @Test("provider configuration contains only the marker version and bounded opaque reference")
  func leastDataProviderConfiguration() async throws {
    let client = FakeVPNPreferencesClient()
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    let result = try await repository.ensure(
      profileIdentifier: profileID,
      localizedDescription: "Relux Tunnel"
    )
    let configuration = try #require(result.snapshot.providerConfiguration)
    #expect(
      Set(configuration.keys)
        == Set([
          OwnedVPNManagerRepository.ownerKey,
          OwnedVPNManagerRepository.managerContractKey,
          OwnedVPNManagerRepository.configurationReferenceKey,
        ])
    )
    #expect(
      configuration[OwnedVPNManagerRepository.ownerKey]
        == .string(OwnedVPNManagerRepository.ownerValue)
    )
    #expect(
      configuration[OwnedVPNManagerRepository.managerContractKey]
        == .integer(OwnedVPNManagerRepository.managerContractVersion)
    )
    guard
      case .data(let referenceData)? = configuration[
        OwnedVPNManagerRepository.configurationReferenceKey
      ]
    else {
      Issue.record("configuration reference is not Data")
      return
    }
    #expect(referenceData.count <= 4 * 1_024)
    #expect(
      try RuntimeConfigurationCodec.decodeReference(referenceData)
        == TunnelConfigurationReference(profileIdentifier: profileID)
    )
    let encoded = String(decoding: referenceData, as: UTF8.self)
    #expect(!encoded.localizedCaseInsensitiveContains("password"))
    #expect(!encoded.localizedCaseInsensitiveContains("private"))
    #expect(!encoded.localizedCaseInsensitiveContains("host"))
  }

  @Test("future owned configuration is preserved and corruption is repaired only by ensure")
  func futureAndCorruptHandling() async throws {
    let future = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(
        profileID: profileID,
        managerVersion: 2
      )
    )
    let futureRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [future])
    )
    await #expect(throws: VPNManagerRepositoryError.updateRequired(.integer(2))) {
      try await futureRepository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
    await #expect(throws: VPNManagerRepositoryError.updateRequired(.integer(2))) {
      try await futureRepository.removeOwnedManager()
    }
    #expect(future.totalMutationCount == 0)

    let corrupt = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(
        profileID: profileID,
        referenceValue: .string("not-data")
      )
    )
    let corruptRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [corrupt])
    )
    _ = try await corruptRepository.ensure(
      profileIdentifier: profileID,
      localizedDescription: "Relux Tunnel"
    )
    #expect(corrupt.applyCount == 1)
    #expect(corrupt.saveCount == 1)
  }

  @Test("every positive future manager version is preserved without writes")
  func largeFutureManagerVersionsArePreserved() async throws {
    for version in [Int(UInt16.max) + 1, Int.max] {
      let future = FakeVPNPreferencesManager(
        snapshot: try ownedSnapshot(profileID: profileID, managerVersion: version)
      )
      let repository = OwnedVPNManagerRepository(
        identity: try identity(),
        client: FakeVPNPreferencesClient(managers: [future])
      )

      await #expect(throws: VPNManagerRepositoryError.updateRequired(.integer(version))) {
        try await repository.ensure(
          profileIdentifier: profileID,
          localizedDescription: "Relux Tunnel"
        )
      }
      await #expect(throws: VPNManagerRepositoryError.updateRequired(.integer(version))) {
        try await repository.removeOwnedManager()
      }
      #expect(future.totalMutationCount == 0)

      let current = FakeVPNPreferencesManager(
        snapshot: try ownedSnapshot(profileID: profileID)
      )
      let repairRepository = OwnedVPNManagerRepository(
        identity: try identity(),
        client: FakeVPNPreferencesClient(managers: [future, current])
      )
      await #expect(throws: VPNManagerRepositoryError.futureOwnedConfigurationConflict) {
        try await repairRepository.repairDuplicateOwnedManagers(
          profileIdentifier: profileID,
          localizedDescription: "Relux Tunnel"
        )
      }
      #expect(future.totalMutationCount == 0)
      #expect(current.totalMutationCount == 0)
    }
  }

  @Test("iOS seam decodes NSNumber manager versions exactly and preserves invalid values")
  func iOSNSNumberManagerVersionsAreExact() async throws {
    try await assertExactPlatformVersionDecoding(
      boolean: IOSVPNProviderConfigurationCodec.decode(NSNumber(value: true)),
      fractional: IOSVPNProviderConfigurationCodec.decode(NSNumber(value: 1.5)),
      unsignedMaximum: IOSVPNProviderConfigurationCodec.decode(
        NSNumber(value: UInt64.max)
      ),
      integerMaximum: IOSVPNProviderConfigurationCodec.decode(NSNumber(value: Int.max)),
      current: IOSVPNProviderConfigurationCodec.decode(NSNumber(value: Int(1)))
    )
  }

  @Test("macOS seam decodes NSNumber manager versions exactly and preserves invalid values")
  func macOSNSNumberManagerVersionsAreExact() async throws {
    try await assertExactPlatformVersionDecoding(
      boolean: MacOSVPNProviderConfigurationCodec.decode(NSNumber(value: true)),
      fractional: MacOSVPNProviderConfigurationCodec.decode(NSNumber(value: 1.5)),
      unsignedMaximum: MacOSVPNProviderConfigurationCodec.decode(
        NSNumber(value: UInt64.max)
      ),
      integerMaximum: MacOSVPNProviderConfigurationCodec.decode(NSNumber(value: Int.max)),
      current: MacOSVPNProviderConfigurationCodec.decode(NSNumber(value: Int(1)))
    )
  }

  @Test("inactive duplicate repair removes exact owned managers only and recreates one")
  func repairsInactiveDuplicates() async throws {
    let first = FakeVPNPreferencesManager(snapshot: try ownedSnapshot(profileID: profileID))
    let second = FakeVPNPreferencesManager(snapshot: try ownedSnapshot(profileID: profileID))
    let unrelated = FakeVPNPreferencesManager(
      snapshot: .init(
        protocolKind: .tunnelProvider,
        providerBundleIdentifier: "works.other.provider"
      )
    )
    let client = FakeVPNPreferencesClient(managers: [unrelated, first, second])
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    let result = try await repository.repairDuplicateOwnedManagers(
      profileIdentifier: profileID,
      localizedDescription: "Relux Tunnel"
    )

    #expect(first.removeCount + second.removeCount == 2)
    #expect(unrelated.totalMutationCount == 0)
    #expect(client.currentManagers.count == 2)
    let expectedProviderIdentifier = try identity().providerBundleIdentifier
    #expect(result.snapshot.providerBundleIdentifier == expectedProviderIdentifier)
  }

  @Test("active duplicate and future duplicate repair paths perform zero writes")
  func duplicateRepairConflicts() async throws {
    let active = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, sessionStatus: .connected)
    )
    let current = FakeVPNPreferencesManager(snapshot: try ownedSnapshot(profileID: profileID))
    let activeRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [active, current])
    )
    await #expect(throws: VPNManagerRepositoryError.duplicateOwnedManagersActive) {
      try await activeRepository.repairDuplicateOwnedManagers(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
    #expect(active.totalMutationCount == 0)
    #expect(current.totalMutationCount == 0)

    let future = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, managerVersion: 2)
    )
    let futureRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [future, current])
    )
    await #expect(throws: VPNManagerRepositoryError.futureOwnedConfigurationConflict) {
      try await futureRepository.repairDuplicateOwnedManagers(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
    #expect(future.totalMutationCount == 0)
  }

  @Test("enable is explicit and reports the enterprise VPN system effect")
  func explicitEnable() async throws {
    let manager = FakeVPNPreferencesManager(snapshot: try ownedSnapshot(profileID: profileID))
    let repository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [manager])
    )

    let ensured = try await repository.ensure(
      profileIdentifier: profileID,
      localizedDescription: "Relux Tunnel"
    )
    #expect(!ensured.snapshot.isEnabled)
    #expect(manager.saveCount == 0)

    let enabled = try await repository.enableOwnedManager()
    #expect(enabled.snapshot.isEnabled)
    #expect(enabled.systemEffect == .mayDisableAnotherEnterpriseVPN)
    #expect(manager.enabledSetterCount == 1)
    #expect(manager.saveCount == 1)
  }

  @Test("enable rejects every active session transition without writes")
  func enableRejectsSessionTransitions() async throws {
    for status in [
      VPNManagerSessionStatus.connecting,
      .reasserting,
      .disconnecting,
    ] {
      let manager = FakeVPNPreferencesManager(
        snapshot: try ownedSnapshot(profileID: profileID, sessionStatus: status)
      )
      let repository = OwnedVPNManagerRepository(
        identity: try identity(),
        client: FakeVPNPreferencesClient(managers: [manager])
      )

      await #expect(
        throws: VPNManagerRepositoryError.sessionTransitionInProgress(status)
      ) {
        try await repository.enableOwnedManager()
      }
      #expect(manager.totalMutationCount == 0)
    }
  }

  @Test("already enabled still follows explicit save and fresh reload verification")
  func alreadyEnabledStillSavesAndReloads() async throws {
    let manager = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, enabled: true)
    )
    let client = FakeVPNPreferencesClient(managers: [manager])
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    let result = try await repository.enableOwnedManager()

    #expect(result.snapshot.isEnabled)
    #expect(result.systemEffect == .mayDisableAnotherEnterpriseVPN)
    #expect(manager.enabledSetterCount == 1)
    #expect(manager.saveCount == 1)
    let reloaded = try #require(client.currentManagers.first)
    #expect(reloaded !== manager)
  }

  @Test("disable and removal stop active sessions before preference writes")
  func disableAndRemoveStopFirst() async throws {
    let disabling = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, enabled: true, sessionStatus: .connected)
    )
    disabling.statusAfterStop = .disconnected
    let disableRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [disabling])
    )
    _ = try await disableRepository.disableOwnedManager()
    #expect(disabling.stopCount == 1)
    #expect(disabling.saveCount == 1)

    let removing = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, sessionStatus: .connected)
    )
    removing.statusAfterStop = .disconnected
    let removeRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [removing])
    )
    try await removeRepository.removeOwnedManager()
    #expect(removing.stopCount == 1)
    #expect(removing.removeCount == 1)
  }

  @Test("a stale save retries once with a freshly loaded manager")
  func staleRetryUsesFreshManager() async throws {
    let old = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, serverAddress: "old.invalid")
    )
    let fresh = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, serverAddress: "still-old.invalid")
    )
    let client = FakeVPNPreferencesClient(managers: [old])
    old.saveErrors = [platformError(.configurationStale)]
    old.onSave = { _ in client.replaceManagers([fresh]) }
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    _ = try await repository.ensure(
      profileIdentifier: profileID,
      localizedDescription: "Relux Tunnel"
    )

    #expect(old.applyCount == 1)
    #expect(old.saveCount == 1)
    #expect(fresh.applyCount == 1)
    #expect(fresh.saveCount == 1)
  }

  @Test("a second stale save maps to concurrent modification")
  func secondStaleFails() async throws {
    let old = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, serverAddress: "old.invalid")
    )
    let fresh = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, serverAddress: "still-old.invalid")
    )
    let client = FakeVPNPreferencesClient(managers: [old])
    old.saveErrors = [platformError(.configurationStale)]
    fresh.saveErrors = [platformError(.configurationStale)]
    old.onSave = { _ in client.replaceManagers([fresh]) }
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    await #expect(throws: VPNManagerRepositoryError.concurrentModification) {
      try await repository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
    #expect(old.saveCount == 1)
    #expect(fresh.saveCount == 1)
  }

  @Test("stale enable retries revalidate unrelated unmarked and future replacements")
  func staleEnableRevalidatesFreshManager() async throws {
    let unrelatedOld = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID)
    )
    let unrelatedFresh = FakeVPNPreferencesManager(
      snapshot: .init(
        protocolKind: .tunnelProvider,
        providerBundleIdentifier: "works.other.provider"
      )
    )
    let unrelatedClient = FakeVPNPreferencesClient(managers: [unrelatedOld])
    unrelatedOld.saveErrors = [platformError(.configurationStale)]
    unrelatedOld.onSave = { _ in unrelatedClient.replaceManagers([unrelatedFresh]) }
    let unrelatedRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: unrelatedClient
    )
    await #expect(throws: VPNManagerRepositoryError.ownedManagerNotFound) {
      try await unrelatedRepository.enableOwnedManager()
    }
    #expect(unrelatedFresh.totalMutationCount == 0)

    let unmarkedOld = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID)
    )
    let unmarkedFresh = FakeVPNPreferencesManager(
      snapshot: .init(
        protocolKind: .tunnelProvider,
        providerBundleIdentifier: try identity().providerBundleIdentifier
      )
    )
    let unmarkedClient = FakeVPNPreferencesClient(managers: [unmarkedOld])
    unmarkedOld.saveErrors = [platformError(.configurationStale)]
    unmarkedOld.onSave = { _ in unmarkedClient.replaceManagers([unmarkedFresh]) }
    let unmarkedRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: unmarkedClient
    )
    await #expect(throws: VPNManagerRepositoryError.legacyOrForeignCandidate) {
      try await unmarkedRepository.enableOwnedManager()
    }
    #expect(unmarkedFresh.totalMutationCount == 0)

    let futureOld = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID)
    )
    let futureFresh = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, managerVersion: Int.max)
    )
    let futureClient = FakeVPNPreferencesClient(managers: [futureOld])
    futureOld.saveErrors = [platformError(.configurationStale)]
    futureOld.onSave = { _ in futureClient.replaceManagers([futureFresh]) }
    let futureRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: futureClient
    )
    await #expect(throws: VPNManagerRepositoryError.updateRequired(.integer(Int.max))) {
      try await futureRepository.enableOwnedManager()
    }
    #expect(futureFresh.totalMutationCount == 0)
  }

  @Test("save verification uses a distinct reload and rejects noncanonical persistence")
  func saveVerificationRejectsNoncanonicalFreshManager() async throws {
    let manager = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, serverAddress: "wrong.invalid")
    )
    let client = FakeVPNPreferencesClient(managers: [manager])
    client.persistedSnapshotOverride = try ownedSnapshot(
      profileID: profileID,
      serverAddress: "not-persisted-canonically.invalid"
    )
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    await #expect(throws: VPNManagerRepositoryError.savedButReloadFailed) {
      try await repository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }

    #expect(manager.applyCount == 1)
    #expect(manager.saveCount == 1)
    let reloaded = try #require(client.currentManagers.first)
    #expect(reloaded !== manager)
    #expect(reloaded.snapshot.serverAddress == "not-persisted-canonically.invalid")
    #expect(reloaded.totalMutationCount == 0)
  }

  @Test("authorization and saved-but-reload-failed results are stable")
  func stableWriteErrors() async throws {
    let loadClient = FakeVPNPreferencesClient()
    loadClient.loadBehaviors = [.failure(platformError(.readWriteFailed))]
    let loadRepository = OwnedVPNManagerRepository(identity: try identity(), client: loadClient)
    await #expect(throws: VPNManagerRepositoryError.preferencesReadWriteFailed) {
      try await loadRepository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }

    let denied = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, serverAddress: "wrong.invalid")
    )
    denied.saveErrors = [platformError(.other, domain: "Authorization", code: 17)]
    let deniedRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [denied])
    )
    await #expect(
      throws: VPNManagerRepositoryError.authorizationFailed(domain: "Authorization", code: 17)
    ) {
      try await deniedRepository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }

    let saved = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, serverAddress: "wrong.invalid")
    )
    let savedClient = FakeVPNPreferencesClient(managers: [saved])
    saved.onSave = { error in
      if error == nil { savedClient.loadBehaviors = [.failure(platformError(.readWriteFailed))] }
    }
    let savedRepository = OwnedVPNManagerRepository(identity: try identity(), client: savedClient)
    await #expect(throws: VPNManagerRepositoryError.savedButReloadFailed) {
      try await savedRepository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
  }

  @Test("timeout retires a load token and ignores its late callback")
  func lateCallbackAfterTimeoutIsIgnored() async throws {
    let client = FakeVPNPreferencesClient()
    client.loadBehaviors = [.deferred]
    let repository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: client,
      clock: ImmediateTimeoutClock()
    )

    await #expect(throws: VPNManagerRepositoryError.preferencesTimedOut) {
      try await repository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
    client.completeDeferredLoads(with: .success([]))
    #expect(client.makeManagerCount == 0)
  }

  @Test("cancellation retires a load token and ignores its late callback")
  func lateCallbackAfterCancellationIsIgnored() async throws {
    let client = FakeVPNPreferencesClient()
    client.loadBehaviors = [.deferred]
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)
    let operation = Task {
      try await repository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
    await Task.yield()
    operation.cancel()

    await #expect(throws: VPNManagerRepositoryError.operationCancelled) {
      try await operation.value
    }
    client.completeDeferredLoads(with: .success([]))
    #expect(client.makeManagerCount == 0)
  }

  @Test("operation gate queues every repository entry point behind an active callback")
  func operationGateSerializesAllEntryPoints() async throws {
    for queuedOperation in QueuedRepositoryOperation.allCases {
      let manager = FakeVPNPreferencesManager(
        snapshot: try ownedSnapshot(profileID: profileID)
      )
      let client = FakeVPNPreferencesClient(managers: [manager])
      client.loadBehaviors = [.deferred]
      let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

      let first = Task {
        try await repository.ensure(
          profileIdentifier: profileID,
          localizedDescription: "Relux Tunnel"
        )
      }
      await client.waitForLoadCount(1)

      let started = AsyncStream<Void>.makeStream()
      let second = Task {
        started.continuation.yield()
        try await perform(queuedOperation, on: repository)
      }
      for await _ in started.stream.prefix(1) {}
      for _ in 0..<20 { await Task.yield() }

      #expect(client.loadCount == 1, "queued operation: \(queuedOperation)")
      #expect(manager.totalMutationCount == 0, "queued operation: \(queuedOperation)")

      client.completeDeferredLoads(with: .success([manager]))
      _ = try await first.value
      try await second.value
      started.continuation.finish()
    }
  }

  @Test("concurrent zero-manager ensure saves one canonical manager")
  func concurrentZeroManagerEnsureConverges() async throws {
    let client = FakeVPNPreferencesClient()
    client.loadBehaviors = [.deferred]
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    let first = Task {
      try await repository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
    await client.waitForLoadCount(1)

    let started = AsyncStream<Void>.makeStream()
    let second = Task {
      started.continuation.yield()
      return try await repository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
    for await _ in started.stream.prefix(1) {}
    for _ in 0..<20 { await Task.yield() }

    #expect(client.loadCount == 1)
    #expect(client.makeManagerCount == 0)
    client.completeDeferredLoads(with: .success([]))

    let firstResult = try await first.value
    let secondResult = try await second.value
    started.continuation.finish()
    #expect(firstResult.snapshot == secondResult.snapshot)
    #expect(client.createdManagers.count == 1)
    #expect(client.createdManagers[0].saveCount == 1)
  }

  @Test("stop timeout prevents disable and preference save")
  func stopTimeoutPreventsWrite() async throws {
    let manager = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, enabled: true, sessionStatus: .connected)
    )
    let repository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [manager]),
      clock: ImmediateTimeoutClock()
    )

    await #expect(throws: VPNManagerRepositoryError.stopTimedOut) {
      try await repository.disableOwnedManager()
    }
    #expect(manager.stopCount == 1)
    #expect(manager.enabledSetterCount == 0)
    #expect(manager.saveCount == 0)
  }

  @Test(
    "terminal status present before registration resolves without waiting",
    arguments: AppleVPNStatusObservationSeam.allCases
  )
  func terminalBeforeRegistration(platform: AppleVPNStatusObservationSeam) {
    let source = FakeVPNStatusSource(status: .disconnected)
    let recorder = VPNStatusRecorder()

    let observation = platform.observe(source: source) { recorder.record($0) }

    #expect(
      source.events
        == [.registrationStarted, .registrationReturned, .statusRead]
    )
    #expect(source.registrationCount == 1)
    #expect(source.unregistrationCount == 1)
    #expect(recorder.statuses == [.disconnected])
    withExtendedLifetime(observation) {}
  }

  @Test(
    "terminal transition during registration is caught by the authoritative recheck",
    arguments: AppleVPNStatusObservationSeam.allCases
  )
  func terminalDuringRegistration(platform: AppleVPNStatusObservationSeam) {
    let source = FakeVPNStatusSource(
      status: .connected,
      registrationTransition: .terminalWithoutNotification
    )
    let recorder = VPNStatusRecorder()

    let observation = platform.observe(source: source) { recorder.record($0) }

    #expect(
      source.events
        == [.registrationStarted, .registrationReturned, .statusRead]
    )
    #expect(source.registrationCount == 1)
    #expect(source.unregistrationCount == 1)
    #expect(recorder.statuses == [.disconnected])
    withExtendedLifetime(observation) {}
  }

  @Test(
    "notification before registration returns resolves once and retires its token",
    arguments: AppleVPNStatusObservationSeam.allCases
  )
  func notificationBeforeRegistrationReturns(platform: AppleVPNStatusObservationSeam) {
    let source = FakeVPNStatusSource(
      status: .connected,
      registrationTransition: .terminalWithNotification
    )
    let recorder = VPNStatusRecorder()

    let observation = platform.observe(source: source) { recorder.record($0) }

    #expect(
      source.events
        == [
          .registrationStarted,
          .statusRead,
          .registrationReturned,
          .statusRead,
        ]
    )
    #expect(source.registrationCount == 1)
    #expect(source.unregistrationCount == 1)
    #expect(recorder.statuses == [.disconnected])
    withExtendedLifetime(observation) {}
  }

  @Test(
    "notification-first terminal completion wins exactly once",
    arguments: AppleVPNStatusObservationSeam.allCases
  )
  func notificationFirst(platform: AppleVPNStatusObservationSeam) {
    let source = FakeVPNStatusSource(status: .connected)
    let recorder = VPNStatusRecorder()
    let observation = platform.observe(source: source) { recorder.record($0) }

    source.notify(status: .disconnected)

    #expect(source.registrationCount == 1)
    #expect(source.unregistrationCount == 1)
    #expect(recorder.statuses == [.disconnected])
    withExtendedLifetime(observation) {}
  }

  @Test(
    "resolved observation ignores duplicate and late notifications",
    arguments: AppleVPNStatusObservationSeam.allCases
  )
  func resolvedObservationRetires(platform: AppleVPNStatusObservationSeam) {
    let source = FakeVPNStatusSource(status: .connected)
    let recorder = VPNStatusRecorder()
    let observation = platform.observe(source: source) { recorder.record($0) }

    source.notify(status: .disconnected)
    source.notify(status: .invalid)
    source.notify(status: .disconnected)

    #expect(source.unregistrationCount == 1)
    #expect(recorder.statuses == [.disconnected])
    withExtendedLifetime(observation) {}
  }

  @Test(
    "cancelled observation unregisters once and ignores late notification",
    arguments: AppleVPNStatusObservationSeam.allCases
  )
  func cancelledObservationRetires(platform: AppleVPNStatusObservationSeam) {
    let source = FakeVPNStatusSource(status: .connected)
    let recorder = VPNStatusRecorder()
    let observation = platform.observe(source: source) { recorder.record($0) }

    observation.cancel()
    observation.cancel()
    source.notify(status: .disconnected)

    #expect(source.registrationCount == 1)
    #expect(source.unregistrationCount == 1)
    #expect(recorder.statuses.isEmpty)
  }

  @Test("production identities fail closed while both injected host seams compile")
  func hostIdentitySeams() throws {
    #expect(throws: VPNManagerRepositoryError.productionIdentityUnavailable(.iOS)) {
      try IOSHostVPNRepository.production()
    }
    #expect(throws: VPNManagerRepositoryError.productionIdentityUnavailable(.macOS)) {
      try MacOSHostVPNRepository.production()
    }
    _ = try IOSHostVPNRepository.make(identity: identity(platform: .iOS))
    _ = try MacOSHostVPNRepository.make(identity: identity(platform: .macOS))
    #expect(throws: VPNManagerRepositoryError.invalidPlatformIdentity) {
      try IOSHostVPNRepository.make(identity: identity(platform: .macOS))
    }
  }

  @Test("fresh session handoff reuses exact ownership and current-schema validation")
  func freshSessionHandoffUsesRepositoryAuthority() async throws {
    let session = RepositoryHostSessionStub()
    let manager = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, enabled: true),
      hostSession: session
    )
    let client = FakeVPNPreferencesClient(managers: [manager])
    let repository = OwnedVPNManagerRepository(identity: try identity(), client: client)

    let fresh = try await repository.loadFreshOwnedSession(requireEnabled: true)
    #expect(ObjectIdentifier(fresh.session) == ObjectIdentifier(session))
    #expect(
      fresh.configurationReference == TunnelConfigurationReference(profileIdentifier: profileID))
    #expect(fresh.isEnabled)
    #expect(client.loadCount == 1)

    let disabled = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID, enabled: false),
      hostSession: session
    )
    let disabledRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [disabled])
    )
    await #expect(throws: VPNManagerRepositoryError.configurationDisabled) {
      try await disabledRepository.loadFreshOwnedSession(requireEnabled: true)
    }
    #expect(disabled.totalMutationCount == 0)

    let controller = VPNSessionController(repository: disabledRepository)
    await #expect(throws: VPNSessionControllerError.configurationDisabled) {
      try await controller.start()
    }
    #expect(session.startCount == 0)
    #expect(disabled.totalMutationCount == 0)
  }

  @Test(
    "iOS and macOS start adapters normalize public NEVPN errors and preserve unknown errors",
    arguments: AppleVPNStartAdapterSeam.allCases
  )
  func hostStartAdaptersNormalizeErrors(_ seam: AppleVPNStartAdapterSeam) throws {
    let knownCases: [(code: Int, kind: VPNPreferencePlatformError.Kind)] = [
      (NEVPNError.configurationInvalid.rawValue, .configurationInvalid),
      (NEVPNError.configurationDisabled.rawValue, .configurationDisabled),
      (NEVPNError.connectionFailed.rawValue, .connectionFailed),
    ]

    for knownCase in knownCases {
      let source = NSError(domain: NEVPNErrorDomain, code: knownCase.code)
      #expect(
        throws: VPNPreferencePlatformError(
          kind: knownCase.kind,
          domain: NEVPNErrorDomain,
          code: knownCase.code
        )
      ) {
        try seam.start { throw source }
      }
    }

    let unknown = NSError(domain: "works.relux.tests.start", code: 8_675_309)
    #expect(
      throws: VPNPreferencePlatformError(
        kind: .other,
        domain: unknown.domain,
        code: unknown.code
      )
    ) {
      try seam.start { throw unknown }
    }
  }

  private func identity(
    platform: PlatformVPNIdentity.Platform = .macOS
  ) throws -> PlatformVPNIdentity {
    try PlatformVPNIdentity(
      platform: platform,
      hostBundleIdentifier: "works.relux.test.host",
      providerBundleIdentifier: "works.relux.test.provider",
      appGroupIdentifier: "group.works.relux.test",
      keychainAccessGroup: "works.relux.test.keychain"
    )
  }

  private func ownedSnapshot(
    profileID: OpaqueProfileIdentifier,
    enabled: Bool = false,
    serverAddress: String = OwnedVPNManagerRepository.serverAddressSentinel,
    managerVersion: Int = OwnedVPNManagerRepository.managerContractVersion,
    managerVersionValue: VPNProviderConfigurationValue? = nil,
    referenceValue: VPNProviderConfigurationValue? = nil,
    extraConfiguration: [String: VPNProviderConfigurationValue] = [:],
    sessionStatus: VPNManagerSessionStatus = .disconnected
  ) throws -> VPNManagerSnapshot {
    let encoded = try RuntimeConfigurationCodec.encode(
      TunnelConfigurationReference(profileIdentifier: profileID)
    )
    var configuration: [String: VPNProviderConfigurationValue] = [
      OwnedVPNManagerRepository.ownerKey: .string(OwnedVPNManagerRepository.ownerValue),
      OwnedVPNManagerRepository.managerContractKey: managerVersionValue ?? .integer(managerVersion),
      OwnedVPNManagerRepository.configurationReferenceKey: referenceValue ?? .data(encoded),
    ]
    configuration.merge(extraConfiguration) { _, new in new }
    return VPNManagerSnapshot(
      protocolKind: .tunnelProvider,
      providerBundleIdentifier: try identity().providerBundleIdentifier,
      serverAddress: serverAddress,
      providerConfiguration: configuration,
      localizedDescription: "Relux Tunnel",
      isEnabled: enabled,
      sessionStatus: sessionStatus
    )
  }

  private func assertExactPlatformVersionDecoding(
    boolean: VPNProviderConfigurationValue,
    fractional: VPNProviderConfigurationValue,
    unsignedMaximum: VPNProviderConfigurationValue,
    integerMaximum: VPNProviderConfigurationValue,
    current: VPNProviderConfigurationValue
  ) async throws {
    #expect(boolean == .unsupported)
    #expect(fractional == .unsupported)
    #expect(unsignedMaximum == .unsignedInteger(UInt64.max))
    #expect(integerMaximum == .integer(Int.max))
    #expect(current == .integer(OwnedVPNManagerRepository.managerContractVersion))

    for (versionValue, expectedError) in [
      (boolean, VPNManagerRepositoryError.ownedConfigurationCorrupt),
      (fractional, VPNManagerRepositoryError.ownedConfigurationCorrupt),
      (
        unsignedMaximum,
        VPNManagerRepositoryError.updateRequired(.unsignedInteger(UInt64.max))
      ),
    ] {
      for operation in QueuedRepositoryOperation.allCases {
        let manager = FakeVPNPreferencesManager(
          snapshot: try ownedSnapshot(
            profileID: profileID,
            managerVersionValue: versionValue
          )
        )
        let repository = OwnedVPNManagerRepository(
          identity: try identity(),
          client: FakeVPNPreferencesClient(managers: [manager])
        )

        await #expect(throws: expectedError) {
          try await perform(operation, on: repository)
        }
        #expect(manager.totalMutationCount == 0)
      }
    }

    let future = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(
        profileID: profileID,
        managerVersionValue: unsignedMaximum
      )
    )
    let currentManager = FakeVPNPreferencesManager(
      snapshot: try ownedSnapshot(profileID: profileID)
    )
    let repairRepository = OwnedVPNManagerRepository(
      identity: try identity(),
      client: FakeVPNPreferencesClient(managers: [future, currentManager])
    )
    await #expect(throws: VPNManagerRepositoryError.futureOwnedConfigurationConflict) {
      try await repairRepository.repairDuplicateOwnedManagers(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
    #expect(future.totalMutationCount == 0)
    #expect(currentManager.totalMutationCount == 0)
  }

  private func perform(
    _ operation: QueuedRepositoryOperation,
    on repository: OwnedVPNManagerRepository
  ) async throws {
    switch operation {
    case .ensure:
      _ = try await repository.ensure(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    case .enable:
      _ = try await repository.enableOwnedManager()
    case .disable:
      _ = try await repository.disableOwnedManager()
    case .remove:
      try await repository.removeOwnedManager()
    case .repair:
      _ = try await repository.repairDuplicateOwnedManagers(
        profileIdentifier: profileID,
        localizedDescription: "Relux Tunnel"
      )
    }
  }

  private func platformError(
    _ kind: VPNPreferencePlatformError.Kind,
    domain: String = "NEVPNErrorDomain",
    code: Int = 4
  ) -> VPNPreferencePlatformError {
    VPNPreferencePlatformError(kind: kind, domain: domain, code: code)
  }
}

private enum QueuedRepositoryOperation: String, CaseIterable, CustomStringConvertible {
  case ensure
  case enable
  case disable
  case remove
  case repair

  var description: String { rawValue }
}

enum AppleVPNStatusObservationSeam: String, CaseIterable, Sendable,
  CustomTestStringConvertible
{
  case iOS
  case macOS

  var testDescription: String { rawValue }

  func observe(
    source: FakeVPNStatusSource,
    completion: @escaping @Sendable (VPNManagerSessionStatus) -> Void
  ) -> any VPNPreferenceObservation {
    switch self {
    case .iOS:
      IOSVPNStatusObservation(
        status: { source.readStatus() },
        register: { source.register($0) },
        unregister: { source.unregister($0) },
        completion: completion
      )
    case .macOS:
      MacOSVPNStatusObservation(
        status: { source.readStatus() },
        register: { source.register($0) },
        unregister: { source.unregister($0) },
        completion: completion
      )
    }
  }
}

enum AppleVPNStartAdapterSeam: String, CaseIterable, Sendable,
  CustomTestStringConvertible
{
  case iOS
  case macOS

  var testDescription: String { rawValue }

  func start(_ operation: () throws -> Void) throws {
    switch self {
    case .iOS: try IOSVPNHostSessionStartAdapter.start(operation)
    case .macOS: try MacOSVPNHostSessionStartAdapter.start(operation)
    }
  }
}

final class FakeVPNStatusSource: @unchecked Sendable {
  enum RegistrationTransition: Sendable {
    case none
    case terminalWithoutNotification
    case terminalWithNotification
  }

  enum Event: Equatable, Sendable {
    case registrationStarted
    case registrationReturned
    case statusRead
  }

  private final class Token: NSObject {}

  private let lock = NSLock()
  private let token = Token()
  private let registrationTransition: RegistrationTransition
  private var status: VPNManagerSessionStatus
  private var callback: (@Sendable () -> Void)?
  private var _events: [Event] = []
  private var _registrationCount = 0
  private var _unregistrationCount = 0

  init(
    status: VPNManagerSessionStatus,
    registrationTransition: RegistrationTransition = .none
  ) {
    self.status = status
    self.registrationTransition = registrationTransition
  }

  var events: [Event] { lock.withLock { _events } }
  var registrationCount: Int { lock.withLock { _registrationCount } }
  var unregistrationCount: Int { lock.withLock { _unregistrationCount } }

  func readStatus() -> VPNManagerSessionStatus {
    lock.withLock {
      _events.append(.statusRead)
      return status
    }
  }

  func register(_ callback: @escaping @Sendable () -> Void) -> any NSObjectProtocol {
    let synchronousNotification = lock.withLock { () -> Bool in
      _events.append(.registrationStarted)
      _registrationCount += 1
      self.callback = callback
      switch registrationTransition {
      case .none:
        return false
      case .terminalWithoutNotification:
        status = .disconnected
        return false
      case .terminalWithNotification:
        status = .disconnected
        return true
      }
    }
    if synchronousNotification { callback() }
    lock.withLock { _events.append(.registrationReturned) }
    return token
  }

  func unregister(_ token: any NSObjectProtocol) {
    _ = token
    lock.withLock { _unregistrationCount += 1 }
  }

  func notify(status: VPNManagerSessionStatus) {
    let callback = lock.withLock {
      self.status = status
      return self.callback
    }
    callback?()
  }
}

final class VPNStatusRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var recorded: [VPNManagerSessionStatus] = []

  var statuses: [VPNManagerSessionStatus] { lock.withLock { recorded } }

  func record(_ status: VPNManagerSessionStatus) {
    lock.withLock { recorded.append(status) }
  }
}

private struct ImmediateTimeoutClock: TunnelClock {
  func now() -> ContinuousClock.Instant { ContinuousClock().now }
  func sleep(for duration: Duration) async throws {}
}

private final class FakeVPNPreferenceObservation: VPNPreferenceObservation, @unchecked Sendable {
  private let onCancel: @Sendable () -> Void
  init(onCancel: @escaping @Sendable () -> Void = {}) { self.onCancel = onCancel }
  func cancel() { onCancel() }
}

private final class FakeVPNPreferencesClient: VPNPreferencesClient, @unchecked Sendable {
  enum LoadBehavior: Sendable {
    case current
    case noCollection
    case failure(VPNPreferencePlatformError)
    case deferred
  }

  private let lock = NSLock()
  private var managers: [FakeVPNPreferencesManager]
  private var deferredLoads:
    [@Sendable (Result<[any VPNPreferencesManager]?, VPNPreferencePlatformError>) -> Void] = []
  private var _loadBehaviors: [LoadBehavior] = []
  private var _createdManagers: [FakeVPNPreferencesManager] = []
  private var _makeManagerCount = 0
  private var _loadCount = 0
  private var loadCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
  private var _persistedSnapshotOverride: VPNManagerSnapshot?

  init(managers: [FakeVPNPreferencesManager] = []) {
    self.managers = managers
    for manager in managers { manager.client = self }
  }

  var loadBehaviors: [LoadBehavior] {
    get { lock.withLock { _loadBehaviors } }
    set { lock.withLock { _loadBehaviors = newValue } }
  }

  var createdManagers: [FakeVPNPreferencesManager] {
    lock.withLock { _createdManagers }
  }

  var makeManagerCount: Int { lock.withLock { _makeManagerCount } }
  var loadCount: Int { lock.withLock { _loadCount } }
  var currentManagers: [FakeVPNPreferencesManager] { lock.withLock { managers } }

  var persistedSnapshotOverride: VPNManagerSnapshot? {
    get { lock.withLock { _persistedSnapshotOverride } }
    set { lock.withLock { _persistedSnapshotOverride = newValue } }
  }

  func loadAllFromPreferences(
    completion:
      @escaping @Sendable (
        Result<[any VPNPreferencesManager]?, VPNPreferencePlatformError>
      ) -> Void
  ) {
    let (action, readyWaiters): (LoadBehavior, [CheckedContinuation<Void, Never>]) = lock.withLock {
      _loadCount += 1
      let ready = loadCountWaiters.filter { _loadCount >= $0.0 }.map(\.1)
      loadCountWaiters.removeAll { _loadCount >= $0.0 }
      return (
        _loadBehaviors.isEmpty ? .current : _loadBehaviors.removeFirst(),
        ready
      )
    }
    for waiter in readyWaiters { waiter.resume() }
    switch action {
    case .current:
      let current: [any VPNPreferencesManager] = lock.withLock { managers.map { $0 } }
      completion(.success(current))
    case .noCollection:
      completion(.success(nil))
    case .failure(let error):
      completion(.failure(error))
    case .deferred:
      lock.withLock { deferredLoads.append(completion) }
    }
  }

  func waitForLoadCount(_ count: Int) async {
    await withCheckedContinuation { continuation in
      let alreadyReached = lock.withLock { () -> Bool in
        guard _loadCount < count else { return true }
        loadCountWaiters.append((count, continuation))
        return false
      }
      if alreadyReached { continuation.resume() }
    }
  }

  func makeManager() -> any VPNPreferencesManager {
    let manager = FakeVPNPreferencesManager(snapshot: .init(protocolKind: .none))
    manager.client = self
    lock.withLock {
      _makeManagerCount += 1
      _createdManagers.append(manager)
    }
    return manager
  }

  func persist(_ manager: FakeVPNPreferencesManager) {
    let snapshot = lock.withLock { _persistedSnapshotOverride } ?? manager.snapshot
    let reloaded = FakeVPNPreferencesManager(snapshot: snapshot)
    reloaded.client = self
    lock.withLock {
      if let index = managers.firstIndex(where: { $0 === manager }) {
        managers[index] = reloaded
      } else {
        managers.append(reloaded)
      }
    }
  }

  func remove(_ manager: FakeVPNPreferencesManager) {
    lock.withLock { managers.removeAll { $0 === manager } }
  }

  func replaceManagers(_ managers: [FakeVPNPreferencesManager]) {
    for manager in managers { manager.client = self }
    lock.withLock { self.managers = managers }
  }

  func completeDeferredLoads(
    with result: Result<[any VPNPreferencesManager]?, VPNPreferencePlatformError>
  ) {
    let callbacks = lock.withLock {
      let callbacks = deferredLoads
      deferredLoads.removeAll()
      return callbacks
    }
    for callback in callbacks {
      callback(result)
    }
  }
}

private final class FakeVPNPreferencesManager: VPNPreferencesManager, @unchecked Sendable {
  private let lock = NSLock()
  weak var client: FakeVPNPreferencesClient?
  private var state: VPNManagerSnapshot
  private var _applyCount = 0
  private var _enabledSetterCount = 0
  private var _saveCount = 0
  private var _removeCount = 0
  private var _stopCount = 0
  private var _saveErrors: [VPNPreferencePlatformError?] = []
  private var _removeErrors: [VPNPreferencePlatformError?] = []
  private var terminalObservers: [@Sendable (VPNManagerSessionStatus) -> Void] = []
  let hostSession: (any VPNHostSession)?

  var statusAfterStop: VPNManagerSessionStatus?
  var onSave: (@Sendable (VPNPreferencePlatformError?) -> Void)?

  init(
    snapshot: VPNManagerSnapshot,
    hostSession: (any VPNHostSession)? = nil
  ) {
    state = snapshot
    self.hostSession = hostSession
  }

  var snapshot: VPNManagerSnapshot { lock.withLock { state } }
  var applyCount: Int { lock.withLock { _applyCount } }
  var enabledSetterCount: Int { lock.withLock { _enabledSetterCount } }
  var saveCount: Int { lock.withLock { _saveCount } }
  var removeCount: Int { lock.withLock { _removeCount } }
  var stopCount: Int { lock.withLock { _stopCount } }
  var totalMutationCount: Int {
    applyCount + enabledSetterCount + saveCount + removeCount + stopCount
  }

  var saveErrors: [VPNPreferencePlatformError?] {
    get { lock.withLock { _saveErrors } }
    set { lock.withLock { _saveErrors = newValue } }
  }

  func applyCanonicalConfiguration(_ configuration: CanonicalVPNManagerConfiguration) {
    lock.withLock {
      _applyCount += 1
      state = VPNManagerSnapshot(
        protocolKind: .tunnelProvider,
        providerBundleIdentifier: configuration.providerBundleIdentifier,
        serverAddress: configuration.serverAddress,
        disconnectOnSleep: configuration.disconnectOnSleep,
        includeAllNetworks: configuration.includeAllNetworks,
        excludeLocalNetworks: configuration.excludeLocalNetworks,
        enforceRoutes: configuration.enforceRoutes,
        providerConfiguration: configuration.providerConfiguration,
        localizedDescription: configuration.localizedDescription,
        isEnabled: state.isEnabled,
        sessionStatus: state.sessionStatus
      )
    }
  }

  func setEnabled(_ enabled: Bool) {
    lock.withLock {
      _enabledSetterCount += 1
      state = copy(state, enabled: enabled)
    }
  }

  func saveToPreferences(
    completion: @escaping @Sendable (VPNPreferencePlatformError?) -> Void
  ) {
    let error: VPNPreferencePlatformError? = lock.withLock {
      _saveCount += 1
      return _saveErrors.isEmpty ? nil : _saveErrors.removeFirst()
    }
    onSave?(error)
    if error == nil { client?.persist(self) }
    completion(error)
  }

  func removeFromPreferences(
    completion: @escaping @Sendable (VPNPreferencePlatformError?) -> Void
  ) {
    let error: VPNPreferencePlatformError? = lock.withLock {
      _removeCount += 1
      return _removeErrors.isEmpty ? nil : _removeErrors.removeFirst()
    }
    if error == nil { client?.remove(self) }
    completion(error)
  }

  func stopTunnel() {
    let transition = lock.withLock { () -> VPNManagerSessionStatus? in
      _stopCount += 1
      return statusAfterStop
    }
    if let transition { transitionStatus(to: transition) }
  }

  func observeTerminalStatus(
    completion: @escaping @Sendable (VPNManagerSessionStatus) -> Void
  ) -> any VPNPreferenceObservation {
    let status = snapshot.sessionStatus
    if status.isTerminal {
      completion(status)
    } else {
      lock.withLock { terminalObservers.append(completion) }
    }
    return FakeVPNPreferenceObservation()
  }

  private func transitionStatus(to status: VPNManagerSessionStatus) {
    let observers: [@Sendable (VPNManagerSessionStatus) -> Void] = lock.withLock {
      state = copy(state, sessionStatus: status)
      guard status.isTerminal else { return [] }
      let observers = terminalObservers
      terminalObservers.removeAll()
      return observers
    }
    for observer in observers {
      observer(status)
    }
  }

  private func copy(
    _ value: VPNManagerSnapshot,
    enabled: Bool? = nil,
    sessionStatus: VPNManagerSessionStatus? = nil
  ) -> VPNManagerSnapshot {
    VPNManagerSnapshot(
      protocolKind: value.protocolKind,
      providerBundleIdentifier: value.providerBundleIdentifier,
      serverAddress: value.serverAddress,
      disconnectOnSleep: value.disconnectOnSleep,
      includeAllNetworks: value.includeAllNetworks,
      excludeLocalNetworks: value.excludeLocalNetworks,
      enforceRoutes: value.enforceRoutes,
      providerConfiguration: value.providerConfiguration,
      localizedDescription: value.localizedDescription,
      isEnabled: enabled ?? value.isEnabled,
      isOnDemandEnabled: value.isOnDemandEnabled,
      hasOnDemandRules: value.hasOnDemandRules,
      hasAppRules: value.hasAppRules,
      sessionStatus: sessionStatus ?? value.sessionStatus
    )
  }
}

private final class RepositoryHostSessionStub: VPNHostSession, @unchecked Sendable {
  private let lock = NSLock()
  private var _startCount = 0

  var status: VPNManagerSessionStatus { .disconnected }
  var startCount: Int { lock.withLock { _startCount } }

  func startTunnel(options: [String: Data]) throws {
    lock.withLock { _startCount += 1 }
  }
  func stopTunnel() {}
  func sendProviderMessage(
    _ message: Data,
    responseHandler: @escaping @Sendable (Data?) -> Void
  ) throws {
    responseHandler(nil)
  }
  func fetchLastDisconnectError(
    completion: @escaping @Sendable (VPNPlatformError?) -> Void
  ) {
    completion(nil)
  }
  func observeStatusChanges(
    notification: @escaping @Sendable () -> Void
  ) -> any VPNPreferenceObservation {
    FakeVPNPreferenceObservation()
  }
}
