import Darwin
import Dispatch
import Foundation
import ReluxTunnelCore

struct HEVUDPAssociationHandle: Hashable, Sendable {
  fileprivate let value: UInt64
}

public enum HEVUDPRelaySubmissionResult: Equatable, Sendable {
  case accepted
  case queueSaturated
  case sessionUnavailable
}

/// The outer relay pump implements this as a non-waiting bounded admission.
/// The adapter never owns an additional retry queue.
public protocol HEVUDPRelaySink: Sendable {
  func submit(
    _ envelope: RelayEnvelope,
    generation: UInt64
  ) -> HEVUDPRelaySubmissionResult
}

public enum HEVUDPRelayDeliveryOutcome: Equatable, Sendable {
  case delivered
  case outputQueueSaturated
  case oversized
  case invalidDatagram
  case staleGeneration
  case unknownAssociation
  case unavailable(ClientUDPAssociationState)
}

public struct HEVUDPDatagramAdapterMetrics: Equatable, Sendable {
  public fileprivate(set) var authenticatedConnections: UInt64 = 0
  public fileprivate(set) var connectionAdmissionRejected: UInt64 = 0
  public fileprivate(set) var socksRequestsAccepted: UInt64 = 0
  public fileprivate(set) var socksRequestsRejected: UInt64 = 0
  public fileprivate(set) var inputRecords: UInt64 = 0
  public fileprivate(set) var inputBytes: UInt64 = 0
  public fileprivate(set) var datagramsSubmitted: UInt64 = 0
  public fileprivate(set) var associationRejected: UInt64 = 0
  public fileprivate(set) var malformedInbound: UInt64 = 0
  public fileprivate(set) var hevOversizedInbound: UInt64 = 0
  public fileprivate(set) var localPolicyInboundDropped: UInt64 = 0
  public fileprivate(set) var inputQueueSaturatedDropped: UInt64 = 0
  public fileprivate(set) var relayQueueSaturatedDropped: UInt64 = 0
  public fileprivate(set) var relayUnavailable: UInt64 = 0
  public fileprivate(set) var repliesDelivered: UInt64 = 0
  public fileprivate(set) var repliesDropped: UInt64 = 0
  public fileprivate(set) var oversizedReplyDropped: UInt64 = 0
  public fileprivate(set) var outputQueueSaturatedDropped: UInt64 = 0
  public fileprivate(set) var remoteErrors: UInt64 = 0
  public fileprivate(set) var remoteDatagramTooLargeDropped: UInt64 = 0
  public fileprivate(set) var remoteQueueSaturatedDropped: UInt64 = 0
  public fileprivate(set) var remoteCloses: UInt64 = 0
  public fileprivate(set) var localCloses: UInt64 = 0
  public fileprivate(set) var admissionTimeouts: UInt64 = 0
  public fileprivate(set) var cancellations: UInt64 = 0
  public fileprivate(set) var lateCallbacks: UInt64 = 0
  public fileprivate(set) var peakConnections: UInt32 = 0
  public fileprivate(set) var peakInboundQueuedBytes: UInt32 = 0
  public fileprivate(set) var peakOutboundQueuedBytes: UInt32 = 0

  public init() {}
}

public struct HEVUDPDatagramAdapterSnapshot: Equatable, Sendable {
  public let activeConnections: Int
  public let inboundQueuedBytes: UInt32
  public let outboundQueuedBytes: UInt32
  public let metrics: HEVUDPDatagramAdapterMetrics
  public let registry: ClientUDPAssociationRegistrySnapshot
}

public enum HEVUDPDatagramAdapterConfigurationError: Error, Equatable, Sendable {
  case invalidIOTimeout
  case invalidAdmissionTimeout
  case invalidLimits
}

public struct HEVUDPDatagramAdapterConfiguration: Equatable, Sendable {
  public let limits: RelayEffectiveLimits
  public let ioTimeoutMilliseconds: UInt32
  public let admissionTimeoutMilliseconds: UInt32

  public init(
    limits: RelayEffectiveLimits,
    ioTimeoutMilliseconds: UInt32,
    admissionTimeoutMilliseconds: UInt32
  ) throws {
    guard
      ioTimeoutMilliseconds > 0,
      ioTimeoutMilliseconds <= limits.idleTimeoutMilliseconds
    else {
      throw HEVUDPDatagramAdapterConfigurationError.invalidIOTimeout
    }
    guard
      admissionTimeoutMilliseconds > 0,
      admissionTimeoutMilliseconds <= limits.idleTimeoutMilliseconds
    else {
      throw HEVUDPDatagramAdapterConfigurationError.invalidAdmissionTimeout
    }
    guard
      (RelayProtocolV1
        .maxUDPPayloadFloor...RelayProtocolV1
        .maxUDPPayloadClientHardCeiling).contains(limits.maxUDPPayload),
      (RelayProtocolV1
        .perAssociationQueuedBytesFloor...RelayProtocolV1
        .perAssociationQueuedBytesClientHardCeiling).contains(
          limits.perAssociationQueuedBytes),
      (RelayProtocolV1
        .aggregateQueuedBytesFloor...RelayProtocolV1
        .aggregateQueuedBytesClientHardCeiling).contains(limits.aggregateQueuedBytes),
      limits.perAssociationQueuedBytes <= limits.aggregateQueuedBytes
    else {
      throw HEVUDPDatagramAdapterConfigurationError.invalidLimits
    }
    self.limits = limits
    self.ioTimeoutMilliseconds = ioTimeoutMilliseconds
    self.admissionTimeoutMilliseconds = admissionTimeoutMilliseconds
  }
}

/// Private HEV UDP-in-TCP to relay-v1 association adapter.
///
/// `HEVSOCKSChannel` has no public initializer, so only the authenticated
/// process-local boundary can supply admission capability. The adapter stores
/// no endpoint or payload history and emits no destination-bearing logs.
public final class HEVUDPDatagramAdapter: HEVSOCKSConnectionAdapter, @unchecked Sendable {
  private let generation: UInt64
  private let configuration: HEVUDPDatagramAdapterConfiguration
  private let relay: any HEVUDPRelaySink
  private let callbacks: HEVUDPAdapterCallbackRouter
  private let registry: ClientUDPAssociationRegistry<HEVUDPAssociationHandle>
  private let lock = NSLock()
  private var connections: [HEVUDPAssociationHandle: HEVUDPAssociationConnection] = [:]
  private var connectionReservations = 0
  private var nextHandle: UInt64 = 1
  private var inboundQueuedBytes: UInt32 = 0
  private var outboundQueuedBytes: UInt32 = 0
  private var metrics = HEVUDPDatagramAdapterMetrics()
  private var pendingTeardowns = 0
  private var teardownWaiters: [CheckedContinuation<Void, Never>] = []
  private var stopped = false

  public init(
    generation: UInt64,
    configuration: HEVUDPDatagramAdapterConfiguration,
    relay: any HEVUDPRelaySink,
    clock: any TunnelClock = ContinuousTunnelClock()
  ) throws {
    self.generation = generation
    self.configuration = configuration
    self.relay = relay
    let callbacks = HEVUDPAdapterCallbackRouter()
    self.callbacks = callbacks
    registry = ClientUDPAssociationRegistry(
      generation: generation,
      configuration: try ClientUDPAssociationRegistryConfiguration(
        limits: configuration.limits
      ),
      clock: clock,
      callbacks: ClientUDPAssociationCallbacks(
        closeHEV: { handle, reason in
          callbacks.closeHEV(handle, reason: reason)
        },
        cleanupRelay: { cleanup in
          callbacks.cleanupRelay(cleanup)
        }
      )
    )
    callbacks.adapter = self
  }

  deinit {
    let ownedConnections = lock.withLock { () -> [HEVUDPAssociationConnection] in
      stopped = true
      return Array(connections.values)
    }
    for connection in ownedConnections {
      connection.close(notifyRegistry: false)
    }
  }

  public func acceptAuthenticatedConnection(_ channel: HEVSOCKSChannel) {
    let reservation = lock.withLock { () -> HEVUDPAssociationHandle? in
      guard
        !stopped,
        connections.count + connectionReservations
          < Int(configuration.limits.maxAssociations),
        nextHandle != UInt64.max
      else {
        metrics.connectionAdmissionRejected = incremented(
          metrics.connectionAdmissionRejected)
        return nil
      }
      let handle = HEVUDPAssociationHandle(value: nextHandle)
      nextHandle += 1
      connectionReservations += 1
      metrics.authenticatedConnections = incremented(metrics.authenticatedConnections)
      return handle
    }
    guard let reservation else {
      channel.close()
      return
    }

    let connection = HEVUDPAssociationConnection(
      handle: reservation,
      channel: channel,
      maximumPayloadLength: configuration.limits.maxUDPPayload,
      perAssociationQueuedBytes: configuration.limits.perAssociationQueuedBytes,
      ioTimeoutMilliseconds: configuration.ioTimeoutMilliseconds,
      admissionTimeoutMilliseconds: configuration.admissionTimeoutMilliseconds,
      owner: self
    )
    let inserted = lock.withLock { () -> Bool in
      connectionReservations -= 1
      guard !stopped else { return false }
      connections[reservation] = connection
      metrics.peakConnections = max(metrics.peakConnections, UInt32(connections.count))
      return true
    }
    guard inserted else {
      connection.close(notifyRegistry: false)
      return
    }
    connection.start()
  }

  public func receiveRelayDatagram(
    associationID: UInt32,
    generation callbackGeneration: UInt64,
    datagram: RelayDatagram
  ) async -> HEVUDPRelayDeliveryOutcome {
    let resolution = await registry.resolveRemoteDatagram(
      associationID: associationID,
      generation: callbackGeneration
    )
    switch resolution {
    case .resolved(let handle, let key):
      let connection = lock.withLock { connections[handle] }
      guard let connection, connection.matches(key) else {
        recordMetric { $0.lateCallbacks = incremented($0.lateCallbacks) }
        return .unknownAssociation
      }
      do {
        var codec = try RelayDatagramCodec(
          maximumPayloadLength: configuration.limits.maxUDPPayload
        )
        let record = try codec.encode(datagram)
        guard connection.enqueueOutbound(record) else {
          recordMetric {
            $0.outputQueueSaturatedDropped = incremented(
              $0.outputQueueSaturatedDropped)
            $0.repliesDropped = incremented($0.repliesDropped)
          }
          return .outputQueueSaturated
        }
        recordMetric { $0.repliesDelivered = incremented($0.repliesDelivered) }
        return .delivered
      } catch let failure as RelayDatagramFailure {
        recordMetric {
          $0.repliesDropped = incremented($0.repliesDropped)
          if failure.code == .messageLengthExceedsProtocolMaximum
            || failure.code == .messageLengthExceedsLocalMaximum
          {
            $0.oversizedReplyDropped = incremented($0.oversizedReplyDropped)
          }
        }
        if failure.code == .messageLengthExceedsLocalMaximum {
          return .oversized
        }
        _ = await registry.closeLocally(key)
        return failure.code == .messageLengthExceedsProtocolMaximum
          ? .oversized : .invalidDatagram
      } catch {
        recordMetric { $0.repliesDropped = incremented($0.repliesDropped) }
        _ = await registry.closeLocally(key)
        return .invalidDatagram
      }
    case .staleGeneration:
      recordMetric { $0.lateCallbacks = incremented($0.lateCallbacks) }
      return .staleGeneration
    case .unknownAssociation:
      recordMetric { $0.lateCallbacks = incremented($0.lateCallbacks) }
      return .unknownAssociation
    case .unavailable(let state):
      recordMetric { $0.lateCallbacks = incremented($0.lateCallbacks) }
      return .unavailable(state)
    }
  }

  @discardableResult
  public func receiveRelayError(
    associationID: UInt32,
    generation callbackGeneration: UInt64,
    error: RelayRemoteAssociationError
  ) async -> ClientUDPAssociationEventResult {
    if error == .generated(.queueSaturated)
      || error == .generated(.datagramTooLarge)
    {
      let result = await observeNonterminalRelayError(
        associationID: associationID,
        generation: callbackGeneration
      )
      recordRemoteEvent(result) {
        $0.remoteErrors = incremented($0.remoteErrors)
        if error == .generated(.queueSaturated) {
          $0.remoteQueueSaturatedDropped = incremented(
            $0.remoteQueueSaturatedDropped)
        } else {
          $0.remoteDatagramTooLargeDropped = incremented(
            $0.remoteDatagramTooLargeDropped)
        }
      }
      return result
    }

    let result = await registry.receiveRemoteError(
      associationID: associationID,
      generation: callbackGeneration
    )
    recordRemoteEvent(result) {
      $0.remoteErrors = incremented($0.remoteErrors)
    }
    return result
  }

  @discardableResult
  public func receiveRelayClose(
    associationID: UInt32,
    generation callbackGeneration: UInt64
  ) async -> ClientUDPAssociationEventResult {
    let result = await registry.receiveRemoteClose(
      associationID: associationID,
      generation: callbackGeneration
    )
    recordRemoteEvent(result) {
      $0.remoteCloses = incremented($0.remoteCloses)
    }
    return result
  }

  public func sessionLost(generation callbackGeneration: UInt64) async {
    guard callbackGeneration == generation else {
      recordMetric { $0.lateCallbacks = incremented($0.lateCallbacks) }
      return
    }
    await registry.sessionLost(generation: callbackGeneration)
    closeUnadmittedConnections()
  }

  public func cancel(generation callbackGeneration: UInt64) async {
    guard callbackGeneration == generation else {
      recordMetric { $0.lateCallbacks = incremented($0.lateCallbacks) }
      return
    }
    recordMetric { $0.cancellations = incremented($0.cancellations) }
    await registry.cancel(generation: callbackGeneration)
    closeUnadmittedConnections()
  }

  public func stopProvider() async {
    lock.withLock { stopped = true }
    await registry.stopProvider()
    closeUnadmittedConnections()
  }

  public func snapshot() async -> HEVUDPDatagramAdapterSnapshot {
    let local = lock.withLock {
      (
        connections.count,
        inboundQueuedBytes,
        outboundQueuedBytes,
        metrics
      )
    }
    return await HEVUDPDatagramAdapterSnapshot(
      activeConnections: local.0,
      inboundQueuedBytes: local.1,
      outboundQueuedBytes: local.2,
      metrics: local.3,
      registry: registry.snapshot()
    )
  }

  func waitForPendingTeardowns() async {
    await withCheckedContinuation { continuation in
      let resumeImmediately = lock.withLock { () -> Bool in
        guard pendingTeardowns > 0 else { return true }
        teardownWaiters.append(continuation)
        return false
      }
      if resumeImmediately { continuation.resume() }
    }
  }

  fileprivate func requestAccepted() {
    recordMetric { $0.socksRequestsAccepted = incremented($0.socksRequestsAccepted) }
  }

  fileprivate func requestRejected() {
    recordMetric { $0.socksRequestsRejected = incremented($0.socksRequestsRejected) }
  }

  fileprivate func recordInputRecord(byteCount: Int) {
    recordMetric {
      $0.inputRecords = incremented($0.inputRecords)
      $0.inputBytes = adding(UInt64(byteCount), to: $0.inputBytes)
    }
  }

  fileprivate func recordMalformedInbound() {
    recordMetric { $0.malformedInbound = incremented($0.malformedInbound) }
  }

  fileprivate func recordOversizedInbound(localPolicy: Bool) {
    recordMetric {
      if localPolicy {
        $0.localPolicyInboundDropped = incremented($0.localPolicyInboundDropped)
      } else {
        $0.hevOversizedInbound = incremented($0.hevOversizedInbound)
      }
    }
  }

  fileprivate func recordAdmissionTimeout() {
    recordMetric { $0.admissionTimeouts = incremented($0.admissionTimeouts) }
  }

  fileprivate func reserveInbound(_ charge: UInt32) -> Bool {
    lock.withLock {
      let (next, overflow) = inboundQueuedBytes.addingReportingOverflow(charge)
      guard !overflow, next <= configuration.limits.aggregateQueuedBytes else {
        return false
      }
      inboundQueuedBytes = next
      metrics.peakInboundQueuedBytes = max(metrics.peakInboundQueuedBytes, next)
      return true
    }
  }

  fileprivate func releaseInbound(_ charge: UInt32) {
    lock.withLock {
      inboundQueuedBytes = charge > inboundQueuedBytes ? 0 : inboundQueuedBytes - charge
    }
  }

  fileprivate func recordInputQueueSaturation() {
    recordMetric {
      $0.inputQueueSaturatedDropped = incremented($0.inputQueueSaturatedDropped)
    }
  }

  fileprivate func reserveOutbound(_ charge: UInt32) -> Bool {
    lock.withLock {
      let (next, overflow) = outboundQueuedBytes.addingReportingOverflow(charge)
      guard !overflow, next <= configuration.limits.aggregateQueuedBytes else {
        return false
      }
      outboundQueuedBytes = next
      metrics.peakOutboundQueuedBytes = max(metrics.peakOutboundQueuedBytes, next)
      return true
    }
  }

  fileprivate func releaseOutbound(_ charge: UInt32) {
    lock.withLock {
      outboundQueuedBytes = charge > outboundQueuedBytes ? 0 : outboundQueuedBytes - charge
    }
  }

  fileprivate func processInbound(
    _ record: Data,
    from connection: HEVUDPAssociationConnection
  ) async {
    do {
      var codec = try RelayDatagramCodec(
        maximumPayloadLength: configuration.limits.maxUDPPayload
      )
      _ = try codec.decode(record)
    } catch {
      recordMalformedInbound()
      connection.close(notifyRegistry: true)
      return
    }

    let admission = await registry.admit(connection.handle, generation: generation)
    let key: ClientUDPAssociationKey
    switch admission {
    case .success(let admitted):
      key = admitted
    case .failure:
      recordMetric { $0.associationRejected = incremented($0.associationRejected) }
      connection.close(notifyRegistry: false)
      return
    }
    connection.setKey(key)
    guard connection.matches(key) else {
      _ = await registry.closeLocally(key)
      return
    }
    guard case .applied = await registry.recordActivity(for: key) else { return }

    let result = relay.submit(
      RelayEnvelope(
        type: .udpDatagram,
        associationID: key.associationID,
        payload: record
      ),
      generation: generation
    )
    switch result {
    case .accepted:
      recordMetric { $0.datagramsSubmitted = incremented($0.datagramsSubmitted) }
    case .queueSaturated:
      recordMetric {
        $0.relayQueueSaturatedDropped = incremented($0.relayQueueSaturatedDropped)
      }
    case .sessionUnavailable:
      recordMetric { $0.relayUnavailable = incremented($0.relayUnavailable) }
      _ = await registry.closeLocally(key)
    }
  }

  fileprivate func connectionClosed(
    _ connection: HEVUDPAssociationConnection,
    notifyRegistry: Bool,
    inboundCharge: UInt32,
    outboundCharge: UInt32
  ) {
    lock.withLock {
      if connections[connection.handle] === connection {
        connections.removeValue(forKey: connection.handle)
      }
      inboundQueuedBytes =
        inboundCharge > inboundQueuedBytes
        ? 0 : inboundQueuedBytes - inboundCharge
      outboundQueuedBytes =
        outboundCharge > outboundQueuedBytes
        ? 0 : outboundQueuedBytes - outboundCharge
      if notifyRegistry {
        metrics.localCloses = incremented(metrics.localCloses)
      }
    }
    guard notifyRegistry, let key = connection.key else {
      finishTeardown()
      return
    }
    Task { [registry, self] in
      _ = await registry.closeLocally(key)
      finishTeardown()
    }
  }

  fileprivate func beginTeardown() {
    lock.withLock { pendingTeardowns += 1 }
  }

  fileprivate func closeHEV(
    _ handle: HEVUDPAssociationHandle,
    reason: ClientUDPAssociationCleanupReason
  ) {
    let connection = lock.withLock { connections[handle] }
    connection?.requestClose(notifyRegistry: false)
    _ = reason
  }

  fileprivate func cleanupRelay(_ cleanup: ClientUDPAssociationRelayCleanup) {
    guard cleanup.shouldSendClose else { return }
    _ = relay.submit(
      RelayEnvelope(
        type: .closeAssociation,
        associationID: cleanup.key.associationID
      ),
      generation: cleanup.key.generation
    )
  }

  private func recordMetric(
    _ update: (inout HEVUDPDatagramAdapterMetrics) -> Void
  ) {
    lock.withLock { update(&metrics) }
  }

  private func finishTeardown() {
    let waiters = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
      precondition(pendingTeardowns > 0)
      pendingTeardowns -= 1
      guard pendingTeardowns == 0 else { return [] }
      defer { teardownWaiters.removeAll(keepingCapacity: true) }
      return teardownWaiters
    }
    for waiter in waiters { waiter.resume() }
  }

  private func recordRemoteEvent(
    _ result: ClientUDPAssociationEventResult,
    applied update: (inout HEVUDPDatagramAdapterMetrics) -> Void
  ) {
    recordMetric {
      switch result {
      case .applied:
        update(&$0)
      case .ignoredStaleGeneration, .ignoredUnknownAssociation, .ignoredState:
        $0.lateCallbacks = incremented($0.lateCallbacks)
      }
    }
  }

  private func observeNonterminalRelayError(
    associationID: UInt32,
    generation callbackGeneration: UInt64
  ) async -> ClientUDPAssociationEventResult {
    let resolution = await registry.observeActiveAssociation(
      associationID: associationID,
      generation: callbackGeneration
    )
    switch resolution {
    case .resolved(let handle, let key):
      let connection = lock.withLock { connections[handle] }
      guard let connection, connection.matches(key) else {
        return .ignoredUnknownAssociation
      }
      return .applied(key: key, from: .active, to: .active)
    case .staleGeneration:
      return .ignoredStaleGeneration
    case .unknownAssociation:
      return .ignoredUnknownAssociation
    case .unavailable(let state):
      return .ignoredState(state)
    }
  }

  private func closeUnadmittedConnections() {
    let candidates = lock.withLock { Array(connections.values) }
    let unadmitted = candidates.filter { $0.key == nil }
    for connection in unadmitted {
      connection.close(notifyRegistry: false)
    }
  }
}

private final class HEVUDPAdapterCallbackRouter: @unchecked Sendable {
  weak var adapter: HEVUDPDatagramAdapter?

  func closeHEV(
    _ handle: HEVUDPAssociationHandle,
    reason: ClientUDPAssociationCleanupReason
  ) {
    adapter?.closeHEV(handle, reason: reason)
  }

  func cleanupRelay(_ cleanup: ClientUDPAssociationRelayCleanup) {
    adapter?.cleanupRelay(cleanup)
  }
}

private final class HEVUDPAssociationConnection: @unchecked Sendable {
  fileprivate let handle: HEVUDPAssociationHandle
  private let channel: HEVSOCKSChannel
  private let perAssociationQueuedBytes: UInt32
  private let ioTimeoutMilliseconds: UInt32
  private let admissionTimeoutMilliseconds: UInt32
  private weak var owner: HEVUDPDatagramAdapter?
  private let lock = NSLock()
  private let outputQueue: DispatchQueue
  private var decoder: HEVUDPStreamDecoder
  private var storedKey: ClientUDPAssociationKey?
  private var inbound: [(Data, UInt32)] = []
  private var outbound: [(Data, UInt32)] = []
  private var inboundBytes: UInt32 = 0
  private var outboundBytes: UInt32 = 0
  private var signalContinuation: AsyncStream<Void>.Continuation?
  private var worker: Task<Void, Never>?
  private var writerScheduled = false
  private var closed = false

  init(
    handle: HEVUDPAssociationHandle,
    channel: HEVSOCKSChannel,
    maximumPayloadLength: UInt16,
    perAssociationQueuedBytes: UInt32,
    ioTimeoutMilliseconds: UInt32,
    admissionTimeoutMilliseconds: UInt32,
    owner: HEVUDPDatagramAdapter
  ) {
    self.handle = handle
    self.channel = channel
    self.perAssociationQueuedBytes = perAssociationQueuedBytes
    self.ioTimeoutMilliseconds = ioTimeoutMilliseconds
    self.admissionTimeoutMilliseconds = admissionTimeoutMilliseconds
    self.owner = owner
    decoder = HEVUDPStreamDecoder(maximumPayloadLength: maximumPayloadLength)
    outputQueue = DispatchQueue(label: "works.relux.hev-udp.output.\(handle.value)")
  }

  deinit {
    close(notifyRegistry: false)
  }

  var key: ClientUDPAssociationKey? {
    lock.withLock { storedKey }
  }

  func matches(_ key: ClientUDPAssociationKey) -> Bool {
    lock.withLock { !closed && storedKey == key }
  }

  func setKey(_ key: ClientUDPAssociationKey) {
    lock.withLock {
      if !closed { storedKey = key }
    }
  }

  func start() {
    let pair = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    lock.withLock {
      signalContinuation = pair.continuation
      worker = Task { [weak self] in
        for await _ in pair.stream {
          guard let self else { return }
          while let record = self.popInbound() {
            await self.owner?.processInbound(record, from: self)
          }
        }
      }
    }
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.readLoop()
    }
  }

  func enqueueOutbound(_ record: Data) -> Bool {
    let charge = queueCharge(for: record.count)
    guard charge <= perAssociationQueuedBytes, owner?.reserveOutbound(charge) == true else {
      return false
    }
    let result = lock.withLock { () -> (accepted: Bool, schedule: Bool) in
      guard !closed else { return (false, false) }
      let (next, overflow) = outboundBytes.addingReportingOverflow(charge)
      guard !overflow, next <= perAssociationQueuedBytes else {
        return (false, false)
      }
      outbound.append((record, charge))
      outboundBytes = next
      guard !writerScheduled else { return (true, false) }
      writerScheduled = true
      return (true, true)
    }
    guard result.accepted else {
      owner?.releaseOutbound(charge)
      return false
    }
    if result.schedule {
      outputQueue.async { [weak self] in self?.drainOutbound() }
    }
    return true
  }

  func close(notifyRegistry: Bool) {
    let state = lock.withLock { () -> (UInt32, UInt32, Bool) in
      guard !closed else { return (0, 0, false) }
      closed = true
      let input = inboundBytes
      let output = outboundBytes
      inbound.removeAll(keepingCapacity: false)
      outbound.removeAll(keepingCapacity: false)
      inboundBytes = 0
      outboundBytes = 0
      signalContinuation?.finish()
      signalContinuation = nil
      worker?.cancel()
      worker = nil
      return (input, output, true)
    }
    guard state.2 else { return }
    let owner = owner
    owner?.beginTeardown()
    channel.close()
    owner?.connectionClosed(
      self,
      notifyRegistry: notifyRegistry,
      inboundCharge: state.0,
      outboundCharge: state.1
    )
  }

  func requestClose(notifyRegistry: Bool) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.close(notifyRegistry: notifyRegistry)
    }
  }

  private func readLoop() {
    do {
      try configureTimeouts()
      let started = DispatchTime.now().uptimeNanoseconds
      var bytes = [UInt8](repeating: 0, count: 4_096)
      while !lock.withLock({ closed }) {
        let count = try channel.withBorrowedDescriptor { descriptor in
          Darwin.recv(descriptor, &bytes, bytes.count, 0)
        }
        if count > 0 {
          let events = decoder.consume(Data(bytes.prefix(count)))
          for event in events {
            switch event {
            case .requestAccepted:
              try sendSOCKSReply(code: 0)
              owner?.requestAccepted()
            case .requestRejected(let code):
              try? sendSOCKSReply(code: code)
              owner?.requestRejected()
              close(notifyRegistry: true)
              return
            case .record(let record):
              owner?.recordInputRecord(byteCount: record.count)
              enqueueInbound(record)
            case .discardedOversized(let localPolicy):
              owner?.recordOversizedInbound(localPolicy: localPolicy)
            case .fatal:
              owner?.recordMalformedInbound()
              close(notifyRegistry: true)
              return
            }
          }
        } else if count == 0 {
          close(notifyRegistry: true)
          return
        } else if errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK {
          close(notifyRegistry: true)
          return
        }

        if key == nil {
          let elapsed = DispatchTime.now().uptimeNanoseconds - started
          if elapsed >= UInt64(admissionTimeoutMilliseconds) * 1_000_000 {
            owner?.recordAdmissionTimeout()
            close(notifyRegistry: false)
            return
          }
        }
      }
    } catch {
      close(notifyRegistry: true)
    }
  }

  private func enqueueInbound(_ record: Data) {
    let charge = queueCharge(for: record.count)
    guard charge <= perAssociationQueuedBytes, owner?.reserveInbound(charge) == true else {
      owner?.recordInputQueueSaturation()
      return
    }
    let continuation = lock.withLock { () -> AsyncStream<Void>.Continuation? in
      guard !closed else { return nil }
      let (next, overflow) = inboundBytes.addingReportingOverflow(charge)
      guard !overflow, next <= perAssociationQueuedBytes else { return nil }
      inbound.append((record, charge))
      inboundBytes = next
      return signalContinuation
    }
    guard let continuation else {
      owner?.releaseInbound(charge)
      owner?.recordInputQueueSaturation()
      return
    }
    continuation.yield(())
  }

  private func popInbound() -> Data? {
    let item = lock.withLock { () -> (Data, UInt32)? in
      guard !inbound.isEmpty else { return nil }
      let item = inbound.removeFirst()
      inboundBytes -= item.1
      return item
    }
    guard let item else { return nil }
    owner?.releaseInbound(item.1)
    return item.0
  }

  private func drainOutbound() {
    while true {
      let item = lock.withLock { () -> (Data, UInt32)? in
        guard !closed else {
          writerScheduled = false
          return nil
        }
        guard !outbound.isEmpty else {
          writerScheduled = false
          return nil
        }
        let item = outbound.removeFirst()
        outboundBytes -= item.1
        return item
      }
      guard let item else { return }
      owner?.releaseOutbound(item.1)
      do {
        try channel.withBorrowedDescriptor { descriptor in
          try sendAll(item.0, descriptor: descriptor)
        }
      } catch {
        close(notifyRegistry: true)
        return
      }
    }
  }

  private func configureTimeouts() throws {
    try channel.withBorrowedDescriptor { descriptor in
      var timeout = timeval(
        tv_sec: Int(ioTimeoutMilliseconds / 1_000),
        tv_usec: Int32(ioTimeoutMilliseconds % 1_000) * 1_000
      )
      for option in [SO_RCVTIMEO, SO_SNDTIMEO] {
        guard
          setsockopt(
            descriptor,
            SOL_SOCKET,
            option,
            &timeout,
            socklen_t(MemoryLayout.size(ofValue: timeout))
          ) == 0
        else {
          throw HEVIntegrationError.socksBoundaryFailed(code: errno)
        }
      }
    }
  }

  private func sendSOCKSReply(code: UInt8) throws {
    try channel.withBorrowedDescriptor { descriptor in
      try sendAll(Data([5, code, 0, 1, 0, 0, 0, 0, 0, 0]), descriptor: descriptor)
    }
  }
}

private enum HEVUDPStreamEvent {
  case requestAccepted
  case requestRejected(UInt8)
  case record(Data)
  case discardedOversized(localPolicy: Bool)
  case fatal
}

private struct HEVUDPStreamDecoder {
  private let maximumPayloadLength: UInt16
  private var bytes = Data()
  private var requestAccepted = false
  private var discardRemaining = 0
  private var discardLocalPolicy = false
  private var terminal = false

  init(maximumPayloadLength: UInt16) {
    self.maximumPayloadLength = maximumPayloadLength
  }

  mutating func consume(_ input: Data) -> [HEVUDPStreamEvent] {
    guard !terminal else { return [] }
    bytes.append(input)
    var events: [HEVUDPStreamEvent] = []
    while true {
      if discardRemaining > 0 {
        let discarded = min(discardRemaining, bytes.count)
        bytes.removeFirst(discarded)
        discardRemaining -= discarded
        if discardRemaining == 0 {
          events.append(.discardedOversized(localPolicy: discardLocalPolicy))
          continue
        }
        break
      }
      if !requestAccepted {
        guard let event = consumeRequest() else { break }
        events.append(event)
        if case .requestAccepted = event {
          requestAccepted = true
          continue
        }
        terminal = true
        bytes.removeAll(keepingCapacity: false)
        break
      }
      guard bytes.count >= 3 else { break }
      let messageLength = (Int(bytes[bytes.startIndex]) << 8) | Int(bytes[bytes.startIndex + 1])
      let headerLength = Int(bytes[bytes.startIndex + 2])
      guard headerLength >= 4 else {
        events.append(.fatal)
        terminal = true
        bytes.removeAll(keepingCapacity: false)
        break
      }
      guard bytes.count >= headerLength else { break }
      let header = Data(bytes.prefix(headerLength))
      do {
        try RelayDatagramWire.validateHeader(header)
      } catch {
        events.append(.fatal)
        terminal = true
        bytes.removeAll(keepingCapacity: false)
        break
      }
      if messageLength > Int(RelayProtocolV1.maxUDPPayloadClientHardCeiling)
        || messageLength > Int(maximumPayloadLength)
      {
        bytes.removeFirst(headerLength)
        discardRemaining = messageLength
        discardLocalPolicy =
          messageLength
          <= Int(RelayProtocolV1.maxUDPPayloadClientHardCeiling)
        continue
      }
      let recordLength = headerLength + messageLength
      guard bytes.count >= recordLength else { break }
      events.append(.record(Data(bytes.prefix(recordLength))))
      bytes.removeFirst(recordLength)
    }
    return events
  }

  private mutating func consumeRequest() -> HEVUDPStreamEvent? {
    guard bytes.count >= 4 else { return nil }
    guard bytes[bytes.startIndex] == 5, bytes[bytes.startIndex + 2] == 0 else {
      return .requestRejected(1)
    }
    guard bytes[bytes.startIndex + 1] == 5 else {
      return .requestRejected(7)
    }
    let addressLength: Int
    let lengthPrefix: Int
    switch bytes[bytes.startIndex + 3] {
    case RelayProtocolV1.AddressType.ipv4.rawValue:
      addressLength = 4
      lengthPrefix = 0
    case RelayProtocolV1.AddressType.ipv6.rawValue:
      addressLength = 16
      lengthPrefix = 0
    case RelayProtocolV1.AddressType.domain.rawValue:
      guard bytes.count >= 5 else { return nil }
      addressLength = Int(bytes[bytes.startIndex + 4])
      guard addressLength > 0 else { return .requestRejected(8) }
      lengthPrefix = 1
    default:
      return .requestRejected(8)
    }
    let requestLength = 4 + lengthPrefix + addressLength + 2
    guard bytes.count >= requestLength else { return nil }
    bytes.removeFirst(requestLength)
    return .requestAccepted
  }
}

private func sendAll(_ data: Data, descriptor: Int32) throws {
  var offset = 0
  while offset < data.count {
    let sent = data.withUnsafeBytes { buffer in
      Darwin.send(descriptor, buffer.baseAddress! + offset, data.count - offset, 0)
    }
    if sent > 0 {
      offset += sent
    } else if sent < 0, errno == EINTR {
      continue
    } else {
      throw HEVIntegrationError.socksBoundaryFailed(code: sent == 0 ? EPIPE : errno)
    }
  }
}

private func queueCharge(for recordLength: Int) -> UInt32 {
  UInt32(max(recordLength + 10, 64))
}

private func incremented(_ value: UInt64) -> UInt64 {
  value == UInt64.max ? value : value + 1
}

private func adding(_ amount: UInt64, to value: UInt64) -> UInt64 {
  let (result, overflow) = value.addingReportingOverflow(amount)
  return overflow ? UInt64.max : result
}
