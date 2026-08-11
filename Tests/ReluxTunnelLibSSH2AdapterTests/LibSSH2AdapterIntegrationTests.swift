import CryptoKit
import Darwin
import Foundation
import ReluxLibSSH2
import ReluxTunnelCore
import Synchronization
import Testing

@testable import ReluxTunnelLibSSH2Adapter

@Suite("libssh2 adapter loopback conformance", .serialized)
struct LibSSH2AdapterIntegrationTests {
  @Test("every untrusted host stops before credentials and destination channels")
  func mandatoryHostPolicyOrdering() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let exactApproved = adapterTrustRecord(keyBytes: server.hostKeyBlob, state: .approved)
    let exactRevoked = adapterTrustRecord(keyBytes: server.hostKeyBlob, state: .revoked)
    let changed = adapterTrustRecord(
      keyBytes: adapterEd25519WireKey(repeating: 0xA5),
      state: .approved
    )
    let capabilities = LibSSH2TransportFactory().capabilities.hostKeyAlgorithms
    let cases: [(SSHTransportErrorCode, any SSHHostKeyPolicy)] = [
      (
        .hostTrustRequired,
        try SSHApprovedHostIdentityPolicy(
          snapshot: adapterSnapshot(port: server.port, records: []),
          adapterHostKeyAlgorithms: capabilities
        )
      ),
      (
        .hostKeyChanged,
        try SSHApprovedHostIdentityPolicy(
          snapshot: adapterSnapshot(port: server.port, records: [changed]),
          adapterHostKeyAlgorithms: capabilities
        )
      ),
      (
        .hostIdentityRevoked,
        try SSHApprovedHostIdentityPolicy(
          snapshot: adapterSnapshot(port: server.port, records: [exactRevoked]),
          adapterHostKeyAlgorithms: capabilities
        )
      ),
      (
        .hostKeyAlgorithmRejected,
        try SSHApprovedHostIdentityPolicy(
          snapshot: adapterSnapshot(port: server.port, records: [exactApproved]),
          adapterHostKeyAlgorithms: []
        )
      ),
      (
        .hostCanonicalMismatch,
        try SSHApprovedHostIdentityPolicy(
          snapshot: adapterSnapshot(
            port: server.port,
            canonicalHost: "other.invalid",
            records: [exactApproved]
          ),
          adapterHostKeyAlgorithms: capabilities
        )
      ),
      (
        .hostKeyMalformed,
        FixedDecisionHostPolicy(decision: .rejectMalformed)
      ),
    ]

    for (expectedCode, policy) in cases {
      let credentialProvider = CountingCredentialProvider(credential: credential)
      let dependencies = SSHTransportDependencies(
        resolver: FixtureResolver(),
        connector: FixtureConnector(port: server.port),
        hostKeyPolicy: policy,
        credentialProvider: credentialProvider,
        clock: ContinuousTunnelClock(),
        cancellation: TaskCancellationChecker(),
        logger: FixtureLogger(),
        observer: FixtureObserver(),
        metrics: FixtureMetrics(),
        identityGenerator: FixtureIdentities()
      )
      let transport =
        try await LibSSH2TransportFactory().makeTransport(
          lane: SSHLaneIdentity(rawValue: UUID()),
          dependencies: dependencies
        ) as! LibSSH2Transport

      do {
        _ = try await transport.connect(configuration: fixtureConfiguration(port: server.port))
        Issue.record("untrusted host unexpectedly connected")
      } catch let error as SSHTransportError {
        #expect(error.code == expectedCode)
        #expect(error.phase == .hostDecision)
        #expect(error.retryDisposition == .afterConfigurationChange)
      }
      let counters = await transport.snapshot().counters
      #expect(await credentialProvider.invocationCount == 0)
      #expect(counters.authenticationAttempts == 0)
      #expect(counters.directChannelsOpened == 0)
      #expect(counters.execChannelsOpened == 0)
    }
  }

  @Test("caller cancellation is scoped and idle reads have no implicit timeout")
  func operationScopedReadCancellationWithoutIdleTimeout() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let clock = ManualFixtureClock()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace(),
          clock: clock
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(
      configuration: fixtureConfiguration(
        port: server.port,
        writeCreditWait: .milliseconds(300)
      )
    )

    let cancelledChannel = try await transport.openExecChannel(
      request: SSHExecRequest(command: "sleep 2"),
      policy: fixtureChannelPolicy()
    )
    let cancelledRead = Task { try await cancelledChannel.read(maximumBytes: 1) }
    await waitForPendingReads(1, transport: transport)
    cancelledRead.cancel()
    do {
      _ = try await cancelledRead.value
      Issue.record("cancelled read unexpectedly completed", sourceLocation: #_sourceLocation)
    } catch let error as SSHTransportError {
      #expect(error.code == .cancelled)
      #expect(error.scope == .channel(cancelledChannel.identity))
      #expect(error.retryDisposition == .sameChannelOperation)
      #expect(!error.requiresTeardown)
    }
    await cancelledChannel.cancel()

    let idleChannel = try await transport.openExecChannel(
      request: SSHExecRequest(command: "sleep 2"),
      policy: fixtureChannelPolicy()
    )
    let idleRead = Task { try await idleChannel.read(maximumBytes: 1) }
    await waitForPendingReads(1, transport: transport)
    clock.advance(by: .seconds(1))
    for _ in 0..<100 { await Task.yield() }
    #expect(await transport.snapshot().gauges.pendingReads == 1)
    idleRead.cancel()
    await #expect(throws: SSHTransportError.self) { _ = try await idleRead.value }
    await idleChannel.cancel()

    let sibling = try await transport.openExecChannel(
      request: SSHExecRequest(command: "printf sibling-alive"),
      policy: fixtureChannelPolicy()
    )
    #expect(try await readAll(sibling) == Data("sibling-alive".utf8))
    await sibling.close()
    #expect(await transport.snapshot().connectionState == .ready)
    await transport.close()
  }

  @Test("rekey callers coalesce, caller cancellation detaches, and opens keep their deadline")
  func rekeyCoalescingAndOpenScheduling() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let observer = SuspendingRekeyObserver()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace(),
          observer: observer
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(
      configuration: fixtureConfiguration(
        port: server.port,
        channelOpen: .milliseconds(300)
      )
    )

    let cancelledCaller = Task { try await transport.requestRekey(reason: .manual) }
    await observer.waitUntilRekeyStarts()
    let coalescedCaller = Task { try await transport.requestRekey(reason: .test) }
    await Task.yield()
    cancelledCaller.cancel()
    do {
      try await cancelledCaller.value
      Issue.record("cancelled rekey caller unexpectedly stayed attached")
    } catch let error as SSHTransportError {
      #expect(error.code == .cancelled)
      #expect(error.phase == .rekey)
      #expect(error.scope == .operation)
      #expect(!error.requiresTeardown)
    }

    do {
      _ = try await transport.openExecChannel(
        request: SSHExecRequest(command: "printf too-late"),
        policy: fixtureChannelPolicy()
      )
      Issue.record("queued open exceeded its deadline", sourceLocation: #_sourceLocation)
    } catch let error as SSHTransportError {
      #expect(error.code == .timedOut)
      #expect(error.phase == .channelOpen)
      #expect(error.scope == .operation)
      #expect(!error.requiresTeardown)
    }

    let waitingOpen = Task {
      try await transport.openExecChannel(
        request: SSHExecRequest(command: "printf after-rekey"),
        policy: fixtureChannelPolicy()
      )
    }
    let deferredKeepalive = Task { try await transport.sendKeepalive() }
    for _ in 0..<200 {
      if await transport.snapshot().gauges.pendingChannelOpens == 1 { break }
      await Task.yield()
    }
    #expect(await transport.snapshot().gauges.pendingChannelOpens == 1)
    await observer.resumeRekey()
    try await coalescedCaller.value
    #expect(try await deferredKeepalive.value == .unsupported)
    let channel = try await waitingOpen.value
    #expect(try await readAll(channel) == Data("after-rekey".utf8))
    await channel.close()
    let snapshot = await transport.snapshot()
    #expect(snapshot.connectionState == .ready)
    #expect(snapshot.counters.rekeysSucceeded == 1)
    #expect(snapshot.counters.explicitRekeys == 2)
    #expect(snapshot.counters.keepalivesSent == 1)
    await transport.close()
  }

  @Test("authentication timeout cancels and retires the external signer")
  func authenticationTimeoutCancelsSigner() async throws {
    let key = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: key.authorizedKey)
    defer { server.stop() }
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: SuspendedSigningCredential(base: key),
          trace: AdapterFixtureTrace()
        )
      ) as! LibSSH2Transport

    do {
      _ = try await transport.connect(
        configuration: fixtureConfiguration(
          port: server.port,
          authentication: .milliseconds(100)
        )
      )
      Issue.record("suspended signer exceeded authentication timeout")
    } catch let error as SSHTransportError {
      #expect(error.code == .timedOut)
      #expect(error.phase == .authentication)
      #expect(error.requiresTeardown)
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

  @Test("rekey deadline starts before admission to the session gate")
  func rekeyAdmissionUsesBoundedDeadline() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let clock = ManualFixtureClock()
    let observer = SuspendingChannelOpenedObserver()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace(),
          observer: observer,
          clock: clock
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(
      configuration: fixtureConfiguration(
        port: server.port,
        explicitRekey: .seconds(5),
        rekeyTimeout: .milliseconds(200)
      )
    )

    let heldOpen = Task {
      try await transport.openExecChannel(
        request: SSHExecRequest(command: "printf held-open"),
        policy: fixtureChannelPolicy()
      )
    }
    await observer.waitUntilChannelOpens()
    let rekey = Task { try await transport.requestRekey(reason: .manual) }
    for _ in 0..<200 where !clock.hasPendingSleep(within: .seconds(1)) {
      await Task.yield()
    }
    #expect(clock.hasPendingSleep(within: .seconds(1)))
    clock.advance(by: .seconds(1))
    do {
      try await rekey.value
      Issue.record("rekey exceeded its pre-admission deadline")
    } catch let error as SSHTransportError {
      #expect(error.code == .timedOut)
      #expect(error.phase == .rekey)
      #expect(error.scope == .operation)
      #expect(!error.requiresTeardown)
    }

    await observer.resumeChannelOpen()
    _ = try? await heldOpen.value
    for _ in 0..<200 {
      if await transport.snapshot().connectionState == .closed { break }
      await Task.yield()
    }
    #expect(await transport.snapshot().connectionState == .closed)
  }

  @Test("automatic keepalive defers behind KEX without consuming its reply deadline")
  func automaticKeepaliveSurvivesLongRekey() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let clock = ManualFixtureClock()
    let observer = SuspendingRekeyObserver()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace(),
          observer: observer,
          clock: clock
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(
      configuration: fixtureConfiguration(
        port: server.port,
        rekeyTimeout: .seconds(2),
        keepaliveReply: .milliseconds(50),
        keepaliveInterval: .milliseconds(100)
      )
    )

    let rekey = Task { try await transport.requestRekey(reason: .manual) }
    await observer.waitUntilRekeyStarts()
    while !clock.hasPendingSleep(within: .milliseconds(100)) { await Task.yield() }
    clock.advance(by: .milliseconds(100))
    for _ in 0..<200 { await Task.yield() }
    clock.advance(by: .milliseconds(200))
    for _ in 0..<200 { await Task.yield() }
    #expect((await transport.snapshot()).connectionState == .rekeying)
    #expect((await transport.snapshot()).counters.keepalivesSent == 0)

    await observer.resumeRekey()
    try await rekey.value
    for _ in 0..<500 {
      if (await transport.snapshot()).counters.keepalivesSent == 1 { break }
      await Task.yield()
    }
    #expect((await transport.snapshot()).counters.keepalivesSent == 1)

    while !clock.hasPendingSleep(within: .milliseconds(100)) { await Task.yield() }
    clock.advance(by: .milliseconds(100))
    for _ in 0..<500 {
      if (await transport.snapshot()).counters.keepalivesSent == 2 { break }
      await Task.yield()
    }
    #expect((await transport.snapshot()).counters.keepalivesSent == 2)
    await transport.close()
  }

  @Test("same-channel writes preserve exact arguments across EAGAIN")
  func concurrentSameChannelWrites() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let echo = try LoopbackEchoServer()
    defer { echo.stop() }
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 8 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace()
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(configuration: fixtureConfiguration(port: server.port))
    let channel = try await transport.openDirectTCPIP(
      destination: TunnelEndpoint(host: "127.0.0.1", port: echo.port),
      originator: TunnelEndpoint(host: "127.0.0.1", port: 42_424),
      policy: fixtureChannelPolicy()
    )
    let completions = WriteCompletionOrder()
    let payloads = (0..<4).map { Data(repeating: UInt8(0x41 + $0), count: 4 * 1_024) }
    let writes = payloads.enumerated().map { index, payload in
      Task {
        let count = try await channel.writeSome(payload)
        await completions.append(index: index, count: count)
      }
    }
    for _ in 0..<200 {
      if await transport.snapshot().gauges.pendingWrites > 0 { break }
      await Task.yield()
    }
    #expect(await transport.snapshot().gauges.pendingWrites > 0)
    let eof = Task { try await channel.finishWriting() }
    for write in writes { try await write.value }
    try await eof.value
    let expected = await completions.expectedBytes(from: payloads)
    var received = Data()
    while received.count < expected.count {
      received.append(
        try #require(try await channel.read(maximumBytes: expected.count - received.count))
      )
    }
    #expect(received == expected)
    await channel.close()
    await transport.close()
  }

  @Test("credential algorithms outside the caller allowlist fail before authentication")
  func disallowedCredentialAlgorithm() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let transport = try await LibSSH2TransportFactory().makeTransport(
      lane: SSHLaneIdentity(rawValue: UUID()),
      dependencies: fixtureDependencies(
        port: server.port,
        credential: AlgorithmOverrideCredential(
          base: credential,
          algorithm: "rsa-sha2-256"
        ),
        trace: AdapterFixtureTrace()
      )
    )
    do {
      _ = try await transport.connect(
        configuration: fixtureConfiguration(
          port: server.port,
          hostKeyAlgorithms: ["ssh-ed25519", "ecdsa-sha2-nistp256"]
        )
      )
      Issue.record("disallowed user-key algorithm reached authentication")
    } catch let error as SSHTransportError {
      #expect(error.code == .authenticationKeyAlgorithmUnavailable)
      #expect(error.phase == .authentication)
    }
    await transport.close()
  }

  @Test("exec and upload timeouts reset their channel and preserve siblings")
  func channelScopedFailureCleanup() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace()
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(
      configuration: fixtureConfiguration(
        port: server.port,
        execExit: .milliseconds(100),
        upload: .milliseconds(100)
      )
    )

    let firstSibling = try await transport.openExecChannel(
      request: SSHExecRequest(command: "printf first-sibling"),
      policy: fixtureChannelPolicy()
    )
    #expect(try await readAll(firstSibling) == Data("first-sibling".utf8))
    await firstSibling.close()

    let slowExec = try await transport.openExecChannel(
      request: SSHExecRequest(command: "sleep 2"),
      policy: fixtureChannelPolicy()
    )
    do {
      _ = try await slowExec.waitForExit()
      Issue.record("exec exit unexpectedly beat its deadline")
    } catch let error as SSHTransportError {
      #expect(error.code == .timedOut)
      #expect(error.phase == .execExit)
      #expect(error.scope == .channel(slowExec.identity))
      #expect(!error.requiresTeardown)
    }

    let secondSibling = try await transport.openExecChannel(
      request: SSHExecRequest(command: "printf second-sibling"),
      policy: fixtureChannelPolicy()
    )
    #expect(try await readAll(secondSibling) == Data("second-sibling".utf8))
    await secondSibling.close()

    let upload = try SSHExecUploadRequest(
      exec: SSHExecRequest(command: "cat >/dev/null"),
      source: SuspendedUploadSource(),
      channelPolicy: fixtureChannelPolicy(),
      chunkBytes: 1_024
    )
    do {
      _ = try await transport.upload(upload)
      Issue.record("upload source unexpectedly beat its deadline")
    } catch let error as SSHTransportError {
      #expect(error.code == .timedOut)
      #expect(error.phase == .uploadSource)
      #expect(error.scope == .operation)
      #expect(!error.requiresTeardown)
    }

    let sibling = try await transport.openExecChannel(
      request: SSHExecRequest(command: "printf sibling-survived"),
      policy: fixtureChannelPolicy()
    )
    #expect(try await readAll(sibling) == Data("sibling-survived".utf8))
    await sibling.close()
    #expect(await transport.snapshot().connectionState == .ready)
    await transport.close()
  }

  @Test("upload and close deadlines survive a source that ignores cancellation")
  func nonCooperativeUploadSourceTimeout() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace()
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(
      configuration: fixtureConfiguration(port: server.port, upload: .milliseconds(100))
    )
    let baseline = await transport.ownedResourceSnapshot()
    let source = CancellationIgnoringUploadSource()
    let request = try SSHExecUploadRequest(
      exec: SSHExecRequest(command: "cat >/dev/null"),
      source: source,
      channelPolicy: fixtureChannelPolicy(),
      chunkBytes: 1_024
    )

    let upload = Task { try await transport.upload(request) }
    let sourceStarted = await eventually { await source.isWaiting }
    #expect(sourceStarted)
    guard sourceStarted else {
      upload.cancel()
      await transport.close()
      return
    }
    let uploadStarted = ContinuousClock.now
    do {
      _ = try await upload.value
      Issue.record("upload unexpectedly succeeded")
    } catch let error as SSHTransportError {
      #expect(error.code == .timedOut)
      #expect(error.phase == .uploadSource)
      #expect(error.scope == .operation)
    }
    #expect(uploadStarted.duration(to: .now) < .seconds(1))
    #expect(!(await source.wasReleased))
    let sourceIsSoleAdditionalOwner = await eventually {
      (await transport.ownedResourceSnapshot()).automaticTasks == baseline.automaticTasks + 1
    }
    #expect(sourceIsSoleAdditionalOwner)

    let closeStarted = ContinuousClock.now
    await transport.close()
    #expect(closeStarted.duration(to: .now) < .seconds(1))
    #expect((await transport.snapshot()).connectionState == .closed)
    #expect((await transport.ownedResourceSnapshot()).automaticTasks == 1)

    await source.release()
    let returnedToBaseline = await eventually(timeout: .seconds(2)) {
      await transport.ownedResourceSnapshot() == .zero
    }
    #expect(returnedToBaseline)
    #expect(await transport.ownedResourceSnapshot() == .zero)
  }

  @Test("channel-open rejection is operation-scoped and preserves an existing sibling")
  func rejectedOpenPreservesExistingSibling() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let echo = try LoopbackEchoServer()
    defer { echo.stop() }
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace()
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(configuration: fixtureConfiguration(port: server.port))
    let sibling = try await transport.openDirectTCPIP(
      destination: TunnelEndpoint(host: "127.0.0.1", port: echo.port),
      originator: TunnelEndpoint(host: "127.0.0.1", port: 42_426),
      policy: fixtureChannelPolicy()
    )

    do {
      _ = try await transport.openDirectTCPIP(
        destination: TunnelEndpoint(host: "127.0.0.1", port: 9),
        originator: TunnelEndpoint(host: "127.0.0.1", port: 42_425),
        policy: fixtureChannelPolicy()
      )
      Issue.record("direct-tcpip to a closed port unexpectedly opened")
    } catch let error as SSHTransportError {
      #expect(error.code == .channelOpenRejected)
      #expect(error.phase == .channelOpen)
      #expect(error.scope == .operation)
      #expect(error.channelOpenReason == .unsupported)
      #expect(!error.requiresTeardown)
    }

    let payload = Data("sibling-after-rejection".utf8)
    #expect(try await sibling.writeSome(payload) == payload.count)
    #expect(try await sibling.read(maximumBytes: payload.count) == payload)
    await sibling.close()
    #expect(await transport.snapshot().connectionState == .ready)
    await transport.close()
  }

  @Test("socket failure during channel open is privacy-safe and connection-fatal")
  func socketFailureDuringOpenOwnsTeardown() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let fault = SocketFailureController()
    let transport = try await makeFaultableTransport(
      server: server,
      credential: credential,
      fault: fault
    )
    fault.arm()
    await expectConnectionFatal(transport: transport, phase: .channelOpen) {
      _ = try await transport.openExecChannel(
        request: SSHExecRequest(command: "printf never"),
        policy: fixtureChannelPolicy()
      )
    }
  }

  @Test("socket failure during channel read is privacy-safe and connection-fatal")
  func socketFailureDuringReadOwnsTeardown() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let fault = SocketFailureController()
    let transport = try await makeFaultableTransport(
      server: server,
      credential: credential,
      fault: fault
    )
    let channel = try await transport.openExecChannel(
      request: SSHExecRequest(command: "sleep 2"),
      policy: fixtureChannelPolicy()
    )
    fault.arm()
    await expectConnectionFatal(transport: transport, phase: .channelRead) {
      _ = try await channel.read(maximumBytes: 1)
    }
  }

  @Test("socket failure during channel write is privacy-safe and connection-fatal")
  func socketFailureDuringWriteOwnsTeardown() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let echo = try LoopbackEchoServer()
    defer { echo.stop() }
    let fault = SocketFailureController()
    let transport = try await makeFaultableTransport(
      server: server,
      credential: credential,
      fault: fault
    )
    let channel = try await transport.openDirectTCPIP(
      destination: TunnelEndpoint(host: "127.0.0.1", port: echo.port),
      originator: TunnelEndpoint(host: "127.0.0.1", port: 42_427),
      policy: fixtureChannelPolicy()
    )
    fault.arm()
    await expectConnectionFatal(transport: transport, phase: .channelWrite) {
      while true {
        _ = try await channel.writeSome(Data(repeating: 0x41, count: 8 * 1_024))
      }
    }
  }

  @Test("socket failure during manual keepalive is privacy-safe and connection-fatal")
  func socketFailureDuringKeepaliveOwnsTeardown() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let fault = SocketFailureController()
    let transport = try await makeFaultableTransport(
      server: server,
      credential: credential,
      fault: fault
    )
    fault.arm()
    await expectConnectionFatal(transport: transport, phase: .keepalive) {
      _ = try await transport.sendKeepalive()
    }
  }

  @Test("exec-request failure retries EAGAIN free without losing channel ownership")
  func execRequestFailureRetainsPointerUntilFreed() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let fault = ChannelAPIFaultController()
    fault.rejectNextStartup(freeEAGAINCount: 2)
    let transport =
      try await LibSSH2TransportFactory(
        maximumTransportBufferBytes: 64 * 1_024,
        channelAPI: fault.api
      ).makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace()
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(configuration: fixtureConfiguration(port: server.port))

    do {
      _ = try await transport.openExecChannel(
        request: SSHExecRequest(command: "printf rejected"),
        policy: fixtureChannelPolicy()
      )
      Issue.record("injected exec rejection unexpectedly succeeded")
    } catch let error as SSHTransportError {
      #expect(error.code == .execRejected)
      #expect(!error.requiresTeardown)
    }
    #expect(fault.freeCallCount >= 3)
    #expect(fault.freeEAGAINRemaining == 0)
    #expect((await transport.ownedResourceSnapshot()).channels == 0)
    #expect((await transport.snapshot()).connectionState == .ready)
    await transport.close()
  }

  @Test("channel close retries EAGAIN and concurrent close pressure returns tasks to baseline")
  func channelClosePressureReturnsBaseline() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let fault = ChannelAPIFaultController()
    let transport =
      try await LibSSH2TransportFactory(
        maximumTransportBufferBytes: 64 * 1_024,
        channelAPI: fault.api
      ).makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace()
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(configuration: fixtureConfiguration(port: server.port))
    let channel = try await transport.openExecChannel(
      request: SSHExecRequest(command: "printf close-pressure"),
      policy: fixtureChannelPolicy()
    )
    #expect(try await readAll(channel) == Data("close-pressure".utf8))
    _ = try await channel.waitForExit()
    fault.armClose(closeEAGAINCount: 2, freeEAGAINCount: 2)
    let closes = (0..<32).map { _ in Task { await channel.close() } }
    for close in closes { await close.value }
    #expect(fault.closeCallCount >= 3)
    #expect(fault.freeCallCount >= 3)
    #expect(fault.closeEAGAINRemaining == 0)
    #expect(fault.freeEAGAINRemaining == 0)

    let transportCloses = (0..<32).map { _ in Task { await transport.close() } }
    for close in transportCloses { await close.value }
    let resources = await transport.ownedResourceSnapshot()
    #expect(resources == .zero, "residual resources: \(resources)")
  }

  @Test("per-channel operation pressure is rejected at the hard cap")
  func channelOperationPressureIsBounded() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace()
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(configuration: fixtureConfiguration(port: server.port))
    let channel = try await transport.openExecChannel(
      request: SSHExecRequest(command: "cat >/dev/null"),
      policy: fixtureChannelPolicy()
    )
    let exits = (0..<64).map { _ in Task { try await channel.waitForExit() } }
    for _ in 0..<500 {
      if await transport.pendingChannelOperationCount(identity: channel.identity) == 64 { break }
      await Task.yield()
    }
    #expect(await transport.pendingChannelOperationCount(identity: channel.identity) == 64)
    do {
      _ = try await channel.waitForExit()
      Issue.record("operation above the per-channel cap was admitted")
    } catch let error as SSHTransportError {
      #expect(error.code == .resourceLimitExceeded)
      #expect(error.scope == .channel(channel.identity))
      #expect(!error.requiresTeardown)
    }
    await channel.cancel()
    for exit in exits { _ = try? await exit.value }
    await transport.close()
    #expect(await transport.ownedResourceSnapshot() == .zero)
  }

  @Test("successful sessions exercise M0 flows and return resources to baseline")
  func successfulM0FlowsAndLifecycleBaseline() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let echo = try LoopbackEchoServer()
    defer { echo.stop() }
    let factory = LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)

    for iteration in 0..<3 {
      let trace = AdapterFixtureTrace()
      let transport =
        try await factory.makeTransport(
          lane: SSHLaneIdentity(rawValue: UUID()),
          dependencies: fixtureDependencies(
            port: server.port,
            credential: credential,
            trace: trace
          )
        ) as! LibSSH2Transport
      let session = try await transport.connect(
        configuration: fixtureConfiguration(port: server.port))
      #expect(session.hostDecision == .matchAccepted)
      #expect(await trace.events == [.hostPolicy, .credentialLookup])

      if iteration == 0 {
        try await exerciseDirectTCPIP(transport: transport, echoPort: echo.port)
        try await exerciseConcurrentExec(transport: transport)
        try await exerciseUpload(transport: transport)
        try await exerciseServerAndClientRekey(transport: transport)
        #expect(try await transport.sendKeepalive() == .unsupported)
        try await exerciseRepeatedConcurrentCancellation(transport: transport)

        let snapshot = await transport.snapshot()
        #expect(snapshot.connectionState == .ready)
        #expect(snapshot.counters.connectSucceeded == 1)
        #expect(snapshot.counters.authenticationSucceeded == 1)
        #expect(snapshot.counters.directChannelsOpened == 1)
        #expect(snapshot.counters.execChannelsOpened >= 4)
        #expect(snapshot.counters.rekeysSucceeded >= 1)
        #expect(snapshot.counters.keepalivesSent >= 1)
        #expect(snapshot.keyExchangeGeneration == .unsupported)
        #expect(snapshot.counters.serverRekeys == .unsupported)
        #expect(snapshot.gauges.remainingReceiveWindowBytes == .unsupported)
        #expect(snapshot.gauges.lastKeepaliveRTTNanoseconds == .unsupported)
      }

      await transport.close()
      #expect(
        await transport.ownedResourceSnapshot()
          == LibSSH2OwnedResourceSnapshot(
            channels: 0,
            socketOwned: false,
            sessionOwned: false,
            automaticTasks: 0,
            customAllocations: 0,
            bufferedBytes: 0
          ), "iteration \(iteration)")
    }
  }

  @Test("Ed25519 authenticates through the opaque external signer after host approval")
  func ed25519ExternalSignerAuthentication() async throws {
    let recorder = SigningInvocationRecorder()
    let credential = Ed25519FixtureCredential(recorder: recorder)
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let trace = AdapterFixtureTrace()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: trace
        )
      ) as! LibSSH2Transport

    let session = try await transport.connect(
      configuration: fixtureConfiguration(
        port: server.port,
        credentialReference: SSHCredentialReference(rawValue: "keychain.fixture.ed25519")
      )
    )
    #expect(session.hostDecision == .matchAccepted)
    #expect(await trace.events == [.hostPolicy, .credentialLookup])
    #expect(await recorder.invocationCount > 0)

    let channel = try await transport.openExecChannel(
      request: SSHExecRequest(command: "printf ed25519-authenticated"),
      policy: fixtureChannelPolicy()
    )
    #expect(try await readAll(channel) == Data("ed25519-authenticated".utf8))
    await channel.close()
    #expect((await transport.snapshot()).counters.authenticationSucceeded == 1)

    await transport.close()
    #expect(await transport.ownedResourceSnapshot() == .zero)
  }

  @Test("protected-byte threshold rekeys through production KEX and preserves traffic")
  func automaticProtectedByteRekey() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let observer = RecordingRekeyObserver()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace(),
          observer: observer
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(
      configuration: fixtureConfiguration(
        port: server.port,
        protectedByteThresholdPerDirection: 4 * 1_024
      )
    )
    let channel = try await transport.openExecChannel(
      request: SSHExecRequest(command: "cat >/dev/null"),
      policy: fixtureChannelPolicy()
    )

    let triggeringPayload = Data(repeating: 0x42, count: 6 * 1_024)
    #expect(try await channel.writeSome(triggeringPayload) == triggeringPayload.count)
    #expect(
      await eventually(timeout: .seconds(3)) {
        guard await observer.containsSucceeded(.client(.byteThreshold)) else { return false }
        return (await transport.snapshot()).connectionState == .ready
      }
    )
    let postRekeyPayload = Data("after-byte-rekey".utf8)
    #expect(try await channel.writeSome(postRekeyPayload) == postRekeyPayload.count)

    let snapshot = await transport.snapshot()
    #expect(snapshot.connectionState == .ready)
    #expect(snapshot.counters.clientByteRekeys == 1)
    #expect(snapshot.counters.rekeysSucceeded == 1)
    #expect(await observer.containsTriggered(.client(.byteThreshold)))

    await channel.cancel()
    await transport.close()
    #expect(await transport.ownedResourceSnapshot() == .zero)
  }

  @Test("elapsed-time threshold rekeys through production KEX and preserves traffic")
  func automaticElapsedTimeRekey() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let echo = try LoopbackEchoServer()
    defer { echo.stop() }
    let clock = ManualFixtureClock()
    let observer = RecordingRekeyObserver()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace(),
          observer: observer,
          clock: clock
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(
      configuration: fixtureConfiguration(
        port: server.port,
        elapsedTimeThreshold: .milliseconds(100)
      )
    )
    let channel = try await transport.openDirectTCPIP(
      destination: TunnelEndpoint(host: "127.0.0.1", port: echo.port),
      originator: TunnelEndpoint(host: "127.0.0.1", port: 43_002),
      policy: fixtureChannelPolicy()
    )
    try await assertEchoRoundTrip(Data("before-time-rekey".utf8), channel: channel)

    #expect(
      await eventually {
        clock.hasPendingSleep(within: .milliseconds(100))
      }
    )
    clock.advance(by: .milliseconds(100))
    #expect(
      await eventually(timeout: .seconds(3)) {
        guard await observer.containsSucceeded(.client(.timeThreshold)) else { return false }
        return (await transport.snapshot()).connectionState == .ready
      }
    )
    try await assertEchoRoundTrip(Data("after-time-rekey".utf8), channel: channel)

    let snapshot = await transport.snapshot()
    #expect(snapshot.connectionState == .ready)
    #expect(snapshot.counters.clientTimeRekeys == 1)
    #expect(snapshot.counters.rekeysSucceeded == 1)
    #expect(await observer.containsTriggered(.client(.timeThreshold)))

    await channel.cancel()
    await transport.close()
    #expect(await transport.ownedResourceSnapshot() == .zero)
  }

  @Test("connected close retires tasks after a cancellation-ignoring socket deadline")
  func connectedNonCooperativeSocketCloseEventuallyRestoresBaseline() async throws {
    let credential = P256FixtureCredential()
    let server = try LoopbackSSHD(publicKey: credential.authorizedKey)
    defer { server.stop() }
    let closeController = CancellationIgnoringCloseController()
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace(),
          connector: CancellationIgnoringCloseFixtureConnector(
            port: server.port,
            controller: closeController
          )
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(
      configuration: fixtureConfiguration(
        port: server.port,
        transportClose: .milliseconds(50)
      )
    )
    #expect((await transport.ownedResourceSnapshot()).automaticTasks >= 2)

    let started = ContinuousClock.now
    await transport.close()
    #expect(started.duration(to: .now) < .seconds(1))
    #expect(await closeController.closeCount == 1)
    let detached = await transport.ownedResourceSnapshot()
    #expect(!detached.socketOwned)
    #expect(!detached.sessionOwned)
    #expect(detached.automaticTasks > 0)

    let repeatedCloseStarted = ContinuousClock.now
    await transport.close()
    #expect(repeatedCloseStarted.duration(to: .now) < .seconds(1))
    #expect(await closeController.closeCount == 1)

    await closeController.releaseClose()
    await closeController.waitUntilCloseReturns()
    for _ in 0..<1_000 {
      if await transport.ownedResourceSnapshot() == .zero { break }
      await Task.yield()
    }
    #expect(await closeController.closeCount == 1)
    #expect(await closeController.closeReturnCount == 1)
    #expect(await transport.ownedResourceSnapshot() == .zero)
  }

  private func exerciseDirectTCPIP(transport: LibSSH2Transport, echoPort: UInt16) async throws {
    let channel = try await transport.openDirectTCPIP(
      destination: TunnelEndpoint(host: "127.0.0.1", port: echoPort),
      originator: TunnelEndpoint(host: "127.0.0.1", port: 41_414),
      policy: try fixtureChannelPolicy()
    )
    let payload = Data("direct-tcpip-echo".utf8)
    var written = 0
    while written < payload.count {
      written += try await channel.writeSome(Data(payload[written...]))
    }
    var received = Data()
    while received.count < payload.count {
      let next = try #require(try await channel.read(maximumBytes: payload.count - received.count))
      received.append(next)
    }
    #expect(received == payload)
    #expect(await channel.receiveWindow() == .unsupported)
    await channel.close()
  }

  private func assertEchoRoundTrip(
    _ payload: Data,
    channel: any SSHByteChannel
  ) async throws {
    var written = 0
    while written < payload.count {
      written += try await channel.writeSome(Data(payload[written...]))
    }
    var received = Data()
    while received.count < payload.count {
      received.append(
        try #require(try await channel.read(maximumBytes: payload.count - received.count))
      )
    }
    #expect(received == payload)
  }

  private func exerciseConcurrentExec(transport: LibSSH2Transport) async throws {
    async let first = transport.openExecChannel(
      request: SSHExecRequest(command: "printf first"),
      policy: fixtureChannelPolicy()
    )
    async let second = transport.openExecChannel(
      request: SSHExecRequest(command: "printf second"),
      policy: fixtureChannelPolicy()
    )
    let (firstChannel, secondChannel) = try await (first, second)
    async let firstOutput = readAll(firstChannel)
    async let secondOutput = readAll(secondChannel)
    let outputs = try await (firstOutput, secondOutput)
    #expect(outputs.0 == Data("first".utf8))
    #expect(outputs.1 == Data("second".utf8))
    #expect(try await firstChannel.waitForExit() == .notReported)
    #expect(try await secondChannel.waitForExit() == .notReported)
    await firstChannel.close()
    await secondChannel.close()
  }

  private func exerciseUpload(transport: LibSSH2Transport) async throws {
    let payload = Data(repeating: 0x5A, count: 48 * 1_024)
    let request = try SSHExecUploadRequest(
      exec: SSHExecRequest(command: "cat >/dev/null"),
      source: DataUploadSource(payload),
      channelPolicy: fixtureChannelPolicy(),
      chunkBytes: 4 * 1_024
    )
    #expect(try await transport.upload(request) == .notReported)
  }

  private func exerciseServerAndClientRekey(transport: LibSSH2Transport) async throws {
    let channel = try await transport.openExecChannel(
      request: SSHExecRequest(command: "yes r | head -c 131072"),
      policy: fixtureChannelPolicy()
    )
    let bytes = try await readAll(channel)
    #expect(bytes.count == 131_072)
    _ = try await channel.waitForExit()
    await channel.close()
    try await transport.requestRekey(reason: .manual)
  }

  private func exerciseRepeatedConcurrentCancellation(transport: LibSSH2Transport) async throws {
    for iteration in 0..<5 {
      let channel = try await transport.openExecChannel(
        request: SSHExecRequest(command: "sleep 2"),
        policy: fixtureChannelPolicy()
      )
      let pendingRead = Task { try await channel.read(maximumBytes: 1) }
      for _ in 0..<200 {
        if await transport.snapshot().gauges.pendingReads == 1 { break }
        await Task.yield()
      }
      #expect(await transport.snapshot().gauges.pendingReads == 1, "iteration \(iteration)")
      await channel.cancel()
      do {
        _ = try await pendingRead.value
        Issue.record(
          "concurrent channel read unexpectedly completed", sourceLocation: #_sourceLocation)
      } catch let error as SSHTransportError {
        #expect(error.code == .cancelled, "iteration \(iteration)")
        #expect(error.phase == .channelRead, "iteration \(iteration)")
      }
      #expect(await transport.snapshot().gauges.pendingReads == 0, "iteration \(iteration)")
    }
  }

  private func readAll(_ channel: any SSHExecChannel) async throws -> Data {
    var result = Data()
    while let bytes = try await channel.read(maximumBytes: 16 * 1_024) {
      result.append(bytes)
    }
    return result
  }

  private func waitForPendingReads(_ count: Int64, transport: LibSSH2Transport) async {
    for _ in 0..<200 {
      if await transport.snapshot().gauges.pendingReads == count { return }
      await Task.yield()
    }
  }

  private func makeFaultableTransport(
    server: LoopbackSSHD,
    credential: P256FixtureCredential,
    fault: SocketFailureController
  ) async throws -> LibSSH2Transport {
    let transport =
      try await LibSSH2TransportFactory(maximumTransportBufferBytes: 64 * 1_024)
      .makeTransport(
        lane: SSHLaneIdentity(rawValue: UUID()),
        dependencies: fixtureDependencies(
          port: server.port,
          credential: credential,
          trace: AdapterFixtureTrace(),
          connector: FaultInjectingFixtureConnector(port: server.port, controller: fault)
        )
      ) as! LibSSH2Transport
    _ = try await transport.connect(configuration: fixtureConfiguration(port: server.port))
    return transport
  }

  private func expectConnectionFatal(
    transport: LibSSH2Transport,
    phase: SSHTransportPhase,
    operation: () async throws -> Void
  ) async {
    do {
      try await operation()
      Issue.record("injected socket failure unexpectedly succeeded")
    } catch let error as SSHTransportError {
      #expect(error.code == .connectionLost)
      #expect(error.phase == phase)
      #expect(error.requiresTeardown)
      if case .lane = error.scope {} else { Issue.record("fatal error was not lane-scoped") }
    } catch {
      Issue.record("socket failure escaped privacy-safe mapping")
    }
    #expect((await transport.snapshot()).connectionState == .closed)
    let resources = await transport.ownedResourceSnapshot()
    #expect(resources == .zero, "residual resources: \(resources)")
  }
}

extension LibSSH2OwnedResourceSnapshot {
  static let zero = LibSSH2OwnedResourceSnapshot(
    channels: 0,
    socketOwned: false,
    sessionOwned: false,
    automaticTasks: 0,
    customAllocations: 0,
    bufferedBytes: 0
  )
}

private func eventually(
  timeout: Duration = .seconds(1),
  condition: () async -> Bool
) async -> Bool {
  let deadline = ContinuousClock.now.advanced(by: timeout)
  repeat {
    if await condition() { return true }
    try? await Task.sleep(for: .milliseconds(1))
  } while ContinuousClock.now < deadline
  return await condition()
}

private enum AdapterFixtureEvent: Equatable, Sendable {
  case hostPolicy
  case credentialLookup
}

private actor AdapterFixtureTrace {
  private(set) var events: [AdapterFixtureEvent] = []

  func append(_ event: AdapterFixtureEvent) {
    events.append(event)
  }
}

private struct AcceptingFixtureHostPolicy: SSHHostKeyPolicy {
  let trace: AdapterFixtureTrace

  func evaluate(_ input: SSHHostKeyPolicyInput) async throws -> SSHHostKeyDecision {
    await trace.append(.hostPolicy)
    return .acceptMatch(SSHTrustRecordReference(rawValue: "fixture.trust"))
  }
}

private struct FixtureCredentialProvider: SSHCredentialProvider {
  let credential: any SSHPublicKeyCredential
  let trace: AdapterFixtureTrace

  func credential(for request: SSHCredentialRequest) async throws
    -> any SSHPublicKeyCredential
  {
    await trace.append(.credentialLookup)
    return credential
  }
}

private struct AlgorithmOverrideCredential: SSHPublicKeyCredential {
  let base: P256FixtureCredential
  let algorithm: String

  var publicKeyBytes: Data { base.publicKeyBytes }

  func sign(_ payload: Data) async throws -> Data {
    try await base.sign(payload)
  }
}

private struct SuspendedSigningCredential: SSHPublicKeyCredential {
  let base: P256FixtureCredential

  var algorithm: String { base.algorithm }
  var publicKeyBytes: Data { base.publicKeyBytes }

  func sign(_ payload: Data) async throws -> Data {
    try await Task.sleep(for: .seconds(60))
    return try await base.sign(payload)
  }
}

private struct P256FixtureCredential: SSHPublicKeyCredential {
  let algorithm = "ecdsa-sha2-nistp256"
  let publicKeyBytes: Data
  let authorizedKey: String
  private let privateKey: P256.Signing.PrivateKey

  init() {
    let privateKey = P256.Signing.PrivateKey()
    var blob = Data()
    appendSSHString(Data(algorithm.utf8), to: &blob)
    appendSSHString(Data("nistp256".utf8), to: &blob)
    appendSSHString(privateKey.publicKey.x963Representation, to: &blob)
    self.privateKey = privateKey
    publicKeyBytes = blob
    authorizedKey = "\(algorithm) \(blob.base64EncodedString()) relux-fixture"
  }

  func sign(_ payload: Data) async throws -> Data {
    let raw = try privateKey.signature(for: payload).rawRepresentation
    var result = Data()
    appendSSHString(sshMPInt(Data(raw.prefix(32))), to: &result)
    appendSSHString(sshMPInt(Data(raw.suffix(32))), to: &result)
    return result
  }
}

private actor SigningInvocationRecorder {
  private(set) var invocationCount = 0

  func record() {
    invocationCount += 1
  }
}

private struct Ed25519FixtureCredential: SSHPublicKeyCredential {
  let algorithm = "ssh-ed25519"
  let publicKeyBytes: Data
  let authorizedKey: String
  private let privateKey: Curve25519.Signing.PrivateKey
  private let recorder: SigningInvocationRecorder

  init(recorder: SigningInvocationRecorder) {
    let privateKey = Curve25519.Signing.PrivateKey()
    var blob = Data()
    appendSSHString(Data(algorithm.utf8), to: &blob)
    appendSSHString(privateKey.publicKey.rawRepresentation, to: &blob)
    self.privateKey = privateKey
    self.recorder = recorder
    publicKeyBytes = blob
    authorizedKey = "\(algorithm) \(blob.base64EncodedString()) relux-fixture"
  }

  func sign(_ payload: Data) async throws -> Data {
    await recorder.record()
    return try privateKey.signature(for: payload)
  }
}

private actor DataUploadSource: SSHUploadSource {
  private let data: Data
  private var offset = 0

  init(_ data: Data) {
    self.data = data
  }

  func read(maximumBytes: Int) async throws -> Data? {
    guard offset < data.count else { return nil }
    let count = min(maximumBytes, data.count - offset)
    defer { offset += count }
    return Data(data[offset..<(offset + count)])
  }
}

private actor SuspendedUploadSource: SSHUploadSource {
  func read(maximumBytes: Int) async throws -> Data? {
    try await Task.sleep(for: .seconds(60))
    return nil
  }
}

private actor CancellationIgnoringUploadSource: SSHUploadSource {
  private var continuation: CheckedContinuation<Data?, Never>?
  private(set) var wasReleased = false

  var isWaiting: Bool { continuation != nil }

  func read(maximumBytes: Int) async throws -> Data? {
    await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
  }

  func release() {
    wasReleased = true
    continuation?.resume(returning: nil)
    continuation = nil
  }
}

private struct FixtureResolver: SSHNetworkResolver {
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

private struct FixtureConnector: SSHTCPConnector {
  let port: UInt16

  func connect(to endpoint: SSHResolvedEndpoint) async throws -> any SSHTCPConnection {
    try await Task.detached { try POSIXFixtureConnection.connect(port: port) }.value
  }
}

private final class SocketFailureController: @unchecked Sendable {
  private let armed = Mutex(false)

  func arm() {
    armed.withLock { $0 = true }
  }

  func consume() -> Bool {
    armed.withLock { value in
      defer { value = false }
      return value
    }
  }
}

private struct FaultInjectingFixtureConnector: SSHTCPConnector {
  let port: UInt16
  let controller: SocketFailureController

  func connect(to endpoint: SSHResolvedEndpoint) async throws -> any SSHTCPConnection {
    let connection = try await Task.detached {
      try POSIXFixtureConnection.connect(port: port)
    }.value
    return FaultInjectingFixtureConnection(base: connection, controller: controller)
  }
}

private struct CancellationIgnoringCloseFixtureConnector: SSHTCPConnector {
  let port: UInt16
  let controller: CancellationIgnoringCloseController

  func connect(to endpoint: SSHResolvedEndpoint) async throws -> any SSHTCPConnection {
    let connection = try await Task.detached {
      try POSIXFixtureConnection.connect(port: port)
    }.value
    return CancellationIgnoringCloseFixtureConnection(base: connection, controller: controller)
  }
}

private final class CancellationIgnoringCloseFixtureConnection: SSHTCPConnection,
  @unchecked Sendable
{
  private let base: POSIXFixtureConnection
  private let controller: CancellationIgnoringCloseController

  init(base: POSIXFixtureConnection, controller: CancellationIgnoringCloseController) {
    self.base = base
    self.controller = controller
  }

  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    try await base.waitForReadiness(interests)
  }

  func readSome(maximumBytes: Int) async throws -> Data? {
    try await base.readSome(maximumBytes: maximumBytes)
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    try await base.writeSome(bytes)
  }

  func close() async {
    await controller.beginClose()
    await base.close()
    await controller.finishClose()
  }
}

private actor CancellationIgnoringCloseController {
  private(set) var closeCount = 0
  private(set) var closeReturnCount = 0
  private var releaseContinuation: CheckedContinuation<Void, Never>?
  private var closeReturnWaiters: [CheckedContinuation<Void, Never>] = []

  func beginClose() async {
    closeCount += 1
    await withCheckedContinuation { continuation in
      releaseContinuation = continuation
    }
  }

  func finishClose() {
    closeReturnCount += 1
    let waiters = closeReturnWaiters
    closeReturnWaiters.removeAll()
    for waiter in waiters { waiter.resume() }
  }

  func releaseClose() {
    releaseContinuation?.resume()
    releaseContinuation = nil
  }

  func waitUntilCloseReturns() async {
    guard closeReturnCount == 0 else { return }
    await withCheckedContinuation { continuation in
      closeReturnWaiters.append(continuation)
    }
  }
}

private final class FaultInjectingFixtureConnection: SSHTCPConnection, @unchecked Sendable {
  private let base: POSIXFixtureConnection
  private let controller: SocketFailureController

  init(base: POSIXFixtureConnection, controller: SocketFailureController) {
    self.base = base
    self.controller = controller
  }

  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    if controller.consume() { throw POSIXFixtureError.system(ECONNRESET) }
    return try await base.waitForReadiness(interests)
  }

  func readSome(maximumBytes: Int) async throws -> Data? {
    if controller.consume() { throw POSIXFixtureError.system(ECONNRESET) }
    return try await base.readSome(maximumBytes: maximumBytes)
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    if controller.consume() { throw POSIXFixtureError.system(EPIPE) }
    return try await base.writeSome(bytes)
  }

  func close() async {
    await base.close()
  }
}

private final class ChannelAPIFaultController: @unchecked Sendable {
  private struct State {
    var rejectStartup = false
    var closeEAGAINRemaining = 0
    var freeEAGAINRemaining = 0
    var closeCallCount = 0
    var freeCallCount = 0
  }

  private let state = Mutex(State())

  var api: LibSSH2ChannelAPI {
    let live = LibSSH2ChannelAPI.live
    return LibSSH2ChannelAPI(
      processStartup: { [self] pointer, command in
        let reject = state.withLock { state in
          defer { state.rejectStartup = false }
          return state.rejectStartup
        }
        return reject ? LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED : live.processStartup(pointer, command)
      },
      close: { [self] pointer in
        let inject = state.withLock { state in
          state.closeCallCount += 1
          guard state.closeEAGAINRemaining > 0 else { return false }
          state.closeEAGAINRemaining -= 1
          return true
        }
        return inject ? LIBSSH2_ERROR_EAGAIN : live.close(pointer)
      },
      free: { [self] pointer in
        let inject = state.withLock { state in
          state.freeCallCount += 1
          guard state.freeEAGAINRemaining > 0 else { return false }
          state.freeEAGAINRemaining -= 1
          return true
        }
        return inject ? LIBSSH2_ERROR_EAGAIN : live.free(pointer)
      }
    )
  }

  var closeCallCount: Int { state.withLock(\.closeCallCount) }
  var freeCallCount: Int { state.withLock(\.freeCallCount) }
  var closeEAGAINRemaining: Int { state.withLock(\.closeEAGAINRemaining) }
  var freeEAGAINRemaining: Int { state.withLock(\.freeEAGAINRemaining) }

  func rejectNextStartup(freeEAGAINCount: Int) {
    state.withLock {
      $0.rejectStartup = true
      $0.freeEAGAINRemaining = freeEAGAINCount
    }
  }

  func armClose(closeEAGAINCount: Int, freeEAGAINCount: Int) {
    state.withLock {
      $0.closeEAGAINRemaining = closeEAGAINCount
      $0.freeEAGAINRemaining = freeEAGAINCount
    }
  }
}

private final class POSIXFixtureConnection: SSHTCPConnection, @unchecked Sendable {
  private let lock = NSLock()
  private var descriptor: Int32?

  private init(descriptor: Int32) {
    self.descriptor = descriptor
  }

  static func connect(port: UInt16) throws -> POSIXFixtureConnection {
    let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard descriptor >= 0 else { throw POSIXFixtureError.system(errno) }
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard result == 0 else {
      let code = errno
      Darwin.close(descriptor)
      throw POSIXFixtureError.system(code)
    }
    _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
    var noSignal: Int32 = 1
    _ = setsockopt(
      descriptor,
      SOL_SOCKET,
      SO_NOSIGPIPE,
      &noSignal,
      socklen_t(MemoryLayout.size(ofValue: noSignal))
    )
    return POSIXFixtureConnection(descriptor: descriptor)
  }

  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    guard let descriptor = lock.withLock({ descriptor }) else {
      throw POSIXFixtureError.closed
    }
    return try await Task.detached {
      var descriptorState = pollfd(
        fd: descriptor,
        events: Int16(
          (interests.contains(.readable) ? POLLIN : 0)
            | (interests.contains(.writable) ? POLLOUT : 0)
        ),
        revents: 0
      )
      let result = Darwin.poll(&descriptorState, 1, 100)
      if result < 0, errno != EINTR { throw POSIXFixtureError.system(errno) }
      var ready = Set<SSHTCPReadiness>()
      if descriptorState.revents & Int16(POLLIN | POLLHUP) != 0 { ready.insert(.readable) }
      if descriptorState.revents & Int16(POLLOUT) != 0 { ready.insert(.writable) }
      return ready
    }.value
  }

  func readSome(maximumBytes: Int) async throws -> Data? {
    guard let descriptor = lock.withLock({ descriptor }) else {
      throw POSIXFixtureError.closed
    }
    var bytes = [UInt8](repeating: 0, count: maximumBytes)
    let count = Darwin.recv(descriptor, &bytes, bytes.count, 0)
    if count > 0 { return Data(bytes.prefix(count)) }
    if count == 0 { return nil }
    if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { return Data() }
    throw POSIXFixtureError.system(errno)
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    guard let descriptor = lock.withLock({ descriptor }) else {
      throw POSIXFixtureError.closed
    }
    let count = bytes.withUnsafeBytes {
      Darwin.send(descriptor, $0.baseAddress, $0.count, 0)
    }
    if count > 0 { return count }
    throw POSIXFixtureError.system(errno)
  }

  func close() async {
    let descriptor = lock.withLock { () -> Int32? in
      defer { self.descriptor = nil }
      return self.descriptor
    }
    if let descriptor {
      Darwin.shutdown(descriptor, SHUT_RDWR)
      Darwin.close(descriptor)
    }
  }
}

private enum POSIXFixtureError: Error {
  case closed
  case system(Int32)
}

private struct FixtureIdentities: SSHIdentityGenerator {
  func makeLaneIdentity() -> SSHLaneIdentity { SSHLaneIdentity(rawValue: UUID()) }
  func makeSessionIdentity() -> SSHSessionIdentity { SSHSessionIdentity(rawValue: UUID()) }
  func makeChannelIdentity() -> SSHChannelIdentity { SSHChannelIdentity(rawValue: UUID()) }
}

private struct FixtureLogger: SSHTransportLogger {
  func log(level: TunnelLogLevel, event: SSHTransportEvent) async {}
}

private struct FixtureObserver: SSHTransportObserver {
  func observe(_ event: SSHTransportEvent) async {}
}

private actor SuspendingRekeyObserver: SSHTransportObserver {
  private var rekeyStarted = false
  private var startWaiters: [CheckedContinuation<Void, Never>] = []
  private var rekeyContinuation: CheckedContinuation<Void, Never>?

  func observe(_ event: SSHTransportEvent) async {
    guard case .rekeyStarted = event.kind, !rekeyStarted else { return }
    rekeyStarted = true
    let waiters = startWaiters
    startWaiters.removeAll()
    for waiter in waiters { waiter.resume() }
    await withCheckedContinuation { continuation in
      rekeyContinuation = continuation
    }
  }

  func waitUntilRekeyStarts() async {
    guard !rekeyStarted else { return }
    await withCheckedContinuation { continuation in
      startWaiters.append(continuation)
    }
  }

  func resumeRekey() {
    rekeyContinuation?.resume()
    rekeyContinuation = nil
  }
}

private actor RecordingRekeyObserver: SSHTransportObserver {
  private var triggered: [Set<SSHRekeyReason>] = []
  private var succeeded: [Set<SSHRekeyReason>] = []

  func observe(_ event: SSHTransportEvent) async {
    switch event.kind {
    case .rekeyTriggered(let reasons):
      triggered.append(reasons)
    case .rekeySucceeded(let reasons, _):
      succeeded.append(reasons)
    default:
      break
    }
  }

  func containsTriggered(_ reason: SSHRekeyReason) -> Bool {
    triggered.contains { $0.contains(reason) }
  }

  func containsSucceeded(_ reason: SSHRekeyReason) -> Bool {
    succeeded.contains { $0.contains(reason) }
  }
}

private actor SuspendingChannelOpenedObserver: SSHTransportObserver {
  private var channelOpened = false
  private var openWaiters: [CheckedContinuation<Void, Never>] = []
  private var openContinuation: CheckedContinuation<Void, Never>?

  func observe(_ event: SSHTransportEvent) async {
    guard case .channelOpened = event.kind, !channelOpened else { return }
    channelOpened = true
    let waiters = openWaiters
    openWaiters.removeAll()
    for waiter in waiters { waiter.resume() }
    await withCheckedContinuation { continuation in
      openContinuation = continuation
    }
  }

  func waitUntilChannelOpens() async {
    guard !channelOpened else { return }
    await withCheckedContinuation { continuation in
      openWaiters.append(continuation)
    }
  }

  func resumeChannelOpen() {
    openContinuation?.resume()
    openContinuation = nil
  }
}

private actor WriteCompletionOrder {
  private var completions: [(index: Int, count: Int)] = []

  func append(index: Int, count: Int) {
    completions.append((index, count))
  }

  func expectedBytes(from payloads: [Data]) -> Data {
    var result = Data()
    for completion in completions {
      result.append(payloads[completion.index].prefix(completion.count))
    }
    return result
  }
}

private struct FixtureMetrics: SSHTransportMetricsSink {
  func record(_ update: SSHMetricUpdate) async {}
}

private final class ManualFixtureClock: TunnelClock, @unchecked Sendable {
  private struct Sleep {
    let deadline: ContinuousClock.Instant
    let continuation: CheckedContinuation<Void, any Error>
  }

  private struct State {
    var instant = ContinuousClock().now
    var sleeps: [UUID: Sleep] = [:]
  }

  private let state = Mutex(State())

  func now() -> ContinuousClock.Instant {
    state.withLock(\.instant)
  }

  func sleep(for duration: Duration) async throws {
    let identifier = UUID()
    try Task<Never, Never>.checkCancellation()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let shouldCancel = state.withLock { state in
          if Task<Never, Never>.isCancelled { return true }
          state.sleeps[identifier] = Sleep(
            deadline: state.instant.advanced(by: duration),
            continuation: continuation
          )
          return false
        }
        if shouldCancel { continuation.resume(throwing: CancellationError()) }
      }
    } onCancel: {
      let continuation = self.state.withLock {
        $0.sleeps.removeValue(forKey: identifier)?.continuation
      }
      continuation?.resume(throwing: CancellationError())
    }
  }

  func advance(by duration: Duration) {
    let continuations = state.withLock { state -> [CheckedContinuation<Void, any Error>] in
      state.instant = state.instant.advanced(by: duration)
      let ready = state.sleeps.filter { $0.value.deadline <= state.instant }
      for identifier in ready.keys { state.sleeps.removeValue(forKey: identifier) }
      return ready.values.map(\.continuation)
    }
    for continuation in continuations { continuation.resume() }
  }

  func hasPendingSleep(within duration: Duration) -> Bool {
    state.withLock { state in
      let limit = state.instant.advanced(by: duration)
      return state.sleeps.values.contains { $0.deadline <= limit }
    }
  }
}

private func fixtureDependencies(
  port: UInt16,
  credential: any SSHPublicKeyCredential,
  trace: AdapterFixtureTrace,
  observer: any SSHTransportObserver = FixtureObserver(),
  clock: any TunnelClock = ContinuousTunnelClock(),
  connector: (any SSHTCPConnector)? = nil
) -> SSHTransportDependencies {
  SSHTransportDependencies(
    resolver: FixtureResolver(),
    connector: connector ?? FixtureConnector(port: port),
    hostKeyPolicy: AcceptingFixtureHostPolicy(trace: trace),
    credentialProvider: FixtureCredentialProvider(credential: credential, trace: trace),
    clock: clock,
    cancellation: TaskCancellationChecker(),
    logger: FixtureLogger(),
    observer: observer,
    metrics: FixtureMetrics(),
    identityGenerator: FixtureIdentities()
  )
}

private func fixtureConfiguration(
  port: UInt16,
  hostKeyAlgorithms: [String] = ["ssh-ed25519", "ecdsa-sha2-nistp256"],
  credentialReference: SSHCredentialReference = SSHCredentialReference(
    rawValue: "keychain.fixture.p256"
  ),
  authentication: Duration = .seconds(10),
  channelOpen: Duration = .seconds(10),
  writeCreditWait: Duration = .seconds(10),
  execExit: Duration = .seconds(10),
  upload: Duration = .seconds(10),
  explicitRekey: Duration = .seconds(10),
  rekeyTimeout: Duration = .seconds(10),
  keepaliveReply: Duration = .seconds(10),
  keepaliveInterval: Duration = .seconds(3_600),
  transportClose: Duration = .seconds(10),
  protectedByteThresholdPerDirection: UInt64 = .max,
  elapsedTimeThreshold: Duration = .seconds(3_600)
) throws -> SSHConnectionConfiguration {
  let timeout = Duration.seconds(10)
  return try SSHConnectionConfiguration(
    canonicalHostname: "fixture.local",
    endpoint: TunnelEndpoint(host: "127.0.0.1", port: port),
    username: NSUserName(),
    profileReference: TunnelConfigurationReference(
      profileIdentifier: OpaqueProfileIdentifier(UUID())
    ),
    credentialReference: credentialReference,
    credentialGeneration: 1,
    trustRecordReference: nil,
    algorithms: SSHAlgorithmPolicy(
      keyExchange: ["curve25519-sha256", "curve25519-sha256@libssh.org"],
      hostKey: hostKeyAlgorithms,
      cipher: ["aes256-ctr", "aes128-ctr"],
      mac: ["hmac-sha2-256", "hmac-sha2-512"]
    ),
    timeouts: SSHTimeoutPolicy(
      resolution: timeout,
      tcpConnect: timeout,
      initialKeyExchange: timeout,
      hostDecision: timeout,
      credentialLookup: timeout,
      authentication: authentication,
      channelOpen: channelOpen,
      writeCreditWait: writeCreditWait,
      explicitRekey: explicitRekey,
      keepaliveReply: keepaliveReply,
      execExit: execExit,
      upload: upload,
      channelClose: timeout,
      transportClose: transportClose
    ),
    rekey: SSHRekeyPolicy(
      protectedByteThresholdPerDirection: protectedByteThresholdPerDirection,
      elapsedTimeThreshold: elapsedTimeThreshold,
      timeout: rekeyTimeout
    ),
    keepalive: SSHKeepalivePolicy(
      interval: keepaliveInterval,
      replyTimeout: keepaliveReply,
      allowedConsecutiveMisses: 1
    )
  )
}

private func fixtureChannelPolicy() throws -> SSHChannelPolicy {
  try SSHChannelPolicy(
    initialReceiveWindowBytes: 64 * 1_024,
    consumerReceiveWindowCredit: .unsupported,
    maximumBufferedReadBytes: 16 * 1_024,
    maximumQueuedWriteBytes: 32 * 1_024,
    maximumWriteCallBytes: 8 * 1_024
  )
}

private actor CountingCredentialProvider: SSHCredentialProvider {
  private let credential: any SSHPublicKeyCredential
  private(set) var invocationCount = 0

  init(credential: any SSHPublicKeyCredential) {
    self.credential = credential
  }

  func credential(for request: SSHCredentialRequest) async throws
    -> any SSHPublicKeyCredential
  {
    invocationCount += 1
    return credential
  }
}

private struct FixedDecisionHostPolicy: SSHHostKeyPolicy {
  let decision: SSHHostKeyDecision

  func evaluate(_ input: SSHHostKeyPolicyInput) async throws -> SSHHostKeyDecision {
    decision
  }
}

private func adapterSnapshot(
  port: UInt16,
  canonicalHost: String = "fixture.local",
  records: [SSHHostIdentityRecordV1]
) -> SSHProfileSnapshotV1 {
  SSHProfileSnapshotV1(
    configurationGeneration: 1,
    profileID: OpaqueProfileIdentifier(
      UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    ),
    createdAt: SSHProfileTimestamp("2026-08-11T10:00:00.000Z"),
    updatedAt: SSHProfileTimestamp("2026-08-11T10:00:01.000Z"),
    displayName: "Adapter fixture",
    canonicalHost: SSHProfileCanonicalHost(kind: .dns, value: canonicalHost),
    port: port,
    account: "fixture-account",
    credential: SSHProfileCredentialReferenceV1(
      reference: OpaqueCredentialReference(
        UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
      ),
      generation: 1
    ),
    hostPolicy: SSHHostPolicyV1(
      allowedAlgorithms: [.sshEd25519],
      records: records
    )
  )
}

private func adapterTrustRecord(
  keyBytes: Data,
  state: SSHHostIdentityState
) -> SSHHostIdentityRecordV1 {
  SSHHostIdentityRecordV1(
    algorithm: .sshEd25519,
    fingerprintSHA256: SSHHostKeyFingerprint(
      SSHHostKeyEvidence.sha256Fingerprint(for: keyBytes)
    ),
    state: state,
    provenance: state == .approved ? .firstUseApproval : .changedKeyReplacement,
    firstSeenAt: SSHProfileTimestamp("2026-08-10T10:00:00.000Z"),
    lastSeenAt: SSHProfileTimestamp("2026-08-10T11:00:00.000Z"),
    approvedAt: SSHProfileTimestamp("2026-08-10T10:01:00.000Z"),
    revokedAt: state == .revoked
      ? SSHProfileTimestamp("2026-08-10T12:00:00.000Z") : nil,
    revocationReason: state == .revoked ? .replaced : nil
  )
}

private func adapterEd25519WireKey(repeating byte: UInt8) -> Data {
  adapterWireString(Data("ssh-ed25519".utf8))
    + adapterWireString(Data(repeating: byte, count: 32))
}

private func adapterWireString(_ value: Data) -> Data {
  var length = UInt32(value.count).bigEndian
  return withUnsafeBytes(of: &length) { Data($0) } + value
}

private final class LoopbackSSHD {
  let port: UInt16
  let hostKeyBlob: Data
  private let directory: URL
  private let process: Process

  init(publicKey: String) throws {
    guard FileManager.default.fileExists(atPath: "/usr/sbin/sshd") else {
      throw POSIXFixtureError.system(ENOENT)
    }
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "relux-libssh2-adapter-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let hostKey = directory.appendingPathComponent("host-key")
    let authorizedKeys = directory.appendingPathComponent("authorized_keys")
    let configuration = directory.appendingPathComponent("sshd_config")
    let log = directory.appendingPathComponent("sshd.log")
    try Data("\(publicKey)\n".utf8).write(to: authorizedKeys, options: .atomic)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: authorizedKeys.path)
    try runProcess(
      "/usr/bin/ssh-keygen",
      arguments: ["-q", "-t", "ed25519", "-N", "", "-f", hostKey.path]
    )
    let publicKeyText = try String(
      contentsOf: hostKey.appendingPathExtension("pub"),
      encoding: .utf8
    )
    let publicKeyFields = publicKeyText.split(whereSeparator: \.isWhitespace)
    guard publicKeyFields.count >= 2,
      let hostKeyBlob = Data(base64Encoded: String(publicKeyFields[1]))
    else {
      throw POSIXFixtureError.system(EINVAL)
    }
    self.hostKeyBlob = hostKeyBlob
    port = try unusedLoopbackPort()
    let text = [
      "Port \(port)",
      "ListenAddress 127.0.0.1",
      "Protocol 2",
      "HostKey \(hostKey.path)",
      "PidFile \(directory.appendingPathComponent("sshd.pid").path)",
      "AuthorizedKeysFile \(authorizedKeys.path)",
      "StrictModes no",
      "PasswordAuthentication no",
      "KbdInteractiveAuthentication no",
      "PubkeyAuthentication yes",
      "UsePAM no",
      "PermitRootLogin no",
      "AllowUsers \(NSUserName())",
      "AllowTcpForwarding yes",
      "RekeyLimit 32K 0",
      "LogLevel DEBUG3",
      "",
    ].joined(separator: "\n")
    try Data(text.utf8).write(to: configuration, options: .atomic)
    try runProcess("/usr/sbin/sshd", arguments: ["-t", "-f", configuration.path])

    process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/sshd")
    process.arguments = ["-D", "-E", log.path, "-f", configuration.path]
    try process.run()
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while ContinuousClock.now < deadline {
      if process.isRunning, let contents = try? String(contentsOf: log, encoding: .utf8),
        contents.contains("Server listening")
      {
        return
      }
      if !process.isRunning { break }
      Thread.sleep(forTimeInterval: 0.02)
    }
    stop()
    throw POSIXFixtureError.system(ECONNREFUSED)
  }

  func stop() {
    if process.isRunning {
      process.terminate()
      let deadline = ContinuousClock.now.advanced(by: .milliseconds(500))
      while process.isRunning, ContinuousClock.now < deadline {
        Thread.sleep(forTimeInterval: 0.01)
      }
      if process.isRunning {
        Darwin.kill(process.processIdentifier, SIGKILL)
      }
    }
    try? FileManager.default.removeItem(at: directory)
  }
}

private final class LoopbackEchoServer: @unchecked Sendable {
  let port: UInt16
  private let lock = NSLock()
  private var listener: Int32?
  private var client: Int32?
  private var task: Task<Void, Never>?

  init() throws {
    let listener = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard listener >= 0 else { throw POSIXFixtureError.system(errno) }
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard result == 0, Darwin.listen(listener, 1) == 0 else {
      let code = errno
      Darwin.close(listener)
      throw POSIXFixtureError.system(code)
    }
    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameResult = withUnsafeMutablePointer(to: &bound) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        getsockname(listener, $0, &length)
      }
    }
    guard nameResult == 0 else {
      let code = errno
      Darwin.close(listener)
      throw POSIXFixtureError.system(code)
    }
    self.listener = listener
    port = UInt16(bigEndian: bound.sin_port)
    task = Task.detached { [weak self] in self?.serve(listener: listener) }
  }

  func stop() {
    let descriptors = lock.withLock { () -> (Int32?, Int32?) in
      defer {
        listener = nil
        client = nil
      }
      return (listener, client)
    }
    if let client = descriptors.1 {
      Darwin.shutdown(client, SHUT_RDWR)
      Darwin.close(client)
    }
    if let listener = descriptors.0 {
      Darwin.shutdown(listener, SHUT_RDWR)
      Darwin.close(listener)
    }
    task?.cancel()
    task = nil
  }

  private func serve(listener: Int32) {
    let client = Darwin.accept(listener, nil, nil)
    guard client >= 0 else { return }
    lock.withLock { self.client = client }
    var buffer = [UInt8](repeating: 0, count: 4 * 1_024)
    while true {
      let count = Darwin.recv(client, &buffer, buffer.count, 0)
      if count <= 0 { return }
      var offset = 0
      while offset < count {
        let written = buffer.withUnsafeBytes {
          Darwin.send(client, $0.baseAddress! + offset, count - offset, 0)
        }
        if written <= 0 { return }
        offset += written
      }
    }
  }
}

private func runProcess(_ executable: String, arguments: [String]) throws {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  let errorPipe = Pipe()
  process.standardOutput = FileHandle.nullDevice
  process.standardError = errorPipe
  try process.run()
  process.waitUntilExit()
  guard process.terminationStatus == 0 else {
    throw POSIXFixtureError.system(process.terminationStatus)
  }
}

private func unusedLoopbackPort() throws -> UInt16 {
  let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
  guard descriptor >= 0 else { throw POSIXFixtureError.system(errno) }
  defer { Darwin.close(descriptor) }
  var address = sockaddr_in()
  address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
  address.sin_family = sa_family_t(AF_INET)
  address.sin_port = 0
  address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
  let result = withUnsafePointer(to: &address) { pointer in
    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  guard result == 0 else { throw POSIXFixtureError.system(errno) }
  var bound = sockaddr_in()
  var length = socklen_t(MemoryLayout<sockaddr_in>.size)
  let nameResult = withUnsafeMutablePointer(to: &bound) { pointer in
    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      getsockname(descriptor, $0, &length)
    }
  }
  guard nameResult == 0 else { throw POSIXFixtureError.system(errno) }
  return UInt16(bigEndian: bound.sin_port)
}

private func appendSSHString(_ value: Data, to data: inout Data) {
  var length = UInt32(value.count).bigEndian
  withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
  data.append(value)
}

private func sshMPInt(_ bytes: Data) -> Data {
  var value = Data(bytes.drop(while: { $0 == 0 }))
  if value.first.map({ $0 & 0x80 != 0 }) == true { value.insert(0, at: 0) }
  return value
}
