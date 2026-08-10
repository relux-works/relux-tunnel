import Darwin
import Foundation
import ReluxLibSSH2
import ReluxTunnelCore

enum LibSSH2AdapterConstants {
  static let wouldBlock = Int(LIBSSH2_ERROR_EAGAIN)
  static let socketToken: Int32 = 0
}

/// Bounded storage used by libssh2's synchronous custom transport callbacks.
/// Async socket I/O is performed only by `service`; the callbacks never block.
final class LibSSH2NetworkBridge: @unchecked Sendable {
  private let lock = NSLock()
  private let maximumBufferedBytes: Int
  private var inbound = Data()
  private var outbound = Data()
  private var remoteEOF = false
  private var terminalFailure = false
  private var abortDrain = false
  private var bytesDeliveredToEngine: UInt64 = 0
  private var bytesAcceptedFromEngine: UInt64 = 0
  private var serviceGeneration: UInt64 = 0
  private var serviceTail: Task<Void, Error>?
  private var serviceTasks: [UInt64: Task<Void, Error>] = [:]
  private var serviceDrainWaiters: [UUID: LibSSH2BridgeOperationWaiter] = [:]

  init(maximumBufferedBytes: Int) {
    precondition(maximumBufferedBytes > 0)
    self.maximumBufferedBytes = maximumBufferedBytes
  }

  var bufferedByteCounts: (inbound: Int, outbound: Int) {
    lock.withLock { (inbound.count, outbound.count) }
  }

  var engineByteCounts: (received: UInt64, sent: UInt64) {
    lock.withLock { (bytesDeliveredToEngine, bytesAcceptedFromEngine) }
  }

  var pendingServiceCount: Int {
    lock.withLock { serviceTasks.count }
  }

  func receive(into buffer: UnsafeMutableRawPointer?, maximumLength: Int) -> Int {
    guard let buffer, maximumLength > 0 else { return 0 }
    return lock.withLock {
      if !inbound.isEmpty {
        let count = min(maximumLength, inbound.count)
        inbound.copyBytes(to: buffer.assumingMemoryBound(to: UInt8.self), count: count)
        inbound.removeFirst(count)
        bytesDeliveredToEngine += UInt64(count)
        return count
      }
      if remoteEOF || terminalFailure { return 0 }
      Darwin.errno = EAGAIN
      return -Int(EAGAIN)
    }
  }

  func send(bytes: UnsafeRawPointer?, length: Int) -> Int {
    guard let bytes, length > 0 else { return 0 }
    return lock.withLock {
      if abortDrain { return length }
      guard !terminalFailure else {
        Darwin.errno = EPIPE
        return -Int(EPIPE)
      }
      guard length <= maximumBufferedBytes - outbound.count else {
        Darwin.errno = EAGAIN
        return -Int(EAGAIN)
      }
      outbound.append(bytes.assumingMemoryBound(to: UInt8.self), count: length)
      bytesAcceptedFromEngine += UInt64(length)
      return length
    }
  }

  func service(
    connection: any SSHTCPConnection,
    interests: Set<SSHTCPReadiness>
  ) async throws {
    let queued:
      (
        generation: UInt64,
        task: Task<Void, Error>,
        completion: LibSSH2BridgeOperationWaiter
      )? = lock.withLock {
        guard !terminalFailure else { return nil }
        serviceGeneration &+= 1
        let generation = serviceGeneration
        let predecessor = serviceTail
        let completion = LibSSH2BridgeOperationWaiter()
        let task = Task {
          do {
            defer { self.finishService(generation: generation) }
            // A failed socket attempt is reported to its caller, but must not poison
            // the serialization chain for later cleanup attempts.
            _ = try? await predecessor?.value
            try Task.checkCancellation()
            try await self.serviceExclusively(connection: connection, interests: interests)
            completion.complete(with: .success(()))
          } catch {
            completion.complete(with: .failure(error))
            throw error
          }
        }
        serviceTail = task
        serviceTasks[generation] = task
        return (generation, task, completion)
      }
    guard let queued else { throw LibSSH2BridgeError.bridgeClosed }

    try await withTaskCancellationHandler {
      try await queued.completion.wait()
    } onCancel: {
      queued.task.cancel()
    }
  }

  private func serviceExclusively(
    connection: any SSHTCPConnection,
    interests: Set<SSHTCPReadiness>
  ) async throws {
    var requested = interests
    let counts = bufferedByteCounts
    if counts.outbound > 0 { requested.insert(.writable) }
    if counts.inbound < maximumBufferedBytes { requested.insert(.readable) }
    guard !requested.isEmpty else { return }

    let ready = try await connection.waitForReadiness(requested)
    guard lock.withLock({ !terminalFailure }) else { return }
    if ready.contains(.writable) {
      let bytes = lock.withLock { Data(outbound.prefix(maximumBufferedBytes)) }
      if !bytes.isEmpty {
        let written = try await connection.writeSome(bytes)
        guard written > 0, written <= bytes.count else {
          throw LibSSH2BridgeError.invalidSocketWriteCount
        }
        guard lock.withLock({ !terminalFailure }) else { return }
        lock.withLock { outbound.removeFirst(min(written, outbound.count)) }
      }
    }
    if ready.contains(.readable) {
      let capacity = lock.withLock { maximumBufferedBytes - inbound.count }
      if capacity > 0 {
        if let bytes = try await connection.readSome(maximumBytes: capacity) {
          guard bytes.count <= capacity else {
            throw LibSSH2BridgeError.socketReadExceededBound
          }
          guard lock.withLock({ !terminalFailure }) else { return }
          lock.withLock { inbound.append(bytes) }
        } else {
          guard lock.withLock({ !terminalFailure }) else { return }
          lock.withLock { remoteEOF = true }
        }
      }
    }
  }

  private func finishService(generation: UInt64) {
    let waiters: [LibSSH2BridgeOperationWaiter] = lock.withLock {
      serviceTasks.removeValue(forKey: generation)
      if generation == serviceGeneration {
        serviceTail = nil
      }
      guard serviceTasks.isEmpty else { return [] }
      defer { serviceDrainWaiters.removeAll() }
      return Array(serviceDrainWaiters.values)
    }
    for waiter in waiters { waiter.complete(with: .success(())) }
  }

  func beginShutdown() {
    lock.withLock { terminalFailure = true }
  }

  /// Completes only libssh2's retained nonblocking callback state after the
  /// real socket has failed. Bytes are discarded locally and are never
  /// reported as protected-network traffic or as a successful operation.
  func beginAbortDrain() {
    lock.withLock {
      inbound.removeAll(keepingCapacity: false)
      outbound.removeAll(keepingCapacity: false)
      remoteEOF = true
      terminalFailure = true
      abortDrain = true
    }
  }

  func drainServices(
    until deadline: ContinuousClock.Instant,
    clock: any TunnelClock
  ) async -> Bool {
    let waiter = LibSSH2BridgeOperationWaiter()
    let identifier = UUID()
    let tasks: [Task<Void, Error>] = lock.withLock {
      guard !serviceTasks.isEmpty else { return [] }
      serviceDrainWaiters[identifier] = waiter
      return Array(serviceTasks.values)
    }
    guard !tasks.isEmpty else { return true }
    for task in tasks { task.cancel() }
    let now = clock.now()
    guard now < deadline else {
      _ = lock.withLock { serviceDrainWaiters.removeValue(forKey: identifier) }
      return false
    }
    let timer = Task {
      do {
        try await clock.sleep(for: now.duration(to: deadline))
        waiter.complete(with: .failure(LibSSH2BridgeError.bridgeClosed))
      } catch {
        waiter.complete(with: .failure(error))
      }
    }
    defer {
      timer.cancel()
      _ = lock.withLock { serviceDrainWaiters.removeValue(forKey: identifier) }
    }
    do {
      try await waiter.wait()
      return true
    } catch {
      return false
    }
  }

  func discard() {
    lock.withLock {
      inbound.removeAll(keepingCapacity: false)
      outbound.removeAll(keepingCapacity: false)
      remoteEOF = true
      terminalFailure = true
      abortDrain = false
    }
  }
}

enum LibSSH2BridgeError: Error, Equatable {
  case bridgeClosed
  case invalidSocketWriteCount
  case socketReadExceededBound
  case signaturePayloadChanged
  case signatureFailed
}

/// Lets an operation caller detach promptly while the owned underlying task is
/// retained for deterministic teardown and joined by its owner.
private final class LibSSH2BridgeOperationWaiter: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Void, Error>?
  private var result: Result<Void, Error>?

  func wait() async throws {
    try await withTaskCancellationHandler {
      try Task.checkCancellation()
      try await withCheckedThrowingContinuation { continuation in
        let immediate: Result<Void, Error>? = lock.withLock {
          if Task.isCancelled { return .failure(CancellationError()) }
          if let result { return result }
          self.continuation = continuation
          return nil
        }
        if let immediate { continuation.resume(with: immediate) }
      }
    } onCancel: {
      self.complete(with: .failure(CancellationError()))
    }
  }

  func complete(with result: Result<Void, Error>) {
    let continuation: CheckedContinuation<Void, Error>? = lock.withLock {
      guard self.result == nil else { return nil }
      self.result = result
      defer { self.continuation = nil }
      return self.continuation
    }
    continuation?.resume(with: result)
  }
}

struct LibSSH2SessionOperationPermit: Hashable, Sendable {
  fileprivate let identifier: UUID
}

enum LibSSH2SessionOperationGateError: Error, Equatable {
  case resourceLimitExceeded
  case shutDown
}

/// FIFO gate for libssh2 state machines stored on the shared session object.
/// Channel payload I/O remains independently interleavable; channel opens,
/// rekeys, and reply-requiring global requests hold one permit across EAGAIN.
final class LibSSH2SessionOperationGate: @unchecked Sendable {
  private struct Waiter {
    let identifier: UUID
    let continuation: CheckedContinuation<LibSSH2SessionOperationPermit, Error>
  }

  private let lock = NSLock()
  private let maximumWaiters: Int
  private var activeIdentifier: UUID?
  private var waiters: [Waiter] = []
  private var shutDown = false

  init(maximumWaiters: Int) {
    precondition(maximumWaiters > 0)
    self.maximumWaiters = maximumWaiters
  }

  var pendingCount: Int {
    lock.withLock { waiters.count + (activeIdentifier == nil ? 0 : 1) }
  }

  func acquire() async throws -> LibSSH2SessionOperationPermit {
    let identifier = UUID()
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      let permit = try await withCheckedThrowingContinuation { continuation in
        let immediate: Result<LibSSH2SessionOperationPermit, Error>? = lock.withLock {
          if Task.isCancelled { return .failure(CancellationError()) }
          if shutDown { return .failure(LibSSH2SessionOperationGateError.shutDown) }
          if activeIdentifier == nil {
            activeIdentifier = identifier
            return .success(LibSSH2SessionOperationPermit(identifier: identifier))
          }
          guard waiters.count < maximumWaiters else {
            return .failure(LibSSH2SessionOperationGateError.resourceLimitExceeded)
          }
          waiters.append(Waiter(identifier: identifier, continuation: continuation))
          return nil
        }
        if let immediate { continuation.resume(with: immediate) }
      }
      try Task.checkCancellation()
      return permit
    } onCancel: {
      self.cancelAcquisition(identifier: identifier)
    }
  }

  func release(_ permit: LibSSH2SessionOperationPermit) {
    let next: Waiter? = lock.withLock {
      guard activeIdentifier == permit.identifier else { return nil }
      guard !waiters.isEmpty, !shutDown else {
        activeIdentifier = nil
        return nil
      }
      let next = waiters.removeFirst()
      activeIdentifier = next.identifier
      return next
    }
    if let next {
      next.continuation.resume(
        returning: LibSSH2SessionOperationPermit(identifier: next.identifier))
    }
  }

  func cancelPending() {
    let cancelled: [Waiter] = lock.withLock {
      shutDown = true
      let cancelled = waiters
      waiters.removeAll(keepingCapacity: false)
      return cancelled
    }
    for waiter in cancelled {
      waiter.continuation.resume(throwing: LibSSH2SessionOperationGateError.shutDown)
    }
  }

  private func cancelAcquisition(identifier: UUID) {
    let action: (cancelled: Waiter?, promoted: Waiter?) = lock.withLock {
      if let index = waiters.firstIndex(where: { $0.identifier == identifier }) {
        return (waiters.remove(at: index), nil)
      }
      guard activeIdentifier == identifier else { return (nil, nil) }
      guard !waiters.isEmpty, !shutDown else {
        activeIdentifier = nil
        return (nil, nil)
      }
      let promoted = waiters.removeFirst()
      activeIdentifier = promoted.identifier
      return (nil, promoted)
    }
    action.cancelled?.continuation.resume(throwing: CancellationError())
    if let promoted = action.promoted {
      promoted.continuation.resume(
        returning: LibSSH2SessionOperationPermit(identifier: promoted.identifier))
    }
  }
}

private enum LibSSH2SignatureState {
  case idle
  case pending(Data)
  case ready(payload: Data, signature: Data)
  case failed(Data)
}

final class LibSSH2SessionContext: @unchecked Sendable {
  let network: LibSSH2NetworkBridge
  private let lock = NSLock()
  private var credential: (any SSHPublicKeyCredential)?
  private var signatureState = LibSSH2SignatureState.idle
  private var signatureTasks: [UUID: Task<Void, Never>] = [:]
  private var signatureWaiter: LibSSH2BridgeOperationWaiter?
  private var allocations: Set<UInt> = []

  init(maximumTransportBufferBytes: Int) {
    network = LibSSH2NetworkBridge(maximumBufferedBytes: maximumTransportBufferBytes)
  }

  var outstandingAllocationCount: Int {
    lock.withLock { allocations.count }
  }

  var outstandingTaskCount: Int {
    lock.withLock { signatureTasks.count }
  }

  func install(credential: any SSHPublicKeyCredential) {
    let tasks = lock.withLock { () -> [Task<Void, Never>] in
      let tasks = Array(signatureTasks.values)
      signatureWaiter = nil
      self.credential = credential
      signatureState = .idle
      return tasks
    }
    for task in tasks { task.cancel() }
  }

  func requestSignature(for payload: Data) -> Result<Data, LibSSH2BridgeError>? {
    lock.lock()
    switch signatureState {
    case .idle:
      guard let credential else {
        lock.unlock()
        return .failure(.signatureFailed)
      }
      signatureState = .pending(payload)
      let waiter = LibSSH2BridgeOperationWaiter()
      signatureWaiter = waiter
      let identifier = UUID()
      let task = Task {
        do {
          let signature = try await credential.sign(payload)
          self.completeSignature(
            identifier: identifier,
            payload: payload,
            result: .success(signature)
          )
        } catch {
          self.completeSignature(
            identifier: identifier,
            payload: payload,
            result: .failure(.signatureFailed)
          )
        }
      }
      signatureTasks[identifier] = task
      lock.unlock()
      return nil
    case .pending(let existing):
      lock.unlock()
      return existing == payload ? nil : .failure(.signaturePayloadChanged)
    case .ready(let existing, let signature):
      signatureState = .idle
      lock.unlock()
      return existing == payload ? .success(signature) : .failure(.signaturePayloadChanged)
    case .failed(let existing):
      signatureState = .idle
      lock.unlock()
      return existing == payload ? .failure(.signatureFailed) : .failure(.signaturePayloadChanged)
    }
  }

  func signatureIsPending() -> Bool {
    lock.withLock {
      if case .pending = signatureState { return true }
      return false
    }
  }

  func waitForSignature() async throws {
    let waiter = lock.withLock { signatureWaiter }
    try await waiter?.wait()
  }

  func cancelSignature() {
    let owned = lock.withLock { () -> ([Task<Void, Never>], LibSSH2BridgeOperationWaiter?) in
      let tasks = Array(signatureTasks.values)
      let waiter = signatureWaiter
      signatureWaiter = nil
      credential = nil
      if case .pending(let payload) = signatureState {
        signatureState = .failed(payload)
      }
      return (tasks, waiter)
    }
    for task in owned.0 { task.cancel() }
    owned.1?.complete(with: .failure(CancellationError()))
  }

  private func completeSignature(
    identifier: UUID,
    payload: Data,
    result: Result<Data, LibSSH2BridgeError>
  ) {
    let waiter: LibSSH2BridgeOperationWaiter? = lock.withLock {
      signatureTasks.removeValue(forKey: identifier)
      guard case .pending(let existing) = signatureState, existing == payload else { return nil }
      switch result {
      case .success(let signature):
        signatureState = .ready(payload: payload, signature: signature)
      case .failure:
        signatureState = .failed(payload)
      }
      defer { signatureWaiter = nil }
      return signatureWaiter
    }
    waiter?.complete(with: .success(()))
  }

  func allocate(byteCount: Int) -> UnsafeMutableRawPointer? {
    guard byteCount > 0, let pointer = malloc(byteCount) else { return nil }
    _ = lock.withLock { allocations.insert(UInt(bitPattern: pointer)) }
    return pointer
  }

  func reallocate(_ pointer: UnsafeMutableRawPointer?, byteCount: Int) -> UnsafeMutableRawPointer? {
    guard let pointer else { return allocate(byteCount: byteCount) }
    let oldAddress = UInt(bitPattern: pointer)
    guard let replacement = realloc(pointer, byteCount) else { return nil }
    lock.withLock {
      allocations.remove(oldAddress)
      allocations.insert(UInt(bitPattern: replacement))
    }
    return replacement
  }

  func free(_ pointer: UnsafeMutableRawPointer?) {
    guard let pointer else { return }
    _ = lock.withLock { allocations.remove(UInt(bitPattern: pointer)) }
    Darwin.free(pointer)
  }
}

private func context(from abstract: UnsafeMutablePointer<UnsafeMutableRawPointer?>?)
  -> LibSSH2SessionContext?
{
  guard let opaque = abstract?.pointee else { return nil }
  return Unmanaged<LibSSH2SessionContext>.fromOpaque(opaque).takeUnretainedValue()
}

let reluxLibSSH2SendCallback:
  @convention(c) (
    Int32, UnsafeRawPointer?, Int, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?
  )
    -> Int = { _, buffer, length, _, abstract in
      guard let context = context(from: abstract) else { return -1 }
      return context.network.send(bytes: buffer, length: length)
    }

let reluxLibSSH2ReceiveCallback:
  @convention(c) (
    Int32, UnsafeMutableRawPointer?, Int, Int32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?
  )
    -> Int = { _, buffer, length, _, abstract in
      guard let context = context(from: abstract) else { return -1 }
      return context.network.receive(into: buffer, maximumLength: length)
    }

let reluxLibSSH2AllocateCallback:
  @convention(c) (Int, UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> UnsafeMutableRawPointer? =
    {
      byteCount, abstract in
      context(from: abstract)?.allocate(byteCount: byteCount)
    }

let reluxLibSSH2ReallocateCallback:
  @convention(c) (
    UnsafeMutableRawPointer?, Int, UnsafeMutablePointer<UnsafeMutableRawPointer?>?
  ) -> UnsafeMutableRawPointer? = {
    pointer, byteCount, abstract in
    context(from: abstract)?.reallocate(pointer, byteCount: byteCount)
  }

let reluxLibSSH2FreeCallback:
  @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>?
  ) -> Void = { pointer, abstract in
    context(from: abstract)?.free(pointer)
  }

let reluxLibSSH2SignCallback:
  @convention(c) (
    OpaquePointer?,
    UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
    UnsafeMutablePointer<Int>?,
    UnsafePointer<UInt8>?,
    Int,
    UnsafeMutablePointer<UnsafeMutableRawPointer?>?
  ) -> Int32 = { _, signature, signatureLength, payload, payloadLength, abstract in
    guard let context = context(from: abstract), let payload, let signature, let signatureLength
    else {
      return Int32(LIBSSH2_ERROR_BAD_USE)
    }
    let bytes = Data(bytes: payload, count: payloadLength)
    guard let result = context.requestSignature(for: bytes) else {
      return Int32(LIBSSH2_ERROR_EAGAIN)
    }
    switch result {
    case .success(let signed):
      guard !signed.isEmpty, let output = context.allocate(byteCount: signed.count) else {
        return Int32(LIBSSH2_ERROR_ALLOC)
      }
      signed.copyBytes(to: output.assumingMemoryBound(to: UInt8.self), count: signed.count)
      signature.pointee = output.assumingMemoryBound(to: UInt8.self)
      signatureLength.pointee = signed.count
      return 0
    case .failure:
      return Int32(LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED)
    }
  }

enum LibSSH2GlobalRuntime {
  private static let lock = NSLock()
  nonisolated(unsafe) private static var initialized = false

  static func initialize() throws {
    try lock.withLock {
      guard !initialized else { return }
      guard libssh2_init(0) == 0 else { throw LibSSH2RuntimeError.initializationFailed }
      initialized = true
    }
  }
}

enum LibSSH2RuntimeError: Error {
  case initializationFailed
}
