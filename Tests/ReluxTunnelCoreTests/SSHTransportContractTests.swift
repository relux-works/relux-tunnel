import Foundation
import ReluxTunnelCore
import Testing

@Suite("Candidate-neutral SSH transport contract")
struct SSHTransportContractTests {
  @Test("every SSH requirement has an explicit M0 or M3 tier")
  func conformanceTiers() {
    let deferred = SSHConformanceRequirement.allCases.filter {
      if case .m3Deferred = $0.tier { return true }
      return false
    }

    #expect(
      deferred == [
        .consumerDrivenReceiveWindowCredit,
        .rfcChannelOpenFailureReasons,
        .exactExecExitMetadata,
        .deepRekeyAndKeepaliveObservability,
      ])
    #expect(
      deferred.allSatisfy {
        $0.tier == .m3Deferred(ownerTaskID: "TASK-260728-3cveay")
      }
    )
    #expect(
      SSHConformanceRequirement.allCases.filter { $0.tier == .m0ViabilityMandatory }.count
        == 16
    )
  }

  @Test("connection state transitions reject lifecycle shortcuts")
  func connectionStateTransitions() {
    let validPath: [(SSHConnectionState, SSHConnectionState)] = [
      (.idle, .resolving),
      (.resolving, .tcpConnecting),
      (.tcpConnecting, .keyExchange),
      (.keyExchange, .awaitingHostDecision),
      (.awaitingHostDecision, .authenticating),
      (.authenticating, .ready),
      (.ready, .rekeying),
      (.rekeying, .ready),
      (.ready, .closing),
      (.closing, .closed),
    ]

    for (current, next) in validPath {
      #expect(current.permitsTransition(to: next))
    }
    #expect(SSHConnectionState.idle.permitsConnect)
    #expect(!SSHConnectionState.resolving.permitsConnect)
    #expect(SSHConnectionState.ready.permitsChannelOpen)
    #expect(!SSHConnectionState.rekeying.permitsChannelOpen)
    #expect(!SSHConnectionState.idle.permitsTransition(to: .ready))
    #expect(!SSHConnectionState.closed.permitsTransition(to: .resolving))
    #expect(!SSHConnectionState.ready.permitsTransition(to: .ready))
    #expect(SSHConnectionState.authenticating.permitsTransition(to: .failed))
    #expect(SSHConnectionState.failed.permitsTransition(to: .closing))
  }

  @Test("caller-owned policies reject invalid bounds and durations")
  func policyValidation() throws {
    #expect(throws: SSHContractValidationError.nonPositive(.initialReceiveWindowBytes)) {
      _ = try SSHChannelPolicy(
        initialReceiveWindowBytes: 0,
        consumerReceiveWindowCredit: .unsupported,
        maximumBufferedReadBytes: 8,
        maximumQueuedWriteBytes: 4,
        maximumWriteCallBytes: 8
      )
    }
    #expect(throws: SSHContractValidationError.initialReceiveWindowExceedsCap) {
      _ = try SSHConsumerReceiveWindowPolicy(
        initialReceiveWindowBytes: 9,
        maximumAdvertisedReceiveWindowBytes: 8,
        windowAdjustThresholdBytes: 4
      )
    }
    #expect(throws: SSHContractValidationError.windowAdjustThresholdExceedsCap) {
      _ = try SSHConsumerReceiveWindowPolicy(
        initialReceiveWindowBytes: 8,
        maximumAdvertisedReceiveWindowBytes: 8,
        windowAdjustThresholdBytes: 9
      )
    }
    let reportedReceiveWindow = try SSHConsumerReceiveWindowPolicy(
      initialReceiveWindowBytes: 8,
      maximumAdvertisedReceiveWindowBytes: 8,
      windowAdjustThresholdBytes: 4
    )
    #expect(reportedReceiveWindow.initialReceiveWindowBytes == 8)
    #expect(throws: SSHContractValidationError.initialReceiveWindowPolicyMismatch) {
      _ = try SSHChannelPolicy(
        initialReceiveWindowBytes: 9,
        consumerReceiveWindowCredit: .reported(reportedReceiveWindow),
        maximumBufferedReadBytes: 8,
        maximumQueuedWriteBytes: 4,
        maximumWriteCallBytes: 8
      )
    }
    #expect(throws: SSHContractValidationError.nonPositive(.protectedByteThresholdPerDirection)) {
      _ = try SSHRekeyPolicy(
        protectedByteThresholdPerDirection: 0,
        elapsedTimeThreshold: .seconds(1),
        timeout: .seconds(1)
      )
    }
    #expect(throws: SSHContractValidationError.nonPositive(.keepaliveInterval)) {
      _ = try SSHKeepalivePolicy(
        interval: .zero,
        replyTimeout: .seconds(1),
        allowedConsecutiveMisses: 1
      )
    }
    #expect(throws: SSHContractValidationError.negative(.allowedConsecutiveKeepaliveMisses)) {
      _ = try SSHKeepalivePolicy(
        interval: .seconds(1),
        replyTimeout: .seconds(1),
        allowedConsecutiveMisses: -1
      )
    }
    #expect(throws: SSHContractValidationError.nonPositive(.uploadTimeout)) {
      _ = try fixtureTimeouts(upload: .zero)
    }

    let policy = try fixtureChannelPolicy()
    #expect(throws: SSHContractValidationError.uploadChunkExceedsWriteCallLimit) {
      _ = try SSHExecUploadRequest(
        exec: SSHExecRequest(command: "upload-command"),
        source: FixtureUploadSource(chunks: []),
        channelPolicy: policy,
        chunkBytes: policy.maximumWriteCallBytes + 1
      )
    }
    #expect(throws: SSHContractValidationError.empty(.endpointHost)) {
      _ = try fixtureConnectionConfiguration(endpoint: TunnelEndpoint(host: "", port: 22))
    }
    #expect(throws: SSHContractValidationError.nonPositive(.endpointPort)) {
      _ = try fixtureConnectionConfiguration(endpoint: TunnelEndpoint(host: "ssh.example", port: 0))
    }
    #expect(throws: SSHContractValidationError.empty(.execCommand)) {
      _ = try SSHExecRequest(command: "")
    }
    let viabilityPolicy = try SSHChannelPolicy(
      initialReceiveWindowBytes: 8,
      consumerReceiveWindowCredit: .unsupported,
      maximumBufferedReadBytes: 8,
      maximumQueuedWriteBytes: 4,
      maximumWriteCallBytes: 8
    )
    #expect(viabilityPolicy.consumerReceiveWindowCredit == .unsupported)
    let unreportedPolicy = try SSHChannelPolicy(
      initialReceiveWindowBytes: 9,
      consumerReceiveWindowCredit: .notReported,
      maximumBufferedReadBytes: 8,
      maximumQueuedWriteBytes: 4,
      maximumWriteCallBytes: 8
    )
    #expect(unreportedPolicy.consumerReceiveWindowCredit == .notReported)
  }

  @Test("host evidence is canonical and acceptance gates credential lookup")
  func hostPolicyPrecedesCredentials() async throws {
    let recorder = OrderingRecorder()
    let lane = fixtureLane()
    let evidence = try SSHHostKeyEvidence(
      algorithm: "ssh-ed25519",
      keyBytes: Data("abc".utf8)
    )
    #expect(
      evidence.fingerprint
        == "SHA256:ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0"
    )
    #expect(!evidence.fingerprint.hasSuffix("="))

    let input = SSHHostKeyPolicyInput(
      canonicalHostname: "private-host.example",
      connectedEndpoint: TunnelEndpoint(host: "private-host.example", port: 22),
      evidence: evidence,
      lane: lane,
      trustRecordReference: SSHTrustRecordReference(rawValue: "trust-record")
    )
    let policy = OrderingHostPolicy(recorder: recorder)
    let provider = OrderingCredentialProvider(recorder: recorder)
    let decision = try await policy.evaluate(input)
    let acceptedHost = try decision.acceptance(for: input)
    _ = try await provider.credential(
      for: SSHCredentialRequest(
        credentialReference: SSHCredentialReference(rawValue: "credential-reference"),
        username: "private-user",
        allowedPublicKeyAlgorithms: ["ssh-ed25519"],
        acceptedHost: acceptedHost
      )
    )

    #expect(await recorder.events() == [.hostPolicy, .credentialLookup])
    #expect(acceptedHost.evidence == evidence)
    #expect(acceptedHost.outcome == .matchAccepted)

    #expect(throws: SSHHostAcceptanceError.rejected(.changedRejected)) {
      _ = try SSHHostKeyDecision.rejectChanged.acceptance(for: input)
    }
    #expect(throws: SSHContractValidationError.empty(.trustRecordReference)) {
      _ = try SSHHostKeyDecision.acceptFirstUse(
        SSHTrustRecordReference(rawValue: "")
      ).acceptance(for: input)
    }
    let expectedError = try SSHTransportError(
      code: .hostKeyChanged,
      phase: .hostDecision,
      scope: .lane(lane),
      retryDisposition: .afterConfigurationChange,
      requiresTeardown: true,
      channelOpenReason: .notApplicable
    )
    #expect(SSHTransportError.hostDecisionFailure(.rejectChanged, lane: lane) == expectedError)
  }

  @Test("all public-key authentication outcomes map without losing their category")
  func authenticationOutcomeMapping() {
    let lane = fixtureLane()
    let expected: [(SSHAuthenticationOutcome, SSHTransportErrorCode?)] = [
      (.success, nil),
      (.rejectedByServer, .authenticationRejected),
      (.methodUnavailable, .authenticationMethodUnavailable),
      (.keyAlgorithmUnavailable, .authenticationKeyAlgorithmUnavailable),
      (.credentialUnavailable, .credentialUnavailable),
      (.credentialInteractionRequired, .credentialInteractionRequired),
      (.signatureFailed, .signatureFailed),
      (.cancelled, .cancelled),
      (.timedOut, .timedOut),
    ]

    #expect(SSHAuthenticationOutcome.allCases.count == expected.count)
    for (outcome, code) in expected {
      #expect(SSHTransportError.authenticationFailure(outcome, lane: lane)?.code == code)
    }
    #expect(
      SSHTransportError.authenticationFailure(.credentialUnavailable, lane: lane)?.phase
        == .credentialLookup
    )
    #expect(
      SSHTransportError.authenticationFailure(.rejectedByServer, lane: lane)?
        .retryDisposition == .never
    )
    #expect(
      SSHTransportError.authenticationFailure(.cancelled, lane: lane)?.retryDisposition
        == .newConnection
    )
  }

  @Test("channel protocols preserve endpoints, partial writes, stream EOF, and exit results")
  func channelSurface() async throws {
    let policy = try fixtureChannelPolicy()
    let directWindow = try SSHReceiveWindowSnapshot(
      initialReceiveWindowBytes: 8,
      maximumAdvertisedReceiveWindowBytes: 8,
      remainingProtocolCreditBytes: 2,
      bufferedUnreadBytes: 3,
      deliveredButNotYetReturnedCreditBytes: 3,
      adjustmentCount: 1,
      cumulativeAdjustmentBytes: 3
    )
    let execWindow = try SSHReceiveWindowSnapshot(
      initialReceiveWindowBytes: 4,
      maximumAdvertisedReceiveWindowBytes: 4,
      remainingProtocolCreditBytes: 1,
      bufferedUnreadBytes: 2,
      deliveredButNotYetReturnedCreditBytes: 1,
      adjustmentCount: 2,
      cumulativeAdjustmentBytes: 5
    )
    let direct = BoundedFixtureChannel(
      identity: fixtureChannelID(1),
      policy: policy,
      stdout: Data("abcdef".utf8),
      stderr: Data(),
      exit: .notReported,
      window: directWindow
    )
    let exec = BoundedFixtureChannel(
      identity: fixtureChannelID(2),
      policy: policy,
      stdout: Data("stdout".utf8),
      stderr: Data("stderr".utf8),
      exit: .status(23),
      window: execWindow
    )
    let transport = FixtureTransport(lane: fixtureLane(), direct: direct, exec: exec)
    let destination = TunnelEndpoint(host: "destination.private", port: 443)
    let originator = TunnelEndpoint(host: "origin.private", port: 49152)

    let openedDirect = try await transport.openDirectTCPIP(
      destination: destination,
      originator: originator,
      policy: policy
    )
    #expect(await transport.directRequest() == DirectRequest(destination, originator, policy))
    #expect(openedDirect.identity == direct.identity)
    #expect(try await openedDirect.read(maximumBytes: 2) == Data("ab".utf8))
    #expect(try await openedDirect.read(maximumBytes: 8) == Data("cdef".utf8))
    #expect(try await openedDirect.read(maximumBytes: 8) == nil)
    #expect(try await openedDirect.writeSome(Data("12345678".utf8)) == 4)
    #expect(try await openedDirect.writeSome(Data("5678".utf8)) == 4)
    #expect(await direct.writtenBytes() == Data("12345678".utf8))
    #expect(await openedDirect.receiveWindow() == .reported(directWindow))

    try await openedDirect.finishWriting()
    try await openedDirect.finishWriting()
    await #expect(throws: SSHTransportError.self) {
      _ = try await openedDirect.writeSome(Data([1]))
    }
    await openedDirect.close()
    await openedDirect.close()
    #expect(await direct.closeInvocationCount() == 1)

    let request = try SSHExecRequest(command: "private exec command")
    let openedExec = try await transport.openExecChannel(request: request, policy: policy)
    #expect(await transport.execRequest() == ExecRequest(request, policy))
    #expect(try await openedExec.read(maximumBytes: 6) == Data("stdout".utf8))
    #expect(
      try await openedExec.readStandardError(maximumBytes: 6) == Data("stderr".utf8)
    )
    #expect(try await openedExec.waitForExit() == .status(23))
    #expect(await openedExec.receiveWindow() == .reported(execWindow))
    #expect(directWindow.maximumAdvertisedReceiveWindowBytes == 8)
    #expect(execWindow.maximumAdvertisedReceiveWindowBytes == 4)
  }

  @Test("window snapshots and adjustments enforce immutable caps")
  func windowValidation() throws {
    #expect(throws: SSHContractValidationError.invalidWindowSnapshot) {
      _ = try SSHReceiveWindowSnapshot(
        initialReceiveWindowBytes: 8,
        maximumAdvertisedReceiveWindowBytes: 8,
        remainingProtocolCreditBytes: 6,
        bufferedUnreadBytes: 3,
        deliveredButNotYetReturnedCreditBytes: 0,
        adjustmentCount: 0,
        cumulativeAdjustmentBytes: 0
      )
    }
    #expect(throws: SSHContractValidationError.invalidWindowAdjustment) {
      _ = try SSHWindowAdjustment(
        channel: fixtureChannelID(1),
        before: 7,
        amount: 2,
        after: 9,
        cap: 8
      )
    }
    #expect(throws: SSHContractValidationError.invalidWindowAdjustment) {
      _ = try SSHWindowAdjustment(
        channel: fixtureChannelID(1),
        before: Int.max,
        amount: 1,
        after: Int.max,
        cap: Int.max
      )
    }
    let adjustment = try SSHWindowAdjustment(
      channel: fixtureChannelID(1),
      before: 3,
      amount: 4,
      after: 7,
      cap: 8
    )
    #expect(adjustment.after <= adjustment.cap)
    #expect(adjustment.before + adjustment.amount == adjustment.after)
    #expect(
      SSHDeferredSemanticReport<SSHReceiveWindowSnapshot>.notReported == .notReported
    )
    #expect(
      SSHDeferredSemanticReport<SSHReceiveWindowSnapshot>.unsupported == .unsupported
    )
  }

  @Test("exec upload is typed as bounded exec stdin with no subsystem surface")
  func execUpload() async throws {
    let source = FixtureUploadSource(chunks: [Data("chunk".utf8)])
    let request = try SSHExecUploadRequest(
      exec: SSHExecRequest(command: "private upload command"),
      source: source,
      channelPolicy: fixtureChannelPolicy(),
      chunkBytes: 4
    )
    let transport = FixtureTransport(lane: fixtureLane())

    #expect(request.chunkBytes == 4)
    #expect(try await request.source.read(maximumBytes: request.chunkBytes) == Data("chun".utf8))
    #expect(try await transport.upload(request) == .status(0))
  }

  @Test("byte, time, explicit, server rekey and keepalive share typed events")
  func rekeyAndKeepaliveSchema() throws {
    let clock = ContinuousClock()
    let reasons: Set<SSHRekeyReason> = [
      .client(.byteThreshold),
      .client(.timeThreshold),
      .client(.test),
      .client(.manual),
      .serverInitiated,
    ]
    let events = [
      SSHTransportEvent(timestamp: clock.now, kind: .rekeyTriggered(reasons)),
      SSHTransportEvent(
        timestamp: clock.now,
        kind: .rekeyStarted(reasons: reasons, generation: 7)
      ),
      SSHTransportEvent(
        timestamp: clock.now,
        kind: .rekeySucceeded(reasons: reasons, generation: 8)
      ),
      SSHTransportEvent(
        timestamp: clock.now,
        kind: .rekeyFailed(reasons: reasons, generation: 8, code: .rekeyFailed)
      ),
      SSHTransportEvent(timestamp: clock.now, kind: .keepaliveSent),
      SSHTransportEvent(
        timestamp: clock.now,
        kind: .keepaliveAcknowledged(roundTripTime: .milliseconds(4))
      ),
      SSHTransportEvent(
        timestamp: clock.now,
        kind: .keepaliveTimedOut(consecutiveMisses: 2)
      ),
    ]

    #expect(SSHClientRekeyReason.allCases == [.byteThreshold, .timeThreshold, .test, .manual])
    #expect(events.allSatisfy { $0.schemaVersion == 1 })
    #expect(try fixtureConnectionConfiguration().rekey.protectedByteThresholdPerDirection == 64)
    #expect(try fixtureConnectionConfiguration().keepalive.allowedConsecutiveMisses == 2)
    #expect(
      SSHExecSignal(name: .terminate, coreDumped: .notReported).coreDumped == .notReported
    )
    #expect(SSHExecExit.unsupported == .unsupported)
  }

  @Test("stable errors expose every common code and no engine payload")
  func stableErrors() throws {
    let expectedCodes = [
      "cancelled", "timedOut", "invalidArgument", "invalidState", "operationInProgress",
      "unsupportedCapability", "resolutionFailed", "networkUnavailable", "connectionLost",
      "connectionClosed", "hostKeyUnknown", "hostKeyChanged", "hostKeyRejected",
      "hostKeyAlgorithmRejected", "algorithmNegotiationFailed", "authenticationRejected",
      "authenticationMethodUnavailable", "authenticationKeyAlgorithmUnavailable",
      "credentialUnavailable", "credentialInteractionRequired", "signatureFailed",
      "channelOpenRejected", "channelLimitReached", "channelClosed", "peerReset",
      "channelReset", "writeAfterEOF", "backpressureTimedOut", "execRejected",
      "rekeyFailed", "keepaliveFailed", "protocolViolation", "resourceLimitExceeded",
      "adapterFailure",
    ]
    #expect(SSHTransportErrorCode.allCases.map(\.rawValue) == expectedCodes)

    let rejection = try SSHTransportError(
      code: .channelOpenRejected,
      phase: .channelOpen,
      scope: .channel(fixtureChannelID(3)),
      retryDisposition: .never,
      requiresTeardown: false,
      channelOpenReason: .reported(.administrativelyProhibited)
    )
    #expect(rejection.channelOpenReason == .reported(.administrativelyProhibited))
    let unsupported = try SSHTransportError(
      code: .channelOpenRejected,
      phase: .channelOpen,
      scope: .channel(fixtureChannelID(4)),
      retryDisposition: .never,
      requiresTeardown: false,
      channelOpenReason: .unsupported
    )
    #expect(unsupported.channelOpenReason == .unsupported)
    let notReported = try SSHTransportError(
      code: .channelOpenRejected,
      phase: .channelOpen,
      scope: .channel(fixtureChannelID(5)),
      retryDisposition: .never,
      requiresTeardown: false,
      channelOpenReason: .notReported
    )
    #expect(notReported.channelOpenReason == .notReported)
    #expect(throws: SSHContractValidationError.channelOpenReasonRequired) {
      _ = try SSHTransportError(
        code: .channelOpenRejected,
        phase: .channelOpen,
        scope: .channel(fixtureChannelID(6)),
        retryDisposition: .never,
        requiresTeardown: false,
        channelOpenReason: .notApplicable
      )
    }
    #expect(throws: SSHContractValidationError.channelOpenReasonUnexpected) {
      _ = try SSHTransportError(
        code: .authenticationRejected,
        phase: .authentication,
        scope: .lane(fixtureLane()),
        retryDisposition: .never,
        requiresTeardown: true,
        channelOpenReason: .notReported
      )
    }
    #expect(!rejection.requiresTeardown)
    #expect(!String(reflecting: rejection).contains("underlying"))
  }

  @Test("schema-v1 metrics contain exactly the reviewed counters and gauges")
  func metricSchema() {
    let expectedCounters = [
      "connectAttempts", "connectSucceeded", "connectFailed", "operationsCancelled",
      "operationsTimedOut", "hostFirstUseAccepted", "hostMatchAccepted",
      "hostUnknownRejected", "hostChangedRejected", "hostAlgorithmRejected",
      "authenticationAttempts", "authenticationSucceeded", "authenticationRejected",
      "directChannelsOpened", "execChannelsOpened", "channelOpenFailed",
      "channelsClosedGracefully", "channelsReset", "channelsCancelled", "payloadBytesSent",
      "payloadBytesReceived", "protectedBytesSent", "protectedBytesReceived",
      "writeBackpressureWaits", "windowAdjustments", "windowAdjustmentBytes",
      "clientByteRekeys", "clientTimeRekeys", "explicitRekeys", "serverRekeys",
      "rekeysSucceeded", "rekeysFailed", "keepalivesSent", "keepalivesAcknowledged",
      "keepalivesTimedOut",
    ]
    let expectedGauges = [
      "openDirectChannels", "openExecChannels", "pendingChannelOpens", "pendingReads",
      "pendingWrites", "queuedWriteBytes", "bufferedReadBytes",
      "remainingReceiveWindowBytes", "activeKeyExchange", "consecutiveKeepaliveMisses",
      "lastKeepaliveRTTNanoseconds",
    ]

    #expect(
      SSHTransportSnapshot(
        lane: fixtureLane(),
        connectionState: .idle,
        negotiatedAlgorithms: nil,
        keyExchangeGeneration: .notReported,
        counters: fixtureCounters(),
        gauges: fixtureGauges()
      ).schemaVersion == 1
    )
    #expect(
      SSHTransportEvent(
        timestamp: ContinuousClock().now,
        kind: .keepaliveSent
      ).schemaVersion == 1
    )
    #expect(SSHMetricCounter.allCases.map(\.rawValue) == expectedCounters)
    #expect(SSHMetricGauge.allCases.map(\.rawValue) == expectedGauges)
    #expect(
      Mirror(reflecting: fixtureCounters()).children.compactMap(\.label)
        == expectedCounters
    )
    #expect(
      Mirror(reflecting: fixtureGauges()).children.compactMap(\.label)
        == expectedGauges
    )
  }

  @Test("events, metrics, errors, and typed logs exclude sensitive contract inputs")
  func privacySafeDiagnostics() async throws {
    let logger = FixtureLogger()
    let event = SSHTransportEvent(
      timestamp: ContinuousClock().now,
      kind: .error(
        code: .channelOpenRejected,
        phase: .channelOpen,
        scope: .channel(fixtureChannelID(9))
      )
    )
    await logger.log(level: .error, event: event)
    let snapshot = SSHTransportSnapshot(
      lane: fixtureLane(),
      connectionState: .ready,
      negotiatedAlgorithms: fixtureNegotiatedAlgorithms(),
      keyExchangeGeneration: .reported(4),
      counters: fixtureCounters(payloadBytesSent: 17, payloadBytesReceived: 19),
      gauges: fixtureGauges(
        openDirectChannels: 1,
        remainingReceiveWindowBytes: .reported(8)
      )
    )
    let error = try SSHTransportError(
      code: .authenticationRejected,
      phase: .authentication,
      scope: .lane(fixtureLane()),
      retryDisposition: .never,
      requiresTeardown: true,
      channelOpenReason: .notApplicable
    )
    let diagnostics = [
      String(reflecting: event),
      String(reflecting: snapshot),
      String(reflecting: error),
      await logger.renderedEvents(),
    ].joined(separator: "\n")
    let sentinels = [
      "private-host.example",
      "203.0.113.44",
      "SHA256:private-fingerprint",
      "private-user",
      "credential-reference-private",
      "destination.private",
      "origin.private",
      "private exec command",
      "/private/remote/path",
      "private-key-material",
      "payload-secret",
    ]

    for sentinel in sentinels {
      #expect(!diagnostics.contains(sentinel))
    }
  }

  @Test("factories erase candidate types behind one dependency shape")
  func candidateTypeErasure() async throws {
    let dependencies = sshDependencies()
    let factories: [any SSHTransportFactory] = [FixtureFactoryA(), FixtureFactoryB()]

    #expect(factories.count == 2)
    for factory in factories {
      let transport = try await factory.makeTransport(
        lane: fixtureLane(),
        dependencies: dependencies
      )
      #expect(await transport.snapshot().lane == fixtureLane())
      #expect(factory.capabilities.features.contains(.boundedReceiveBuffers))
      #expect(factory.capabilities.features.contains(.serverRekey))
      #expect(
        factory.capabilities.deferredSemantics.consumerDrivenReceiveWindowCredit
          == .unsupported
      )
    }
  }
}

private enum OrderingEvent: Equatable, Sendable {
  case hostPolicy
  case credentialLookup
}

private actor OrderingRecorder {
  private var recorded: [OrderingEvent] = []

  func record(_ event: OrderingEvent) {
    recorded.append(event)
  }

  func events() -> [OrderingEvent] {
    recorded
  }
}

private struct OrderingHostPolicy: SSHHostKeyPolicy {
  let recorder: OrderingRecorder

  func evaluate(_ input: SSHHostKeyPolicyInput) async throws -> SSHHostKeyDecision {
    #expect(input.evidence.algorithm == "ssh-ed25519")
    #expect(input.evidence.keyBytes == Data("abc".utf8))
    #expect(input.evidence.fingerprint.hasPrefix("SHA256:"))
    await recorder.record(.hostPolicy)
    return .acceptMatch(SSHTrustRecordReference(rawValue: "trust-record"))
  }
}

private struct OrderingCredentialProvider: SSHCredentialProvider {
  let recorder: OrderingRecorder

  func credential(for request: SSHCredentialRequest) async throws -> any SSHPublicKeyCredential {
    #expect(request.acceptedHost.outcome == .matchAccepted)
    await recorder.record(.credentialLookup)
    return FixtureCredential()
  }
}

private struct FixtureCredential: SSHPublicKeyCredential {
  let algorithm = "ssh-ed25519"
  let publicKeyBytes = Data("public-key".utf8)

  func sign(_ payload: Data) async throws -> Data {
    Data(payload.reversed())
  }
}

private struct DirectRequest: Equatable, Sendable {
  let destination: TunnelEndpoint
  let originator: TunnelEndpoint
  let policy: SSHChannelPolicy

  init(_ destination: TunnelEndpoint, _ originator: TunnelEndpoint, _ policy: SSHChannelPolicy) {
    self.destination = destination
    self.originator = originator
    self.policy = policy
  }
}

private struct ExecRequest: Equatable, Sendable {
  let request: SSHExecRequest
  let policy: SSHChannelPolicy

  init(_ request: SSHExecRequest, _ policy: SSHChannelPolicy) {
    self.request = request
    self.policy = policy
  }
}

private actor FixtureTransport: SSHTransport {
  private let lane: SSHLaneIdentity
  private let directChannel: BoundedFixtureChannel
  private let execChannel: BoundedFixtureChannel
  private var recordedDirectRequest: DirectRequest?
  private var recordedExecRequest: ExecRequest?

  init(
    lane: SSHLaneIdentity,
    direct: BoundedFixtureChannel? = nil,
    exec: BoundedFixtureChannel? = nil
  ) {
    self.lane = lane
    self.directChannel = direct ?? BoundedFixtureChannel.fixture(identity: fixtureChannelID(10))
    self.execChannel = exec ?? BoundedFixtureChannel.fixture(identity: fixtureChannelID(11))
  }

  func connect(configuration: SSHConnectionConfiguration) async throws -> SSHSession {
    let evidence = try SSHHostKeyEvidence(algorithm: "ssh-ed25519", keyBytes: Data("abc".utf8))
    let input = SSHHostKeyPolicyInput(
      canonicalHostname: configuration.canonicalHostname,
      connectedEndpoint: configuration.endpoint,
      evidence: evidence,
      lane: lane,
      trustRecordReference: configuration.trustRecordReference
    )
    let accepted = try SSHHostKeyDecision.acceptMatch(
      configuration.trustRecordReference ?? SSHTrustRecordReference(rawValue: "fixture-trust")
    ).acceptance(for: input)
    return SSHSession(
      identity: SSHSessionIdentity(
        rawValue: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
      ),
      acceptedHost: accepted,
      negotiatedAlgorithms: fixtureNegotiatedAlgorithms(),
      keyExchangeGeneration: .reported(1)
    )
  }

  func openDirectTCPIP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint,
    policy: SSHChannelPolicy
  ) async throws -> any SSHByteChannel {
    recordedDirectRequest = DirectRequest(destination, originator, policy)
    return directChannel
  }

  func openExecChannel(
    request: SSHExecRequest,
    policy: SSHChannelPolicy
  ) async throws -> any SSHExecChannel {
    recordedExecRequest = ExecRequest(request, policy)
    return execChannel
  }

  func upload(_ request: SSHExecUploadRequest) async throws -> SSHExecExit {
    .status(0)
  }

  func requestRekey(reason: SSHClientRekeyReason) async throws {}

  func sendKeepalive() async throws -> SSHDeferredSemanticReport<Duration> {
    .reported(.milliseconds(1))
  }

  func snapshot() -> SSHTransportSnapshot {
    SSHTransportSnapshot(
      lane: lane,
      connectionState: .idle,
      negotiatedAlgorithms: nil,
      keyExchangeGeneration: .notReported,
      counters: fixtureCounters(),
      gauges: fixtureGauges()
    )
  }

  func close() async {}

  func directRequest() -> DirectRequest? {
    recordedDirectRequest
  }

  func execRequest() -> ExecRequest? {
    recordedExecRequest
  }
}

private actor BoundedFixtureChannel: SSHExecChannel {
  nonisolated let identity: SSHChannelIdentity

  private let policy: SSHChannelPolicy
  private let window: SSHReceiveWindowSnapshot
  private let exit: SSHExecExit
  private var stdout: Data
  private var stderr: Data
  private var written = Data()
  private var eofSent = false
  private var closed = false
  private var closeCount = 0

  init(
    identity: SSHChannelIdentity,
    policy: SSHChannelPolicy,
    stdout: Data,
    stderr: Data,
    exit: SSHExecExit,
    window: SSHReceiveWindowSnapshot
  ) {
    self.identity = identity
    self.policy = policy
    self.stdout = stdout
    self.stderr = stderr
    self.exit = exit
    self.window = window
  }

  static func fixture(identity: SSHChannelIdentity) -> BoundedFixtureChannel {
    BoundedFixtureChannel(
      identity: identity,
      policy: try! fixtureChannelPolicy(),
      stdout: Data(),
      stderr: Data(),
      exit: .notReported,
      window: try! SSHReceiveWindowSnapshot(
        initialReceiveWindowBytes: 8,
        maximumAdvertisedReceiveWindowBytes: 8,
        remainingProtocolCreditBytes: 8,
        bufferedUnreadBytes: 0,
        deliveredButNotYetReturnedCreditBytes: 0,
        adjustmentCount: 0,
        cumulativeAdjustmentBytes: 0
      )
    )
  }

  func read(maximumBytes: Int) async throws -> Data? {
    try readPrefix(from: &stdout, maximumBytes: maximumBytes)
  }

  func readStandardError(maximumBytes: Int) async throws -> Data? {
    try readPrefix(from: &stderr, maximumBytes: maximumBytes)
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    guard !bytes.isEmpty, bytes.count <= policy.maximumWriteCallBytes else {
      throw channelError(code: .invalidArgument, phase: .channelWrite)
    }
    guard !eofSent else {
      throw channelError(code: .writeAfterEOF, phase: .channelWrite)
    }
    guard !closed else {
      throw channelError(code: .channelClosed, phase: .channelWrite)
    }
    let accepted = min(bytes.count, policy.maximumQueuedWriteBytes)
    written.append(bytes.prefix(accepted))
    return accepted
  }

  func finishWriting() async throws {
    guard !closed else {
      throw channelError(code: .channelClosed, phase: .channelEOF)
    }
    eofSent = true
  }

  func receiveWindow() async -> SSHDeferredSemanticReport<SSHReceiveWindowSnapshot> {
    .reported(window)
  }

  func cancel() async {
    closed = true
  }

  func reset() async {
    stdout.removeAll()
    stderr.removeAll()
    closed = true
  }

  func close() async {
    guard !closed else { return }
    closeCount += 1
    closed = true
  }

  func waitForExit() async throws -> SSHExecExit {
    exit
  }

  func writtenBytes() -> Data {
    written
  }

  func closeInvocationCount() -> Int {
    closeCount
  }

  private func readPrefix(from buffer: inout Data, maximumBytes: Int) throws -> Data? {
    guard maximumBytes > 0 else {
      throw channelError(code: .invalidArgument, phase: .channelRead)
    }
    guard !buffer.isEmpty else { return nil }
    let count = min(maximumBytes, buffer.count)
    let result = Data(buffer.prefix(count))
    buffer.removeFirst(count)
    return result
  }

  private func channelError(
    code: SSHTransportErrorCode,
    phase: SSHTransportPhase
  ) -> SSHTransportError {
    try! SSHTransportError(
      code: code,
      phase: phase,
      scope: .channel(identity),
      retryDisposition: .never,
      requiresTeardown: false,
      channelOpenReason: .notApplicable
    )
  }
}

private actor FixtureUploadSource: SSHUploadSource {
  private var chunks: [Data]

  init(chunks: [Data]) {
    self.chunks = chunks
  }

  func read(maximumBytes: Int) async throws -> Data? {
    guard maximumBytes > 0, !chunks.isEmpty else { return nil }
    let chunk = chunks.removeFirst()
    if chunk.count <= maximumBytes {
      return chunk
    }
    let prefix = Data(chunk.prefix(maximumBytes))
    chunks.insert(Data(chunk.dropFirst(maximumBytes)), at: 0)
    return prefix
  }
}

private struct FixtureFactoryA: SSHTransportFactory {
  let capabilities = fixtureCapabilities()

  func makeTransport(
    lane: SSHLaneIdentity,
    dependencies: SSHTransportDependencies
  ) async throws -> any SSHTransport {
    FixtureTransport(lane: lane)
  }
}

private struct FixtureFactoryB: SSHTransportFactory {
  let capabilities = fixtureCapabilities()

  func makeTransport(
    lane: SSHLaneIdentity,
    dependencies: SSHTransportDependencies
  ) async throws -> any SSHTransport {
    FixtureTransport(lane: lane)
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
  func connect(to endpoint: SSHResolvedEndpoint) async throws -> any SSHTCPConnection {
    FixtureTCPConnection()
  }
}

private actor FixtureTCPConnection: SSHTCPConnection {
  func waitForReadiness(_ interests: Set<SSHTCPReadiness>) async throws
    -> Set<SSHTCPReadiness>
  {
    interests
  }

  func readSome(maximumBytes: Int) async throws -> Data? { nil }
  func writeSome(_ bytes: Data) async throws -> Int { bytes.count }
  func close() async {}
}

private struct FixtureHostPolicy: SSHHostKeyPolicy {
  func evaluate(_ input: SSHHostKeyPolicyInput) async throws -> SSHHostKeyDecision {
    .acceptMatch(SSHTrustRecordReference(rawValue: "fixture-trust"))
  }
}

private struct FixtureCredentialProvider: SSHCredentialProvider {
  func credential(for request: SSHCredentialRequest) async throws -> any SSHPublicKeyCredential {
    FixtureCredential()
  }
}

private actor FixtureLogger: SSHTransportLogger {
  private var events: [SSHTransportEvent] = []

  func log(level: TunnelLogLevel, event: SSHTransportEvent) async {
    events.append(event)
  }

  func renderedEvents() -> String {
    String(reflecting: events)
  }
}

private struct FixtureObserver: SSHTransportObserver {
  func observe(_ event: SSHTransportEvent) async {}
}

private struct FixtureMetrics: SSHTransportMetricsSink {
  func record(_ update: SSHMetricUpdate) async {}
}

private struct FixtureIdentityGenerator: SSHIdentityGenerator {
  func makeLaneIdentity() -> SSHLaneIdentity { fixtureLane() }
  func makeSessionIdentity() -> SSHSessionIdentity {
    SSHSessionIdentity(rawValue: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!)
  }
  func makeChannelIdentity() -> SSHChannelIdentity { fixtureChannelID(1) }
}

private func sshDependencies() -> SSHTransportDependencies {
  SSHTransportDependencies(
    resolver: FixtureResolver(),
    connector: FixtureConnector(),
    hostKeyPolicy: FixtureHostPolicy(),
    credentialProvider: FixtureCredentialProvider(),
    clock: ContinuousTunnelClock(),
    cancellation: TaskCancellationChecker(),
    logger: FixtureLogger(),
    observer: FixtureObserver(),
    metrics: FixtureMetrics(),
    identityGenerator: FixtureIdentityGenerator()
  )
}

private func fixtureLane() -> SSHLaneIdentity {
  SSHLaneIdentity(rawValue: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!)
}

private func fixtureChannelID(_ value: Int) -> SSHChannelIdentity {
  SSHChannelIdentity(
    rawValue: UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", value))!
  )
}

private func fixtureCapabilities() -> SSHAdapterCapabilities {
  SSHAdapterCapabilities(
    features: Set(SSHAdapterFeature.allCases),
    deferredSemantics: SSHDeferredSemanticCapabilities(
      consumerDrivenReceiveWindowCredit: .unsupported,
      rfcChannelOpenFailureReasons: .unsupported,
      exactExecExitMetadata: .notReported,
      deepRekeyAndKeepaliveObservability: .unsupported
    ),
    keyExchangeAlgorithms: ["curve25519-sha256"],
    hostKeyAlgorithms: ["ssh-ed25519", "rsa-sha2-512"],
    cipherAlgorithms: ["aes128-gcm@openssh.com"],
    macAlgorithms: ["hmac-sha2-256"],
    publicKeyAuthenticationAlgorithms: ["ssh-ed25519", "rsa-sha2-512"]
  )
}

private func fixtureCounters(
  payloadBytesSent: UInt64 = 0,
  payloadBytesReceived: UInt64 = 0
) -> SSHTransportCounters {
  SSHTransportCounters(
    payloadBytesSent: payloadBytesSent,
    payloadBytesReceived: payloadBytesReceived,
    windowAdjustments: .unsupported,
    windowAdjustmentBytes: .unsupported,
    serverRekeys: .notReported,
    keepalivesAcknowledged: .notReported,
    keepalivesTimedOut: .notReported
  )
}

private func fixtureGauges(
  openDirectChannels: Int64 = 0,
  remainingReceiveWindowBytes: SSHDeferredSemanticReport<Int64> = .unsupported
) -> SSHTransportGauges {
  SSHTransportGauges(
    openDirectChannels: openDirectChannels,
    remainingReceiveWindowBytes: remainingReceiveWindowBytes,
    activeKeyExchange: .notReported,
    consecutiveKeepaliveMisses: .notReported,
    lastKeepaliveRTTNanoseconds: .notReported
  )
}

private func fixtureChannelPolicy() throws -> SSHChannelPolicy {
  let receiveWindow = try SSHConsumerReceiveWindowPolicy(
    initialReceiveWindowBytes: 8,
    maximumAdvertisedReceiveWindowBytes: 8,
    windowAdjustThresholdBytes: 4
  )
  return try SSHChannelPolicy(
    initialReceiveWindowBytes: 8,
    consumerReceiveWindowCredit: .reported(receiveWindow),
    maximumBufferedReadBytes: 8,
    maximumQueuedWriteBytes: 4,
    maximumWriteCallBytes: 8
  )
}

private func fixtureTimeouts(upload: Duration = .seconds(1)) throws -> SSHTimeoutPolicy {
  try SSHTimeoutPolicy(
    resolution: .seconds(1),
    tcpConnect: .seconds(1),
    initialKeyExchange: .seconds(1),
    hostDecision: .seconds(1),
    credentialLookup: .seconds(1),
    authentication: .seconds(1),
    channelOpen: .seconds(1),
    writeCreditWait: .seconds(1),
    explicitRekey: .seconds(1),
    keepaliveReply: .seconds(1),
    execExit: .seconds(1),
    upload: upload,
    channelClose: .seconds(1),
    transportClose: .seconds(1)
  )
}

private func fixtureConnectionConfiguration(
  endpoint: TunnelEndpoint = TunnelEndpoint(host: "ssh.example", port: 22)
) throws -> SSHConnectionConfiguration {
  try SSHConnectionConfiguration(
    canonicalHostname: "ssh.example",
    endpoint: endpoint,
    username: "fixture-user",
    profileReference: TunnelConfigurationReference(
      profileIdentifier: OpaqueProfileIdentifier(
        UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
      )
    ),
    credentialReference: SSHCredentialReference(rawValue: "fixture-credential"),
    trustRecordReference: SSHTrustRecordReference(rawValue: "fixture-trust"),
    algorithms: SSHAlgorithmPolicy(
      keyExchange: ["curve25519-sha256"],
      hostKey: ["ssh-ed25519"],
      cipher: ["aes128-gcm@openssh.com"],
      mac: ["hmac-sha2-256"]
    ),
    timeouts: fixtureTimeouts(),
    rekey: SSHRekeyPolicy(
      protectedByteThresholdPerDirection: 64,
      elapsedTimeThreshold: .seconds(30),
      timeout: .seconds(2)
    ),
    keepalive: SSHKeepalivePolicy(
      interval: .seconds(10),
      replyTimeout: .seconds(2),
      allowedConsecutiveMisses: 2
    )
  )
}

private func fixtureNegotiatedAlgorithms() -> SSHNegotiatedAlgorithms {
  SSHNegotiatedAlgorithms(
    keyExchange: "curve25519-sha256",
    hostKey: "ssh-ed25519",
    cipherClientToServer: "aes128-gcm@openssh.com",
    cipherServerToClient: "aes128-gcm@openssh.com",
    macClientToServer: "implicit",
    macServerToClient: "implicit"
  )
}
