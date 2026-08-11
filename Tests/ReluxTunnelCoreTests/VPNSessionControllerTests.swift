import Foundation
import ReluxTunnelCore
import Testing

@Suite("VPN session controller")
struct VPNSessionControllerTests {
  private let reference = TunnelConfigurationReference(
    profileIdentifier: OpaqueProfileIdentifier(
      UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    )
  )
  private let profileStartRequest = RuntimeStartRequest(
    configurationGeneration: 7,
    snapshotDigestSHA256: try! SSHProfileSnapshotDigestSHA256(
      String(repeating: "a", count: 64)
    )
  )

  @Test("start preflight maps every system status without duplicate start calls")
  func startPreflightMatrix() async throws {
    for status in [
      VPNManagerSessionStatus.connecting,
      .connected,
      .reasserting,
      .disconnecting,
      .invalid,
    ] {
      let session = FakeHostSession(status: status)
      session.installCurrentProviderSnapshot()
      let sessions = status == .invalid ? [session, session] : [session]
      let repository = FakeHostSessionRepository(
        sessions.map { fresh($0, enabled: true) }
      )
      let controller = VPNSessionController(repository: repository)

      do {
        let outcome = try await controller.start()
        switch status {
        case .connecting: #expect(outcome == .alreadyStarting)
        case .connected: #expect(outcome == .alreadyConnected)
        case .reasserting: #expect(outcome == .systemReasserting)
        default: Issue.record("Unexpected start success for \(status)")
        }
      } catch let error as VPNSessionControllerError {
        switch status {
        case .disconnecting: #expect(error == .sessionBusyDisconnecting)
        case .invalid: #expect(error == .sessionInvalid)
        default: Issue.record("Unexpected start error \(error) for \(status)")
        }
      }

      #expect(session.startCount == 0)
      #expect(repository.loadCount == (status == .invalid ? 2 : 1))
      await controller.retire()
    }
  }

  @Test("start sends exactly one bounded v1 request matching stored snapshot bytes")
  func startRequestIsExactAndBounded() async throws {
    let session = FakeHostSession(status: .disconnected)
    session.installCurrentProviderSnapshot(generation: 4, sequence: 9)
    session.onStart = {
      session.setStatus(.connected, notifying: true)
    }
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)])
    )

    #expect(try await controller.start() == .connected)
    #expect(session.startCount == 1)
    let options = try #require(session.startOptions.first)
    #expect(Set(options.keys) == [VPNSessionController.startRequestKey])
    let data = try #require(options[VPNSessionController.startRequestKey])
    #expect(data.count <= RuntimeStartRequest.maximumEncodedSize)
    #expect(
      try RuntimeConfigurationCodec.decodeStartRequest(data)
        == profileStartRequest
    )
    #expect(
      (await controller.currentProjection()).providerFacts?.position
        == .init(
          runtimeGeneration: 4,
          snapshotSequence: 9
        ))
  }

  @Test("synchronous start errors use stable mappings")
  func synchronousStartErrors() async throws {
    let cases: [(VPNPreferencePlatformError, VPNSessionControllerError)] = [
      (
        .init(kind: .configurationInvalid, domain: "NEVPNErrorDomain", code: 1),
        .configurationInvalid
      ),
      (
        .init(kind: .configurationDisabled, domain: "NEVPNErrorDomain", code: 2),
        .configurationDisabled
      ),
      (
        .init(kind: .connectionFailed, domain: "NEVPNErrorDomain", code: 3),
        .connectionFailed
      ),
      (
        .init(kind: .other, domain: "Custom", code: 42),
        .platformRejected(domain: "Custom", code: 42)
      ),
    ]

    for (platformError, expected) in cases {
      let session = FakeHostSession(status: .disconnected)
      session.startError = platformError
      let controller = VPNSessionController(
        repository: FakeHostSessionRepository([fresh(session, enabled: true)])
      )
      await #expect(throws: expected) {
        try await controller.start()
      }
      #expect(session.startCount == 1)
      #expect(session.stopCount == 0)
    }
  }

  @Test("start timeout stops once and never projects connected")
  func startTimeoutStopsOnce() async throws {
    let clock = ManualSessionClock()
    let session = FakeHostSession(status: .disconnected)
    session.onStart = { session.setStatus(.connecting, notifying: false) }
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)]),
      clock: clock
    )
    let task = Task { try await controller.start() }

    await clock.waitUntilRegistered(.seconds(60))
    clock.fire(.seconds(60))
    await #expect(throws: VPNSessionControllerError.startTimedOut) {
      try await task.value
    }
    #expect(session.stopCount == 1)
    #expect((await controller.currentProjection()).systemStatus == .connecting)
    #expect((await controller.currentProjection()).providerFacts == nil)
  }

  @Test("caller cancellation after accepted start stops once")
  func startCancellationStopsOnce() async throws {
    let clock = ManualSessionClock()
    let session = FakeHostSession(status: .disconnected)
    session.onStart = { session.setStatus(.connecting, notifying: false) }
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)]),
      clock: clock
    )
    let task = Task { try await controller.start() }

    await clock.waitUntilRegistered(.seconds(60))
    task.cancel()
    await #expect(throws: VPNSessionControllerError.operationCancelled) {
      try await task.value
    }
    #expect(session.stopCount == 1)
  }

  @Test("controller retirement cancels start wait without stopping the tunnel")
  func retirementNeverStopsAcceptedStart() async throws {
    let clock = ManualSessionClock()
    let session = FakeHostSession(status: .disconnected)
    session.onStart = { session.setStatus(.connecting, notifying: false) }
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)]),
      clock: clock
    )
    let task = Task { try await controller.start() }

    await clock.waitUntilRegistered(.seconds(60))
    await controller.retire()
    await #expect(throws: VPNSessionControllerError.operationCancelled) {
      try await task.value
    }
    #expect(session.stopCount == 0)
    #expect(session.observerCount == 0)
  }

  @Test("terminal start fetches and maps the last disconnect error exactly once")
  func terminalStartMapsReason() async throws {
    let session = FakeHostSession(status: .disconnected)
    session.disconnectError = VPNPlatformError(
      domain: VPNDisconnectErrorMapping.providerErrorDomain,
      code: 1008
    )
    session.onStart = { session.setStatus(.disconnected, notifying: true) }
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)])
    )

    await #expect(
      throws: VPNSessionControllerError.startFailed(.providerNetworkSettingsFailed)
    ) {
      try await controller.start()
    }
    #expect(session.fetchDisconnectCount == 1)
    #expect(
      (await controller.currentProjection()).disconnectReason
        == .providerNetworkSettingsFailed
    )
  }

  @Test("stop maps every status and never duplicates the stop call")
  func stopStatusMatrix() async throws {
    for status in [
      VPNManagerSessionStatus.invalid,
      .disconnected,
      .connecting,
      .connected,
      .reasserting,
      .disconnecting,
    ] {
      let session = FakeHostSession(status: status)
      if status == .disconnecting {
        session.registrationTransition = (.disconnected, false)
      } else if !status.isTerminal {
        session.onStop = { session.setStatus(.disconnected, notifying: true) }
      }
      let controller = VPNSessionController(
        repository: FakeHostSessionRepository([fresh(session, enabled: false)])
      )

      let outcome = try await controller.stop()
      if status.isTerminal {
        #expect(outcome == .alreadyStopped(status))
      } else {
        #expect(outcome == .stopped(.disconnected))
      }
      #expect(session.stopCount == ((!status.isTerminal && status != .disconnecting) ? 1 : 0))
      await controller.retire()
    }
  }

  @Test("concurrent stops join one fresh load one system stop and one terminal wait")
  func concurrentStopsJoin() async throws {
    let session = FakeHostSession(status: .connected)
    let repository = FakeHostSessionRepository([fresh(session, enabled: true)])
    let controller = VPNSessionController(repository: repository)
    let first = Task { try await controller.stop() }
    await session.waitForObserverCount(1)
    let second = Task { try await controller.stop() }
    await Task.yield()

    #expect(session.stopCount == 1)
    #expect(repository.loadCount == 1)
    session.setStatus(.disconnected, notifying: true)
    #expect(try await first.value == .stopped(.disconnected))
    #expect(try await second.value == .stopped(.disconnected))
  }

  @Test("stop timeout never claims cleanup and cancellation does not issue another stop")
  func stopTimeoutAndCancellation() async throws {
    let clock = ManualSessionClock()
    let session = FakeHostSession(status: .connected)
    session.installCurrentProviderSnapshot()
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)]),
      clock: clock
    )
    let task = Task { try await controller.stop() }

    await clock.waitUntilRegistered(.seconds(15))
    clock.fire(.seconds(15))
    await #expect(throws: VPNSessionControllerError.stopTimedOut) {
      try await task.value
    }
    #expect(session.stopCount == 1)
    #expect((await controller.currentProjection()).systemStatus == .connected)

    let cancellingSession = FakeHostSession(status: .connected)
    let cancellingController = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(cancellingSession, enabled: true)]),
      clock: clock
    )
    let cancelled = Task { try await cancellingController.stop() }
    await cancellingSession.waitForObserverCount(1)
    cancelled.cancel()
    await #expect(throws: VPNSessionControllerError.operationCancelled) {
      try await cancelled.value
    }
    #expect(cancellingSession.stopCount == 1)

    let joined = Task { try await cancellingController.stop() }
    cancellingSession.setStatus(.disconnected, notifying: true)
    let joinedOutcome = try await joined.value
    #expect(
      joinedOutcome == .stopped(.disconnected)
        || joinedOutcome == .alreadyStopped(.disconnected)
    )
    #expect(cancellingSession.stopCount == 1)
  }

  @Test("every non-connected system status clears provider capability")
  func nonConnectedStatusesClearCapability() async throws {
    for status in [
      VPNManagerSessionStatus.invalid,
      .disconnected,
      .connecting,
      .reasserting,
      .disconnecting,
    ] {
      let session = FakeHostSession(status: status)
      session.installCurrentProviderSnapshot()
      let controller = VPNSessionController(
        repository: FakeHostSessionRepository([fresh(session, enabled: true)])
      )
      let projection = try await controller.reconcile()
      #expect(projection.systemStatus == status)
      #expect(projection.providerFacts == nil)
      #expect(session.messageCount == 0)
      await controller.retire()
    }
  }

  @Test("connected projection recovers only from matching current provider snapshots")
  func connectedProjectionRecoversFromProvider() async throws {
    let session = FakeHostSession(status: .connected)
    session.installCurrentProviderSnapshot(generation: 8, sequence: 13, udp: false)
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)])
    )

    let projection = try await controller.reconcile()
    let facts = try #require(projection.providerFacts)
    #expect(facts.position == .init(runtimeGeneration: 8, snapshotSequence: 13))
    #expect(facts.isConnectedDegraded)
    #expect(session.messageCount == 3)
  }

  @Test("stale and out-of-order provider facts clear capability")
  func staleSnapshotsStayUnknown() async throws {
    let session = FakeHostSession(status: .connected)
    session.installCurrentProviderSnapshot(generation: 7, sequence: 5)
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)])
    )
    #expect(try await controller.reconcile().providerFacts != nil)

    session.installCurrentProviderSnapshot(generation: 7, sequence: 4)
    session.setStatus(.connected, notifying: true)
    await session.waitForMessageCount(6)
    await eventually {
      await controller.currentProjection().providerFacts == nil
    }
    #expect((await controller.currentProjection()).systemStatus == .connected)
  }

  @Test("recreated controller accepts a fresh response without app-owned history")
  func appRecreationRecoversFromAuthorities() async throws {
    let session = FakeHostSession(status: .connected)
    session.installCurrentProviderSnapshot(generation: 12, sequence: 2)
    let repository = FakeHostSessionRepository([fresh(session, enabled: true)])
    let first = VPNSessionController(repository: repository)
    #expect(try await first.reconcile().providerFacts != nil)
    await first.retire()

    let second = VPNSessionController(repository: repository)
    #expect(try await second.reconcile().providerFacts != nil)
    #expect(session.messageCount == 6)
    #expect(session.stopCount == 0)
  }

  @Test("nil wrong-request corrupt unsupported future-schema and mismatched snapshots stay unknown")
  func invalidProviderResponsesStayUnknown() async throws {
    let behaviors: [FakeHostSession.MessageBehavior] = [
      .nilResponse,
      .wrongRequest,
      .corrupt,
      .unsupportedProtocol,
      .futureSchema,
      .mismatchedPositions,
    ]
    for behavior in behaviors {
      let session = FakeHostSession(status: .connected)
      session.messageBehavior = behavior
      let controller = VPNSessionController(
        repository: FakeHostSessionRepository([fresh(session, enabled: true)])
      )
      let projection = try await controller.reconcile()
      #expect(projection.systemStatus == .connected)
      #expect(projection.providerFacts == nil)
      await controller.retire()
    }
  }

  @Test("provider message timeout cancellation and late response cannot publish capability")
  func providerMessageTimeoutCancellationAndLateResponse() async throws {
    let clock = ManualSessionClock()
    let session = FakeHostSession(status: .connected)
    session.messageBehavior = .deferred
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)]),
      clock: clock
    )
    let timedOut = Task { try await controller.reconcile() }
    await clock.waitUntilRegistered(.seconds(3))
    clock.fire(.seconds(3))
    #expect(try await timedOut.value.providerFacts == nil)
    session.completeDeferredMessagesWithCurrentSnapshot()
    #expect((await controller.currentProjection()).providerFacts == nil)

    let cancellingSession = FakeHostSession(status: .connected)
    cancellingSession.messageBehavior = .deferred
    let cancellingController = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(cancellingSession, enabled: true)]),
      clock: clock
    )
    let cancelled = Task { try await cancellingController.reconcile() }
    await cancellingSession.waitForMessageCount(1)
    cancelled.cancel()
    _ = try await cancelled.value
    cancellingSession.completeDeferredMessagesWithCurrentSnapshot()
    #expect((await cancellingController.currentProjection()).providerFacts == nil)
  }

  @Test("last disconnect timeout and cancellation supplement but never change system status")
  func lastDisconnectTimeoutAndCancellation() async throws {
    let clock = ManualSessionClock()
    let timedOutSession = FakeHostSession(status: .disconnected)
    timedOutSession.disconnectBehavior = .deferred
    let timedOutController = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(timedOutSession, enabled: true)]),
      clock: clock
    )
    let timedOut = Task { try await timedOutController.reconcile() }
    await clock.waitUntilRegistered(.seconds(3))
    clock.fire(.seconds(3))
    let timedOutProjection = try await timedOut.value
    #expect(timedOutProjection.systemStatus == .disconnected)
    #expect(
      timedOutProjection.disconnectReason
        == .disconnectReasonUnavailable(.timeout)
    )
    timedOutSession.completeDeferredDisconnectError(
      VPNPlatformError(domain: VPNDisconnectErrorMapping.connectionErrorDomain, code: 8)
    )
    #expect(
      (await timedOutController.currentProjection()).disconnectReason
        == .disconnectReasonUnavailable(.timeout)
    )

    let cancelledSession = FakeHostSession(status: .invalid)
    cancelledSession.disconnectBehavior = .deferred
    let cancelledController = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(cancelledSession, enabled: true)]),
      clock: clock
    )
    let cancelled = Task { try await cancelledController.reconcile() }
    await eventually { cancelledSession.fetchDisconnectCount == 1 }
    cancelled.cancel()
    let cancelledProjection = try await cancelled.value
    #expect(cancelledProjection.systemStatus == .invalid)
    #expect(
      cancelledProjection.disconnectReason
        == .disconnectReasonUnavailable(.cancelled)
    )
  }

  @Test("a newer provider generation resets the sequence baseline")
  func newerGenerationResetsSequenceBaseline() async throws {
    let session = FakeHostSession(status: .connected)
    session.installCurrentProviderSnapshot(generation: 20, sequence: 50)
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)])
    )
    #expect(
      try await controller.reconcile().providerFacts?.position
        == .init(
          runtimeGeneration: 20,
          snapshotSequence: 50
        ))

    session.installCurrentProviderSnapshot(generation: 21, sequence: 1)
    session.setStatus(.connected, notifying: true)
    await session.waitForMessageCount(6)
    await eventually {
      await controller.currentProjection().providerFacts?.position
        == .init(
          runtimeGeneration: 21,
          snapshotSequence: 1
        )
    }
  }

  @Test("non-running provider lifecycle facts suppress every capability claim")
  func nonRunningLifecycleSuppressesCapabilities() {
    let lifecycle = RuntimeLifecycleSnapshot(
      runtimeGeneration: 1,
      snapshotSequence: 2,
      lifecycleState: .connecting,
      routeState: .installed,
      tcp: true,
      safeDNS: true,
      udp: true,
      routeMode: .compatible,
      routesInstalled: true,
      healthy: true
    )
    let capabilities = RuntimeCapabilitySnapshot(
      runtimeGeneration: 1,
      snapshotSequence: 2,
      tcp: true,
      safeDNS: true,
      udp: true,
      routeMode: .compatible,
      routesInstalled: true,
      healthy: true
    )
    let facts = VPNProviderFacts(lifecycle: lifecycle, capabilities: capabilities)
    #expect(!facts.capabilities.tcp)
    #expect(!facts.capabilities.safeDNS)
    #expect(!facts.capabilities.udp)
    #expect(!facts.capabilities.routesInstalled)
    #expect(!facts.capabilities.healthy)
  }

  @Test("controller deallocation releases its exact-session observer without stopping")
  func deallocationReleasesObserver() async throws {
    let session = FakeHostSession(status: .connecting)
    weak var released: VPNSessionController?
    do {
      var controller: VPNSessionController? = VPNSessionController(
        repository: FakeHostSessionRepository([fresh(session, enabled: true)])
      )
      released = controller
      _ = try await controller?.reconcile()
      #expect(session.observerCount == 1)
      controller = nil
    }
    await eventually { released == nil && session.observerCount == 0 }
    #expect(session.stopCount == 0)
  }

  @Test("initial observer registration race reads authoritative status and retirement releases it")
  func initialReadRegistrationRaceAndRelease() async throws {
    let session = FakeHostSession(status: .connected)
    session.registrationTransition = (.disconnected, false)
    let controller = VPNSessionController(
      repository: FakeHostSessionRepository([fresh(session, enabled: true)])
    )

    let projection = try await controller.reconcile()
    #expect(projection.systemStatus == .disconnected)
    #expect(projection.providerFacts == nil)
    #expect(session.observerCount == 1)
    await controller.retire()
    #expect(session.observerCount == 0)
    #expect(session.stopCount == 0)
  }

  @Test("start-stop race uses one system stop and converges from fresh status")
  func startStopRace() async throws {
    let clock = ManualSessionClock()
    let session = FakeHostSession(status: .disconnected)
    session.onStart = { session.setStatus(.connecting, notifying: false) }
    session.onStop = { session.setStatus(.disconnected, notifying: true) }
    let repository = FakeHostSessionRepository([
      fresh(session, enabled: true),
      fresh(session, enabled: true),
    ])
    let controller = VPNSessionController(repository: repository, clock: clock)
    let start = Task { try await controller.start() }
    await clock.waitUntilRegistered(.seconds(60))
    let stop = Task { try await controller.stop() }

    let stopOutcome = try await stop.value
    #expect(
      stopOutcome == .stopped(.disconnected)
        || stopOutcome == .alreadyStopped(.disconnected)
    )
    await #expect(throws: VPNSessionControllerError.operationCancelled) {
      try await start.value
    }
    #expect(session.startCount == 1)
    #expect(session.stopCount == 1)
    #expect((await controller.currentProjection()).systemStatus == .disconnected)
  }

  @Test("all public system and provider disconnect codes map exactly")
  func disconnectErrorTable() {
    let system: [VPNDisconnectReason] = [
      .systemOverslept,
      .networkUnavailable,
      .unrecoverableNetworkChange,
      .configurationFailed,
      .serverResolutionFailed,
      .serverNotResponding,
      .serverUnavailable,
      .authenticationFailed,
      .clientCertificateInvalid,
      .clientCertificateNotYetValid,
      .clientCertificateExpired,
      .providerProcessFailed,
      .configurationNotFound,
      .providerUnavailableOrUpdateRequired,
      .negotiationFailed,
      .serverDisconnected,
      .serverCertificateInvalid,
      .serverCertificateNotYetValid,
      .serverCertificateExpired,
    ]
    for (offset, expected) in system.enumerated() {
      #expect(
        VPNDisconnectErrorMapping.map(
          VPNPlatformError(
            domain: VPNDisconnectErrorMapping.connectionErrorDomain,
            code: offset + 1
          )
        ) == expected
      )
    }

    let provider: [VPNDisconnectReason] = [
      .providerConfigurationInvalid,
      .providerConfigurationSchemaUnsupported,
      .providerStartReferenceMismatch,
      .providerLifecycleBusy,
      .providerStartCancelled,
      .providerStartupTimedOut,
      .providerRuntimeStartupFailed,
      .providerNetworkSettingsFailed,
      .providerInternalInvariant,
    ]
    for (offset, expected) in provider.enumerated() {
      #expect(
        VPNDisconnectErrorMapping.map(
          VPNPlatformError(
            domain: VPNDisconnectErrorMapping.providerErrorDomain,
            code: 1001 + offset
          )
        ) == expected
      )
    }

    #expect(
      VPNDisconnectErrorMapping.map(
        VPNPlatformError(domain: VPNDisconnectErrorMapping.providerErrorDomain, code: 1999)
      ) == .providerFailureUnknown(code: 1999)
    )
    #expect(
      VPNDisconnectErrorMapping.map(VPNPlatformError(domain: "Other", code: 3))
        == .systemDisconnectUnknown(domain: "Other", code: 3)
    )
    #expect(
      VPNDisconnectErrorMapping.map(nil)
        == .systemDisconnectedWithoutReportedError
    )
    #expect(
      VPNDisconnectErrorMapping.map(nil, startTerminatedStatus: .invalid)
        == .startTerminatedWithoutError(status: .invalid)
    )
  }

  private func fresh(
    _ session: FakeHostSession,
    enabled: Bool
  ) -> FreshOwnedVPNSession {
    FreshOwnedVPNSession(
      session: session,
      configurationReference: reference,
      startRequest: profileStartRequest,
      isEnabled: enabled
    )
  }
}

private final class FakeHostSessionRepository: VPNHostSessionRepository, @unchecked Sendable {
  private let lock = NSLock()
  private var sessions: [FreshOwnedVPNSession]
  private var _loadCount = 0

  init(_ sessions: [FreshOwnedVPNSession]) {
    self.sessions = sessions
  }

  var loadCount: Int { lock.withLock { _loadCount } }

  func loadFreshOwnedSession(requireEnabled: Bool) async throws -> FreshOwnedVPNSession {
    let fresh = lock.withLock { () -> FreshOwnedVPNSession? in
      _loadCount += 1
      guard !sessions.isEmpty else { return nil }
      if sessions.count == 1 { return sessions[0] }
      return sessions.removeFirst()
    }
    guard let fresh else { throw VPNManagerRepositoryError.ownedManagerNotFound }
    if requireEnabled, !fresh.isEnabled {
      throw VPNManagerRepositoryError.configurationDisabled
    }
    return fresh
  }
}

private final class FakeHostSession: VPNHostSession, @unchecked Sendable {
  enum MessageBehavior: Sendable {
    case current
    case nilResponse
    case wrongRequest
    case corrupt
    case unsupportedProtocol
    case futureSchema
    case mismatchedPositions
    case deferred
  }

  enum DisconnectBehavior: Equatable, Sendable {
    case immediate
    case deferred
  }

  private final class Observation: VPNPreferenceObservation, @unchecked Sendable {
    private let lock = NSLock()
    private var cancellation: (@Sendable () -> Void)?

    init(_ cancellation: @escaping @Sendable () -> Void) {
      self.cancellation = cancellation
    }

    func cancel() {
      let cancellation = lock.withLock {
        defer { self.cancellation = nil }
        return self.cancellation
      }
      cancellation?()
    }

    deinit { cancel() }
  }

  private let lock = NSLock()
  private var state: VPNManagerSessionStatus
  private var observers: [UUID: @Sendable () -> Void] = [:]
  private var observerWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
  private var messageWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
  private var deferredMessages: [(RuntimeCommand, @Sendable (Data?) -> Void)] = []
  private var deferredDisconnects: [@Sendable (VPNPlatformError?) -> Void] = []
  private var snapshotGeneration: UInt64 = 1
  private var snapshotSequence: UInt64 = 1
  private var snapshotUDP = false
  private var _startCount = 0
  private var _startOptions: [[String: Data]] = []
  private var _stopCount = 0
  private var _messageCount = 0
  private var _fetchDisconnectCount = 0

  var onStart: (@Sendable () -> Void)?
  var onStop: (@Sendable () -> Void)?
  var startError: VPNPreferencePlatformError?
  var disconnectError: VPNPlatformError?
  var disconnectBehavior: DisconnectBehavior = .immediate
  var messageBehavior: MessageBehavior = .current
  var registrationTransition: (VPNManagerSessionStatus, Bool)?

  init(status: VPNManagerSessionStatus) {
    state = status
  }

  var status: VPNManagerSessionStatus { lock.withLock { state } }
  var startCount: Int { lock.withLock { _startCount } }
  var startOptions: [[String: Data]] { lock.withLock { _startOptions } }
  var stopCount: Int { lock.withLock { _stopCount } }
  var messageCount: Int { lock.withLock { _messageCount } }
  var fetchDisconnectCount: Int { lock.withLock { _fetchDisconnectCount } }
  var observerCount: Int { lock.withLock { observers.count } }

  func installCurrentProviderSnapshot(
    generation: UInt64 = 1,
    sequence: UInt64 = 1,
    udp: Bool = false
  ) {
    lock.withLock {
      snapshotGeneration = generation
      snapshotSequence = sequence
      snapshotUDP = udp
      messageBehavior = .current
    }
  }

  func startTunnel(options: [String: Data]) throws {
    let error = lock.withLock { () -> VPNPreferencePlatformError? in
      _startCount += 1
      _startOptions.append(options)
      return startError
    }
    if let error { throw error }
    onStart?()
  }

  func stopTunnel() {
    lock.withLock { _stopCount += 1 }
    onStop?()
  }

  func sendProviderMessage(
    _ message: Data,
    responseHandler: @escaping @Sendable (Data?) -> Void
  ) throws {
    let command = try RuntimeMessageCodec.decodeCommand(message)
    let values = lock.withLock {
      () -> (
        MessageBehavior, UInt64, UInt64, Bool, [CheckedContinuation<Void, Never>]
      ) in
      _messageCount += 1
      let waiters = messageWaiters.filter { _messageCount >= $0.0 }.map(\.1)
      messageWaiters.removeAll { _messageCount >= $0.0 }
      return (
        messageBehavior,
        snapshotGeneration,
        snapshotSequence,
        snapshotUDP,
        waiters
      )
    }
    for waiter in values.4 { waiter.resume() }

    switch values.0 {
    case .nilResponse:
      responseHandler(nil)
    case .corrupt:
      responseHandler(Data("{".utf8))
    case .deferred:
      lock.withLock { deferredMessages.append((command, responseHandler)) }
    case .wrongRequest:
      responseHandler(
        response(
          to: command,
          requestID: OpaqueRuntimeRequestIdentifier(UUID()),
          generation: values.1,
          sequence: values.2,
          udp: values.3
        )
      )
    case .unsupportedProtocol:
      responseHandler(unsupportedProtocolResponse(requestID: command.requestID))
    case .futureSchema:
      responseHandler(
        futureSchemaResponse(
          to: command,
          generation: values.1,
          sequence: values.2,
          udp: values.3
        )
      )
    case .mismatchedPositions:
      let sequence = command.kind == .getCapabilities ? values.2 + 1 : values.2
      responseHandler(
        response(
          to: command,
          requestID: command.requestID,
          generation: values.1,
          sequence: sequence,
          udp: values.3
        )
      )
    case .current:
      responseHandler(
        response(
          to: command,
          requestID: command.requestID,
          generation: values.1,
          sequence: values.2,
          udp: values.3
        )
      )
    }
  }

  func fetchLastDisconnectError(
    completion: @escaping @Sendable (VPNPlatformError?) -> Void
  ) {
    let result = lock.withLock { () -> (DisconnectBehavior, VPNPlatformError?) in
      _fetchDisconnectCount += 1
      if disconnectBehavior == .deferred {
        deferredDisconnects.append(completion)
      }
      return (disconnectBehavior, disconnectError)
    }
    if result.0 == .immediate { completion(result.1) }
  }

  func observeStatusChanges(
    notification: @escaping @Sendable () -> Void
  ) -> any VPNPreferenceObservation {
    let identifier = UUID()
    let transition = lock.withLock { () -> (VPNManagerSessionStatus, Bool)? in
      observers[identifier] = notification
      let waiters = observerWaiters.filter { observers.count >= $0.0 }.map(\.1)
      observerWaiters.removeAll { observers.count >= $0.0 }
      for waiter in waiters { waiter.resume() }
      defer { registrationTransition = nil }
      return registrationTransition
    }
    if let transition {
      setStatus(transition.0, notifying: transition.1)
    }
    return Observation { [weak self] in
      _ = self?.lock.withLock { self?.observers.removeValue(forKey: identifier) }
    }
  }

  func setStatus(_ status: VPNManagerSessionStatus, notifying: Bool) {
    let callbacks = lock.withLock { () -> [@Sendable () -> Void] in
      state = status
      return notifying ? Array(observers.values) : []
    }
    for callback in callbacks { callback() }
  }

  func waitForObserverCount(_ count: Int) async {
    if observerCount >= count { return }
    await withCheckedContinuation { continuation in
      let resumeNow = lock.withLock {
        if observers.count >= count { return true }
        observerWaiters.append((count, continuation))
        return false
      }
      if resumeNow { continuation.resume() }
    }
  }

  func waitForMessageCount(_ count: Int) async {
    if messageCount >= count { return }
    await withCheckedContinuation { continuation in
      let resumeNow = lock.withLock {
        if _messageCount >= count { return true }
        messageWaiters.append((count, continuation))
        return false
      }
      if resumeNow { continuation.resume() }
    }
  }

  func completeDeferredMessagesWithCurrentSnapshot() {
    let pending = lock.withLock {
      let pending = deferredMessages
      deferredMessages.removeAll()
      return pending
    }
    for (command, completion) in pending {
      completion(
        response(
          to: command,
          requestID: command.requestID,
          generation: snapshotGeneration,
          sequence: snapshotSequence,
          udp: snapshotUDP
        )
      )
    }
  }

  func completeDeferredDisconnectError(_ error: VPNPlatformError?) {
    let callbacks = lock.withLock {
      let callbacks = deferredDisconnects
      deferredDisconnects.removeAll()
      return callbacks
    }
    for callback in callbacks { callback(error) }
  }

  private func response(
    to command: RuntimeCommand,
    requestID: OpaqueRuntimeRequestIdentifier?,
    generation: UInt64,
    sequence: UInt64,
    udp: Bool
  ) -> Data {
    do {
      switch command.kind {
      case .getProtocolCapabilities:
        return try RuntimeMessageCodec.encode(
          RuntimeProtocolCapabilitiesSnapshot(
            requestID: requestID,
            kinds: [
              RuntimeKindCapability(kind: .runtimeSnapshot, schemaVersions: .currentSchema),
              RuntimeKindCapability(kind: .capabilitySnapshot, schemaVersions: .currentSchema),
            ]
          )
        )
      case .getRuntimeSnapshot:
        return try RuntimeMessageCodec.encode(
          RuntimeLifecycleSnapshot(
            requestID: requestID,
            runtimeGeneration: generation,
            snapshotSequence: sequence,
            lifecycleState: .connectedDegraded,
            routeState: .installed,
            tcp: true,
            safeDNS: true,
            udp: udp,
            routeMode: .compatible,
            routesInstalled: true,
            healthy: true
          )
        )
      case .getCapabilities:
        return try RuntimeMessageCodec.encode(
          RuntimeCapabilitySnapshot(
            requestID: requestID,
            runtimeGeneration: generation,
            snapshotSequence: sequence,
            tcp: true,
            safeDNS: true,
            udp: udp,
            routeMode: .compatible,
            routesInstalled: true,
            healthy: true
          )
        )
      case .getDiagnostics:
        return Data()
      }
    } catch {
      return Data()
    }
  }

  private func unsupportedProtocolResponse(
    requestID: OpaqueRuntimeRequestIdentifier?
  ) -> Data {
    (try? RuntimeMessageCodec.encode(
      RuntimeProtocolCapabilitiesSnapshot(
        requestID: requestID,
        protocolVersions: RuntimeVersionRange(minimum: 2, maximum: 2),
        kinds: []
      )
    )) ?? Data()
  }

  private func futureSchemaResponse(
    to command: RuntimeCommand,
    generation: UInt64,
    sequence: UInt64,
    udp: Bool
  ) -> Data {
    let encoded = response(
      to: command,
      requestID: command.requestID,
      generation: generation,
      sequence: sequence,
      udp: udp
    )
    guard
      var object = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    else {
      return Data()
    }
    object["schemaVersion"] = Int(RuntimeMessageProtocol.currentSchemaVersion) + 1
    return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
  }
}

private final class ManualSessionClock: TunnelClock, @unchecked Sendable {
  private let lock = NSLock()
  private let instant = ContinuousClock().now
  private var sleepers: [Duration: [UUID: CheckedContinuation<Void, any Error>]] = [:]
  private var registrationWaiters: [Duration: [CheckedContinuation<Void, Never>]] = [:]

  func now() -> ContinuousClock.Instant { instant }

  func sleep(for duration: Duration) async throws {
    let identifier = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, any Error>) in
        let waiters = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
          if Task<Never, Never>.isCancelled {
            continuation.resume(throwing: CancellationError())
            return []
          }
          sleepers[duration, default: [:]][identifier] = continuation
          return registrationWaiters.removeValue(forKey: duration) ?? []
        }
        for waiter in waiters { waiter.resume() }
      }
    } onCancel: {
      let continuation = self.lock.withLock {
        self.sleepers[duration]?.removeValue(forKey: identifier)
      }
      continuation?.resume(throwing: CancellationError())
    }
  }

  func waitUntilRegistered(_ duration: Duration) async {
    let registered = lock.withLock { !(sleepers[duration]?.isEmpty ?? true) }
    if registered { return }
    await withCheckedContinuation { continuation in
      let resumeNow = lock.withLock {
        if !(sleepers[duration]?.isEmpty ?? true) { return true }
        registrationWaiters[duration, default: []].append(continuation)
        return false
      }
      if resumeNow { continuation.resume() }
    }
  }

  func fire(_ duration: Duration) {
    let continuations = lock.withLock {
      Array(sleepers.removeValue(forKey: duration)?.values ?? [:].values)
    }
    for continuation in continuations { continuation.resume() }
  }
}

private func eventually(
  _ predicate: @escaping () async -> Bool
) async {
  for _ in 0..<100 {
    if await predicate() { return }
    await Task.yield()
  }
  Issue.record("Condition did not become true")
}
