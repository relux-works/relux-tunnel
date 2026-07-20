import Foundation

public enum PacketBridgeDirection: String, Equatable, Sendable {
  case forward
  case reverse
}

public enum PacketBridgeOperation: String, Equatable, Sendable {
  case socketPair
  case getDescriptorFlags
  case setDescriptorFlags
  case getStatusFlags
  case setStatusFlags
  case setSendBuffer
  case setReceiveBuffer
  case getSendBuffer
  case getReceiveBuffer
  case installReadiness
  case send
  case receive
  case readiness
  case descriptorBorrow
  case packetFlowRead
  case packetFlowWrite
  case close
}

public enum PacketFlowBridgeError: Error, Equatable, Sendable {
  case alreadyActive
  case invalidConfiguration(field: String)
  case startInterrupted
  case socketError(operation: PacketBridgeOperation, errno: Int32)
  case readinessFailure
  case descriptorBorrowFailure
  case messageTooLarge(
    direction: PacketBridgeDirection,
    datagramBytes: Int,
    configuredMaximumBytes: Int
  )
  case peerEOF(operation: PacketBridgeOperation)
  case packetFlowFailure(operation: PacketBridgeOperation)
  case shortDatagramSend(expectedBytes: Int, actualBytes: Int)
}

public struct PacketBridgeSocketPair: Equatable, Sendable {
  public let bridgeDescriptor: Int32
  public let hevDescriptor: Int32

  public init(bridgeDescriptor: Int32, hevDescriptor: Int32) {
    self.bridgeDescriptor = bridgeDescriptor
    self.hevDescriptor = hevDescriptor
  }
}

public enum PacketBridgeSocketBuffer: Equatable, Sendable {
  case send
  case receive
}

public struct PacketBridgeReceiveResult: Equatable, Sendable {
  public let copiedBytes: Int
  public let fullDatagramBytes: Int
  public let wasTruncated: Bool

  public init(copiedBytes: Int, fullDatagramBytes: Int, wasTruncated: Bool) {
    self.copiedBytes = copiedBytes
    self.fullDatagramBytes = fullDatagramBytes
    self.wasTruncated = wasTruncated
  }
}

/// Injectable system-call boundary. Byte buffers are borrowed only for the
/// duration of each synchronous call and are never retained by implementations.
public protocol PacketBridgeSocketIO: Sendable {
  func makeDatagramSocketPair() throws -> PacketBridgeSocketPair
  func descriptorFlags(for descriptor: Int32) throws -> Int32
  func setDescriptorFlags(_ flags: Int32, for descriptor: Int32) throws
  func statusFlags(for descriptor: Int32) throws -> Int32
  func setStatusFlags(_ flags: Int32, for descriptor: Int32) throws
  func setSocketBuffer(
    _ buffer: PacketBridgeSocketBuffer,
    bytes: Int32,
    for descriptor: Int32
  ) throws
  func socketBuffer(
    _ buffer: PacketBridgeSocketBuffer,
    for descriptor: Int32
  ) throws -> Int32
  func sendDatagram(
    on descriptor: Int32,
    bytes: UnsafeRawBufferPointer
  ) throws -> Int
  func receiveDatagram(
    on descriptor: Int32,
    into bytes: UnsafeMutableRawBufferPointer
  ) throws -> PacketBridgeReceiveResult
  func closeDescriptor(_ descriptor: Int32) throws
}

public enum PacketBridgeReadinessEvent: Sendable {
  case readable
  case peerClosed
}

public protocol PacketBridgeReadinessSource: AnyObject, Sendable {
  func waitForEvent() async throws -> PacketBridgeReadinessEvent
  func cancel() async
}

public protocol PacketBridgeReadinessFactory: Sendable {
  func makeReadinessSource(
    descriptor: Int32
  ) throws -> any PacketBridgeReadinessSource
}

/// Endpoint B is an exclusive scoped borrow. Implementations must not close,
/// duplicate, reopen, or transfer the descriptor.
public protocol DescriptorBorrowHandle: AnyObject, Sendable {
  func requestStop() async
  func waitForReturn() async
}

public protocol DescriptorBorrowConsumer: Sendable {
  func beginBorrowing(
    _ descriptor: Int32
  ) async throws -> any DescriptorBorrowHandle
}

public protocol PacketBridgeScheduler: Sendable {
  func yield() async
}

public struct TaskPacketBridgeScheduler: PacketBridgeScheduler {
  public init() {}

  public func yield() async {
    await Task.yield()
  }
}

public protocol PacketBridgeRunIDSource: Sendable {
  func nextRunID() -> String
}

public struct UUIDPacketBridgeRunIDSource: PacketBridgeRunIDSource {
  public init() {}

  public func nextRunID() -> String {
    UUID().uuidString
  }
}

public enum PacketBridgeLifecycleStage: String, Sendable {
  case configurationValidated
  case socketPairCreated
  case descriptorsConfigured
  case readinessInstalled
  case borrowAccepted
  case supervisorInstalled
  case running
  case packetReadsStopped
  case readinessCancelled
  case pumpsJoined
  case borrowStopRequested
  case borrowReturned
  case hevDescriptorClosed
  case bridgeDescriptorClosed
}

public protocol PacketBridgeLifecycleBarrier: Sendable {
  func reach(_ stage: PacketBridgeLifecycleStage) async throws
}

public struct NoOpPacketBridgeLifecycleBarrier: PacketBridgeLifecycleBarrier {
  public init() {}

  public func reach(_ stage: PacketBridgeLifecycleStage) async throws {}
}

public enum PacketBridgeMetricUnit: String, Sendable {
  case packets
  case bytes
  case datagrams
  case batches
  case events
  case runs
}

public enum PacketBridgeMetricSchema {
  public static let version: UInt16 = 1

  public static let counters: [String: PacketBridgeMetricUnit] = [
    "packet_bridge_forward_packets_received_total": .packets,
    "packet_bridge_forward_payload_bytes_received_total": .bytes,
    "packet_bridge_forward_datagrams_sent_total": .datagrams,
    "packet_bridge_forward_datagram_bytes_sent_total": .bytes,
    "packet_bridge_reverse_datagrams_received_total": .datagrams,
    "packet_bridge_reverse_datagram_bytes_received_total": .bytes,
    "packet_bridge_reverse_packets_written_total": .packets,
    "packet_bridge_reverse_payload_bytes_written_total": .bytes,
    "packet_bridge_reverse_batches_written_total": .batches,
    "packet_bridge_forward_budget_count_yield_total": .events,
    "packet_bridge_forward_budget_time_yield_total": .events,
    "packet_bridge_reverse_budget_count_yield_total": .events,
    "packet_bridge_reverse_budget_time_yield_total": .events,
    "packet_bridge_forward_drop_malformed_total": .packets,
    "packet_bridge_reverse_drop_malformed_total": .datagrams,
    "packet_bridge_forward_drop_would_block_total": .packets,
    "packet_bridge_reverse_drain_would_block_total": .events,
    "packet_bridge_forward_drop_no_buffer_total": .packets,
    "packet_bridge_reverse_receive_no_buffer_total": .events,
    "packet_bridge_fatal_message_too_large_total": .events,
    "packet_bridge_fatal_peer_eof_total": .events,
    "packet_bridge_fatal_socket_error_total": .events,
    "packet_bridge_fatal_packet_flow_error_total": .events,
    "packet_bridge_reverse_drop_write_rejected_packets_total": .packets,
    "packet_bridge_cleanup_close_error_total": .events,
    "packet_bridge_cancellation_total": .events,
    "packet_bridge_startup_failure_total": .runs,
    "packet_bridge_terminal_failure_total": .runs,
    "packet_bridge_start_total": .runs,
    "packet_bridge_stop_total": .runs,
  ]

  public static let gauges: [String: PacketBridgeMetricUnit] = [
    "packet_bridge_forward_datagram_max_bytes": .bytes,
    "packet_bridge_reverse_datagram_max_bytes": .bytes,
    "packet_bridge_socket_a_send_buffer_requested_bytes": .bytes,
    "packet_bridge_socket_a_send_buffer_effective_bytes": .bytes,
    "packet_bridge_socket_a_receive_buffer_requested_bytes": .bytes,
    "packet_bridge_socket_a_receive_buffer_effective_bytes": .bytes,
    "packet_bridge_socket_b_send_buffer_requested_bytes": .bytes,
    "packet_bridge_socket_b_send_buffer_effective_bytes": .bytes,
    "packet_bridge_socket_b_receive_buffer_requested_bytes": .bytes,
    "packet_bridge_socket_b_receive_buffer_effective_bytes": .bytes,
    "packet_bridge_configured_mtu_bytes": .bytes,
    "packet_bridge_configured_max_datagram_bytes": .bytes,
  ]
}

public struct PacketFlowBridgeRunHandle: Sendable {
  let completion: PacketBridgeRunCompletion

  public func waitForTermination() async throws {
    try await completion.wait()
  }
}

public enum PacketFlowBridgeLifecycleState: Equatable, Sendable {
  case idle
  case starting(runID: String)
  case running(runID: String)
  case stopping(runID: String)
  case failing(runID: String, error: PacketFlowBridgeError)
  case stopped(lastRunID: String)
  case failed(runID: String, error: PacketFlowBridgeError)
}

final class PacketBridgeRunCompletion: @unchecked Sendable {
  private let lock = NSLock()
  private var result: Result<Void, PacketFlowBridgeError>?
  private var waiters: [CheckedContinuation<Result<Void, PacketFlowBridgeError>, Never>] = []

  func wait() async throws {
    let result: Result<Void, PacketFlowBridgeError> = await withCheckedContinuation {
      (continuation: CheckedContinuation<Result<Void, PacketFlowBridgeError>, Never>) in
      lock.lock()
      if let finished = self.result {
        lock.unlock()
        continuation.resume(returning: finished)
      } else {
        waiters.append(continuation)
        lock.unlock()
      }
    }
    try result.get()
  }

  func finish(_ result: Result<Void, PacketFlowBridgeError>) {
    lock.lock()
    guard self.result == nil else {
      lock.unlock()
      return
    }
    self.result = result
    let waiters = self.waiters
    self.waiters.removeAll()
    lock.unlock()
    for waiter in waiters {
      waiter.resume(returning: result)
    }
  }
}
