import Darwin
import Foundation
import ReluxTunnelCore
import Testing

@Suite("PacketFlowBridge public socket pair")
struct PacketFlowBridgeTests {
  @Test("normal stop preserves flags, joins the borrow, and closes B before A once")
  func normalStopOwnershipAndConfiguration() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )

    #expect(fixture.consumer.borrowedDescriptors == [101])
    #expect(fixture.socketIO.descriptorFlagsSnapshot[100] == (0x40 | FD_CLOEXEC))
    #expect(fixture.socketIO.descriptorFlagsSnapshot[101] == (0x80 | FD_CLOEXEC))
    #expect(fixture.socketIO.statusFlagsSnapshot[100] == (0x100 | O_NONBLOCK))
    #expect(fixture.socketIO.statusFlagsSnapshot[101] == (0x200 | O_NONBLOCK))
    #expect(fixture.socketIO.bufferRequests.count == 4)

    await fixture.bridge.stop()
    try await handle.waitForTermination()

    #expect(fixture.socketIO.closedDescriptors == [101, 100])
    #expect(
      fixture.events.snapshot().suffix(6) == [
        "flow.shutdown",
        "readiness.cancel",
        "borrow.stop",
        "borrow.return",
        "close.101",
        "close.100",
      ]
    )
    #expect(await fixture.bridge.lifecycleState() == .stopped(lastRunID: "run-1"))
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_start_total"] == 1)
    #expect(metrics.counters["packet_bridge_stop_total"] == 1)
    #expect(metrics.gauges["packet_bridge_socket_a_send_buffer_requested_bytes"] == 4096)
    #expect(metrics.gauges["packet_bridge_socket_b_receive_buffer_effective_bytes"] == 4096)
  }

  @Test("forward framing derives SDK families and preserves each payload")
  func forwardFramingAndMalformedDrop() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    let ipv4 = Data([0x45, 0x01, 0x02])
    let ipv6 = Data([0x60, 0x03, 0x04, 0x05])
    await flow.enqueue(
      PacketReadBatch(results: [
        .malformed(.unsupportedAddressFamily(Int32.max)),
        .packet(TunnelPacket(payload: ipv4, addressFamily: .ipv4)),
        .packet(TunnelPacket(payload: ipv6, addressFamily: .ipv6)),
      ])
    )

    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 2 })
    let sent = fixture.socketIO.sentDatagrams
    #expect(sent[0] == familyWord(AF_INET) + ipv4)
    #expect(sent[1] == familyWord(AF_INET6) + ipv6)

    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_forward_packets_received_total"] == 3)
    #expect(metrics.counters["packet_bridge_forward_drop_malformed_total"] == 1)
    #expect(metrics.counters["packet_bridge_forward_datagrams_sent_total"] == 2)
    #expect(metrics.gauges["packet_bridge_forward_datagram_max_bytes"] == 8)
    await fixture.bridge.stop()
  }

  @Test("reverse framing drops malformed datagrams and writes valid packets in order")
  func reverseFramingAndZeroLengthDatagram() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    let ipv4 = Data([0x45, 0x11])
    let ipv6 = Data([0x60, 0x22, 0x33])
    fixture.socketIO.enqueueReceives([
      .datagram(Data()),
      .datagram(Data([0, 1, 2])),
      .datagram(familyWord(Int32.max) + Data([0x45])),
      .datagram(familyWord(AF_INET) + Data([0x60])),
      .datagram(familyWord(AF_INET) + ipv4),
      .datagram(familyWord(AF_INET6) + ipv6),
    ])
    fixture.readinessFactory.latest?.signal(.readable)

    #expect(await eventually { await flow.writtenPackets.count == 2 })
    #expect(
      await flow.writtenPackets == [
        TunnelPacket(payload: ipv4, addressFamily: .ipv4),
        TunnelPacket(payload: ipv6, addressFamily: .ipv6),
      ]
    )
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_reverse_datagrams_received_total"] == 6)
    #expect(metrics.counters["packet_bridge_reverse_drop_malformed_total"] == 4)
    #expect(metrics.counters["packet_bridge_fatal_peer_eof_total"] == 0)
    #expect(metrics.counters["packet_bridge_reverse_packets_written_total"] == 2)

    await fixture.bridge.stop()
    try await handle.waitForTermination()
  }

  @Test("would-block and ENOBUFS drop once; EMSGSIZE is the one fatal transition")
  func forwardBackpressureAndFatalMessageSize() async throws {
    let fixture = BridgeFixture()
    fixture.socketIO.enqueueSends([
      .error(EWOULDBLOCK),
      .error(ENOBUFS),
      .error(EMSGSIZE),
    ])
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    let packet = TunnelPacket(payload: Data([0x45, 1]), addressFamily: .ipv4)
    await flow.enqueue(
      PacketReadBatch(results: [.packet(packet), .packet(packet), .packet(packet)]))

    await #expect(
      throws: PacketFlowBridgeError.messageTooLarge(
        direction: .forward,
        datagramBytes: 6,
        configuredMaximumBytes: 24
      )
    ) {
      try await handle.waitForTermination()
    }
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_forward_drop_would_block_total"] == 1)
    #expect(metrics.counters["packet_bridge_forward_drop_no_buffer_total"] == 1)
    #expect(metrics.counters["packet_bridge_fatal_message_too_large_total"] == 1)
    #expect(metrics.counters["packet_bridge_terminal_failure_total"] == 1)
    #expect(fixture.logger.messages.filter { $0.message == "packet_bridge.fatal" }.count == 1)
    #expect(fixture.socketIO.closedDescriptors == [101, 100])
  }

  @Test("first persistent socket error wins over a later HEV return")
  func firstErrorWins() async throws {
    let fixture = BridgeFixture(autoReturnBorrowOnStop: false)
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    fixture.socketIO.enqueueReceives([.error(EIO)])
    fixture.readinessFactory.latest?.signal(.readable)
    #expect(
      await eventually {
        if case .failing = await fixture.bridge.lifecycleState() { return true }
        return false
      }
    )
    fixture.consumer.latest?.returnNow()

    await #expect(
      throws: PacketFlowBridgeError.socketError(operation: .receive, errno: EIO)
    ) {
      try await handle.waitForTermination()
    }
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_fatal_socket_error_total"] == 1)
    #expect(metrics.counters["packet_bridge_fatal_peer_eof_total"] == 0)
    #expect(fixture.logger.messages.filter { $0.message == "packet_bridge.fatal" }.count == 1)
  }

  @Test("startup configuration failure closes both owned endpoints without borrowing")
  func startupFailureCleanup() async {
    let fixture = BridgeFixture()
    fixture.socketIO.failOperation = .setStatusFlags
    let flow = FakePacketFlow(events: fixture.events)

    await #expect(
      throws: PacketFlowBridgeError.socketError(operation: .setStatusFlags, errno: EIO)
    ) {
      _ = try await fixture.bridge.start(
        packetFlow: flow,
        configuration: fixture.configuration
      )
    }
    #expect(fixture.consumer.borrowedDescriptors.isEmpty)
    #expect(fixture.socketIO.closedDescriptors == [101, 100])
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_startup_failure_total"] == 1)
    #expect(metrics.counters["packet_bridge_terminal_failure_total"] == 1)
  }

  @Test("metric schema is exact and every run starts from zero")
  func metricSchema() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    let snapshot = await fixture.bridge.metrics()
    #expect(Set(snapshot.counters.keys) == Set(PacketBridgeMetricSchema.counters.keys))
    #expect(Set(snapshot.gauges.keys) == Set(PacketBridgeMetricSchema.gauges.keys))
    #expect(snapshot.schemaVersion == PacketBridgeMetricSchema.version)
    #expect(snapshot.counters.values.allSatisfy { $0 == 0 || $0 == 1 })
    #expect(PacketBridgeMetricSchema.counters.count == 30)
    #expect(PacketBridgeMetricSchema.gauges.count == 12)
    await fixture.bridge.stop()
  }

  @Test("one hundred restart cycles restore descriptor and task ownership baselines")
  func repeatedRestart() async throws {
    let fixture = BridgeFixture()
    for iteration in 0..<100 {
      let flow = FakePacketFlow(events: fixture.events)
      let handle = try await fixture.bridge.start(
        packetFlow: flow,
        configuration: fixture.configuration
      )
      await fixture.bridge.stop()
      try await handle.waitForTermination()
      #expect(
        await fixture.bridge.lifecycleState()
          == .stopped(lastRunID: "run-\(iteration + 1)")
      )
    }
    #expect(fixture.socketIO.closedDescriptors.count == 200)
    #expect(Set(fixture.socketIO.closedDescriptors).count == 200)
    #expect(fixture.consumer.borrowedDescriptors.count == 100)
  }
}

final class BridgeFixture: @unchecked Sendable {
  let events = BridgeEventRecorder()
  let socketIO: FakePacketBridgeSocketIO
  let readinessFactory: FakeReadinessFactory
  let consumer: FakeDescriptorConsumer
  let logger = FakeTunnelLogger()
  let sink = FakeTunnelMetrics()
  let runIDs = SequentialRunIDSource()
  let bridge: PacketFlowBridge
  let configuration: PacketBridgeConfiguration

  init(
    autoReturnBorrowOnStop: Bool = true,
    maximumWorkCount: Int = 8,
    workTimeBudget: Duration = .seconds(1),
    clock: any TunnelClock = ContinuousTunnelClock(),
    scheduler: any PacketBridgeScheduler = TaskPacketBridgeScheduler(),
    lifecycleBarrier: any PacketBridgeLifecycleBarrier = NoOpPacketBridgeLifecycleBarrier()
  ) {
    socketIO = FakePacketBridgeSocketIO(events: events)
    readinessFactory = FakeReadinessFactory(events: events)
    consumer = FakeDescriptorConsumer(
      events: events,
      autoReturnOnStop: autoReturnBorrowOnStop
    )
    configuration = PacketBridgeConfiguration(
      mtu: 20,
      sendBufferBytes: 4096,
      receiveBufferBytes: 4096,
      maximumWorkCount: maximumWorkCount,
      workTimeBudget: workTimeBudget,
      diagnosticsWindow: .seconds(60)
    )
    bridge = PacketFlowBridge(
      socketIO: socketIO,
      readinessFactory: readinessFactory,
      descriptorConsumer: consumer,
      clock: clock,
      scheduler: scheduler,
      logger: logger,
      metrics: sink,
      runIDSource: runIDs,
      lifecycleBarrier: lifecycleBarrier
    )
  }
}

final class BridgeEventRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var events: [String] = []

  func record(_ event: String) {
    lock.withLock { events.append(event) }
  }

  func snapshot() -> [String] {
    lock.withLock { events }
  }
}

actor FakePacketFlow: PacketFlow {
  private let events: BridgeEventRecorder
  private var queued: [PacketReadBatch] = []
  private var readWaiter: CheckedContinuation<PacketReadBatch, Error>?
  private var isShutDown = false
  private(set) var writtenPackets: [TunnelPacket] = []
  private(set) var writeAttemptCount = 0
  private let rejectWrites: Bool

  init(events: BridgeEventRecorder, rejectWrites: Bool = false) {
    self.events = events
    self.rejectWrites = rejectWrites
  }

  func readPackets() async throws -> PacketReadBatch {
    if isShutDown {
      throw PacketFlowError.adapterShutDown
    }
    if !queued.isEmpty {
      return queued.removeFirst()
    }
    return try await withCheckedThrowingContinuation { continuation in
      readWaiter = continuation
    }
  }

  func writePackets(_ packets: [TunnelPacket]) async throws {
    writeAttemptCount += 1
    if rejectWrites {
      throw PacketFlowError.writeRejected
    }
    writtenPackets.append(contentsOf: packets)
  }

  func shutdown() async {
    guard !isShutDown else { return }
    isShutDown = true
    events.record("flow.shutdown")
    let waiter = readWaiter
    readWaiter = nil
    waiter?.resume(throwing: PacketFlowError.adapterShutDown)
  }

  func enqueue(_ batch: PacketReadBatch) {
    if let waiter = readWaiter {
      readWaiter = nil
      waiter.resume(returning: batch)
    } else {
      queued.append(batch)
    }
  }
}

enum FakeSendOutcome: Sendable {
  case full
  case short(Int)
  case error(Int32)
}

enum FakeReceiveOutcome: Sendable {
  case datagram(Data, fullBytes: Int? = nil, truncated: Bool = false)
  case error(Int32)
}

final class FakePacketBridgeSocketIO: PacketBridgeSocketIO, @unchecked Sendable {
  struct BufferRequest: Equatable {
    let descriptor: Int32
    let buffer: PacketBridgeSocketBuffer
    let bytes: Int32
  }

  private let lock = NSLock()
  private let events: BridgeEventRecorder
  private var nextDescriptor: Int32 = 100
  private var descriptorFlags: [Int32: Int32] = [:]
  private var statusFlags: [Int32: Int32] = [:]
  private var sendBuffers: [Int32: Int32] = [:]
  private var receiveBuffers: [Int32: Int32] = [:]
  private var requests: [BufferRequest] = []
  private var sends: [Data] = []
  private var sendOutcomes: [FakeSendOutcome] = []
  private var receiveOutcomes: [FakeReceiveOutcome] = []
  private var closes: [Int32] = []
  var failOperation: PacketBridgeOperation?
  var sendHook: (@Sendable () -> Void)?

  init(events: BridgeEventRecorder) {
    self.events = events
  }

  var descriptorFlagsSnapshot: [Int32: Int32] { lock.withLock { descriptorFlags } }
  var statusFlagsSnapshot: [Int32: Int32] { lock.withLock { statusFlags } }
  var bufferRequests: [BufferRequest] { lock.withLock { requests } }
  var sentDatagrams: [Data] { lock.withLock { sends } }
  var closedDescriptors: [Int32] { lock.withLock { closes } }

  func makeDatagramSocketPair() throws -> PacketBridgeSocketPair {
    try failIfNeeded(.socketPair)
    return lock.withLock {
      let a = nextDescriptor
      let b = nextDescriptor + 1
      nextDescriptor += 2
      descriptorFlags[a] = 0x40
      descriptorFlags[b] = 0x80
      statusFlags[a] = 0x100
      statusFlags[b] = 0x200
      return PacketBridgeSocketPair(bridgeDescriptor: a, hevDescriptor: b)
    }
  }

  func descriptorFlags(for descriptor: Int32) throws -> Int32 {
    try failIfNeeded(.getDescriptorFlags)
    return lock.withLock { descriptorFlags[descriptor] ?? 0 }
  }

  func setDescriptorFlags(_ flags: Int32, for descriptor: Int32) throws {
    try failIfNeeded(.setDescriptorFlags)
    lock.withLock { descriptorFlags[descriptor] = flags }
  }

  func statusFlags(for descriptor: Int32) throws -> Int32 {
    try failIfNeeded(.getStatusFlags)
    return lock.withLock { statusFlags[descriptor] ?? 0 }
  }

  func setStatusFlags(_ flags: Int32, for descriptor: Int32) throws {
    try failIfNeeded(.setStatusFlags)
    lock.withLock { statusFlags[descriptor] = flags }
  }

  func setSocketBuffer(
    _ buffer: PacketBridgeSocketBuffer,
    bytes: Int32,
    for descriptor: Int32
  ) throws {
    try failIfNeeded(buffer == .send ? .setSendBuffer : .setReceiveBuffer)
    lock.withLock {
      requests.append(.init(descriptor: descriptor, buffer: buffer, bytes: bytes))
      if buffer == .send {
        sendBuffers[descriptor] = bytes
      } else {
        receiveBuffers[descriptor] = bytes
      }
    }
  }

  func socketBuffer(
    _ buffer: PacketBridgeSocketBuffer,
    for descriptor: Int32
  ) throws -> Int32 {
    try failIfNeeded(buffer == .send ? .getSendBuffer : .getReceiveBuffer)
    return lock.withLock {
      buffer == .send ? sendBuffers[descriptor] ?? 0 : receiveBuffers[descriptor] ?? 0
    }
  }

  func sendDatagram(
    on descriptor: Int32,
    bytes: UnsafeRawBufferPointer
  ) throws -> Int {
    let data = Data(bytes)
    let outcome: FakeSendOutcome = lock.withLock {
      sends.append(data)
      return sendOutcomes.isEmpty ? .full : sendOutcomes.removeFirst()
    }
    switch outcome {
    case .full:
      sendHook?()
      return bytes.count
    case .short(let count):
      sendHook?()
      return count
    case .error(let code):
      throw PacketFlowBridgeError.socketError(operation: .send, errno: code)
    }
  }

  func receiveDatagram(
    on descriptor: Int32,
    into bytes: UnsafeMutableRawBufferPointer
  ) throws -> PacketBridgeReceiveResult {
    try lock.withLock {
      guard !receiveOutcomes.isEmpty else {
        throw PacketFlowBridgeError.socketError(operation: .receive, errno: EAGAIN)
      }
      let outcome = receiveOutcomes.removeFirst()
      switch outcome {
      case .error(let code):
        throw PacketFlowBridgeError.socketError(operation: .receive, errno: code)
      case .datagram(let data, let fullBytes, let truncated):
        let copied = min(data.count, bytes.count)
        data.prefix(copied).withUnsafeBytes { source in
          bytes.copyMemory(from: source)
        }
        return PacketBridgeReceiveResult(
          copiedBytes: copied,
          fullDatagramBytes: fullBytes ?? data.count,
          wasTruncated: truncated
        )
      }
    }
  }

  func closeDescriptor(_ descriptor: Int32) throws {
    try failIfNeeded(.close)
    lock.withLock { closes.append(descriptor) }
    events.record("close.\(descriptor)")
  }

  func enqueueSends(_ outcomes: [FakeSendOutcome]) {
    lock.withLock { sendOutcomes.append(contentsOf: outcomes) }
  }

  func enqueueReceives(_ outcomes: [FakeReceiveOutcome]) {
    lock.withLock { receiveOutcomes.append(contentsOf: outcomes) }
  }

  private func failIfNeeded(_ operation: PacketBridgeOperation) throws {
    if lock.withLock({ failOperation == operation }) {
      throw PacketFlowBridgeError.socketError(operation: operation, errno: EIO)
    }
  }
}

final class FakeReadinessSource: PacketBridgeReadinessSource, @unchecked Sendable {
  private let events: BridgeEventRecorder
  private let stream: AsyncStream<PacketBridgeReadinessEvent>
  private let continuation: AsyncStream<PacketBridgeReadinessEvent>.Continuation

  init(events: BridgeEventRecorder) {
    self.events = events
    (stream, continuation) = AsyncStream.makeStream(
      of: PacketBridgeReadinessEvent.self,
      bufferingPolicy: .bufferingNewest(1)
    )
  }

  func waitForEvent() async throws -> PacketBridgeReadinessEvent {
    for await event in stream {
      return event
    }
    throw CancellationError()
  }

  func cancel() async {
    events.record("readiness.cancel")
    continuation.finish()
  }

  func signal(_ event: PacketBridgeReadinessEvent) {
    continuation.yield(event)
  }
}

final class FakeReadinessFactory: PacketBridgeReadinessFactory, @unchecked Sendable {
  private let lock = NSLock()
  private let events: BridgeEventRecorder
  private var sources: [FakeReadinessSource] = []

  init(events: BridgeEventRecorder) {
    self.events = events
  }

  var latest: FakeReadinessSource? { lock.withLock { sources.last } }

  func makeReadinessSource(
    descriptor: Int32
  ) throws -> any PacketBridgeReadinessSource {
    let source = FakeReadinessSource(events: events)
    lock.withLock { sources.append(source) }
    return source
  }
}

final class FakeBorrowHandle: DescriptorBorrowHandle, @unchecked Sendable {
  private let lock = NSLock()
  private let events: BridgeEventRecorder
  private let autoReturnOnStop: Bool
  private var didReturn = false
  private var waiter: CheckedContinuation<Void, Never>?

  init(events: BridgeEventRecorder, autoReturnOnStop: Bool) {
    self.events = events
    self.autoReturnOnStop = autoReturnOnStop
  }

  func requestStop() async {
    events.record("borrow.stop")
    if autoReturnOnStop {
      returnNow()
    }
  }

  func waitForReturn() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      if didReturn {
        lock.unlock()
        continuation.resume()
      } else {
        waiter = continuation
        lock.unlock()
      }
    }
  }

  func returnNow() {
    lock.lock()
    guard !didReturn else {
      lock.unlock()
      return
    }
    didReturn = true
    let waiter = waiter
    self.waiter = nil
    lock.unlock()
    events.record("borrow.return")
    waiter?.resume()
  }
}

final class FakeDescriptorConsumer: DescriptorBorrowConsumer, @unchecked Sendable {
  private let lock = NSLock()
  private let events: BridgeEventRecorder
  private let autoReturnOnStop: Bool
  private var descriptors: [Int32] = []
  private var handles: [FakeBorrowHandle] = []

  init(events: BridgeEventRecorder, autoReturnOnStop: Bool) {
    self.events = events
    self.autoReturnOnStop = autoReturnOnStop
  }

  var borrowedDescriptors: [Int32] { lock.withLock { descriptors } }
  var latest: FakeBorrowHandle? { lock.withLock { handles.last } }

  func beginBorrowing(
    _ descriptor: Int32
  ) async throws -> any DescriptorBorrowHandle {
    let handle = FakeBorrowHandle(events: events, autoReturnOnStop: autoReturnOnStop)
    lock.withLock {
      descriptors.append(descriptor)
      handles.append(handle)
    }
    return handle
  }
}

final class FakeTunnelLogger: TunnelLogger, @unchecked Sendable {
  struct Message {
    let level: TunnelLogLevel
    let message: String
    let fields: [String: TunnelLogField]
  }

  private let lock = NSLock()
  private var storage: [Message] = []
  var messages: [Message] { lock.withLock { storage } }

  func log(
    level: TunnelLogLevel,
    message: String,
    fields: [String: TunnelLogField]
  ) {
    lock.withLock { storage.append(.init(level: level, message: message, fields: fields)) }
  }
}

actor FakeTunnelMetrics: TunnelMetrics {
  private var counters: [String: UInt64] = [:]
  private var gauges: [String: Int64] = [:]

  func incrementCounter(named name: String, by amount: UInt64) {
    counters[name, default: 0] = counters[name, default: 0].saturatingAdding(amount)
  }

  func setGauge(named name: String, to value: Int64) {
    gauges[name] = value
  }

  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: counters, gauges: gauges)
  }
}

final class SequentialRunIDSource: PacketBridgeRunIDSource, @unchecked Sendable {
  private let lock = NSLock()
  private var next = 1

  func nextRunID() -> String {
    lock.withLock {
      defer { next += 1 }
      return "run-\(next)"
    }
  }
}

func familyWord(_ family: Int32) -> Data {
  let value = UInt32(family)
  return Data([
    UInt8(truncatingIfNeeded: value >> 24),
    UInt8(truncatingIfNeeded: value >> 16),
    UInt8(truncatingIfNeeded: value >> 8),
    UInt8(truncatingIfNeeded: value),
  ])
}

func eventually(
  attempts: Int = 10_000,
  _ condition: @escaping @Sendable () async -> Bool
) async -> Bool {
  for _ in 0..<attempts {
    if await condition() {
      return true
    }
    await Task.yield()
  }
  return false
}

extension UInt64 {
  fileprivate func saturatingAdding(_ other: UInt64) -> UInt64 {
    let (result, overflow) = addingReportingOverflow(other)
    return overflow ? .max : result
  }
}
