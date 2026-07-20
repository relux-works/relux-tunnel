import Darwin
import Foundation
import ReluxTunnelCore
import Testing

@Suite("PacketFlowBridge lifecycle fault matrix")
struct PacketFlowBridgeLifecycleTests {
  @Test(
    "cancellation at every startup stage restores all observable resources",
    arguments: StartupStage.allCases)
  func cancellationAtStartupStage(stage: StartupStage) async {
    let barrier = PauseLifecycleBarrier(target: stage.value)
    let fixture = BridgeFixture(lifecycleBarrier: barrier)
    let flow = FakePacketFlow(events: fixture.events)
    let startTask = Task {
      try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    }

    await barrier.waitUntilReached()
    startTask.cancel()
    await #expect(throws: CancellationError.self) {
      _ = try await startTask.value
    }

    #expect(await fixture.bridge.lifecycleState() == .stopped(lastRunID: "run-1"))
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_cancellation_total"] == 1)
    #expect(metrics.counters["packet_bridge_terminal_failure_total"] == 0)
    #expect(fixture.logger.messages.filter { $0.message == "packet_bridge.cancelled" }.count == 1)
    #expect(fixture.logger.messages.filter { $0.message == "packet_bridge.stopped" }.count == 1)
    #expect(fixture.logger.messages.allSatisfy { $0.message != "packet_bridge.fatal" })
    #expect(await flow.activeReadCount == 0)
    #expect(await flow.maximumActiveReadCount <= 1)

    if stage == .configurationValidated {
      #expect(fixture.socketIO.closeAttempts.isEmpty)
      #expect(fixture.consumer.borrowedDescriptors.isEmpty)
      #expect(await flow.shutdownCount == 0)
    } else {
      #expect(fixture.socketIO.closeAttempts == [101, 100])
      #expect(await flow.shutdownCount == 1)
    }

    if stage.reachesReadiness {
      #expect(fixture.readinessFactory.latest?.snapshot().activeWaitCount == 0)
      #expect(fixture.readinessFactory.latest?.snapshot().cancelCount == 1)
    } else {
      #expect(fixture.readinessFactory.sourcesSnapshot.isEmpty)
    }

    if stage.reachesBorrow {
      #expect(fixture.consumer.borrowedDescriptors == [101])
      #expect(fixture.consumer.latest?.snapshot().stopRequestCount == 1)
      #expect(fixture.consumer.latest?.snapshot().activeWaitCount == 0)
      #expect(fixture.consumer.latest?.snapshot().didReturn == true)
    } else {
      #expect(fixture.consumer.borrowedDescriptors.isEmpty)
    }
  }

  @Test(
    "caller cancellation while cleanup is paused cannot interrupt ordered cleanup",
    arguments: CleanupStage.allCases)
  func cancellationAtCleanupStage(stage: CleanupStage) async throws {
    let barrier = PauseLifecycleBarrier(target: stage.value)
    let fixture = BridgeFixture(lifecycleBarrier: barrier)
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    let stopTask = Task { await fixture.bridge.stop() }

    await barrier.waitUntilReached()
    stopTask.cancel()
    barrier.release()
    await stopTask.value
    try await handle.waitForTermination()

    #expect(fixture.socketIO.closeAttempts == [101, 100])
    #expect(fixture.socketIO.closedDescriptors == [101, 100])
    #expect(await flow.activeReadCount == 0)
    #expect(await flow.shutdownCount == 1)
    #expect(fixture.readinessFactory.latest?.snapshot().activeWaitCount == 0)
    #expect(fixture.readinessFactory.latest?.snapshot().cancelCount == 1)
    #expect(fixture.consumer.latest?.snapshot().stopRequestCount == 1)
    #expect(fixture.consumer.latest?.snapshot().activeWaitCount == 0)
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_stop_total"] == 1)
    #expect(metrics.counters["packet_bridge_cancellation_total"] == 0)
  }

  @Test("duplicate start and concurrent stop calls have no duplicate side effects")
  func activeStartAndIdempotentStop() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )

    await #expect(throws: PacketFlowBridgeError.alreadyActive) {
      _ = try await fixture.bridge.start(
        packetFlow: FakePacketFlow(events: fixture.events),
        configuration: fixture.configuration
      )
    }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<10 {
        group.addTask { await fixture.bridge.stop() }
      }
    }
    try await handle.waitForTermination()
    await fixture.bridge.stop()

    #expect(fixture.socketIO.closeAttempts == [101, 100])
    #expect(fixture.consumer.latest?.snapshot().stopRequestCount == 1)
    #expect(await flow.shutdownCount == 1)
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_start_total"] == 1)
    #expect(metrics.counters["packet_bridge_stop_total"] == 1)
  }

  @Test(
    "every socket setup errno closes exactly the descriptors that were created",
    arguments: SocketSetupFailure.allCases)
  func socketSetupFailure(failure: SocketSetupFailure) async {
    let fixture = BridgeFixture()
    fixture.socketIO.failOperation = failure.operation
    let flow = FakePacketFlow(events: fixture.events)

    await #expect(
      throws: PacketFlowBridgeError.socketError(operation: failure.operation, errno: EIO)
    ) {
      _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    }

    #expect(
      fixture.socketIO.closeAttempts
        == (failure.operation == .socketPair ? [] : [101, 100])
    )
    #expect(fixture.consumer.borrowedDescriptors.isEmpty)
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_startup_failure_total"] == 1)
    #expect(metrics.counters["packet_bridge_terminal_failure_total"] == 1)
    #expect(fixture.logger.messages.filter { $0.message == "packet_bridge.fatal" }.count == 1)
  }

  @Test("readiness installation failure closes both endpoints without borrowing")
  func readinessInstallationFailure() async {
    let fixture = BridgeFixture()
    fixture.readinessFactory.failCreation = true

    await #expect(throws: PacketFlowBridgeError.readinessFailure) {
      _ = try await fixture.bridge.start(
        packetFlow: FakePacketFlow(events: fixture.events),
        configuration: fixture.configuration
      )
    }
    #expect(fixture.consumer.borrowedDescriptors.isEmpty)
    #expect(fixture.socketIO.closeAttempts == [101, 100])
  }

  @Test("descriptor borrow rejection closes B and A without requesting borrowed stop")
  func descriptorBorrowFailure() async {
    let fixture = BridgeFixture()
    fixture.consumer.failBorrow = true

    await #expect(throws: PacketFlowBridgeError.descriptorBorrowFailure) {
      _ = try await fixture.bridge.start(
        packetFlow: FakePacketFlow(events: fixture.events),
        configuration: fixture.configuration
      )
    }
    #expect(fixture.consumer.borrowedDescriptors.isEmpty)
    #expect(fixture.socketIO.closeAttempts == [101, 100])
  }

  @Test("runtime readiness failure is a single persistent socket fatal")
  func readinessWaitFailure() async throws {
    let fixture = BridgeFixture()
    fixture.readinessFactory.failWaits = true
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )

    await #expect(
      throws: PacketFlowBridgeError.socketError(operation: .readiness, errno: 0)
    ) {
      try await handle.waitForTermination()
    }
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_fatal_socket_error_total"] == 1)
    #expect(fixture.logger.messages.filter { $0.message == "packet_bridge.fatal" }.count == 1)
  }

  @Test(
    "every invalid configuration branch fails before descriptor creation",
    arguments: InvalidConfiguration.allCases)
  func invalidConfiguration(input: InvalidConfiguration) async {
    let fixture = BridgeFixture()

    await #expect(
      throws: PacketFlowBridgeError.invalidConfiguration(field: input.field)
    ) {
      _ = try await fixture.bridge.start(
        packetFlow: FakePacketFlow(events: fixture.events),
        configuration: input.configuration
      )
    }

    #expect(fixture.socketIO.closeAttempts.isEmpty)
    #expect(fixture.consumer.borrowedDescriptors.isEmpty)
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_startup_failure_total"] == 1)
    #expect(metrics.counters["packet_bridge_terminal_failure_total"] == 1)
  }
}

enum StartupStage: String, CaseIterable, Sendable, CustomTestStringConvertible {
  case configurationValidated
  case socketPairCreated
  case descriptorsConfigured
  case readinessInstalled
  case borrowAccepted
  case supervisorInstalled
  case running

  var testDescription: String { rawValue }

  var value: PacketBridgeLifecycleStage {
    switch self {
    case .configurationValidated: .configurationValidated
    case .socketPairCreated: .socketPairCreated
    case .descriptorsConfigured: .descriptorsConfigured
    case .readinessInstalled: .readinessInstalled
    case .borrowAccepted: .borrowAccepted
    case .supervisorInstalled: .supervisorInstalled
    case .running: .running
    }
  }

  var reachesReadiness: Bool {
    switch self {
    case .configurationValidated, .socketPairCreated, .descriptorsConfigured:
      false
    case .readinessInstalled, .borrowAccepted, .supervisorInstalled, .running:
      true
    }
  }

  var reachesBorrow: Bool {
    switch self {
    case .configurationValidated, .socketPairCreated, .descriptorsConfigured,
      .readinessInstalled:
      false
    case .borrowAccepted, .supervisorInstalled, .running:
      true
    }
  }
}

enum CleanupStage: String, CaseIterable, Sendable, CustomTestStringConvertible {
  case packetReadsStopped
  case readinessCancelled
  case pumpsJoined
  case borrowStopRequested
  case borrowReturned
  case hevDescriptorClosed
  case bridgeDescriptorClosed

  var testDescription: String { rawValue }

  var value: PacketBridgeLifecycleStage {
    switch self {
    case .packetReadsStopped: .packetReadsStopped
    case .readinessCancelled: .readinessCancelled
    case .pumpsJoined: .pumpsJoined
    case .borrowStopRequested: .borrowStopRequested
    case .borrowReturned: .borrowReturned
    case .hevDescriptorClosed: .hevDescriptorClosed
    case .bridgeDescriptorClosed: .bridgeDescriptorClosed
    }
  }
}

enum SocketSetupFailure: String, CaseIterable, Sendable, CustomTestStringConvertible {
  case socketPair
  case getDescriptorFlags
  case setDescriptorFlags
  case getStatusFlags
  case setStatusFlags
  case setSendBuffer
  case setReceiveBuffer
  case getSendBuffer
  case getReceiveBuffer

  var testDescription: String { rawValue }

  var operation: PacketBridgeOperation {
    switch self {
    case .socketPair: .socketPair
    case .getDescriptorFlags: .getDescriptorFlags
    case .setDescriptorFlags: .setDescriptorFlags
    case .getStatusFlags: .getStatusFlags
    case .setStatusFlags: .setStatusFlags
    case .setSendBuffer: .setSendBuffer
    case .setReceiveBuffer: .setReceiveBuffer
    case .getSendBuffer: .getSendBuffer
    case .getReceiveBuffer: .getReceiveBuffer
    }
  }
}

enum InvalidConfiguration: String, CaseIterable, Sendable, CustomTestStringConvertible {
  case mtu
  case sendBufferZero
  case sendBufferOverflow
  case receiveBufferZero
  case receiveBufferOverflow
  case workCount
  case workTime
  case diagnosticsWindow
  case datagramOverflow

  var testDescription: String { rawValue }

  var field: String {
    switch self {
    case .mtu: "mtu"
    case .sendBufferZero, .sendBufferOverflow: "send_buffer_bytes"
    case .receiveBufferZero, .receiveBufferOverflow: "receive_buffer_bytes"
    case .workCount: "maximum_work_count"
    case .workTime: "work_time_budget"
    case .diagnosticsWindow: "diagnostics_window"
    case .datagramOverflow: "maximum_datagram_bytes"
    }
  }

  var configuration: PacketBridgeConfiguration {
    var mtu = 20
    var sendBuffer = 4096
    var receiveBuffer = 4096
    var workCount = 8
    var workTime = Duration.seconds(1)
    var diagnosticsWindow = Duration.seconds(60)
    switch self {
    case .mtu:
      mtu = 0
    case .sendBufferZero:
      sendBuffer = 0
    case .sendBufferOverflow:
      sendBuffer = Int(Int32.max) + 1
    case .receiveBufferZero:
      receiveBuffer = 0
    case .receiveBufferOverflow:
      receiveBuffer = Int(Int32.max) + 1
    case .workCount:
      workCount = 0
    case .workTime:
      workTime = .zero
    case .diagnosticsWindow:
      diagnosticsWindow = .zero
    case .datagramOverflow:
      mtu = Int.max
    }
    return PacketBridgeConfiguration(
      mtu: mtu,
      sendBufferBytes: sendBuffer,
      receiveBufferBytes: receiveBuffer,
      maximumWorkCount: workCount,
      workTimeBudget: workTime,
      diagnosticsWindow: diagnosticsWindow
    )
  }
}

final class PauseLifecycleBarrier: PacketBridgeLifecycleBarrier, @unchecked Sendable {
  private let lock = NSLock()
  private let target: PacketBridgeLifecycleStage
  private let stream: AsyncStream<Void>
  private let continuation: AsyncStream<Void>.Continuation
  private var reached = false
  private var reachedWaiters: [CheckedContinuation<Void, Never>] = []

  init(target: PacketBridgeLifecycleStage) {
    self.target = target
    (stream, continuation) = AsyncStream.makeStream(of: Void.self)
  }

  func reach(_ stage: PacketBridgeLifecycleStage) async throws {
    guard stage == target else { return }
    let waiters = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
      reached = true
      defer { reachedWaiters.removeAll() }
      return reachedWaiters
    }
    for waiter in waiters {
      waiter.resume()
    }
    for await _ in stream {
      return
    }
    throw CancellationError()
  }

  func waitUntilReached() async {
    await withCheckedContinuation { continuation in
      let resumeImmediately = lock.withLock { () -> Bool in
        if reached { return true }
        reachedWaiters.append(continuation)
        return false
      }
      if resumeImmediately {
        continuation.resume()
      }
    }
  }

  func release() {
    continuation.yield(())
  }
}

final class BoundaryPacketFlow: PacketFlow, @unchecked Sendable {
  private let boundary: PacketFlowAdapterBoundary

  init(driver: any PacketFlowPlatformDriver) {
    boundary = PacketFlowAdapterBoundary(driver: driver)
  }

  func readPackets() async throws -> PacketReadBatch {
    try await boundary.readPackets()
  }

  func writePackets(_ packets: [TunnelPacket]) async throws {
    try boundary.writePackets(packets)
  }

  func shutdown() async {
    boundary.shutDown()
  }
}

final class BridgeCallbackDriver: PacketFlowPlatformDriver, @unchecked Sendable {
  struct Snapshot: Equatable {
    let registrationCount: Int
    let outstandingCount: Int
  }

  private let lock = NSLock()
  private var registrations = 0
  private var callbacks: [@Sendable ([Data], [Int32]) -> Void] = []

  func registerRead(
    _ callback: @escaping @Sendable ([Data], [Int32]) -> Void
  ) {
    lock.withLock {
      registrations += 1
      callbacks.append(callback)
    }
  }

  func writePackets(_ packets: [Data], protocols: [Int32]) -> Bool {
    true
  }

  func deliver(packets: [Data], protocols: [Int32]) {
    let callback = lock.withLock { callbacks.removeFirst() }
    callback(packets, protocols)
  }

  func snapshot() -> Snapshot {
    lock.withLock {
      Snapshot(registrationCount: registrations, outstandingCount: callbacks.count)
    }
  }
}
