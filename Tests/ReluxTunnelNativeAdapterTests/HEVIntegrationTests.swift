import Darwin
import Foundation
import ReluxTunnelCore
import ReluxTunnelNativeAdapter
import Testing

@Suite("Pinned HEV integration", .serialized)
struct HEVIntegrationTests {
  @Test("approved low-memory configuration is emitted exactly")
  func configurationGeneration() throws {
    let data = try HEVConfigurationGenerator.makeConfiguration(
      baselineConfiguration(),
      access: testAccess()
    )
    let yaml = String(decoding: data, as: UTF8.self)

    #expect(yaml.contains("mtu: 1500"))
    #expect(yaml.contains("address: 127.0.0.1"))
    #expect(yaml.contains("port: 41414"))
    #expect(yaml.contains("udp: tcp"))
    #expect(yaml.contains("task-stack-size: 24576"))
    #expect(yaml.contains("tcp-buffer-size: 4096"))
    #expect(yaml.contains("udp-copy-buffer-nums: 2"))
    #expect(yaml.contains("max-session-count: 1200"))
    #expect(
      HEVConfigurationGenerator.effectiveMinimumTaskStackBytes(
        tcpBufferSizeBytes: 4_096,
        udpCopyBufferCount: 2
      ) == 24_576
    )
  }

  @Test("configuration rejects a stack request that upstream would silently raise")
  func configurationRejectsIneffectiveStack() {
    let configuration = InternalSOCKSConfiguration(
      mtuBytes: 1_500,
      taskStackSizeBytes: 24_575,
      tcpBufferSizeBytes: 4_096,
      udpCopyBufferCount: 2,
      maximumSessionCount: 1_200
    )
    #expect(
      throws: HEVIntegrationError.invalidConfiguration(field: "taskStackSizeBytes")
    ) {
      try HEVConfigurationGenerator.makeConfiguration(configuration, access: testAccess())
    }
  }

  @Test("external no-auth ingress is rejected before the adapter seam")
  func externalIngressRejected() async throws {
    let adapter = RecordingSOCKSAdapter()
    let boundary = HEVLoopbackSOCKSBoundary(
      adapter: adapter,
      credentials: testAccess().credentials,
      maximumPendingConnections: 4,
      authenticationTimeoutMilliseconds: 1_000
    )
    let access = try await boundary.start()

    let external = try connect(port: access.port)
    defer { Darwin.close(external) }
    try sendBytes([5, 1, 0], descriptor: external)
    #expect(try receiveBytes(count: 2, descriptor: external) == [5, 0xFF])
    #expect(adapter.acceptedCount == 0)

    let owned = try connect(port: access.port)
    defer { Darwin.close(owned) }
    try sendBytes([5, 1, 2], descriptor: owned)
    #expect(try receiveBytes(count: 2, descriptor: owned) == [5, 2])
    let username = Array(access.credentials.username.utf8)
    let password = Array(access.credentials.password.utf8)
    try sendBytes(
      [1, UInt8(username.count)] + username + [UInt8(password.count)] + password,
      descriptor: owned
    )
    let authReply = try receiveBytes(count: 2, descriptor: owned)
    #expect(authReply == [1, 0])
    let channel = await adapter.nextAcceptedChannel()
    #expect(adapter.acceptedCount == 1)
    channel.close()
    await boundary.stop()
  }

  @Test("SOCKS boundary stop waits for listener close and is idempotent")
  func socksBoundaryStopClosesListener() async throws {
    let boundary = HEVLoopbackSOCKSBoundary(
      adapter: RecordingSOCKSAdapter(),
      credentials: testAccess().credentials,
      maximumPendingConnections: 4,
      authenticationTimeoutMilliseconds: 1_000
    )
    let access = try await boundary.start()

    await boundary.stop()
    await boundary.stop()

    #expect(throws: (any Error).self) {
      try connect(port: access.port)
    }
  }

  @Test("borrow passes only endpoint B and quit joins without closing it")
  func descriptorBorrowLifecycle() async throws {
    var descriptors: [Int32] = [0, 0]
    #expect(Darwin.socketpair(AF_UNIX, SOCK_DGRAM, 0, &descriptors) == 0)
    defer {
      Darwin.close(descriptors[0])
      Darwin.close(descriptors[1])
    }

    let runtime = BlockingHEVRuntime()
    let boundary = RecordingBoundary(access: testAccess())
    let metrics = RecordingMetrics()
    let consumer = HEVDescriptorBorrowConsumer(
      configuration: baselineConfiguration(),
      boundaryFactory: SingleBoundaryFactory(boundary: boundary),
      runtime: runtime,
      logger: RecordingLogger(),
      metrics: metrics
    )

    let handle = try await consumer.beginBorrowing(descriptors[1])
    await runtime.waitUntilStarted()
    #expect(runtime.borrowedDescriptor == descriptors[1])
    #expect(runtime.configurationText.contains("udp-copy-buffer-nums: 2"))
    #expect(fcntl(descriptors[1], F_GETFD) >= 0)

    await handle.requestStop()
    await handle.requestStop()
    await handle.waitForReturn()
    await handle.waitForReturn()

    #expect(runtime.stopRequestCount == 1)
    #expect(runtime.statisticsCallCount == 1)
    #expect(runtime.statisticsAfterStopCallCount == 0)
    #expect(boundary.effectiveStopCount == 1)
    #expect(boundary.stopInvocationCount == 1)
    #expect(fcntl(descriptors[1], F_GETFD) >= 0)
    #expect(await metrics.counter("hev_start_total") == 1)
    #expect(await metrics.counter("hev_stop_request_total") == 1)
    #expect(await metrics.counter("hev_main_return_total") == 1)
    #expect(await metrics.gauge("hev_transmitted_packets") == 1)
    #expect(await metrics.gauge("hev_transmitted_bytes") == 2)
    #expect(await metrics.gauge("hev_received_packets") == 3)
    #expect(await metrics.gauge("hev_received_bytes") == 4)
  }

  @Test("quit is never sent after HEV main returns in either stop ordering")
  func descriptorBorrowStopOrderings() async throws {
    var descriptors: [Int32] = [0, 0]
    #expect(Darwin.socketpair(AF_UNIX, SOCK_DGRAM, 0, &descriptors) == 0)
    defer {
      Darwin.close(descriptors[0])
      Darwin.close(descriptors[1])
    }

    let returnedFirstRuntime = ReturnAwareHEVRuntime(waitForStop: false)
    let returnedFirstBoundary = RecordingBoundary(access: testAccess())
    let returnedFirstMetrics = RecordingMetrics()
    let returnedFirstConsumer = HEVDescriptorBorrowConsumer(
      configuration: baselineConfiguration(),
      boundaryFactory: SingleBoundaryFactory(boundary: returnedFirstBoundary),
      runtime: returnedFirstRuntime,
      logger: RecordingLogger(),
      metrics: returnedFirstMetrics
    )
    let returnedFirstHandle = try await returnedFirstConsumer.beginBorrowing(descriptors[1])

    await returnedFirstHandle.waitForReturn()
    await returnedFirstHandle.requestStop()

    #expect(returnedFirstRuntime.stopRequestCount == 0)
    #expect(returnedFirstRuntime.lateStopRequestCount == 0)
    #expect(returnedFirstBoundary.effectiveStopCount == 1)
    #expect(returnedFirstBoundary.stopInvocationCount == 1)
    #expect(await returnedFirstMetrics.counter("hev_stop_request_total") == 1)

    let stoppedFirstRuntime = ReturnAwareHEVRuntime(waitForStop: true)
    let stoppedFirstBoundary = RecordingBoundary(access: testAccess())
    let stoppedFirstConsumer = HEVDescriptorBorrowConsumer(
      configuration: baselineConfiguration(),
      boundaryFactory: SingleBoundaryFactory(boundary: stoppedFirstBoundary),
      runtime: stoppedFirstRuntime,
      logger: RecordingLogger(),
      metrics: RecordingMetrics()
    )
    let stoppedFirstHandle = try await stoppedFirstConsumer.beginBorrowing(descriptors[1])
    await stoppedFirstRuntime.waitUntilStarted()

    await stoppedFirstHandle.requestStop()
    await stoppedFirstHandle.waitForReturn()

    #expect(stoppedFirstRuntime.stopRequestCount == 1)
    #expect(stoppedFirstRuntime.lateStopRequestCount == 0)
    #expect(stoppedFirstBoundary.effectiveStopCount == 1)
    #expect(stoppedFirstBoundary.stopInvocationCount == 1)
    #expect(fcntl(descriptors[1], F_GETFD) >= 0)
  }

  @Test("startup failure stops listener state and releases the process lease")
  func startupFailureCleanup() async throws {
    var descriptors: [Int32] = [0, 0]
    #expect(Darwin.socketpair(AF_UNIX, SOCK_DGRAM, 0, &descriptors) == 0)
    defer {
      Darwin.close(descriptors[0])
      Darwin.close(descriptors[1])
    }

    let failingBoundary = FailingBoundary()
    let metrics = RecordingMetrics()
    let failingConsumer = HEVDescriptorBorrowConsumer(
      configuration: baselineConfiguration(),
      boundaryFactory: FailingBoundaryFactory(boundary: failingBoundary),
      runtime: UnexpectedHEVRuntime(),
      logger: RecordingLogger(),
      metrics: metrics
    )
    await #expect(throws: HEVIntegrationError.socksBoundaryFailed(code: EACCES)) {
      try await failingConsumer.beginBorrowing(descriptors[1])
    }
    #expect(failingBoundary.effectiveStopCount == 1)
    #expect(fcntl(descriptors[1], F_GETFD) >= 0)
    #expect(await metrics.counter("hev_startup_failure_total") == 1)

    let runtime = BlockingHEVRuntime()
    let replacementBoundary = RecordingBoundary(access: testAccess())
    let replacement = HEVDescriptorBorrowConsumer(
      configuration: baselineConfiguration(),
      boundaryFactory: SingleBoundaryFactory(boundary: replacementBoundary),
      runtime: runtime,
      logger: RecordingLogger(),
      metrics: metrics
    )
    let handle = try await replacement.beginBorrowing(descriptors[1])
    await runtime.waitUntilStarted()
    await handle.requestStop()
    await handle.waitForReturn()
    #expect(fcntl(descriptors[1], F_GETFD) >= 0)
  }

  @Test("HEV/core/task/lwIP notices are bundled and trace pinned revisions")
  func noticeBundle() {
    let notice = HEVNoticeBundle.contents()
    #expect(notice.contains("hev-socks5-tunnel @ ad7600497931205105b08367bd1b450048157e40"))
    #expect(notice.contains("hev-socks5-core @ c234519072ff5b928b90b304da9a666bcb440455"))
    #expect(notice.contains("hev-task-system @ b1afa0e21fb4ed5a69560e78e54baf0efdebe171"))
    #expect(notice.contains("lwIP @ 2a11c14c7a32887af25a034e82ef18b0b12076ac"))
    #expect(notice.contains("SPDX-License-Identifier: BSD-3-Clause"))
  }
}

private func baselineConfiguration() -> InternalSOCKSConfiguration {
  InternalSOCKSConfiguration(
    mtuBytes: 1_500,
    taskStackSizeBytes: 24_576,
    tcpBufferSizeBytes: 4_096,
    udpCopyBufferCount: 2,
    maximumSessionCount: 1_200
  )
}

private func testAccess() -> HEVSOCKSAccess {
  HEVSOCKSAccess(
    port: 41_414,
    credentials: HEVSOCKSCredentials(
      username: "relux-test-user",
      password: "relux-test-password"
    )
  )
}

private func connect(port: UInt16) throws -> Int32 {
  let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
  guard descriptor >= 0 else {
    throw HEVIntegrationError.socksBoundaryFailed(code: errno)
  }
  var address = sockaddr_in()
  address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
  address.sin_family = sa_family_t(AF_INET)
  address.sin_port = port.bigEndian
  address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
  let result = withUnsafePointer(to: &address) { pointer in
    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  guard result == 0 else {
    let code = errno
    Darwin.close(descriptor)
    throw HEVIntegrationError.socksBoundaryFailed(code: code)
  }
  return descriptor
}

private func sendBytes(_ bytes: [UInt8], descriptor: Int32) throws {
  var offset = 0
  while offset < bytes.count {
    let sent = bytes.withUnsafeBytes {
      Darwin.send(descriptor, $0.baseAddress! + offset, bytes.count - offset, 0)
    }
    guard sent > 0 else {
      if sent < 0, errno == EINTR { continue }
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }
    offset += sent
  }
}

private func receiveBytes(count: Int, descriptor: Int32) throws -> [UInt8] {
  var result = [UInt8](repeating: 0, count: count)
  var offset = 0
  while offset < count {
    let received = result.withUnsafeMutableBytes {
      Darwin.recv(descriptor, $0.baseAddress! + offset, count - offset, 0)
    }
    guard received > 0 else {
      if received < 0, errno == EINTR { continue }
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }
    offset += received
  }
  return result
}

private final class RecordingSOCKSAdapter: HEVSOCKSConnectionAdapter, @unchecked Sendable {
  private let lock = NSLock()
  private let stream: AsyncStream<HEVSOCKSChannel>
  private let continuation: AsyncStream<HEVSOCKSChannel>.Continuation
  private var count = 0

  init() {
    let pair = AsyncStream<HEVSOCKSChannel>.makeStream()
    stream = pair.stream
    continuation = pair.continuation
  }

  var acceptedCount: Int {
    lock.withLock { count }
  }

  func acceptAuthenticatedConnection(_ channel: HEVSOCKSChannel) {
    lock.withLock { count += 1 }
    continuation.yield(channel)
  }

  func nextAcceptedChannel() async -> HEVSOCKSChannel {
    var iterator = stream.makeAsyncIterator()
    return await iterator.next()!
  }
}

private final class RecordingBoundary: HEVSOCKSBoundary, @unchecked Sendable {
  private let access: HEVSOCKSAccess
  private let lock = NSLock()
  private var stopped = false
  private var stopCount = 0
  private var stopInvocations = 0

  init(access: HEVSOCKSAccess) {
    self.access = access
  }

  var effectiveStopCount: Int {
    lock.withLock { stopCount }
  }

  var stopInvocationCount: Int {
    lock.withLock { stopInvocations }
  }

  func start() async throws -> HEVSOCKSAccess {
    access
  }

  func stop() async {
    lock.withLock {
      stopInvocations += 1
      guard !stopped else { return }
      stopped = true
      stopCount += 1
    }
  }
}

private struct SingleBoundaryFactory: HEVSOCKSBoundaryFactory {
  let boundary: RecordingBoundary

  func makeBoundary() -> any HEVSOCKSBoundary {
    boundary
  }
}

private final class FailingBoundary: HEVSOCKSBoundary, @unchecked Sendable {
  private let lock = NSLock()
  private var stopped = false
  private var stopCount = 0

  var effectiveStopCount: Int {
    lock.withLock { stopCount }
  }

  func start() async throws -> HEVSOCKSAccess {
    throw HEVIntegrationError.socksBoundaryFailed(code: EACCES)
  }

  func stop() async {
    lock.withLock {
      guard !stopped else { return }
      stopped = true
      stopCount += 1
    }
  }
}

private struct FailingBoundaryFactory: HEVSOCKSBoundaryFactory {
  let boundary: FailingBoundary

  func makeBoundary() -> any HEVSOCKSBoundary {
    boundary
  }
}

private struct UnexpectedHEVRuntime: HEVNativeRuntime {
  func run(configuration: Data, tunnelDescriptor: Int32) -> Int32 {
    Issue.record("HEV runtime must not start after boundary failure")
    return -1
  }

  func requestStop() {}

  func statistics() -> HEVTrafficStatistics {
    HEVTrafficStatistics(
      transmittedPackets: 0,
      transmittedBytes: 0,
      receivedPackets: 0,
      receivedBytes: 0
    )
  }
}

private final class BlockingHEVRuntime: HEVNativeRuntime, @unchecked Sendable {
  private let condition = NSCondition()
  private let startedStream: AsyncStream<Void>
  private let startedContinuation: AsyncStream<Void>.Continuation
  private var shouldStop = false
  private var descriptor: Int32?
  private var configuration = ""
  private var stops = 0
  private var statisticsCalls = 0
  private var statisticsAfterStopCalls = 0

  init() {
    let pair = AsyncStream<Void>.makeStream()
    startedStream = pair.stream
    startedContinuation = pair.continuation
  }

  var borrowedDescriptor: Int32? {
    condition.withLock { descriptor }
  }

  var configurationText: String {
    condition.withLock { configuration }
  }

  var stopRequestCount: Int {
    condition.withLock { stops }
  }

  var statisticsCallCount: Int {
    condition.withLock { statisticsCalls }
  }

  var statisticsAfterStopCallCount: Int {
    condition.withLock { statisticsAfterStopCalls }
  }

  func run(configuration: Data, tunnelDescriptor: Int32) -> Int32 {
    condition.lock()
    descriptor = tunnelDescriptor
    self.configuration = String(decoding: configuration, as: UTF8.self)
    startedContinuation.yield()
    while !shouldStop {
      condition.wait()
    }
    condition.unlock()
    return 0
  }

  func requestStop() {
    condition.withLock {
      stops += 1
      shouldStop = true
      condition.broadcast()
    }
  }

  func statistics() -> HEVTrafficStatistics {
    condition.withLock {
      statisticsCalls += 1
      if shouldStop {
        statisticsAfterStopCalls += 1
        return HEVTrafficStatistics(
          transmittedPackets: 0,
          transmittedBytes: 0,
          receivedPackets: 0,
          receivedBytes: 0
        )
      }
      return HEVTrafficStatistics(
        transmittedPackets: 1,
        transmittedBytes: 2,
        receivedPackets: 3,
        receivedBytes: 4
      )
    }
  }

  func waitUntilStarted() async {
    var iterator = startedStream.makeAsyncIterator()
    _ = await iterator.next()
  }
}

private final class ReturnAwareHEVRuntime: HEVNativeRuntime, @unchecked Sendable {
  private let condition = NSCondition()
  private let waitForStop: Bool
  private let startedStream: AsyncStream<Void>
  private let startedContinuation: AsyncStream<Void>.Continuation
  private var shouldStop = false
  private var returned = false
  private var stopRequests = 0
  private var lateStopRequests = 0

  init(waitForStop: Bool) {
    self.waitForStop = waitForStop
    let pair = AsyncStream<Void>.makeStream()
    startedStream = pair.stream
    startedContinuation = pair.continuation
  }

  var stopRequestCount: Int {
    condition.withLock { stopRequests }
  }

  var lateStopRequestCount: Int {
    condition.withLock { lateStopRequests }
  }

  func run(configuration: Data, tunnelDescriptor: Int32) -> Int32 {
    condition.lock()
    startedContinuation.yield()
    while waitForStop && !shouldStop {
      condition.wait()
    }
    returned = true
    condition.unlock()
    return 0
  }

  func requestStop() {
    condition.withLock {
      if returned {
        lateStopRequests += 1
        Issue.record("requestStop must not be called after HEV main returns")
        return
      }
      stopRequests += 1
      shouldStop = true
      condition.broadcast()
    }
  }

  func statistics() -> HEVTrafficStatistics {
    HEVTrafficStatistics(
      transmittedPackets: 0,
      transmittedBytes: 0,
      receivedPackets: 0,
      receivedBytes: 0
    )
  }

  func waitUntilStarted() async {
    var iterator = startedStream.makeAsyncIterator()
    _ = await iterator.next()
  }
}

private actor RecordingMetrics: TunnelMetrics {
  private var counters: [String: UInt64] = [:]
  private var gauges: [String: Int64] = [:]

  func incrementCounter(named name: String, by amount: UInt64) {
    counters[name, default: 0] += amount
  }

  func setGauge(named name: String, to value: Int64) {
    gauges[name] = value
  }

  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: counters, gauges: gauges)
  }

  func counter(_ name: String) -> UInt64 {
    counters[name, default: 0]
  }

  func gauge(_ name: String) -> Int64 {
    gauges[name, default: 0]
  }
}

private struct RecordingLogger: TunnelLogger {
  func log(
    level: TunnelLogLevel,
    message: String,
    fields: [String: TunnelLogField]
  ) {}
}
