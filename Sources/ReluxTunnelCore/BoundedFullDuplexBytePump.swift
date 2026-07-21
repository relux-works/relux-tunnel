import Foundation

/// The two independently scheduled halves of one local-to-SSH byte stream.
public enum BytePumpDirection: String, CaseIterable, Hashable, Sendable {
  case localToSSH = "local_to_ssh"
  case sshToLocal = "ssh_to_local"
}

public enum LocalByteStreamReadiness: String, Equatable, Sendable {
  case readable
  case writable
}

public enum LocalByteStreamReadinessEvent: Equatable, Sendable {
  case ready
  case peerClosed
}

public enum LocalByteStreamReadResult: Equatable, Sendable {
  case bytes(Data)
  case wouldBlock
  case endOfStream
}

public enum LocalByteStreamWriteResult: Equatable, Sendable {
  case written(Int)
  case wouldBlock
  case peerClosed
}

/// Candidate-neutral local stream boundary for a nonblocking socket.
///
/// `readSome` and `writeSome` must complete without waiting for readiness.
/// A would-block result is followed by exactly one readiness wait. The
/// implementation must make every readiness wait return after
/// `cancelPendingOperations`; Core never polls a descriptor or runs a blocking
/// syscall on a packet, lifecycle, or SSH event executor.
public protocol LocalNonblockingByteStream: AnyObject, Sendable {
  func readSome(maximumBytes: Int) async throws -> LocalByteStreamReadResult
  func writeSome(_ bytes: Data) async throws -> LocalByteStreamWriteResult
  func waitForReadiness(_ readiness: LocalByteStreamReadiness) async throws
    -> LocalByteStreamReadinessEvent
  func cancelPendingOperations()
}

public protocol BytePumpScheduler: Sendable {
  /// Cooperatively yields one bounded work slice and must respect task cancellation.
  func yield() async throws
}

public struct TaskBytePumpScheduler: BytePumpScheduler {
  public init() {}

  public func yield() async throws {
    try Task<Never, Never>.checkCancellation()
    await Task.yield()
    try Task<Never, Never>.checkCancellation()
  }
}

public enum BytePumpConfigurationField: String, Equatable, Sendable {
  case localReadChunkBytes = "local_read_chunk_bytes"
  case remoteReadChunkBytes = "remote_read_chunk_bytes"
  case maximumSSHWriteCallBytes = "maximum_ssh_write_call_bytes"
  case maximumAggregateReservedBytes = "maximum_aggregate_reserved_bytes"
  case fairnessMaximumOperations = "fairness_maximum_operations"
  case fairnessMaximumBytes = "fairness_maximum_bytes"
  case maximumConsecutiveReadinessWakeupsWithoutProgress =
    "maximum_consecutive_readiness_wakeups_without_progress"
}

public enum BytePumpConfigurationError: Error, Equatable, Sendable {
  case nonPositive(BytePumpConfigurationField)
  case perFlowReservationOverflow
  case perFlowReservationExceedsAggregate(perFlow: Int, aggregate: Int)
  case aggregateBudgetMismatch(configuration: Int, budget: Int)
}

/// Caller-owned fixed ceilings for one full-duplex pump.
///
/// Pump-owned live byte storage is bounded by `localReadChunkBytes` in the
/// local-to-SSH direction and `remoteReadChunkBytes` in the SSH-to-local
/// direction. Their checked sum is the per-flow reservation. Peer-advertised
/// lengths and SSH window credit never increase these values. A shared
/// `BytePumpBufferBudget` additionally caps the sum reserved by all concurrent
/// flows.
public struct BoundedFullDuplexBytePumpConfiguration: Equatable, Sendable {
  public let localReadChunkBytes: Int
  public let remoteReadChunkBytes: Int
  public let maximumSSHWriteCallBytes: Int
  public let maximumAggregateReservedBytes: Int
  public let fairnessMaximumOperations: Int
  public let fairnessMaximumBytes: Int
  public let maximumConsecutiveReadinessWakeupsWithoutProgress: Int
  public let perFlowReservedBufferBytes: Int

  public init(
    localReadChunkBytes: Int,
    remoteReadChunkBytes: Int,
    maximumSSHWriteCallBytes: Int,
    maximumAggregateReservedBytes: Int,
    fairnessMaximumOperations: Int,
    fairnessMaximumBytes: Int,
    maximumConsecutiveReadinessWakeupsWithoutProgress: Int
  ) throws {
    let positiveValues: [(Int, BytePumpConfigurationField)] = [
      (localReadChunkBytes, .localReadChunkBytes),
      (remoteReadChunkBytes, .remoteReadChunkBytes),
      (maximumSSHWriteCallBytes, .maximumSSHWriteCallBytes),
      (maximumAggregateReservedBytes, .maximumAggregateReservedBytes),
      (fairnessMaximumOperations, .fairnessMaximumOperations),
      (fairnessMaximumBytes, .fairnessMaximumBytes),
      (
        maximumConsecutiveReadinessWakeupsWithoutProgress,
        .maximumConsecutiveReadinessWakeupsWithoutProgress
      ),
    ]
    for (value, field) in positiveValues where value <= 0 {
      throw BytePumpConfigurationError.nonPositive(field)
    }

    let (reservation, overflow) =
      localReadChunkBytes.addingReportingOverflow(remoteReadChunkBytes)
    guard !overflow else {
      throw BytePumpConfigurationError.perFlowReservationOverflow
    }
    guard reservation <= maximumAggregateReservedBytes else {
      throw BytePumpConfigurationError.perFlowReservationExceedsAggregate(
        perFlow: reservation,
        aggregate: maximumAggregateReservedBytes
      )
    }

    self.localReadChunkBytes = localReadChunkBytes
    self.remoteReadChunkBytes = remoteReadChunkBytes
    self.maximumSSHWriteCallBytes = maximumSSHWriteCallBytes
    self.maximumAggregateReservedBytes = maximumAggregateReservedBytes
    self.fairnessMaximumOperations = fairnessMaximumOperations
    self.fairnessMaximumBytes = fairnessMaximumBytes
    self.maximumConsecutiveReadinessWakeupsWithoutProgress =
      maximumConsecutiveReadinessWakeupsWithoutProgress
    perFlowReservedBufferBytes = reservation
  }
}

public struct BytePumpBufferBudgetSnapshot: Equatable, Sendable {
  public let maximumReservedBytes: Int
  public let reservedBytes: Int
  public let peakReservedBytes: Int
  public let successfulReservations: UInt64
  public let deniedReservations: UInt64
  public let releases: UInt64
  public let releaseViolations: UInt64
}

/// Shared non-waiting reservation authority for all pump-owned byte buffers.
///
/// Reservations cover fixed capacities rather than current `Data.count`, so
/// concurrent flows cannot overcommit the caller's aggregate ceiling. Capacity
/// denial never queues a waiter.
public actor BytePumpBufferBudget {
  public nonisolated let maximumReservedBytes: Int

  private var reservedBytes = 0
  private var peakReservedBytes = 0
  private var successfulReservations: UInt64 = 0
  private var deniedReservations: UInt64 = 0
  private var releases: UInt64 = 0
  private var releaseViolations: UInt64 = 0

  public init(maximumReservedBytes: Int) throws {
    guard maximumReservedBytes > 0 else {
      throw BytePumpConfigurationError.nonPositive(.maximumAggregateReservedBytes)
    }
    self.maximumReservedBytes = maximumReservedBytes
  }

  public func tryReserve(bytes: Int) -> Bool {
    guard bytes > 0 else {
      deniedReservations = Self.incremented(deniedReservations)
      return false
    }
    let (proposed, overflow) = reservedBytes.addingReportingOverflow(bytes)
    guard !overflow, proposed <= maximumReservedBytes else {
      deniedReservations = Self.incremented(deniedReservations)
      return false
    }
    reservedBytes = proposed
    peakReservedBytes = max(peakReservedBytes, proposed)
    successfulReservations = Self.incremented(successfulReservations)
    return true
  }

  public func release(bytes: Int) {
    guard bytes > 0, bytes <= reservedBytes else {
      releaseViolations = Self.incremented(releaseViolations)
      return
    }
    reservedBytes -= bytes
    releases = Self.incremented(releases)
  }

  public func snapshot() -> BytePumpBufferBudgetSnapshot {
    BytePumpBufferBudgetSnapshot(
      maximumReservedBytes: maximumReservedBytes,
      reservedBytes: reservedBytes,
      peakReservedBytes: peakReservedBytes,
      successfulReservations: successfulReservations,
      deniedReservations: deniedReservations,
      releases: releases,
      releaseViolations: releaseViolations
    )
  }

  private static func incremented(_ value: UInt64) -> UInt64 {
    value == UInt64.max ? UInt64.max : value + 1
  }
}

public enum BytePumpTerminalReason: String, CaseIterable, Hashable, Sendable {
  case eof
  case cancelled
  case localClosure = "local_closure"
  case remoteClosure = "remote_closure"
  case readError = "read_error"
  case writeError = "write_error"
  case zeroProgress = "zero_progress"
  case boundViolation = "bound_violation"
}

public struct BytePumpTerminalEvent: Hashable, Sendable {
  public let direction: BytePumpDirection
  public let reason: BytePumpTerminalReason

  public init(direction: BytePumpDirection, reason: BytePumpTerminalReason) {
    self.direction = direction
    self.reason = reason
  }
}

public struct BoundedFullDuplexBytePumpOutcome: Equatable, Sendable {
  public let localToSSH: BytePumpTerminalEvent
  public let sshToLocal: BytePumpTerminalEvent

  public init(
    localToSSH: BytePumpTerminalEvent,
    sshToLocal: BytePumpTerminalEvent
  ) {
    self.localToSSH = localToSSH
    self.sshToLocal = sshToLocal
  }
}

public enum BytePumpOperation: String, Equatable, Sendable {
  case read
  case write
  case readinessWait = "readiness_wait"
}

/// Finite, aggregate-safe observations. No case can carry endpoints, payload,
/// hashes, credentials, channel identity, flow identity, or free-form errors.
public enum BytePumpDiagnosticUpdate: Equatable, Sendable {
  case operation(direction: BytePumpDirection, operation: BytePumpOperation)
  case bytes(direction: BytePumpDirection, count: Int)
  case fairnessYield(direction: BytePumpDirection)
  case pressure(direction: BytePumpDirection, readiness: LocalByteStreamReadiness)
  case bufferedBytes(direction: BytePumpDirection, count: Int)
  case aggregateReservedBytes(Int)
  case terminal(BytePumpTerminalEvent)
}

public protocol BytePumpDiagnosticsSink: AnyObject, Sendable {
  /// Must return promptly; updates are already finite and bounded by pump work.
  func record(_ update: BytePumpDiagnosticUpdate)
}

public final class NoOpBytePumpDiagnosticsSink: BytePumpDiagnosticsSink, @unchecked Sendable {
  public init() {}

  public func record(_ update: BytePumpDiagnosticUpdate) {}
}

public protocol BytePumpTerminalEventSink: Sendable {
  /// Receives at most one terminal event per direction for a pump run.
  func receive(_ event: BytePumpTerminalEvent) async
}

public struct NoOpBytePumpTerminalEventSink: BytePumpTerminalEventSink {
  public init() {}

  public func receive(_ event: BytePumpTerminalEvent) async {}
}

public enum BoundedFullDuplexBytePumpRunError: Error, Equatable, Sendable {
  case alreadyRunning
  case alreadyTerminated
}

/// One-shot structured owner of two independent bounded byte pumps.
///
/// EOF and failure policy deliberately remain outside this type. A direction
/// reports its typed terminal event while its sibling continues until the
/// lifecycle owner cancels it or it reaches its own terminal event.
public actor BoundedFullDuplexBytePump {
  private enum State {
    case idle
    case running
    case terminated
  }

  private let local: any LocalNonblockingByteStream
  private let channel: any SSHByteChannel
  private let configuration: BoundedFullDuplexBytePumpConfiguration
  private let bufferBudget: BytePumpBufferBudget
  private let scheduler: any BytePumpScheduler
  private let eventSink: any BytePumpTerminalEventSink
  private let diagnostics: any BytePumpDiagnosticsSink
  private let control = BytePumpControl()
  private var state = State.idle

  public init(
    local: any LocalNonblockingByteStream,
    channel: any SSHByteChannel,
    configuration: BoundedFullDuplexBytePumpConfiguration,
    bufferBudget: BytePumpBufferBudget,
    scheduler: any BytePumpScheduler = TaskBytePumpScheduler(),
    eventSink: any BytePumpTerminalEventSink = NoOpBytePumpTerminalEventSink(),
    diagnostics: any BytePumpDiagnosticsSink = NoOpBytePumpDiagnosticsSink()
  ) throws {
    guard configuration.maximumAggregateReservedBytes == bufferBudget.maximumReservedBytes else {
      throw BytePumpConfigurationError.aggregateBudgetMismatch(
        configuration: configuration.maximumAggregateReservedBytes,
        budget: bufferBudget.maximumReservedBytes
      )
    }
    self.local = local
    self.channel = channel
    self.configuration = configuration
    self.bufferBudget = bufferBudget
    self.scheduler = scheduler
    self.eventSink = eventSink
    self.diagnostics = diagnostics
  }

  public func run() async throws -> BoundedFullDuplexBytePumpOutcome {
    switch state {
    case .idle:
      state = .running
    case .running:
      throw BoundedFullDuplexBytePumpRunError.alreadyRunning
    case .terminated:
      throw BoundedFullDuplexBytePumpRunError.alreadyTerminated
    }

    let reservedBytes = configuration.perFlowReservedBufferBytes
    guard !control.isCancellationRequested else {
      let outcome = cancellationOutcome()
      await publish(outcome)
      state = .terminated
      return outcome
    }
    guard await bufferBudget.tryReserve(bytes: reservedBytes) else {
      let outcome = boundViolationOutcome()
      await publish(outcome)
      state = .terminated
      return outcome
    }
    diagnostics.record(.aggregateReservedBytes((await bufferBudget.snapshot()).reservedBytes))

    let local = self.local
    let channel = self.channel
    let configuration = self.configuration
    let scheduler = self.scheduler
    let eventSink = self.eventSink
    let diagnostics = self.diagnostics
    let control = self.control

    let outcome = await withTaskCancellationHandler {
      await Self.runStructuredPumps(
        local: local,
        channel: channel,
        configuration: configuration,
        scheduler: scheduler,
        eventSink: eventSink,
        diagnostics: diagnostics,
        control: control
      )
    } onCancel: {
      if control.requestCancellation() {
        local.cancelPendingOperations()
      }
    }

    await bufferBudget.release(bytes: reservedBytes)
    diagnostics.record(.aggregateReservedBytes((await bufferBudget.snapshot()).reservedBytes))
    state = .terminated
    return outcome
  }

  public func cancel() {
    guard state != .terminated else { return }
    if control.requestCancellation() {
      local.cancelPendingOperations()
    }
  }

  private func cancellationOutcome() -> BoundedFullDuplexBytePumpOutcome {
    BoundedFullDuplexBytePumpOutcome(
      localToSSH: BytePumpTerminalEvent(direction: .localToSSH, reason: .cancelled),
      sshToLocal: BytePumpTerminalEvent(direction: .sshToLocal, reason: .cancelled)
    )
  }

  private func boundViolationOutcome() -> BoundedFullDuplexBytePumpOutcome {
    BoundedFullDuplexBytePumpOutcome(
      localToSSH: BytePumpTerminalEvent(direction: .localToSSH, reason: .boundViolation),
      sshToLocal: BytePumpTerminalEvent(direction: .sshToLocal, reason: .boundViolation)
    )
  }

  private func publish(_ outcome: BoundedFullDuplexBytePumpOutcome) async {
    diagnostics.record(.terminal(outcome.localToSSH))
    await eventSink.receive(outcome.localToSSH)
    diagnostics.record(.terminal(outcome.sshToLocal))
    await eventSink.receive(outcome.sshToLocal)
  }

  private static func runStructuredPumps(
    local: any LocalNonblockingByteStream,
    channel: any SSHByteChannel,
    configuration: BoundedFullDuplexBytePumpConfiguration,
    scheduler: any BytePumpScheduler,
    eventSink: any BytePumpTerminalEventSink,
    diagnostics: any BytePumpDiagnosticsSink,
    control: BytePumpControl
  ) async -> BoundedFullDuplexBytePumpOutcome {
    await withTaskGroup(of: BytePumpChildResult.self) { group in
      group.addTask {
        .terminal(
          await pumpLocalToSSH(
            local: local,
            channel: channel,
            configuration: configuration,
            scheduler: scheduler,
            diagnostics: diagnostics,
            control: control
          ))
      }
      group.addTask {
        .terminal(
          await pumpSSHToLocal(
            local: local,
            channel: channel,
            configuration: configuration,
            scheduler: scheduler,
            diagnostics: diagnostics,
            control: control
          ))
      }
      group.addTask {
        .control(await control.wait())
      }

      var localToSSH: BytePumpTerminalEvent?
      var sshToLocal: BytePumpTerminalEvent?
      var cancellationHandled = false

      for await result in group {
        switch result {
        case .terminal(let event):
          switch event.direction {
          case .localToSSH:
            localToSSH = event
          case .sshToLocal:
            sshToLocal = event
          }
          diagnostics.record(.terminal(event))
          await eventSink.receive(event)
          if localToSSH != nil, sshToLocal != nil {
            control.requestFinished()
          }
        case .control(.cancellation):
          if !cancellationHandled {
            cancellationHandled = true
            group.cancelAll()
            await channel.cancel()
          }
        case .control(.finished):
          break
        }
      }

      return BoundedFullDuplexBytePumpOutcome(
        localToSSH: localToSSH
          ?? BytePumpTerminalEvent(direction: .localToSSH, reason: .cancelled),
        sshToLocal: sshToLocal
          ?? BytePumpTerminalEvent(direction: .sshToLocal, reason: .cancelled)
      )
    }
  }

  private static func pumpLocalToSSH(
    local: any LocalNonblockingByteStream,
    channel: any SSHByteChannel,
    configuration: BoundedFullDuplexBytePumpConfiguration,
    scheduler: any BytePumpScheduler,
    diagnostics: any BytePumpDiagnosticsSink,
    control: BytePumpControl
  ) async -> BytePumpTerminalEvent {
    let direction = BytePumpDirection.localToSSH
    var fairness = BytePumpFairnessSlice(configuration: configuration)
    var buffer: Data?
    var offset = 0
    var retryAfterReadiness = false
    var readinessWakeupsWithoutProgress = 0
    var failureFallback = BytePumpTerminalReason.readError

    let reason: BytePumpTerminalReason
    do {
      pumpLoop: while true {
        try checkCancellation(control)

        if buffer == nil {
          failureFallback = .readError
          let readLimit = try await fairness.beginOperation(
            maximumTransferBytes: configuration.localReadChunkBytes,
            direction: direction,
            scheduler: scheduler,
            diagnostics: diagnostics,
            control: control
          )
          diagnostics.record(.operation(direction: direction, operation: .read))
          let result = try await local.readSome(maximumBytes: readLimit)
          try checkCancellation(control)
          switch result {
          case .bytes(let bytes):
            guard !bytes.isEmpty else {
              reason = .zeroProgress
              break pumpLoop
            }
            guard bytes.count <= readLimit else {
              reason = .boundViolation
              break pumpLoop
            }
            fairness.recordTransferred(bytes.count)
            buffer = bytes
            offset = 0
            retryAfterReadiness = false
            readinessWakeupsWithoutProgress = 0
            diagnostics.record(.bufferedBytes(direction: direction, count: bytes.count))
          case .endOfStream:
            reason = .eof
            break pumpLoop
          case .wouldBlock:
            if retryAfterReadiness {
              readinessWakeupsWithoutProgress += 1
              guard
                readinessWakeupsWithoutProgress
                  < configuration.maximumConsecutiveReadinessWakeupsWithoutProgress
              else {
                reason = .zeroProgress
                break pumpLoop
              }
            }
            diagnostics.record(.pressure(direction: direction, readiness: .readable))
            _ = try await fairness.beginOperation(
              maximumTransferBytes: nil,
              direction: direction,
              scheduler: scheduler,
              diagnostics: diagnostics,
              control: control
            )
            diagnostics.record(.operation(direction: direction, operation: .readinessWait))
            let readiness = try await local.waitForReadiness(.readable)
            try checkCancellation(control)
            guard readiness == .ready else {
              reason = .localClosure
              break pumpLoop
            }
            retryAfterReadiness = true
          }
          continue
        }

        guard let ownedBuffer = buffer else {
          preconditionFailure("Local-to-SSH pump lost its owned buffer")
        }
        let remaining = ownedBuffer.count - offset
        let callMaximum = min(remaining, configuration.maximumSSHWriteCallBytes)
        failureFallback = .writeError
        let writeLimit = try await fairness.beginOperation(
          maximumTransferBytes: callMaximum,
          direction: direction,
          scheduler: scheduler,
          diagnostics: diagnostics,
          control: control
        )
        diagnostics.record(.operation(direction: direction, operation: .write))
        let writeStart = ownedBuffer.index(ownedBuffer.startIndex, offsetBy: offset)
        let writeEnd = ownedBuffer.index(writeStart, offsetBy: writeLimit)
        let suffix = ownedBuffer[writeStart..<writeEnd]
        let accepted = try await channel.writeSome(suffix)
        try checkCancellation(control)
        guard accepted > 0 else {
          reason = .zeroProgress
          break pumpLoop
        }
        guard accepted <= writeLimit else {
          reason = .boundViolation
          break pumpLoop
        }
        offset += accepted
        fairness.recordTransferred(accepted)
        diagnostics.record(.bytes(direction: direction, count: accepted))
        diagnostics.record(
          .bufferedBytes(direction: direction, count: ownedBuffer.count - offset))
        if offset == ownedBuffer.count {
          selfDiscard(&buffer, offset: &offset)
        }
      }
    } catch {
      reason = terminalReason(
        for: error,
        fallback: failureFallback,
        control: control
      )
    }

    selfDiscard(&buffer, offset: &offset)
    diagnostics.record(.bufferedBytes(direction: direction, count: 0))
    return BytePumpTerminalEvent(direction: direction, reason: reason)
  }

  private static func pumpSSHToLocal(
    local: any LocalNonblockingByteStream,
    channel: any SSHByteChannel,
    configuration: BoundedFullDuplexBytePumpConfiguration,
    scheduler: any BytePumpScheduler,
    diagnostics: any BytePumpDiagnosticsSink,
    control: BytePumpControl
  ) async -> BytePumpTerminalEvent {
    let direction = BytePumpDirection.sshToLocal
    var fairness = BytePumpFairnessSlice(configuration: configuration)
    var buffer: Data?
    var offset = 0
    var retryAfterReadiness = false
    var readinessWakeupsWithoutProgress = 0
    var failureFallback = BytePumpTerminalReason.readError

    let reason: BytePumpTerminalReason
    do {
      pumpLoop: while true {
        try checkCancellation(control)

        if buffer == nil {
          failureFallback = .readError
          let readLimit = try await fairness.beginOperation(
            maximumTransferBytes: configuration.remoteReadChunkBytes,
            direction: direction,
            scheduler: scheduler,
            diagnostics: diagnostics,
            control: control
          )
          diagnostics.record(.operation(direction: direction, operation: .read))
          let bytes = try await channel.read(maximumBytes: readLimit)
          try checkCancellation(control)
          guard let bytes else {
            reason = .eof
            break pumpLoop
          }
          guard !bytes.isEmpty else {
            reason = .zeroProgress
            break pumpLoop
          }
          guard bytes.count <= readLimit else {
            reason = .boundViolation
            break pumpLoop
          }
          fairness.recordTransferred(bytes.count)
          buffer = bytes
          offset = 0
          diagnostics.record(.bufferedBytes(direction: direction, count: bytes.count))
          continue
        }

        guard let ownedBuffer = buffer else {
          preconditionFailure("SSH-to-local pump lost its owned buffer")
        }
        let remaining = ownedBuffer.count - offset
        failureFallback = .writeError
        let writeLimit = try await fairness.beginOperation(
          maximumTransferBytes: remaining,
          direction: direction,
          scheduler: scheduler,
          diagnostics: diagnostics,
          control: control
        )
        diagnostics.record(.operation(direction: direction, operation: .write))
        let writeStart = ownedBuffer.index(ownedBuffer.startIndex, offsetBy: offset)
        let writeEnd = ownedBuffer.index(writeStart, offsetBy: writeLimit)
        let suffix = ownedBuffer[writeStart..<writeEnd]
        let result = try await local.writeSome(suffix)
        try checkCancellation(control)
        switch result {
        case .written(let count):
          guard count > 0 else {
            reason = .localClosure
            break pumpLoop
          }
          guard count <= writeLimit else {
            reason = .boundViolation
            break pumpLoop
          }
          offset += count
          fairness.recordTransferred(count)
          diagnostics.record(.bytes(direction: direction, count: count))
          diagnostics.record(
            .bufferedBytes(direction: direction, count: ownedBuffer.count - offset))
          retryAfterReadiness = false
          readinessWakeupsWithoutProgress = 0
          if offset == ownedBuffer.count {
            selfDiscard(&buffer, offset: &offset)
          }
        case .peerClosed:
          reason = .localClosure
          break pumpLoop
        case .wouldBlock:
          if retryAfterReadiness {
            readinessWakeupsWithoutProgress += 1
            guard
              readinessWakeupsWithoutProgress
                < configuration.maximumConsecutiveReadinessWakeupsWithoutProgress
            else {
              reason = .zeroProgress
              break pumpLoop
            }
          }
          diagnostics.record(.pressure(direction: direction, readiness: .writable))
          _ = try await fairness.beginOperation(
            maximumTransferBytes: nil,
            direction: direction,
            scheduler: scheduler,
            diagnostics: diagnostics,
            control: control
          )
          diagnostics.record(.operation(direction: direction, operation: .readinessWait))
          let readiness = try await local.waitForReadiness(.writable)
          try checkCancellation(control)
          guard readiness == .ready else {
            reason = .localClosure
            break pumpLoop
          }
          retryAfterReadiness = true
        }
      }
    } catch {
      reason = terminalReason(
        for: error,
        fallback: failureFallback,
        control: control
      )
    }

    selfDiscard(&buffer, offset: &offset)
    diagnostics.record(.bufferedBytes(direction: direction, count: 0))
    return BytePumpTerminalEvent(direction: direction, reason: reason)
  }

  private static func checkCancellation(_ control: BytePumpControl) throws {
    if control.isCancellationRequested || Task<Never, Never>.isCancelled {
      throw CancellationError()
    }
  }

  private static func terminalReason(
    for error: any Error,
    fallback: BytePumpTerminalReason,
    control: BytePumpControl
  ) -> BytePumpTerminalReason {
    if control.isCancellationRequested || error is CancellationError {
      return .cancelled
    }
    guard let sshError = error as? SSHTransportError else {
      return fallback
    }
    switch sshError.code {
    case .cancelled:
      return .cancelled
    case .connectionLost, .connectionClosed, .channelClosed, .peerReset, .channelReset:
      return .remoteClosure
    default:
      return fallback
    }
  }

  private static func selfDiscard(_ buffer: inout Data?, offset: inout Int) {
    buffer = nil
    offset = 0
  }
}

private struct BytePumpFairnessSlice {
  private let maximumOperations: Int
  private let maximumBytes: Int
  private var operations = 0
  private var bytes = 0

  init(configuration: BoundedFullDuplexBytePumpConfiguration) {
    maximumOperations = configuration.fairnessMaximumOperations
    maximumBytes = configuration.fairnessMaximumBytes
  }

  mutating func beginOperation(
    maximumTransferBytes: Int?,
    direction: BytePumpDirection,
    scheduler: any BytePumpScheduler,
    diagnostics: any BytePumpDiagnosticsSink,
    control: BytePumpControl
  ) async throws -> Int {
    if operations >= maximumOperations || bytes >= maximumBytes {
      diagnostics.record(.fairnessYield(direction: direction))
      try await scheduler.yield()
      if control.isCancellationRequested || Task<Never, Never>.isCancelled {
        throw CancellationError()
      }
      operations = 0
      bytes = 0
    }
    operations += 1
    guard let maximumTransferBytes else { return 0 }
    return min(maximumTransferBytes, maximumBytes - bytes)
  }

  mutating func recordTransferred(_ count: Int) {
    bytes += count
  }
}

private enum BytePumpControlEvent: Sendable {
  case cancellation
  case finished
}

private enum BytePumpChildResult: Sendable {
  case terminal(BytePumpTerminalEvent)
  case control(BytePumpControlEvent)
}

private final class BytePumpControl: @unchecked Sendable {
  private let lock = NSLock()
  private var event: BytePumpControlEvent?
  private var waiter: CheckedContinuation<BytePumpControlEvent, Never>?

  var isCancellationRequested: Bool {
    lock.withLock {
      if case .cancellation = event {
        return true
      }
      return false
    }
  }

  @discardableResult
  func requestCancellation() -> Bool {
    finish(with: .cancellation)
  }

  func requestFinished() {
    _ = finish(with: .finished)
  }

  func wait() async -> BytePumpControlEvent {
    await withCheckedContinuation { continuation in
      lock.lock()
      if let event {
        lock.unlock()
        continuation.resume(returning: event)
      } else {
        waiter = continuation
        lock.unlock()
      }
    }
  }

  private func finish(with event: BytePumpControlEvent) -> Bool {
    lock.lock()
    guard self.event == nil else {
      lock.unlock()
      return false
    }
    self.event = event
    let waiter = waiter
    self.waiter = nil
    lock.unlock()
    waiter?.resume(returning: event)
    return true
  }
}
