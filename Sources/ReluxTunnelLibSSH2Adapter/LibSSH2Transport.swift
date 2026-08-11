import Foundation
import ReluxLibSSH2
import ReluxTunnelCore

public enum LibSSH2PackagingAnchor {
  public static let schemaVersion: UInt16 = 1

  public static func linkageSmoke() -> Bool {
    libssh2_session_rekey(nil) == LIBSSH2_ERROR_BAD_USE
  }
}

struct LibSSH2ChannelAPI: Sendable {
  var processStartup: @Sendable (OpaquePointer, String) -> Int32
  var close: @Sendable (OpaquePointer) -> Int32
  var free: @Sendable (OpaquePointer) -> Int32

  static let live = LibSSH2ChannelAPI(
    processStartup: { pointer, command in
      command.utf8CString.withUnsafeBytes { bytes in
        libssh2_channel_process_startup(
          pointer,
          "exec",
          UInt32("exec".utf8.count),
          bytes.bindMemory(to: CChar.self).baseAddress,
          UInt32(max(0, bytes.count - 1))
        )
      }
    },
    close: { libssh2_channel_close($0) },
    free: { libssh2_channel_free($0) }
  )
}

public struct LibSSH2TransportFactory: SSHTransportFactory {
  public static let m3OwnerTaskID = "TASK-260728-3cveay"

  public let capabilities = SSHAdapterCapabilities(
    features: Set(SSHAdapterFeature.allCases),
    deferredSemantics: SSHDeferredSemanticCapabilities(
      consumerDrivenReceiveWindowCredit: .unsupported,
      rfcChannelOpenFailureReasons: .unsupported,
      exactExecExitMetadata: .unsupported,
      deepRekeyAndKeepaliveObservability: .unsupported
    ),
    keyExchangeAlgorithms: [
      "curve25519-sha256", "curve25519-sha256@libssh.org",
      "ecdh-sha2-nistp256", "ecdh-sha2-nistp384", "ecdh-sha2-nistp521",
      "diffie-hellman-group16-sha512", "diffie-hellman-group18-sha512",
      "diffie-hellman-group14-sha256",
    ],
    hostKeyAlgorithms: [
      "ssh-ed25519", "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384",
      "ecdsa-sha2-nistp521", "rsa-sha2-512", "rsa-sha2-256",
    ],
    cipherAlgorithms: [
      "chacha20-poly1305@openssh.com", "aes256-gcm@openssh.com",
      "aes128-gcm@openssh.com", "aes256-ctr", "aes192-ctr", "aes128-ctr",
    ],
    macAlgorithms: [
      "hmac-sha2-512-etm@openssh.com", "hmac-sha2-256-etm@openssh.com",
      "hmac-sha2-512", "hmac-sha2-256",
    ],
    publicKeyAuthenticationAlgorithms: [
      "ssh-ed25519", "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384",
      "ecdsa-sha2-nistp521", "rsa-sha2-512", "rsa-sha2-256",
    ]
  )

  private let maximumTransportBufferBytes: Int
  private let channelAPI: LibSSH2ChannelAPI

  public init(maximumTransportBufferBytes: Int = 256 * 1_024) {
    self.init(maximumTransportBufferBytes: maximumTransportBufferBytes, channelAPI: .live)
  }

  init(
    maximumTransportBufferBytes: Int = 256 * 1_024,
    channelAPI: LibSSH2ChannelAPI
  ) {
    precondition(maximumTransportBufferBytes > 0 && maximumTransportBufferBytes <= 1_048_576)
    self.maximumTransportBufferBytes = maximumTransportBufferBytes
    self.channelAPI = channelAPI
  }

  public func makeTransport(
    lane: SSHLaneIdentity,
    dependencies: SSHTransportDependencies
  ) async throws -> any SSHTransport {
    try LibSSH2GlobalRuntime.initialize()
    return LibSSH2Transport(
      lane: lane,
      dependencies: dependencies,
      maximumTransportBufferBytes: maximumTransportBufferBytes,
      channelAPI: channelAPI
    )
  }
}

private struct LibSSH2ChannelRecord {
  let pointer: OpaquePointer
  let kind: SSHChannelKind
  let policy: SSHChannelPolicy
  var writeEOF = false
  var closed = false
}

private struct LibSSH2ReadOperation: Hashable {
  let channel: SSHChannelIdentity
  let stream: Int32
}

struct LibSSH2OwnedResourceSnapshot: Equatable, Sendable {
  let channels: Int
  let socketOwned: Bool
  let sessionOwned: Bool
  let automaticTasks: Int
  let customAllocations: Int
  let bufferedBytes: Int
}

public actor LibSSH2Transport: SSHTransport {
  private static let maximumPendingOperations = 64

  private let lane: SSHLaneIdentity
  private let dependencies: SSHTransportDependencies
  private let context: LibSSH2SessionContext
  private let channelAPI: LibSSH2ChannelAPI
  private let sessionOperationGate = LibSSH2SessionOperationGate(
    maximumWaiters: maximumPendingOperations
  )
  let asyncOperations = LibSSH2OwnedAsyncOperationRegistry(
    maximumOperations: maximumPendingOperations
  )
  private let teardownAsyncOperations = LibSSH2OwnedAsyncOperationRegistry(
    maximumOperations: 2
  )
  private var state = SSHConnectionState.idle
  private var connection: (any SSHTCPConnection)?
  private var engineSession: OpaquePointer?
  private var sessionContextPointer: UnsafeMutableRawPointer?
  private var configuration: SSHConnectionConfiguration?
  private var negotiatedAlgorithms: SSHNegotiatedAlgorithms?
  private var channels: [SSHChannelIdentity: LibSSH2ChannelRecord] = [:]
  private var counters = SSHTransportCounters(
    windowAdjustments: .unsupported,
    windowAdjustmentBytes: .unsupported,
    serverRekeys: .unsupported,
    keepalivesAcknowledged: .unsupported,
    keepalivesTimedOut: .unsupported
  )
  private var rekeySentBytesBaseline: UInt64 = 0
  private var rekeyReceivedBytesBaseline: UInt64 = 0
  private var byteRekeyScheduled = false
  private var protectedNetworkBaseline: (received: UInt64, sent: UInt64)?
  private var automaticRekeyTask: Task<Void, Never>?
  private var automaticKeepaliveTask: Task<Void, Never>?
  private var byteRekeyTask: Task<Void, Never>?
  private var rekeyFlightTask: Task<Void, Never>?
  private var rekeyFlightInProgress = false
  private var rekeyFlightDeadline: ContinuousClock.Instant?
  private var rekeyReasons: Set<SSHRekeyReason> = []
  private var rekeyWaiters: [UUID: LibSSH2OperationWaiter] = [:]
  private var pendingChannelOpens = 0
  private var channelOpenDrainWaiter: CheckedContinuation<Void, Never>?
  private var pendingReads: Set<LibSSH2ReadOperation> = []
  private var pendingWriteBytes: [SSHChannelIdentity: Int] = [:]
  private var pendingWriteOperations = 0
  private var channelWriteGates: [SSHChannelIdentity: LibSSH2SessionOperationGate] = [:]
  private var pendingChannelOperationCounts: [SSHChannelIdentity: Int] = [:]
  private var disposingChannels: [SSHChannelIdentity: SSHTransportErrorCode] = [:]
  private var channelDrainWaiters: [SSHChannelIdentity: CheckedContinuation<Void, Never>] = [:]
  private var channelDisposalTasks: [SSHChannelIdentity: Task<Bool, Never>] = [:]
  private var consecutiveKeepaliveFailures = 0
  private var connectInProgress = false
  private var closeRequested = false
  private var connectDrainWaiter: CheckedContinuation<Void, Never>?
  private var pendingSessionOperations = 0
  private var sessionDrainWaiter: CheckedContinuation<Void, Never>?
  private var keepaliveInFlight = false
  private var teardownTask: Task<Void, Never>?

  init(
    lane: SSHLaneIdentity,
    dependencies: SSHTransportDependencies,
    maximumTransportBufferBytes: Int,
    channelAPI: LibSSH2ChannelAPI = .live
  ) {
    self.lane = lane
    self.dependencies = dependencies
    self.channelAPI = channelAPI
    context = LibSSH2SessionContext(maximumTransportBufferBytes: maximumTransportBufferBytes)
  }

  public func connect(configuration: SSHConnectionConfiguration) async throws -> SSHSession {
    guard state.permitsConnect else {
      throw transportError(code: .invalidState, phase: .configuration)
    }
    connectInProgress = true
    do {
      let result = try await performConnect(configuration: configuration)
      finishConnectOperation()
      return result
    } catch {
      finishConnectOperation()
      await tearDown()
      throw error
    }
  }

  private func performConnect(configuration: SSHConnectionConfiguration) async throws -> SSHSession
  {
    self.configuration = configuration
    try validateAlgorithmPolicy(configuration.algorithms)
    counters.connectAttempts += 1
    await metric(.increment(.connectAttempts, by: 1))
    var failurePhase = SSHTransportPhase.configuration

    do {
      failurePhase = .resolution
      try await transition(to: .resolving)
      let endpoints = try await withTimeout(
        configuration.timeouts.resolution,
        clock: dependencies.clock,
        registry: asyncOperations,
        operation: {
          try await self.dependencies.resolver.resolve(
            hostname: configuration.endpoint.host,
            port: configuration.endpoint.port
          )
        }
      )
      guard let endpoint = endpoints.first else {
        throw transportError(code: .resolutionFailed, phase: .resolution)
      }

      failurePhase = .tcpConnect
      try await transition(to: .tcpConnecting)
      let connection = try await withTimeout(
        configuration.timeouts.tcpConnect,
        clock: dependencies.clock,
        registry: asyncOperations,
        cleanupAbandonedResult: { connection in await connection.close() },
        operation: { try await self.dependencies.connector.connect(to: endpoint) }
      )
      self.connection = connection

      try configureEngine(configuration: configuration)
      failurePhase = .initialKeyExchange
      try await transition(to: .keyExchange)
      try await runHandshake(timeout: configuration.timeouts.initialKeyExchange)

      let evidence = try hostKeyEvidence()
      failurePhase = .hostDecision
      try await transition(to: .awaitingHostDecision)
      let hostInput = SSHHostKeyPolicyInput(
        canonicalHostname: configuration.canonicalHostname,
        connectedEndpoint: configuration.endpoint,
        evidence: evidence,
        lane: lane,
        trustRecordReference: configuration.trustRecordReference
      )
      let decision = try await withTimeout(
        configuration.timeouts.hostDecision,
        clock: dependencies.clock,
        registry: asyncOperations,
        operation: { try await self.dependencies.hostKeyPolicy.evaluate(hostInput) }
      )
      await recordHostDecision(decision)
      if let failure = SSHTransportError.hostDecisionFailure(decision, lane: lane) {
        throw failure
      }
      let acceptedHost = try decision.acceptance(for: hostInput)

      failurePhase = .credentialLookup
      try await transition(to: .authenticating)
      let request = SSHCredentialRequest(
        credentialReference: configuration.credentialReference,
        credentialGeneration: configuration.credentialGeneration,
        username: configuration.username,
        allowedPublicKeyAlgorithms: configuration.algorithms.hostKey,
        acceptedHost: acceptedHost
      )
      let credential = try await withTimeout(
        configuration.timeouts.credentialLookup,
        clock: dependencies.clock,
        registry: asyncOperations,
        operation: { try await self.dependencies.credentialProvider.credential(for: request) }
      )
      guard
        LibSSH2TransportFactory().capabilities.publicKeyAuthenticationAlgorithms.contains(
          credential.algorithm),
        request.allowedPublicKeyAlgorithms.contains(credential.algorithm)
      else {
        throw SSHTransportError.authenticationFailure(.keyAlgorithmUnavailable, lane: lane)!
      }
      context.install(credential: credential)
      defer { context.retireCredential() }
      counters.authenticationAttempts += 1
      await metric(.increment(.authenticationAttempts, by: 1))
      failurePhase = .authentication
      try await authenticate(
        username: configuration.username,
        publicKey: credential.publicKeyBytes,
        timeout: configuration.timeouts.authentication
      )

      let negotiated = try readNegotiatedAlgorithms()
      negotiatedAlgorithms = negotiated
      try await transition(to: .ready)
      counters.connectSucceeded += 1
      counters.authenticationSucceeded += 1
      await metric(.increment(.connectSucceeded, by: 1))
      await metric(.increment(.authenticationSucceeded, by: 1))
      await emit(.authentication(.success))
      startAutomaticTasks(configuration: configuration)
      let result = SSHSession(
        identity: dependencies.identityGenerator.makeSessionIdentity(),
        acceptedHost: acceptedHost,
        negotiatedAlgorithms: negotiated,
        keyExchangeGeneration: .unsupported
      )
      await dependencies.experimentRecorder?.record(
        .capabilities(LibSSH2TransportFactory().capabilities))
      return result
    } catch {
      let mapped = map(error, phase: failurePhase)
      await recordTerminalOperation(mapped)
      counters.connectFailed += 1
      await metric(.increment(.connectFailed, by: 1))
      if state != .failed, state != .closing, state != .closed {
        try? await transition(to: .failed)
      }
      throw mapped
    }
  }

  public func openDirectTCPIP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint,
    policy: SSHChannelPolicy
  ) async throws -> any SSHByteChannel {
    guard let configuration else {
      throw transportError(code: .invalidState, phase: .channelOpen)
    }
    let deadline = dependencies.clock.now().advanced(by: configuration.timeouts.channelOpen)
    let permit = try await beginChannelOpen(until: deadline)
    do {
      let channel = try await performOpenDirectTCPIP(
        destination: destination,
        originator: originator,
        policy: policy,
        deadline: deadline
      )
      await endChannelOpen(permit)
      return channel
    } catch {
      await endChannelOpen(permit)
      throw await handleOperationFailure(
        error,
        phase: .channelOpen,
        fallback: .channelOpenRejected,
        scope: .operation
      )
    }
  }

  private func performOpenDirectTCPIP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint,
    policy: SSHChannelPolicy,
    deadline: ContinuousClock.Instant
  ) async throws -> any SSHByteChannel {
    guard state == .ready else {
      throw transportError(code: .invalidState, phase: .channelOpen)
    }
    let identity = dependencies.identityGenerator.makeChannelIdentity()
    let message = directTCPIPMessage(destination: destination, originator: originator)
    while true {
      try checkCancellation(phase: .channelOpen, scope: .operation)
      guard state == .ready, let engineSession else {
        throw transportError(code: .cancelled, phase: .channelOpen)
      }
      let pointer = message.withUnsafeBytes { bytes in
        libssh2_channel_open_ex(
          engineSession,
          "direct-tcpip",
          UInt32("direct-tcpip".utf8.count),
          UInt32(clamping: policy.initialReceiveWindowBytes),
          UInt32(clamping: min(policy.maximumWriteCallBytes, Int(LIBSSH2_CHANNEL_PACKET_DEFAULT))),
          bytes.bindMemory(to: CChar.self).baseAddress,
          UInt32(bytes.count)
        )
      }
      if let pointer {
        channels[identity] = LibSSH2ChannelRecord(
          pointer: pointer,
          kind: .directTCPIP,
          policy: policy
        )
        channelWriteGates[identity] = LibSSH2SessionOperationGate(
          maximumWaiters: Self.maximumPendingOperations
        )
        counters.directChannelsOpened += 1
        await metric(.increment(.directChannelsOpened, by: 1))
        await emit(.channelOpened(channel: identity, kind: .directTCPIP))
        return LibSSH2ByteChannel(identity: identity, owner: self)
      }
      let code = libssh2_session_last_errno(engineSession)
      guard code == LIBSSH2_ERROR_EAGAIN else {
        counters.channelOpenFailed += 1
        await metric(.increment(.channelOpenFailed, by: 1))
        throw engineError(
          code,
          phase: .channelOpen,
          fallback: .channelOpenRejected,
          scope: .operation
        )
      }
      try await progress(until: deadline, phase: .channelOpen, scope: .operation)
    }
  }

  public func openExecChannel(
    request: SSHExecRequest,
    policy: SSHChannelPolicy
  ) async throws -> any SSHExecChannel {
    guard let configuration else {
      throw transportError(code: .invalidState, phase: .channelOpen)
    }
    let deadline = dependencies.clock.now().advanced(by: configuration.timeouts.channelOpen)
    return try await openExecChannel(request: request, policy: policy, until: deadline)
  }

  private func openExecChannel(
    request: SSHExecRequest,
    policy: SSHChannelPolicy,
    until deadline: ContinuousClock.Instant
  ) async throws -> any SSHExecChannel {
    let permit = try await beginChannelOpen(until: deadline)
    do {
      let channel = try await performOpenExecChannel(
        request: request,
        policy: policy,
        deadline: deadline
      )
      await endChannelOpen(permit)
      return channel
    } catch {
      await endChannelOpen(permit)
      throw await handleOperationFailure(
        error,
        phase: .channelOpen,
        fallback: .channelOpenRejected,
        scope: .operation
      )
    }
  }

  private func performOpenExecChannel(
    request: SSHExecRequest,
    policy: SSHChannelPolicy,
    deadline: ContinuousClock.Instant
  ) async throws -> any SSHExecChannel {
    guard state == .ready else {
      throw transportError(code: .invalidState, phase: .channelOpen)
    }
    let identity = dependencies.identityGenerator.makeChannelIdentity()
    let pointer: OpaquePointer
    while true {
      try checkCancellation(phase: .channelOpen, scope: .operation)
      guard state == .ready, let engineSession else {
        throw transportError(code: .cancelled, phase: .channelOpen)
      }
      if let opened = libssh2_channel_open_ex(
        engineSession,
        "session",
        UInt32("session".utf8.count),
        UInt32(clamping: policy.initialReceiveWindowBytes),
        UInt32(clamping: min(policy.maximumWriteCallBytes, Int(LIBSSH2_CHANNEL_PACKET_DEFAULT))),
        nil,
        0
      ) {
        pointer = opened
        channels[identity] = LibSSH2ChannelRecord(pointer: pointer, kind: .exec, policy: policy)
        channelWriteGates[identity] = LibSSH2SessionOperationGate(
          maximumWaiters: Self.maximumPendingOperations
        )
        break
      }
      let code = libssh2_session_last_errno(engineSession)
      guard code == LIBSSH2_ERROR_EAGAIN else {
        counters.channelOpenFailed += 1
        await metric(.increment(.channelOpenFailed, by: 1))
        throw engineError(
          code,
          phase: .channelOpen,
          fallback: .channelOpenRejected,
          scope: .operation
        )
      }
      try await progress(until: deadline, phase: .channelOpen, scope: .operation)
    }

    do {
      while true {
        try checkCancellation(phase: .execRequest, scope: .channel(identity))
        guard state == .ready, engineSession != nil else {
          throw transportError(code: .cancelled, phase: .execRequest)
        }
        let result = channelAPI.processStartup(pointer, request.command)
        if result == 0 { break }
        guard result == LIBSSH2_ERROR_EAGAIN else {
          throw engineError(
            result,
            phase: .execRequest,
            fallback: .execRejected,
            scope: .operation
          )
        }
        try await progress(
          until: deadline,
          phase: .execRequest,
          scope: .channel(identity)
        )
      }
    } catch {
      let disposed = await channelDispose(
        identity: identity,
        disposition: .channelReset,
        graceful: false,
        terminalEvent: nil,
        triggersTeardownOnFailure: true
      )
      if !disposed {
        throw transportError(code: .connectionLost, phase: .execRequest)
      }
      throw error
    }
    counters.execChannelsOpened += 1
    await metric(.increment(.execChannelsOpened, by: 1))
    await emit(.channelOpened(channel: identity, kind: .exec))
    return LibSSH2ExecChannel(identity: identity, owner: self)
  }

  public func upload(_ request: SSHExecUploadRequest) async throws -> SSHExecExit {
    guard let configuration else {
      throw transportError(code: .invalidState, phase: .uploadSource)
    }
    let ownedOperationBaseline = asyncOperations.outstandingCount
    let deadline = dependencies.clock.now().advanced(by: configuration.timeouts.upload)
    do {
      return try await performUpload(request, until: deadline)
    } catch {
      let mapped = map(error, phase: .uploadSource, scope: .operation)
      if mapped.code == .timedOut {
        // `performUpload` has already cancelled and awaited its cooperative
        // stdout/stderr children at this point. Give the timeout races backing
        // those children a bounded retirement barrier before exposing the
        // result. One additional operation may legitimately remain: the
        // upload source itself is allowed to ignore cancellation, and must
        // stay visible in ownership evidence until it actually returns.
        let retirementDeadline = dependencies.clock.now().advanced(
          by: min(configuration.timeouts.channelClose, .milliseconds(250))
        )
        _ = await asyncOperations.waitUntilOutstandingCount(
          atMost: ownedOperationBaseline + 1,
          until: retirementDeadline,
          clock: dependencies.clock
        )
      }
      await recordTerminalOperation(mapped)
      throw mapped
    }
  }

  private func performUpload(
    _ request: SSHExecUploadRequest,
    until deadline: ContinuousClock.Instant
  ) async throws -> SSHExecExit {
    guard let configuration else {
      throw transportError(code: .invalidState, phase: .uploadSource)
    }
    let channelOpenDeadline = min(
      deadline,
      dependencies.clock.now().advanced(by: configuration.timeouts.channelOpen)
    )
    let channel = try await openExecChannel(
      request: request.exec,
      policy: request.channelPolicy,
      until: channelOpenDeadline
    )
    let execChannel = channel as! LibSSH2ExecChannel
    do {
      async let stdout: Void = drain(
        channel: execChannel,
        standardError: false,
        until: deadline
      )
      async let stderr: Void = drain(
        channel: execChannel,
        standardError: true,
        until: deadline
      )
      while let bytes = try await readUploadSource(request, until: deadline) {
        guard !bytes.isEmpty, bytes.count <= request.chunkBytes else {
          throw transportError(code: .protocolViolation, phase: .uploadSource)
        }
        var offset = 0
        while offset < bytes.count {
          let written = try await channelWrite(
            identity: execChannel.identity,
            bytes: Data(bytes[offset...]),
            deadline: deadline
          )
          offset += written
        }
      }
      try await channelFinishWriting(identity: execChannel.identity, deadline: deadline)
      let exit = try await channelExit(identity: execChannel.identity, deadline: deadline)
      _ = try await (stdout, stderr)
      await execChannel.close()
      return exit
    } catch {
      await resetChannelAfterFailedOperation(identity: execChannel.identity)
      if error is LibSSH2TimeoutError
        || (error as? SSHTransportError)?.code == .timedOut
      {
        throw transportError(code: .timedOut, phase: .uploadSource, scope: .operation)
      }
      throw map(error, phase: .uploadSource, scope: .channel(execChannel.identity))
    }
  }

  private func readUploadSource(
    _ request: SSHExecUploadRequest,
    until deadline: ContinuousClock.Instant
  ) async throws -> Data? {
    let now = dependencies.clock.now()
    guard now < deadline else { throw LibSSH2TimeoutError.elapsed }
    return try await withTimeout(
      now.duration(to: deadline),
      clock: dependencies.clock,
      registry: asyncOperations
    ) {
      try await request.source.read(maximumBytes: request.chunkBytes)
    }
  }

  private func drain(
    channel: LibSSH2ExecChannel,
    standardError: Bool,
    until deadline: ContinuousClock.Instant
  ) async throws {
    while true {
      let bytes = try await channelRead(
        identity: channel.identity,
        maximumBytes: 16 * 1_024,
        stream: standardError ? Int32(SSH_EXTENDED_DATA_STDERR) : 0,
        deadline: deadline
      )
      if bytes == nil { return }
    }
  }

  public func requestRekey(reason: SSHClientRekeyReason) async throws {
    try await requestRekey(reason: reason, waitsForFatalTeardown: true)
  }

  private func requestRekey(
    reason: SSHClientRekeyReason,
    waitsForFatalTeardown: Bool
  ) async throws {
    guard state == .ready || state == .rekeying, !closeRequested, let configuration else {
      throw transportError(code: .invalidState, phase: .rekey)
    }
    guard rekeyWaiters.count < Self.maximumPendingOperations else {
      throw transportError(code: .resourceLimitExceeded, phase: .rekey, scope: .operation)
    }
    let waiter = LibSSH2OperationWaiter()
    rekeyWaiters[waiter.identifier] = waiter
    rekeyReasons.insert(.client(reason))
    incrementRekeyCounter(reason)
    if !rekeyFlightInProgress {
      if let completedFlight = rekeyFlightTask {
        await completedFlight.value
        rekeyFlightTask = nil
      }
      let now = dependencies.clock.now()
      let explicitDeadline = now.advanced(by: configuration.timeouts.explicitRekey)
      let rekeyDeadline = now.advanced(by: configuration.rekey.timeout)
      let deadline = min(explicitDeadline, rekeyDeadline)
      rekeyFlightDeadline = deadline
      rekeyFlightInProgress = true
      rekeyFlightTask = Task { [weak self] in
        guard let self else { return }
        await self.runRekeyFlight(until: deadline)
      }
    }
    do {
      guard let deadline = rekeyFlightDeadline else {
        throw transportError(code: .invalidState, phase: .rekey, scope: .operation)
      }
      let now = dependencies.clock.now()
      guard now < deadline else { throw LibSSH2TimeoutError.elapsed }
      try await withTimeout(
        now.duration(to: deadline),
        clock: dependencies.clock,
        registry: asyncOperations
      ) {
        try await waiter.wait()
      }
    } catch {
      rekeyWaiters.removeValue(forKey: waiter.identifier)
      let mapped =
        if error is CancellationError {
          transportError(code: .cancelled, phase: .rekey, scope: .operation)
        } else if error is LibSSH2TimeoutError {
          transportError(code: .timedOut, phase: .rekey, scope: .operation)
        } else {
          map(error, phase: .rekey, fallback: .rekeyFailed, scope: .operation)
        }
      await recordTerminalOperation(mapped)
      if mapped.requiresTeardown, waitsForFatalTeardown {
        await tearDown()
      }
      throw mapped
    }
  }

  private func runRekeyFlight(until deadline: ContinuousClock.Instant) async {
    var permit: LibSSH2SessionOperationPermit?
    do {
      permit = try await beginSessionOperation(phase: .rekey, until: deadline)
      try await performRequestRekey(until: deadline)
      if let permit { finishSessionOperation(permit) }
      finishRekeyFlight(with: .success(()))
    } catch {
      if let permit { finishSessionOperation(permit) }
      let mapped = map(error, phase: .rekey, fallback: .rekeyFailed)
      await recordTerminalOperation(mapped)
      if state != .failed, state != .closing, state != .closed {
        try? await transition(to: .failed)
      }
      finishRekeyFlight(with: .failure(mapped))
      _ = startTearDownIfNeeded()
    }
  }

  private func finishRekeyFlight(with result: Result<Void, Error>) {
    let waiters = Array(rekeyWaiters.values)
    rekeyWaiters.removeAll(keepingCapacity: false)
    rekeyReasons.removeAll(keepingCapacity: false)
    rekeyFlightInProgress = false
    rekeyFlightDeadline = nil
    for waiter in waiters { waiter.complete(with: result) }
  }

  private func performRequestRekey(until deadline: ContinuousClock.Instant) async throws {
    guard state == .ready else {
      throw transportError(code: .invalidState, phase: .rekey)
    }
    await emit(.rekeyTriggered(rekeyReasons))
    try await transition(to: .rekeying)
    await emit(.rekeyStarted(reasons: rekeyReasons, generation: counters.rekeysSucceeded + 1))
    do {
      while true {
        try checkCancellation(phase: .rekey)
        guard state == .rekeying, let engineSession else {
          throw transportError(code: .cancelled, phase: .rekey)
        }
        let result = libssh2_session_rekey(engineSession)
        if result == 0 { break }
        guard result == LIBSSH2_ERROR_EAGAIN else {
          throw engineError(result, phase: .rekey, fallback: .rekeyFailed)
        }
        try await progress(until: deadline, phase: .rekey)
      }
      counters.rekeysSucceeded += 1
      rekeySentBytesBaseline = counters.protectedBytesSent
      rekeyReceivedBytesBaseline = counters.protectedBytesReceived
      await metric(.increment(.rekeysSucceeded, by: 1))
      await emit(.rekeySucceeded(reasons: rekeyReasons, generation: counters.rekeysSucceeded))
      try await transition(to: .ready)
    } catch {
      counters.rekeysFailed += 1
      await metric(.increment(.rekeysFailed, by: 1))
      await emit(
        .rekeyFailed(
          reasons: rekeyReasons,
          generation: counters.rekeysSucceeded + 1,
          code: .rekeyFailed
        )
      )
      throw map(error, phase: .rekey, fallback: .rekeyFailed)
    }
  }

  public func sendKeepalive() async throws -> SSHDeferredSemanticReport<Duration> {
    try await sendKeepalive(deferBehindRekey: false)
  }

  private func sendKeepalive(
    deferBehindRekey: Bool
  ) async throws -> SSHDeferredSemanticReport<Duration> {
    guard let configuration else {
      throw transportError(code: .invalidState, phase: .keepalive)
    }
    guard !keepaliveInFlight else {
      throw transportError(code: .operationInProgress, phase: .keepalive, scope: .operation)
    }
    keepaliveInFlight = true
    let timeout = min(
      configuration.timeouts.keepaliveReply,
      configuration.keepalive.replyTimeout
    )
    let now = dependencies.clock.now()
    let admissionDeadline =
      if deferBehindRekey, state == .rekeying {
        rekeyFlightDeadline ?? now.advanced(by: configuration.rekey.timeout)
      } else {
        now.advanced(by: timeout)
      }
    let permit: LibSSH2SessionOperationPermit
    do {
      permit = try await beginSessionOperation(
        phase: .keepalive,
        until: admissionDeadline,
        allowsRekeying: true,
        scope: .operation
      )
    } catch {
      keepaliveInFlight = false
      throw error
    }
    do {
      let replyDeadline = dependencies.clock.now().advanced(by: timeout)
      let result = try await performSendKeepalive(until: replyDeadline)
      finishSessionOperation(permit)
      keepaliveInFlight = false
      return result
    } catch {
      finishSessionOperation(permit)
      keepaliveInFlight = false
      let mapped = await handleOperationFailure(
        error,
        phase: .keepalive,
        fallback: .keepaliveFailed,
        scope: .operation
      )
      throw mapped
    }
  }

  private func performSendKeepalive(
    until deadline: ContinuousClock.Instant
  ) async throws -> SSHDeferredSemanticReport<Duration> {
    guard state == .ready else {
      throw transportError(code: .invalidState, phase: .keepalive)
    }
    while true {
      try checkCancellation(phase: .keepalive)
      guard state == .ready, let engineSession else {
        throw transportError(code: .cancelled, phase: .keepalive)
      }
      var reply = LIBSSH2_GLOBAL_REQUEST_REPLY_NONE
      let result = libssh2_session_global_request(
        engineSession,
        "keepalive@openssh.com",
        "keepalive@openssh.com".utf8.count,
        nil,
        0,
        &reply
      )
      if result == 0 {
        consecutiveKeepaliveFailures = 0
        counters.keepalivesSent += 1
        await metric(.increment(.keepalivesSent, by: 1))
        await emit(.keepaliveSent)
        return .unsupported
      }
      guard result == LIBSSH2_ERROR_EAGAIN else {
        throw engineError(result, phase: .keepalive, fallback: .keepaliveFailed)
      }
      try await progress(until: deadline, phase: .keepalive)
    }
  }

  public func snapshot() async -> SSHTransportSnapshot {
    await reconcileProtectedMetrics()
    let counts = context.network.bufferedByteCounts
    let direct = channels.values.filter { $0.kind == .directTCPIP && !$0.closed }.count
    let exec = channels.values.filter { $0.kind == .exec && !$0.closed }.count
    return SSHTransportSnapshot(
      lane: lane,
      connectionState: state,
      negotiatedAlgorithms: negotiatedAlgorithms,
      keyExchangeGeneration: .unsupported,
      counters: counters,
      gauges: SSHTransportGauges(
        openDirectChannels: Int64(direct),
        openExecChannels: Int64(exec),
        pendingChannelOpens: Int64(pendingChannelOpens),
        pendingReads: Int64(pendingReads.count),
        pendingWrites: Int64(pendingWriteOperations),
        queuedWriteBytes: Int64(pendingWriteBytes.values.reduce(0, +)),
        bufferedReadBytes: Int64(counts.inbound),
        remainingReceiveWindowBytes: .unsupported,
        activeKeyExchange: .unsupported,
        consecutiveKeepaliveMisses: .unsupported,
        lastKeepaliveRTTNanoseconds: .unsupported
      )
    )
  }

  func ownedResourceSnapshot() async -> LibSSH2OwnedResourceSnapshot {
    if let teardownTask {
      await teardownTask.value
      self.teardownTask = nil
    }
    let buffered = context.network.bufferedByteCounts
    return LibSSH2OwnedResourceSnapshot(
      channels: channels.count,
      socketOwned: connection != nil,
      sessionOwned: engineSession != nil,
      automaticTasks: (automaticRekeyTask == nil ? 0 : 1)
        + (automaticKeepaliveTask == nil ? 0 : 1)
        + (byteRekeyTask == nil ? 0 : 1)
        + (rekeyFlightTask == nil ? 0 : 1)
        + channelDisposalTasks.count + context.outstandingTaskCount
        + context.network.pendingServiceCount + asyncOperations.outstandingCount
        + teardownAsyncOperations.outstandingCount,
      customAllocations: context.outstandingAllocationCount,
      bufferedBytes: buffered.inbound + buffered.outbound
    )
  }

  func pendingChannelOperationCount(identity: SSHChannelIdentity) -> Int {
    pendingChannelOperationCounts[identity, default: 0]
  }

  public func close() async {
    guard state != .closed else { return }
    closeRequested = true
    await tearDown()
  }

  private func configureEngine(configuration: SSHConnectionConfiguration) throws {
    let opaque = Unmanaged.passUnretained(context).toOpaque()
    sessionContextPointer = opaque
    let freeCallback = unsafeBitCast(reluxLibSSH2FreeCallback, to: OpaquePointer.self)
    guard
      let session = libssh2_session_init_ex(
        reluxLibSSH2AllocateCallback,
        freeCallback,
        reluxLibSSH2ReallocateCallback,
        opaque
      )
    else {
      throw transportError(code: .resourceLimitExceeded, phase: .initialKeyExchange)
    }
    engineSession = session
    libssh2_session_set_blocking(session, 0)
    let sendCallback: (@convention(c) () -> Void)? = unsafeBitCast(
      reluxLibSSH2SendCallback,
      to: Optional<@convention(c) () -> Void>.self
    )
    let receiveCallback: (@convention(c) () -> Void)? = unsafeBitCast(
      reluxLibSSH2ReceiveCallback,
      to: Optional<@convention(c) () -> Void>.self
    )
    _ = libssh2_session_callback_set2(session, Int32(LIBSSH2_CALLBACK_SEND), sendCallback)
    _ = libssh2_session_callback_set2(session, Int32(LIBSSH2_CALLBACK_RECV), receiveCallback)

    try setPreference(Int32(LIBSSH2_METHOD_KEX), configuration.algorithms.keyExchange)
    try setPreference(Int32(LIBSSH2_METHOD_HOSTKEY), configuration.algorithms.hostKey)
    try setPreference(Int32(LIBSSH2_METHOD_CRYPT_CS), configuration.algorithms.cipher)
    try setPreference(Int32(LIBSSH2_METHOD_CRYPT_SC), configuration.algorithms.cipher)
    try setPreference(Int32(LIBSSH2_METHOD_MAC_CS), configuration.algorithms.mac)
    try setPreference(Int32(LIBSSH2_METHOD_MAC_SC), configuration.algorithms.mac)
    try setPreference(Int32(LIBSSH2_METHOD_SIGN_ALGO), configuration.algorithms.hostKey)
    libssh2_keepalive_config(
      session,
      1,
      UInt32(max(2, configuration.keepalive.interval.wholeSeconds))
    )
  }

  private func setPreference(_ method: Int32, _ values: [String]) throws {
    guard let engineSession else { return }
    let preference = values.joined(separator: ",")
    let result = preference.withCString { libssh2_session_method_pref(engineSession, method, $0) }
    guard result == 0 else {
      throw engineError(result, phase: .configuration, fallback: .algorithmNegotiationFailed)
    }
  }

  private func validateAlgorithmPolicy(_ policy: SSHAlgorithmPolicy) throws {
    let capabilities = LibSSH2TransportFactory().capabilities
    guard Set(policy.keyExchange).isSubset(of: capabilities.keyExchangeAlgorithms),
      Set(policy.hostKey).isSubset(of: capabilities.hostKeyAlgorithms),
      Set(policy.cipher).isSubset(of: capabilities.cipherAlgorithms),
      Set(policy.mac).isSubset(of: capabilities.macAlgorithms)
    else {
      throw transportError(code: .algorithmNegotiationFailed, phase: .configuration)
    }
    let normalized = (policy.keyExchange + policy.hostKey + policy.cipher + policy.mac)
      .map { $0.lowercased() }
    guard !normalized.contains(where: { $0.contains("sha1") || $0.contains("-cbc") }) else {
      throw transportError(code: .algorithmNegotiationFailed, phase: .configuration)
    }
  }

  private func runHandshake(timeout: Duration) async throws {
    guard let engineSession else {
      throw transportError(code: .invalidState, phase: .initialKeyExchange)
    }
    let deadline = dependencies.clock.now().advanced(by: timeout)
    while true {
      try checkCancellation(phase: .initialKeyExchange)
      let result = libssh2_session_handshake(engineSession, LibSSH2AdapterConstants.socketToken)
      if result == 0 {
        protectedNetworkBaseline = context.network.engineByteCounts
        return
      }
      guard result == LIBSSH2_ERROR_EAGAIN else {
        throw engineError(result, phase: .initialKeyExchange, fallback: .algorithmNegotiationFailed)
      }
      try await progress(until: deadline, phase: .initialKeyExchange)
    }
  }

  private func authenticate(username: String, publicKey: Data, timeout: Duration) async throws {
    guard let engineSession else {
      throw transportError(code: .invalidState, phase: .authentication)
    }
    let deadline = dependencies.clock.now().advanced(by: timeout)
    while true {
      try checkCancellation(phase: .authentication)
      var abstract = sessionContextPointer
      let result = username.withCString { user in
        publicKey.withUnsafeBytes { bytes in
          libssh2_userauth_publickey(
            engineSession,
            user,
            bytes.bindMemory(to: UInt8.self).baseAddress,
            bytes.count,
            reluxLibSSH2SignCallback,
            &abstract
          )
        }
      }
      if result == 0 { return }
      guard result == LIBSSH2_ERROR_EAGAIN else {
        counters.authenticationRejected += 1
        await metric(.increment(.authenticationRejected, by: 1))
        throw engineError(result, phase: .authentication, fallback: .authenticationRejected)
      }
      try await progress(until: deadline, phase: .authentication)
    }
  }

  private func hostKeyEvidence() throws -> SSHHostKeyEvidence {
    guard let engineSession else { throw transportError(code: .invalidState, phase: .hostDecision) }
    var length = 0
    guard let bytes = libssh2_session_hostkey(engineSession, &length, nil), length > 0 else {
      throw transportError(code: .protocolViolation, phase: .hostDecision)
    }
    guard let method = libssh2_session_methods(engineSession, Int32(LIBSSH2_METHOD_HOSTKEY)) else {
      throw transportError(code: .protocolViolation, phase: .hostDecision)
    }
    return try SSHHostKeyEvidence(
      algorithm: String(cString: method),
      keyBytes: Data(bytes: bytes, count: length)
    )
  }

  private func readNegotiatedAlgorithms() throws -> SSHNegotiatedAlgorithms {
    func method(_ type: Int32) throws -> String {
      guard let engineSession, let value = libssh2_session_methods(engineSession, type) else {
        throw transportError(code: .protocolViolation, phase: .initialKeyExchange)
      }
      return String(cString: value)
    }
    return try SSHNegotiatedAlgorithms(
      keyExchange: method(Int32(LIBSSH2_METHOD_KEX)),
      hostKey: method(Int32(LIBSSH2_METHOD_HOSTKEY)),
      cipherClientToServer: method(Int32(LIBSSH2_METHOD_CRYPT_CS)),
      cipherServerToClient: method(Int32(LIBSSH2_METHOD_CRYPT_SC)),
      macClientToServer: method(Int32(LIBSSH2_METHOD_MAC_CS)),
      macServerToClient: method(Int32(LIBSSH2_METHOD_MAC_SC))
    )
  }

  private func progress(
    until deadline: ContinuousClock.Instant,
    phase: SSHTransportPhase,
    scope: SSHTransportErrorScope? = nil
  )
    async throws
  {
    try checkCancellation(phase: phase, scope: scope)
    let now = dependencies.clock.now()
    guard now < deadline else {
      throw transportError(code: .timedOut, phase: phase, scope: scope)
    }
    let remaining = now.duration(to: deadline)
    if context.signatureIsPending() {
      do {
        try await withTimeout(
          remaining,
          clock: dependencies.clock,
          registry: asyncOperations
        ) {
          try await self.context.waitForSignature()
        }
      } catch {
        context.cancelSignature()
        throw error
      }
      return
    }
    guard let connection, let engineSession else {
      throw transportError(code: .connectionClosed, phase: phase)
    }
    let directions = libssh2_session_block_directions(engineSession)
    var interests = Set<SSHTCPReadiness>()
    if directions & LIBSSH2_SESSION_BLOCK_INBOUND != 0 { interests.insert(.readable) }
    if directions & LIBSSH2_SESSION_BLOCK_OUTBOUND != 0 { interests.insert(.writable) }
    if interests.isEmpty { interests = [.readable, .writable] }
    let requestedInterests = interests
    do {
      try await withTimeout(
        remaining,
        clock: dependencies.clock,
        registry: asyncOperations
      ) {
        try await self.context.network.service(
          connection: connection,
          interests: requestedInterests
        )
      }
    } catch is LibSSH2TimeoutError {
      throw transportError(code: .timedOut, phase: phase, scope: scope)
    } catch is CancellationError {
      throw transportError(code: .cancelled, phase: phase, scope: scope)
    } catch {
      throw transportError(code: .connectionLost, phase: phase)
    }
  }

  private func progress(
    phase: SSHTransportPhase,
    scope: SSHTransportErrorScope
  ) async throws {
    try checkCancellation(phase: phase, scope: scope)
    guard let connection, let engineSession else {
      throw transportError(code: .connectionClosed, phase: phase)
    }
    let directions = libssh2_session_block_directions(engineSession)
    var interests = Set<SSHTCPReadiness>()
    if directions & LIBSSH2_SESSION_BLOCK_INBOUND != 0 { interests.insert(.readable) }
    if directions & LIBSSH2_SESSION_BLOCK_OUTBOUND != 0 { interests.insert(.writable) }
    if interests.isEmpty { interests = [.readable, .writable] }
    do {
      try await context.network.service(connection: connection, interests: interests)
      try checkCancellation(phase: phase, scope: scope)
    } catch is CancellationError {
      throw transportError(code: .cancelled, phase: phase, scope: scope)
    } catch {
      throw transportError(code: .connectionLost, phase: phase)
    }
  }

  private func startAutomaticTasks(configuration: SSHConnectionConfiguration) {
    automaticRekeyTask = Task { [weak self, clock = dependencies.clock] in
      while !Task.isCancelled {
        do {
          try await clock.sleep(for: configuration.rekey.elapsedTimeThreshold)
          try await self?.requestRekey(reason: .timeThreshold, waitsForFatalTeardown: false)
        } catch { return }
      }
    }
    automaticKeepaliveTask = Task { [weak self, clock = dependencies.clock] in
      while !Task.isCancelled {
        do {
          try await clock.sleep(for: configuration.keepalive.interval)
          _ = try await self?.sendKeepalive(deferBehindRekey: true)
        } catch {
          guard
            await self?.handleAutomaticKeepaliveFailure(
              error,
              policy: configuration.keepalive
            ) == true
          else { return }
        }
      }
    }
  }

  private func handleAutomaticKeepaliveFailure(
    _ error: Error,
    policy: SSHKeepalivePolicy
  ) async -> Bool {
    let mapped = map(error, phase: .keepalive, fallback: .keepaliveFailed)
    if state == .rekeying, mapped.code == .timedOut || mapped.code == .invalidState {
      return true
    }
    guard state == .ready else { return false }
    consecutiveKeepaliveFailures += 1
    guard consecutiveKeepaliveFailures > policy.allowedConsecutiveMisses else {
      return true
    }
    await recordTerminalOperation(mapped)
    try? await transition(to: .failed)
    await emit(.error(code: mapped.code, phase: mapped.phase, scope: mapped.scope))
    _ = startTearDownIfNeeded()
    return false
  }

  private func beginChannelOpen(
    until deadline: ContinuousClock.Instant
  ) async throws -> LibSSH2SessionOperationPermit {
    guard state == .ready || state == .rekeying else {
      throw transportError(code: .invalidState, phase: .channelOpen)
    }
    guard pendingChannelOpens < Self.maximumPendingOperations else {
      throw transportError(code: .resourceLimitExceeded, phase: .channelOpen, scope: .operation)
    }
    pendingChannelOpens += 1
    await metric(.set(.pendingChannelOpens, to: Int64(pendingChannelOpens)))
    do {
      let now = dependencies.clock.now()
      guard now < deadline else { throw LibSSH2TimeoutError.elapsed }
      return try await withTimeout(
        now.duration(to: deadline),
        clock: dependencies.clock,
        registry: asyncOperations
      ) {
        try await self.sessionOperationGate.acquire()
      }
    } catch {
      await finishChannelOpenWithoutPermit()
      if (error as? LibSSH2SessionOperationGateError) == .resourceLimitExceeded {
        throw transportError(code: .resourceLimitExceeded, phase: .channelOpen, scope: .operation)
      }
      if error is LibSSH2TimeoutError {
        throw transportError(code: .timedOut, phase: .channelOpen, scope: .operation)
      }
      if error is CancellationError
        || (error as? LibSSH2SessionOperationGateError) == .shutDown
      {
        throw transportError(code: .cancelled, phase: .channelOpen, scope: .operation)
      }
      throw map(error, phase: .channelOpen, scope: .operation)
    }
  }

  private func finishConnectOperation() {
    connectInProgress = false
    let waiter = connectDrainWaiter
    connectDrainWaiter = nil
    waiter?.resume()
  }

  private func waitForConnectToDrain() async {
    guard connectInProgress else { return }
    await withCheckedContinuation { continuation in
      precondition(connectDrainWaiter == nil)
      connectDrainWaiter = continuation
    }
  }

  private func beginSessionOperation(
    phase: SSHTransportPhase,
    until deadline: ContinuousClock.Instant,
    allowsRekeying: Bool = false,
    scope: SSHTransportErrorScope? = nil
  ) async throws -> LibSSH2SessionOperationPermit {
    guard state == .ready || (allowsRekeying && state == .rekeying), !closeRequested else {
      throw transportError(code: .invalidState, phase: phase)
    }
    guard pendingSessionOperations < Self.maximumPendingOperations else {
      throw transportError(code: .resourceLimitExceeded, phase: phase, scope: scope)
    }
    pendingSessionOperations += 1
    do {
      let now = dependencies.clock.now()
      guard now < deadline else { throw LibSSH2TimeoutError.elapsed }
      return try await withTimeout(
        now.duration(to: deadline),
        clock: dependencies.clock,
        registry: asyncOperations
      ) {
        try await self.sessionOperationGate.acquire()
      }
    } catch {
      finishSessionOperationWithoutPermit()
      if (error as? LibSSH2SessionOperationGateError) == .resourceLimitExceeded {
        throw transportError(code: .resourceLimitExceeded, phase: phase, scope: scope)
      }
      if error is LibSSH2TimeoutError {
        throw transportError(code: .timedOut, phase: phase, scope: scope)
      }
      if error is CancellationError
        || (error as? LibSSH2SessionOperationGateError) == .shutDown
      {
        throw transportError(code: .cancelled, phase: phase, scope: scope)
      }
      throw map(error, phase: phase, scope: scope)
    }
  }

  private func finishSessionOperation(_ permit: LibSSH2SessionOperationPermit) {
    sessionOperationGate.release(permit)
    finishSessionOperationWithoutPermit()
  }

  private func finishSessionOperationWithoutPermit() {
    pendingSessionOperations -= 1
    if pendingSessionOperations == 0 {
      let waiter = sessionDrainWaiter
      sessionDrainWaiter = nil
      waiter?.resume()
    }
  }

  private func waitForSessionOperationsToDrain() async {
    guard pendingSessionOperations > 0 else { return }
    await withCheckedContinuation { continuation in
      precondition(sessionDrainWaiter == nil)
      sessionDrainWaiter = continuation
    }
  }

  private func endChannelOpen(_ permit: LibSSH2SessionOperationPermit) async {
    sessionOperationGate.release(permit)
    await finishChannelOpenWithoutPermit()
  }

  private func finishChannelOpenWithoutPermit() async {
    pendingChannelOpens -= 1
    await metric(.set(.pendingChannelOpens, to: Int64(pendingChannelOpens)))
    if pendingChannelOpens == 0 {
      let waiter = channelOpenDrainWaiter
      channelOpenDrainWaiter = nil
      waiter?.resume()
    }
  }

  private func waitForChannelOpensToDrain() async {
    guard pendingChannelOpens > 0 else { return }
    await withCheckedContinuation { continuation in
      precondition(channelOpenDrainWaiter == nil)
      channelOpenDrainWaiter = continuation
    }
  }

  private func beginChannelRead(identity: SSHChannelIdentity, stream: Int32) async throws {
    try beginChannelOperation(identity: identity, phase: .channelRead)
    let operation = LibSSH2ReadOperation(channel: identity, stream: stream)
    guard pendingReads.insert(operation).inserted else {
      finishChannelOperation(identity: identity)
      throw transportError(
        code: .operationInProgress,
        phase: .channelRead,
        scope: .channel(identity)
      )
    }
    await metric(.set(.pendingReads, to: Int64(pendingReads.count)))
  }

  private func endChannelRead(identity: SSHChannelIdentity, stream: Int32) async {
    pendingReads.remove(LibSSH2ReadOperation(channel: identity, stream: stream))
    finishChannelOperation(identity: identity)
    await metric(.set(.pendingReads, to: Int64(pendingReads.count)))
  }

  private func beginChannelWrite(
    identity: SSHChannelIdentity,
    byteCount: Int,
    until deadline: ContinuousClock.Instant
  ) async throws -> LibSSH2SessionOperationPermit {
    try beginChannelOperation(identity: identity, phase: .channelWrite)
    guard let record = channels[identity], let writeGate = channelWriteGates[identity] else {
      finishChannelOperation(identity: identity)
      throw transportError(code: .channelClosed, phase: .channelWrite, scope: .channel(identity))
    }
    let queued = pendingWriteBytes[identity, default: 0]
    guard byteCount <= record.policy.maximumQueuedWriteBytes - queued else {
      finishChannelOperation(identity: identity)
      throw transportError(
        code: .resourceLimitExceeded,
        phase: .channelWrite,
        scope: .channel(identity)
      )
    }
    pendingWriteBytes[identity] = queued + byteCount
    pendingWriteOperations += 1
    await metric(.set(.pendingWrites, to: Int64(pendingWriteOperations)))
    await metric(.set(.queuedWriteBytes, to: Int64(pendingWriteBytes.values.reduce(0, +))))
    do {
      let now = dependencies.clock.now()
      guard now < deadline else { throw LibSSH2TimeoutError.elapsed }
      return try await withTimeout(
        now.duration(to: deadline),
        clock: dependencies.clock,
        registry: asyncOperations
      ) {
        try await writeGate.acquire()
      }
    } catch {
      await finishChannelWriteWithoutPermit(identity: identity, byteCount: byteCount)
      if (error as? LibSSH2SessionOperationGateError) == .resourceLimitExceeded {
        throw transportError(
          code: .resourceLimitExceeded,
          phase: .channelWrite,
          scope: .channel(identity)
        )
      }
      if error is CancellationError
        || (error as? LibSSH2SessionOperationGateError) == .shutDown
      {
        throw transportError(code: .cancelled, phase: .channelWrite, scope: .channel(identity))
      }
      if error is LibSSH2TimeoutError {
        throw transportError(code: .timedOut, phase: .channelWrite, scope: .channel(identity))
      }
      throw map(error, phase: .channelWrite, scope: .channel(identity))
    }
  }

  private func endChannelWrite(
    identity: SSHChannelIdentity,
    byteCount: Int,
    permit: LibSSH2SessionOperationPermit
  ) async {
    channelWriteGates[identity]?.release(permit)
    await finishChannelWriteWithoutPermit(identity: identity, byteCount: byteCount)
  }

  private func finishChannelWriteWithoutPermit(
    identity: SSHChannelIdentity,
    byteCount: Int
  ) async {
    let remaining = max(0, pendingWriteBytes[identity, default: byteCount] - byteCount)
    if remaining == 0 {
      pendingWriteBytes.removeValue(forKey: identity)
    } else {
      pendingWriteBytes[identity] = remaining
    }
    pendingWriteOperations -= 1
    finishChannelOperation(identity: identity)
    await metric(.set(.pendingWrites, to: Int64(pendingWriteOperations)))
    await metric(.set(.queuedWriteBytes, to: Int64(pendingWriteBytes.values.reduce(0, +))))
  }

  private func beginChannelOperation(
    identity: SSHChannelIdentity,
    phase: SSHTransportPhase
  ) throws {
    if let code = disposingChannels[identity] {
      throw transportError(code: code, phase: phase, scope: .channel(identity))
    }
    guard let record = channels[identity], !record.closed else {
      throw transportError(code: .channelClosed, phase: phase, scope: .channel(identity))
    }
    guard pendingChannelOperationCounts[identity, default: 0] < Self.maximumPendingOperations
    else {
      throw transportError(
        code: .resourceLimitExceeded,
        phase: phase,
        scope: .channel(identity)
      )
    }
    pendingChannelOperationCounts[identity, default: 0] += 1
  }

  private func finishChannelOperation(identity: SSHChannelIdentity) {
    let remaining = max(0, pendingChannelOperationCounts[identity, default: 1] - 1)
    if remaining == 0 {
      pendingChannelOperationCounts.removeValue(forKey: identity)
      channelDrainWaiters.removeValue(forKey: identity)?.resume()
    } else {
      pendingChannelOperationCounts[identity] = remaining
    }
  }

  private func waitForChannelOperationsToDrain(identity: SSHChannelIdentity) async {
    guard pendingChannelOperationCounts[identity, default: 0] > 0 else { return }
    await withCheckedContinuation { continuation in
      precondition(channelDrainWaiters[identity] == nil)
      channelDrainWaiters[identity] = continuation
    }
  }

  private func checkChannelDisposition(
    identity: SSHChannelIdentity,
    phase: SSHTransportPhase
  ) throws {
    if let code = disposingChannels[identity] {
      throw transportError(code: code, phase: phase, scope: .channel(identity))
    }
  }

  func channelRead(
    identity: SSHChannelIdentity,
    maximumBytes: Int,
    stream: Int32,
    deadline: ContinuousClock.Instant? = nil
  ) async throws -> Data? {
    try await beginChannelRead(identity: identity, stream: stream)
    do {
      let result = try await performChannelRead(
        identity: identity,
        maximumBytes: maximumBytes,
        stream: stream,
        deadline: deadline
      )
      await endChannelRead(identity: identity, stream: stream)
      return result
    } catch {
      await endChannelRead(identity: identity, stream: stream)
      throw await handleOperationFailure(
        error,
        phase: .channelRead,
        scope: .channel(identity)
      )
    }
  }

  private func performChannelRead(
    identity: SSHChannelIdentity,
    maximumBytes: Int,
    stream: Int32,
    deadline: ContinuousClock.Instant?
  ) async throws -> Data? {
    guard maximumBytes > 0 else {
      throw transportError(
        code: .invalidArgument,
        phase: .channelRead,
        scope: .channel(identity)
      )
    }
    guard let record = channels[identity], !record.closed else {
      throw transportError(code: .channelClosed, phase: .channelRead, scope: .channel(identity))
    }
    let count = min(maximumBytes, record.policy.maximumBufferedReadBytes)
    while true {
      try checkCancellation(phase: .channelRead, scope: .channel(identity))
      try checkChannelDisposition(identity: identity, phase: .channelRead)
      var data = Data(count: count)
      let result = data.withUnsafeMutableBytes { bytes in
        libssh2_channel_read_ex(
          record.pointer,
          stream,
          bytes.bindMemory(to: CChar.self).baseAddress,
          bytes.count
        )
      }
      if result > 0 {
        data.removeSubrange(Int(result)..<data.count)
        counters.payloadBytesReceived += UInt64(result)
        await metric(.increment(.payloadBytesReceived, by: UInt64(result)))
        await reconcileProtectedMetrics()
        await scheduleByteRekeyIfNeeded()
        return data
      }
      if result == 0, libssh2_channel_eof(record.pointer) != 0 {
        await emit(.channelEOF(channel: identity, direction: .remoteRead))
        return nil
      }
      guard result == LIBSSH2_ERROR_EAGAIN || result == 0 else {
        throw engineError(
          Int32(result),
          phase: .channelRead,
          fallback: .connectionLost,
          scope: .channel(identity)
        )
      }
      if let deadline {
        try await progress(
          until: deadline,
          phase: .channelRead,
          scope: .channel(identity)
        )
      } else {
        try await progress(phase: .channelRead, scope: .channel(identity))
      }
    }
  }

  func channelWrite(
    identity: SSHChannelIdentity,
    bytes: Data,
    deadline uploadDeadline: ContinuousClock.Instant? = nil
  ) async throws -> Int {
    guard !bytes.isEmpty else {
      throw transportError(code: .invalidArgument, phase: .channelWrite, scope: .channel(identity))
    }
    guard let record = channels[identity], !record.closed, !record.writeEOF else {
      throw transportError(code: .writeAfterEOF, phase: .channelWrite, scope: .channel(identity))
    }
    let acceptedPrefix = min(
      bytes.count,
      record.policy.maximumWriteCallBytes,
      record.policy.maximumQueuedWriteBytes
    )
    guard let configuration else {
      throw transportError(code: .invalidState, phase: .channelWrite, scope: .channel(identity))
    }
    let ordinaryDeadline = dependencies.clock.now().advanced(
      by: configuration.timeouts.writeCreditWait
    )
    let deadline = uploadDeadline.map { min($0, ordinaryDeadline) } ?? ordinaryDeadline
    let permit = try await beginChannelWrite(
      identity: identity,
      byteCount: acceptedPrefix,
      until: deadline
    )
    do {
      let result = try await performChannelWrite(
        identity: identity,
        bytes: bytes,
        acceptedPrefix: acceptedPrefix,
        until: deadline
      )
      await endChannelWrite(identity: identity, byteCount: acceptedPrefix, permit: permit)
      return result
    } catch {
      await endChannelWrite(identity: identity, byteCount: acceptedPrefix, permit: permit)
      throw await handleOperationFailure(
        error,
        phase: .channelWrite,
        scope: .channel(identity)
      )
    }
  }

  private func performChannelWrite(
    identity: SSHChannelIdentity,
    bytes: Data,
    acceptedPrefix: Int,
    until deadline: ContinuousClock.Instant
  ) async throws -> Int {
    guard let record = channels[identity], !record.closed, !record.writeEOF else {
      throw transportError(code: .writeAfterEOF, phase: .channelWrite, scope: .channel(identity))
    }
    while true {
      try checkCancellation(phase: .channelWrite, scope: .channel(identity))
      try checkChannelDisposition(identity: identity, phase: .channelWrite)
      let result = bytes.withUnsafeBytes { raw in
        libssh2_channel_write_ex(
          record.pointer,
          0,
          raw.bindMemory(to: CChar.self).baseAddress,
          acceptedPrefix
        )
      }
      if result > 0 {
        counters.payloadBytesSent += UInt64(result)
        await metric(.increment(.payloadBytesSent, by: UInt64(result)))
        await reconcileProtectedMetrics()
        await scheduleByteRekeyIfNeeded()
        return result
      }
      guard result == LIBSSH2_ERROR_EAGAIN else {
        throw engineError(
          Int32(result),
          phase: .channelWrite,
          fallback: .connectionLost,
          scope: .channel(identity)
        )
      }
      counters.writeBackpressureWaits += 1
      await metric(.increment(.writeBackpressureWaits, by: 1))
      await emit(.writeBackpressureBegan(identity))
      let started = dependencies.clock.now()
      do {
        try await progress(
          until: deadline,
          phase: .channelWrite,
          scope: .channel(identity)
        )
      } catch {
        if let failure = error as? SSHTransportError, failure.requiresTeardown {
          // libssh2 retains the nonblocking write state until the same API is
          // re-entered. Finish that state-machine edge against a terminal
          // callback before channel/session teardown attempts another API.
          context.network.beginAbortDrain()
          _ = bytes.withUnsafeBytes { raw in
            libssh2_channel_write_ex(
              record.pointer,
              0,
              raw.bindMemory(to: CChar.self).baseAddress,
              acceptedPrefix
            )
          }
        }
        throw error
      }
      await emit(
        .writeBackpressureEnded(
          channel: identity,
          waitDuration: started.duration(to: dependencies.clock.now())
        )
      )
    }
  }

  func channelFinishWriting(
    identity: SSHChannelIdentity,
    deadline uploadDeadline: ContinuousClock.Instant? = nil
  ) async throws {
    guard let configuration else {
      throw transportError(code: .invalidState, phase: .channelEOF, scope: .channel(identity))
    }
    let ordinaryDeadline = dependencies.clock.now().advanced(
      by: configuration.timeouts.channelClose
    )
    let deadline = uploadDeadline.map { min($0, ordinaryDeadline) } ?? ordinaryDeadline
    let permit = try await beginChannelEOF(identity: identity, until: deadline)
    do {
      try await performChannelFinishWriting(identity: identity, until: deadline)
      channelWriteGates[identity]?.release(permit)
      finishChannelOperation(identity: identity)
    } catch {
      channelWriteGates[identity]?.release(permit)
      finishChannelOperation(identity: identity)
      let mapped = map(error, phase: .channelEOF, scope: .channel(identity))
      await recordTerminalOperation(mapped)
      if mapped.requiresTeardown {
        if state != .failed, state != .closing, state != .closed {
          try? await transition(to: .failed)
        }
        await tearDown()
      } else {
        await resetChannelAfterFailedOperation(identity: identity)
      }
      throw mapped
    }
  }

  private func beginChannelEOF(
    identity: SSHChannelIdentity,
    until deadline: ContinuousClock.Instant
  ) async throws -> LibSSH2SessionOperationPermit {
    try beginChannelOperation(identity: identity, phase: .channelEOF)
    guard let writeGate = channelWriteGates[identity] else {
      finishChannelOperation(identity: identity)
      throw transportError(code: .channelClosed, phase: .channelEOF, scope: .channel(identity))
    }
    do {
      let now = dependencies.clock.now()
      guard now < deadline else { throw LibSSH2TimeoutError.elapsed }
      return try await withTimeout(
        now.duration(to: deadline),
        clock: dependencies.clock,
        registry: asyncOperations
      ) {
        try await writeGate.acquire()
      }
    } catch {
      finishChannelOperation(identity: identity)
      if (error as? LibSSH2SessionOperationGateError) == .resourceLimitExceeded {
        throw transportError(
          code: .resourceLimitExceeded,
          phase: .channelEOF,
          scope: .channel(identity)
        )
      }
      if error is LibSSH2TimeoutError {
        throw transportError(code: .timedOut, phase: .channelEOF, scope: .channel(identity))
      }
      if error is CancellationError
        || (error as? LibSSH2SessionOperationGateError) == .shutDown
      {
        throw transportError(code: .cancelled, phase: .channelEOF, scope: .channel(identity))
      }
      throw map(error, phase: .channelEOF, scope: .channel(identity))
    }
  }

  private func performChannelFinishWriting(
    identity: SSHChannelIdentity,
    until deadline: ContinuousClock.Instant
  ) async throws {
    guard var record = channels[identity], !record.closed else {
      throw transportError(code: .channelClosed, phase: .channelEOF, scope: .channel(identity))
    }
    if record.writeEOF { return }
    while true {
      try checkCancellation(phase: .channelEOF, scope: .channel(identity))
      try checkChannelDisposition(identity: identity, phase: .channelEOF)
      let result = libssh2_channel_send_eof(record.pointer)
      if result == 0 { break }
      guard result == LIBSSH2_ERROR_EAGAIN else {
        throw engineError(
          result,
          phase: .channelEOF,
          fallback: .channelClosed,
          scope: .channel(identity)
        )
      }
      try await progress(
        until: deadline,
        phase: .channelEOF,
        scope: .channel(identity)
      )
    }
    record.writeEOF = true
    channels[identity] = record
    await emit(.channelEOF(channel: identity, direction: .localWrite))
  }

  func channelExit(
    identity: SSHChannelIdentity,
    deadline uploadDeadline: ContinuousClock.Instant? = nil
  ) async throws -> SSHExecExit {
    try beginChannelOperation(identity: identity, phase: .execExit)
    do {
      let result = try await performChannelExit(identity: identity, deadline: uploadDeadline)
      finishChannelOperation(identity: identity)
      return result
    } catch {
      finishChannelOperation(identity: identity)
      let mapped = map(error, phase: .execExit, scope: .channel(identity))
      await recordTerminalOperation(mapped)
      if mapped.requiresTeardown {
        if state != .failed, state != .closing, state != .closed {
          try? await transition(to: .failed)
        }
        await tearDown()
      } else {
        await resetChannelAfterFailedOperation(identity: identity)
      }
      throw mapped
    }
  }

  private func performChannelExit(
    identity: SSHChannelIdentity,
    deadline uploadDeadline: ContinuousClock.Instant?
  ) async throws -> SSHExecExit {
    guard let record = channels[identity], record.kind == .exec, let configuration else {
      throw transportError(code: .invalidState, phase: .execExit, scope: .channel(identity))
    }
    let ordinaryDeadline = dependencies.clock.now().advanced(by: configuration.timeouts.execExit)
    let deadline = uploadDeadline.map { min($0, ordinaryDeadline) } ?? ordinaryDeadline
    while libssh2_channel_eof(record.pointer) == 0 {
      try checkChannelDisposition(identity: identity, phase: .execExit)
      try await progress(
        until: deadline,
        phase: .execExit,
        scope: .channel(identity)
      )
    }

    var signal: UnsafeMutablePointer<CChar>?
    var signalLength = 0
    let result = libssh2_channel_get_exit_signal(
      record.pointer,
      &signal,
      &signalLength,
      nil,
      nil,
      nil,
      nil
    )
    guard result == 0 else { return .notReported }
    guard let signal, signalLength > 0 else {
      // libssh2 exposes status 0 without a presence bit. Returning it would
      // fabricate the M3-deferred exact-exit semantic.
      return .notReported
    }
    let name = Data(bytes: signal, count: signalLength).withUnsafeBytes {
      String(decoding: $0.bindMemory(to: UInt8.self), as: UTF8.self)
    }
    if let engineSession { libssh2_free(engineSession, signal) }
    return .signal(
      SSHExecSignal(name: execSignalName(name), coreDumped: .unsupported)
    )
  }

  func channelDeferredWindow(
    identity: SSHChannelIdentity
  ) -> SSHDeferredSemanticReport<SSHReceiveWindowSnapshot> {
    channels[identity] == nil ? .notReported : .unsupported
  }

  func channelCancel(identity: SSHChannelIdentity) async {
    guard channels[identity] != nil else { return }
    counters.channelsCancelled += 1
    await metric(.increment(.channelsCancelled, by: 1))
    await emit(.channelCancelled(identity))
    await channelDispose(
      identity: identity,
      disposition: .cancelled,
      graceful: false,
      terminalEvent: nil
    )
  }

  func channelReset(identity: SSHChannelIdentity) async {
    guard channels[identity] != nil else { return }
    counters.channelsReset += 1
    await metric(.increment(.channelsReset, by: 1))
    await emit(.channelReset(identity))
    await channelDispose(
      identity: identity,
      disposition: .channelReset,
      graceful: false,
      terminalEvent: nil
    )
  }

  /// Cleanup must not inherit cancellation from the failed caller. A fresh
  /// actor-isolated task owns the bounded close/free sequence to completion.
  private func resetChannelAfterFailedOperation(identity: SSHChannelIdentity) async {
    let cleanup = Task { await self.channelReset(identity: identity) }
    await cleanup.value
  }

  func channelClose(identity: SSHChannelIdentity) async {
    guard channels[identity] != nil else { return }
    counters.channelsClosedGracefully += 1
    await metric(.increment(.channelsClosedGracefully, by: 1))
    await channelDispose(
      identity: identity,
      disposition: .channelClosed,
      graceful: true,
      terminalEvent: .channelClosed(identity)
    )
  }

  @discardableResult
  private func channelDispose(
    identity: SSHChannelIdentity,
    disposition: SSHTransportErrorCode,
    graceful: Bool,
    terminalEvent: SSHTransportEventKind?,
    triggersTeardownOnFailure: Bool = true
  ) async -> Bool {
    guard channels[identity] != nil else { return true }
    let task: Task<Bool, Never>
    if let existing = channelDisposalTasks[identity] {
      task = existing
    } else {
      disposingChannels[identity] = disposition
      channelWriteGates[identity]?.cancelPending()
      task = Task { [weak self] in
        guard let self else { return false }
        return await self.performChannelDispose(
          identity: identity,
          graceful: graceful,
          terminalEvent: terminalEvent
        )
      }
      channelDisposalTasks[identity] = task
    }
    let disposed = await task.value
    channelDisposalTasks.removeValue(forKey: identity)
    if !disposed, triggersTeardownOnFailure {
      if state != .failed, state != .closing, state != .closed {
        try? await transition(to: .failed)
      }
      await tearDown()
    }
    return disposed
  }

  private func performChannelDispose(
    identity: SSHChannelIdentity,
    graceful: Bool,
    terminalEvent: SSHTransportEventKind?
  ) async -> Bool {
    await waitForChannelOperationsToDrain(identity: identity)
    guard let record = channels[identity] else { return true }
    let deadline = dependencies.clock.now().advanced(
      by: configuration?.timeouts.channelClose ?? .seconds(1)
    )
    if graceful {
      var closeResult = channelAPI.close(record.pointer)
      while closeResult == LIBSSH2_ERROR_EAGAIN {
        do {
          try await cleanupProgress(until: deadline)
        } catch {
          return false
        }
        closeResult = channelAPI.close(record.pointer)
      }
      guard closeResult == 0 else { return false }
    }
    var freeResult = channelAPI.free(record.pointer)
    while freeResult == LIBSSH2_ERROR_EAGAIN {
      do {
        try await cleanupProgress(until: deadline)
      } catch {
        return false
      }
      freeResult = channelAPI.free(record.pointer)
    }
    guard freeResult == 0 else { return false }
    channels.removeValue(forKey: identity)
    channelWriteGates.removeValue(forKey: identity)
    disposingChannels.removeValue(forKey: identity)
    pendingWriteBytes.removeValue(forKey: identity)
    if let terminalEvent { await emit(terminalEvent) }
    return true
  }

  private func scheduleByteRekeyIfNeeded() async {
    guard let configuration, !byteRekeyScheduled else { return }
    if let completedTask = byteRekeyTask {
      await completedTask.value
      byteRekeyTask = nil
    }
    let threshold = configuration.rekey.protectedByteThresholdPerDirection
    guard
      counters.protectedBytesSent - rekeySentBytesBaseline >= threshold
        || counters.protectedBytesReceived - rekeyReceivedBytesBaseline >= threshold
    else { return }
    byteRekeyScheduled = true
    byteRekeyTask = Task { [weak self] in
      try? await self?.requestRekey(reason: .byteThreshold, waitsForFatalTeardown: false)
      await self?.clearByteRekeySchedule()
    }
  }

  private func clearByteRekeySchedule() {
    byteRekeyScheduled = false
  }

  private func directTCPIPMessage(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) -> Data {
    var data = Data()
    appendSSHString(destination.host, to: &data)
    appendUInt32(UInt32(destination.port), to: &data)
    appendSSHString(originator.host, to: &data)
    appendUInt32(UInt32(originator.port), to: &data)
    return data
  }

  private func appendSSHString(_ value: String, to data: inout Data) {
    let bytes = Data(value.utf8)
    appendUInt32(UInt32(clamping: bytes.count), to: &data)
    data.append(bytes)
  }

  private func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
  }

  private func execSignalName(_ value: String) -> SSHExecSignalName {
    switch value.uppercased() {
    case "HUP": .hangup
    case "INT": .interrupt
    case "QUIT": .quit
    case "ILL": .illegalInstruction
    case "ABRT": .abort
    case "FPE": .floatingPointException
    case "KILL": .kill
    case "SEGV": .segmentationFault
    case "PIPE": .pipe
    case "ALRM": .alarm
    case "TERM": .terminate
    default: .other(value)
    }
  }

  private func tearDown() async {
    let task = startTearDownIfNeeded()
    await task.value
    if teardownTask != nil { teardownTask = nil }
  }

  private func startTearDownIfNeeded() -> Task<Void, Never> {
    if let teardownTask { return teardownTask }
    let task = Task { [weak self] in
      guard let self else { return }
      await self.performTearDown()
    }
    teardownTask = task
    return task
  }

  private func performTearDown() async {
    let deadline = dependencies.clock.now().advanced(
      by: configuration?.timeouts.transportClose ?? .seconds(1)
    )
    let ownedTasks = [
      automaticRekeyTask,
      automaticKeepaliveTask,
      byteRekeyTask,
      rekeyFlightTask,
    ].compactMap { $0 }
    for task in ownedTasks { task.cancel() }
    let automaticTaskDrain: Task<Void, Never>?
    if ownedTasks.isEmpty {
      clearAutomaticTaskReferences()
      automaticTaskDrain = nil
    } else {
      // Start retirement before socket close consumes the shared deadline. A
      // cancellation-ignoring socket must not prevent already-cancelled
      // automatic tasks from eventually clearing their owned references.
      automaticTaskDrain = Task { [weak self] in
        for task in ownedTasks { await task.value }
        await self?.clearAutomaticTaskReferences()
      }
    }
    asyncOperations.cancelAll()
    sessionOperationGate.cancelPending()
    context.network.beginShutdown()
    if let connection, let remaining = remainingDuration(until: deadline) {
      _ = try? await withReservedTimeout(
        remaining,
        clock: dependencies.clock,
        registry: teardownAsyncOperations
      ) {
        await connection.close()
      }
    }
    if let automaticTaskDrain, let remaining = remainingDuration(until: deadline) {
      _ = try? await withReservedTimeout(
        remaining,
        clock: dependencies.clock,
        registry: teardownAsyncOperations
      ) {
        await automaticTaskDrain.value
      }
    }
    // A timeout race resumes its caller when the first child resolves, but it
    // remains owned until both the operation and timer children retire. Drain
    // cooperative children before teardown completes; genuinely
    // non-cooperative work remains counted until its late completion.
    _ = await teardownAsyncOperations.waitForAll(
      until: deadline,
      clock: dependencies.clock
    )
    await waitForConnectToDrain()
    _ = await context.network.drainServices(until: deadline, clock: dependencies.clock)
    context.cancelSignature()
    // Once the socket is closed, consume only libssh2's retained callback
    // state locally so its destructors cannot remain parked behind a stale
    // partially-sent packet. No abort-drain byte reaches the network.
    context.network.beginAbortDrain()
    await waitForChannelOpensToDrain()
    await waitForSessionOperationsToDrain()
    let ownedOperationDrainDeadline = min(
      deadline,
      dependencies.clock.now().advanced(by: .milliseconds(100))
    )
    _ = await asyncOperations.waitForAll(
      until: ownedOperationDrainDeadline,
      clock: dependencies.clock
    )
    for identity in Array(channels.keys) {
      await channelDispose(
        identity: identity,
        disposition: .connectionClosed,
        graceful: false,
        terminalEvent: .channelClosed(identity),
        triggersTeardownOnFailure: false
      )
    }
    var sessionFreed = true
    if let engineSession {
      while libssh2_session_disconnect_ex(
        engineSession,
        Int32(SSH_DISCONNECT_BY_APPLICATION),
        "closed",
        ""
      ) == LIBSSH2_ERROR_EAGAIN {
        do { try await cleanupProgress(until: deadline) } catch { break }
      }
      var freeResult = libssh2_session_free(engineSession)
      var freeAttempts = 0
      while freeResult == LIBSSH2_ERROR_EAGAIN,
        freeAttempts < Self.maximumPendingOperations
      {
        freeAttempts += 1
        // The socket and callback bridge are already terminal. Re-entering the
        // destructor advances libssh2's retained nonblocking sub-operation;
        // yielding between a fixed number of attempts avoids a cleanup spin.
        await Task.yield()
        freeResult = libssh2_session_free(engineSession)
      }
      if freeResult == 0 {
        self.engineSession = nil
        sessionContextPointer = nil
      } else {
        sessionFreed = false
      }
    }
    guard sessionFreed else {
      connection = nil
      negotiatedAlgorithms = nil
      if state != .failed { try? await transition(to: .failed) }
      return
    }
    channels.removeAll(keepingCapacity: false)
    channelWriteGates.removeAll(keepingCapacity: false)
    disposingChannels.removeAll(keepingCapacity: false)
    channelDisposalTasks.removeAll(keepingCapacity: false)
    pendingWriteBytes.removeAll(keepingCapacity: false)
    pendingChannelOperationCounts.removeAll(keepingCapacity: false)
    channelDrainWaiters.removeAll(keepingCapacity: false)
    context.network.discard()
    connection = nil
    negotiatedAlgorithms = nil
    if state != .closed {
      if state != .closing { try? await transition(to: .closing) }
      try? await transition(to: .closed)
    }
  }

  private func remainingDuration(until deadline: ContinuousClock.Instant) -> Duration? {
    let now = dependencies.clock.now()
    guard now < deadline else { return nil }
    return now.duration(to: deadline)
  }

  private func clearAutomaticTaskReferences() {
    automaticRekeyTask = nil
    automaticKeepaliveTask = nil
    byteRekeyTask = nil
    rekeyFlightTask = nil
    rekeyFlightInProgress = false
  }

  private func cleanupProgress(until deadline: ContinuousClock.Instant) async throws {
    let now = dependencies.clock.now()
    guard now < deadline else { throw LibSSH2TimeoutError.elapsed }
    guard let connection, let engineSession else { return }
    let directions = libssh2_session_block_directions(engineSession)
    var interests = Set<SSHTCPReadiness>()
    if directions & LIBSSH2_SESSION_BLOCK_INBOUND != 0 { interests.insert(.readable) }
    if directions & LIBSSH2_SESSION_BLOCK_OUTBOUND != 0 { interests.insert(.writable) }
    if interests.isEmpty { interests = [.readable, .writable] }
    let requestedInterests = interests
    try await withTimeout(
      now.duration(to: deadline),
      clock: dependencies.clock,
      registry: asyncOperations
    ) {
      try await self.context.network.service(
        connection: connection,
        interests: requestedInterests
      )
    }
  }

  private func transition(to next: SSHConnectionState) async throws {
    guard state.permitsTransition(to: next) else {
      throw transportError(code: .invalidState, phase: phase(for: state))
    }
    let previous = state
    state = next
    await emit(.connectionTransition(from: previous, to: next))
  }

  private func recordHostDecision(_ decision: SSHHostKeyDecision) async {
    switch decision.outcome {
    case .firstUseAccepted:
      counters.hostFirstUseAccepted += 1
      await metric(.increment(.hostFirstUseAccepted, by: 1))
    case .matchAccepted:
      counters.hostMatchAccepted += 1
      await metric(.increment(.hostMatchAccepted, by: 1))
    case .unknownRejected:
      counters.hostUnknownRejected += 1
      await metric(.increment(.hostUnknownRejected, by: 1))
    case .changedRejected:
      counters.hostChangedRejected += 1
      await metric(.increment(.hostChangedRejected, by: 1))
    case .algorithmRejected:
      counters.hostAlgorithmRejected += 1
      await metric(.increment(.hostAlgorithmRejected, by: 1))
    case .policyRejected:
      break
    }
    await emit(.hostDecision(decision.outcome))
  }

  private func incrementRekeyCounter(_ reason: SSHClientRekeyReason) {
    switch reason {
    case .byteThreshold: counters.clientByteRekeys += 1
    case .timeThreshold: counters.clientTimeRekeys += 1
    case .test, .manual: counters.explicitRekeys += 1
    }
  }

  private func checkCancellation(
    phase: SSHTransportPhase,
    scope: SSHTransportErrorScope? = nil
  ) throws {
    do {
      if closeRequested { throw CancellationError() }
      try dependencies.cancellation.checkCancellation()
      try Task.checkCancellation()
    } catch {
      throw transportError(code: .cancelled, phase: phase, scope: scope)
    }
  }

  private func emit(_ kind: SSHTransportEventKind) async {
    await reconcileProtectedMetrics()
    let event = SSHTransportEvent(timestamp: dependencies.clock.now(), kind: kind)
    await dependencies.observer.observe(event)
    await dependencies.logger.log(level: .info, event: event)
    await dependencies.experimentRecorder?.record(.event(event))
  }

  private func metric(_ update: SSHMetricUpdate) async {
    await dependencies.metrics.record(update)
  }

  private func reconcileProtectedMetrics() async {
    guard let baseline = protectedNetworkBaseline else { return }
    let current = context.network.engineByteCounts
    let sent = current.sent - baseline.sent
    let received = current.received - baseline.received
    if sent > counters.protectedBytesSent {
      await metric(.increment(.protectedBytesSent, by: sent - counters.protectedBytesSent))
      counters.protectedBytesSent = sent
    }
    if received > counters.protectedBytesReceived {
      await metric(
        .increment(.protectedBytesReceived, by: received - counters.protectedBytesReceived))
      counters.protectedBytesReceived = received
    }
  }

  private func phase(for state: SSHConnectionState) -> SSHTransportPhase {
    switch state {
    case .idle: .configuration
    case .resolving: .resolution
    case .tcpConnecting: .tcpConnect
    case .keyExchange: .initialKeyExchange
    case .awaitingHostDecision: .hostDecision
    case .authenticating: .authentication
    case .ready: .protocolProcessing
    case .rekeying: .rekey
    case .failed: .protocolProcessing
    case .closing, .closed: .transportClose
    }
  }

  private func engineError(
    _ engineCode: Int32,
    phase: SSHTransportPhase,
    fallback: SSHTransportErrorCode,
    scope: SSHTransportErrorScope? = nil
  ) -> SSHTransportError {
    let code: SSHTransportErrorCode
    switch engineCode {
    case LIBSSH2_ERROR_AUTHENTICATION_FAILED: code = .authenticationRejected
    case LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED, LIBSSH2_ERROR_PUBLICKEY_PROTOCOL:
      code = .signatureFailed
    case LIBSSH2_ERROR_CHANNEL_FAILURE: code = .channelOpenRejected
    case LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED: code = .execRejected
    case LIBSSH2_ERROR_CHANNEL_CLOSED, LIBSSH2_ERROR_CHANNEL_EOF_SENT: code = .channelClosed
    case LIBSSH2_ERROR_ALLOC: code = .resourceLimitExceeded
    case LIBSSH2_ERROR_SOCKET_SEND, LIBSSH2_ERROR_SOCKET_RECV,
      LIBSSH2_ERROR_SOCKET_DISCONNECT:
      code = .connectionLost
    case LIBSSH2_ERROR_TIMEOUT, LIBSSH2_ERROR_SOCKET_TIMEOUT: code = .timedOut
    default: code = fallback
    }
    let effectiveScope: SSHTransportErrorScope? =
      switch code {
      case .connectionLost, .connectionClosed:
        nil
      default:
        scope
      }
    return transportError(code: code, phase: phase, scope: effectiveScope)
  }

  private func map(
    _ error: Error,
    phase: SSHTransportPhase,
    fallback: SSHTransportErrorCode = .adapterFailure,
    scope: SSHTransportErrorScope? = nil
  ) -> SSHTransportError {
    if let error = error as? SSHTransportError { return error }
    if error is CancellationError {
      return transportError(code: .cancelled, phase: phase, scope: scope)
    }
    if error is LibSSH2TimeoutError {
      return transportError(code: .timedOut, phase: phase, scope: scope)
    }
    if error is LibSSH2OwnedAsyncOperationRegistryError {
      return transportError(code: .resourceLimitExceeded, phase: phase, scope: scope)
    }
    return transportError(code: fallback, phase: phase, scope: scope)
  }

  private func handleOperationFailure(
    _ error: Error,
    phase: SSHTransportPhase,
    fallback: SSHTransportErrorCode = .adapterFailure,
    scope: SSHTransportErrorScope? = nil,
    resetChannel identity: SSHChannelIdentity? = nil
  ) async -> SSHTransportError {
    let mapped = map(error, phase: phase, fallback: fallback, scope: scope)
    await recordTerminalOperation(mapped)
    await emit(.error(code: mapped.code, phase: mapped.phase, scope: mapped.scope))
    if mapped.requiresTeardown {
      if state != .failed, state != .closing, state != .closed {
        try? await transition(to: .failed)
      }
      await tearDown()
    } else if let identity {
      await resetChannelAfterFailedOperation(identity: identity)
    }
    return mapped
  }

  private func recordTerminalOperation(_ error: SSHTransportError) async {
    if error.code == .timedOut {
      await metric(.increment(.operationsTimedOut, by: 1))
    } else if error.code == .cancelled {
      await metric(.increment(.operationsCancelled, by: 1))
    }
  }

  private func transportError(
    code: SSHTransportErrorCode,
    phase: SSHTransportPhase,
    scope: SSHTransportErrorScope? = nil
  ) -> SSHTransportError {
    if code == .timedOut {
      counters.operationsTimedOut += 1
    } else if code == .cancelled {
      counters.operationsCancelled += 1
    }
    let resolvedScope = scope ?? .lane(lane)
    let operationScoped = scope != nil
    return try! SSHTransportError(
      code: code,
      phase: phase,
      scope: resolvedScope,
      retryDisposition: code == .cancelled || code == .timedOut
        ? (operationScoped ? .sameChannelOperation : .newConnection) : .never,
      requiresTeardown: !operationScoped,
      channelOpenReason: code == .channelOpenRejected ? .unsupported : .notApplicable
    )
  }
}

private final class LibSSH2OperationWaiter: @unchecked Sendable {
  let identifier = UUID()

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

private enum LibSSH2TimeoutError: Error {
  case elapsed
}

protocol LibSSH2OwnedAsyncOperation: AnyObject, Sendable {
  var identifier: UUID { get }
  func cancel()
}

enum LibSSH2OwnedAsyncOperationRegistryError: Error {
  case resourceLimitExceeded
}

/// Retains timeout-raced work after its caller detaches. A dependency that
/// ignores cancellation can no longer hold the public operation or close past
/// its deadline, but remains visible as owned work until it actually returns.
final class LibSSH2OwnedAsyncOperationRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private let maximumOperations: Int
  private var operations: [UUID: any LibSSH2OwnedAsyncOperation] = [:]
  private var drainWaiters: [UUID: (maximumCount: Int, waiter: LibSSH2OperationWaiter)] = [:]

  init(maximumOperations: Int) {
    precondition(maximumOperations > 0)
    self.maximumOperations = maximumOperations
  }

  var outstandingCount: Int {
    lock.withLock { operations.count }
  }

  func register(_ operation: any LibSSH2OwnedAsyncOperation) throws {
    try lock.withLock {
      guard operations.count < maximumOperations else {
        throw LibSSH2OwnedAsyncOperationRegistryError.resourceLimitExceeded
      }
      operations[operation.identifier] = operation
    }
  }

  /// Admits work into capacity held exclusively by one lifecycle owner. The
  /// caller proves the fixed slot count structurally, so teardown cannot lose
  /// socket ownership to ordinary-operation pressure or a discarded error.
  func registerReserved(_ operation: any LibSSH2OwnedAsyncOperation) {
    lock.withLock {
      precondition(operations.count < maximumOperations)
      operations[operation.identifier] = operation
    }
  }

  func remove(identifier: UUID) {
    let waiters: [LibSSH2OperationWaiter] = lock.withLock {
      operations.removeValue(forKey: identifier)
      let ready = drainWaiters.filter { operations.count <= $0.value.maximumCount }
      for identifier in ready.keys { drainWaiters.removeValue(forKey: identifier) }
      return ready.values.map(\.waiter)
    }
    for waiter in waiters { waiter.complete(with: .success(())) }
  }

  func cancelAll() {
    let snapshot = lock.withLock { Array(operations.values) }
    for operation in snapshot { operation.cancel() }
  }

  func waitForAll(
    until deadline: ContinuousClock.Instant,
    clock: any TunnelClock
  ) async -> Bool {
    await waitUntilOutstandingCount(atMost: 0, until: deadline, clock: clock)
  }

  func waitUntilOutstandingCount(
    atMost maximumCount: Int,
    until deadline: ContinuousClock.Instant,
    clock: any TunnelClock
  ) async -> Bool {
    precondition(maximumCount >= 0)
    let waiter = LibSSH2OperationWaiter()
    let waiterIdentifier = waiter.identifier
    let registered = lock.withLock {
      guard operations.count > maximumCount else { return false }
      drainWaiters[waiterIdentifier] = (maximumCount, waiter)
      return true
    }
    guard registered else { return true }
    let now = clock.now()
    guard now < deadline else {
      _ = lock.withLock { drainWaiters.removeValue(forKey: waiterIdentifier) }
      return false
    }
    let timer = Task {
      do {
        try await clock.sleep(for: now.duration(to: deadline))
        waiter.complete(with: .failure(LibSSH2TimeoutError.elapsed))
      } catch {
        waiter.complete(with: .failure(error))
      }
    }
    defer {
      timer.cancel()
      _ = lock.withLock { drainWaiters.removeValue(forKey: waiterIdentifier) }
    }
    do {
      try await waiter.wait()
      return true
    } catch {
      return false
    }
  }
}

private final class LibSSH2TimeoutRace<Value: Sendable>: LibSSH2OwnedAsyncOperation,
  @unchecked Sendable
{
  enum Child {
    case operation
    case timer
  }

  let identifier = UUID()

  private let lock = NSLock()
  private weak var registry: LibSSH2OwnedAsyncOperationRegistry?
  private let timeout: Duration
  private let clock: any TunnelClock
  private let operation: @Sendable () async throws -> Value
  private let cleanupAbandonedResult: (@Sendable (Value) async -> Void)?
  private var operationTask: Task<Void, Never>?
  private var timerTask: Task<Void, Never>?
  private var continuation: CheckedContinuation<Value, Error>?
  private var result: Result<Value, Error>?
  private var completedChildren = 0
  private var started = false

  init(
    timeout: Duration,
    clock: any TunnelClock,
    registry: LibSSH2OwnedAsyncOperationRegistry,
    cleanupAbandonedResult: (@Sendable (Value) async -> Void)?,
    operation: @escaping @Sendable () async throws -> Value
  ) {
    self.timeout = timeout
    self.clock = clock
    self.registry = registry
    self.cleanupAbandonedResult = cleanupAbandonedResult
    self.operation = operation
  }

  func start() {
    let cancellationRequested = lock.withLock { () -> Bool in
      precondition(!started)
      started = true
      operationTask = Task {
        let outcome: Result<Value, Error>
        do {
          outcome = .success(try await self.operation())
        } catch {
          outcome = .failure(error)
        }
        let won = self.resolveChild(.operation, outcome: outcome)
        if !won, case .success(let value) = outcome {
          await self.cleanupAbandonedResult?(value)
        }
        self.finishChild()
      }
      timerTask = Task {
        let outcome: Result<Value, Error>
        do {
          try await self.clock.sleep(for: self.timeout)
          outcome = .failure(LibSSH2TimeoutError.elapsed)
        } catch {
          outcome = .failure(error)
        }
        _ = self.resolveChild(.timer, outcome: outcome)
        self.finishChild()
      }
      return result != nil
    }
    if cancellationRequested { cancelTasks() }
  }

  func wait() async throws -> Value {
    try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        let immediate: Result<Value, Error>? = lock.withLock {
          if Task.isCancelled { return .failure(CancellationError()) }
          if let result { return result }
          self.continuation = continuation
          return nil
        }
        if let immediate { continuation.resume(with: immediate) }
      }
    } onCancel: {
      self.cancel()
    }
  }

  func cancel() {
    completeCallerIfNeeded(with: .failure(CancellationError()))
    cancelTasks()
  }

  private func resolveChild(_ child: Child, outcome: Result<Value, Error>) -> Bool {
    let action = lock.withLock {
      let continuation: CheckedContinuation<Value, Error>?
      let won = result == nil
      if won {
        result = outcome
        continuation = self.continuation
        self.continuation = nil
      } else {
        continuation = nil
      }
      return (continuation, won)
    }
    if action.1 {
      switch child {
      case .operation: timerTask?.cancel()
      case .timer: operationTask?.cancel()
      }
    }
    // Cancellation must be observable before the public waiter resumes. The
    // registry still retains both children until they really finish, so an
    // uncooperative dependency remains accounted for without extending the
    // caller's deadline.
    action.0?.resume(with: outcome)
    return action.1
  }

  private func finishChild() {
    let allChildrenFinished = lock.withLock {
      completedChildren += 1
      return completedChildren == 2
    }
    if allChildrenFinished { registry?.remove(identifier: identifier) }
  }

  private func completeCallerIfNeeded(with outcome: Result<Value, Error>) {
    let continuation: CheckedContinuation<Value, Error>? = lock.withLock {
      guard result == nil else { return nil }
      result = outcome
      defer { self.continuation = nil }
      return self.continuation
    }
    continuation?.resume(with: outcome)
  }

  private func cancelTasks() {
    let tasks = lock.withLock { (operationTask, timerTask) }
    tasks.0?.cancel()
    tasks.1?.cancel()
  }
}

private func withTimeout<Value: Sendable>(
  _ timeout: Duration,
  clock: any TunnelClock,
  registry: LibSSH2OwnedAsyncOperationRegistry,
  cleanupAbandonedResult: (@Sendable (Value) async -> Void)? = nil,
  operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
  let race = LibSSH2TimeoutRace(
    timeout: timeout,
    clock: clock,
    registry: registry,
    cleanupAbandonedResult: cleanupAbandonedResult,
    operation: operation
  )
  try registry.register(race)
  race.start()
  return try await race.wait()
}

private func withReservedTimeout<Value: Sendable>(
  _ timeout: Duration,
  clock: any TunnelClock,
  registry: LibSSH2OwnedAsyncOperationRegistry,
  operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
  let race = LibSSH2TimeoutRace(
    timeout: timeout,
    clock: clock,
    registry: registry,
    cleanupAbandonedResult: nil,
    operation: operation
  )
  registry.registerReserved(race)
  race.start()
  return try await race.wait()
}

extension Duration {
  fileprivate var wholeSeconds: Int64 {
    let components = components
    let fractional = components.attoseconds == 0 ? 0 : 1
    return max(1, components.seconds + Int64(fractional))
  }
}
