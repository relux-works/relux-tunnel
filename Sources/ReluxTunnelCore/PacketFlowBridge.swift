import Darwin
import Foundation

public actor PacketFlowBridge: PacketBridge {
  private let socketIO: any PacketBridgeSocketIO
  private let readinessFactory: any PacketBridgeReadinessFactory
  private let descriptorConsumer: any DescriptorBorrowConsumer
  private let clock: any TunnelClock
  private let scheduler: any PacketBridgeScheduler
  private let logger: any TunnelLogger
  private let metricsSink: any TunnelMetrics
  private let runIDSource: any PacketBridgeRunIDSource
  private let lifecycleBarrier: any PacketBridgeLifecycleBarrier

  private var state: PacketFlowBridgeLifecycleState = .idle
  private var activeRun: PacketBridgeRun?
  private var latestMetrics: PacketBridgeRunMetrics?

  public init(
    socketIO: any PacketBridgeSocketIO = DarwinPacketBridgeSocketIO(),
    readinessFactory: any PacketBridgeReadinessFactory =
      DispatchPacketBridgeReadinessFactory(),
    descriptorConsumer: any DescriptorBorrowConsumer,
    clock: any TunnelClock,
    scheduler: any PacketBridgeScheduler = TaskPacketBridgeScheduler(),
    logger: any TunnelLogger,
    metrics: any TunnelMetrics,
    runIDSource: any PacketBridgeRunIDSource = UUIDPacketBridgeRunIDSource(),
    lifecycleBarrier: any PacketBridgeLifecycleBarrier =
      NoOpPacketBridgeLifecycleBarrier()
  ) {
    self.socketIO = socketIO
    self.readinessFactory = readinessFactory
    self.descriptorConsumer = descriptorConsumer
    self.clock = clock
    self.scheduler = scheduler
    self.logger = logger
    metricsSink = metrics
    self.runIDSource = runIDSource
    self.lifecycleBarrier = lifecycleBarrier
  }

  public func start(
    packetFlow: any PacketFlow,
    configuration: PacketBridgeConfiguration
  ) async throws -> PacketFlowBridgeRunHandle {
    guard activeRun == nil else {
      throw PacketFlowBridgeError.alreadyActive
    }

    let runID = runIDSource.nextRunID()
    let runMetrics = PacketBridgeRunMetrics(
      runID: runID,
      clock: clock,
      diagnosticsWindow: configuration.diagnosticsWindow,
      sink: metricsSink,
      logger: logger
    )
    latestMetrics = runMetrics
    state = .starting(runID: runID)
    await runMetrics.increment("packet_bridge_start_total")

    let maximumDatagramBytes: Int
    do {
      maximumDatagramBytes = try Self.validate(configuration)
      try await lifecycleBarrier.reach(.configurationValidated)
    } catch is CancellationError {
      await runMetrics.increment("packet_bridge_cancellation_total")
      logger.log(
        level: .info,
        message: "packet_bridge.cancelled",
        fields: ["run_id": .init(runID, privacy: .public)]
      )
      logger.log(
        level: .info,
        message: "packet_bridge.stopped",
        fields: ["run_id": .init(runID, privacy: .public)]
      )
      state = .stopped(lastRunID: runID)
      throw CancellationError()
    } catch {
      let bridgeError = Self.bridgeError(from: error)
      await finishRejectedStart(runID: runID, metrics: runMetrics, error: bridgeError)
      throw bridgeError
    }

    let run = PacketBridgeRun(
      runID: runID,
      packetFlow: packetFlow,
      configuration: configuration,
      maximumDatagramBytes: maximumDatagramBytes,
      socketIO: socketIO,
      readinessFactory: readinessFactory,
      descriptorConsumer: descriptorConsumer,
      clock: clock,
      scheduler: scheduler,
      logger: logger,
      metrics: runMetrics,
      lifecycleBarrier: lifecycleBarrier
    ) { [weak self] error in
      await self?.runBeganFailing(runID: runID, error: error)
    } onFinish: { [weak self] result, reachedRunning in
      await self?.runEnded(runID: runID, result: result, reachedRunning: reachedRunning)
    }
    activeRun = run

    do {
      try await withTaskCancellationHandler {
        try await run.installInfrastructure()
      } onCancel: {
        run.requestCancellation()
      }
    } catch {
      let bridgeError = Self.bridgeError(from: error)
      if !run.isTerminated {
        await run.finishStartupFailure(bridgeError)
      }
      if Task.isCancelled || run.wasCancelled {
        throw CancellationError()
      }
      throw bridgeError
    }

    state = .running(runID: runID)
    await run.activate()
    if Task.isCancelled {
      run.requestCancellation()
      await run.waitForTerminationIgnoringError()
      throw CancellationError()
    }
    return run.handle
  }

  public func stop() async {
    guard let run = activeRun else {
      return
    }
    switch state {
    case .starting, .running:
      state = .stopping(runID: run.runID)
    case .failing, .stopping:
      break
    case .idle, .stopped, .failed:
      return
    }
    run.requestStop()
    await run.waitForTerminationIgnoringError()
  }

  public func metrics() async -> TunnelMetricsSnapshot {
    guard let latestMetrics else {
      return TunnelMetricsSnapshot(
        schemaVersion: PacketBridgeMetricSchema.version,
        counters: PacketBridgeMetricSchema.counters.mapValues { _ in 0 },
        gauges: PacketBridgeMetricSchema.gauges.mapValues { _ in 0 }
      )
    }
    return await latestMetrics.snapshot()
  }

  public func lifecycleState() -> PacketFlowBridgeLifecycleState {
    state
  }

  private func finishRejectedStart(
    runID: String,
    metrics: PacketBridgeRunMetrics,
    error: PacketFlowBridgeError
  ) async {
    state = .failing(runID: runID, error: error)
    await metrics.recordFatalReason(error)
    await metrics.increment("packet_bridge_startup_failure_total")
    await metrics.increment("packet_bridge_terminal_failure_total")
    logFatal(runID: runID, error: error, fields: [:])
    state = .failed(runID: runID, error: error)
  }

  private func runBeganFailing(runID: String, error: PacketFlowBridgeError) {
    guard activeRun?.runID == runID else { return }
    switch state {
    case .starting, .running:
      state = .failing(runID: runID, error: error)
    case .failing, .stopping, .idle, .stopped, .failed:
      break
    }
  }

  private func runEnded(
    runID: String,
    result: Result<Void, PacketFlowBridgeError>,
    reachedRunning: Bool
  ) {
    guard activeRun?.runID == runID else {
      return
    }
    activeRun = nil
    switch result {
    case .success:
      state = .stopped(lastRunID: runID)
    case .failure(let error):
      if reachedRunning {
        state = .failed(runID: runID, error: error)
      } else {
        state = .failed(runID: runID, error: error)
      }
    }
  }

  private func logFatal(
    runID: String,
    error: PacketFlowBridgeError,
    fields: [String: TunnelLogField]
  ) {
    var fields = fields
    fields["run_id"] = .init(runID, privacy: .public)
    fields["error_category"] = .init(error.category, privacy: .public)
    logger.log(level: .error, message: "packet_bridge.fatal", fields: fields)
  }

  private static func validate(_ configuration: PacketBridgeConfiguration) throws -> Int {
    guard configuration.mtu > 0 else {
      throw PacketFlowBridgeError.invalidConfiguration(field: "mtu")
    }
    guard configuration.sendBufferBytes > 0,
      configuration.sendBufferBytes <= Int(Int32.max)
    else {
      throw PacketFlowBridgeError.invalidConfiguration(field: "send_buffer_bytes")
    }
    guard configuration.receiveBufferBytes > 0,
      configuration.receiveBufferBytes <= Int(Int32.max)
    else {
      throw PacketFlowBridgeError.invalidConfiguration(field: "receive_buffer_bytes")
    }
    guard configuration.maximumWorkCount > 0 else {
      throw PacketFlowBridgeError.invalidConfiguration(field: "maximum_work_count")
    }
    guard configuration.workTimeBudget > .zero else {
      throw PacketFlowBridgeError.invalidConfiguration(field: "work_time_budget")
    }
    guard configuration.diagnosticsWindow > .zero else {
      throw PacketFlowBridgeError.invalidConfiguration(field: "diagnostics_window")
    }
    let (maximum, overflow) = configuration.mtu.addingReportingOverflow(4)
    guard !overflow, maximum > 4 else {
      throw PacketFlowBridgeError.invalidConfiguration(field: "maximum_datagram_bytes")
    }
    return maximum
  }

  fileprivate static func bridgeError(from error: any Error) -> PacketFlowBridgeError {
    if let error = error as? PacketFlowBridgeError {
      return error
    }
    if error is CancellationError {
      return .startInterrupted
    }
    return .socketError(operation: .socketPair, errno: 0)
  }
}

private enum PacketBridgeTerminationRequest: Sendable {
  case stop
  case cancellation
  case fatal(PacketFlowBridgeError)
}

private final class PacketBridgeRunControl: @unchecked Sendable {
  private let lock = NSLock()
  private var request: PacketBridgeTerminationRequest?
  private var waiter: CheckedContinuation<PacketBridgeTerminationRequest, Never>?

  var currentRequest: PacketBridgeTerminationRequest? {
    lock.withLock { request }
  }

  @discardableResult
  func request(_ newRequest: PacketBridgeTerminationRequest) -> Bool {
    lock.lock()
    guard request == nil else {
      lock.unlock()
      return false
    }
    request = newRequest
    let waiter = waiter
    self.waiter = nil
    lock.unlock()
    waiter?.resume(returning: newRequest)
    return true
  }

  func wait() async -> PacketBridgeTerminationRequest {
    await withCheckedContinuation { continuation in
      lock.lock()
      if let request {
        lock.unlock()
        continuation.resume(returning: request)
      } else {
        waiter = continuation
        lock.unlock()
      }
    }
  }
}

private final class PacketBridgeStartGate: @unchecked Sendable {
  private let lock = NSLock()
  private var isOpen = false
  private var isCancelled = false
  private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]

  func wait() async throws {
    let identifier = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        lock.lock()
        if isOpen {
          lock.unlock()
          continuation.resume()
        } else if isCancelled {
          lock.unlock()
          continuation.resume(throwing: CancellationError())
        } else {
          waiters[identifier] = continuation
          lock.unlock()
        }
      }
    } onCancel: {
      cancelWait(identifier)
    }
  }

  func open() {
    finish(open: true)
  }

  func cancel() {
    finish(open: false)
  }

  private func finish(open: Bool) {
    lock.lock()
    guard !isOpen, !isCancelled else {
      lock.unlock()
      return
    }
    isOpen = open
    isCancelled = !open
    let waiters = waiters.values
    self.waiters.removeAll()
    lock.unlock()
    for waiter in waiters {
      if open {
        waiter.resume()
      } else {
        waiter.resume(throwing: CancellationError())
      }
    }
  }

  private func cancelWait(_ identifier: UUID) {
    lock.lock()
    let waiter = waiters.removeValue(forKey: identifier)
    lock.unlock()
    waiter?.resume(throwing: CancellationError())
  }
}

private final class PacketBridgeOwnedDescriptor: @unchecked Sendable {
  let rawValue: Int32
  private let socketIO: any PacketBridgeSocketIO
  private let lock = NSLock()
  private var isOpen = true

  init(rawValue: Int32, socketIO: any PacketBridgeSocketIO) {
    self.rawValue = rawValue
    self.socketIO = socketIO
  }

  func close() -> Bool {
    lock.lock()
    guard isOpen else {
      lock.unlock()
      return true
    }
    isOpen = false
    lock.unlock()
    do {
      try socketIO.closeDescriptor(rawValue)
      return true
    } catch {
      return false
    }
  }
}

private struct PacketBridgeBufferReadbacks: Sendable {
  let aSend: Int32
  let aReceive: Int32
  let bSend: Int32
  let bReceive: Int32
}

private final class PacketBridgeRun: @unchecked Sendable {
  let runID: String
  let handle: PacketFlowBridgeRunHandle

  private let packetFlow: any PacketFlow
  private let configuration: PacketBridgeConfiguration
  private let maximumDatagramBytes: Int
  private let socketIO: any PacketBridgeSocketIO
  private let readinessFactory: any PacketBridgeReadinessFactory
  private let descriptorConsumer: any DescriptorBorrowConsumer
  private let clock: any TunnelClock
  private let scheduler: any PacketBridgeScheduler
  private let logger: any TunnelLogger
  private let metrics: PacketBridgeRunMetrics
  private let lifecycleBarrier: any PacketBridgeLifecycleBarrier
  private let completion = PacketBridgeRunCompletion()
  private let control = PacketBridgeRunControl()
  private let gate = PacketBridgeStartGate()
  private let stateLock = NSLock()
  private let onFatal: @Sendable (PacketFlowBridgeError) async -> Void
  private let onFinish: @Sendable (Result<Void, PacketFlowBridgeError>, Bool) async -> Void

  private var bridgeDescriptor: PacketBridgeOwnedDescriptor?
  private var hevDescriptor: PacketBridgeOwnedDescriptor?
  private var readiness: (any PacketBridgeReadinessSource)?
  private var borrowHandle: (any DescriptorBorrowHandle)?
  private var readbacks: PacketBridgeBufferReadbacks?
  private var forwardTask: Task<Void, Never>?
  private var reverseTask: Task<Void, Never>?
  private var hevTask: Task<Void, Never>?
  private var supervisorTask: Task<Void, Never>?
  private var reachedRunning = false
  private var terminated = false

  init(
    runID: String,
    packetFlow: any PacketFlow,
    configuration: PacketBridgeConfiguration,
    maximumDatagramBytes: Int,
    socketIO: any PacketBridgeSocketIO,
    readinessFactory: any PacketBridgeReadinessFactory,
    descriptorConsumer: any DescriptorBorrowConsumer,
    clock: any TunnelClock,
    scheduler: any PacketBridgeScheduler,
    logger: any TunnelLogger,
    metrics: PacketBridgeRunMetrics,
    lifecycleBarrier: any PacketBridgeLifecycleBarrier,
    onFatal: @escaping @Sendable (PacketFlowBridgeError) async -> Void,
    onFinish: @escaping @Sendable (Result<Void, PacketFlowBridgeError>, Bool) async -> Void
  ) {
    self.runID = runID
    self.packetFlow = packetFlow
    self.configuration = configuration
    self.maximumDatagramBytes = maximumDatagramBytes
    self.socketIO = socketIO
    self.readinessFactory = readinessFactory
    self.descriptorConsumer = descriptorConsumer
    self.clock = clock
    self.scheduler = scheduler
    self.logger = logger
    self.metrics = metrics
    self.lifecycleBarrier = lifecycleBarrier
    self.onFatal = onFatal
    self.onFinish = onFinish
    handle = PacketFlowBridgeRunHandle(completion: completion)
  }

  var isTerminated: Bool {
    stateLock.withLock { terminated }
  }

  var wasCancelled: Bool {
    if case .cancellation = control.currentRequest {
      return true
    }
    return false
  }

  func requestStop() {
    control.request(.stop)
  }

  func requestCancellation() {
    control.request(.cancellation)
  }

  func installInfrastructure() async throws {
    do {
      try throwIfStartupTerminationRequested()
      let pair = try socketIO.makeDatagramSocketPair()
      bridgeDescriptor = PacketBridgeOwnedDescriptor(
        rawValue: pair.bridgeDescriptor,
        socketIO: socketIO
      )
      hevDescriptor = PacketBridgeOwnedDescriptor(
        rawValue: pair.hevDescriptor,
        socketIO: socketIO
      )
      try await lifecycleBarrier.reach(.socketPairCreated)
      try throwIfStartupTerminationRequested()

      try await configureDescriptors()
      try await lifecycleBarrier.reach(.descriptorsConfigured)
      try throwIfStartupTerminationRequested()

      guard let bridgeDescriptor else {
        throw PacketFlowBridgeError.socketError(operation: .socketPair, errno: 0)
      }
      readiness = try readinessFactory.makeReadinessSource(
        descriptor: bridgeDescriptor.rawValue
      )
      try await lifecycleBarrier.reach(.readinessInstalled)
      try throwIfStartupTerminationRequested()

      guard let hevDescriptor else {
        throw PacketFlowBridgeError.socketError(operation: .socketPair, errno: 0)
      }
      do {
        borrowHandle = try await descriptorConsumer.beginBorrowing(
          hevDescriptor.rawValue
        )
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        throw PacketFlowBridgeError.descriptorBorrowFailure
      }
      try await lifecycleBarrier.reach(.borrowAccepted)
      try throwIfStartupTerminationRequested()

      installTasks()
      try await lifecycleBarrier.reach(.supervisorInstalled)
      try throwIfStartupTerminationRequested()
    } catch {
      if supervisorTask != nil {
        if error is CancellationError {
          requestCancellation()
        } else if let error = error as? PacketFlowBridgeError {
          await signalFatal(error)
        }
        await waitForTerminationIgnoringError()
      } else {
        let request: PacketBridgeTerminationRequest
        if error is CancellationError {
          requestCancellation()
          request = .cancellation
        } else if let existing = control.currentRequest {
          request = existing
        } else {
          let bridgeError = PacketFlowBridge.bridgeError(from: error)
          await metrics.recordFatalReason(bridgeError)
          await onFatal(bridgeError)
          request = .fatal(bridgeError)
        }
        await cleanupBeforeSupervision(request)
      }
      throw error
    }
  }

  func activate() async {
    stateLock.withLock {
      reachedRunning = true
    }
    await logStarted()
    try? await lifecycleBarrier.reach(.running)
    if control.currentRequest == nil {
      gate.open()
    } else {
      gate.cancel()
    }
  }

  func finishStartupFailure(_ error: PacketFlowBridgeError) async {
    guard !isTerminated else {
      return
    }
    await metrics.recordFatalReason(error)
    if supervisorTask != nil {
      if control.request(.fatal(error)) {
        await onFatal(error)
      }
      await waitForTerminationIgnoringError()
    } else {
      await cleanupBeforeSupervision(.fatal(error))
    }
  }

  func waitForTerminationIgnoringError() async {
    _ = try? await handle.waitForTermination()
    if let supervisorTask {
      await supervisorTask.value
    }
  }

  private func configureDescriptors() async throws {
    guard let bridgeDescriptor, let hevDescriptor else {
      throw PacketFlowBridgeError.socketError(operation: .socketPair, errno: 0)
    }
    for descriptor in [bridgeDescriptor.rawValue, hevDescriptor.rawValue] {
      let descriptorFlags = try socketIO.descriptorFlags(for: descriptor)
      try socketIO.setDescriptorFlags(descriptorFlags | FD_CLOEXEC, for: descriptor)
      let statusFlags = try socketIO.statusFlags(for: descriptor)
      try socketIO.setStatusFlags(statusFlags | O_NONBLOCK, for: descriptor)
      try socketIO.setSocketBuffer(
        .send,
        bytes: Int32(configuration.sendBufferBytes),
        for: descriptor
      )
      try socketIO.setSocketBuffer(
        .receive,
        bytes: Int32(configuration.receiveBufferBytes),
        for: descriptor
      )
    }
    let values = PacketBridgeBufferReadbacks(
      aSend: try socketIO.socketBuffer(.send, for: bridgeDescriptor.rawValue),
      aReceive: try socketIO.socketBuffer(.receive, for: bridgeDescriptor.rawValue),
      bSend: try socketIO.socketBuffer(.send, for: hevDescriptor.rawValue),
      bReceive: try socketIO.socketBuffer(.receive, for: hevDescriptor.rawValue)
    )
    readbacks = values
    await publishConfigurationMetrics(values)
  }

  private func publishConfigurationMetrics(_ values: PacketBridgeBufferReadbacks) async {
    await metrics.setGauge(
      "packet_bridge_socket_a_send_buffer_requested_bytes",
      to: Int64(configuration.sendBufferBytes)
    )
    await metrics.setGauge(
      "packet_bridge_socket_a_send_buffer_effective_bytes",
      to: Int64(values.aSend)
    )
    await metrics.setGauge(
      "packet_bridge_socket_a_receive_buffer_requested_bytes",
      to: Int64(configuration.receiveBufferBytes)
    )
    await metrics.setGauge(
      "packet_bridge_socket_a_receive_buffer_effective_bytes",
      to: Int64(values.aReceive)
    )
    await metrics.setGauge(
      "packet_bridge_socket_b_send_buffer_requested_bytes",
      to: Int64(configuration.sendBufferBytes)
    )
    await metrics.setGauge(
      "packet_bridge_socket_b_send_buffer_effective_bytes",
      to: Int64(values.bSend)
    )
    await metrics.setGauge(
      "packet_bridge_socket_b_receive_buffer_requested_bytes",
      to: Int64(configuration.receiveBufferBytes)
    )
    await metrics.setGauge(
      "packet_bridge_socket_b_receive_buffer_effective_bytes",
      to: Int64(values.bReceive)
    )
    await metrics.setGauge("packet_bridge_configured_mtu_bytes", to: Int64(configuration.mtu))
    await metrics.setGauge(
      "packet_bridge_configured_max_datagram_bytes",
      to: Int64(maximumDatagramBytes)
    )
  }

  private func installTasks() {
    forwardTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await gate.wait()
        await forwardPump()
      } catch {}
    }
    reverseTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await gate.wait()
        await reversePump()
      } catch {}
    }
    hevTask = Task { [weak self] in
      guard let self, let borrowHandle else { return }
      await borrowHandle.waitForReturn()
      if control.currentRequest == nil {
        await signalFatal(.peerEOF(operation: .descriptorBorrow))
      }
    }
    supervisorTask = Task { [weak self] in
      guard let self else { return }
      let request = await control.wait()
      await supervisedCleanup(request)
    }
  }

  private func forwardPump() async {
    guard let descriptor = bridgeDescriptor?.rawValue else { return }
    var frame = [UInt8](repeating: 0, count: maximumDatagramBytes)

    while !Task.isCancelled, control.currentRequest == nil {
      let batch: PacketReadBatch
      do {
        batch = try await packetFlow.readPackets()
      } catch is CancellationError {
        return
      } catch let error as PacketFlowError {
        if control.currentRequest != nil {
          return
        }
        if case .packetProtocolCardinalityMismatch = error {
          for increment in error.metricIncrements {
            await metrics.recordDrop(increment.counterName, by: increment.amount)
          }
          continue
        }
        await signalFatal(.packetFlowFailure(operation: .packetFlowRead))
        return
      } catch {
        if control.currentRequest == nil {
          await signalFatal(.packetFlowFailure(operation: .packetFlowRead))
        }
        return
      }

      var inspected = 0
      var sliceStart = clock.now()
      for result in batch.results {
        if Task.isCancelled || control.currentRequest != nil {
          return
        }
        if inspected >= configuration.maximumWorkCount {
          await metrics.increment("packet_bridge_forward_budget_count_yield_total")
          await scheduler.yield()
          inspected = 0
          sliceStart = clock.now()
        } else if inspected > 0,
          sliceStart.duration(to: clock.now()) >= configuration.workTimeBudget
        {
          await metrics.increment("packet_bridge_forward_budget_time_yield_total")
          await scheduler.yield()
          inspected = 0
          sliceStart = clock.now()
        }
        inspected += 1
        await metrics.increment("packet_bridge_forward_packets_received_total")

        guard case .packet(let packet) = result, Self.isValid(packet) else {
          await metrics.recordDrop("packet_bridge_forward_drop_malformed_total")
          continue
        }
        await metrics.increment(
          "packet_bridge_forward_payload_bytes_received_total",
          by: UInt64(packet.payload.count)
        )
        let (datagramBytes, sizeOverflow) = packet.payload.count.addingReportingOverflow(4)
        guard !sizeOverflow else {
          await signalFatal(
            .messageTooLarge(
              direction: .forward,
              datagramBytes: .max,
              configuredMaximumBytes: maximumDatagramBytes
            )
          )
          return
        }
        await metrics.maxGauge(
          "packet_bridge_forward_datagram_max_bytes",
          value: Int64(datagramBytes)
        )
        guard datagramBytes <= maximumDatagramBytes else {
          await signalFatal(
            .messageTooLarge(
              direction: .forward,
              datagramBytes: datagramBytes,
              configuredMaximumBytes: maximumDatagramBytes
            )
          )
          return
        }

        let family = UInt32(packet.addressFamily == .ipv4 ? AF_INET : AF_INET6)
        frame[0] = UInt8(truncatingIfNeeded: family >> 24)
        frame[1] = UInt8(truncatingIfNeeded: family >> 16)
        frame[2] = UInt8(truncatingIfNeeded: family >> 8)
        frame[3] = UInt8(truncatingIfNeeded: family)
        frame.replaceSubrange(4..<datagramBytes, with: packet.payload)

        do {
          let sent = try frame.withUnsafeBytes { bytes in
            try socketIO.sendDatagram(
              on: descriptor,
              bytes: UnsafeRawBufferPointer(rebasing: bytes[..<datagramBytes])
            )
          }
          guard sent == datagramBytes else {
            await signalFatal(
              .shortDatagramSend(expectedBytes: datagramBytes, actualBytes: sent)
            )
            return
          }
          await metrics.increment("packet_bridge_forward_datagrams_sent_total")
          await metrics.increment(
            "packet_bridge_forward_datagram_bytes_sent_total",
            by: UInt64(datagramBytes)
          )
        } catch let error as PacketFlowBridgeError {
          guard case .socketError(_, let code) = error else {
            await signalFatal(error)
            return
          }
          if Self.isWouldBlock(code) {
            await metrics.recordDrop("packet_bridge_forward_drop_would_block_total")
          } else if code == ENOBUFS {
            await metrics.recordDrop("packet_bridge_forward_drop_no_buffer_total")
          } else if code == EMSGSIZE {
            await signalFatal(
              .messageTooLarge(
                direction: .forward,
                datagramBytes: datagramBytes,
                configuredMaximumBytes: maximumDatagramBytes
              )
            )
            return
          } else {
            await signalFatal(error)
            return
          }
        } catch {
          await signalFatal(.socketError(operation: .send, errno: 0))
          return
        }
      }
    }
  }

  private func reversePump() async {
    guard let descriptor = bridgeDescriptor?.rawValue, let readiness else { return }
    var buffer = [UInt8](repeating: 0, count: maximumDatagramBytes)

    while !Task.isCancelled, control.currentRequest == nil {
      do {
        let event = try await readiness.waitForEvent()
        if case .peerClosed = event {
          await signalFatal(.peerEOF(operation: .readiness))
          return
        }
      } catch is CancellationError {
        return
      } catch {
        if control.currentRequest == nil {
          await signalFatal(.socketError(operation: .readiness, errno: 0))
        }
        return
      }

      let sliceStart = clock.now()
      var inspected = 0
      var packets: [TunnelPacket] = []
      var yieldForCount = false
      var yieldForTime = false
      var endDrain = false

      while !endDrain, !Task.isCancelled, control.currentRequest == nil {
        if inspected > 0 {
          if inspected >= configuration.maximumWorkCount {
            yieldForCount = true
            break
          }
          if sliceStart.duration(to: clock.now()) >= configuration.workTimeBudget {
            yieldForTime = true
            break
          }
        }

        do {
          let received = try buffer.withUnsafeMutableBytes { bytes in
            try socketIO.receiveDatagram(on: descriptor, into: bytes)
          }
          inspected += 1
          await metrics.increment("packet_bridge_reverse_datagrams_received_total")
          await metrics.increment(
            "packet_bridge_reverse_datagram_bytes_received_total",
            by: UInt64(max(0, received.fullDatagramBytes))
          )
          await metrics.maxGauge(
            "packet_bridge_reverse_datagram_max_bytes",
            value: Int64(max(0, received.fullDatagramBytes))
          )
          if received.wasTruncated || received.fullDatagramBytes > maximumDatagramBytes {
            await signalFatal(
              .messageTooLarge(
                direction: .reverse,
                datagramBytes: received.fullDatagramBytes,
                configuredMaximumBytes: maximumDatagramBytes
              )
            )
            return
          }
          guard received.copiedBytes >= 4 else {
            await metrics.recordDrop("packet_bridge_reverse_drop_malformed_total")
            continue
          }
          let family =
            (UInt32(buffer[0]) << 24)
            | (UInt32(buffer[1]) << 16)
            | (UInt32(buffer[2]) << 8)
            | UInt32(buffer[3])
          let payloadCount = received.copiedBytes - 4
          guard payloadCount > 0 else {
            await metrics.recordDrop("packet_bridge_reverse_drop_malformed_total")
            continue
          }
          let addressFamily: PacketAddressFamily
          let expectedVersion: UInt8
          if family == UInt32(AF_INET) {
            addressFamily = .ipv4
            expectedVersion = 4
          } else if family == UInt32(AF_INET6) {
            addressFamily = .ipv6
            expectedVersion = 6
          } else {
            await metrics.recordDrop("packet_bridge_reverse_drop_malformed_total")
            continue
          }
          guard buffer[4] >> 4 == expectedVersion else {
            await metrics.recordDrop("packet_bridge_reverse_drop_malformed_total")
            continue
          }
          packets.append(
            TunnelPacket(
              payload: Data(buffer[4..<received.copiedBytes]),
              addressFamily: addressFamily
            )
          )
        } catch let error as PacketFlowBridgeError {
          guard case .socketError(_, let code) = error else {
            await signalFatal(error)
            return
          }
          if Self.isWouldBlock(code) {
            await metrics.increment("packet_bridge_reverse_drain_would_block_total")
            endDrain = true
          } else if code == ENOBUFS {
            await metrics.recordDrop("packet_bridge_reverse_receive_no_buffer_total")
            endDrain = true
          } else if code == EMSGSIZE {
            await signalFatal(
              .messageTooLarge(
                direction: .reverse,
                datagramBytes: maximumDatagramBytes,
                configuredMaximumBytes: maximumDatagramBytes
              )
            )
            return
          } else {
            await signalFatal(error)
            return
          }
        } catch {
          await signalFatal(.socketError(operation: .receive, errno: 0))
          return
        }
      }

      guard control.currentRequest == nil else { return }
      if !packets.isEmpty {
        do {
          try await packetFlow.writePackets(packets)
          await metrics.increment(
            "packet_bridge_reverse_packets_written_total",
            by: UInt64(packets.count)
          )
          await metrics.increment(
            "packet_bridge_reverse_payload_bytes_written_total",
            by: packets.reduce(into: UInt64.zero) { total, packet in
              total = total.saturatingAdding(UInt64(packet.payload.count))
            }
          )
          await metrics.increment("packet_bridge_reverse_batches_written_total")
        } catch {
          await metrics.increment(
            "packet_bridge_reverse_drop_write_rejected_packets_total",
            by: UInt64(packets.count)
          )
          await signalFatal(.packetFlowFailure(operation: .packetFlowWrite))
          return
        }
      }
      if yieldForCount {
        await metrics.increment("packet_bridge_reverse_budget_count_yield_total")
        await scheduler.yield()
      } else if yieldForTime {
        await metrics.increment("packet_bridge_reverse_budget_time_yield_total")
        await scheduler.yield()
      }
    }
  }

  private func signalFatal(_ error: PacketFlowBridgeError) async {
    await metrics.recordFatalReason(error)
    if control.request(.fatal(error)) {
      await onFatal(error)
    }
  }

  private func supervisedCleanup(_ request: PacketBridgeTerminationRequest) async {
    gate.cancel()
    await packetFlow.shutdown()
    try? await lifecycleBarrier.reach(.packetReadsStopped)
    await readiness?.cancel()
    try? await lifecycleBarrier.reach(.readinessCancelled)
    forwardTask?.cancel()
    reverseTask?.cancel()
    await forwardTask?.value
    await reverseTask?.value
    try? await lifecycleBarrier.reach(.pumpsJoined)
    await borrowHandle?.requestStop()
    try? await lifecycleBarrier.reach(.borrowStopRequested)
    await hevTask?.value
    try? await lifecycleBarrier.reach(.borrowReturned)
    await finishCleanup(request)
  }

  private func cleanupBeforeSupervision(_ request: PacketBridgeTerminationRequest) async {
    await packetFlow.shutdown()
    try? await lifecycleBarrier.reach(.packetReadsStopped)
    await readiness?.cancel()
    try? await lifecycleBarrier.reach(.readinessCancelled)
    await borrowHandle?.requestStop()
    try? await lifecycleBarrier.reach(.borrowStopRequested)
    await borrowHandle?.waitForReturn()
    try? await lifecycleBarrier.reach(.borrowReturned)
    await finishCleanup(request)
  }

  private func finishCleanup(_ request: PacketBridgeTerminationRequest) async {
    if hevDescriptor?.close() == false {
      await recordCloseFailure(ownedToken: "hev")
    }
    try? await lifecycleBarrier.reach(.hevDescriptorClosed)
    if bridgeDescriptor?.close() == false {
      await recordCloseFailure(ownedToken: "bridge")
    }
    try? await lifecycleBarrier.reach(.bridgeDescriptorClosed)
    await metrics.flushDropSummary()

    let result: Result<Void, PacketFlowBridgeError>
    switch request {
    case .stop:
      await metrics.increment("packet_bridge_stop_total")
      result = .success(())
    case .cancellation:
      await metrics.increment("packet_bridge_cancellation_total")
      logger.log(
        level: .info,
        message: "packet_bridge.cancelled",
        fields: ["run_id": .init(runID, privacy: .public)]
      )
      result = .success(())
    case .fatal(let error):
      let didReachRunning = stateLock.withLock { reachedRunning }
      if !didReachRunning {
        await metrics.increment("packet_bridge_startup_failure_total")
      }
      await metrics.increment("packet_bridge_terminal_failure_total")
      logFatal(error)
      result = .failure(error)
    }
    logger.log(
      level: .info,
      message: "packet_bridge.stopped",
      fields: ["run_id": .init(runID, privacy: .public)]
    )
    let didReachRunning = stateLock.withLock { () -> Bool in
      terminated = true
      return reachedRunning
    }
    await onFinish(result, didReachRunning)
    completion.finish(result)
  }

  private func recordCloseFailure(ownedToken: String) async {
    await metrics.increment("packet_bridge_cleanup_close_error_total")
    logger.log(
      level: .warning,
      message: "packet_bridge.close_failed",
      fields: [
        "run_id": .init(runID, privacy: .public),
        "operation": .init("close_\(ownedToken)_endpoint", privacy: .public),
      ]
    )
  }

  private func logStarted() async {
    guard let values = readbacks else { return }
    let fields = bufferFields(values)
    logger.log(level: .info, message: "packet_bridge.started", fields: fields)
    if values.aSend < configuration.sendBufferBytes
      || values.aReceive < configuration.receiveBufferBytes
      || values.bSend < configuration.sendBufferBytes
      || values.bReceive < configuration.receiveBufferBytes
    {
      logger.log(
        level: .notice,
        message: "packet_bridge.socket_buffer_clamped",
        fields: fields
      )
    }
  }

  private func logFatal(_ error: PacketFlowBridgeError) {
    var fields =
      readbacks.map(bufferFields) ?? [
        "run_id": .init(runID, privacy: .public)
      ]
    fields["error_category"] = .init(error.category, privacy: .public)
    for (name, field) in error.logFields {
      fields[name] = field
    }
    logger.log(level: .error, message: "packet_bridge.fatal", fields: fields)
  }

  private func bufferFields(_ values: PacketBridgeBufferReadbacks) -> [String: TunnelLogField] {
    [
      "run_id": .init(runID, privacy: .public),
      "configured_mtu_bytes": .init(String(configuration.mtu), privacy: .public),
      "configured_max_datagram_bytes": .init(String(maximumDatagramBytes), privacy: .public),
      "socket_a_send_buffer_requested_bytes": .init(
        String(configuration.sendBufferBytes), privacy: .public),
      "socket_a_send_buffer_effective_bytes": .init(String(values.aSend), privacy: .public),
      "socket_a_receive_buffer_requested_bytes": .init(
        String(configuration.receiveBufferBytes), privacy: .public),
      "socket_a_receive_buffer_effective_bytes": .init(
        String(values.aReceive), privacy: .public),
      "socket_b_send_buffer_requested_bytes": .init(
        String(configuration.sendBufferBytes), privacy: .public),
      "socket_b_send_buffer_effective_bytes": .init(String(values.bSend), privacy: .public),
      "socket_b_receive_buffer_requested_bytes": .init(
        String(configuration.receiveBufferBytes), privacy: .public),
      "socket_b_receive_buffer_effective_bytes": .init(
        String(values.bReceive), privacy: .public),
    ]
  }

  private func throwIfStartupTerminationRequested() throws {
    guard let request = control.currentRequest else { return }
    switch request {
    case .stop:
      throw PacketFlowBridgeError.startInterrupted
    case .cancellation:
      throw CancellationError()
    case .fatal(let error):
      throw error
    }
  }

  private static func isValid(_ packet: TunnelPacket) -> Bool {
    guard let first = packet.payload.first else { return false }
    switch packet.addressFamily {
    case .ipv4:
      return first >> 4 == 4
    case .ipv6:
      return first >> 4 == 6
    }
  }

  private static func isWouldBlock(_ code: Int32) -> Bool {
    code == EAGAIN
  }
}

private actor PacketBridgeRunMetrics {
  private let runID: String
  private let clock: any TunnelClock
  private let diagnosticsWindow: Duration
  private let sink: any TunnelMetrics
  private let logger: any TunnelLogger
  private var counters = PacketBridgeMetricSchema.counters.mapValues { _ in UInt64.zero }
  private var gauges = PacketBridgeMetricSchema.gauges.mapValues { _ in Int64.zero }
  private var unsummarizedDrops: [String: UInt64] = [:]
  private var lastDropSummary: ContinuousClock.Instant
  private var saturationWasLogged = false

  init(
    runID: String,
    clock: any TunnelClock,
    diagnosticsWindow: Duration,
    sink: any TunnelMetrics,
    logger: any TunnelLogger
  ) {
    self.runID = runID
    self.clock = clock
    self.diagnosticsWindow = diagnosticsWindow
    self.sink = sink
    self.logger = logger
    lastDropSummary = clock.now()
  }

  func increment(_ name: String, by amount: UInt64 = 1) async {
    guard amount > 0, let current = counters[name] else { return }
    let updated = current.saturatingAdding(amount)
    counters[name] = updated
    let applied = updated - current
    if applied > 0 {
      await sink.incrementCounter(named: name, by: applied)
    }
    if applied < amount {
      logSaturationOnce(metric: name)
    }
  }

  func setGauge(_ name: String, to value: Int64) async {
    guard gauges[name] != nil else { return }
    gauges[name] = value
    await sink.setGauge(named: name, to: value)
  }

  func maxGauge(_ name: String, value: Int64) async {
    guard let current = gauges[name], value > current else { return }
    gauges[name] = value
    await sink.setGauge(named: name, to: value)
  }

  func recordDrop(_ name: String, by amount: UInt64 = 1) async {
    await increment(name, by: amount)
    unsummarizedDrops[name] = (unsummarizedDrops[name] ?? 0).saturatingAdding(amount)
    if lastDropSummary.duration(to: clock.now()) >= diagnosticsWindow {
      emitDropSummary()
    }
  }

  func recordFatalReason(_ error: PacketFlowBridgeError) async {
    switch error {
    case .messageTooLarge:
      await increment("packet_bridge_fatal_message_too_large_total")
    case .peerEOF:
      await increment("packet_bridge_fatal_peer_eof_total")
    case .packetFlowFailure:
      await increment("packet_bridge_fatal_packet_flow_error_total")
    case .socketError, .shortDatagramSend, .readinessFailure:
      await increment("packet_bridge_fatal_socket_error_total")
    case .alreadyActive, .invalidConfiguration, .startInterrupted,
      .descriptorBorrowFailure:
      break
    }
  }

  func flushDropSummary() {
    emitDropSummary()
  }

  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(
      schemaVersion: PacketBridgeMetricSchema.version,
      counters: counters,
      gauges: gauges
    )
  }

  private func emitDropSummary() {
    guard !unsummarizedDrops.isEmpty else { return }
    var fields: [String: TunnelLogField] = [
      "run_id": .init(runID, privacy: .public)
    ]
    for (name, value) in unsummarizedDrops {
      fields[name] = .init(String(value), privacy: .public)
    }
    logger.log(level: .notice, message: "packet_bridge.drop_summary", fields: fields)
    unsummarizedDrops.removeAll()
    lastDropSummary = clock.now()
  }

  private func logSaturationOnce(metric: String) {
    guard !saturationWasLogged else { return }
    saturationWasLogged = true
    logger.log(
      level: .warning,
      message: "packet_bridge.metric_saturated",
      fields: [
        "run_id": .init(runID, privacy: .public),
        "metric": .init(metric, privacy: .public),
      ]
    )
  }
}

extension PacketFlowBridgeError {
  fileprivate var category: String {
    switch self {
    case .alreadyActive: "already_active"
    case .invalidConfiguration: "invalid_configuration"
    case .startInterrupted: "start_interrupted"
    case .socketError, .shortDatagramSend: "socket_error"
    case .readinessFailure: "readiness_failure"
    case .descriptorBorrowFailure: "descriptor_borrow_failure"
    case .messageTooLarge: "message_too_large"
    case .peerEOF: "peer_eof"
    case .packetFlowFailure: "packet_flow_error"
    }
  }

  fileprivate var logFields: [String: TunnelLogField] {
    switch self {
    case .socketError(let operation, let code):
      [
        "operation": .init(operation.rawValue, privacy: .public),
        "errno": .init(String(code), privacy: .public),
        "errno_symbol": .init(symbolicErrno(code), privacy: .public),
      ]
    case .messageTooLarge(let direction, let bytes, let maximum):
      [
        "direction": .init(direction.rawValue, privacy: .public),
        "operation": .init(
          direction == .forward
            ? PacketBridgeOperation.send.rawValue : PacketBridgeOperation.receive.rawValue,
          privacy: .public
        ),
        "errno": .init(String(EMSGSIZE), privacy: .public),
        "errno_symbol": .init("EMSGSIZE", privacy: .public),
        "datagram_bytes": .init(String(bytes), privacy: .public),
        "configured_max_datagram_bytes": .init(String(maximum), privacy: .public),
      ]
    case .peerEOF(let operation), .packetFlowFailure(let operation):
      ["operation": .init(operation.rawValue, privacy: .public)]
    case .shortDatagramSend(let expected, let actual):
      [
        "operation": .init(PacketBridgeOperation.send.rawValue, privacy: .public),
        "expected_datagram_bytes": .init(String(expected), privacy: .public),
        "actual_datagram_bytes": .init(String(actual), privacy: .public),
      ]
    case .alreadyActive, .invalidConfiguration, .startInterrupted,
      .readinessFailure, .descriptorBorrowFailure:
      [:]
    }
  }
}

private func symbolicErrno(_ code: Int32) -> String {
  switch code {
  case EAGAIN: "EAGAIN"
  case ENOBUFS: "ENOBUFS"
  case EMSGSIZE: "EMSGSIZE"
  case EIO: "EIO"
  case EINTR: "EINTR"
  case EBADF: "EBADF"
  default: "UNKNOWN"
  }
}

extension UInt64 {
  fileprivate func saturatingAdding(_ other: UInt64) -> UInt64 {
    let (result, overflow) = addingReportingOverflow(other)
    return overflow ? .max : result
  }
}
