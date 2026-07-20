import Darwin
import Dispatch
import Foundation
import HevSocks5Tunnel
import ReluxTunnelCore

public enum HEVIntegrationError: Error, Equatable, Sendable {
  case invalidConfiguration(field: String)
  case processAlreadyRunning
  case threadCreationFailed(code: Int32)
  case socksBoundaryFailed(code: Int32)
}

public struct HEVSOCKSCredentials: Equatable, Sendable {
  public let username: String
  public let password: String

  public init(username: String, password: String) {
    self.username = username
    self.password = password
  }
}

public struct HEVSOCKSAccess: Equatable, Sendable {
  public let port: UInt16
  public let credentials: HEVSOCKSCredentials

  public init(port: UInt16, credentials: HEVSOCKSCredentials) {
    self.port = port
    self.credentials = credentials
  }

  public let host = "127.0.0.1"
}

public struct HEVTrafficStatistics: Equatable, Sendable {
  public let transmittedPackets: UInt64
  public let transmittedBytes: UInt64
  public let receivedPackets: UInt64
  public let receivedBytes: UInt64

  public init(
    transmittedPackets: UInt64,
    transmittedBytes: UInt64,
    receivedPackets: UInt64,
    receivedBytes: UInt64
  ) {
    self.transmittedPackets = transmittedPackets
    self.transmittedBytes = transmittedBytes
    self.receivedPackets = receivedPackets
    self.receivedBytes = receivedBytes
  }
}

public protocol HEVNativeRuntime: Sendable {
  func run(configuration: Data, tunnelDescriptor: Int32) -> Int32
  func requestStop()
  func statistics() -> HEVTrafficStatistics
}

public struct PinnedHEVNativeRuntime: HEVNativeRuntime {
  public init() {}

  public func run(configuration: Data, tunnelDescriptor: Int32) -> Int32 {
    configuration.withUnsafeBytes { bytes in
      guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else {
        return -1
      }
      return Int32(
        hev_socks5_tunnel_main_from_str(
          baseAddress,
          UInt32(configuration.count),
          tunnelDescriptor
        )
      )
    }
  }

  public func requestStop() {
    hev_socks5_tunnel_quit()
  }

  public func statistics() -> HEVTrafficStatistics {
    var transmittedPackets = 0
    var transmittedBytes = 0
    var receivedPackets = 0
    var receivedBytes = 0
    hev_socks5_tunnel_stats(
      &transmittedPackets,
      &transmittedBytes,
      &receivedPackets,
      &receivedBytes
    )
    return HEVTrafficStatistics(
      transmittedPackets: UInt64(transmittedPackets),
      transmittedBytes: UInt64(transmittedBytes),
      receivedPackets: UInt64(receivedPackets),
      receivedBytes: UInt64(receivedBytes)
    )
  }
}

public protocol HEVSOCKSBoundary: AnyObject, Sendable {
  func start() async throws -> HEVSOCKSAccess
  func stop() async
}

public protocol HEVSOCKSBoundaryFactory: Sendable {
  func makeBoundary() -> any HEVSOCKSBoundary
}

public enum HEVConfigurationGenerator {
  public static let upstreamTaskStackBaseBytes = 20_480
  public static let upstreamUDPBufferBytes = 1_500

  public static func makeConfiguration(
    _ configuration: InternalSOCKSConfiguration,
    access: HEVSOCKSAccess
  ) throws -> Data {
    try validate(configuration, access: access)
    let udpMode: String
    switch configuration.udpMode {
    case .udpInTCP:
      udpMode = "tcp"
    }

    let yaml = """
      tunnel:
        mtu: \(configuration.mtuBytes)
        multi-queue: false
      socks5:
        address: \(access.host)
        port: \(access.port)
        udp: \(udpMode)
        username: \(access.credentials.username)
        password: \(access.credentials.password)
      misc:
        task-stack-size: \(configuration.taskStackSizeBytes)
        tcp-buffer-size: \(configuration.tcpBufferSizeBytes)
        udp-copy-buffer-nums: \(configuration.udpCopyBufferCount)
        max-session-count: \(configuration.maximumSessionCount)
        log-level: error
      """
    return Data(yaml.utf8)
  }

  public static func effectiveMinimumTaskStackBytes(
    tcpBufferSizeBytes: Int,
    udpCopyBufferCount: Int
  ) -> Int? {
    guard tcpBufferSizeBytes > 0, udpCopyBufferCount > 0 else {
      return nil
    }
    let (udpBytes, udpOverflow) = upstreamUDPBufferBytes.multipliedReportingOverflow(
      by: udpCopyBufferCount
    )
    guard !udpOverflow else {
      return nil
    }
    let (minimum, stackOverflow) = upstreamTaskStackBaseBytes.addingReportingOverflow(
      max(tcpBufferSizeBytes, udpBytes)
    )
    return stackOverflow ? nil : minimum
  }

  private static func validate(
    _ configuration: InternalSOCKSConfiguration,
    access: HEVSOCKSAccess
  ) throws {
    let positiveValues = [
      ("mtuBytes", configuration.mtuBytes),
      ("taskStackSizeBytes", configuration.taskStackSizeBytes),
      ("tcpBufferSizeBytes", configuration.tcpBufferSizeBytes),
      ("udpCopyBufferCount", configuration.udpCopyBufferCount),
      ("maximumSessionCount", configuration.maximumSessionCount),
    ]
    for (field, value) in positiveValues where value <= 0 || value > Int(UInt32.max) {
      throw HEVIntegrationError.invalidConfiguration(field: field)
    }
    guard access.port > 0 else {
      throw HEVIntegrationError.invalidConfiguration(field: "socksPort")
    }
    guard isYAMLSafeCredential(access.credentials.username) else {
      throw HEVIntegrationError.invalidConfiguration(field: "socksUsername")
    }
    guard isYAMLSafeCredential(access.credentials.password) else {
      throw HEVIntegrationError.invalidConfiguration(field: "socksPassword")
    }
    guard
      let minimum = effectiveMinimumTaskStackBytes(
        tcpBufferSizeBytes: configuration.tcpBufferSizeBytes,
        udpCopyBufferCount: configuration.udpCopyBufferCount
      ),
      configuration.taskStackSizeBytes >= minimum
    else {
      throw HEVIntegrationError.invalidConfiguration(field: "taskStackSizeBytes")
    }
  }

  private static func isYAMLSafeCredential(_ value: String) -> Bool {
    guard !value.isEmpty, value.utf8.count <= 255 else {
      return false
    }
    return value.utf8.allSatisfy {
      ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122)
        || $0 == 45
    }
  }
}

public final class HEVDescriptorBorrowConsumer: DescriptorBorrowConsumer, @unchecked Sendable {
  private let configuration: InternalSOCKSConfiguration
  private let boundaryFactory: any HEVSOCKSBoundaryFactory
  private let runtime: any HEVNativeRuntime
  private let logger: any TunnelLogger
  private let metrics: any TunnelMetrics

  public init(
    configuration: InternalSOCKSConfiguration,
    boundaryFactory: any HEVSOCKSBoundaryFactory,
    runtime: any HEVNativeRuntime = PinnedHEVNativeRuntime(),
    logger: any TunnelLogger,
    metrics: any TunnelMetrics
  ) {
    self.configuration = configuration
    self.boundaryFactory = boundaryFactory
    self.runtime = runtime
    self.logger = logger
    self.metrics = metrics
  }

  public func beginBorrowing(
    _ descriptor: Int32
  ) async throws -> any DescriptorBorrowHandle {
    guard HEVProcessLease.shared.acquire() else {
      throw HEVIntegrationError.processAlreadyRunning
    }

    let boundary = boundaryFactory.makeBoundary()
    do {
      let access = try await boundary.start()
      let generated = try HEVConfigurationGenerator.makeConfiguration(
        configuration,
        access: access
      )
      let context = HEVThreadContext(
        configuration: generated,
        descriptor: descriptor,
        runtime: runtime
      )
      var thread: pthread_t?
      let opaque = Unmanaged.passRetained(context).toOpaque()
      let result = pthread_create(&thread, nil, hevThreadEntry, opaque)
      guard result == 0, let thread else {
        Unmanaged<HEVThreadContext>.fromOpaque(opaque).release()
        throw HEVIntegrationError.threadCreationFailed(code: result)
      }

      await metrics.incrementCounter(named: "hev_start_total", by: 1)
      await recordConfigurationMetrics()
      logger.log(
        level: .info,
        message: "hev.started",
        fields: [
          "mtu_bytes": .init(String(configuration.mtuBytes), privacy: .public),
          "task_stack_size_bytes": .init(
            String(configuration.taskStackSizeBytes), privacy: .public),
          "tcp_buffer_size_bytes": .init(
            String(configuration.tcpBufferSizeBytes), privacy: .public),
          "udp_copy_buffer_count": .init(
            String(configuration.udpCopyBufferCount), privacy: .public),
          "maximum_session_count": .init(
            String(configuration.maximumSessionCount), privacy: .public),
          "udp_mode": .init("tcp", privacy: .public),
        ]
      )
      return HEVDescriptorBorrowHandle(
        thread: thread,
        context: context,
        boundary: boundary,
        runtime: runtime,
        logger: logger,
        metrics: metrics
      )
    } catch {
      await boundary.stop()
      HEVProcessLease.shared.release()
      await metrics.incrementCounter(named: "hev_startup_failure_total", by: 1)
      throw error
    }
  }

  private func recordConfigurationMetrics() async {
    await metrics.setGauge(named: "hev_configured_mtu_bytes", to: Int64(configuration.mtuBytes))
    await metrics.setGauge(
      named: "hev_configured_task_stack_size_bytes",
      to: Int64(configuration.taskStackSizeBytes)
    )
    await metrics.setGauge(
      named: "hev_configured_tcp_buffer_size_bytes",
      to: Int64(configuration.tcpBufferSizeBytes)
    )
    await metrics.setGauge(
      named: "hev_configured_udp_copy_buffer_count",
      to: Int64(configuration.udpCopyBufferCount)
    )
    await metrics.setGauge(
      named: "hev_configured_maximum_session_count",
      to: Int64(configuration.maximumSessionCount)
    )
  }
}

private final class HEVThreadContext: @unchecked Sendable {
  let configuration: Data
  let descriptor: Int32
  let runtime: any HEVNativeRuntime
  private let lock = NSLock()
  private var storedReturnCode: Int32?

  init(configuration: Data, descriptor: Int32, runtime: any HEVNativeRuntime) {
    self.configuration = configuration
    self.descriptor = descriptor
    self.runtime = runtime
  }

  func run() {
    let result = runtime.run(configuration: configuration, tunnelDescriptor: descriptor)
    lock.withLock {
      storedReturnCode = result
    }
  }

  var returnCode: Int32? {
    lock.withLock { storedReturnCode }
  }
}

private let hevThreadEntry: @convention(c) (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? = {
  opaque in
  let context = Unmanaged<HEVThreadContext>.fromOpaque(opaque).takeRetainedValue()
  context.run()
  return nil
}

private final class HEVDescriptorBorrowHandle: DescriptorBorrowHandle, @unchecked Sendable {
  private let thread: pthread_t
  private let context: HEVThreadContext
  private let boundary: any HEVSOCKSBoundary
  private let runtime: any HEVNativeRuntime
  private let logger: any TunnelLogger
  private let metrics: any TunnelMetrics
  private let lock = NSLock()
  private var stopRequested = false
  private var joinTask: Task<Void, Never>?
  private var boundaryStopTask: Task<Void, Never>?
  private var statisticsBeforeStop: HEVTrafficStatistics?
  private var leaseReleased = false

  init(
    thread: pthread_t,
    context: HEVThreadContext,
    boundary: any HEVSOCKSBoundary,
    runtime: any HEVNativeRuntime,
    logger: any TunnelLogger,
    metrics: any TunnelMetrics
  ) {
    self.thread = thread
    self.context = context
    self.boundary = boundary
    self.runtime = runtime
    self.logger = logger
    self.metrics = metrics
  }

  func requestStop() async {
    let shouldStop = lock.withLock {
      guard !stopRequested else { return false }
      stopRequested = true
      return true
    }
    guard shouldStop else { return }
    // Upstream quit waits forever if its event socket has already been torn down.
    // Joining first makes a completed main call observable here, so never issue
    // quit after return. A spontaneous return concurrent with this check remains
    // an upstream-inherent race that cannot be removed without patching HEV.
    if context.returnCode == nil {
      let statistics = runtime.statistics()
      lock.withLock {
        statisticsBeforeStop = statistics
      }
      runtime.requestStop()
    }
    await stopBoundaryOnce()
    await metrics.incrementCounter(named: "hev_stop_request_total", by: 1)
  }

  func waitForReturn() async {
    let task = lock.withLock { () -> Task<Void, Never> in
      if let joinTask {
        return joinTask
      }
      let thread = self.thread
      let created = Task(priority: .high) {
        await joinHEVThread(thread)
      }
      joinTask = created
      return created
    }
    await task.value
    await stopBoundaryOnce()

    let shouldRelease = lock.withLock {
      guard !leaseReleased else { return false }
      leaseReleased = true
      return true
    }
    guard shouldRelease else { return }
    let statistics = lock.withLock { statisticsBeforeStop } ?? runtime.statistics()
    HEVProcessLease.shared.release()
    await metrics.setGauge(
      named: "hev_transmitted_packets", to: clampedInt64(statistics.transmittedPackets))
    await metrics.setGauge(
      named: "hev_transmitted_bytes", to: clampedInt64(statistics.transmittedBytes))
    await metrics.setGauge(
      named: "hev_received_packets", to: clampedInt64(statistics.receivedPackets))
    await metrics.setGauge(
      named: "hev_received_bytes", to: clampedInt64(statistics.receivedBytes))
    await metrics.incrementCounter(named: "hev_main_return_total", by: 1)
    if context.returnCode != 0 {
      await metrics.incrementCounter(named: "hev_main_failure_total", by: 1)
    }
    logger.log(
      level: context.returnCode == 0 ? .info : .error,
      message: "hev.stopped",
      fields: [
        "return_code": .init(String(context.returnCode ?? -1), privacy: .public)
      ]
    )
  }

  private func stopBoundaryOnce() async {
    let task = lock.withLock { () -> Task<Void, Never> in
      if let boundaryStopTask {
        return boundaryStopTask
      }
      let boundary = self.boundary
      let created = Task {
        await boundary.stop()
      }
      boundaryStopTask = created
      return created
    }
    await task.value
  }

  private func clampedInt64(_ value: UInt64) -> Int64 {
    value > UInt64(Int64.max) ? Int64.max : Int64(value)
  }
}

private func joinHEVThread(_ thread: pthread_t) async {
  let sendableThread = SendablePthread(value: thread)
  await withCheckedContinuation { continuation in
    DispatchQueue.global(qos: .userInitiated).async {
      _ = pthread_join(sendableThread.value, nil)
      continuation.resume()
    }
  }
}

private struct SendablePthread: @unchecked Sendable {
  let value: pthread_t
}

private final class HEVProcessLease: @unchecked Sendable {
  static let shared = HEVProcessLease()
  private let lock = NSLock()
  private var isLeased = false

  func acquire() -> Bool {
    lock.withLock {
      guard !isLeased else { return false }
      isLeased = true
      return true
    }
  }

  func release() {
    lock.withLock {
      precondition(isLeased)
      isLeased = false
    }
  }
}
