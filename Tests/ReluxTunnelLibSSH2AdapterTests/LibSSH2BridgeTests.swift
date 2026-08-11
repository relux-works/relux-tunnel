import Foundation
import ReluxTunnelCore
import Testing

@testable import ReluxTunnelLibSSH2Adapter

@Suite("libssh2 bounded async bridges")
struct LibSSH2BridgeTests {
  @Test("send callback applies a hard bound and async service drains partial writes")
  func boundedOutboundBridge() async throws {
    let bridge = LibSSH2NetworkBridge(maximumBufferedBytes: 8)
    let connection = BridgeConnection(maximumWriteBytes: 3)

    #expect(
      Data("12345678".utf8).withUnsafeBytes { bridge.send(bytes: $0.baseAddress, length: 8) } == 8)
    #expect(
      Data("x".utf8).withUnsafeBytes { bridge.send(bytes: $0.baseAddress, length: 1) }
        == -Int(EAGAIN))
    #expect(bridge.bufferedByteCounts.outbound == 8)

    try await bridge.service(connection: connection, interests: [.writable])
    #expect(bridge.bufferedByteCounts.outbound == 5)
    try await bridge.service(connection: connection, interests: [.writable])
    try await bridge.service(connection: connection, interests: [.writable])
    #expect(bridge.bufferedByteCounts.outbound == 0)
    #expect(await connection.writtenBytes() == Data("12345678".utf8))
  }

  @Test("receive callback returns only caller-sized prefixes and then EAGAIN")
  func boundedInboundBridge() async throws {
    let bridge = LibSSH2NetworkBridge(maximumBufferedBytes: 8)
    let connection = BridgeConnection(reads: [Data("abc".utf8)])
    try await bridge.service(connection: connection, interests: [.readable])

    var first = [UInt8](repeating: 0, count: 2)
    let firstCount = first.withUnsafeMutableBytes {
      bridge.receive(into: $0.baseAddress, maximumLength: $0.count)
    }
    #expect(firstCount == 2)
    #expect(first == Array("ab".utf8))

    var second = [UInt8](repeating: 0, count: 2)
    let secondCount = second.withUnsafeMutableBytes {
      bridge.receive(into: $0.baseAddress, maximumLength: $0.count)
    }
    #expect(secondCount == 1)
    #expect(second[0] == UInt8(ascii: "c"))
    #expect(
      second.withUnsafeMutableBytes { bridge.receive(into: $0.baseAddress, maximumLength: 2) }
        == -Int(EAGAIN)
    )
  }

  @Test("socket reads that violate the advertised bound fail closed")
  func oversizedSocketReadFails() async {
    let bridge = LibSSH2NetworkBridge(maximumBufferedBytes: 4)
    let connection = BridgeConnection(reads: [Data(repeating: 1, count: 5)])
    await #expect(throws: LibSSH2BridgeError.socketReadExceededBound) {
      try await bridge.service(connection: connection, interests: [.readable])
    }
  }

  @Test("overlapping socket progress writes every queued byte exactly once")
  func concurrentSocketProgressIsSerialized() async throws {
    let bridge = LibSSH2NetworkBridge(maximumBufferedBytes: 8)
    let connection = SuspendingWriteConnection(maximumWriteBytes: 3)
    #expect(
      Data("abcdef".utf8).withUnsafeBytes { bridge.send(bytes: $0.baseAddress, length: 6) } == 6)

    let first = Task { try await bridge.service(connection: connection, interests: [.writable]) }
    await connection.waitUntilFirstWriteStarts()
    let second = Task { try await bridge.service(connection: connection, interests: [.writable]) }
    for _ in 0..<100 where bridge.pendingServiceCount < 2 {
      await Task.yield()
    }
    #expect(bridge.pendingServiceCount == 2)
    await connection.releaseFirstWrite()
    try await first.value
    try await second.value

    #expect(await connection.writtenBytes() == Data("abcdef".utf8))
    #expect(await connection.maximumConcurrentWrites() == 1)
    #expect(bridge.bufferedByteCounts.outbound == 0)
  }

  @Test("session state-machine gate serializes callers and bounds its queue")
  func sessionOperationGateIsSerializedAndBounded() async throws {
    let gate = LibSSH2SessionOperationGate(maximumWaiters: 1)
    let first = try await gate.acquire()
    let second = Task { try await gate.acquire() }
    for _ in 0..<100 where gate.pendingCount < 2 { await Task.yield() }
    #expect(gate.pendingCount == 2)

    await #expect(throws: LibSSH2SessionOperationGateError.resourceLimitExceeded) {
      _ = try await gate.acquire()
    }
    gate.release(first)
    let secondPermit = try await second.value
    gate.release(secondPermit)
    #expect(gate.pendingCount == 0)
  }

  @Test("cancelled session state-machine waiters retire without taking the permit")
  func sessionOperationGateCancellation() async throws {
    let gate = LibSSH2SessionOperationGate(maximumWaiters: 2)
    let first = try await gate.acquire()
    let waiter = Task { try await gate.acquire() }
    for _ in 0..<100 where gate.pendingCount < 2 { await Task.yield() }
    waiter.cancel()
    await #expect(throws: CancellationError.self) { _ = try await waiter.value }
    gate.release(first)
    #expect(gate.pendingCount == 0)
  }

  @Test("bridge shutdown joins a late non-cooperative socket completion before discard")
  func bridgeShutdownDrainsLateCompletion() async throws {
    let bridge = LibSSH2NetworkBridge(maximumBufferedBytes: 8)
    let connection = CloseReleasedWriteConnection()
    #expect(
      Data("abcdef".utf8).withUnsafeBytes {
        bridge.send(bytes: $0.baseAddress, length: $0.count)
      } == 6)

    let service = Task { try await bridge.service(connection: connection, interests: [.writable]) }
    await connection.waitUntilWriteStarts()
    bridge.beginShutdown()
    let clock = ContinuousTunnelClock()
    let drain = Task {
      await bridge.drainServices(until: clock.now().advanced(by: .seconds(1)), clock: clock)
    }
    await Task.yield()
    #expect(bridge.pendingServiceCount == 1)
    await connection.close()
    _ = await drain.value
    _ = try? await service.value
    bridge.discard()

    #expect(bridge.pendingServiceCount == 0)
    #expect(bridge.bufferedByteCounts.inbound == 0)
    #expect(bridge.bufferedByteCounts.outbound == 0)
  }

  @Test("external signer suspends with EAGAIN state instead of blocking the callback")
  func externalSignerBridge() async throws {
    let context = LibSSH2SessionContext(maximumTransportBufferBytes: 64)
    context.install(credential: ReversingCredential())
    let payload = Data([1, 2, 3, 4])

    #expect(context.requestSignature(for: payload) == nil)
    try await context.waitForSignature()
    let result = context.requestSignature(for: payload)
    #expect(try result?.get() == Data([4, 3, 2, 1]))
  }

  @Test("external signer cancellation remains owned until completion")
  func externalSignerCancellation() async {
    let context = LibSSH2SessionContext(maximumTransportBufferBytes: 64)
    let credential = CancellationIgnoringCredential()
    context.install(credential: credential)
    #expect(context.requestSignature(for: Data([1])) == nil)
    while !credential.isWaiting { await Task.yield() }
    #expect(context.outstandingTaskCount == 1)

    context.cancelSignature()

    #expect(context.outstandingTaskCount == 1)
    #expect(credential.isRetired)
    credential.release()
    while context.outstandingTaskCount != 0 { await Task.yield() }
    #expect(context.outstandingTaskCount == 0)
  }

  @Test("custom allocations return to baseline")
  func allocationHooksReturnToBaseline() throws {
    let context = LibSSH2SessionContext(maximumTransportBufferBytes: 64)
    let pointer = try #require(context.allocate(byteCount: 16))
    #expect(context.outstandingAllocationCount == 1)
    let replacement = try #require(context.reallocate(pointer, byteCount: 32))
    #expect(context.outstandingAllocationCount == 1)
    context.free(replacement)
    #expect(context.outstandingAllocationCount == 0)
  }

  @Test("factory explicitly discloses every M3-deferred semantic as unsupported")
  func deferredCapabilitiesAreNeverFabricated() {
    let capabilities = LibSSH2TransportFactory().capabilities
    #expect(capabilities.deferredSemantics.consumerDrivenReceiveWindowCredit == .unsupported)
    #expect(capabilities.deferredSemantics.rfcChannelOpenFailureReasons == .unsupported)
    #expect(capabilities.deferredSemantics.exactExecExitMetadata == .unsupported)
    #expect(capabilities.deferredSemantics.deepRekeyAndKeepaliveObservability == .unsupported)
    #expect(capabilities.features.contains(.explicitRekey))
    #expect(capabilities.features.contains(.serverRekey))
    #expect(capabilities.features.contains(.keepalive))
  }

  @Test("repeated failed handshakes return every owned resource to baseline")
  func repeatedHandshakeCleanup() async throws {
    let dependencies = try lifecycleDependencies()
    let configuration = try lifecycleConfiguration()
    let factory = LibSSH2TransportFactory(maximumTransportBufferBytes: 4 * 1_024)

    for index in 0..<20 {
      let transport =
        try await factory.makeTransport(
          lane: SSHLaneIdentity(rawValue: UUID()),
          dependencies: dependencies
        ) as! LibSSH2Transport
      await #expect(throws: SSHTransportError.self) {
        try await transport.connect(configuration: configuration)
      }
      let resources = await transport.ownedResourceSnapshot()
      #expect(
        resources
          == LibSSH2OwnedResourceSnapshot(
            channels: 0,
            socketOwned: false,
            sessionOwned: false,
            automaticTasks: 0,
            customAllocations: 0,
            bufferedBytes: 0
          ), "iteration \(index)")
      #expect((await transport.snapshot()).connectionState == .closed)
    }
  }

  @Test("connect timeout preserves resolution phase and restores resources")
  func resolutionTimeoutEvidence() async throws {
    let dependencies = try lifecycleDependencies(resolver: SuspendedResolver())
    let configuration = try lifecycleConfiguration()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 4 * 1_024).makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: dependencies
      ) as! LibSSH2Transport

    do {
      _ = try await transport.connect(configuration: configuration)
      Issue.record("connect unexpectedly succeeded")
    } catch let error as SSHTransportError {
      #expect(error.code == .timedOut)
      #expect(error.phase == .resolution)
      let bootstrap = SSHBootstrapErrorMapper.transport(
        error,
        configurationGeneration: 4
      ).diagnostic
      #expect(bootstrap.code == .operationTimedOut)
      #expect(bootstrap.stage == .physicalPathResolution)
      #expect(bootstrap.retryDisposition == .retryableLater)
    }
    let snapshot = await transport.snapshot()
    #expect(snapshot.counters.operationsTimedOut == 1)
    #expect(snapshot.connectionState == .closed)
    #expect(
      await transport.ownedResourceSnapshot()
        == LibSSH2OwnedResourceSnapshot(
          channels: 0,
          socketOwned: false,
          sessionOwned: false,
          automaticTasks: 0,
          customAllocations: 0,
          bufferedBytes: 0
        )
    )
  }

  @Test("resolution timeout detaches from a dependency that ignores cancellation")
  func nonCooperativeResolutionTimeout() async throws {
    let resolver = CancellationIgnoringResolver()
    let dependencies = try lifecycleDependencies(resolver: resolver)
    let configuration = try lifecycleConfiguration()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 4 * 1_024).makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: dependencies
      ) as! LibSSH2Transport

    let connect = Task { try await transport.connect(configuration: configuration) }
    while !(await resolver.isWaiting) { await Task.yield() }
    let started = ContinuousClock.now
    do {
      _ = try await connect.value
      Issue.record("connect unexpectedly succeeded")
    } catch let error as SSHTransportError {
      #expect(error.code == .timedOut)
      #expect(error.phase == .resolution)
    }
    #expect(started.duration(to: .now) < .seconds(1))
    #expect(!(await resolver.wasReleased))

    let detached = await transport.ownedResourceSnapshot()
    #expect(detached.channels == 0)
    #expect(!detached.socketOwned)
    #expect(!detached.sessionOwned)
    #expect(detached.automaticTasks == 1)
    #expect((await transport.snapshot()).connectionState == .closed)

    await transport.close()
    await resolver.release()
    while (await transport.ownedResourceSnapshot()).automaticTasks != 0 {
      await Task.yield()
    }
    #expect(
      await transport.ownedResourceSnapshot()
        == LibSSH2OwnedResourceSnapshot(
          channels: 0,
          socketOwned: false,
          sessionOwned: false,
          automaticTasks: 0,
          customAllocations: 0,
          bufferedBytes: 0
        )
    )
  }

  @Test("a connector result arriving after timeout is closed and retired")
  func lateConnectorResultIsClosed() async throws {
    let connection = LateConnectorConnection()
    let connector = CancellationIgnoringConnector(connection: connection)
    let dependencies = try lifecycleDependencies(connector: connector)
    let configuration = try lifecycleConfiguration()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 4 * 1_024).makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: dependencies
      ) as! LibSSH2Transport

    let connect = Task { try await transport.connect(configuration: configuration) }
    while !(await connector.isWaiting) { await Task.yield() }
    do {
      _ = try await connect.value
      Issue.record("connect unexpectedly succeeded")
    } catch let error as SSHTransportError {
      #expect(error.code == .timedOut)
      #expect(error.phase == .tcpConnect)
      let bootstrap = SSHBootstrapErrorMapper.transport(
        error,
        configurationGeneration: 4
      ).diagnostic
      #expect(bootstrap.code == .operationTimedOut)
      #expect(bootstrap.stage == .endpointConnect)
      #expect(bootstrap.retryDisposition == .retryableLater)
    }
    #expect((await transport.ownedResourceSnapshot()).automaticTasks == 1)

    await connector.release()
    while await connection.closeCount == 0 { await Task.yield() }
    while await transport.ownedResourceSnapshot() != .zero { await Task.yield() }
    #expect(await connection.closeCount == 1)
    #expect(await transport.ownedResourceSnapshot() == .zero)
  }

  @Test("transport close is bounded when socket teardown ignores cancellation")
  func nonCooperativeSocketTeardownIsBounded() async throws {
    let connection = CancellationIgnoringTeardownConnection()
    let dependencies = try lifecycleDependencies(
      connector: ImmediateLifecycleConnector(connection: connection)
    )
    let configuration = try lifecycleConfiguration()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 4 * 1_024).makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: dependencies
      ) as! LibSSH2Transport

    let started = ContinuousClock.now
    do {
      _ = try await transport.connect(configuration: configuration)
      Issue.record("connect unexpectedly succeeded")
    } catch let error as SSHTransportError {
      #expect(error.code == .timedOut)
      #expect(error.phase == .initialKeyExchange)
      let bootstrap = SSHBootstrapErrorMapper.transport(
        error,
        configurationGeneration: 4
      ).diagnostic
      #expect(bootstrap.code == .operationTimedOut)
      #expect(bootstrap.stage == .algorithmNegotiation)
      #expect(bootstrap.retryDisposition == .retryableLater)
    }
    #expect(started.duration(to: .now) < .seconds(1))
    #expect((await transport.snapshot()).connectionState == .closed)
    #expect((await transport.ownedResourceSnapshot()).automaticTasks > 0)
    #expect(await connection.writeCount == 0)

    await connection.release()
    while await transport.ownedResourceSnapshot() != .zero { await Task.yield() }
    #expect(await connection.closeCount == 1)
    #expect(await connection.writeCount == 0)
    #expect(await transport.ownedResourceSnapshot() == .zero)
  }

  @Test("socket close owns reserved capacity when ordinary operations are saturated")
  func saturatedOrdinaryOperationsCannotSkipSocketClose() async throws {
    let connection = SaturatedCloseConnection()
    let dependencies = try lifecycleDependencies(
      connector: ImmediateLifecycleConnector(connection: connection)
    )
    let configuration = try lifecycleConfiguration()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 4 * 1_024).makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: dependencies
      ) as! LibSSH2Transport

    let connect = Task { try await transport.connect(configuration: configuration) }
    await connection.waitUntilReadinessStarts()
    let ordinaryOperations = await transport.asyncOperations
    for _ in 0..<500 where ordinaryOperations.outstandingCount != 1 {
      await Task.yield()
    }
    #expect(ordinaryOperations.outstandingCount == 1)

    let retained = (0..<63).map { _ in RetainedOwnedOperation() }
    for operation in retained { try ordinaryOperations.register(operation) }
    #expect(ordinaryOperations.outstandingCount == 64)

    let started = ContinuousClock.now
    await transport.close()
    #expect(started.duration(to: .now) < .seconds(1))
    #expect(await connection.closeCount == 1)
    #expect(await connection.readCount == 0)
    #expect(await connection.writeCount == 0)
    #expect(ordinaryOperations.outstandingCount == retained.count)
    #expect(retained.allSatisfy { $0.cancelCount == 1 })

    await connection.releaseReadiness()
    await connection.waitUntilReadinessReturns()
    _ = try? await connect.value
    #expect(await connection.readCount == 0)
    #expect(await connection.writeCount == 0)
    for operation in retained {
      ordinaryOperations.remove(identifier: operation.identifier)
    }
    while await transport.ownedResourceSnapshot() != .zero { await Task.yield() }
    #expect(await connection.closeCount == 1)
    #expect(await transport.ownedResourceSnapshot() == .zero)
  }

  @Test("repeated connect cancellation restores tasks and resources to baseline")
  func repeatedConnectCancellation() async throws {
    let dependencies = try lifecycleDependencies(resolver: SuspendedResolver())
    let configuration = try lifecycleConfiguration()
    let factory = LibSSH2TransportFactory(maximumTransportBufferBytes: 4 * 1_024)

    for index in 0..<20 {
      let transport =
        try await factory.makeTransport(
          lane: SSHLaneIdentity(rawValue: UUID()),
          dependencies: dependencies
        ) as! LibSSH2Transport
      let connect = Task { try await transport.connect(configuration: configuration) }
      await Task.yield()
      connect.cancel()
      do {
        _ = try await connect.value
        Issue.record("cancelled connect unexpectedly succeeded")
      } catch let error as SSHTransportError {
        #expect(error.code == .cancelled, "iteration \(index)")
        #expect(error.phase == .resolution, "iteration \(index)")
      }
      let snapshot = await transport.snapshot()
      #expect(snapshot.counters.operationsCancelled == 1, "iteration \(index)")
      #expect(snapshot.connectionState == .closed, "iteration \(index)")
      #expect(
        await transport.ownedResourceSnapshot()
          == LibSSH2OwnedResourceSnapshot(
            channels: 0,
            socketOwned: false,
            sessionOwned: false,
            automaticTasks: 0,
            customAllocations: 0,
            bufferedBytes: 0
          ), "iteration \(index)")
    }
  }
}

private actor BridgeConnection: SSHTCPConnection {
  private var reads: [Data?]
  private let maximumWriteBytes: Int
  private var written = Data()

  init(reads: [Data?] = [], maximumWriteBytes: Int = .max) {
    self.reads = reads
    self.maximumWriteBytes = maximumWriteBytes
  }

  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    interests
  }

  func readSome(maximumBytes: Int) async throws -> Data? {
    guard !reads.isEmpty else { return Data() }
    return reads.removeFirst()
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    let count = min(bytes.count, maximumWriteBytes)
    written.append(bytes.prefix(count))
    return count
  }

  func close() async {}

  func writtenBytes() -> Data { written }
}

private actor SuspendingWriteConnection: SSHTCPConnection {
  private let maximumWriteBytes: Int
  private var written = Data()
  private var activeWrites = 0
  private var maximumActiveWrites = 0
  private var firstWriteStarted = false
  private var firstWriteStartWaiters: [CheckedContinuation<Void, Never>] = []
  private var firstWriteRelease: CheckedContinuation<Void, Never>?

  init(maximumWriteBytes: Int) {
    self.maximumWriteBytes = maximumWriteBytes
  }

  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    interests
  }

  func readSome(maximumBytes: Int) async throws -> Data? { Data() }

  func writeSome(_ bytes: Data) async throws -> Int {
    activeWrites += 1
    maximumActiveWrites = max(maximumActiveWrites, activeWrites)
    if !firstWriteStarted {
      firstWriteStarted = true
      let waiters = firstWriteStartWaiters
      firstWriteStartWaiters.removeAll()
      for waiter in waiters { waiter.resume() }
      await withCheckedContinuation { continuation in
        firstWriteRelease = continuation
      }
    }
    let count = min(bytes.count, maximumWriteBytes)
    written.append(bytes.prefix(count))
    activeWrites -= 1
    return count
  }

  func close() async {}

  func waitUntilFirstWriteStarts() async {
    guard !firstWriteStarted else { return }
    await withCheckedContinuation { continuation in
      firstWriteStartWaiters.append(continuation)
    }
  }

  func releaseFirstWrite() {
    firstWriteRelease?.resume()
    firstWriteRelease = nil
  }

  func writtenBytes() -> Data { written }
  func maximumConcurrentWrites() -> Int { maximumActiveWrites }
}

private actor CloseReleasedWriteConnection: SSHTCPConnection {
  private var writeStarted = false
  private var writeStartWaiters: [CheckedContinuation<Void, Never>] = []
  private var writeRelease: CheckedContinuation<Void, Never>?

  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    [.writable]
  }

  func readSome(maximumBytes: Int) async throws -> Data? { Data() }

  func writeSome(_ bytes: Data) async throws -> Int {
    writeStarted = true
    let waiters = writeStartWaiters
    writeStartWaiters.removeAll()
    for waiter in waiters { waiter.resume() }
    await withCheckedContinuation { continuation in
      writeRelease = continuation
    }
    return bytes.count
  }

  func close() async {
    writeRelease?.resume()
    writeRelease = nil
  }

  func waitUntilWriteStarts() async {
    guard !writeStarted else { return }
    await withCheckedContinuation { continuation in
      writeStartWaiters.append(continuation)
    }
  }
}

private struct ReversingCredential: SSHPublicKeyCredential {
  let algorithm = "ssh-ed25519"
  let publicKeyBytes = Data([0, 1])

  func sign(_ payload: Data) async throws -> Data {
    Data(payload.reversed())
  }
}

private final class CancellationIgnoringCredential: SSHPublicKeyCredential, @unchecked Sendable {
  let algorithm = "ssh-ed25519"
  let publicKeyBytes = Data([0, 1])
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Data, Never>?
  private var retired = false

  var isWaiting: Bool { lock.withLock { continuation != nil } }
  var isRetired: Bool { lock.withLock { retired } }

  func sign(_ payload: Data) async throws -> Data {
    await withCheckedContinuation { continuation in
      lock.withLock { self.continuation = continuation }
    }
  }

  func release() {
    let continuation = lock.withLock {
      defer { self.continuation = nil }
      return self.continuation
    }
    continuation?.resume(returning: Data([1]))
  }

  func retire() {
    lock.withLock { retired = true }
  }
}

private actor EOFConnection: SSHTCPConnection {
  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    interests
  }

  func readSome(maximumBytes: Int) async throws -> Data? { nil }
  func writeSome(_ bytes: Data) async throws -> Int { bytes.count }
  func close() async {}
}

private struct LifecycleResolver: SSHNetworkResolver {
  func resolve(hostname: String, port: UInt16) async throws -> [SSHResolvedEndpoint] {
    [
      try SSHResolvedEndpoint(
        addressFamily: .ipv4,
        addressBytes: Data([127, 0, 0, 1]),
        port: port
      )
    ]
  }
}

private struct SuspendedResolver: SSHNetworkResolver {
  func resolve(hostname: String, port: UInt16) async throws -> [SSHResolvedEndpoint] {
    try await Task.sleep(for: .seconds(60))
    return []
  }
}

private actor CancellationIgnoringResolver: SSHNetworkResolver {
  private var continuation: CheckedContinuation<[SSHResolvedEndpoint], Never>?
  private(set) var wasReleased = false

  var isWaiting: Bool { continuation != nil }

  func resolve(hostname: String, port: UInt16) async throws -> [SSHResolvedEndpoint] {
    await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
  }

  func release() {
    wasReleased = true
    continuation?.resume(returning: [])
    continuation = nil
  }
}

private struct LifecycleConnector: SSHTCPConnector {
  func connect(to endpoint: SSHResolvedEndpoint) async throws -> any SSHTCPConnection {
    EOFConnection()
  }
}

private struct ImmediateLifecycleConnector: SSHTCPConnector {
  let connection: any SSHTCPConnection

  func connect(to endpoint: SSHResolvedEndpoint) async throws -> any SSHTCPConnection {
    connection
  }
}

private actor LateConnectorConnection: SSHTCPConnection {
  private(set) var closeCount = 0

  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    interests
  }

  func readSome(maximumBytes: Int) async throws -> Data? { nil }
  func writeSome(_ bytes: Data) async throws -> Int { bytes.count }
  func close() async { closeCount += 1 }
}

private actor CancellationIgnoringConnector: SSHTCPConnector {
  private let connection: any SSHTCPConnection
  private var continuation: CheckedContinuation<Void, Never>?

  init(connection: any SSHTCPConnection) {
    self.connection = connection
  }

  var isWaiting: Bool { continuation != nil }

  func connect(to endpoint: SSHResolvedEndpoint) async throws -> any SSHTCPConnection {
    await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
    return connection
  }

  func release() {
    continuation?.resume()
    continuation = nil
  }
}

private actor CancellationIgnoringTeardownConnection: SSHTCPConnection {
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private(set) var closeCount = 0
  private(set) var writeCount = 0

  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    await suspendUntilReleased()
    return interests
  }

  func readSome(maximumBytes: Int) async throws -> Data? {
    await suspendUntilReleased()
    return nil
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    writeCount += 1
    return bytes.count
  }

  func close() async {
    closeCount += 1
    await suspendUntilReleased()
  }

  func release() {
    let continuations = waiters
    waiters.removeAll()
    for continuation in continuations { continuation.resume() }
  }

  private func suspendUntilReleased() async {
    await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }
}

private final class RetainedOwnedOperation: LibSSH2OwnedAsyncOperation, @unchecked Sendable {
  let identifier = UUID()

  private let lock = NSLock()
  private var cancellations = 0

  var cancelCount: Int { lock.withLock { cancellations } }

  func cancel() {
    lock.withLock { cancellations += 1 }
  }
}

private actor SaturatedCloseConnection: SSHTCPConnection {
  private var readinessStarted = false
  private var readinessReturned = false
  private var readinessRelease: CheckedContinuation<Void, Never>?
  private var readinessStartWaiters: [CheckedContinuation<Void, Never>] = []
  private var readinessReturnWaiters: [CheckedContinuation<Void, Never>] = []
  private(set) var closeCount = 0
  private(set) var readCount = 0
  private(set) var writeCount = 0

  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    readinessStarted = true
    let startWaiters = readinessStartWaiters
    readinessStartWaiters.removeAll()
    for waiter in startWaiters { waiter.resume() }
    await withCheckedContinuation { continuation in
      readinessRelease = continuation
    }
    readinessReturned = true
    let returnWaiters = readinessReturnWaiters
    readinessReturnWaiters.removeAll()
    for waiter in returnWaiters { waiter.resume() }
    return interests
  }

  func readSome(maximumBytes: Int) async throws -> Data? {
    readCount += 1
    return nil
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    writeCount += 1
    return bytes.count
  }

  func close() async { closeCount += 1 }

  func waitUntilReadinessStarts() async {
    guard !readinessStarted else { return }
    await withCheckedContinuation { continuation in
      readinessStartWaiters.append(continuation)
    }
  }

  func releaseReadiness() {
    readinessRelease?.resume()
    readinessRelease = nil
  }

  func waitUntilReadinessReturns() async {
    guard !readinessReturned else { return }
    await withCheckedContinuation { continuation in
      readinessReturnWaiters.append(continuation)
    }
  }
}

private struct RejectingHostPolicy: SSHHostKeyPolicy {
  func evaluate(_ input: SSHHostKeyPolicyInput) async throws -> SSHHostKeyDecision {
    .rejectPolicy
  }
}

private enum LifecycleFixtureError: Error { case unavailable }

private struct UnavailableCredentialProvider: SSHCredentialProvider {
  func credential(for request: SSHCredentialRequest) async throws
    -> any SSHPublicKeyCredential
  {
    throw LifecycleFixtureError.unavailable
  }
}

private struct LifecycleIdentities: SSHIdentityGenerator {
  func makeLaneIdentity() -> SSHLaneIdentity { SSHLaneIdentity(rawValue: UUID()) }
  func makeSessionIdentity() -> SSHSessionIdentity { SSHSessionIdentity(rawValue: UUID()) }
  func makeChannelIdentity() -> SSHChannelIdentity { SSHChannelIdentity(rawValue: UUID()) }
}

private struct SilentSSHLogger: SSHTransportLogger {
  func log(level: TunnelLogLevel, event: SSHTransportEvent) async {}
}

private struct SilentSSHObserver: SSHTransportObserver {
  func observe(_ event: SSHTransportEvent) async {}
}

private struct SilentSSHMetrics: SSHTransportMetricsSink {
  func record(_ update: SSHMetricUpdate) async {}
}

private func lifecycleDependencies(
  resolver: any SSHNetworkResolver = LifecycleResolver(),
  connector: any SSHTCPConnector = LifecycleConnector()
) throws -> SSHTransportDependencies {
  SSHTransportDependencies(
    resolver: resolver,
    connector: connector,
    hostKeyPolicy: RejectingHostPolicy(),
    credentialProvider: UnavailableCredentialProvider(),
    clock: ContinuousTunnelClock(),
    cancellation: TaskCancellationChecker(),
    logger: SilentSSHLogger(),
    observer: SilentSSHObserver(),
    metrics: SilentSSHMetrics(),
    identityGenerator: LifecycleIdentities()
  )
}

private func lifecycleConfiguration() throws -> SSHConnectionConfiguration {
  let short = Duration.milliseconds(50)
  return try SSHConnectionConfiguration(
    canonicalHostname: "fixture.invalid",
    endpoint: TunnelEndpoint(host: "fixture.invalid", port: 22),
    username: "fixture",
    profileReference: TunnelConfigurationReference(
      profileIdentifier: OpaqueProfileIdentifier(UUID())
    ),
    credentialReference: SSHCredentialReference(rawValue: "keychain.fixture"),
    credentialGeneration: 1,
    trustRecordReference: nil,
    algorithms: SSHAlgorithmPolicy(
      keyExchange: ["curve25519-sha256"],
      hostKey: ["ssh-ed25519"],
      cipher: ["aes256-ctr"],
      mac: ["hmac-sha2-256"]
    ),
    timeouts: SSHTimeoutPolicy(
      resolution: short,
      tcpConnect: short,
      initialKeyExchange: short,
      hostDecision: short,
      credentialLookup: short,
      authentication: short,
      channelOpen: short,
      writeCreditWait: short,
      explicitRekey: short,
      keepaliveReply: short,
      execExit: short,
      upload: short,
      channelClose: short,
      transportClose: short
    ),
    rekey: SSHRekeyPolicy(
      protectedByteThresholdPerDirection: 1_024,
      elapsedTimeThreshold: .seconds(60),
      timeout: short
    ),
    keepalive: SSHKeepalivePolicy(
      interval: .seconds(60),
      replyTimeout: short,
      allowedConsecutiveMisses: 1
    )
  )
}
