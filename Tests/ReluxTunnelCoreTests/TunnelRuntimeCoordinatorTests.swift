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

    await #expect(throws: point.expectedError) {
      try await fixture.coordinator.start()
    }

    #expect(await fixture.coordinator.coordinatorState() == .failed)
    #expect(fixture.recorder.cleanupEvents() == point.expectedCleanup)
    for event in point.expectedCleanup {
      #expect(fixture.recorder.count(event) == 1)
    }
    #expect(
      fixture.recorder.snapshots().count { $0.lifecycle.lifecycleState == .disconnecting } == 1
    )
    #expect(fixture.recorder.snapshots().count { $0.lifecycle.lifecycleState == .failed } == 1)
    #expect(fixture.recorder.snapshots().last?.lifecycle.error == point.expectedFailure)
    #expect(fixture.recorder.resourceBaseline() == .zero)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
    #expect(fixture.recorder.snapshots().allSatisfy { !$0.capabilities.tcp })
    #expect(fixture.recorder.snapshots().allSatisfy { !$0.capabilities.safeDNS })
  }

  @Test(
    "failure before and after every ownership boundary rolls back once",
    arguments: StartupOwnershipBoundary.allCases
  )
  func ownershipBoundaryFailure(boundary: StartupOwnershipBoundary) async {
    let cancellation = OrdinalFailureCancellationChecker(failingAt: boundary.checkOrdinal)
    let fixture = CoordinatorFixture(cancellation: cancellation)

    await #expect(
      throws: TunnelRuntimeCoordinatorError.startupFailed(
        redactedError(domain: .runtimeInvariant, code: "startup_failed")
      )
    ) {
      try await fixture.coordinator.start()
    }

    #expect(cancellation.checkCount() == boundary.checkOrdinal)
    #expect(fixture.recorder.cleanupEvents() == boundary.expectedCleanup)
    for event in boundary.expectedCleanup {
      #expect(fixture.recorder.count(event) == 1)
    }
    #expect(
      fixture.recorder.snapshots().count { $0.lifecycle.lifecycleState == .disconnecting } == 1
    )
    #expect(fixture.recorder.snapshots().count { $0.lifecycle.lifecycleState == .failed } == 1)
    #expect(fixture.recorder.resourceBaseline() == .zero)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
    #expect(fixture.recorder.snapshots().allSatisfy { !$0.capabilities.tcp })
    #expect(fixture.recorder.snapshots().allSatisfy { !$0.capabilities.safeDNS })
  }

  @Test("settings apply error dispositions preserve failure and clear exactly when required")
  func applyFailureCommitDisposition() async {
    let notCommitted = CoordinatorFixture(failurePoint: .settingsApplyNotCommitted)
    await #expect(throws: StartupFailurePoint.settingsApplyNotCommitted.expectedError) {
      try await notCommitted.coordinator.start()
    }
    #expect(notCommitted.recorder.count("settings.clear") == 0)
    #expect(notCommitted.recorder.resourceBaseline() == .zero)
    #expect(await notCommitted.coordinator.resourceFootprint() == .baseline)

    let committed = CoordinatorFixture(failurePoint: .settingsApplyCommitted)
    await #expect(throws: StartupFailurePoint.settingsApplyCommitted.expectedError) {
      try await committed.coordinator.start()
    }
    #expect(committed.recorder.count("settings.clear") == 1)
    #expect(
      committed.recorder.snapshots().last?.lifecycle.error
        == StartupFailurePoint.settingsApplyCommitted.expectedFailure
    )
    #expect(committed.recorder.resourceBaseline() == .zero)
    #expect(await committed.coordinator.resourceFootprint() == .baseline)

    let uncertain = CoordinatorFixture(failurePoint: .settingsApplyUncertain)
    await #expect(throws: StartupFailurePoint.settingsApplyUncertain.expectedError) {
      try await uncertain.coordinator.start()
    }
    #expect(uncertain.recorder.count("settings.clear") == 1)
    #expect(uncertain.recorder.resourceBaseline() == .zero)
    #expect(await uncertain.coordinator.resourceFootprint() == .baseline)
  }

  @Test("concurrent starts are rejected and stop cancels an in-flight generation")
  func concurrentStartAndStop() async {
    let gate = SuspensionGate()
    let stoppingGate = SuspensionGate()
    let fixture = CoordinatorFixture(
      cancellationPoint: .beforeSSH,
      gate: gate,
      stoppingSnapshotGate: stoppingGate
    )
    let firstStart = Task { try await fixture.coordinator.start() }
    await gate.waitUntilReached()

    await #expect(throws: TunnelRuntimeCoordinatorError.generationAlreadyConsumed) {
      try await fixture.coordinator.start()
    }

    let stop = Task {
      await fixture.coordinator.stop(reason: .system)
    }
    await stoppingGate.waitUntilReached()
    await stoppingGate.release()
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
    let stoppingGate = SuspensionGate()
    let fixture = CoordinatorFixture(
      cancellationPoint: point,
      gate: gate,
      stoppingSnapshotGate: stoppingGate
    )
    let start = Task { try await fixture.coordinator.start() }
    await gate.waitUntilReached()

    #expect(await fixture.coordinator.coordinatorState() == point.expectedState)

    let stop = Task { await fixture.coordinator.stop(reason: .system) }
    await stoppingGate.waitUntilReached()
    await stoppingGate.release()
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

  @Test("concurrent starts create exactly one usable runtime")
  func concurrentStartsCreateOneRuntime() async {
    let fixture = CoordinatorFixture()
    var outcomes: [StartAttemptOutcome] = []

    await withTaskGroup(of: StartAttemptOutcome.self) { group in
      for _ in 0..<32 {
        group.addTask {
          do {
            try await fixture.coordinator.start()
            return .started
          } catch TunnelRuntimeCoordinatorError.generationAlreadyConsumed {
            return .alreadyConsumed
          } catch {
            return .unexpectedFailure
          }
        }
      }
      for await outcome in group {
        outcomes.append(outcome)
      }
    }

    #expect(outcomes.count { $0 == .started } == 1)
    #expect(outcomes.count { $0 == .alreadyConsumed } == 31)
    #expect(!outcomes.contains(.unexpectedFailure))
    #expect(await fixture.coordinator.coordinatorState() == .usableTCPDNS)
    #expect(
      fixture.recorder.snapshots().count { $0.lifecycle.lifecycleState == .connectedDegraded } == 1
    )

    await fixture.coordinator.stop(reason: .system)
    #expect(fixture.recorder.resourceBaseline() == .zero)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
  }

  @Test(
    "mandatory dependency health loss revokes capability before cleanup",
    arguments: TunnelRuntimeMandatoryComponent.allCases
  )
  func mandatoryHealthLoss(component: TunnelRuntimeMandatoryComponent) async throws {
    let generation: UInt64 = 44
    let fixture = CoordinatorFixture(generation: generation)
    try await fixture.coordinator.start()

    await fixture.coordinator.receive(
      TunnelRuntimeHealthEvent(
        runtimeGeneration: generation,
        component: component,
        health: .unhealthy
      )
    )
    await fixture.coordinator.stop(reason: .providerFailure)

    #expect(await fixture.coordinator.coordinatorState() == .failed)
    let events = fixture.recorder.events()
    #expect(
      index(of: "snapshot.disconnecting.0.0", in: events)
        < index(of: "tcp.closeAdmission", in: events)
    )
    #expect(fixture.recorder.count("snapshot.disconnecting.0.0") == 1)
    #expect(fixture.recorder.count("packet.stop") == 1)
    #expect(fixture.recorder.count("settings.clear") == 1)
    #expect(fixture.recorder.count("dns.stop") == 1)
    #expect(fixture.recorder.count("tcp.stop") == 1)
    #expect(fixture.recorder.count("ssh.close") == 1)
    #expect(
      fixture.recorder.snapshots().last?.lifecycle.error == component.expectedFailure
    )
    expectCapabilitiesRemainUnavailableAfterStopping(fixture.recorder.snapshots())
    #expect(fixture.recorder.resourceBaseline() == .zero)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
  }

  @Test(
    "failure stop reasons map exactly and revoke capability before one cleanup",
    arguments: FailureStopCase.allCases
  )
  func failureStopReason(stopCase: FailureStopCase) async throws {
    let fixture = CoordinatorFixture()
    try await fixture.coordinator.start()

    await fixture.coordinator.stop(reason: stopCase.reason)
    await fixture.coordinator.stop(reason: stopCase.reason)

    #expect(await fixture.coordinator.coordinatorState() == .failed)
    let events = fixture.recorder.events()
    #expect(
      index(of: "snapshot.disconnecting.0.0", in: events)
        < index(of: "tcp.closeAdmission", in: events)
    )
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
    #expect(fixture.recorder.count("snapshot.disconnecting.0.0") == 1)
    #expect(fixture.recorder.snapshots().count { $0.lifecycle.lifecycleState == .failed } == 1)
    #expect(fixture.recorder.snapshots().last?.lifecycle.error == stopCase.expectedFailure)
    expectCapabilitiesRemainUnavailableAfterStopping(fixture.recorder.snapshots())
    #expect(fixture.recorder.resourceBaseline() == .zero)
    #expect(await fixture.coordinator.resourceFootprint() == .baseline)
  }

  @Test(
    "legal and illegal coordinator controls follow the transition table",
    arguments: CoordinatorControlCase.allCases
  )
  func coordinatorControlTransitionTable(control: CoordinatorControlCase) async {
    switch control {
    case .startWhileStarting:
      let gate = SuspensionGate()
      let fixture = CoordinatorFixture(cancellationPoint: .beforeSSH, gate: gate)
      let first = Task { try await fixture.coordinator.start() }
      await gate.waitUntilReached()
      await #expect(throws: TunnelRuntimeCoordinatorError.generationAlreadyConsumed) {
        try await fixture.coordinator.start()
      }
      #expect(await fixture.coordinator.coordinatorState() == .starting(.sshAuthentication))
      await gate.release()
      await #expect(throws: Never.self) { try await first.value }
      await fixture.coordinator.stop(reason: .system)

    case .startWhileUsable:
      let fixture = CoordinatorFixture()
      await #expect(throws: Never.self) { try await fixture.coordinator.start() }
      await #expect(throws: TunnelRuntimeCoordinatorError.generationAlreadyConsumed) {
        try await fixture.coordinator.start()
      }
      #expect(await fixture.coordinator.coordinatorState() == .usableTCPDNS)
      await fixture.coordinator.stop(reason: .system)

    case .startWhileStopping:
      let stoppingGate = SuspensionGate()
      let fixture = CoordinatorFixture(stoppingSnapshotGate: stoppingGate)
      await #expect(throws: Never.self) { try await fixture.coordinator.start() }
      let stop = Task { await fixture.coordinator.stop(reason: .system) }
      await stoppingGate.waitUntilReached()
      await #expect(throws: TunnelRuntimeCoordinatorError.generationAlreadyConsumed) {
        try await fixture.coordinator.start()
      }
      #expect(await fixture.coordinator.coordinatorState() == .stopping)
      await stoppingGate.release()
      await stop.value

    case .startAfterStopped:
      let fixture = CoordinatorFixture()
      await #expect(throws: Never.self) { try await fixture.coordinator.start() }
      await fixture.coordinator.stop(reason: .system)
      let eventCount = fixture.recorder.events().count
      await #expect(throws: TunnelRuntimeCoordinatorError.generationAlreadyConsumed) {
        try await fixture.coordinator.start()
      }
      #expect(fixture.recorder.events().count == eventCount)
      #expect(await fixture.coordinator.coordinatorState() == .disconnected)

    case .startAfterFailed:
      let fixture = CoordinatorFixture(failurePoint: .configuration)
      await #expect(throws: StartupFailurePoint.configuration.expectedError) {
        try await fixture.coordinator.start()
      }
      let eventCount = fixture.recorder.events().count
      await #expect(throws: TunnelRuntimeCoordinatorError.generationAlreadyConsumed) {
        try await fixture.coordinator.start()
      }
      #expect(fixture.recorder.events().count == eventCount)
      #expect(await fixture.coordinator.coordinatorState() == .failed)
      #expect(fixture.recorder.resourceBaseline() == .zero)
      #expect(await fixture.coordinator.resourceFootprint() == .baseline)

    case .stopWhileDisconnected:
      let fixture = CoordinatorFixture()
      await fixture.coordinator.stop(reason: .system)
      await fixture.coordinator.stop(reason: .userInitiated)
      #expect(await fixture.coordinator.coordinatorState() == .disconnected)
      #expect(
        fixture.recorder.snapshots().map(\.lifecycle.lifecycleState)
          == [.disconnecting, .disconnected]
      )

    case .healthyAndStaleWhileUsable:
      let generation: UInt64 = 9
      let fixture = CoordinatorFixture(generation: generation)
      await #expect(throws: Never.self) { try await fixture.coordinator.start() }
      let eventCount = fixture.recorder.events().count
      await fixture.coordinator.receive(
        TunnelRuntimeHealthEvent(
          runtimeGeneration: generation,
          component: .ssh,
          health: .healthy
        )
      )
      await fixture.coordinator.receive(
        TunnelRuntimeHealthEvent(
          runtimeGeneration: generation - 1,
          component: .ssh,
          health: .unhealthy
        )
      )
      #expect(fixture.recorder.events().count == eventCount)
      #expect(await fixture.coordinator.coordinatorState() == .usableTCPDNS)
      await fixture.coordinator.stop(reason: .system)

    case .callbackWhileStopping:
      let generation: UInt64 = 10
      let stoppingGate = SuspensionGate()
      let fixture = CoordinatorFixture(
        generation: generation,
        stoppingSnapshotGate: stoppingGate
      )
      await #expect(throws: Never.self) { try await fixture.coordinator.start() }
      let stop = Task { await fixture.coordinator.stop(reason: .system) }
      await stoppingGate.waitUntilReached()
      let eventCount = fixture.recorder.events().count
      await fixture.coordinator.receive(
        TunnelRuntimeHealthEvent(
          runtimeGeneration: generation,
          component: .dns,
          health: .unhealthy
        )
      )
      #expect(fixture.recorder.events().count == eventCount)
      #expect(await fixture.coordinator.coordinatorState() == .stopping)
      await stoppingGate.release()
      await stop.value

    case .callbackWhileDisconnected:
      let generation: UInt64 = 11
      let fixture = CoordinatorFixture(generation: generation)
      await fixture.coordinator.stop(reason: .system)
      let eventCount = fixture.recorder.events().count
      await fixture.coordinator.receive(
        TunnelRuntimeHealthEvent(
          runtimeGeneration: generation,
          component: .packetPlane,
          health: .unhealthy
        )
      )
      #expect(fixture.recorder.events().count == eventCount)
      #expect(await fixture.coordinator.coordinatorState() == .disconnected)

    case .callbackWhileFailed:
      let generation: UInt64 = 12
      let fixture = CoordinatorFixture(generation: generation, failurePoint: .configuration)
      await #expect(throws: TunnelRuntimeCoordinatorError.self) {
        try await fixture.coordinator.start()
      }
      let eventCount = fixture.recorder.events().count
      await fixture.coordinator.receive(
        TunnelRuntimeHealthEvent(
          runtimeGeneration: generation,
          component: .tcp,
          health: .unhealthy
        )
      )
      await fixture.coordinator.stop(reason: .providerFailure)
      #expect(fixture.recorder.events().count == eventCount)
      #expect(await fixture.coordinator.coordinatorState() == .failed)
    }
  }

  @Test("repeated stop and health races clean exactly one generation")
  func repeatedStopHealthRace() async throws {
    for generation in 1...32 {
      let fixture = CoordinatorFixture(generation: UInt64(generation))
      try await fixture.coordinator.start()

      await withTaskGroup(of: Void.self) { group in
        for index in 0..<32 {
          group.addTask {
            if index.isMultiple(of: 2) {
              await fixture.coordinator.stop(reason: .system)
            } else {
              await fixture.coordinator.receive(
                TunnelRuntimeHealthEvent(
                  runtimeGeneration: UInt64(generation),
                  component: TunnelRuntimeMandatoryComponent.allCases[index % 4],
                  health: .unhealthy
                )
              )
            }
          }
        }
      }
      await fixture.coordinator.stop(reason: .system)

      #expect(fixture.recorder.count("packet.stop") == 1)
      #expect(fixture.recorder.count("settings.clear") == 1)
      #expect(fixture.recorder.count("dns.stop") == 1)
      #expect(fixture.recorder.count("tcp.stop") == 1)
      #expect(fixture.recorder.count("ssh.close") == 1)
      #expect(fixture.recorder.resourceBaseline() == .zero)
      #expect(await fixture.coordinator.resourceFootprint() == .baseline)
      expectCapabilitiesRemainUnavailableAfterStopping(fixture.recorder.snapshots())
    }
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
      let coordinator = try #require(runtime as? TunnelRuntimeCoordinator)
      try await runtime.start()
      await runtime.stop(reason: .system)
      #expect(recorder.activeResources() == 0)
      #expect(recorder.resourceBaseline() == .zero)
      #expect(await coordinator.resourceFootprint() == .baseline)
    }

    #expect(recorder.count("settings.apply") == 100)
    #expect(recorder.count("settings.clear") == 100)
    #expect(recorder.count("packet.stop") == 100)
    #expect(recorder.count("dns.stop") == 100)
    #expect(recorder.count("tcp.stop") == 100)
    #expect(recorder.count("ssh.close") == 100)
  }
}

enum StartupOwnershipBoundary: String, CaseIterable, Sendable {
  case beforeConfiguration
  case afterConfiguration
  case beforeSSH
  case afterSSH
  case beforeTCP
  case afterTCP
  case beforeDNS
  case afterDNS
  case beforePacketPlane
  case afterPacketPlane
  case beforeSettingsCommit
  case afterSettingsCommit
  case beforePacketReads
  case afterPacketReads

  var checkOrdinal: Int {
    switch self {
    case .beforeConfiguration: 2
    case .afterConfiguration: 3
    case .beforeSSH: 6
    case .afterSSH: 7
    case .beforeTCP: 10
    case .afterTCP: 11
    case .beforeDNS: 12
    case .afterDNS: 13
    case .beforePacketPlane: 14
    case .afterPacketPlane: 15
    case .beforeSettingsCommit: 21
    case .afterSettingsCommit: 22
    case .beforePacketReads: 24
    case .afterPacketReads: 25
    }
  }

  var expectedCleanup: [String] {
    switch self {
    case .beforeConfiguration, .afterConfiguration, .beforeSSH:
      []
    case .afterSSH, .beforeTCP:
      ["ssh.close"]
    case .afterTCP, .beforeDNS:
      ["tcp.closeAdmission", "tcp.stop", "ssh.close"]
    case .afterDNS, .beforePacketPlane:
      [
        "tcp.closeAdmission", "dns.closeAdmission", "dns.stop", "tcp.stop", "ssh.close",
      ]
    case .afterPacketPlane, .beforeSettingsCommit:
      [
        "tcp.closeAdmission", "dns.closeAdmission", "packet.stop", "dns.stop", "tcp.stop",
        "ssh.close",
      ]
    case .afterSettingsCommit, .beforePacketReads, .afterPacketReads:
      [
        "tcp.closeAdmission", "dns.closeAdmission", "packet.stop", "settings.clear",
        "dns.stop", "tcp.stop", "ssh.close",
      ]
    }
  }
}

private enum StartAttemptOutcome: Equatable, Sendable {
  case started
  case alreadyConsumed
  case unexpectedFailure
}

enum CoordinatorControlCase: String, CaseIterable, Sendable {
  case startWhileStarting
  case startWhileUsable
  case startWhileStopping
  case startAfterStopped
  case startAfterFailed
  case stopWhileDisconnected
  case healthyAndStaleWhileUsable
  case callbackWhileStopping
  case callbackWhileDisconnected
  case callbackWhileFailed
}

enum StartupFailurePoint: String, CaseIterable, Sendable {
  case configuration
  case ssh
  case tcp
  case dns
  case packetPrepare
  case settingsPlan
  case settingsApplyNotCommitted
  case settingsApplyCommitted
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
    case .settingsApplyCommitted, .settingsApplyUncertain, .packetActivation, .finalHealth:
      [
        "tcp.closeAdmission", "dns.closeAdmission", "packet.stop", "settings.clear",
        "dns.stop", "tcp.stop", "ssh.close",
      ]
    }
  }

  var expectedFailure: RedactedRuntimeError {
    switch self {
    case .configuration:
      redactedError(domain: .configuration, code: "configuration_invalid")
    case .ssh:
      redactedError(domain: .sshTransport, code: "ssh_session_lost")
    case .tcp:
      redactedError(domain: .tcp, code: "tcp_flow_failed")
    case .dns, .finalHealth:
      redactedError(domain: .dns, code: "dns_upstream_timeout")
    case .packetPrepare, .packetActivation:
      redactedError(domain: .packetPlane, code: "packet_plane_failed")
    case .settingsPlan:
      redactedError(domain: .networkSettings, code: "settings_invalid")
    case .settingsApplyNotCommitted, .settingsApplyCommitted, .settingsApplyUncertain:
      redactedError(domain: .networkSettings, code: "network_settings_apply_failed")
    }
  }

  var expectedError: TunnelRuntimeCoordinatorError {
    .startupFailed(expectedFailure)
  }
}

enum FailureStopCase: String, CaseIterable, Sendable {
  case startupFailure
  case providerFailure

  var reason: ProviderStopReason {
    switch self {
    case .startupFailure:
      .startupFailure
    case .providerFailure:
      .providerFailure
    }
  }

  var expectedFailure: RedactedRuntimeError {
    switch self {
    case .startupFailure:
      redactedError(domain: .runtimeInvariant, code: "startup_failed")
    case .providerFailure:
      redactedError(domain: .runtimeInvariant, code: "provider_failure")
    }
  }
}

enum StartupCancellationPoint: String, CaseIterable, Sendable {
  case duringConfiguration
  case beforeSSH
  case beforeTCP
  case beforeDNS
  case beforePacketPreparation
  case duringSettingsApply
  case duringPacketActivation
  case duringFinalHealth

  var expectedCleanup: [String] {
    switch self {
    case .duringConfiguration, .beforeSSH:
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

  var expectedState: TunnelRuntimeCoordinatorState {
    switch self {
    case .duringConfiguration:
      .starting(.configuration)
    case .beforeSSH:
      .starting(.sshAuthentication)
    case .beforeTCP, .beforeDNS, .beforePacketPreparation:
      .starting(.consumers)
    case .duringSettingsApply:
      .starting(.networkSettings)
    case .duringPacketActivation, .duringFinalHealth:
      .starting(.packetReads)
    }
  }
}

private struct FixtureResourceBaseline: Equatable, Sendable {
  var tasks = 0
  var timers = 0
  var sockets = 0
  var channels = 0
  var dependencies = 0

  static let zero = FixtureResourceBaseline()

  mutating func acquire(_ resource: String) {
    apply(resource, delta: 1)
  }

  mutating func release(_ resource: String) {
    apply(resource, delta: -1)
    precondition(tasks >= 0 && timers >= 0 && sockets >= 0 && channels >= 0)
    precondition(dependencies >= 0)
  }

  private mutating func apply(_ resource: String, delta: Int) {
    switch resource {
    case "ssh":
      sockets += delta
      dependencies += delta
    case "tcp":
      channels += delta
      dependencies += delta
    case "dns":
      timers += delta
      sockets += delta
      dependencies += delta
    case "packet":
      sockets += delta
      channels += delta
      dependencies += delta
    case "settings":
      dependencies += delta
    case "reads":
      tasks += delta
    default:
      preconditionFailure("Unknown fixture resource: \(resource)")
    }
  }
}

private final class CoordinatorRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var recordedEvents: [String] = []
  private var recordedSnapshots: [TunnelRuntimePublishedSnapshot] = []
  private var resourceCount = 0
  private var resources = FixtureResourceBaseline.zero
  private var resourceLeases: [String: Int] = [:]

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
      resources.acquire(resource)
      resourceLeases[resource, default: 0] += 1
      recordedEvents.append("\(resource).acquired")
    }
  }

  func release(_ resource: String) {
    lock.withLock {
      resourceCount -= 1
      resources.release(resource)
      resourceLeases[resource, default: 0] -= 1
      precondition(resourceLeases[resource, default: 0] >= 0)
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

  func resourceBaseline() -> FixtureResourceBaseline {
    lock.withLock { resources }
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
    cancellation: any TunnelCancellationChecking = TaskCancellationChecker(),
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
      context: makeContext(cancellation: cancellation),
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
    await faults.pauseIfNeeded(at: .duringConfiguration)
    try Task<Never, Never>.checkCancellation()
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
    recorder.releaseWithoutEvent("tcp")
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
    recorder.releaseWithoutEvent("dns")
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
  private let readsLease = ResourceLeaseFlag()
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
    if readsLease.activate() {
      recorder.acquire("reads")
    }
  }

  func health() async -> TunnelRuntimeComponentHealth {
    let count = healthCount.next()
    recorder.record("packet.health.\(count)")
    return faults.health(for: .packetPlane)
  }

  func stop() async {
    guard stopped.take() else { return }
    recorder.record("packet.stop")
    if readsLease.deactivate() {
      recorder.releaseWithoutEvent("reads")
    }
    recorder.releaseWithoutEvent("packet")
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
    case .settingsApplyCommitted:
      recorder.acquire("settings")
      throw TestApplyFailure(commitDisposition: .committed)
    case .settingsApplyUncertain:
      recorder.acquire("settings")
      throw TestApplyFailure(commitDisposition: .uncertain)
    default:
      recorder.acquire("settings")
      return
    }
  }

  func clear(runtimeGeneration: UInt64) async throws {
    recorder.record("settings.clear")
    if faults.clearFails { throw TestFailure() }
    recorder.releaseIfAcquired("settings")
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

private final class OrdinalFailureCancellationChecker: TunnelCancellationChecking,
  @unchecked Sendable
{
  private let lock = NSLock()
  private let failingOrdinal: Int
  private var checks = 0

  init(failingAt failingOrdinal: Int) {
    self.failingOrdinal = failingOrdinal
  }

  var isCancelled: Bool { false }

  func checkCancellation() throws {
    let shouldFail = lock.withLock {
      checks += 1
      return checks == failingOrdinal
    }
    if shouldFail { throw TestFailure() }
  }

  func checkCount() -> Int {
    lock.withLock { checks }
  }
}

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

private final class ResourceLeaseFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var active = false

  func activate() -> Bool {
    lock.withLock {
      guard !active else { return false }
      active = true
      return true
    }
  }

  func deactivate() -> Bool {
    lock.withLock {
      guard active else { return false }
      active = false
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
  fileprivate func releaseWithoutEvent(_ resource: String) {
    lock.withLock {
      resourceCount -= 1
      resources.release(resource)
      resourceLeases[resource, default: 0] -= 1
      precondition(resourceLeases[resource, default: 0] >= 0)
    }
  }

  fileprivate func releaseIfAcquired(_ resource: String) {
    lock.withLock {
      guard resourceLeases[resource, default: 0] > 0 else { return }
      resourceCount -= 1
      resources.release(resource)
      resourceLeases[resource, default: 0] -= 1
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

extension TunnelRuntimeMandatoryComponent {
  fileprivate var expectedFailure: RedactedRuntimeError {
    switch self {
    case .ssh:
      redactedError(domain: .sshTransport, code: "ssh_session_lost")
    case .tcp:
      redactedError(domain: .tcp, code: "tcp_flow_failed")
    case .dns:
      redactedError(domain: .dns, code: "dns_upstream_timeout")
    case .packetPlane:
      redactedError(domain: .packetPlane, code: "packet_plane_failed")
    }
  }
}

private func makeContext(
  cancellation: any TunnelCancellationChecking = TaskCancellationChecker()
) -> TunnelRuntimeContext {
  TunnelRuntimeContext(
    configuration: TunnelConfiguration(
      profileReference: TunnelConfigurationReference(
        profileIdentifier: OpaqueProfileIdentifier(testUUID(1))
      )
    ),
    packetFlow: TestPacketFlow(),
    dependencies: TunnelRuntimeDependencies(
      clock: TestCoordinatorClock(),
      logger: TestCoordinatorLogger(),
      metrics: TestCoordinatorMetrics(),
      cancellation: cancellation,
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

private struct TestCoordinatorClock: TunnelClock {
  private let fixedInstant = ContinuousClock().now

  func now() -> ContinuousClock.Instant { fixedInstant }

  func sleep(for duration: Duration) async throws {
    throw TestFailure()
  }
}

private func testUUID(_ suffix: Int) -> UUID {
  UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
}

private func index(of event: String, in events: [String]) -> Int {
  events.firstIndex(of: event) ?? Int.max
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
