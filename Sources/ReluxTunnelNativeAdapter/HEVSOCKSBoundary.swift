import Darwin
import Dispatch
import Foundation

public protocol HEVSOCKSConnectionAdapter: Sendable {
  /// Receives an authenticated, exclusively owned channel positioned at the
  /// first byte of the SOCKS request. The channel closes itself on release.
  func acceptAuthenticatedConnection(_ channel: HEVSOCKSChannel)
}

public final class HEVSOCKSChannel: @unchecked Sendable {
  private let lock = NSLock()
  private var descriptor: Int32?

  fileprivate init(descriptor: Int32) {
    self.descriptor = descriptor
  }

  deinit {
    close()
  }

  public func withBorrowedDescriptor<T>(
    _ operation: (Int32) throws -> T
  ) throws -> T {
    try lock.withLock {
      guard let descriptor else {
        throw HEVIntegrationError.socksBoundaryFailed(code: EBADF)
      }
      return try operation(descriptor)
    }
  }

  public func close() {
    let descriptor = lock.withLock { () -> Int32? in
      defer { self.descriptor = nil }
      return self.descriptor
    }
    if let descriptor {
      Darwin.close(descriptor)
    }
  }
}

public struct HEVLoopbackSOCKSBoundaryFactory: HEVSOCKSBoundaryFactory {
  public typealias CredentialSource = @Sendable () -> HEVSOCKSCredentials

  private let adapter: any HEVSOCKSConnectionAdapter
  private let credentialSource: CredentialSource
  private let maximumPendingConnections: Int
  private let authenticationTimeoutMilliseconds: Int

  public init(
    adapter: any HEVSOCKSConnectionAdapter,
    maximumPendingConnections: Int,
    authenticationTimeoutMilliseconds: Int,
    credentialSource: @escaping CredentialSource = {
      HEVSOCKSCredentials(
        username: "relux-\(UUID().uuidString)",
        password: "relux-\(UUID().uuidString)-\(UUID().uuidString)"
      )
    }
  ) {
    self.adapter = adapter
    self.maximumPendingConnections = maximumPendingConnections
    self.authenticationTimeoutMilliseconds = authenticationTimeoutMilliseconds
    self.credentialSource = credentialSource
  }

  public func makeBoundary() -> any HEVSOCKSBoundary {
    HEVLoopbackSOCKSBoundary(
      adapter: adapter,
      credentials: credentialSource(),
      maximumPendingConnections: maximumPendingConnections,
      authenticationTimeoutMilliseconds: authenticationTimeoutMilliseconds
    )
  }
}

/// A loopback-only listener protected by per-run RFC 1929 credentials.
/// Connections that do not prove the capability are closed before the
/// injectable adapter sees any bytes or descriptor.
public final class HEVLoopbackSOCKSBoundary: HEVSOCKSBoundary, @unchecked Sendable {
  private let adapter: any HEVSOCKSConnectionAdapter
  private let credentials: HEVSOCKSCredentials
  private let maximumPendingConnections: Int
  private let authenticationTimeoutMilliseconds: Int
  private let stateLock = NSLock()
  private let listenerQueue = DispatchQueue(label: "works.relux.hev.socks-listener")
  private let authenticationQueue = DispatchQueue(
    label: "works.relux.hev.socks-auth",
    attributes: .concurrent
  )
  private let listenerCancellationGroup = DispatchGroup()
  private let authenticationGroup = DispatchGroup()
  private var source: DispatchSourceRead?
  private var listenerDescriptor: Int32?
  private var pendingDescriptors: Set<Int32> = []
  private var stopped = false

  public init(
    adapter: any HEVSOCKSConnectionAdapter,
    credentials: HEVSOCKSCredentials,
    maximumPendingConnections: Int,
    authenticationTimeoutMilliseconds: Int
  ) {
    self.adapter = adapter
    self.credentials = credentials
    self.maximumPendingConnections = maximumPendingConnections
    self.authenticationTimeoutMilliseconds = authenticationTimeoutMilliseconds
  }

  deinit {
    let state = stateLock.withLock { () -> ([Int32], Int32?, DispatchSourceRead?) in
      let pending = Array(pendingDescriptors)
      let listener = listenerDescriptor
      let source = self.source
      pendingDescriptors.removeAll()
      listenerDescriptor = nil
      self.source = nil
      return (pending, listener, source)
    }
    state.2?.cancel()
    if state.2 == nil, let listener = state.1 {
      Darwin.shutdown(listener, SHUT_RDWR)
      Darwin.close(listener)
    }
    for descriptor in state.0 {
      Darwin.shutdown(descriptor, SHUT_RDWR)
      Darwin.close(descriptor)
    }
  }

  public func start() async throws -> HEVSOCKSAccess {
    guard maximumPendingConnections > 0, authenticationTimeoutMilliseconds > 0 else {
      throw HEVIntegrationError.invalidConfiguration(field: "socksBoundaryLimits")
    }
    guard
      stateLock.withLock({ listenerDescriptor == nil && source == nil && !stopped })
    else {
      throw HEVIntegrationError.socksBoundaryFailed(code: EALREADY)
    }
    let listener = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard listener >= 0 else {
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }
    var shouldClose = true
    defer {
      if shouldClose {
        Darwin.close(listener)
      }
    }

    try setCloseOnExec(listener)
    try setNonBlocking(listener)
    var noSignal: Int32 = 1
    guard
      setsockopt(
        listener,
        SOL_SOCKET,
        SO_NOSIGPIPE,
        &noSignal,
        socklen_t(MemoryLayout.size(ofValue: noSignal))
      ) == 0
    else {
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let bindResult = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bindResult == 0 else {
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }
    guard Darwin.listen(listener, 16) == 0 else {
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }

    var boundAddress = sockaddr_in()
    var boundLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        getsockname(listener, $0, &boundLength)
      }
    }
    guard nameResult == 0 else {
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }
    let port = UInt16(bigEndian: boundAddress.sin_port)
    guard port > 0 else {
      throw HEVIntegrationError.socksBoundaryFailed(code: EADDRNOTAVAIL)
    }

    let readSource = DispatchSource.makeReadSource(
      fileDescriptor: listener,
      queue: listenerQueue
    )
    readSource.setEventHandler { [weak self] in
      self?.acceptAvailableConnections()
    }
    let cancellationGroup = listenerCancellationGroup
    cancellationGroup.enter()
    readSource.setCancelHandler {
      Darwin.shutdown(listener, SHUT_RDWR)
      Darwin.close(listener)
      cancellationGroup.leave()
    }
    stateLock.withLock {
      listenerDescriptor = listener
      source = readSource
      stopped = false
    }
    shouldClose = false
    readSource.resume()
    return HEVSOCKSAccess(port: port, credentials: credentials)
  }

  public func stop() async {
    let state = stateLock.withLock { () -> ([Int32], DispatchSourceRead?) in
      guard !stopped else { return ([], nil) }
      stopped = true
      listenerDescriptor = nil
      let pending = Array(pendingDescriptors)
      let source = self.source
      self.source = nil
      return (pending, source)
    }
    state.1?.cancel()
    for descriptor in state.0 {
      Darwin.shutdown(descriptor, SHUT_RDWR)
    }
    await withCheckedContinuation { continuation in
      listenerCancellationGroup.notify(queue: listenerQueue) {
        continuation.resume()
      }
    }
    await withCheckedContinuation { continuation in
      authenticationGroup.notify(queue: listenerQueue) {
        continuation.resume()
      }
    }
  }

  private func acceptAvailableConnections() {
    guard let listener = stateLock.withLock({ listenerDescriptor }) else {
      return
    }
    while true {
      let descriptor = Darwin.accept(listener, nil, nil)
      if descriptor < 0 {
        if errno == EINTR {
          continue
        }
        return
      }
      do {
        try setCloseOnExec(descriptor)
        try setBlocking(descriptor)
        try setAuthenticationTimeout(descriptor)
        var noSignal: Int32 = 1
        guard
          setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSignal,
            socklen_t(MemoryLayout.size(ofValue: noSignal))
          ) == 0
        else {
          throw HEVIntegrationError.socksBoundaryFailed(code: errno)
        }
      } catch {
        Darwin.close(descriptor)
        continue
      }

      let accepted = stateLock.withLock { () -> Bool in
        guard !stopped, pendingDescriptors.count < maximumPendingConnections else {
          return false
        }
        pendingDescriptors.insert(descriptor)
        return true
      }
      guard accepted else {
        Darwin.close(descriptor)
        continue
      }
      authenticationGroup.enter()
      authenticationQueue.async { [weak self] in
        defer { self?.authenticationGroup.leave() }
        self?.authenticate(descriptor)
      }
    }
  }

  private func authenticate(_ descriptor: Int32) {
    guard
      let greeting = receiveExactly(2, from: descriptor),
      greeting[0] == 5,
      let methods = receiveExactly(Int(greeting[1]), from: descriptor),
      methods.contains(2)
    else {
      _ = sendAll([5, 0xFF], to: descriptor)
      reject(descriptor)
      return
    }
    guard sendAll([5, 2], to: descriptor) else {
      reject(descriptor)
      return
    }
    guard let authHeader = receiveExactly(2, from: descriptor), authHeader[0] == 1 else {
      _ = sendAll([1, 1], to: descriptor)
      reject(descriptor)
      return
    }
    guard let username = receiveExactly(Int(authHeader[1]), from: descriptor) else {
      _ = sendAll([1, 1], to: descriptor)
      reject(descriptor)
      return
    }
    guard
      let passwordLengthBytes = receiveExactly(1, from: descriptor),
      let passwordLength = passwordLengthBytes.first,
      let password = receiveExactly(Int(passwordLength), from: descriptor)
    else {
      _ = sendAll([1, 1], to: descriptor)
      reject(descriptor)
      return
    }
    let usernameMatches = constantTimeEquals(username, Array(credentials.username.utf8))
    let passwordMatches = constantTimeEquals(password, Array(credentials.password.utf8))
    guard usernameMatches, passwordMatches else {
      _ = sendAll([1, 1], to: descriptor)
      reject(descriptor)
      return
    }
    guard sendAll([1, 0], to: descriptor) else {
      reject(descriptor)
      return
    }

    let mayTransfer = stateLock.withLock { () -> Bool in
      pendingDescriptors.remove(descriptor)
      return !stopped
    }
    guard mayTransfer else {
      Darwin.close(descriptor)
      return
    }
    adapter.acceptAuthenticatedConnection(HEVSOCKSChannel(descriptor: descriptor))
  }

  private func reject(_ descriptor: Int32) {
    _ = stateLock.withLock {
      pendingDescriptors.remove(descriptor)
    }
    Darwin.shutdown(descriptor, SHUT_RDWR)
    Darwin.close(descriptor)
  }

  private func receiveExactly(_ count: Int, from descriptor: Int32) -> [UInt8]? {
    guard count >= 0 else { return nil }
    if count == 0 { return [] }
    var bytes = [UInt8](repeating: 0, count: count)
    var offset = 0
    while offset < count {
      let received = bytes.withUnsafeMutableBytes { buffer in
        Darwin.recv(descriptor, buffer.baseAddress! + offset, count - offset, 0)
      }
      if received > 0 {
        offset += received
      } else if received < 0 && errno == EINTR {
        continue
      } else {
        return nil
      }
    }
    return bytes
  }

  private func sendAll(_ bytes: [UInt8], to descriptor: Int32) -> Bool {
    var offset = 0
    while offset < bytes.count {
      let sent = bytes.withUnsafeBytes { buffer in
        Darwin.send(descriptor, buffer.baseAddress! + offset, bytes.count - offset, 0)
      }
      if sent > 0 {
        offset += sent
      } else if sent < 0 && errno == EINTR {
        continue
      } else {
        return false
      }
    }
    return true
  }

  private func constantTimeEquals(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
    var difference = UInt8(truncatingIfNeeded: lhs.count ^ rhs.count)
    let count = max(lhs.count, rhs.count)
    for index in 0..<count {
      let left = index < lhs.count ? lhs[index] : 0
      let right = index < rhs.count ? rhs[index] : 0
      difference |= left ^ right
    }
    return difference == 0
  }

  private func setCloseOnExec(_ descriptor: Int32) throws {
    let flags = fcntl(descriptor, F_GETFD)
    guard flags >= 0, fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) == 0 else {
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }
  }

  private func setNonBlocking(_ descriptor: Int32) throws {
    let flags = fcntl(descriptor, F_GETFL)
    guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }
  }

  private func setBlocking(_ descriptor: Int32) throws {
    let flags = fcntl(descriptor, F_GETFL)
    guard flags >= 0, fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK) == 0 else {
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }
  }

  private func setAuthenticationTimeout(_ descriptor: Int32) throws {
    var timeout = timeval(
      tv_sec: authenticationTimeoutMilliseconds / 1_000,
      tv_usec: Int32(authenticationTimeoutMilliseconds % 1_000) * 1_000
    )
    guard
      setsockopt(
        descriptor,
        SOL_SOCKET,
        SO_RCVTIMEO,
        &timeout,
        socklen_t(MemoryLayout.size(ofValue: timeout))
      ) == 0
    else {
      throw HEVIntegrationError.socksBoundaryFailed(code: errno)
    }
  }
}
