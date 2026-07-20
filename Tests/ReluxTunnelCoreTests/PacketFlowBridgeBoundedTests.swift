import Darwin
import Foundation
import ReluxTunnelCore
import Testing

@Suite("PacketFlowBridge bounded execution")
struct PacketFlowBridgeBoundedTests {
  @Test("Darwin SO_NREAD plus recvmsg reports full truncated and zero-length datagrams")
  func darwinReceiveSizing() throws {
    let socketIO = DarwinPacketBridgeSocketIO()
    let pair = try socketIO.makeDatagramSocketPair()
    defer {
      try? socketIO.closeDescriptor(pair.hevDescriptor)
      try? socketIO.closeDescriptor(pair.bridgeDescriptor)
    }

    let oversized = Data([1, 2, 3, 4, 5, 6])
    let sent = try oversized.withUnsafeBytes { bytes in
      try socketIO.sendDatagram(on: pair.hevDescriptor, bytes: bytes)
    }
    #expect(sent == oversized.count)
    var receiveBuffer = [UInt8](repeating: 0, count: 4)
    let truncated = try receiveBuffer.withUnsafeMutableBytes { bytes in
      try socketIO.receiveDatagram(on: pair.bridgeDescriptor, into: bytes)
    }
    #expect(truncated.copiedBytes == 4)
    #expect(truncated.fullDatagramBytes == 6)
    #expect(truncated.wasTruncated)

    let empty = Data()
    let emptySent = try empty.withUnsafeBytes { bytes in
      try socketIO.sendDatagram(on: pair.hevDescriptor, bytes: bytes)
    }
    #expect(emptySent == 0)
    let zeroLength = try receiveBuffer.withUnsafeMutableBytes { bytes in
      try socketIO.receiveDatagram(on: pair.bridgeDescriptor, into: bytes)
    }
    #expect(zeroLength.copiedBytes == 0)
    #expect(zeroLength.fullDatagramBytes == 0)
    #expect(!zeroLength.wasTruncated)
  }

  @Test("reverse PacketFlow rejection is fatal and the rejected batch is never retried")
  func reverseWriteRejection() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events, rejectWrites: true)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    fixture.socketIO.enqueueReceives([
      .datagram(familyWord(AF_INET) + Data([0x45, 0x01]))
    ])
    fixture.readinessFactory.latest?.signal(.readable)

    await #expect(
      throws: PacketFlowBridgeError.packetFlowFailure(operation: .packetFlowWrite)
    ) {
      try await handle.waitForTermination()
    }
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_fatal_packet_flow_error_total"] == 1)
    #expect(metrics.counters["packet_bridge_reverse_drop_write_rejected_packets_total"] == 1)
    #expect(await flow.writeAttemptCount == 1)
  }

  @Test("forward and reverse count slices yield deterministically")
  func countBoundedWorkSlices() async throws {
    let scheduler = CountingScheduler()
    let fixture = BridgeFixture(maximumWorkCount: 2, scheduler: scheduler)
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    let packet = TunnelPacket(payload: Data([0x45, 1]), addressFamily: .ipv4)
    let results: [PacketReadResult] = Array(repeating: .packet(packet), count: 5)
    await flow.enqueue(PacketReadBatch(results: results))
    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 5 })
    var metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_forward_budget_count_yield_total"] == 2)

    fixture.socketIO.enqueueReceives([
      .datagram(familyWord(AF_INET) + Data([0x45, 1])),
      .datagram(familyWord(AF_INET) + Data([0x45, 2])),
      .datagram(familyWord(AF_INET) + Data([0x45, 3])),
    ])
    fixture.readinessFactory.latest?.signal(.readable)
    #expect(await eventually { await flow.writtenPackets.count == 2 })
    fixture.readinessFactory.latest?.signal(.readable)
    #expect(await eventually { await flow.writtenPackets.count == 3 })
    metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_reverse_budget_count_yield_total"] == 1)
    await fixture.bridge.stop()
  }

  @Test("forward elapsed-time slices use the injected monotonic clock")
  func timeBoundedWorkSlices() async throws {
    let clock = AdvancingClock()
    let scheduler = CountingScheduler()
    let fixture = BridgeFixture(
      maximumWorkCount: 100,
      workTimeBudget: .seconds(1),
      clock: clock,
      scheduler: scheduler
    )
    fixture.socketIO.sendHook = { clock.advance(by: .seconds(2)) }
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    let packet = TunnelPacket(payload: Data([0x45, 1]), addressFamily: .ipv4)
    let results: [PacketReadResult] = Array(repeating: .packet(packet), count: 3)
    await flow.enqueue(PacketReadBatch(results: results))
    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 3 })
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_forward_budget_time_yield_total"] == 2)
    #expect(await scheduler.yieldCount == 2)
    await fixture.bridge.stop()
  }

  @Test("cancelling start at a startup barrier performs normal ordered cleanup")
  func startupCancellation() async {
    let barrier = CancellationLifecycleBarrier(stage: .socketPairCreated)
    let fixture = BridgeFixture(lifecycleBarrier: barrier)
    let flow = FakePacketFlow(events: fixture.events)
    let start = Task {
      try await fixture.bridge.start(
        packetFlow: flow,
        configuration: fixture.configuration
      )
    }
    #expect(await eventually { barrier.wasReached })
    start.cancel()
    await #expect(throws: CancellationError.self) {
      _ = try await start.value
    }
    #expect(fixture.consumer.borrowedDescriptors.isEmpty)
    #expect(fixture.socketIO.closedDescriptors == [101, 100])
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_cancellation_total"] == 1)
    #expect(metrics.counters["packet_bridge_terminal_failure_total"] == 0)
    #expect(await fixture.bridge.lifecycleState() == .stopped(lastRunID: "run-1"))
  }
}

private actor CountingScheduler: PacketBridgeScheduler {
  private(set) var yieldCount = 0

  func yield() async {
    yieldCount += 1
    await Task.yield()
  }
}

private final class AdvancingClock: TunnelClock, @unchecked Sendable {
  private let lock = NSLock()
  private var instant = ContinuousClock().now

  func now() -> ContinuousClock.Instant {
    lock.withLock { instant }
  }

  func sleep(for duration: Duration) async throws {
    try Task<Never, Never>.checkCancellation()
    advance(by: duration)
  }

  func advance(by duration: Duration) {
    lock.withLock { instant = instant.advanced(by: duration) }
  }
}

private final class CancellationLifecycleBarrier:
  PacketBridgeLifecycleBarrier, @unchecked Sendable
{
  private let lock = NSLock()
  private let stage: PacketBridgeLifecycleStage
  private var reached = false
  private let stream: AsyncStream<Void>
  private let continuation: AsyncStream<Void>.Continuation

  init(stage: PacketBridgeLifecycleStage) {
    self.stage = stage
    (stream, continuation) = AsyncStream.makeStream(of: Void.self)
  }

  var wasReached: Bool { lock.withLock { reached } }

  func reach(_ stage: PacketBridgeLifecycleStage) async throws {
    guard stage == self.stage else { return }
    lock.withLock { reached = true }
    for await _ in stream {
      return
    }
    throw CancellationError()
  }
}
