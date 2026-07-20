import Foundation
import Testing

@testable import ReluxTunnelCore

@Suite("Tunnel runtime coordinator")
struct TunnelRuntimeCoordinatorTests {
  @Test("startup gates settings and publishes M1 usability only after reads")
  func orderedStartupAndStop() async throws {
    let fixture = CoordinatorFixture()

    try await fixture.coordinator.start()

    #expect(await fixture.coordinator.coordinatorState() == .usableTCPDNS)
    let events = fixture.recorder.events()
    #expect(events.first == "snapshot.connecting.0.0")
    #expect(events.dropFirst().first == "configuration.load")
    #expect(index(of: "settings.apply", in: events) > index(of: "packet.prepare", in: events))
    #expect(index(of: "packet.activate", in: events) > index(of: "settings.apply", in: events))
    #expect(
      index(of: "snapshot.connectedDegraded.1.1", in: events)
        > index(of: "packet.health.2", in: events)
    )

    let startupSnapshots = fixture.recorder.snapshots()
    #expect(startupSnapshots.first?.position.snapshotSequence == 0)
    #expect(startupSnapshots.dropLast().allSatisfy { !$0.capabilities.tcp })
    #expect(startupSnapshots.dropLast().allSatisfy { !$0.capabilities.safeDNS })
    #expect(startupSnapshots.last?.capabilities.tcp == true)
    #expect(startupSnapshots.last?.capabilities.safeDNS == true)
    #expect(startupSnapshots.last?.capabilities.udp == false)
    #expect(startupSnapshots.last?.capabilities.routesInstalled == true)

    await fixture.coordinator.stop(reason: .userInitiated)

    #expect(await fixture.coordinator.coordinatorState() == .disconnected)
    #expect(
      fixture.recorder.cleanupEvents() == [
        "tcp.closeAdmission",
        "dns.closeAdmission",
        "packet.stop",
        "settings.clear",
        "dns.stop",
        "tcp.stop",
        "ssh.close",
      ]
    )
    #expect(fixture.recorder.snapshots().last?.lifecycle.lifecycleState == .disconnected)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
    #expect(fixture.recorder.activeResources() == 0)
  }

  @Test(
    "every partial startup acquisition rolls back only acquired resources",
    arguments: StartupFailurePoint.allCases
  )
  func partialStartRollback(point: StartupFailurePoint) async {
    let fixture = CoordinatorFixture(failurePoint: point)

    await #expect(throws: TunnelRuntimeCoordinatorError.self) {
      try await fixture.coordinator.start()
    }

    #expect(await fixture.coordinator.coordinatorState() == .failed)
    #expect(fixture.recorder.cleanupEvents() == point.expectedCleanup)
    #expect(fixture.recorder.activeResources() == 0)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
    #expect(fixture.recorder.snapshots().allSatisfy { !$0.capabilities.tcp })
    #expect(fixture.recorder.snapshots().allSatisfy { !$0.capabilities.safeDNS })
  }

  @Test("unknown settings commit is cleared while definite non-commit is not")
  func applyFailureCommitDisposition() async {
    let notCommitted = CoordinatorFixture(failurePoint: .settingsApplyNotCommitted)
    await #expect(throws: TunnelRuntimeCoordinatorError.self) {
      try await notCommitted.coordinator.start()
    }
    #expect(!notCommitted.recorder.events().contains("settings.clear"))

    let uncertain = CoordinatorFixture(failurePoint: .settingsApplyUncertain)
    await #expect(throws: TunnelRuntimeCoordinatorError.self) {
      try await uncertain.coordinator.start()
    }
    #expect(uncertain.recorder.events().contains("settings.clear"))
  }

  @Test("concurrent starts are rejected and stop cancels an in-flight generation")
  func concurrentStartAndStop() async {
    let gate = SuspensionGate()
    let fixture = CoordinatorFixture(cancellationPoint: .beforeSSH, gate: gate)
    let firstStart = Task { try await fixture.coordinator.start() }
    await gate.waitUntilReached()

    await #expect(throws: TunnelRuntimeCoordinatorError.generationAlreadyConsumed) {
      try await fixture.coordinator.start()
    }

    let stop = Task {
      await fixture.coordinator.stop(reason: .system)
    }
    await waitUntil {
      fixture.recorder.snapshots().contains { $0.lifecycle.lifecycleState == .disconnecting }
    }
    await gate.release()

    await #expect(throws: CancellationError.self) {
      try await firstStart.value
    }
    await stop.value

    #expect(await fixture.coordinator.coordinatorState() == .disconnected)
    #expect(!fixture.recorder.events().contains("tcp.prepare"))
    #expect(!fixture.recorder.events().contains("settings.apply"))
    #expect(fixture.recorder.cleanupEvents().isEmpty)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
  }

  @Test("stop before start consumes the generation and releases configuration")
  func stopBeforeStart() async {
    let fixture = CoordinatorFixture()

    await fixture.coordinator.stop(reason: .system)
    await fixture.coordinator.stop(reason: .userInitiated)

    await #expect(throws: TunnelRuntimeCoordinatorError.generationAlreadyConsumed) {
      try await fixture.coordinator.start()
    }

    #expect(await fixture.coordinator.coordinatorState() == .disconnected)
    #expect(
      fixture.recorder.snapshots().map(\.lifecycle.lifecycleState)
        == [.disconnecting, .disconnected]
    )
    #expect(!fixture.recorder.events().contains("configuration.load"))
    #expect(!fixture.recorder.events().contains("settings.apply"))
    #expect(!fixture.recorder.events().contains("snapshot.connectedDegraded.1.1"))
    #expect(fixture.recorder.cleanupEvents().isEmpty)
    #expect(fixture.recorder.activeResources() == 0)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
  }

  @Test("stop wins a concurrent pre-start ordering and cannot be revived")
  func stopWinsConcurrentStart() async {
    let stoppingSnapshotGate = SuspensionGate()
    let fixture = CoordinatorFixture(stoppingSnapshotGate: stoppingSnapshotGate)
    let stop = Task {
      await fixture.coordinator.stop(reason: .system)
    }
    await stoppingSnapshotGate.waitUntilReached()

    let start = Task {
      try await fixture.coordinator.start()
    }
    await #expect(throws: TunnelRuntimeCoordinatorError.generationAlreadyConsumed) {
      try await start.value
    }

    #expect(await fixture.coordinator.coordinatorState() == .stopping)
    #expect(!fixture.recorder.events().contains("configuration.load"))
    #expect(!fixture.recorder.events().contains("settings.apply"))
    #expect(!fixture.recorder.events().contains("snapshot.connectedDegraded.1.1"))

    await stoppingSnapshotGate.release()
    await stop.value
    await fixture.coordinator.stop(reason: .platform(code: 0))

    #expect(await fixture.coordinator.coordinatorState() == .disconnected)
    #expect(
      fixture.recorder.snapshots().map(\.lifecycle.lifecycleState)
        == [.disconnecting, .disconnected]
    )
    #expect(fixture.recorder.cleanupEvents().isEmpty)
    #expect(fixture.recorder.activeResources() == 0)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
  }

  @Test(
    "cancellation after each startup acquisition rolls back in reverse order",
    arguments: StartupCancellationPoint.allCases
  )
  func cancellationRollback(point: StartupCancellationPoint) async {
    let gate = SuspensionGate()
    let fixture = CoordinatorFixture(cancellationPoint: point, gate: gate)
    let start = Task { try await fixture.coordinator.start() }
    await gate.waitUntilReached()

    let stop = Task { await fixture.coordinator.stop(reason: .system) }
    await waitUntil {
      fixture.recorder.snapshots().contains { $0.lifecycle.lifecycleState == .disconnecting }
    }
    await gate.release()

    await #expect(throws: CancellationError.self) {
      try await start.value
    }
    await stop.value

    #expect(fixture.recorder.cleanupEvents() == point.expectedCleanup)
    #expect(fixture.recorder.activeResources() == 0)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
    #expect(!fixture.recorder.events().contains("snapshot.connectedDegraded.1.1"))
  }

  @Test("caller task cancellation is propagated and cleanup remains shielded")
  func callerCancellation() async {
    let gate = SuspensionGate()
    let fixture = CoordinatorFixture(cancellationPoint: .beforeDNS, gate: gate)
    let start = Task { try await fixture.coordinator.start() }
    await gate.waitUntilReached()

    start.cancel()
    await gate.release()

    await #expect(throws: CancellationError.self) {
      try await start.value
    }
    #expect(await fixture.coordinator.coordinatorState() == .disconnected)
    #expect(
      fixture.recorder.cleanupEvents()
        == ["tcp.closeAdmission", "tcp.stop", "ssh.close"]
    )
    #expect(fixture.recorder.activeResources() == 0)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
  }

  @Test("mandatory health loss during startup completion owns cleanup")
  func healthLossDuringStartupCompletionHandoff() async {
    let generation: UInt64 = 8
    let fixture = CoordinatorFixture(
      generation: generation,
      startupCompletionHandoffHook: { coordinator in
        await coordinator.receive(
          TunnelRuntimeHealthEvent(
            runtimeGeneration: generation,
            component: .dns,
            health: .unhealthy
          )
        )
      }
    )

    await #expect(
      throws: TunnelRuntimeCoordinatorError.startupFailed(
        redactedError(domain: .dns, code: "dns_upstream_timeout")
      )
    ) {
      try await fixture.coordinator.start()
    }

    #expect(await fixture.coordinator.coordinatorState() == .failed)
    #expect(
      fixture.recorder.cleanupEvents() == [
        "tcp.closeAdmission",
        "dns.closeAdmission",
        "packet.stop",
        "settings.clear",
        "dns.stop",
        "tcp.stop",
        "ssh.close",
      ]
    )
    #expect(fixture.recorder.count("packet.stop") == 1)
    #expect(fixture.recorder.count("settings.clear") == 1)
    #expect(fixture.recorder.count("dns.stop") == 1)
    #expect(fixture.recorder.count("tcp.stop") == 1)
    #expect(fixture.recorder.count("ssh.close") == 1)
    #expect(fixture.recorder.activeResources() == 0)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
    expectCapabilitiesRemainUnavailableAfterStopping(fixture.recorder.snapshots())
  }

  @Test("caller cancellation during startup completion owns cleanup")
  func callerCancellationDuringStartupCompletionHandoff() async {
    let handoffGate = SuspensionGate()
    let fixture = CoordinatorFixture(
      startupCompletionHandoffHook: { _ in
        await handoffGate.pause()
      }
    )
    let start = Task { try await fixture.coordinator.start() }
    await handoffGate.waitUntilReached()

    start.cancel()
    await handoffGate.release()

    await #expect(throws: CancellationError.self) {
      try await start.value
    }

    #expect(await fixture.coordinator.coordinatorState() == .disconnected)
    #expect(
      fixture.recorder.cleanupEvents() == [
        "tcp.closeAdmission",
        "dns.closeAdmission",
        "packet.stop",
        "settings.clear",
        "dns.stop",
        "tcp.stop",
        "ssh.close",
      ]
    )
    #expect(fixture.recorder.count("packet.stop") == 1)
    #expect(fixture.recorder.count("settings.clear") == 1)
    #expect(fixture.recorder.count("dns.stop") == 1)
    #expect(fixture.recorder.count("tcp.stop") == 1)
    #expect(fixture.recorder.count("ssh.close") == 1)
    #expect(fixture.recorder.activeResources() == 0)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
    expectCapabilitiesRemainUnavailableAfterStopping(fixture.recorder.snapshots())
  }

  @Test("repeated concurrent stop joins one reverse-order cleanup")
  func repeatedConcurrentStop() async throws {
    let fixture = CoordinatorFixture()
    try await fixture.coordinator.start()

    await withTaskGroup(of: Void.self) { group in
      for index in 0..<32 {
        group.addTask {
          let reason: ProviderStopReason = index.isMultiple(of: 2) ? .userInitiated : .system
          await fixture.coordinator.stop(reason: reason)
        }
      }
    }

    #expect(fixture.recorder.count("packet.stop") == 1)
    #expect(fixture.recorder.count("settings.clear") == 1)
    #expect(fixture.recorder.count("dns.stop") == 1)
    #expect(fixture.recorder.count("tcp.stop") == 1)
    #expect(fixture.recorder.count("ssh.close") == 1)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
  }

  @Test("stale health events cannot mutate the active generation")
  func staleHealthEvent() async throws {
    let fixture = CoordinatorFixture(generation: 8)
    try await fixture.coordinator.start()

    await fixture.coordinator.receive(
      TunnelRuntimeHealthEvent(
        runtimeGeneration: 7,
        component: .dns,
        health: .unhealthy
      )
    )
    #expect(await fixture.coordinator.coordinatorState() == .usableTCPDNS)
    #expect(fixture.recorder.count("settings.clear") == 0)

    await fixture.coordinator.receive(
      TunnelRuntimeHealthEvent(
        runtimeGeneration: 8,
        component: .dns,
        health: .unhealthy
      )
    )
    await fixture.coordinator.stop(reason: .providerFailure)

    #expect(await fixture.coordinator.coordinatorState() == .failed)
    #expect(fixture.recorder.count("settings.clear") == 1)
    let snapshots = fixture.recorder.snapshots()
    let failureIndex = snapshots.firstIndex { $0.lifecycle.lifecycleState == .disconnecting }
    #expect(failureIndex != nil)
    if let failureIndex {
      #expect(snapshots[failureIndex...].allSatisfy { !$0.capabilities.tcp })
      #expect(snapshots[failureIndex...].allSatisfy { !$0.capabilities.safeDNS })
    }
  }

  @Test("clear failure preserves truthful route state and no capability")
  func clearFailureTruth() async throws {
    let fixture = CoordinatorFixture(clearFails: true)
    try await fixture.coordinator.start()

    await fixture.coordinator.stop(reason: .userInitiated)

    #expect(await fixture.coordinator.coordinatorState() == .failed)
    let snapshot = await fixture.coordinator.latestSnapshot()
    #expect(snapshot?.lifecycle.routeState == .clearFailed)
    #expect(snapshot?.lifecycle.routesInstalled == true)
    #expect(snapshot?.capabilities.routesInstalled == true)
    #expect(snapshot?.capabilities.tcp == false)
    #expect(snapshot?.capabilities.safeDNS == false)
    #expect(snapshot?.lifecycle.error?.domain == .networkSettings)
    #expect(snapshot?.lifecycle.error?.code.rawValue == "network_settings_clear_failed")
  }

  @Test("latest snapshot store rejects older generations and sequences")
  func snapshotStoreGenerationFilter() async {
    let store = LatestRuntimeSnapshotStore()
    let generationTwo = publishedSnapshot(generation: 2, sequence: 0)
    await store.publish(generationTwo)
    await store.publish(publishedSnapshot(generation: 1, sequence: 99))
    await store.publish(publishedSnapshot(generation: 2, sequence: 0))
    #expect(await store.latest() == generationTwo)

    let newer = publishedSnapshot(generation: 2, sequence: 1)
    await store.publish(newer)
    #expect(await store.latest() == newer)
  }

  @Test("one hundred generations return all owned resources to baseline")
  func repeatedGenerationBaseline() async throws {
    let recorder = CoordinatorRecorder()
    let dependencies = makeCoordinatorDependencies(recorder: recorder)
    let factory = TunnelRuntimeCoordinatorFactory(dependencies: dependencies)

    for _ in 0..<100 {
      let runtime = try await factory.makeRuntime(context: makeContext())
      try await runtime.start()
      await runtime.stop(reason: .system)
      #expect(recorder.activeResources() == 0)
    }

    #expect(recorder.count("settings.apply") == 100)
    #expect(recorder.count("settings.clear") == 100)
    #expect(recorder.count("packet.stop") == 100)
    #expect(recorder.count("dns.stop") == 100)
    #expect(recorder.count("tcp.stop") == 100)
    #expect(recorder.count("ssh.close") == 100)
  }
}

enum StartupFailurePoint: String, CaseIterable, Sendable {
  case configuration
  case ssh
  case tcp
  case dns
  case packetPrepare
  case settingsPlan
  case settingsApplyNotCommitted
  case settingsApplyUncertain
  case packetActivation
  case finalHealth

  var expectedCleanup: [String] {
    switch self {
    case .configuration, .ssh:
      []
    case .tcp:
      ["ssh.close"]
    case .dns:
      ["tcp.closeAdmission", "tcp.stop", "ssh.close"]
    case .packetPrepare:
      [
        "tcp.closeAdmission", "dns.closeAdmission", "dns.stop", "tcp.stop", "ssh.close",
      ]
    case .settingsPlan, .settingsApplyNotCommitted:
      [
        "tcp.closeAdmission", "dns.closeAdmission", "packet.stop", "dns.stop", "tcp.stop",
        "ssh.close",
      ]
    case .settingsApplyUncertain, .packetActivation, .finalHealth:
      [
        "tcp.closeAdmission", "dns.closeAdmission", "packet.stop", "settings.clear",
        "dns.stop", "tcp.stop", "ssh.close",
      ]
    }
  }
}

enum StartupCancellationPoint: String, CaseIterable, Sendable {
  case beforeSSH
  case beforeTCP
  case beforeDNS
  case beforePacketPreparation
  case duringSettingsApply
  case duringPacketActivation
  case duringFinalHealth

  var expectedCleanup: [String] {
    switch self {
    case .beforeSSH:
      []
    case .beforeTCP:
      ["ssh.close"]
    case .beforeDNS:
      ["tcp.closeAdmission", "tcp.stop", "ssh.close"]
    case .beforePacketPreparation:
      [
        "tcp.closeAdmission", "dns.closeAdmission", "dns.stop", "tcp.stop", "ssh.close",
      ]
    case .duringSettingsApply:
      [
        "tcp.closeAdmission", "dns.closeAdmission", "packet.stop", "settings.clear",
        "dns.stop", "tcp.stop", "ssh.close",
      ]
    case .duringPacketActivation, .duringFinalHealth:
      [
        "tcp.closeAdmission", "dns.closeAdmission", "packet.stop", "settings.clear",
        "dns.stop", "tcp.stop", "ssh.close",
      ]
    }
  }
}

private final class CoordinatorRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var recordedEvents: [String] = []
  private var recordedSnapshots: [TunnelRuntimePublishedSnapshot] = []
  private var resourceCount = 0

  func record(_ event: String) {
    lock.withLock {
      recordedEvents.append(event)
    }
  }

  func record(_ snapshot: TunnelRuntimePublishedSnapshot) {
    lock.withLock {
      recordedSnapshots.append(snapshot)
      recordedEvents.append(
        "snapshot.\(snapshot.lifecycle.lifecycleState.rawValue)."
          + "\(snapshot.capabilities.tcp ? 1 : 0)."
          + "\(snapshot.capabilities.safeDNS ? 1 : 0)"
      )
    }
  }

  func acquire(_ resource: String) {
    lock.withLock {
      resourceCount += 1
      recordedEvents.append("\(resource).acquired")
    }
  }

  func release(_ resource: String) {
    lock.withLock {
      resourceCount -= 1
      recordedEvents.append("\(resource).close")
    }
  }

  func events() -> [String] {
    lock.withLock { recordedEvents }
  }

  func snapshots() -> [TunnelRuntimePublishedSnapshot] {
    lock.withLock { recordedSnapshots }
  }

  func cleanupEvents() -> [String] {
    let cleanupNames: Set<String> = [
      "tcp.closeAdmission", "dns.closeAdmission", "packet.stop", "settings.clear", "dns.stop",
      "tcp.stop", "ssh.close",
    ]
    return events().filter(cleanupNames.contains)
  }

  func count(_ event: String) -> Int {
    events().count { $0 == event }
  }

  func activeResources() -> Int {
    lock.withLock { resourceCount }
  }
}

private final class FaultController: @unchecked Sendable {
  private let lock = NSLock()
  let failurePoint: StartupFailurePoint?
  let cancellationPoint: StartupCancellationPoint?
  let gate: SuspensionGate?
  let clearFails: Bool
  private var healthCounts: [TunnelRuntimeMandatoryComponent: Int] = [:]

  init(
    failurePoint: StartupFailurePoint?,
    cancellationPoint: StartupCancellationPoint?,
    gate: SuspensionGate?,
    clearFails: Bool
  ) {
    self.failurePoint = failurePoint
    self.cancellationPoint = cancellationPoint
    self.gate = gate
    self.clearFails = clearFails
  }

  func health(for component: TunnelRuntimeMandatoryComponent) -> TunnelRuntimeComponentHealth {
    lock.withLock {
      let count = healthCounts[component, default: 0] + 1
      healthCounts[component] = count
      if failurePoint == .finalHealth, component == .dns, count == 2 {
        return .unhealthy
      }
      return .healthy
    }
  }

  func pauseIfNeeded(at point: StartupCancellationPoint) async {
    guard cancellationPoint == point else { return }
    await gate?.pause()
  }
}

private actor SuspensionGate {
  private var reached = false
  private var released = false
  private var reachedWaiters: [CheckedContinuation<Void, Never>] = []
  private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

  func pause() async {
    reached = true
    let waiters = reachedWaiters
    reachedWaiters.removeAll()
    for waiter in waiters {
      waiter.resume()
    }
    guard !released else { return }
    await withCheckedContinuation { continuation in
      releaseWaiters.append(continuation)
    }
  }

  func waitUntilReached() async {
    guard !reached else { return }
    await withCheckedContinuation { continuation in
      reachedWaiters.append(continuation)
    }
  }

  func release() {
    released = true
    let waiters = releaseWaiters
    releaseWaiters.removeAll()
    for waiter in waiters {
      waiter.resume()
    }
  }
}

private struct CoordinatorFixture: Sendable {
  let recorder: CoordinatorRecorder
  let coordinator: TunnelRuntimeCoordinator

  init(
    generation: UInt64 = 1,
    failurePoint: StartupFailurePoint? = nil,
    cancellationPoint: StartupCancellationPoint? = nil,
    gate: SuspensionGate? = nil,
    clearFails: Bool = false,
    stoppingSnapshotGate: SuspensionGate? = nil,
    startupCompletionHandoffHook:
      (@Sendable (TunnelRuntimeCoordinator) async -> Void)? = nil
  ) {
    let recorder = CoordinatorRecorder()
    let faults = FaultController(
      failurePoint: failurePoint,
      cancellationPoint: cancellationPoint,
      gate: gate,
      clearFails: clearFails
    )
    self.recorder = recorder
    coordinator = TunnelRuntimeCoordinator(
      runtimeGeneration: generation,
      context: makeContext(),
      dependencies: makeCoordinatorDependencies(
        recorder: recorder,
        faults: faults,
        stoppingSnapshotGate: stoppingSnapshotGate
      ),
      startupCompletionHandoffHook: startupCompletionHandoffHook
    )
  }
}

private func makeCoordinatorDependencies(
  recorder: CoordinatorRecorder,
  faults: FaultController = FaultController(
    failurePoint: nil,
    cancellationPoint: nil,
    gate: nil,
    clearFails: false
  ),
  stoppingSnapshotGate: SuspensionGate? = nil
) -> TunnelRuntimeCoordinatorDependencies {
  TunnelRuntimeCoordinatorDependencies(
    configurationSource: TestConfigurationSource(recorder: recorder, faults: faults),
    sshBootstrap: TestSSHBootstrap(recorder: recorder, faults: faults),
    tcpFactory: TestTCPFactory(recorder: recorder, faults: faults),
    dnsFactory: TestDNSFactory(recorder: recorder, faults: faults),
    packetPlaneFactory: TestPacketPlaneFactory(recorder: recorder, faults: faults),
    settingsPlanBuilder: TestSettingsPlanBuilder(recorder: recorder, faults: faults),
    settingsApplier: TestSettingsApplier(recorder: recorder, faults: faults),
    snapshotStore: RecordingSnapshotStore(
      recorder: recorder,
      stoppingSnapshotGate: stoppingSnapshotGate
    )
  )
}

private struct TestConfigurationSource: ConfigurationSnapshotSource {
  let recorder: CoordinatorRecorder
  let faults: FaultController

  func loadValidatedSnapshot(
    for reference: TunnelConfigurationReference
  ) async throws -> RuntimeConfigurationSnapshot {
    recorder.record("configuration.load")
    if faults.failurePoint == .configuration { throw TestFailure() }
    return RuntimeConfigurationSnapshot(
      configurationGeneration: 1,
      profileIdentifier: reference.profileIdentifier,
      profileRevision: OpaqueProfileRevision(testUUID(2)),
      credentialReference: OpaqueCredentialReference(testUUID(3)),
      trustReference: OpaqueTrustReference(testUUID(4))
    )
  }
}

private struct TestSSHBootstrap: SSHBootstrap {
  let recorder: CoordinatorRecorder
  let faults: FaultController

  func authenticate(
    configuration: RuntimeConfigurationSnapshot,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any SSHBootstrapSession {
    recorder.record("ssh.authenticate")
    await faults.pauseIfNeeded(at: .beforeSSH)
    try Task<Never, Never>.checkCancellation()
    if faults.failurePoint == .ssh { throw TestFailure() }
    recorder.acquire("ssh")
    return TestSSHSession(recorder: recorder, faults: faults)
  }
}

private final class TestSSHSession: SSHBootstrapSession, @unchecked Sendable {
  let connectedEndpoint = TunnelEndpoint(host: "192.0.2.1", port: 22)
  private let recorder: CoordinatorRecorder
  private let faults: FaultController
  private let stopped = OnceFlag()

  init(recorder: CoordinatorRecorder, faults: FaultController) {
    self.recorder = recorder
    self.faults = faults
  }

  func health() async -> TunnelRuntimeComponentHealth {
    let health = faults.health(for: .ssh)
    recorder.record(
      "ssh.health.\(faultsHealthCountLabel(health, recorder: recorder, prefix: "ssh"))")
    return health
  }

  func close() async {
    guard stopped.take() else { return }
    recorder.release("ssh")
  }
}

private struct TestTCPFactory: TCPConsumerFactory {
  let recorder: CoordinatorRecorder
  let faults: FaultController

  func prepare(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any TCPConsumer {
    recorder.record("tcp.prepare")
    await faults.pauseIfNeeded(at: .beforeTCP)
    try Task<Never, Never>.checkCancellation()
    if faults.failurePoint == .tcp { throw TestFailure() }
    recorder.acquire("tcp")
    return TestTCPConsumer(recorder: recorder, faults: faults)
  }
}

private final class TestTCPConsumer: TCPConsumer, @unchecked Sendable {
  private let recorder: CoordinatorRecorder
  private let faults: FaultController
  private let stopped = OnceFlag()
  private let healthCount = Counter()

  init(recorder: CoordinatorRecorder, faults: FaultController) {
    self.recorder = recorder
    self.faults = faults
  }

  func health() async -> TunnelRuntimeComponentHealth {
    let count = healthCount.next()
    recorder.record("tcp.health.\(count)")
    return faults.health(for: .tcp)
  }

  func closeAdmission() async {
    recorder.record("tcp.closeAdmission")
  }

  func stop() async {
    guard stopped.take() else { return }
    recorder.record("tcp.stop")
    recorder.releaseWithoutEvent()
  }
}

private struct TestDNSFactory: DNSConsumerFactory {
  let recorder: CoordinatorRecorder
  let faults: FaultController

  func prepareSafeDNS(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any DNSConsumer {
    recorder.record("dns.prepare")
    await faults.pauseIfNeeded(at: .beforeDNS)
    try Task<Never, Never>.checkCancellation()
    if faults.failurePoint == .dns { throw TestFailure() }
    recorder.acquire("dns")
    return TestDNSConsumer(recorder: recorder, faults: faults)
  }
}

private final class TestDNSConsumer: DNSConsumer, @unchecked Sendable {
  private let recorder: CoordinatorRecorder
  private let faults: FaultController
  private let stopped = OnceFlag()
  private let healthCount = Counter()

  init(recorder: CoordinatorRecorder, faults: FaultController) {
    self.recorder = recorder
    self.faults = faults
  }

  func health() async -> TunnelRuntimeComponentHealth {
    let count = healthCount.next()
    recorder.record("dns.health.\(count)")
    if count == 2 {
      await faults.pauseIfNeeded(at: .duringFinalHealth)
    }
    return faults.health(for: .dns)
  }

  func closeAdmission() async {
    recorder.record("dns.closeAdmission")
  }

  func stop() async {
    guard stopped.take() else { return }
    recorder.record("dns.stop")
    recorder.releaseWithoutEvent()
  }
}

private struct TestPacketPlaneFactory: M1PacketPlaneFactory {
  let recorder: CoordinatorRecorder
  let faults: FaultController

  func prepare(
    configuration: RuntimeConfigurationSnapshot,
    tcp: any TCPConsumer,
    dns: any DNSConsumer,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any M1PacketPlaneSession {
    recorder.record("packet.prepare")
    await faults.pauseIfNeeded(at: .beforePacketPreparation)
    try Task<Never, Never>.checkCancellation()
    if faults.failurePoint == .packetPrepare { throw TestFailure() }
    recorder.acquire("packet")
    return TestPacketPlane(recorder: recorder, faults: faults)
  }
}

private final class TestPacketPlane: M1PacketPlaneSession, @unchecked Sendable {
  private let recorder: CoordinatorRecorder
  private let faults: FaultController
  private let stopped = OnceFlag()
  private let healthCount = Counter()

  init(recorder: CoordinatorRecorder, faults: FaultController) {
    self.recorder = recorder
    self.faults = faults
  }

  func activateReads(packetFlow: any PacketFlow) async throws {
    recorder.record("packet.activate")
    await faults.pauseIfNeeded(at: .duringPacketActivation)
    try Task<Never, Never>.checkCancellation()
    if faults.failurePoint == .packetActivation { throw TestFailure() }
  }

  func health() async -> TunnelRuntimeComponentHealth {
    let count = healthCount.next()
    recorder.record("packet.health.\(count)")
    return faults.health(for: .packetPlane)
  }

  func stop() async {
    guard stopped.take() else { return }
    recorder.record("packet.stop")
    recorder.releaseWithoutEvent()
  }
}

private struct TestSettingsPlan: NetworkSettingsPlan {}

private struct TestSettingsPlanBuilder: NetworkSettingsPlanBuilder {
  let recorder: CoordinatorRecorder
  let faults: FaultController

  func makePlan(
    configuration: RuntimeConfigurationSnapshot,
    connectedEndpoint: TunnelEndpoint,
    runtimeGeneration: UInt64
  ) throws -> any NetworkSettingsPlan {
    recorder.record("settings.plan")
    if faults.failurePoint == .settingsPlan { throw TestFailure() }
    return TestSettingsPlan()
  }
}

private struct TestApplyFailure: NetworkSettingsCommitDescribingError {
  let commitDisposition: NetworkSettingsCommitDisposition
}

private struct TestSettingsApplier: NetworkSettingsApplier {
  let recorder: CoordinatorRecorder
  let faults: FaultController

  func apply(
    _ plan: any NetworkSettingsPlan,
    runtimeGeneration: UInt64
  ) async throws {
    recorder.record("settings.apply")
    await faults.pauseIfNeeded(at: .duringSettingsApply)
    try Task<Never, Never>.checkCancellation()
    switch faults.failurePoint {
    case .settingsApplyNotCommitted:
      throw TestApplyFailure(commitDisposition: .notCommitted)
    case .settingsApplyUncertain:
      throw TestApplyFailure(commitDisposition: .uncertain)
    default:
      return
    }
  }

  func clear(runtimeGeneration: UInt64) async throws {
    recorder.record("settings.clear")
    if faults.clearFails { throw TestFailure() }
  }
}

private struct RecordingSnapshotStore: RuntimeSnapshotStore {
  let recorder: CoordinatorRecorder
  let stoppingSnapshotGate: SuspensionGate?

  func publish(_ snapshot: TunnelRuntimePublishedSnapshot) async {
    recorder.record(snapshot)
    if snapshot.lifecycle.lifecycleState == .disconnecting {
      await stoppingSnapshotGate?.pause()
    }
  }
}

private actor TestPacketFlow: PacketFlow {
  func readPackets() async throws -> PacketReadBatch {
    PacketReadBatch(results: [])
  }

  func writePackets(_ packets: [TunnelPacket]) async throws {}
}

private struct TestFailure: Error, Sendable {}

private final class OnceFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var available = true

  func take() -> Bool {
    lock.withLock {
      guard available else { return false }
      available = false
      return true
    }
  }
}

private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0

  func next() -> Int {
    lock.withLock {
      value += 1
      return value
    }
  }
}

extension CoordinatorRecorder {
  fileprivate func releaseWithoutEvent() {
    lock.withLock {
      resourceCount -= 1
    }
  }
}

extension TunnelRuntimeCoordinatorResourceFootprint {
  fileprivate static let baseline = TunnelRuntimeCoordinatorResourceFootprint(
    retainsConfigurationReference: false,
    retainsConfigurationSnapshot: false,
    retainsSSHSession: false,
    retainsTCPConsumer: false,
    retainsDNSConsumer: false,
    retainsPacketPlane: false,
    settingsRequireClear: false,
    retainsStartupTask: false,
    retainsCleanupTask: false
  )
}

private func makeContext() -> TunnelRuntimeContext {
  TunnelRuntimeContext(
    configuration: TunnelConfiguration(
      profileReference: TunnelConfigurationReference(
        profileIdentifier: OpaqueProfileIdentifier(testUUID(1))
      )
    ),
    packetFlow: TestPacketFlow(),
    dependencies: TunnelRuntimeDependencies(
      clock: ContinuousTunnelClock(),
      logger: TestCoordinatorLogger(),
      metrics: TestCoordinatorMetrics(),
      cancellation: TaskCancellationChecker(),
      memoryPressure: TestCoordinatorMemoryPressure()
    )
  )
}

private struct TestCoordinatorLogger: TunnelLogger {
  func log(
    level: TunnelLogLevel,
    message: String,
    fields: [String: TunnelLogField]
  ) {}
}

private actor TestCoordinatorMetrics: TunnelMetrics {
  func incrementCounter(named name: String, by amount: UInt64) {}
  func setGauge(named name: String, to value: Int64) {}

  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: [:], gauges: [:])
  }
}

private struct TestCoordinatorMemoryPressure: TunnelMemoryPressureSource {
  func currentPressure() async -> TunnelMemoryPressure { .normal }
}

private func testUUID(_ suffix: Int) -> UUID {
  UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
}

private func index(of event: String, in events: [String]) -> Int {
  events.firstIndex(of: event) ?? Int.max
}

private func waitUntil(
  _ predicate: @escaping @Sendable () -> Bool
) async {
  for _ in 0..<1_000 {
    if predicate() { return }
    await Task.yield()
  }
}

private func expectCapabilitiesRemainUnavailableAfterStopping(
  _ snapshots: [TunnelRuntimePublishedSnapshot]
) {
  let stoppingIndex = snapshots.firstIndex {
    $0.lifecycle.lifecycleState == .disconnecting
  }
  #expect(stoppingIndex != nil)
  if let stoppingIndex {
    #expect(snapshots[stoppingIndex...].allSatisfy { !$0.capabilities.tcp })
    #expect(snapshots[stoppingIndex...].allSatisfy { !$0.capabilities.safeDNS })
  }
}

private func redactedError(
  domain: RuntimeErrorDomain,
  code: String
) -> RedactedRuntimeError {
  RedactedRuntimeError(
    domain: domain,
    code: try! RedactedRuntimeErrorCode(code)
  )
}

private func publishedSnapshot(
  generation: UInt64,
  sequence: UInt64
) -> TunnelRuntimePublishedSnapshot {
  TunnelRuntimePublishedSnapshot(
    lifecycle: RuntimeLifecycleSnapshot(
      runtimeGeneration: generation,
      snapshotSequence: sequence,
      lifecycleState: .connecting,
      routeState: .notInstalled,
      tcp: false,
      safeDNS: false,
      udp: false,
      routeMode: .compatible,
      routesInstalled: false,
      healthy: false
    ),
    capabilities: RuntimeCapabilitySnapshot(
      runtimeGeneration: generation,
      snapshotSequence: sequence,
      tcp: false,
      safeDNS: false,
      udp: false,
      routeMode: .compatible,
      routesInstalled: false,
      healthy: false
    )
  )
}

private func faultsHealthCountLabel(
  _ health: TunnelRuntimeComponentHealth,
  recorder: CoordinatorRecorder,
  prefix: String
) -> Int {
  recorder.events().count { $0.hasPrefix("\(prefix).health.") } + 1
}
