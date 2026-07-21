import Foundation
import Synchronization
import Testing

@testable import ReluxTunnelCore

@Suite("Client UDP association registry")
struct ClientUDPAssociationRegistryTests {
  @Test("configuration and lifecycle table cover every bounded state transition")
  func configurationAndTransitionTable() throws {
    let configuration = try ClientUDPAssociationRegistryConfiguration()
    #expect(configuration.maximumAssociations == 256)
    #expect(configuration.allocatorSearchLimit == 256)
    #expect(configuration.idleTimeoutMilliseconds == 60_000)

    #expect(throws: ClientUDPAssociationConfigurationError.maximumAssociationsOutOfRange) {
      _ = try ClientUDPAssociationRegistryConfiguration(maximumAssociations: 0)
    }
    #expect(throws: ClientUDPAssociationConfigurationError.maximumAssociationsOutOfRange) {
      _ = try ClientUDPAssociationRegistryConfiguration(maximumAssociations: 1_025)
    }
    #expect(throws: ClientUDPAssociationConfigurationError.allocatorSearchLimitOutOfRange) {
      _ = try ClientUDPAssociationRegistryConfiguration(allocatorSearchLimit: 0)
    }
    #expect(throws: ClientUDPAssociationConfigurationError.allocatorSearchLimitOutOfRange) {
      _ = try ClientUDPAssociationRegistryConfiguration(allocatorSearchLimit: 1_025)
    }
    #expect(throws: ClientUDPAssociationConfigurationError.idleTimeoutOutOfRange) {
      _ = try ClientUDPAssociationRegistryConfiguration(idleTimeoutMilliseconds: 9_999)
    }

    let table = ClientUDPAssociationTransitions.v1
    #expect(table.count == 41)
    #expect(
      table.contains(
        .init(event: .admission, from: nil, to: .active, releasesIdentifier: false)
      )
    )
    #expect(
      table.contains(
        .init(
          event: .localClose,
          from: .active,
          to: .closing,
          releasesIdentifier: false
        )
      )
    )
    #expect(
      table.contains(
        .init(
          event: .idleExpiry,
          from: .active,
          to: .expired,
          releasesIdentifier: false
        )
      )
    )
    #expect(
      table.contains(
        .init(
          event: .expiryCompleted,
          from: .expired,
          to: .closing,
          releasesIdentifier: false
        )
      )
    )
    for state in ClientUDPAssociationState.allCases {
      #expect(
        table.contains(
          .init(event: .remoteClose, from: state, to: .closed, releasesIdentifier: true)
        )
      )
      #expect(
        table.contains(
          .init(event: .sessionLoss, from: state, to: .closed, releasesIdentifier: true)
        )
      )
      #expect(
        table.contains(
          .init(
            event: .sessionReplacement,
            from: state,
            to: .closed,
            releasesIdentifier: true
          )
        )
      )
      #expect(
        table.contains(
          .init(event: .cancellation, from: state, to: .closed, releasesIdentifier: true)
        )
      )
      #expect(
        table.contains(
          .init(event: .providerStop, from: state, to: .closed, releasesIdentifier: true)
        )
      )
    }
  }

  @Test("admission is unique nonzero idempotent and rejects before wire at the cap")
  func boundedAdmission() async throws {
    let clock = ManualAssociationClock()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 7,
      configuration: try configuration(maximumAssociations: 2),
      clock: clock
    )

    let first = try await registry.admit(11, generation: 7).get()
    let second = try await registry.admit(12, generation: 7).get()
    let duplicate = try await registry.admit(11, generation: 7).get()
    #expect(first.associationID != 0)
    #expect(second.associationID != 0)
    #expect(first.associationID != second.associationID)
    #expect(duplicate == first)

    let rejection = try failure(await registry.admit(13, generation: 7))
    #expect(rejection.reason == .associationLimit)
    #expect(!rejection.shouldWriteRelayBytes)
    let stale = try failure(await registry.admit(13, generation: 6))
    #expect(stale.reason == .staleGeneration)

    let snapshot = await registry.snapshot()
    #expect(snapshot.associationCount == 2)
    #expect(snapshot.activeAssociations == 2)
    #expect(snapshot.scheduledTimers == 2)
    #expect(snapshot.metrics.admitted == 2)
    #expect(snapshot.metrics.admissionRejected == 2)
    await expectClock(clock, pendingSleeps: 2, outstandingSleepTasks: 2)
    await registry.stopProvider()
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
  }

  @Test("wraparound and collision search are bounded and closing ids are not reused")
  func wraparoundCollisionAndReuse() async throws {
    let recorder = AssociationCleanupRecorder()
    let clock = ManualAssociationClock()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 20,
      configuration: try configuration(maximumAssociations: 4, searchLimit: 3),
      clock: clock,
      callbacks: recorder.callbacks,
      initialAssociationIDForTesting: UInt32.max
    )

    let maximum = try await registry.admit(1, generation: 20).get()
    let one = try await registry.admit(2, generation: 20).get()
    let two = try await registry.admit(3, generation: 20).get()
    #expect(maximum.associationID == UInt32.max)
    #expect(one.associationID == 1)
    #expect(two.associationID == 2)
    #expect(await registry.snapshot().metrics.identifierWraparounds == 1)
    await expectClock(clock, pendingSleeps: 3, outstandingSleepTasks: 3)

    #expect(
      await registry.closeLocally(maximum)
        == .applied(key: maximum, from: .active, to: .closing)
    )
    await expectClock(clock, pendingSleeps: 2, outstandingSleepTasks: 2)
    await registry.setNextAssociationIDForTesting(UInt32.max)
    let exhausted = try failure(await registry.admit(4, generation: 20))
    #expect(exhausted.reason == .allocatorSearchExhausted)
    let afterCollision = await registry.snapshot()
    #expect(afterCollision.metrics.allocationCollisions == 3)
    #expect(afterCollision.associationCount == 3)

    #expect(
      await registry.receiveRemoteClose(
        associationID: maximum.associationID,
        generation: 20
      ) == .applied(key: maximum, from: .closing, to: .closed)
    )
    await registry.setNextAssociationIDForTesting(UInt32.max)
    let reused = try await registry.admit(4, generation: 20).get()
    #expect(reused.associationID == maximum.associationID)
    #expect(reused.allocation != maximum.allocation)
    #expect(await registry.recordActivity(for: maximum) == .ignoredUnknownAssociation)
    #expect(await registry.key(for: 4, generation: 20) == reused)
    await expectClock(clock, pendingSleeps: 3, outstandingSleepTasks: 3)
    await registry.stopProvider()
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
  }

  @Test("duplicate and crossed close paths invoke HEV and relay cleanup once")
  func duplicateAndCrossedClose() async throws {
    let recorder = AssociationCleanupRecorder()
    let clock = ManualAssociationClock()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 30,
      configuration: try configuration(maximumAssociations: 2),
      clock: clock,
      callbacks: recorder.callbacks
    )
    let localFirst = try await registry.admit(10, generation: 30).get()

    #expect(
      await registry.closeLocally(localFirst)
        == .applied(key: localFirst, from: .active, to: .closing)
    )
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
    #expect(await registry.closeLocally(localFirst) == .ignoredState(.closing))
    #expect(
      await registry.receiveRemoteClose(
        associationID: localFirst.associationID,
        generation: 30
      ) == .applied(key: localFirst, from: .closing, to: .closed)
    )
    #expect(
      await registry.receiveRemoteClose(
        associationID: localFirst.associationID,
        generation: 30
      ) == .ignoredUnknownAssociation
    )

    let remoteFirst = try await registry.admit(11, generation: 30).get()
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)
    #expect(
      await registry.receiveRemoteClose(
        associationID: remoteFirst.associationID,
        generation: 30
      ) == .applied(key: remoteFirst, from: .active, to: .closed)
    )
    #expect(
      await registry.receiveRemoteClose(
        associationID: remoteFirst.associationID,
        generation: 30
      ) == .ignoredUnknownAssociation
    )

    let cleanup = recorder.snapshot()
    #expect(cleanup.hev.count == 2)
    #expect(cleanup.relay.count == 2)
    #expect(cleanup.hev.map(\.reason) == [.localClose, .remoteClose])
    #expect(cleanup.relay.allSatisfy { $0.shouldSendClose })
    let snapshot = await registry.snapshot()
    #expect(snapshot.associationCount == 0)
    #expect(snapshot.scheduledTimers == 0)
    #expect(snapshot.metrics.hevCleanupCallbacks == 2)
    #expect(snapshot.metrics.relayCleanupCallbacks == 2)
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
  }

  @Test("activity rearms the fake-clock timer and expiry retains id until close ack")
  func activityExpiryAndCompletion() async throws {
    let clock = ManualAssociationClock()
    let recorder = AssociationCleanupRecorder()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 40,
      configuration: try configuration(maximumAssociations: 1, idleMilliseconds: 10_000),
      clock: clock,
      callbacks: recorder.callbacks
    )
    let key = try await registry.admit(100, generation: 40).get()
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)

    clock.advance(by: .seconds(5))
    #expect(
      await registry.recordActivity(for: key) == .applied(key: key, from: .active, to: .active))
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)
    clock.advance(by: .seconds(9))
    await Task.yield()
    #expect(await registry.snapshot().activeAssociations == 1)

    clock.advance(by: .seconds(1))
    await waitUntil { await registry.snapshot().expiredAssociations == 1 }
    var snapshot = await registry.snapshot()
    #expect(snapshot.scheduledTimers == 0)
    #expect(snapshot.metrics.idleExpired == 1)
    #expect(recorder.snapshot().hev.map(\.reason) == [.idleExpiry])
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)

    #expect(
      await registry.completeExpiry(for: key)
        == .applied(key: key, from: .expired, to: .closing)
    )
    snapshot = await registry.snapshot()
    #expect(snapshot.closingAssociations == 1)
    #expect(snapshot.associationCount == 1)

    #expect(
      await registry.receiveRemoteClose(associationID: key.associationID, generation: 40)
        == .applied(key: key, from: .closing, to: .closed)
    )
    snapshot = await registry.snapshot()
    #expect(snapshot.associationCount == 0)
    #expect(snapshot.scheduledTimers == 0)
    #expect(recorder.snapshot().hev.count == 1)
    #expect(recorder.snapshot().relay.count == 1)
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
  }

  @Test("a completed stale timer arm cannot displace the refreshed timer")
  func staleTimerArmCannotReplaceCurrentTimer() async throws {
    let clock = ManualAssociationClock()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 42,
      configuration: try configuration(maximumAssociations: 1, idleMilliseconds: 10_000),
      clock: clock
    )
    let key = try await registry.admit(101, generation: 42).get()
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)

    #expect(
      clock.installPostWakeActionForOnlyPendingSleep {
        _ = await registry.recordActivity(for: key)
      }
    )
    clock.advance(by: .seconds(10))

    await waitUntil { await registry.snapshot().metrics.staleTimerCallbacks == 1 }
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)
    let snapshot = await registry.snapshot()
    #expect(snapshot.activeAssociations == 1)
    #expect(snapshot.scheduledTimers == 1)
    #expect(snapshot.metrics.activityUpdates == 1)

    _ = await registry.closeLocally(key)
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
  }

  @Test("repeated activity churn retains exactly one real sleeper")
  func repeatedActivityKeepsOneSleeper() async throws {
    let clock = ManualAssociationClock()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 43,
      configuration: try configuration(maximumAssociations: 1),
      clock: clock
    )
    let key = try await registry.admit(102, generation: 43).get()

    for _ in 0..<100 {
      #expect(
        await registry.recordActivity(for: key)
          == .applied(key: key, from: .active, to: .active)
      )
      await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)
    }

    _ = await registry.closeLocally(key)
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
  }

  @Test("control observation validates identity and state without refreshing activity")
  func controlObservationDoesNotRefreshActivity() async throws {
    let clock = ManualAssociationClock()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 44,
      configuration: try configuration(maximumAssociations: 1),
      clock: clock
    )
    let key = try await registry.admit(103, generation: 44).get()
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)

    switch await registry.observeActiveAssociation(
      associationID: key.associationID,
      generation: 44
    ) {
    case .resolved(let handle, let observedKey):
      #expect(handle == 103)
      #expect(observedKey == key)
    default:
      Issue.record("active association was not observed")
    }
    var snapshot = await registry.snapshot()
    #expect(snapshot.metrics.activityUpdates == 0)
    #expect(snapshot.scheduledTimers == 1)
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)

    switch await registry.observeActiveAssociation(
      associationID: key.associationID,
      generation: 43
    ) {
    case .staleGeneration:
      break
    default:
      Issue.record("stale-generation observation was not rejected")
    }
    switch await registry.observeActiveAssociation(
      associationID: key.associationID + 1,
      generation: 44
    ) {
    case .unknownAssociation:
      break
    default:
      Issue.record("unknown-association observation was not rejected")
    }
    _ = await registry.closeLocally(key)
    switch await registry.observeActiveAssociation(
      associationID: key.associationID,
      generation: 44
    ) {
    case .unavailable(.closing):
      break
    default:
      Issue.record("closing association was not reported unavailable")
    }

    snapshot = await registry.snapshot()
    #expect(snapshot.metrics.activityUpdates == 0)
    #expect(snapshot.metrics.staleEvents == 1)
    #expect(snapshot.metrics.lateEvents == 2)
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
  }

  @Test("expiry activity and remote-close race has one terminal cleanup")
  func expiryRace() async throws {
    let clock = ManualAssociationClock()
    let recorder = AssociationCleanupRecorder()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 45,
      configuration: try configuration(maximumAssociations: 1, idleMilliseconds: 10_000),
      clock: clock,
      callbacks: recorder.callbacks
    )
    let key = try await registry.admit(200, generation: 45).get()
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)
    clock.advance(by: .seconds(10))

    await withTaskGroup(of: Void.self) { group in
      group.addTask { _ = await registry.recordActivity(for: key) }
      group.addTask {
        _ = await registry.receiveRemoteClose(
          associationID: key.associationID,
          generation: 45
        )
      }
      for await _ in group {}
    }
    await Task.yield()

    let snapshot = await registry.snapshot()
    #expect(snapshot.associationCount == 0)
    #expect(snapshot.scheduledTimers == 0)
    #expect(snapshot.metrics.hevCleanupCallbacks == 1)
    #expect(snapshot.metrics.relayCleanupCallbacks == 1)
    #expect(snapshot.metrics.terminalCleanups == 1)
    #expect(recorder.snapshot().hev.count == 1)
    #expect(recorder.snapshot().relay.count == 1)
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
  }

  @Test("old-generation timer reply error and close cannot resolve a reused numeric id")
  func staleGenerationIsolation() async throws {
    let clock = ManualAssociationClock()
    let recorder = AssociationCleanupRecorder()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 50,
      configuration: try configuration(maximumAssociations: 1, idleMilliseconds: 10_000),
      clock: clock,
      callbacks: recorder.callbacks
    )
    let old = try await registry.admit(1, generation: 50).get()
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)
    clock.advance(by: .seconds(5))

    #expect(await registry.activateGeneration(51) == .activated(51))
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
    let current = try await registry.admit(2, generation: 51).get()
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)
    #expect(current.associationID == old.associationID)
    #expect(current.allocation != old.allocation)
    #expect(await registry.recordActivity(for: old) == .ignoredStaleGeneration)
    #expect(
      await registry.receiveRemoteError(associationID: old.associationID, generation: 50)
        == .ignoredStaleGeneration
    )
    #expect(
      await registry.receiveRemoteClose(associationID: old.associationID, generation: 50)
        == .ignoredStaleGeneration
    )
    switch await registry.resolveRemoteDatagram(
      associationID: old.associationID,
      generation: 50
    ) {
    case .staleGeneration:
      break
    default:
      Issue.record("old-generation reply unexpectedly resolved")
    }

    // Pass the old deadline while remaining before the new generation's.
    clock.advance(by: .seconds(6))
    await Task.yield()
    #expect(await registry.key(for: 2, generation: 51) == current)
    let snapshot = await registry.snapshot()
    #expect(snapshot.activeAssociations == 1)
    #expect(snapshot.metrics.staleEvents >= 4)
    await registry.stopProvider()
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
    #expect(recorder.snapshot().hev.count == 2)
  }

  @Test("session loss cancellation and provider stop return all owned resources to baseline")
  func terminalGenerationCleanup() async throws {
    let recorder = AssociationCleanupRecorder()
    let clock = ManualAssociationClock()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 60,
      configuration: try configuration(maximumAssociations: 3),
      clock: clock,
      callbacks: recorder.callbacks
    )
    let closing = try await registry.admit(1, generation: 60).get()
    let errored = try await registry.admit(2, generation: 60).get()
    await expectClock(clock, pendingSleeps: 2, outstandingSleepTasks: 2)
    _ = await registry.closeLocally(closing)
    _ = await registry.receiveRemoteError(
      associationID: errored.associationID,
      generation: 60
    )
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
    await registry.sessionLost(generation: 60)
    await expectBaseline(registry, clock: clock)

    #expect(await registry.activateGeneration(61) == .activated(61))
    _ = try await registry.admit(3, generation: 61).get()
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)
    await registry.cancel(generation: 61)
    await expectBaseline(registry, clock: clock)

    #expect(await registry.activateGeneration(62) == .activated(62))
    _ = try await registry.admit(4, generation: 62).get()
    await expectClock(clock, pendingSleeps: 1, outstandingSleepTasks: 1)
    await registry.stopProvider()
    await registry.stopProvider()
    await expectBaseline(registry, clock: clock, stopped: true)

    let stopped = try failure(await registry.admit(5, generation: 62))
    #expect(stopped.reason == .providerStopped)
    let snapshot = await registry.snapshot()
    #expect(snapshot.metrics.sessionLosses == 1)
    #expect(snapshot.metrics.cancellations == 1)
    #expect(snapshot.metrics.providerStops == 1)
    #expect(snapshot.metrics.hevCleanupCallbacks == 4)
    #expect(snapshot.metrics.relayCleanupCallbacks == 4)
    #expect(snapshot.metrics.terminalCleanups == 4)
    #expect(recorder.snapshot().relay.count == 4)
  }

  @Test("concurrent admission never exceeds the configured bound")
  func concurrentAdmission() async throws {
    let clock = ManualAssociationClock()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 70,
      configuration: try configuration(maximumAssociations: 256),
      clock: clock
    )

    let results = await withTaskGroup(
      of: Result<ClientUDPAssociationKey, ClientUDPAssociationAdmissionFailure>.self,
      returning: [Result<ClientUDPAssociationKey, ClientUDPAssociationAdmissionFailure>].self
    ) { group in
      for handle in 0..<512 {
        group.addTask { await registry.admit(handle, generation: 70) }
      }
      var values: [Result<ClientUDPAssociationKey, ClientUDPAssociationAdmissionFailure>] = []
      for await result in group { values.append(result) }
      return values
    }

    let keys = results.compactMap { try? $0.get() }
    let failures = results.compactMap { result -> ClientUDPAssociationAdmissionFailure? in
      guard case .failure(let failure) = result else { return nil }
      return failure
    }
    #expect(keys.count == 256)
    #expect(Set(keys.map(\.associationID)).count == 256)
    #expect(keys.allSatisfy { $0.associationID != 0 })
    #expect(failures.count == 256)
    #expect(failures.allSatisfy { $0.reason == .associationLimit })
    let snapshot = await registry.snapshot()
    #expect(snapshot.associationCount == 256)
    #expect(snapshot.metrics.peakAssociations == 256)
    await expectClock(clock, pendingSleeps: 256, outstandingSleepTasks: 256)
    await registry.stopProvider()
    await expectBaseline(registry, clock: clock, stopped: true)
  }

  @Test(
    "deterministic property sequences preserve uniqueness and exactly-once cleanup",
    arguments: [UInt64(1), 0x1234_5678, UInt64.max - 1]
  )
  func lifecycleProperty(seed: UInt64) async throws {
    let recorder = AssociationCleanupRecorder()
    let clock = ManualAssociationClock()
    let registry = ClientUDPAssociationRegistry<Int>(
      generation: 80,
      configuration: try configuration(maximumAssociations: 16, searchLimit: 16),
      clock: clock,
      callbacks: recorder.callbacks
    )
    var random = DeterministicRandom(seed: seed)
    var nextHandle = 0
    var live: [Int: ClientUDPAssociationKey] = [:]

    for _ in 0..<400 {
      switch random.next() % 6 {
      case 0, 1:
        let handle = nextHandle
        nextHandle += 1
        switch await registry.admit(handle, generation: 80) {
        case .success(let key):
          #expect(!live.values.contains { $0.associationID == key.associationID })
          live[handle] = key
        case .failure(let failure):
          #expect(failure.reason == .associationLimit)
        }
      case 2:
        if let (handle, key) = randomEntry(live, random: &random) {
          switch await registry.recordActivity(for: key) {
          case .applied:
            #expect(await registry.key(for: handle, generation: 80) == key)
          case .ignoredState(.closing), .ignoredState(.expired):
            #expect(await registry.key(for: handle, generation: 80) == nil)
          default:
            Issue.record("live property entry unexpectedly disappeared")
          }
        }
      case 3:
        if let (_, key) = randomEntry(live, random: &random) {
          _ = await registry.closeLocally(key)
        }
      case 4:
        if let (handle, key) = randomEntry(live, random: &random) {
          _ = await registry.receiveRemoteError(
            associationID: key.associationID,
            generation: 80
          )
          _ = handle
        }
      default:
        if let (handle, key) = randomEntry(live, random: &random) {
          _ = await registry.receiveRemoteClose(
            associationID: key.associationID,
            generation: 80
          )
          live.removeValue(forKey: handle)
        }
      }
      #expect(await registry.snapshot().associationCount <= 16)
    }

    await registry.stopProvider()
    await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
    let snapshot = await registry.snapshot()
    #expect(snapshot.associationCount == 0)
    #expect(snapshot.scheduledTimers == 0)
    #expect(snapshot.metrics.hevCleanupCallbacks == snapshot.metrics.admitted)
    #expect(snapshot.metrics.relayCleanupCallbacks == snapshot.metrics.admitted)
    #expect(snapshot.metrics.terminalCleanups == snapshot.metrics.admitted)
    #expect(recorder.snapshot().hev.count == Int(snapshot.metrics.admitted))
  }
}

private struct RecordedHEVCleanup: Sendable {
  let handle: Int
  let reason: ClientUDPAssociationCleanupReason
}

private final class AssociationCleanupRecorder: @unchecked Sendable {
  struct Snapshot: Sendable {
    let hev: [RecordedHEVCleanup]
    let relay: [ClientUDPAssociationRelayCleanup]
  }

  private struct State {
    var hev: [RecordedHEVCleanup] = []
    var relay: [ClientUDPAssociationRelayCleanup] = []
  }

  private let state = Mutex(State())

  var callbacks: ClientUDPAssociationCallbacks<Int> {
    ClientUDPAssociationCallbacks(
      closeHEV: { [weak self] handle, reason in
        self?.state.withLock { $0.hev.append(.init(handle: handle, reason: reason)) }
      },
      cleanupRelay: { [weak self] cleanup in
        self?.state.withLock { $0.relay.append(cleanup) }
      }
    )
  }

  func snapshot() -> Snapshot {
    state.withLock { Snapshot(hev: $0.hev, relay: $0.relay) }
  }
}

private final class ManualAssociationClock: TunnelClock, @unchecked Sendable {
  private struct Sleep {
    let deadline: ContinuousClock.Instant
    let continuation: CheckedContinuation<Void, any Error>
  }

  private struct State {
    var instant = ContinuousClock().now
    var sleeps: [UUID: Sleep] = [:]
    var postWakeActions: [UUID: @Sendable () async -> Void] = [:]
    var outstandingSleepTasks = 0
  }

  private let state = Mutex(State())

  func now() -> ContinuousClock.Instant {
    state.withLock(\.instant)
  }

  func sleep(for duration: Duration) async throws {
    let identifier = UUID()
    try Task<Never, Never>.checkCancellation()
    state.withLock { $0.outstandingSleepTasks += 1 }
    defer {
      state.withLock { state in
        state.postWakeActions.removeValue(forKey: identifier)
        state.outstandingSleepTasks -= 1
      }
    }
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let shouldCancel = state.withLock { state in
          if Task<Never, Never>.isCancelled { return true }
          state.sleeps[identifier] = Sleep(
            deadline: state.instant.advanced(by: duration),
            continuation: continuation
          )
          return false
        }
        if shouldCancel { continuation.resume(throwing: CancellationError()) }
      }
    } onCancel: {
      let continuation = self.state.withLock {
        $0.sleeps.removeValue(forKey: identifier)?.continuation
      }
      continuation?.resume(throwing: CancellationError())
    }
    let postWakeAction = state.withLock { $0.postWakeActions.removeValue(forKey: identifier) }
    await postWakeAction?()
  }

  func advance(by duration: Duration) {
    let continuations = state.withLock { state -> [CheckedContinuation<Void, any Error>] in
      state.instant = state.instant.advanced(by: duration)
      let ready = state.sleeps.filter { $0.value.deadline <= state.instant }
      for identifier in ready.keys { state.sleeps.removeValue(forKey: identifier) }
      return ready.values.map(\.continuation)
    }
    for continuation in continuations { continuation.resume() }
  }

  func installPostWakeActionForOnlyPendingSleep(
    _ action: @escaping @Sendable () async -> Void
  ) -> Bool {
    state.withLock { state in
      guard state.sleeps.count == 1, let identifier = state.sleeps.keys.first else { return false }
      state.postWakeActions[identifier] = action
      return true
    }
  }

  func snapshot() -> (pendingSleeps: Int, outstandingSleepTasks: Int) {
    state.withLock { ($0.sleeps.count, $0.outstandingSleepTasks) }
  }
}

private struct DeterministicRandom {
  private var value: UInt64

  init(seed: UInt64) {
    value = seed
  }

  mutating func next() -> UInt64 {
    value = value &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return value
  }
}

private func configuration(
  maximumAssociations: UInt32,
  searchLimit: UInt32? = nil,
  idleMilliseconds: UInt32 = RelayProtocolV1.idleTimeoutFloor
) throws -> ClientUDPAssociationRegistryConfiguration {
  try ClientUDPAssociationRegistryConfiguration(
    maximumAssociations: maximumAssociations,
    allocatorSearchLimit: searchLimit,
    idleTimeoutMilliseconds: idleMilliseconds
  )
}

private func failure<Success>(
  _ result: Result<Success, ClientUDPAssociationAdmissionFailure>
) throws -> ClientUDPAssociationAdmissionFailure {
  switch result {
  case .success:
    Issue.record("expected admission failure")
    throw TestFailure.expectedFailure
  case .failure(let failure):
    return failure
  }
}

private func randomEntry(
  _ values: [Int: ClientUDPAssociationKey],
  random: inout DeterministicRandom
) -> (Int, ClientUDPAssociationKey)? {
  guard !values.isEmpty else { return nil }
  let index = Int(random.next() % UInt64(values.count))
  return values.sorted { $0.key < $1.key }[index]
}

private func expectBaseline(
  _ registry: ClientUDPAssociationRegistry<Int>,
  clock: ManualAssociationClock,
  stopped: Bool = false
) async {
  let snapshot = await registry.snapshot()
  #expect(snapshot.associationCount == 0)
  #expect(snapshot.activeAssociations == 0)
  #expect(snapshot.closingAssociations == 0)
  #expect(snapshot.expiredAssociations == 0)
  #expect(snapshot.scheduledTimers == 0)
  #expect(snapshot.providerStopped == stopped)
  await expectClock(clock, pendingSleeps: 0, outstandingSleepTasks: 0)
}

private func expectClock(
  _ clock: ManualAssociationClock,
  pendingSleeps: Int,
  outstandingSleepTasks: Int
) async {
  await waitUntil {
    let snapshot = clock.snapshot()
    return snapshot.pendingSleeps == pendingSleeps
      && snapshot.outstandingSleepTasks == outstandingSleepTasks
  }
  let snapshot = clock.snapshot()
  #expect(snapshot.pendingSleeps == pendingSleeps)
  #expect(snapshot.outstandingSleepTasks == outstandingSleepTasks)
}

private func waitUntil(
  attempts: Int = 2_000,
  _ predicate: @escaping @Sendable () async -> Bool
) async {
  for _ in 0..<attempts {
    if await predicate() { return }
    await Task.yield()
  }
  Issue.record("condition did not become true")
}

private enum TestFailure: Error {
  case expectedFailure
}
