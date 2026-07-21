import Foundation
import Synchronization
import Testing

@testable import ReluxTunnelCore

@Suite("Bounded TCP admission and metrics")
struct TCPAdmissionRegistryTests {
  @Test("configuration validates every injectable evidence gate")
  func configurationValidation() throws {
    #expect(throws: TCPAdmissionConfigurationError.nonPositive(.maximumReservedFlows)) {
      _ = try configuration(maximumFlows: 0)
    }
    #expect(
      throws: TCPAdmissionConfigurationError.flowCeilingExceedsMeasuredSafeCeiling(
        configured: 5,
        measuredSafe: 4
      )
    ) {
      _ = try configuration(maximumFlows: 5, measuredSafeFlows: 4)
    }
    #expect(
      throws: TCPAdmissionConfigurationError.flowCeilingExceedsHEVSessionCeiling(
        configured: 5,
        hevMaximum: 4
      )
    ) {
      _ = try configuration(maximumFlows: 5, hevSessions: 4)
    }
    #expect(
      throws: TCPAdmissionConfigurationError.openCeilingExceedsFlowCeiling(opens: 3, flows: 2)
    ) {
      _ = try configuration(maximumFlows: 2, maximumOpens: 3)
    }
    #expect(throws: TCPFlowQueuedByteReservationError.nonPositive(.localToSSH)) {
      _ = try TCPFlowQueuedByteReservation(localToSSHBytes: 0, sshToLocalBytes: 1)
    }
  }

  @Test("below at and above every independent ceiling reject deterministically")
  func independentCeilings() throws {
    let bytes = try queuedBytes(4, 4)

    let handshakeRegistry = TCPAdmissionRegistry(
      configuration: try configuration(maximumHandshakes: 2),
      initialSessionHealth: .healthy
    )
    let handshake1 = try handshakeRegistry.tryReserveHandshake().get()
    let handshake2 = try handshakeRegistry.tryReserveHandshake().get()
    let handshakeRejection = try failure(handshakeRegistry.tryReserveHandshake())
    #expect(handshakeRejection.reason == .handshakeCapacity)
    #expect(handshakeRejection.socksReply == 0x01)
    #expect(!handshakeRejection.shouldOpenSSHChannel)
    #expect(handshakeRegistry.snapshot().pendingHandshakes == 2)
    #expect(handshake1.release())
    #expect(handshake2.release())

    let flowRegistry = TCPAdmissionRegistry(
      configuration: try configuration(
        maximumHandshakes: 3,
        maximumFlows: 2,
        maximumOpens: 2
      ),
      initialSessionHealth: .healthy
    )
    let flow1 = try admittedFlow(in: flowRegistry, bytes: bytes)
    let flow2 = try admittedFlow(in: flowRegistry, bytes: bytes)
    let flowHandshake = try flowRegistry.tryReserveHandshake().get()
    let flowRejection = try failure(
      flowRegistry.admitAuthenticated(flowHandshake, queuedBytes: bytes)
    )
    #expect(flowRejection.reason == .flowCapacity)
    #expect(flowRegistry.snapshot().reservedFlows == 2)
    #expect(flow1.release(reason: .capacity))
    #expect(flow2.release(reason: .capacity))

    let byteRegistry = TCPAdmissionRegistry(
      configuration: try configuration(
        maximumHandshakes: 3,
        maximumFlows: 3,
        maximumOpens: 3,
        maximumQueuedBytes: 16
      ),
      initialSessionHealth: .healthy
    )
    let byteFlow1 = try admittedFlow(in: byteRegistry, bytes: bytes)
    let byteFlow2 = try admittedFlow(in: byteRegistry, bytes: bytes)
    let byteHandshake = try byteRegistry.tryReserveHandshake().get()
    let byteRejection = try failure(
      byteRegistry.admitAuthenticated(byteHandshake, queuedBytes: bytes)
    )
    #expect(byteRejection.reason == .queuedByteCapacity)
    #expect(byteRegistry.snapshot().reservedQueuedBytes == 16)
    #expect(byteFlow1.release(reason: .capacity))
    #expect(byteFlow2.release(reason: .capacity))

    let openingRegistry = TCPAdmissionRegistry(
      configuration: try configuration(maximumFlows: 2, maximumOpens: 1),
      initialSessionHealth: .healthy
    )
    let openingFlow1 = try admittedFlow(in: openingRegistry, bytes: bytes)
    let openingFlow2 = try admittedFlow(in: openingRegistry, bytes: bytes)
    let opening = try openingRegistry.tryReserveChannelOpen(
      for: openingFlow1,
      atUptimeMilliseconds: 10
    ).get()
    let openRejection = try failure(
      openingRegistry.tryReserveChannelOpen(
        for: openingFlow2,
        atUptimeMilliseconds: 10
      )
    )
    #expect(openRejection.reason == .openingCapacity)
    #expect(!openRejection.shouldOpenSSHChannel)
    #expect(openingRegistry.snapshot().openingFlows == 1)
    #expect(opening.finish(.failed, atUptimeMilliseconds: 11))
    #expect(openingFlow1.release(reason: .capacity))
    #expect(openingFlow2.release(reason: .capacity))

    let unhealthyRegistry = TCPAdmissionRegistry(
      configuration: try configuration(),
      initialSessionHealth: .unavailable
    )
    let healthRejection = try failure(unhealthyRegistry.tryReserveHandshake())
    #expect(healthRejection.reason == .sessionUnavailable)
    #expect(unhealthyRegistry.snapshot().pendingHandshakes == 0)
  }

  @Test("pressure reject cannot open SSH or disturb an admitted flow")
  func immediateRejectAndAdmittedFairness() throws {
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(
        maximumHandshakes: 1,
        maximumFlows: 1,
        maximumOpens: 1
      ),
      initialSessionHealth: .healthy
    )
    let flow = try admittedFlow(in: registry, bytes: queuedBytes(8, 8))
    let rejectedHandshake = try registry.tryReserveHandshake().get()
    let rejection = try failure(
      registry.admitAuthenticated(rejectedHandshake, queuedBytes: queuedBytes(8, 8))
    )
    let sshOpenCalls = Atomic<Int>(0)
    if rejection.shouldOpenSSHChannel {
      _ = sshOpenCalls.wrappingAdd(1, ordering: .relaxed)
    }

    #expect(rejection.socksReply == TCPAdmissionRejection.socksGeneralFailureReply)
    #expect(sshOpenCalls.load(ordering: .relaxed) == 0)
    #expect(flow.updateBufferedBytes(localToSSHBytes: 8, sshToLocalBytes: 8))
    #expect(flow.recordTransferredBytes(localToSSH: 1_024, sshToLocal: 2_048))
    let pressured = registry.snapshot()
    #expect(pressured.reservedFlows == 1)
    #expect(pressured.adapterBufferedBytes == 16)
    #expect(pressured.bytesLocalToSSH == 1_024)
    #expect(pressured.bytesSSHToLocal == 2_048)
    #expect(flow.release(reason: .graceful))
    #expect(registry.snapshot().reservedFlows == 0)
  }

  @Test("sustained reject pressure cannot starve an admitted flow or create SSH work")
  func sustainedPressureFairness() async throws {
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(
        maximumHandshakes: 32,
        maximumFlows: 1,
        maximumOpens: 1
      ),
      initialSessionHealth: .healthy
    )
    let bytes = try queuedBytes(8, 8)
    let flow = try admittedFlow(in: registry, bytes: bytes)
    let progressIterations = 2_000
    let pressureWorkers = 8
    let pressureIterations = 1_000
    let sshOpenCalls = TestAtomicCounter()
    let unexpectedRejections = TestAtomicCounter()

    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        for iteration in 0..<progressIterations {
          #expect(
            flow.updateBufferedBytes(
              localToSSHBytes: iteration.isMultiple(of: 2) ? 8 : 0,
              sshToLocalBytes: iteration.isMultiple(of: 2) ? 0 : 8
            )
          )
          #expect(flow.recordTransferredBytes(localToSSH: 1, sshToLocal: 1))
          await Task.yield()
        }
      }
      for _ in 0..<pressureWorkers {
        group.addTask {
          for _ in 0..<pressureIterations {
            switch registry.tryReserveHandshake() {
            case .failure:
              unexpectedRejections.increment()
            case .success(let handshake):
              switch registry.admitAuthenticated(handshake, queuedBytes: bytes) {
              case .success(let unexpectedFlow):
                unexpectedRejections.increment()
                _ = unexpectedFlow.release(reason: .internal)
              case .failure(let rejection):
                if rejection.reason != .flowCapacity {
                  unexpectedRejections.increment()
                }
                if rejection.shouldOpenSSHChannel {
                  sshOpenCalls.increment()
                }
              }
            }
          }
        }
      }
    }

    let pressured = registry.snapshot()
    #expect(unexpectedRejections.load() == 0)
    #expect(sshOpenCalls.load() == 0)
    #expect(pressured.pendingHandshakes == 0)
    #expect(pressured.reservedFlows == 1)
    #expect(pressured.openingFlows == 0)
    #expect(pressured.bytesLocalToSSH == UInt64(progressIterations))
    #expect(pressured.bytesSSHToLocal == UInt64(progressIterations))
    #expect(
      pressured.pressureRejects[.flowCapacity]
        == UInt64(pressureWorkers * pressureIterations)
    )
    #expect(flow.release(reason: .graceful))
    expectCurrentBaseline(registry.snapshot())
  }

  @Test("concurrent flow and opening races never exceed capacity")
  func concurrentReservationRaces() async throws {
    let flowLimit = 16
    let openLimit = 4
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(
        maximumHandshakes: 256,
        maximumFlows: flowLimit,
        maximumOpens: openLimit,
        maximumQueuedBytes: flowLimit * 8,
        measuredSafeFlows: flowLimit,
        hevSessions: flowLimit
      ),
      initialSessionHealth: .healthy
    )
    let bytes = try queuedBytes(4, 4)
    var flows: [TCPFlowReservation] = []
    var rejections: [TCPAdmissionRejection] = []

    await withTaskGroup(
      of: Result<TCPFlowReservation, TCPAdmissionRejection>.self
    ) { group in
      for _ in 0..<256 {
        group.addTask {
          switch registry.tryReserveHandshake() {
          case .success(let handshake):
            return registry.admitAuthenticated(handshake, queuedBytes: bytes)
          case .failure(let rejection):
            return .failure(rejection)
          }
        }
      }
      for await result in group {
        switch result {
        case .success(let flow): flows.append(flow)
        case .failure(let rejection): rejections.append(rejection)
        }
      }
    }

    #expect(flows.count == flowLimit)
    #expect(rejections.count == 256 - flowLimit)
    #expect(rejections.allSatisfy { $0.reason == .flowCapacity })
    #expect(registry.snapshot().peakReservedFlows == flowLimit)
    #expect(registry.snapshot().peakReservedQueuedBytes == flowLimit * 8)

    var openings: [TCPChannelOpenReservation] = []
    var openRejections: [TCPAdmissionRejection] = []
    await withTaskGroup(
      of: Result<TCPChannelOpenReservation, TCPAdmissionRejection>.self
    ) { group in
      for flow in flows {
        group.addTask {
          registry.tryReserveChannelOpen(for: flow, atUptimeMilliseconds: 100)
        }
      }
      for await result in group {
        switch result {
        case .success(let opening): openings.append(opening)
        case .failure(let rejection): openRejections.append(rejection)
        }
      }
    }

    #expect(openings.count == openLimit)
    #expect(openRejections.count == flowLimit - openLimit)
    #expect(openRejections.allSatisfy { $0.reason == .openingCapacity })
    #expect(registry.snapshot().peakOpeningFlows == openLimit)
    for opening in openings {
      #expect(opening.finish(.failed, atUptimeMilliseconds: 101))
    }
    for flow in flows {
      #expect(flow.release(reason: .cancelled))
    }
    let baseline = registry.snapshot()
    #expect(baseline.pendingHandshakes == 0)
    #expect(baseline.reservedFlows == 0)
    #expect(baseline.openingFlows == 0)
    #expect(baseline.openChannels == 0)
    #expect(baseline.reservedQueuedBytes == 0)
    #expect(baseline.releaseViolations == 0)
  }

  @Test("concurrent handshake and queued-byte races honor independent ceilings")
  func concurrentHandshakeAndByteRaces() async throws {
    let handshakeLimit = 8
    let handshakeRegistry = TCPAdmissionRegistry(
      configuration: try configuration(maximumHandshakes: handshakeLimit),
      initialSessionHealth: .healthy
    )
    var handshakes: [TCPHandshakeReservation] = []
    var handshakeRejections: [TCPAdmissionRejection] = []
    await withTaskGroup(
      of: Result<TCPHandshakeReservation, TCPAdmissionRejection>.self
    ) { group in
      for _ in 0..<128 {
        group.addTask { handshakeRegistry.tryReserveHandshake() }
      }
      for await result in group {
        switch result {
        case .success(let handshake): handshakes.append(handshake)
        case .failure(let rejection): handshakeRejections.append(rejection)
        }
      }
    }
    #expect(handshakes.count == handshakeLimit)
    #expect(handshakeRejections.count == 128 - handshakeLimit)
    #expect(handshakeRejections.allSatisfy { $0.reason == .handshakeCapacity })
    #expect(handshakeRegistry.snapshot().peakPendingHandshakes == handshakeLimit)
    for handshake in handshakes { #expect(handshake.release()) }
    #expect(handshakeRegistry.snapshot().pendingHandshakes == 0)

    let byteLimit = 32
    let byteRegistry = TCPAdmissionRegistry(
      configuration: try configuration(
        maximumHandshakes: 128,
        maximumFlows: 64,
        maximumOpens: 64,
        maximumQueuedBytes: byteLimit,
        measuredSafeFlows: 64,
        hevSessions: 64
      ),
      initialSessionHealth: .healthy
    )
    let bytes = try queuedBytes(4, 4)
    var flows: [TCPFlowReservation] = []
    var byteRejections: [TCPAdmissionRejection] = []
    await withTaskGroup(
      of: Result<TCPFlowReservation, TCPAdmissionRejection>.self
    ) { group in
      for _ in 0..<128 {
        group.addTask {
          switch byteRegistry.tryReserveHandshake() {
          case .success(let handshake):
            return byteRegistry.admitAuthenticated(handshake, queuedBytes: bytes)
          case .failure(let rejection):
            return .failure(rejection)
          }
        }
      }
      for await result in group {
        switch result {
        case .success(let flow): flows.append(flow)
        case .failure(let rejection): byteRejections.append(rejection)
        }
      }
    }
    #expect(flows.count == byteLimit / bytes.totalBytes)
    #expect(byteRejections.count == 128 - flows.count)
    #expect(byteRejections.allSatisfy { $0.reason == .queuedByteCapacity })
    #expect(byteRegistry.snapshot().peakReservedQueuedBytes == byteLimit)
    for flow in flows { #expect(flow.release(reason: .capacity)) }
    let baseline = byteRegistry.snapshot()
    #expect(baseline.pendingHandshakes == 0)
    #expect(baseline.reservedFlows == 0)
    #expect(baseline.reservedQueuedBytes == 0)
    #expect(baseline.releaseViolations == 0)
  }

  @Test("every terminal reason and repeated churn return exact baseline")
  func terminalChurn() throws {
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(maximumFlows: 1, maximumOpens: 1),
      initialSessionHealth: .healthy
    )
    let iterations = 20
    for _ in 0..<iterations {
      for reason in TCPFlowTerminalReason.allCases {
        let flow = try admittedFlow(in: registry, bytes: queuedBytes(7, 9))
        let opening = try registry.tryReserveChannelOpen(
          for: flow,
          atUptimeMilliseconds: 1_000
        ).get()
        #expect(opening.finish(.succeeded, atUptimeMilliseconds: 1_025))
        #expect(flow.updateBufferedBytes(localToSSHBytes: 7, sshToLocalBytes: 9))
        #expect(flow.markHalfClosed())
        #expect(flow.release(reason: reason))
        let baseline = registry.snapshot()
        #expect(baseline.reservedFlows == 0)
        #expect(baseline.openingFlows == 0)
        #expect(baseline.openChannels == 0)
        #expect(baseline.reservedQueuedBytes == 0)
        #expect(baseline.adapterBufferedBytes == 0)
      }
    }

    let snapshot = registry.snapshot()
    for reason in TCPFlowTerminalReason.allCases {
      #expect(snapshot.terminalReasons[reason] == UInt64(iterations))
    }
    #expect(snapshot.peakReservedFlows == 1)
    #expect(snapshot.peakOpeningFlows == 1)
    #expect(snapshot.peakOpenChannels == 1)
    #expect(snapshot.peakReservedQueuedBytes == 16)
    #expect(snapshot.peakAdapterBufferedBytes == 16)
    #expect(snapshot.releaseViolations == 0)
  }

  @Test("open failure terminal race releases each reservation once")
  func terminalDuringOpen() throws {
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(maximumFlows: 1, maximumOpens: 1),
      initialSessionHealth: .healthy
    )
    let flow = try admittedFlow(in: registry, bytes: queuedBytes(4, 4))
    let opening = try registry.tryReserveChannelOpen(
      for: flow,
      atUptimeMilliseconds: 1
    ).get()
    #expect(flow.release(reason: .cancelled))
    #expect(!opening.finish(.succeeded, atUptimeMilliseconds: 2))

    let snapshot = registry.snapshot()
    #expect(snapshot.reservedFlows == 0)
    #expect(snapshot.openingFlows == 0)
    #expect(snapshot.openChannels == 0)
    #expect(snapshot.reservedQueuedBytes == 0)
    #expect(snapshot.releaseViolations == 0)
  }

  @Test("release and channel-open completion race without double accounting")
  func concurrentTerminalDuringOpen() async throws {
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(maximumFlows: 1, maximumOpens: 1),
      initialSessionHealth: .healthy
    )

    for _ in 0..<500 {
      let flow = try admittedFlow(in: registry, bytes: queuedBytes(4, 4))
      let opening = try registry.tryReserveChannelOpen(
        for: flow,
        atUptimeMilliseconds: 1
      ).get()
      var outcomes: [Bool] = []
      await withTaskGroup(of: Bool.self) { group in
        group.addTask { flow.release(reason: .cancelled) }
        group.addTask { opening.finish(.succeeded, atUptimeMilliseconds: 2) }
        for await outcome in group { outcomes.append(outcome) }
      }
      #expect(outcomes.filter { $0 }.count >= 1)
      #expect(outcomes.filter { $0 }.count <= 2)
      expectCurrentBaseline(registry.snapshot())
    }
    #expect(registry.snapshot().releaseViolations == 0)
  }

  @Test("explicit release versus last-reference drop remains exactly once")
  func concurrentReleaseAndDeinit() async throws {
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(maximumFlows: 1, maximumOpens: 1),
      initialSessionHealth: .healthy
    )
    let iterations = 250

    for _ in 0..<iterations {
      let holder = FlowReservationHolder(
        try admittedFlow(in: registry, bytes: queuedBytes(4, 4))
      )
      await withTaskGroup(of: Void.self) { group in
        group.addTask { _ = holder.releaseIfPresent() }
        group.addTask { holder.dropLastReference() }
      }
      expectCurrentBaseline(registry.snapshot())
    }

    let snapshot = registry.snapshot()
    #expect(snapshot.releaseViolations == 0)
    let terminated =
      (snapshot.terminalReasons[.graceful] ?? 0)
      + (snapshot.terminalReasons[.cancelled] ?? 0)
    #expect(terminated == UInt64(iterations))
  }

  @Test("handshake flow and opening deinit rollback recover all capacity")
  func tokenDeinitRollback() throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: 52)
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(maximumFlows: 1, maximumOpens: 1),
      initialSessionHealth: .healthy,
      diagnostics: store.recorder()
    )

    var handshake: TCPHandshakeReservation? = try registry.tryReserveHandshake().get()
    #expect(registry.snapshot().pendingHandshakes == 1)
    handshake = nil
    #expect(handshake == nil)
    expectCurrentBaseline(registry.snapshot())

    var flow: TCPFlowReservation? = try admittedFlow(in: registry, bytes: queuedBytes(4, 4))
    var opening: TCPChannelOpenReservation? = try registry.tryReserveChannelOpen(
      for: try #require(flow),
      atUptimeMilliseconds: 10
    ).get()
    flow = nil
    opening = nil
    #expect(opening == nil)
    expectCurrentBaseline(registry.snapshot())

    let diagnostics = try store.snapshot()
    #expect(diagnostics.counters["tcp_terminal_cancelled_total"] == 1)
    #expect(diagnostics.counters["tcp_late_event_discarded_total"] == 1)
  }

  @Test("duplicate finish release and late callbacks never release capacity twice")
  func duplicateTerminalAndLateCallbacks() throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: 53)
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(maximumFlows: 1, maximumOpens: 1),
      initialSessionHealth: .healthy,
      diagnostics: store.recorder()
    )
    let flow = try admittedFlow(in: registry, bytes: queuedBytes(4, 4))
    let opening = try registry.tryReserveChannelOpen(
      for: flow,
      atUptimeMilliseconds: 10
    ).get()
    #expect(opening.finish(.succeeded, atUptimeMilliseconds: 11))
    #expect(!opening.finish(.failed, atUptimeMilliseconds: 12))
    #expect(flow.release(reason: .graceful))
    #expect(!flow.release(reason: .cancelled))
    #expect(!flow.updateBufferedBytes(localToSSHBytes: 1, sshToLocalBytes: 1))
    #expect(!flow.recordTransferredBytes(localToSSH: 1, sshToLocal: 1))
    #expect(!flow.markHalfClosed())
    _ = try failure(
      registry.tryReserveChannelOpen(for: flow, atUptimeMilliseconds: 13)
    )

    let snapshot = registry.snapshot()
    expectCurrentBaseline(snapshot)
    #expect(snapshot.releaseViolations == 2)
    let diagnostics = try store.snapshot()
    #expect(diagnostics.counters["tcp_reservation_release_violation_total"] == 2)
    #expect(diagnostics.counters["tcp_late_event_discarded_total"] == 4)
  }

  @Test("late buffer and byte callbacks racing terminal cleanup cannot leak")
  func concurrentLateCallbacks() async throws {
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(maximumFlows: 1, maximumOpens: 1),
      initialSessionHealth: .healthy
    )

    for _ in 0..<500 {
      let flow = try admittedFlow(in: registry, bytes: queuedBytes(4, 4))
      let opening = try registry.tryReserveChannelOpen(
        for: flow,
        atUptimeMilliseconds: 10
      ).get()
      #expect(opening.finish(.succeeded, atUptimeMilliseconds: 11))
      await withTaskGroup(of: Bool.self) { group in
        group.addTask { flow.release(reason: .cancelled) }
        group.addTask { flow.updateBufferedBytes(localToSSHBytes: 4, sshToLocalBytes: 4) }
        group.addTask { flow.recordTransferredBytes(localToSSH: 1, sshToLocal: 1) }
        group.addTask { flow.markHalfClosed() }
        for await _ in group {}
      }
      expectCurrentBaseline(registry.snapshot())
    }
    #expect(registry.snapshot().releaseViolations == 0)
  }

  @Test("identifier exhaustion fails closed without wrap reuse or ABA")
  func identifierExhaustion() throws {
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(
        maximumHandshakes: 2,
        maximumFlows: 1,
        maximumOpens: 1
      ),
      initialSessionHealth: .healthy,
      diagnostics: nil,
      initialReservationIdentifierForTesting: UInt64.max - 2
    )
    let flow = try admittedFlow(in: registry, bytes: queuedBytes(4, 4))
    let opening = try registry.tryReserveChannelOpen(
      for: flow,
      atUptimeMilliseconds: 1
    ).get()

    let exhaustedWhileLive = try failure(registry.tryReserveHandshake())
    #expect(exhaustedWhileLive.reason == .identifierCapacity)
    #expect(!exhaustedWhileLive.shouldOpenSSHChannel)
    #expect(opening.finish(.failed, atUptimeMilliseconds: 2))
    #expect(flow.release(reason: .graceful))
    expectCurrentBaseline(registry.snapshot())

    let exhaustedAfterRetirement = try failure(registry.tryReserveHandshake())
    #expect(exhaustedAfterRetirement.reason == .identifierCapacity)
    expectCurrentBaseline(registry.snapshot())
    #expect(registry.snapshot().releaseViolations == 0)
  }

  @Test("queued-byte accumulation overflow rejects and returns exact baseline")
  func queuedByteAccumulationOverflow() throws {
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(
        maximumHandshakes: 2,
        maximumFlows: 2,
        maximumOpens: 1,
        maximumQueuedBytes: Int.max,
        measuredSafeFlows: 2,
        hevSessions: 2
      ),
      initialSessionHealth: .healthy
    )
    let maximumReservation = try queuedBytes(Int.max - 1, 1)
    let flow = try admittedFlow(in: registry, bytes: maximumReservation)
    let handshake = try registry.tryReserveHandshake().get()
    let rejection = try failure(
      registry.admitAuthenticated(handshake, queuedBytes: try queuedBytes(1, 1))
    )
    #expect(rejection.reason == .queuedByteCapacity)
    #expect(registry.snapshot().reservedQueuedBytes == Int.max)
    #expect(flow.release(reason: .capacity))
    expectCurrentBaseline(registry.snapshot())
  }

  @Test("session-health changes racing admission linearize without leaks")
  func sessionHealthAdmissionRace() async throws {
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(
        maximumHandshakes: 32,
        maximumFlows: 8,
        maximumOpens: 4,
        maximumQueuedBytes: 128
      ),
      initialSessionHealth: .stopping
    )
    _ = try failure(registry.tryReserveHandshake())
    registry.setSessionHealth(.healthy)
    let bytes = try queuedBytes(4, 4)

    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        for iteration in 0..<2_000 {
          registry.setSessionHealth(iteration.isMultiple(of: 2) ? .healthy : .stopping)
          await Task.yield()
        }
      }
      for _ in 0..<16 {
        group.addTask {
          for _ in 0..<500 {
            guard case .success(let handshake) = registry.tryReserveHandshake() else {
              continue
            }
            if case .success(let flow) = registry.admitAuthenticated(
              handshake,
              queuedBytes: bytes
            ) {
              _ = flow.release(reason: .cancelled)
            }
          }
        }
      }
    }

    registry.setSessionHealth(.stopping)
    let snapshot = registry.snapshot()
    expectCurrentBaseline(snapshot)
    #expect(snapshot.sessionHealth == .stopping)
    #expect(snapshot.peakPendingHandshakes <= 32)
    #expect(snapshot.peakReservedFlows <= 8)
    #expect((snapshot.pressureRejects[.sessionUnavailable] ?? 0) > 0)
    #expect(snapshot.releaseViolations == 0)
  }

  @Test("bounded diagnostics drops still reconcile every current TCP gauge")
  func boundedDiagnosticsGaugeConvergence() async throws {
    let (snapshotEntered, snapshotEnteredContinuation) = AsyncStream<Void>.makeStream()
    let releaseSnapshot = DispatchSemaphore(value: 0)
    let shouldBlockSnapshot = Atomic(true)
    let store = RuntimeDiagnosticsStore(
      runtimeGeneration: 54,
      initialSnapshotSequenceForTesting: 0,
      snapshotConstructionHook: {
        guard shouldBlockSnapshot.exchange(false, ordering: .relaxed) else { return }
        snapshotEnteredContinuation.yield()
        releaseSnapshot.wait()
      }
    )
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(maximumFlows: 1, maximumOpens: 1),
      initialSessionHealth: .healthy,
      diagnostics: store.recorder()
    )
    let blockedSnapshot = Task.detached { try store.snapshot() }
    defer { releaseSnapshot.signal() }
    var enteredIterator = snapshotEntered.makeAsyncIterator()
    _ = await enteredIterator.next()

    for _ in 0..<2_000 {
      let flow = try admittedFlow(in: registry, bytes: queuedBytes(11, 13))
      let opening = try registry.tryReserveChannelOpen(
        for: flow,
        atUptimeMilliseconds: 10
      ).get()
      #expect(opening.finish(.succeeded, atUptimeMilliseconds: 11))
      #expect(flow.updateBufferedBytes(localToSSHBytes: 11, sshToLocalBytes: 13))
      #expect(flow.release(reason: .graceful))
    }
    expectCurrentBaseline(registry.snapshot())

    releaseSnapshot.signal()
    _ = try await blockedSnapshot.value
    let snapshot = try store.snapshot()
    #expect((snapshot.counters["diagnostics_ingestion_drop_total"] ?? 0) > 0)
    for gauge in [
      "tcp_pending_handshakes", "tcp_reserved_flows", "tcp_parsing_flows",
      "tcp_opening_flows", "tcp_streaming_flows", "tcp_half_closed_flows",
      "tcp_open_channels", "tcp_reserved_queued_bytes", "tcp_adapter_buffered_bytes",
      "tcp_local_to_ssh_buffered_bytes", "tcp_ssh_to_local_buffered_bytes",
      "tcp_active_flows",
    ] {
      #expect(snapshot.gauges[gauge] == 0)
    }
    #expect(snapshot.gauges["tcp_session_health_code"] == 1)
    #expect(snapshot.gauges["tcp_peak_reserved_flows"] == 1)
    #expect(snapshot.gauges["tcp_peak_opening_flows"] == 1)
    #expect(snapshot.gauges["tcp_peak_open_channels"] == 1)
    #expect(snapshot.gauges["tcp_peak_reserved_queued_bytes"] == 24)
    #expect(snapshot.gauges["tcp_peak_adapter_buffered_bytes"] == 24)
    #expect(snapshot.gauges["tcp_peak_flows"] == 1)

    let later = try store.snapshot()
    #expect(
      (later.counters["tcp_flows_opened_total"] ?? 0)
        >= (snapshot.counters["tcp_flows_opened_total"] ?? 0)
    )
    #expect(
      (later.counters["tcp_flows_closed_total"] ?? 0)
        >= (snapshot.counters["tcp_flows_closed_total"] ?? 0)
    )
    #expect(later.gauges["tcp_active_flows"] == 0)
  }

  @Test("runtime snapshots reset by generation and contain aggregate TCP fields only")
  func diagnosticsGenerationAndPrivacy() throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: 40)
    let registry = TCPAdmissionRegistry(
      configuration: try configuration(maximumFlows: 1, maximumOpens: 1),
      initialSessionHealth: .healthy,
      diagnostics: store.recorder()
    )
    let flow = try admittedFlow(in: registry, bytes: queuedBytes(11, 13))
    let opening = try registry.tryReserveChannelOpen(
      for: flow,
      atUptimeMilliseconds: 100
    ).get()
    #expect(opening.finish(.succeeded, atUptimeMilliseconds: 125))
    #expect(flow.recordTransferredBytes(localToSSH: 111, sshToLocal: 222))
    #expect(flow.release(reason: .graceful))

    let snapshot = try store.snapshot()
    #expect(snapshot.counters["tcp_accepted_authenticated_total"] == 1)
    #expect(snapshot.counters["tcp_channel_open_attempted_total"] == 1)
    #expect(snapshot.counters["tcp_channel_open_succeeded_total"] == 1)
    #expect(snapshot.counters["tcp_terminal_graceful_total"] == 1)
    #expect(snapshot.counters["tcp_flows_graceful_total"] == 1)
    #expect(snapshot.counters["tcp_bytes_local_to_ssh_total"] == 111)
    #expect(snapshot.counters["tcp_bytes_ssh_to_local_total"] == 222)
    #expect(snapshot.gauges["tcp_reserved_flows"] == 0)
    #expect(snapshot.gauges["tcp_peak_reserved_flows"] == 1)
    #expect(snapshot.gauges["tcp_active_flows"] == 0)
    #expect(snapshot.gauges["tcp_peak_flows"] == 1)
    #expect(snapshot.counters["tcp_flows_opened_total"] == 1)
    #expect(snapshot.counters["tcp_flows_closed_total"] == 1)
    let latency = try #require(
      snapshot.histograms["tcp_channel_open_latency_milliseconds"]
    )
    #expect(latency.buckets.first { $0.upperBound == 25 }?.count == 1)
    #expect(latency.buckets.last?.count == 1)

    let encoded = String(decoding: try RuntimeMessageCodec.encode(snapshot), as: UTF8.self)
    for prohibited in [
      "destination_hostname", "destination_address", "destination_port", "packet_payload",
      "raw_credential", "secret.example", "203.0.113.8", "198.51.100.44:443",
    ] {
      #expect(!encoded.localizedCaseInsensitiveContains(prohibited))
    }

    let newRecorder = try store.beginGeneration(41)
    registry.setSessionHealth(.stopping)
    let reset = try store.snapshot()
    #expect(reset.runtimeGeneration == 41)
    #expect(reset.counters["tcp_accepted_authenticated_total"] == 0)
    #expect(reset.gauges["tcp_peak_reserved_flows"] == 0)
    #expect(
      reset.histograms["tcp_channel_open_latency_milliseconds"]?.buckets.last?.count == 0
    )
    #expect(reset.gauges["tcp_session_health_code"] == 0)
    #expect(reset.gauges["tcp_reserved_flows"] == 0)

    let newRegistry = TCPAdmissionRegistry(
      configuration: try configuration(),
      initialSessionHealth: .unavailable,
      diagnostics: newRecorder
    )
    _ = newRegistry.tryReserveHandshake()
    let current = try store.snapshot()
    #expect(current.counters["tcp_admission_rejected_total"] == 1)
    #expect(current.counters["tcp_pressure_reject_session_unavailable_total"] == 1)
  }
}

private final class FlowReservationHolder: Sendable {
  private let storage: Mutex<TCPFlowReservation?>

  init(_ reservation: TCPFlowReservation) {
    storage = Mutex(reservation)
  }

  func releaseIfPresent() -> Bool {
    storage.withLock { reservation in
      reservation?.release(reason: .graceful) ?? false
    }
  }

  func dropLastReference() {
    storage.withLock { $0 = nil }
  }
}

private final class TestAtomicCounter: Sendable {
  private let value = Atomic<Int>(0)

  func increment() {
    _ = value.wrappingAdd(1, ordering: .relaxed)
  }

  func load() -> Int {
    value.load(ordering: .relaxed)
  }
}

private func expectCurrentBaseline(
  _ snapshot: TCPAdmissionSnapshot,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  #expect(snapshot.pendingHandshakes == 0, sourceLocation: sourceLocation)
  #expect(snapshot.reservedFlows == 0, sourceLocation: sourceLocation)
  #expect(snapshot.parsingFlows == 0, sourceLocation: sourceLocation)
  #expect(snapshot.openingFlows == 0, sourceLocation: sourceLocation)
  #expect(snapshot.streamingFlows == 0, sourceLocation: sourceLocation)
  #expect(snapshot.halfClosedFlows == 0, sourceLocation: sourceLocation)
  #expect(snapshot.openChannels == 0, sourceLocation: sourceLocation)
  #expect(snapshot.reservedQueuedBytes == 0, sourceLocation: sourceLocation)
  #expect(snapshot.adapterBufferedBytes == 0, sourceLocation: sourceLocation)
}

private func configuration(
  maximumHandshakes: Int = 8,
  maximumFlows: Int = 8,
  maximumOpens: Int = 4,
  maximumQueuedBytes: Int = 1_024,
  measuredSafeFlows: Int = 8,
  hevSessions: Int = 8
) throws -> TCPAdmissionConfiguration {
  try TCPAdmissionConfiguration(
    maximumPendingHandshakes: maximumHandshakes,
    maximumReservedFlows: maximumFlows,
    maximumConcurrentChannelOpens: maximumOpens,
    maximumAggregateQueuedBytes: maximumQueuedBytes,
    measuredSafeMaximumFlows: measuredSafeFlows,
    hevMaximumSessionCount: hevSessions
  )
}

private func queuedBytes(_ localToSSH: Int, _ sshToLocal: Int) throws
  -> TCPFlowQueuedByteReservation
{
  try TCPFlowQueuedByteReservation(
    localToSSHBytes: localToSSH,
    sshToLocalBytes: sshToLocal
  )
}

private func admittedFlow(
  in registry: TCPAdmissionRegistry,
  bytes: TCPFlowQueuedByteReservation
) throws -> TCPFlowReservation {
  let handshake = try registry.tryReserveHandshake().get()
  return try registry.admitAuthenticated(handshake, queuedBytes: bytes).get()
}

private func failure<Success>(
  _ result: Result<Success, TCPAdmissionRejection>
) throws -> TCPAdmissionRejection {
  switch result {
  case .success:
    Issue.record("expected admission rejection")
    throw TestFailure.expectedRejection
  case .failure(let rejection):
    return rejection
  }
}

private enum TestFailure: Error {
  case expectedRejection
}
