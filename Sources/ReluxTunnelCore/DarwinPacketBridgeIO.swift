import Darwin
import Dispatch
import Foundation

public struct DarwinPacketBridgeSocketIO: PacketBridgeSocketIO {
  public init() {}

  public func makeDatagramSocketPair() throws -> PacketBridgeSocketPair {
    var descriptors: [Int32] = [-1, -1]
    guard socketpair(AF_UNIX, SOCK_DGRAM, 0, &descriptors) == 0 else {
      throw socketFailure(.socketPair)
    }
    return PacketBridgeSocketPair(
      bridgeDescriptor: descriptors[0],
      hevDescriptor: descriptors[1]
    )
  }

  public func descriptorFlags(for descriptor: Int32) throws -> Int32 {
    let result = fcntl(descriptor, F_GETFD)
    guard result >= 0 else {
      throw socketFailure(.getDescriptorFlags)
    }
    return result
  }

  public func setDescriptorFlags(_ flags: Int32, for descriptor: Int32) throws {
    guard fcntl(descriptor, F_SETFD, flags) == 0 else {
      throw socketFailure(.setDescriptorFlags)
    }
  }

  public func statusFlags(for descriptor: Int32) throws -> Int32 {
    let result = fcntl(descriptor, F_GETFL)
    guard result >= 0 else {
      throw socketFailure(.getStatusFlags)
    }
    return result
  }

  public func setStatusFlags(_ flags: Int32, for descriptor: Int32) throws {
    guard fcntl(descriptor, F_SETFL, flags) == 0 else {
      throw socketFailure(.setStatusFlags)
    }
  }

  public func setSocketBuffer(
    _ buffer: PacketBridgeSocketBuffer,
    bytes: Int32,
    for descriptor: Int32
  ) throws {
    var bytes = bytes
    let option: Int32
    let operation: PacketBridgeOperation
    switch buffer {
    case .send:
      option = SO_SNDBUF
      operation = .setSendBuffer
    case .receive:
      option = SO_RCVBUF
      operation = .setReceiveBuffer
    }
    let result = withUnsafePointer(to: &bytes) { pointer in
      setsockopt(
        descriptor,
        SOL_SOCKET,
        option,
        pointer,
        socklen_t(MemoryLayout<Int32>.size)
      )
    }
    guard result == 0 else {
      throw socketFailure(operation)
    }
  }

  public func socketBuffer(
    _ buffer: PacketBridgeSocketBuffer,
    for descriptor: Int32
  ) throws -> Int32 {
    var bytes: Int32 = 0
    var length = socklen_t(MemoryLayout<Int32>.size)
    let option: Int32
    let operation: PacketBridgeOperation
    switch buffer {
    case .send:
      option = SO_SNDBUF
      operation = .getSendBuffer
    case .receive:
      option = SO_RCVBUF
      operation = .getReceiveBuffer
    }
    let result = withUnsafeMutablePointer(to: &bytes) { pointer in
      getsockopt(descriptor, SOL_SOCKET, option, pointer, &length)
    }
    guard result == 0 else {
      throw socketFailure(operation)
    }
    return bytes
  }

  public func sendDatagram(
    on descriptor: Int32,
    bytes: UnsafeRawBufferPointer
  ) throws -> Int {
    let result = Darwin.send(descriptor, bytes.baseAddress, bytes.count, 0)
    guard result >= 0 else {
      throw socketFailure(.send)
    }
    return result
  }

  public func receiveDatagram(
    on descriptor: Int32,
    into bytes: UnsafeMutableRawBufferPointer
  ) throws -> PacketBridgeReceiveResult {
    var firstPacketBytes: Int32 = 0
    var optionLength = socklen_t(MemoryLayout<Int32>.size)
    let sizeResult = withUnsafeMutablePointer(to: &firstPacketBytes) { pointer in
      getsockopt(descriptor, SOL_SOCKET, SO_NREAD, pointer, &optionLength)
    }
    guard sizeResult == 0 else {
      throw socketFailure(.receive)
    }

    var vector = iovec(iov_base: bytes.baseAddress, iov_len: bytes.count)
    var message = msghdr()
    message.msg_iovlen = 1
    let result = withUnsafeMutablePointer(to: &vector) { vectorPointer in
      message.msg_iov = vectorPointer
      return recvmsg(descriptor, &message, 0)
    }
    guard result >= 0 else {
      throw socketFailure(.receive)
    }
    let copiedBytes = Int(result)
    let fullBytes = max(copiedBytes, Int(firstPacketBytes))
    return PacketBridgeReceiveResult(
      copiedBytes: copiedBytes,
      fullDatagramBytes: fullBytes,
      wasTruncated: (message.msg_flags & MSG_TRUNC) != 0
    )
  }

  public func closeDescriptor(_ descriptor: Int32) throws {
    guard Darwin.close(descriptor) == 0 else {
      throw PacketFlowBridgeError.socketError(operation: .close, errno: errno)
    }
  }

  private func socketFailure(_ operation: PacketBridgeOperation) -> PacketFlowBridgeError {
    PacketFlowBridgeError.socketError(operation: operation, errno: errno)
  }
}

public struct DispatchPacketBridgeReadinessFactory: PacketBridgeReadinessFactory {
  public init() {}

  public func makeReadinessSource(
    descriptor: Int32
  ) throws -> any PacketBridgeReadinessSource {
    DispatchPacketBridgeReadinessSource(descriptor: descriptor)
  }
}

private final class DispatchPacketBridgeReadinessSource:
  PacketBridgeReadinessSource, @unchecked Sendable
{
  private let source: DispatchSourceRead
  private let stream: AsyncStream<PacketBridgeReadinessEvent>
  private let continuation: AsyncStream<PacketBridgeReadinessEvent>.Continuation
  private let cancellation = PacketBridgeReadinessCancellation()

  init(descriptor: Int32) {
    let stream: AsyncStream<PacketBridgeReadinessEvent>
    let continuation: AsyncStream<PacketBridgeReadinessEvent>.Continuation
    (stream, continuation) = AsyncStream.makeStream(
      of: PacketBridgeReadinessEvent.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    self.stream = stream
    self.continuation = continuation
    source = DispatchSource.makeReadSource(
      fileDescriptor: descriptor,
      queue: DispatchQueue(label: "works.relux.packet-bridge.readiness")
    )
    source.setEventHandler { [continuation] in
      continuation.yield(.readable)
    }
    source.setCancelHandler { [continuation, cancellation] in
      continuation.finish()
      cancellation.finish()
    }
    source.activate()
  }

  func waitForEvent() async throws -> PacketBridgeReadinessEvent {
    for await event in stream {
      return event
    }
    throw CancellationError()
  }

  func cancel() async {
    continuation.finish()
    source.cancel()
    await cancellation.wait()
  }
}

private final class PacketBridgeReadinessCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var isFinished = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func wait() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      lock.lock()
      if isFinished {
        lock.unlock()
        continuation.resume()
      } else {
        waiters.append(continuation)
        lock.unlock()
      }
    }
  }

  func finish() {
    lock.lock()
    guard !isFinished else {
      lock.unlock()
      return
    }
    isFinished = true
    let waiters = waiters
    self.waiters.removeAll()
    lock.unlock()
    for waiter in waiters {
      waiter.resume()
    }
  }
}
