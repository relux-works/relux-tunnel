import Darwin
import Foundation

/// Shared cancellation and batch-validation boundary for platform packet flows.
///
/// A committed callback registration remains represented by a tombstone after
/// cancellation or shutdown until its callback arrives. This preserves the
/// one-outstanding-read invariant even though `NEPacketTunnelFlow` does not
/// expose callback deregistration.
public final class PacketFlowAdapterBoundary: @unchecked Sendable {
  private final class ReadToken: @unchecked Sendable {
    var isCancelled = false
  }

  private struct CurrentRead {
    let token: ReadToken
    var continuation: CheckedContinuation<PacketReadBatch, Error>?
    var registrationCommitted: Bool
  }

  private let driver: any PacketFlowPlatformDriver
  private let lock = NSLock()
  private var isShutDown = false
  private var currentRead: CurrentRead?

  public init(driver: any PacketFlowPlatformDriver) {
    self.driver = driver
  }

  deinit {
    shutDown()
  }

  public func readPackets() async throws -> PacketReadBatch {
    let token = ReadToken()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        beginRead(token: token, continuation: continuation)
      }
    } onCancel: {
      cancelRead(token: token)
    }
  }

  public func writePackets(_ packets: [TunnelPacket]) throws {
    let payloads = packets.map(\.payload)
    let protocols = packets.map { packet in
      switch packet.addressFamily {
      case .ipv4:
        AF_INET
      case .ipv6:
        AF_INET6
      }
    }
    guard driver.writePackets(payloads, protocols: protocols) else {
      throw PacketFlowError.writeRejected
    }
  }

  public func shutDown() {
    let continuation: CheckedContinuation<PacketReadBatch, Error>?

    lock.lock()
    isShutDown = true
    continuation = currentRead?.continuation
    currentRead?.continuation = nil
    if currentRead?.registrationCommitted == false {
      currentRead = nil
    }
    lock.unlock()

    continuation?.resume(throwing: PacketFlowError.adapterShutDown)
  }

  private func beginRead(
    token: ReadToken,
    continuation: CheckedContinuation<PacketReadBatch, Error>
  ) {
    let immediateError: (any Error)?

    lock.lock()
    if token.isCancelled {
      immediateError = CancellationError()
    } else if isShutDown {
      immediateError = PacketFlowError.adapterShutDown
    } else if currentRead != nil {
      immediateError = PacketFlowError.readAlreadyPending
    } else {
      currentRead = CurrentRead(
        token: token,
        continuation: continuation,
        registrationCommitted: false
      )
      immediateError = nil
    }
    lock.unlock()

    if let immediateError {
      continuation.resume(throwing: immediateError)
      return
    }

    guard commitRegistration(for: token) else {
      return
    }
    driver.registerRead { [weak self, token] packets, protocols in
      self?.receiveCallback(
        token: token,
        packets: packets,
        protocols: protocols
      )
    }
  }

  /// Commits immediately before invoking the platform registration API.
  /// Cancellation or shutdown that wins before this point prevents the read.
  private func commitRegistration(for token: ReadToken) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard var currentRead, currentRead.token === token else {
      return false
    }
    currentRead.registrationCommitted = true
    self.currentRead = currentRead
    return true
  }

  private func cancelRead(token: ReadToken) {
    let continuation: CheckedContinuation<PacketReadBatch, Error>?

    lock.lock()
    token.isCancelled = true
    if currentRead?.token === token {
      continuation = currentRead?.continuation
      currentRead?.continuation = nil
      if currentRead?.registrationCommitted == false {
        currentRead = nil
      }
    } else {
      continuation = nil
    }
    lock.unlock()

    continuation?.resume(throwing: CancellationError())
  }

  private func receiveCallback(
    token: ReadToken,
    packets: [Data],
    protocols: [Int32]
  ) {
    let continuation: CheckedContinuation<PacketReadBatch, Error>?

    lock.lock()
    if currentRead?.token === token {
      continuation = currentRead?.continuation
      currentRead?.continuation = nil
      if continuation == nil {
        currentRead = nil
      }
    } else {
      continuation = nil
    }
    lock.unlock()

    // A cancellation/shutdown winner leaves no continuation. Do not inspect
    // the late callback's payloads and never schedule a replacement read.
    guard let continuation else {
      return
    }

    let result: Result<PacketReadBatch, Error>
    guard packets.count == protocols.count else {
      result = .failure(
        PacketFlowError.packetProtocolCardinalityMismatch(
          packetCount: packets.count,
          protocolCount: protocols.count
        )
      )
      finishCallback(token: token, continuation: continuation, result: result)
      return
    }

    result = .success(
      PacketReadBatch(
        results: packets.indices.map { index in
          inspect(packet: packets[index], protocolNumber: protocols[index])
        }
      )
    )
    finishCallback(token: token, continuation: continuation, result: result)
  }

  private func finishCallback(
    token: ReadToken,
    continuation: CheckedContinuation<PacketReadBatch, Error>,
    result: Result<PacketReadBatch, Error>
  ) {
    lock.lock()
    if currentRead?.token === token {
      currentRead = nil
    }
    lock.unlock()

    continuation.resume(with: result)
  }

  private func inspect(packet: Data, protocolNumber: Int32) -> PacketReadResult {
    let expectedFamily: PacketAddressFamily
    switch protocolNumber {
    case AF_INET:
      expectedFamily = .ipv4
    case AF_INET6:
      expectedFamily = .ipv6
    default:
      return .malformed(.unsupportedAddressFamily(protocolNumber))
    }

    guard let firstByte = packet.first else {
      return .malformed(.emptyPayload(expectedFamily: expectedFamily))
    }

    let actualVersion = firstByte >> 4
    let expectedVersion: UInt8 = expectedFamily == .ipv4 ? 4 : 6
    guard actualVersion == expectedVersion else {
      return .malformed(
        .payloadVersionMismatch(
          expectedFamily: expectedFamily,
          actualVersion: actualVersion
        )
      )
    }

    return .packet(
      TunnelPacket(payload: packet, addressFamily: expectedFamily)
    )
  }
}
