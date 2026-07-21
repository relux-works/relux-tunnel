import Foundation
import Synchronization

/// Caller-injected capacity evidence for one TCP adapter generation.
///
/// `measuredSafeMaximumFlows` and `hevMaximumSessionCount` are evidence gates,
/// not product defaults. The configured flow ceiling must fit under both.
public struct TCPAdmissionConfiguration: Equatable, Sendable {
  public let maximumPendingHandshakes: Int
  public let maximumReservedFlows: Int
  public let maximumConcurrentChannelOpens: Int
  public let maximumAggregateQueuedBytes: Int
  public let measuredSafeMaximumFlows: Int
  public let hevMaximumSessionCount: Int

  public init(
    maximumPendingHandshakes: Int,
    maximumReservedFlows: Int,
    maximumConcurrentChannelOpens: Int,
    maximumAggregateQueuedBytes: Int,
    measuredSafeMaximumFlows: Int,
    hevMaximumSessionCount: Int
  ) throws {
    let values: [(Int, TCPAdmissionConfigurationField)] = [
      (maximumPendingHandshakes, .maximumPendingHandshakes),
      (maximumReservedFlows, .maximumReservedFlows),
      (maximumConcurrentChannelOpens, .maximumConcurrentChannelOpens),
      (maximumAggregateQueuedBytes, .maximumAggregateQueuedBytes),
      (measuredSafeMaximumFlows, .measuredSafeMaximumFlows),
      (hevMaximumSessionCount, .hevMaximumSessionCount),
    ]
    for (value, field) in values where value <= 0 {
      throw TCPAdmissionConfigurationError.nonPositive(field)
    }
    guard maximumReservedFlows <= measuredSafeMaximumFlows else {
      throw TCPAdmissionConfigurationError.flowCeilingExceedsMeasuredSafeCeiling(
        configured: maximumReservedFlows,
        measuredSafe: measuredSafeMaximumFlows
      )
    }
    guard maximumReservedFlows <= hevMaximumSessionCount else {
      throw TCPAdmissionConfigurationError.flowCeilingExceedsHEVSessionCeiling(
        configured: maximumReservedFlows,
        hevMaximum: hevMaximumSessionCount
      )
    }
    guard maximumConcurrentChannelOpens <= maximumReservedFlows else {
      throw TCPAdmissionConfigurationError.openCeilingExceedsFlowCeiling(
        opens: maximumConcurrentChannelOpens,
        flows: maximumReservedFlows
      )
    }

    self.maximumPendingHandshakes = maximumPendingHandshakes
    self.maximumReservedFlows = maximumReservedFlows
    self.maximumConcurrentChannelOpens = maximumConcurrentChannelOpens
    self.maximumAggregateQueuedBytes = maximumAggregateQueuedBytes
    self.measuredSafeMaximumFlows = measuredSafeMaximumFlows
    self.hevMaximumSessionCount = hevMaximumSessionCount
  }
}

public enum TCPAdmissionConfigurationField: String, Equatable, Sendable {
  case maximumPendingHandshakes = "maximum_pending_handshakes"
  case maximumReservedFlows = "maximum_reserved_flows"
  case maximumConcurrentChannelOpens = "maximum_concurrent_channel_opens"
  case maximumAggregateQueuedBytes = "maximum_aggregate_queued_bytes"
  case measuredSafeMaximumFlows = "measured_safe_maximum_flows"
  case hevMaximumSessionCount = "hev_maximum_session_count"
}

public enum TCPAdmissionConfigurationError: Error, Equatable, Sendable {
  case nonPositive(TCPAdmissionConfigurationField)
  case flowCeilingExceedsMeasuredSafeCeiling(configured: Int, measuredSafe: Int)
  case flowCeilingExceedsHEVSessionCeiling(configured: Int, hevMaximum: Int)
  case openCeilingExceedsFlowCeiling(opens: Int, flows: Int)
}

/// Fixed capacity reserved for the two pump-owned directional buffers.
public struct TCPFlowQueuedByteReservation: Equatable, Sendable {
  public let localToSSHBytes: Int
  public let sshToLocalBytes: Int
  public let totalBytes: Int

  public init(localToSSHBytes: Int, sshToLocalBytes: Int) throws {
    guard localToSSHBytes > 0 else {
      throw TCPFlowQueuedByteReservationError.nonPositive(.localToSSH)
    }
    guard sshToLocalBytes > 0 else {
      throw TCPFlowQueuedByteReservationError.nonPositive(.sshToLocal)
    }
    let (total, overflow) = localToSSHBytes.addingReportingOverflow(sshToLocalBytes)
    guard !overflow else { throw TCPFlowQueuedByteReservationError.totalOverflow }
    self.localToSSHBytes = localToSSHBytes
    self.sshToLocalBytes = sshToLocalBytes
    totalBytes = total
  }

  /// Uses the exact fixed directional capacities already validated for a
  /// bounded full-duplex pump, avoiding a second independently tuned value.
  public init(pumpConfiguration: BoundedFullDuplexBytePumpConfiguration) {
    localToSSHBytes = pumpConfiguration.localReadChunkBytes
    sshToLocalBytes = pumpConfiguration.remoteReadChunkBytes
    totalBytes = pumpConfiguration.perFlowReservedBufferBytes
  }
}

public enum TCPFlowQueuedByteDirection: String, Equatable, Sendable {
  case localToSSH = "local_to_ssh"
  case sshToLocal = "ssh_to_local"
}

public enum TCPFlowQueuedByteReservationError: Error, Equatable, Sendable {
  case nonPositive(TCPFlowQueuedByteDirection)
  case totalOverflow
}

public enum TCPAdmissionSessionHealth: Int64, Equatable, Sendable {
  case unavailable = 0
  case healthy = 1
  case stopping = 2
}

public enum TCPAdmissionPressureReason: String, CaseIterable, Hashable, Sendable {
  case sessionUnavailable = "session_unavailable"
  case handshakeCapacity = "handshake_capacity"
  case flowCapacity = "flow_capacity"
  case openingCapacity = "opening_capacity"
  case queuedByteCapacity = "queued_byte_capacity"
  case identifierCapacity = "identifier_capacity"
}

/// Immediate admission failure. Every pressure reason maps to SOCKS5 general
/// failure and explicitly prohibits an SSH channel-open attempt.
public struct TCPAdmissionRejection: Error, Equatable, Sendable {
  public static let socksGeneralFailureReply: UInt8 = 0x01

  public let reason: TCPAdmissionPressureReason
  public let socksReply: UInt8
  public let shouldOpenSSHChannel: Bool

  fileprivate init(reason: TCPAdmissionPressureReason) {
    self.reason = reason
    socksReply = Self.socksGeneralFailureReply
    shouldOpenSSHChannel = false
  }
}

public enum TCPFlowAccountingPhase: String, CaseIterable, Hashable, Sendable {
  case parsing
  case opening
  case streaming
  case halfClosed = "half_closed"
}

/// Finite terminal reasons accepted by the TCP adapter contract.
public enum TCPFlowTerminalReason: String, CaseIterable, Hashable, Sendable {
  case capacity
  case malformed
  case unsupportedCommand = "unsupported_command"
  case unsupportedAddress = "unsupported_address"
  case policyDenied = "policy_denied"
  case networkUnreachable = "network_unreachable"
  case hostUnreachable = "host_unreachable"
  case connectionRefused = "connection_refused"
  case timeout
  case cancelled
  case localReset = "local_reset"
  case remoteReset = "remote_reset"
  case sessionLost = "session_lost"
  case contractViolation = "contract_violation"
  case `internal`
  case graceful
}

public enum TCPChannelOpenResult: Equatable, Sendable {
  case succeeded
  case failed
}

/// Fixed schema counters available to TCP producers. No case accepts a label.
public enum RuntimeTCPAdapterCounter: String, CaseIterable, Sendable {
  case acceptedAuthenticatedTotal = "tcp_accepted_authenticated_total"
  case admissionRejectedTotal = "tcp_admission_rejected_total"
  case requestValidTotal = "tcp_request_valid_total"
  case requestRejectedTotal = "tcp_request_rejected_total"
  case channelOpenAttemptedTotal = "tcp_channel_open_attempted_total"
  case channelOpenSucceededTotal = "tcp_channel_open_succeeded_total"
  case channelOpenFailedTotal = "tcp_channel_open_failed_total"
  case successReplyTotal = "tcp_success_reply_total"
  case failureReplyTotal = "tcp_failure_reply_total"
  case bytesLocalToSSHTotal = "tcp_bytes_local_to_ssh_total"
  case bytesSSHToLocalTotal = "tcp_bytes_ssh_to_local_total"
  case localEOFTotal = "tcp_local_eof_total"
  case remoteEOFTotal = "tcp_remote_eof_total"
  case flowsGracefulTotal = "tcp_flows_graceful_total"
  case flowsResetTotal = "tcp_flows_reset_total"
  case flowsCancelledTotal = "tcp_flows_cancelled_total"
  case flowsTimedOutTotal = "tcp_flows_timed_out_total"
  case lateEventDiscardedTotal = "tcp_late_event_discarded_total"
  case zeroProgressViolationTotal = "tcp_zero_progress_violation_total"
  case reservationReleaseViolationTotal = "tcp_reservation_release_violation_total"
}

public enum RuntimeTCPAdapterGauge: String, CaseIterable, Sendable {
  case pendingHandshakes = "tcp_pending_handshakes"
  case reservedFlows = "tcp_reserved_flows"
  case parsingFlows = "tcp_parsing_flows"
  case openingFlows = "tcp_opening_flows"
  case streamingFlows = "tcp_streaming_flows"
  case halfClosedFlows = "tcp_half_closed_flows"
  case openChannels = "tcp_open_channels"
  case reservedQueuedBytes = "tcp_reserved_queued_bytes"
  case adapterBufferedBytes = "tcp_adapter_buffered_bytes"
  case localToSSHBufferedBytes = "tcp_local_to_ssh_buffered_bytes"
  case sshToLocalBufferedBytes = "tcp_ssh_to_local_buffered_bytes"
  case peakPendingHandshakes = "tcp_peak_pending_handshakes"
  case peakReservedFlows = "tcp_peak_reserved_flows"
  case peakOpeningFlows = "tcp_peak_opening_flows"
  case peakOpenChannels = "tcp_peak_open_channels"
  case peakReservedQueuedBytes = "tcp_peak_reserved_queued_bytes"
  case peakAdapterBufferedBytes = "tcp_peak_adapter_buffered_bytes"
  case sessionHealthCode = "tcp_session_health_code"
}

/// One absolute, fixed-cardinality view of every registry-owned gauge.
///
/// Diagnostics implementations may coalesce intermediate publications, but
/// the latest publication must remain available for snapshot reconciliation.
/// No field can carry flow identity or destination data.
public struct TCPAdmissionGaugeSnapshot: Equatable, Sendable {
  public let sessionHealthCode: Int64
  public let pendingHandshakes: Int64
  public let reservedFlows: Int64
  public let parsingFlows: Int64
  public let openingFlows: Int64
  public let streamingFlows: Int64
  public let halfClosedFlows: Int64
  public let openChannels: Int64
  public let reservedQueuedBytes: Int64
  public let adapterBufferedBytes: Int64
  public let localToSSHBufferedBytes: Int64
  public let sshToLocalBufferedBytes: Int64
  public let peakPendingHandshakes: Int64
  public let peakReservedFlows: Int64
  public let peakOpeningFlows: Int64
  public let peakOpenChannels: Int64
  public let peakReservedQueuedBytes: Int64
  public let peakAdapterBufferedBytes: Int64
}

/// Non-waiting, aggregate-only diagnostics seam used while the registry lock is held.
public protocol TCPAdmissionDiagnosticsSink: Sendable {
  func recordTCPAdapterCounter(_ counter: RuntimeTCPAdapterCounter, by amount: UInt64)
  func recordTCPAdmissionPressure(_ reason: TCPAdmissionPressureReason)
  func recordTCPFlowReserved()
  func recordTCPFlowReleased()
  func recordTCPFlowTerminal(_ reason: TCPFlowTerminalReason)
  func recordTCPChannelOpenLatency(milliseconds: UInt64)
  func publishTCPAdmissionGauges(_ snapshot: TCPAdmissionGaugeSnapshot)
}

public struct TCPAdmissionSnapshot: Equatable, Sendable {
  public let sessionHealth: TCPAdmissionSessionHealth
  public let pendingHandshakes: Int
  public let reservedFlows: Int
  public let parsingFlows: Int
  public let openingFlows: Int
  public let streamingFlows: Int
  public let halfClosedFlows: Int
  public let openChannels: Int
  public let reservedQueuedBytes: Int
  public let localToSSHBufferedBytes: Int
  public let sshToLocalBufferedBytes: Int
  public let peakPendingHandshakes: Int
  public let peakReservedFlows: Int
  public let peakOpeningFlows: Int
  public let peakOpenChannels: Int
  public let peakReservedQueuedBytes: Int
  public let peakAdapterBufferedBytes: Int
  public let acceptedAuthenticated: UInt64
  public let admissionRejected: UInt64
  public let bytesLocalToSSH: UInt64
  public let bytesSSHToLocal: UInt64
  public let releaseViolations: UInt64
  public let pressureRejects: [TCPAdmissionPressureReason: UInt64]
  public let terminalReasons: [TCPFlowTerminalReason: UInt64]

  public var adapterBufferedBytes: Int {
    localToSSHBufferedBytes + sshToLocalBufferedBytes
  }
}

/// Race-safe, generation-scoped reservation authority for TCP work.
///
/// All `try` operations decide under one lock and never enqueue an unadmitted
/// request. Token destruction is a rollback safety net; normal owners release
/// explicitly at their accepted lifecycle boundary.
public final class TCPAdmissionRegistry: @unchecked Sendable {
  private struct FlowRecord {
    let queuedBytes: TCPFlowQueuedByteReservation
    var phase: TCPFlowAccountingPhase = .parsing
    var openingID: UInt64?
    var ownsChannel = false
    var localToSSHBufferedBytes = 0
    var sshToLocalBufferedBytes = 0
  }

  private struct State {
    var sessionHealth: TCPAdmissionSessionHealth
    var nextID: UInt64?
    var handshakes: Set<UInt64> = []
    var flows: [UInt64: FlowRecord] = [:]
    var openings: [UInt64: UInt64] = [:]
    var openChannels = 0
    var reservedQueuedBytes = 0
    var localToSSHBufferedBytes = 0
    var sshToLocalBufferedBytes = 0
    var peakPendingHandshakes = 0
    var peakReservedFlows = 0
    var peakOpeningFlows = 0
    var peakOpenChannels = 0
    var peakReservedQueuedBytes = 0
    var peakAdapterBufferedBytes = 0
    var acceptedAuthenticated: UInt64 = 0
    var admissionRejected: UInt64 = 0
    var bytesLocalToSSH: UInt64 = 0
    var bytesSSHToLocal: UInt64 = 0
    var releaseViolations: UInt64 = 0
    var pressureRejects = Dictionary(
      uniqueKeysWithValues: TCPAdmissionPressureReason.allCases.map { ($0, UInt64.zero) }
    )
    var terminalReasons = Dictionary(
      uniqueKeysWithValues: TCPFlowTerminalReason.allCases.map { ($0, UInt64.zero) }
    )

    mutating func allocateID() -> UInt64? {
      guard let id = nextID else { return nil }
      nextID = id == UInt64.max ? nil : id + 1
      return id
    }
  }

  public let configuration: TCPAdmissionConfiguration

  private let state: Mutex<State>
  private let diagnostics: (any TCPAdmissionDiagnosticsSink)?

  public init(
    configuration: TCPAdmissionConfiguration,
    initialSessionHealth: TCPAdmissionSessionHealth = .unavailable,
    diagnostics: (any TCPAdmissionDiagnosticsSink)? = nil
  ) {
    self.configuration = configuration
    state = Mutex(State(sessionHealth: initialSessionHealth, nextID: 1))
    self.diagnostics = diagnostics
    state.withLock { emitGauges($0) }
  }

  internal init(
    configuration: TCPAdmissionConfiguration,
    initialSessionHealth: TCPAdmissionSessionHealth,
    diagnostics: (any TCPAdmissionDiagnosticsSink)?,
    initialReservationIdentifierForTesting: UInt64
  ) {
    precondition(initialReservationIdentifierForTesting > 0)
    self.configuration = configuration
    state = Mutex(
      State(
        sessionHealth: initialSessionHealth,
        nextID: initialReservationIdentifierForTesting
      )
    )
    self.diagnostics = diagnostics
    state.withLock { emitGauges($0) }
  }

  public func setSessionHealth(_ health: TCPAdmissionSessionHealth) {
    state.withLock { state in
      state.sessionHealth = health
      emitGauges(state)
    }
  }

  public func tryReserveHandshake() -> Result<TCPHandshakeReservation, TCPAdmissionRejection> {
    state.withLock { state in
      guard state.sessionHealth == .healthy else {
        return .failure(reject(.sessionUnavailable, state: &state))
      }
      guard state.handshakes.count < configuration.maximumPendingHandshakes else {
        return .failure(reject(.handshakeCapacity, state: &state))
      }
      guard let id = state.allocateID() else {
        return .failure(reject(.identifierCapacity, state: &state))
      }
      state.handshakes.insert(id)
      state.peakPendingHandshakes = max(state.peakPendingHandshakes, state.handshakes.count)
      emitGauges(state)
      return .success(TCPHandshakeReservation(registry: self, id: id))
    }
  }

  public func admitAuthenticated(
    _ handshake: TCPHandshakeReservation,
    queuedBytes: TCPFlowQueuedByteReservation
  ) -> Result<TCPFlowReservation, TCPAdmissionRejection> {
    guard handshake.registry === self, handshake.claim() else {
      recordReleaseViolation()
      return .failure(TCPAdmissionRejection(reason: .sessionUnavailable))
    }
    return state.withLock { state in
      guard state.handshakes.remove(handshake.id) != nil else {
        state.releaseViolations = Self.incremented(state.releaseViolations)
        diagnostics?.recordTCPAdapterCounter(.reservationReleaseViolationTotal, by: 1)
        return .failure(TCPAdmissionRejection(reason: .sessionUnavailable))
      }
      state.acceptedAuthenticated = Self.incremented(state.acceptedAuthenticated)
      diagnostics?.recordTCPAdapterCounter(.acceptedAuthenticatedTotal, by: 1)
      guard state.sessionHealth == .healthy else {
        emitGauges(state)
        return .failure(reject(.sessionUnavailable, state: &state))
      }
      guard state.flows.count < configuration.maximumReservedFlows else {
        emitGauges(state)
        return .failure(reject(.flowCapacity, state: &state))
      }
      let (proposedBytes, overflow) = state.reservedQueuedBytes.addingReportingOverflow(
        queuedBytes.totalBytes
      )
      guard !overflow, proposedBytes <= configuration.maximumAggregateQueuedBytes else {
        emitGauges(state)
        return .failure(reject(.queuedByteCapacity, state: &state))
      }

      guard let id = state.allocateID() else {
        emitGauges(state)
        return .failure(reject(.identifierCapacity, state: &state))
      }
      state.flows[id] = FlowRecord(queuedBytes: queuedBytes)
      state.reservedQueuedBytes = proposedBytes
      state.peakReservedFlows = max(state.peakReservedFlows, state.flows.count)
      state.peakReservedQueuedBytes = max(state.peakReservedQueuedBytes, proposedBytes)
      diagnostics?.recordTCPFlowReserved()
      emitGauges(state)
      return .success(TCPFlowReservation(registry: self, id: id))
    }
  }

  public func tryReserveChannelOpen(
    for flow: TCPFlowReservation,
    atUptimeMilliseconds: UInt64
  ) -> Result<TCPChannelOpenReservation, TCPAdmissionRejection> {
    guard flow.registry === self else {
      recordReleaseViolation()
      return .failure(TCPAdmissionRejection(reason: .sessionUnavailable))
    }
    guard flow.isActive else {
      diagnostics?.recordTCPAdapterCounter(.lateEventDiscardedTotal, by: 1)
      return .failure(TCPAdmissionRejection(reason: .sessionUnavailable))
    }
    return state.withLock { state in
      guard var record = state.flows[flow.id] else {
        diagnostics?.recordTCPAdapterCounter(.lateEventDiscardedTotal, by: 1)
        return .failure(TCPAdmissionRejection(reason: .sessionUnavailable))
      }
      guard record.openingID == nil, !record.ownsChannel else {
        state.releaseViolations = Self.incremented(state.releaseViolations)
        diagnostics?.recordTCPAdapterCounter(.reservationReleaseViolationTotal, by: 1)
        return .failure(TCPAdmissionRejection(reason: .sessionUnavailable))
      }
      guard state.sessionHealth == .healthy else {
        return .failure(reject(.sessionUnavailable, state: &state))
      }
      guard state.openings.count < configuration.maximumConcurrentChannelOpens else {
        return .failure(reject(.openingCapacity, state: &state))
      }
      guard let openingID = state.allocateID() else {
        return .failure(reject(.identifierCapacity, state: &state))
      }
      record.phase = .opening
      record.openingID = openingID
      state.flows[flow.id] = record
      state.openings[openingID] = flow.id
      state.peakOpeningFlows = max(state.peakOpeningFlows, state.openings.count)
      diagnostics?.recordTCPAdapterCounter(.channelOpenAttemptedTotal, by: 1)
      emitGauges(state)
      return .success(
        TCPChannelOpenReservation(
          registry: self,
          id: openingID,
          flowID: flow.id,
          startedAtUptimeMilliseconds: atUptimeMilliseconds
        )
      )
    }
  }

  public func snapshot() -> TCPAdmissionSnapshot {
    state.withLock { snapshot(of: $0) }
  }

  fileprivate func releaseHandshake(id: UInt64) {
    state.withLock { state in
      guard state.handshakes.remove(id) != nil else {
        state.releaseViolations = Self.incremented(state.releaseViolations)
        diagnostics?.recordTCPAdapterCounter(.reservationReleaseViolationTotal, by: 1)
        return
      }
      emitGauges(state)
    }
  }

  fileprivate func finishChannelOpen(
    id: UInt64,
    flowID: UInt64,
    result: TCPChannelOpenResult,
    startedAtUptimeMilliseconds: UInt64,
    finishedAtUptimeMilliseconds: UInt64
  ) -> Bool {
    state.withLock { state in
      guard state.openings.removeValue(forKey: id) == flowID,
        var record = state.flows[flowID], record.openingID == id
      else {
        diagnostics?.recordTCPAdapterCounter(.lateEventDiscardedTotal, by: 1)
        return false
      }
      record.openingID = nil
      switch result {
      case .succeeded:
        record.phase = .streaming
        record.ownsChannel = true
        state.openChannels += 1
        state.peakOpenChannels = max(state.peakOpenChannels, state.openChannels)
        diagnostics?.recordTCPAdapterCounter(.channelOpenSucceededTotal, by: 1)
      case .failed:
        record.phase = .parsing
        diagnostics?.recordTCPAdapterCounter(.channelOpenFailedTotal, by: 1)
      }
      state.flows[flowID] = record
      let latency =
        finishedAtUptimeMilliseconds >= startedAtUptimeMilliseconds
        ? finishedAtUptimeMilliseconds - startedAtUptimeMilliseconds : 0
      diagnostics?.recordTCPChannelOpenLatency(milliseconds: latency)
      emitGauges(state)
      return true
    }
  }

  fileprivate func updateBufferedBytes(
    flowID: UInt64,
    localToSSHBytes: Int,
    sshToLocalBytes: Int
  ) -> Bool {
    state.withLock { state in
      guard var record = state.flows[flowID] else {
        diagnostics?.recordTCPAdapterCounter(.lateEventDiscardedTotal, by: 1)
        return false
      }
      guard localToSSHBytes >= 0, sshToLocalBytes >= 0,
        localToSSHBytes <= record.queuedBytes.localToSSHBytes,
        sshToLocalBytes <= record.queuedBytes.sshToLocalBytes
      else {
        state.releaseViolations = Self.incremented(state.releaseViolations)
        diagnostics?.recordTCPAdapterCounter(.reservationReleaseViolationTotal, by: 1)
        return false
      }
      state.localToSSHBufferedBytes -= record.localToSSHBufferedBytes
      state.sshToLocalBufferedBytes -= record.sshToLocalBufferedBytes
      record.localToSSHBufferedBytes = localToSSHBytes
      record.sshToLocalBufferedBytes = sshToLocalBytes
      state.localToSSHBufferedBytes += localToSSHBytes
      state.sshToLocalBufferedBytes += sshToLocalBytes
      state.flows[flowID] = record
      state.peakAdapterBufferedBytes = max(
        state.peakAdapterBufferedBytes,
        state.localToSSHBufferedBytes + state.sshToLocalBufferedBytes
      )
      emitGauges(state)
      return true
    }
  }

  fileprivate func recordBytes(flowID: UInt64, localToSSH: UInt64, sshToLocal: UInt64) -> Bool {
    state.withLock { state in
      guard state.flows[flowID] != nil else {
        diagnostics?.recordTCPAdapterCounter(.lateEventDiscardedTotal, by: 1)
        return false
      }
      state.bytesLocalToSSH = state.bytesLocalToSSH.tcpSaturatingAdding(localToSSH)
      state.bytesSSHToLocal = state.bytesSSHToLocal.tcpSaturatingAdding(sshToLocal)
      diagnostics?.recordTCPAdapterCounter(.bytesLocalToSSHTotal, by: localToSSH)
      diagnostics?.recordTCPAdapterCounter(.bytesSSHToLocalTotal, by: sshToLocal)
      return true
    }
  }

  fileprivate func markHalfClosed(flowID: UInt64) -> Bool {
    state.withLock { state in
      guard var record = state.flows[flowID] else {
        diagnostics?.recordTCPAdapterCounter(.lateEventDiscardedTotal, by: 1)
        return false
      }
      guard record.phase == .streaming else { return false }
      record.phase = .halfClosed
      state.flows[flowID] = record
      emitGauges(state)
      return true
    }
  }

  fileprivate func releaseFlow(id: UInt64, reason: TCPFlowTerminalReason) {
    state.withLock { state in
      guard let record = state.flows.removeValue(forKey: id) else {
        state.releaseViolations = Self.incremented(state.releaseViolations)
        diagnostics?.recordTCPAdapterCounter(.reservationReleaseViolationTotal, by: 1)
        return
      }
      if let openingID = record.openingID {
        state.openings.removeValue(forKey: openingID)
        diagnostics?.recordTCPAdapterCounter(.channelOpenFailedTotal, by: 1)
      }
      if record.ownsChannel {
        state.openChannels -= 1
      }
      state.reservedQueuedBytes -= record.queuedBytes.totalBytes
      state.localToSSHBufferedBytes -= record.localToSSHBufferedBytes
      state.sshToLocalBufferedBytes -= record.sshToLocalBufferedBytes
      state.terminalReasons[reason] = Self.incremented(state.terminalReasons[reason] ?? 0)
      diagnostics?.recordTCPFlowReleased()
      diagnostics?.recordTCPFlowTerminal(reason)
      emitGauges(state)
    }
  }

  fileprivate func recordReleaseViolation() {
    state.withLock { state in
      state.releaseViolations = Self.incremented(state.releaseViolations)
      diagnostics?.recordTCPAdapterCounter(.reservationReleaseViolationTotal, by: 1)
    }
  }

  private func reject(
    _ reason: TCPAdmissionPressureReason,
    state: inout State
  ) -> TCPAdmissionRejection {
    state.admissionRejected = Self.incremented(state.admissionRejected)
    state.pressureRejects[reason] = Self.incremented(state.pressureRejects[reason] ?? 0)
    diagnostics?.recordTCPAdapterCounter(.admissionRejectedTotal, by: 1)
    diagnostics?.recordTCPAdmissionPressure(reason)
    return TCPAdmissionRejection(reason: reason)
  }

  private func emitGauges(_ state: State) {
    let phaseCounts = Dictionary(grouping: state.flows.values, by: \FlowRecord.phase)
      .mapValues(\.count)
    diagnostics?.publishTCPAdmissionGauges(
      TCPAdmissionGaugeSnapshot(
        sessionHealthCode: state.sessionHealth.rawValue,
        pendingHandshakes: Int64(clamping: state.handshakes.count),
        reservedFlows: Int64(clamping: state.flows.count),
        parsingFlows: Int64(clamping: phaseCounts[.parsing] ?? 0),
        openingFlows: Int64(clamping: phaseCounts[.opening] ?? 0),
        streamingFlows: Int64(clamping: phaseCounts[.streaming] ?? 0),
        halfClosedFlows: Int64(clamping: phaseCounts[.halfClosed] ?? 0),
        openChannels: Int64(clamping: state.openChannels),
        reservedQueuedBytes: Int64(clamping: state.reservedQueuedBytes),
        adapterBufferedBytes: Int64(
          clamping: state.localToSSHBufferedBytes + state.sshToLocalBufferedBytes
        ),
        localToSSHBufferedBytes: Int64(clamping: state.localToSSHBufferedBytes),
        sshToLocalBufferedBytes: Int64(clamping: state.sshToLocalBufferedBytes),
        peakPendingHandshakes: Int64(clamping: state.peakPendingHandshakes),
        peakReservedFlows: Int64(clamping: state.peakReservedFlows),
        peakOpeningFlows: Int64(clamping: state.peakOpeningFlows),
        peakOpenChannels: Int64(clamping: state.peakOpenChannels),
        peakReservedQueuedBytes: Int64(clamping: state.peakReservedQueuedBytes),
        peakAdapterBufferedBytes: Int64(clamping: state.peakAdapterBufferedBytes)
      )
    )
  }

  private func snapshot(of state: State) -> TCPAdmissionSnapshot {
    let phaseCounts = Dictionary(grouping: state.flows.values, by: \FlowRecord.phase)
      .mapValues(\.count)
    return TCPAdmissionSnapshot(
      sessionHealth: state.sessionHealth,
      pendingHandshakes: state.handshakes.count,
      reservedFlows: state.flows.count,
      parsingFlows: phaseCounts[.parsing] ?? 0,
      openingFlows: phaseCounts[.opening] ?? 0,
      streamingFlows: phaseCounts[.streaming] ?? 0,
      halfClosedFlows: phaseCounts[.halfClosed] ?? 0,
      openChannels: state.openChannels,
      reservedQueuedBytes: state.reservedQueuedBytes,
      localToSSHBufferedBytes: state.localToSSHBufferedBytes,
      sshToLocalBufferedBytes: state.sshToLocalBufferedBytes,
      peakPendingHandshakes: state.peakPendingHandshakes,
      peakReservedFlows: state.peakReservedFlows,
      peakOpeningFlows: state.peakOpeningFlows,
      peakOpenChannels: state.peakOpenChannels,
      peakReservedQueuedBytes: state.peakReservedQueuedBytes,
      peakAdapterBufferedBytes: state.peakAdapterBufferedBytes,
      acceptedAuthenticated: state.acceptedAuthenticated,
      admissionRejected: state.admissionRejected,
      bytesLocalToSSH: state.bytesLocalToSSH,
      bytesSSHToLocal: state.bytesSSHToLocal,
      releaseViolations: state.releaseViolations,
      pressureRejects: state.pressureRejects,
      terminalReasons: state.terminalReasons
    )
  }

  private static func incremented(_ value: UInt64) -> UInt64 {
    value == UInt64.max ? UInt64.max : value + 1
  }
}

public final class TCPHandshakeReservation: @unchecked Sendable {
  fileprivate let registry: TCPAdmissionRegistry
  fileprivate let id: UInt64
  private let active = Atomic(true)

  fileprivate init(registry: TCPAdmissionRegistry, id: UInt64) {
    self.registry = registry
    self.id = id
  }

  @discardableResult
  public func release() -> Bool {
    guard claim() else {
      registry.recordReleaseViolation()
      return false
    }
    registry.releaseHandshake(id: id)
    return true
  }

  fileprivate func claim() -> Bool {
    active.compareExchange(
      expected: true,
      desired: false,
      ordering: .acquiringAndReleasing
    ).exchanged
  }

  deinit {
    if claim() { registry.releaseHandshake(id: id) }
  }
}

public final class TCPFlowReservation: @unchecked Sendable {
  fileprivate let registry: TCPAdmissionRegistry
  fileprivate let id: UInt64
  private let active = Atomic(true)

  fileprivate init(registry: TCPAdmissionRegistry, id: UInt64) {
    self.registry = registry
    self.id = id
  }

  fileprivate var isActive: Bool { active.load(ordering: .acquiring) }

  @discardableResult
  public func updateBufferedBytes(localToSSHBytes: Int, sshToLocalBytes: Int) -> Bool {
    return registry.updateBufferedBytes(
      flowID: id,
      localToSSHBytes: localToSSHBytes,
      sshToLocalBytes: sshToLocalBytes
    )
  }

  @discardableResult
  public func recordTransferredBytes(localToSSH: UInt64, sshToLocal: UInt64) -> Bool {
    return registry.recordBytes(flowID: id, localToSSH: localToSSH, sshToLocal: sshToLocal)
  }

  @discardableResult
  public func markHalfClosed() -> Bool {
    return registry.markHalfClosed(flowID: id)
  }

  @discardableResult
  public func release(reason: TCPFlowTerminalReason) -> Bool {
    let exchanged = active.compareExchange(
      expected: true,
      desired: false,
      ordering: .acquiringAndReleasing
    ).exchanged
    guard exchanged else {
      registry.recordReleaseViolation()
      return false
    }
    registry.releaseFlow(id: id, reason: reason)
    return true
  }

  deinit {
    if active.compareExchange(
      expected: true,
      desired: false,
      ordering: .acquiringAndReleasing
    ).exchanged {
      registry.releaseFlow(id: id, reason: .cancelled)
    }
  }
}

public final class TCPChannelOpenReservation: @unchecked Sendable {
  fileprivate let registry: TCPAdmissionRegistry
  fileprivate let id: UInt64
  fileprivate let flowID: UInt64
  fileprivate let startedAtUptimeMilliseconds: UInt64
  private let active = Atomic(true)

  fileprivate init(
    registry: TCPAdmissionRegistry,
    id: UInt64,
    flowID: UInt64,
    startedAtUptimeMilliseconds: UInt64
  ) {
    self.registry = registry
    self.id = id
    self.flowID = flowID
    self.startedAtUptimeMilliseconds = startedAtUptimeMilliseconds
  }

  @discardableResult
  public func finish(
    _ result: TCPChannelOpenResult,
    atUptimeMilliseconds: UInt64
  ) -> Bool {
    guard
      active.compareExchange(
        expected: true,
        desired: false,
        ordering: .acquiringAndReleasing
      ).exchanged
    else {
      registry.recordReleaseViolation()
      return false
    }
    return registry.finishChannelOpen(
      id: id,
      flowID: flowID,
      result: result,
      startedAtUptimeMilliseconds: startedAtUptimeMilliseconds,
      finishedAtUptimeMilliseconds: atUptimeMilliseconds
    )
  }

  deinit {
    if active.compareExchange(
      expected: true,
      desired: false,
      ordering: .acquiringAndReleasing
    ).exchanged {
      _ = registry.finishChannelOpen(
        id: id,
        flowID: flowID,
        result: .failed,
        startedAtUptimeMilliseconds: startedAtUptimeMilliseconds,
        finishedAtUptimeMilliseconds: startedAtUptimeMilliseconds
      )
    }
  }
}

extension UInt64 {
  fileprivate func tcpSaturatingAdding(_ other: UInt64) -> UInt64 {
    let (sum, overflow) = addingReportingOverflow(other)
    return overflow ? UInt64.max : sum
  }
}
