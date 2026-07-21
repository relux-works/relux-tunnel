import Foundation

public struct VPNPlatformError: Error, Equatable, Sendable {
  public let domain: String
  public let code: Int

  public init(domain: String, code: Int) {
    self.domain = domain
    self.code = code
  }
}

public protocol VPNHostSession: AnyObject, Sendable {
  var status: VPNManagerSessionStatus { get }

  func startTunnel(options: [String: Data]) throws
  func stopTunnel()
  func sendProviderMessage(
    _ message: Data,
    responseHandler: @escaping @Sendable (Data?) -> Void
  ) throws
  func fetchLastDisconnectError(
    completion: @escaping @Sendable (VPNPlatformError?) -> Void
  )
  func observeStatusChanges(
    notification: @escaping @Sendable () -> Void
  ) -> any VPNPreferenceObservation
}

public struct FreshOwnedVPNSession: Sendable {
  public let session: any VPNHostSession
  public let configurationReference: TunnelConfigurationReference
  public let isEnabled: Bool

  public init(
    session: any VPNHostSession,
    configurationReference: TunnelConfigurationReference,
    isEnabled: Bool
  ) {
    self.session = session
    self.configurationReference = configurationReference
    self.isEnabled = isEnabled
  }
}

public protocol VPNHostSessionRepository: Sendable {
  func loadFreshOwnedSession(requireEnabled: Bool) async throws -> FreshOwnedVPNSession
}

extension OwnedVPNManagerRepository: VPNHostSessionRepository {}

public enum VPNDisconnectReasonUnavailable: Equatable, Sendable {
  case timeout
  case cancelled
}

public enum VPNDisconnectReason: Equatable, Sendable {
  case systemOverslept
  case networkUnavailable
  case unrecoverableNetworkChange
  case configurationFailed
  case serverResolutionFailed
  case serverNotResponding
  case serverUnavailable
  case authenticationFailed
  case clientCertificateInvalid
  case clientCertificateNotYetValid
  case clientCertificateExpired
  case providerProcessFailed
  case configurationNotFound
  case providerUnavailableOrUpdateRequired
  case negotiationFailed
  case serverDisconnected
  case serverCertificateInvalid
  case serverCertificateNotYetValid
  case serverCertificateExpired
  case providerConfigurationInvalid
  case providerConfigurationSchemaUnsupported
  case providerStartReferenceMismatch
  case providerLifecycleBusy
  case providerStartCancelled
  case providerStartupTimedOut
  case providerRuntimeStartupFailed
  case providerNetworkSettingsFailed
  case providerInternalInvariant
  case providerFailureUnknown(code: Int)
  case systemDisconnectUnknown(domain: String, code: Int)
  case startTerminatedWithoutError(status: VPNManagerSessionStatus)
  case systemDisconnectedWithoutReportedError
  case disconnectReasonUnavailable(VPNDisconnectReasonUnavailable)
}

public enum VPNDisconnectErrorMapping {
  public static let connectionErrorDomain = "NEVPNConnectionErrorDomain"
  public static let providerErrorDomain = "works.relux.tunnel.provider"

  public static func map(
    _ error: VPNPlatformError?,
    startTerminatedStatus: VPNManagerSessionStatus? = nil
  ) -> VPNDisconnectReason {
    guard let error else {
      if let startTerminatedStatus {
        return .startTerminatedWithoutError(status: startTerminatedStatus)
      }
      return .systemDisconnectedWithoutReportedError
    }

    if error.domain == connectionErrorDomain {
      switch error.code {
      case 1: return .systemOverslept
      case 2: return .networkUnavailable
      case 3: return .unrecoverableNetworkChange
      case 4: return .configurationFailed
      case 5: return .serverResolutionFailed
      case 6: return .serverNotResponding
      case 7: return .serverUnavailable
      case 8: return .authenticationFailed
      case 9: return .clientCertificateInvalid
      case 10: return .clientCertificateNotYetValid
      case 11: return .clientCertificateExpired
      case 12: return .providerProcessFailed
      case 13: return .configurationNotFound
      case 14: return .providerUnavailableOrUpdateRequired
      case 15: return .negotiationFailed
      case 16: return .serverDisconnected
      case 17: return .serverCertificateInvalid
      case 18: return .serverCertificateNotYetValid
      case 19: return .serverCertificateExpired
      default: return .systemDisconnectUnknown(domain: error.domain, code: error.code)
      }
    }

    if error.domain == providerErrorDomain {
      switch error.code {
      case 1001: return .providerConfigurationInvalid
      case 1002: return .providerConfigurationSchemaUnsupported
      case 1003: return .providerStartReferenceMismatch
      case 1004: return .providerLifecycleBusy
      case 1005: return .providerStartCancelled
      case 1006: return .providerStartupTimedOut
      case 1007: return .providerRuntimeStartupFailed
      case 1008: return .providerNetworkSettingsFailed
      case 1009: return .providerInternalInvariant
      default: return .providerFailureUnknown(code: error.code)
      }
    }

    return .systemDisconnectUnknown(domain: error.domain, code: error.code)
  }
}

public struct VPNProviderFacts: Equatable, Sendable {
  public let lifecycle: RuntimeLifecycleSnapshot
  public let capabilities: RuntimeCapabilitySnapshot

  public init(
    lifecycle: RuntimeLifecycleSnapshot,
    capabilities: RuntimeCapabilitySnapshot
  ) {
    self.lifecycle = lifecycle
    switch lifecycle.lifecycleState {
    case .connectedFull, .connectedDegraded:
      self.capabilities = capabilities
    case .disconnected, .connecting, .reasserting, .failed, .disconnecting, .unknown:
      self.capabilities = RuntimeCapabilitySnapshot(
        requestID: capabilities.requestID,
        runtimeGeneration: capabilities.runtimeGeneration,
        snapshotSequence: capabilities.snapshotSequence,
        tcp: false,
        safeDNS: false,
        udp: false,
        routeMode: capabilities.routeMode,
        routesInstalled: false,
        healthy: false
      )
    }
  }

  public var position: RuntimeSnapshotPosition { lifecycle.position }

  public var isConnectedDegraded: Bool {
    lifecycle.lifecycleState == .connectedDegraded
      && lifecycle.routeState == .installed
      && lifecycle.routeMode == .compatible
      && lifecycle.routesInstalled
      && lifecycle.healthy
      && capabilities.tcp
      && capabilities.safeDNS
      && !capabilities.udp
  }
}

public struct VPNStatusProjection: Equatable, Sendable {
  public let systemStatus: VPNManagerSessionStatus
  public let providerFacts: VPNProviderFacts?
  public let disconnectReason: VPNDisconnectReason?

  public init(
    systemStatus: VPNManagerSessionStatus,
    providerFacts: VPNProviderFacts? = nil,
    disconnectReason: VPNDisconnectReason? = nil
  ) {
    self.systemStatus = systemStatus
    self.providerFacts = systemStatus == .connected ? providerFacts : nil
    self.disconnectReason = disconnectReason
  }
}

public enum VPNStartOutcome: Equatable, Sendable {
  case connected
  case alreadyStarting
  case alreadyConnected
  case systemReasserting
}

public enum VPNStopOutcome: Equatable, Sendable {
  case stopped(VPNManagerSessionStatus)
  case alreadyStopped(VPNManagerSessionStatus)
}

public enum VPNSessionControllerError: Error, Equatable, Sendable {
  case configurationInvalid
  case configurationDisabled
  case connectionFailed
  case platformRejected(domain: String, code: Int)
  case sessionBusyDisconnecting
  case sessionInvalid
  case startTimedOut
  case stopTimedOut
  case operationCancelled
  case providerUnavailable
  case providerNoResponse
  case providerMessageTimedOut
  case providerResponseInvalid
  case providerProtocolUnsupported
  case startFailed(VPNDisconnectReason)
  case controllerRetired
}

/// Shared host-side session command and truthful state projection owner.
///
/// The controller owns only host observers and bounded command waits. It never
/// owns forwarding state, and retirement never calls `stopTunnel()`.
public actor VPNSessionController {
  public static let startRequestKey = "works.relux.tunnel.start-request"

  private struct StartOperation {
    let identifier: UInt64
    let task: Task<StartExecution, any Error>
    let stopGate: SessionStopOnceGate
    let sessionBox: FreshSessionBox
  }

  private struct StopOperation {
    let identifier: UInt64
    let task: Task<StopExecution, any Error>
    let sessionBox: FreshSessionBox
  }

  private struct StartExecution: Sendable {
    let outcome: VPNStartOutcome
    let fresh: FreshOwnedVPNSession
  }

  private struct StopExecution: Sendable {
    let outcome: VPNStopOutcome
    let fresh: FreshOwnedVPNSession
  }

  private let repository: any VPNHostSessionRepository
  private let clock: any TunnelClock
  private let startTimeout: Duration
  private let stopTimeout: Duration
  private let messageTimeout: Duration
  private let requestIdentifier: @Sendable () -> OpaqueRuntimeRequestIdentifier

  private var controllerGeneration: UInt64 = 1
  private var operationSequence: UInt64 = 0
  private var observationSequence: UInt64 = 0
  private var statusRevision: UInt64 = 0
  private var retired = false
  private var observation: (any VPNPreferenceObservation)?
  private var observedSessionIdentity: ObjectIdentifier?
  private var refreshTask: Task<Void, Never>?
  private var activeStart: StartOperation?
  private var activeStop: StopOperation?
  private var lastAcceptedProviderPosition: RuntimeSnapshotPosition?
  private var statusProjection = VPNStatusProjection(systemStatus: .invalid)

  public init(
    repository: any VPNHostSessionRepository,
    clock: any TunnelClock = ContinuousTunnelClock(),
    startTimeout: Duration = .seconds(60),
    stopTimeout: Duration = .seconds(15),
    messageTimeout: Duration = .seconds(3),
    requestIdentifier: @escaping @Sendable () -> OpaqueRuntimeRequestIdentifier = {
      OpaqueRuntimeRequestIdentifier(UUID())
    }
  ) {
    self.repository = repository
    self.clock = clock
    self.startTimeout = startTimeout
    self.stopTimeout = stopTimeout
    self.messageTimeout = messageTimeout
    self.requestIdentifier = requestIdentifier
  }

  deinit {
    observation?.cancel()
    refreshTask?.cancel()
    activeStart?.task.cancel()
    activeStop?.task.cancel()
  }

  public func currentProjection() -> VPNStatusProjection {
    statusProjection
  }

  /// Freshly reloads the owned session, installs an exact-session observer, and
  /// recovers state from system status plus fresh provider snapshots.
  public func reconcile() async throws -> VPNStatusProjection {
    try requireActive()
    let fresh = try await repository.loadFreshOwnedSession(requireEnabled: false)
    return await adopt(fresh, suppliedDisconnectReason: nil)
  }

  public func start() async throws -> VPNStartOutcome {
    try requireActive()
    if activeStart != nil { return .alreadyStarting }

    operationSequence &+= 1
    let identifier = operationSequence
    let stopGate = SessionStopOnceGate()
    let sessionBox = FreshSessionBox()
    let repository = self.repository
    let clock = self.clock
    let startTimeout = self.startTimeout
    let task = Task<StartExecution, any Error> {
      try await Self.performStart(
        repository: repository,
        clock: clock,
        timeout: startTimeout,
        stopGate: stopGate,
        sessionBox: sessionBox
      )
    }
    activeStart = StartOperation(
      identifier: identifier,
      task: task,
      stopGate: stopGate,
      sessionBox: sessionBox
    )

    do {
      let execution = try await withTaskCancellationHandler {
        try await task.value
      } onCancel: {
        stopGate.issueStopIfAccepted()
        task.cancel()
      }
      clearStart(identifier)
      _ = await adopt(execution.fresh, suppliedDisconnectReason: nil)
      return execution.outcome
    } catch {
      clearStart(identifier)
      if let fresh = sessionBox.value {
        let reason: VPNDisconnectReason?
        if case VPNSessionControllerError.startFailed(let mapped) = error {
          reason = mapped
        } else {
          reason = nil
        }
        _ = await adopt(fresh, suppliedDisconnectReason: reason)
      }
      throw error
    }
  }

  public func stop() async throws -> VPNStopOutcome {
    try requireActive()
    if let activeStop {
      return try await Self.awaitShared(activeStop.task).outcome
    }

    let start = activeStart
    start?.stopGate.requestStop()
    start?.task.cancel()

    operationSequence &+= 1
    let identifier = operationSequence
    let sessionBox = FreshSessionBox()
    let repository = self.repository
    let clock = self.clock
    let stopTimeout = self.stopTimeout
    let task = Task<StopExecution, any Error> {
      try await Self.performStop(
        repository: repository,
        clock: clock,
        timeout: stopTimeout,
        sharedStopGate: start?.stopGate,
        sessionBox: sessionBox
      )
    }
    activeStop = StopOperation(identifier: identifier, task: task, sessionBox: sessionBox)
    Task { [weak self] in
      let result = await task.result
      await self?.stopOperationCompleted(
        identifier: identifier,
        result: result,
        sessionBox: sessionBox
      )
    }

    do {
      let execution = try await Self.awaitShared(task)
      if clearStop(identifier) {
        _ = await adopt(execution.fresh, suppliedDisconnectReason: nil)
      }
      return execution.outcome
    } catch {
      throw error
    }
  }

  /// Cancels host work and observers without stopping the system tunnel.
  public func retire() {
    guard !retired else { return }
    retired = true
    controllerGeneration &+= 1
    observationSequence &+= 1
    statusRevision &+= 1
    observation?.cancel()
    observation = nil
    observedSessionIdentity = nil
    refreshTask?.cancel()
    refreshTask = nil
    activeStart?.task.cancel()
    activeStart = nil
    activeStop?.task.cancel()
    activeStop = nil
  }

  private func requireActive() throws {
    if retired { throw VPNSessionControllerError.controllerRetired }
  }

  private func clearStart(_ identifier: UInt64) {
    guard activeStart?.identifier == identifier else { return }
    activeStart = nil
  }

  @discardableResult
  private func clearStop(_ identifier: UInt64) -> Bool {
    guard activeStop?.identifier == identifier else { return false }
    activeStop = nil
    return true
  }

  private func stopOperationCompleted(
    identifier: UInt64,
    result: Result<StopExecution, any Error>,
    sessionBox: FreshSessionBox
  ) async {
    guard clearStop(identifier) else { return }
    guard !retired else { return }
    switch result {
    case .success(let execution):
      _ = await adopt(execution.fresh, suppliedDisconnectReason: nil)
    case .failure:
      if let fresh = sessionBox.value {
        _ = await adopt(fresh, suppliedDisconnectReason: nil)
      }
    }
  }

  private func adopt(
    _ fresh: FreshOwnedVPNSession,
    suppliedDisconnectReason: VPNDisconnectReason?
  ) async -> VPNStatusProjection {
    guard !retired else { return statusProjection }
    observation?.cancel()
    refreshTask?.cancel()

    observationSequence &+= 1
    let observationID = observationSequence
    let generation = controllerGeneration
    let session = fresh.session
    observedSessionIdentity = ObjectIdentifier(session)
    observation = session.observeStatusChanges { [weak self, weak session] in
      guard let self, let session else { return }
      Task {
        await self.receivedStatusNotification(
          from: session,
          controllerGeneration: generation,
          observationID: observationID
        )
      }
    }

    let status = session.status
    return await refreshProjection(
      status: status,
      session: session,
      controllerGeneration: generation,
      observationID: observationID,
      suppliedDisconnectReason: suppliedDisconnectReason
    )
  }

  private func receivedStatusNotification(
    from session: any VPNHostSession,
    controllerGeneration generation: UInt64,
    observationID: UInt64
  ) async {
    guard !retired,
      generation == controllerGeneration,
      observationID == observationSequence,
      observedSessionIdentity == ObjectIdentifier(session)
    else { return }
    _ = await refreshProjection(
      status: session.status,
      session: session,
      controllerGeneration: generation,
      observationID: observationID,
      suppliedDisconnectReason: nil
    )
  }

  private func refreshProjection(
    status: VPNManagerSessionStatus,
    session: any VPNHostSession,
    controllerGeneration generation: UInt64,
    observationID: UInt64,
    suppliedDisconnectReason: VPNDisconnectReason?
  ) async -> VPNStatusProjection {
    statusRevision &+= 1
    let revision = statusRevision
    refreshTask?.cancel()
    statusProjection = VPNStatusProjection(
      systemStatus: status,
      disconnectReason: suppliedDisconnectReason
    )

    let task = Task { [clock, messageTimeout, requestIdentifier] in
      guard !Task<Never, Never>.isCancelled else { return }
      switch status {
      case .connected:
        do {
          let facts = try await Self.fetchProviderFacts(
            session: session,
            clock: clock,
            timeout: messageTimeout,
            requestIdentifier: requestIdentifier
          )
          self.accept(
            facts: facts,
            status: status,
            generation: generation,
            observationID: observationID,
            revision: revision
          )
        } catch {
          self.acceptCapabilityUnknown(
            status: status,
            generation: generation,
            observationID: observationID,
            revision: revision
          )
        }
      case .invalid, .disconnected:
        guard suppliedDisconnectReason == nil else { return }
        let reason = await Self.fetchDisconnectReason(
          session: session,
          clock: clock,
          timeout: messageTimeout,
          startTerminatedStatus: nil
        )
        self.accept(
          disconnectReason: reason,
          status: status,
          generation: generation,
          observationID: observationID,
          revision: revision
        )
      case .connecting, .reasserting, .disconnecting:
        break
      }
    }
    refreshTask = task
    await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }
    return statusProjection
  }

  private func accept(
    facts: VPNProviderFacts,
    status: VPNManagerSessionStatus,
    generation: UInt64,
    observationID: UInt64,
    revision: UInt64
  ) {
    guard
      isCurrent(
        status: status,
        generation: generation,
        observationID: observationID,
        revision: revision
      ), facts.position.isNewer(than: lastAcceptedProviderPosition)
    else {
      if isCurrent(
        status: status,
        generation: generation,
        observationID: observationID,
        revision: revision
      ) {
        statusProjection = VPNStatusProjection(systemStatus: .connected)
      }
      return
    }
    lastAcceptedProviderPosition = facts.position
    statusProjection = VPNStatusProjection(systemStatus: .connected, providerFacts: facts)
  }

  private func acceptCapabilityUnknown(
    status: VPNManagerSessionStatus,
    generation: UInt64,
    observationID: UInt64,
    revision: UInt64
  ) {
    guard
      isCurrent(
        status: status,
        generation: generation,
        observationID: observationID,
        revision: revision
      )
    else { return }
    statusProjection = VPNStatusProjection(systemStatus: .connected)
  }

  private func accept(
    disconnectReason: VPNDisconnectReason,
    status: VPNManagerSessionStatus,
    generation: UInt64,
    observationID: UInt64,
    revision: UInt64
  ) {
    guard
      isCurrent(
        status: status,
        generation: generation,
        observationID: observationID,
        revision: revision
      )
    else { return }
    statusProjection = VPNStatusProjection(
      systemStatus: status,
      disconnectReason: disconnectReason
    )
  }

  private func isCurrent(
    status: VPNManagerSessionStatus,
    generation: UInt64,
    observationID: UInt64,
    revision: UInt64
  ) -> Bool {
    !retired
      && generation == controllerGeneration
      && observationID == observationSequence
      && revision == statusRevision
      && statusProjection.systemStatus == status
  }

  private static func performStart(
    repository: any VPNHostSessionRepository,
    clock: any TunnelClock,
    timeout: Duration,
    stopGate: SessionStopOnceGate,
    sessionBox: FreshSessionBox
  ) async throws -> StartExecution {
    var fresh = try await loadFreshEnabledSession(repository: repository)
    sessionBox.set(fresh)
    var status = fresh.session.status

    if status == .invalid {
      fresh = try await loadFreshEnabledSession(repository: repository)
      sessionBox.set(fresh)
      status = fresh.session.status
      guard status != .invalid else { throw VPNSessionControllerError.sessionInvalid }
    }

    switch status {
    case .connecting:
      return StartExecution(outcome: .alreadyStarting, fresh: fresh)
    case .connected:
      return StartExecution(outcome: .alreadyConnected, fresh: fresh)
    case .reasserting:
      return StartExecution(outcome: .systemReasserting, fresh: fresh)
    case .disconnecting:
      throw VPNSessionControllerError.sessionBusyDisconnecting
    case .invalid:
      throw VPNSessionControllerError.sessionInvalid
    case .disconnected:
      break
    }

    try Task.checkCancellation()
    let request = RuntimeStartRequest(configurationReference: fresh.configurationReference)
    let encoded: Data
    do {
      encoded = try RuntimeConfigurationCodec.encode(request)
    } catch {
      throw VPNSessionControllerError.configurationInvalid
    }
    guard encoded.count <= RuntimeStartRequest.maximumEncodedSize else {
      throw VPNSessionControllerError.configurationInvalid
    }

    stopGate.setSession(fresh.session)
    do {
      try fresh.session.startTunnel(options: [startRequestKey: encoded])
    } catch let error as VPNPreferencePlatformError {
      throw mapStartError(error)
    } catch let error as VPNPlatformError {
      throw VPNSessionControllerError.platformRejected(
        domain: error.domain,
        code: error.code
      )
    } catch {
      throw VPNSessionControllerError.platformRejected(
        domain: String(reflecting: type(of: error)),
        code: 0
      )
    }
    stopGate.markAccepted()

    do {
      let terminal = try await awaitStatus(
        session: fresh.session,
        clock: clock,
        timeout: timeout,
        accepted: { $0 == .connected || $0.isTerminal }
      )
      if Task<Never, Never>.isCancelled {
        throw VPNSessionControllerError.operationCancelled
      }
      if terminal == .connected {
        return StartExecution(outcome: .connected, fresh: fresh)
      }
      let reason = await fetchDisconnectReason(
        session: fresh.session,
        clock: clock,
        timeout: .seconds(3),
        startTerminatedStatus: terminal
      )
      if Task<Never, Never>.isCancelled {
        throw VPNSessionControllerError.operationCancelled
      }
      throw VPNSessionControllerError.startFailed(reason)
    } catch SessionWaitError.timeout {
      stopGate.issueStopIfAccepted()
      throw VPNSessionControllerError.startTimedOut
    } catch SessionWaitError.cancelled {
      throw VPNSessionControllerError.operationCancelled
    }
  }

  private static func loadFreshEnabledSession(
    repository: any VPNHostSessionRepository
  ) async throws -> FreshOwnedVPNSession {
    do {
      return try await repository.loadFreshOwnedSession(requireEnabled: true)
    } catch VPNManagerRepositoryError.configurationDisabled {
      throw VPNSessionControllerError.configurationDisabled
    }
  }

  private static func performStop(
    repository: any VPNHostSessionRepository,
    clock: any TunnelClock,
    timeout: Duration,
    sharedStopGate: SessionStopOnceGate?,
    sessionBox: FreshSessionBox
  ) async throws -> StopExecution {
    let fresh = try await repository.loadFreshOwnedSession(requireEnabled: false)
    sessionBox.set(fresh)
    let initial = fresh.session.status
    if initial.isTerminal {
      return StopExecution(outcome: .alreadyStopped(initial), fresh: fresh)
    }

    if initial != .disconnecting {
      if let sharedStopGate {
        sharedStopGate.issueStop(using: fresh.session)
      } else {
        fresh.session.stopTunnel()
      }
    }

    do {
      let terminal = try await awaitStatus(
        session: fresh.session,
        clock: clock,
        timeout: timeout,
        accepted: { $0.isTerminal }
      )
      return StopExecution(outcome: .stopped(terminal), fresh: fresh)
    } catch SessionWaitError.timeout {
      throw VPNSessionControllerError.stopTimedOut
    } catch SessionWaitError.cancelled {
      throw VPNSessionControllerError.operationCancelled
    }
  }

  private static func mapStartError(
    _ error: VPNPreferencePlatformError
  ) -> VPNSessionControllerError {
    switch error.kind {
    case .configurationInvalid: .configurationInvalid
    case .configurationDisabled: .configurationDisabled
    case .connectionFailed: .connectionFailed
    case .configurationStale, .readWriteFailed, .unknown, .other:
      .platformRejected(domain: error.domain, code: error.code)
    }
  }

  private static func fetchProviderFacts(
    session: any VPNHostSession,
    clock: any TunnelClock,
    timeout: Duration,
    requestIdentifier: @Sendable () -> OpaqueRuntimeRequestIdentifier
  ) async throws -> VPNProviderFacts {
    let protocolID = requestIdentifier()
    let protocolData = try await send(
      kind: .getProtocolCapabilities,
      requestID: protocolID,
      session: session,
      clock: clock,
      timeout: timeout
    )
    let protocolSnapshot: RuntimeProtocolCapabilitiesSnapshot
    do {
      protocolSnapshot = try RuntimeMessageCodec.decodeProtocolCapabilities(protocolData)
    } catch {
      if let protocolError = try? RuntimeMessageCodec.decodeProtocolError(protocolData),
        protocolError.requestID == protocolID
      {
        throw VPNSessionControllerError.providerProtocolUnsupported
      }
      throw VPNSessionControllerError.providerResponseInvalid
    }
    guard protocolSnapshot.requestID == protocolID,
      protocolSnapshot.protocolVersions.minimum <= RuntimeMessageProtocol.currentProtocolVersion,
      protocolSnapshot.protocolVersions.maximum >= RuntimeMessageProtocol.currentProtocolVersion,
      supports(.runtimeSnapshot, in: protocolSnapshot),
      supports(.capabilitySnapshot, in: protocolSnapshot)
    else {
      throw VPNSessionControllerError.providerProtocolUnsupported
    }

    let lifecycleID = requestIdentifier()
    let lifecycleData = try await send(
      kind: .getRuntimeSnapshot,
      requestID: lifecycleID,
      session: session,
      clock: clock,
      timeout: timeout
    )
    let lifecycle: RuntimeLifecycleSnapshot
    do {
      lifecycle = try RuntimeMessageCodec.decodeLifecycleSnapshot(lifecycleData)
    } catch {
      throw VPNSessionControllerError.providerResponseInvalid
    }
    guard lifecycle.requestID == lifecycleID else {
      throw VPNSessionControllerError.providerResponseInvalid
    }

    let capabilityID = requestIdentifier()
    let capabilityData = try await send(
      kind: .getCapabilities,
      requestID: capabilityID,
      session: session,
      clock: clock,
      timeout: timeout
    )
    let capabilities: RuntimeCapabilitySnapshot
    do {
      capabilities = try RuntimeMessageCodec.decodeCapabilitySnapshot(capabilityData)
    } catch {
      throw VPNSessionControllerError.providerResponseInvalid
    }
    guard capabilities.requestID == capabilityID,
      lifecycle.position == capabilities.position,
      session.status == .connected
    else {
      throw VPNSessionControllerError.providerResponseInvalid
    }
    return VPNProviderFacts(lifecycle: lifecycle, capabilities: capabilities)
  }

  private static func supports(
    _ kind: RuntimeMessageKind,
    in snapshot: RuntimeProtocolCapabilitiesSnapshot
  ) -> Bool {
    snapshot.kinds.contains { capability in
      capability.kind == kind
        && capability.schemaVersions.minimum <= RuntimeMessageProtocol.currentSchemaVersion
        && capability.schemaVersions.maximum >= RuntimeMessageProtocol.currentSchemaVersion
    }
  }

  private static func send(
    kind: RuntimeCommandKind,
    requestID: OpaqueRuntimeRequestIdentifier,
    session: any VPNHostSession,
    clock: any TunnelClock,
    timeout: Duration
  ) async throws -> Data {
    guard session.status == .connected else {
      throw VPNSessionControllerError.providerUnavailable
    }
    let command = try RuntimeMessageCodec.encode(
      RuntimeCommand(kind: kind, requestID: requestID)
    )
    let token = SessionCallbackToken<Data>()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        token.install(continuation)
        do {
          try session.sendProviderMessage(command) { response in
            guard let response else {
              token.resolve(.failure(.noResponse))
              return
            }
            token.resolve(.success(response))
          }
        } catch {
          token.resolve(.failure(.platform))
        }
        token.setTimeoutTask(
          Task {
            do {
              try await clock.sleep(for: timeout)
              token.resolve(.failure(.timeout))
            } catch {}
          }
        )
      }
    } onCancel: {
      token.resolve(.failure(.cancelled))
    }
  }

  private static func fetchDisconnectReason(
    session: any VPNHostSession,
    clock: any TunnelClock,
    timeout: Duration,
    startTerminatedStatus: VPNManagerSessionStatus?
  ) async -> VPNDisconnectReason {
    let token = SessionCallbackToken<VPNPlatformError?>()
    do {
      let error = try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          token.install(continuation)
          session.fetchLastDisconnectError { error in
            token.resolve(.success(error))
          }
          token.setTimeoutTask(
            Task {
              do {
                try await clock.sleep(for: timeout)
                token.resolve(.failure(.timeout))
              } catch {}
            }
          )
        }
      } onCancel: {
        token.resolve(.failure(.cancelled))
      }
      return VPNDisconnectErrorMapping.map(
        error,
        startTerminatedStatus: startTerminatedStatus
      )
    } catch SessionCallbackError.timeout {
      return .disconnectReasonUnavailable(.timeout)
    } catch {
      return .disconnectReasonUnavailable(.cancelled)
    }
  }

  private static func awaitStatus(
    session: any VPNHostSession,
    clock: any TunnelClock,
    timeout: Duration,
    accepted: @escaping @Sendable (VPNManagerSessionStatus) -> Bool
  ) async throws -> VPNManagerSessionStatus {
    let token = SessionStatusToken(accepted: accepted)
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        token.install(continuation)
        let observation = session.observeStatusChanges {
          token.receive(session.status)
        }
        token.setObservation(observation)
        token.receive(session.status)
        token.setTimeoutTask(
          Task {
            do {
              try await clock.sleep(for: timeout)
              token.resolve(.failure(.timeout))
            } catch {}
          }
        )
      }
    } onCancel: {
      token.resolve(.failure(.cancelled))
    }
  }

  private static func awaitShared<Value: Sendable>(
    _ task: Task<Value, any Error>
  ) async throws -> Value {
    let token = SharedTaskValueToken<Value>()
    let waiter = Task {
      do {
        token.resolve(.success(try await task.value))
      } catch {
        token.resolve(.failure(error))
      }
    }
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        token.install(continuation)
        token.setWaiter(waiter)
        if Task<Never, Never>.isCancelled {
          token.resolve(.failure(VPNSessionControllerError.operationCancelled))
        }
      }
    } onCancel: {
      token.resolve(.failure(VPNSessionControllerError.operationCancelled))
    }
  }
}

private enum SessionWaitError: Error, Sendable {
  case timeout
  case cancelled
}

private enum SessionCallbackError: Error, Sendable {
  case timeout
  case cancelled
  case noResponse
  case platform
}

private final class SessionStopOnceGate: @unchecked Sendable {
  private let lock = NSLock()
  private var session: (any VPNHostSession)?
  private var accepted = false
  private var stopRequested = false
  private var stopIssued = false

  func setSession(_ session: any VPNHostSession) {
    lock.withLock { self.session = session }
  }

  func markAccepted() {
    let session = lock.withLock { () -> (any VPNHostSession)? in
      accepted = true
      return claimStopIfReady()
    }
    session?.stopTunnel()
  }

  func requestStop() {
    issueStopIfAccepted()
  }

  func issueStopIfAccepted() {
    let session = lock.withLock { () -> (any VPNHostSession)? in
      stopRequested = true
      return claimStopIfReady()
    }
    session?.stopTunnel()
  }

  func issueStop(using fallback: any VPNHostSession) {
    let session = lock.withLock { () -> (any VPNHostSession)? in
      stopRequested = true
      guard !stopIssued else { return nil }
      stopIssued = true
      return accepted ? (self.session ?? fallback) : fallback
    }
    session?.stopTunnel()
  }

  private func claimStopIfReady() -> (any VPNHostSession)? {
    guard accepted, stopRequested, !stopIssued, let session else { return nil }
    stopIssued = true
    return session
  }
}

private final class FreshSessionBox: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: FreshOwnedVPNSession?

  var value: FreshOwnedVPNSession? { lock.withLock { stored } }

  func set(_ fresh: FreshOwnedVPNSession) {
    lock.withLock { stored = fresh }
  }
}

private final class SessionStatusToken: @unchecked Sendable {
  private let lock = NSLock()
  private let accepted: @Sendable (VPNManagerSessionStatus) -> Bool
  private var continuation: CheckedContinuation<VPNManagerSessionStatus, any Error>?
  private var pending: Result<VPNManagerSessionStatus, SessionWaitError>?
  private var observation: (any VPNPreferenceObservation)?
  private var timeoutTask: Task<Void, Never>?
  private var resolved = false

  init(accepted: @escaping @Sendable (VPNManagerSessionStatus) -> Bool) {
    self.accepted = accepted
  }

  func install(_ continuation: CheckedContinuation<VPNManagerSessionStatus, any Error>) {
    let pending = lock.withLock { () -> Result<VPNManagerSessionStatus, SessionWaitError>? in
      if let pending = self.pending {
        self.pending = nil
        return pending
      }
      self.continuation = continuation
      return nil
    }
    pending.map { continuation.resume(with: $0.mapError { $0 as any Error }) }
  }

  func setObservation(_ observation: any VPNPreferenceObservation) {
    let cancelNow = lock.withLock {
      if resolved { return true }
      self.observation = observation
      return false
    }
    if cancelNow { observation.cancel() }
  }

  func setTimeoutTask(_ task: Task<Void, Never>) {
    let cancelNow = lock.withLock {
      if resolved { return true }
      timeoutTask = task
      return false
    }
    if cancelNow { task.cancel() }
  }

  func receive(_ status: VPNManagerSessionStatus) {
    if accepted(status) { resolve(.success(status)) }
  }

  func resolve(_ result: Result<VPNManagerSessionStatus, SessionWaitError>) {
    let values = lock.withLock {
      () -> (
        CheckedContinuation<VPNManagerSessionStatus, any Error>?,
        (any VPNPreferenceObservation)?,
        Task<Void, Never>?
      ) in
      guard !resolved else { return (nil, nil, nil) }
      resolved = true
      let continuation = self.continuation
      self.continuation = nil
      if continuation == nil { pending = result }
      let observation = self.observation
      self.observation = nil
      let timeoutTask = self.timeoutTask
      self.timeoutTask = nil
      return (continuation, observation, timeoutTask)
    }
    values.1?.cancel()
    values.2?.cancel()
    values.0?.resume(with: result.mapError { $0 as any Error })
  }
}

private final class SessionCallbackToken<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Value, any Error>?
  private var pending: Result<Value, SessionCallbackError>?
  private var timeoutTask: Task<Void, Never>?
  private var resolved = false

  func install(_ continuation: CheckedContinuation<Value, any Error>) {
    let pending = lock.withLock { () -> Result<Value, SessionCallbackError>? in
      if let pending = self.pending {
        self.pending = nil
        return pending
      }
      self.continuation = continuation
      return nil
    }
    pending.map { continuation.resume(with: $0.mapError { $0 as any Error }) }
  }

  func setTimeoutTask(_ task: Task<Void, Never>) {
    let cancelNow = lock.withLock {
      if resolved { return true }
      timeoutTask = task
      return false
    }
    if cancelNow { task.cancel() }
  }

  func resolve(_ result: Result<Value, SessionCallbackError>) {
    let values = lock.withLock {
      () -> (
        CheckedContinuation<Value, any Error>?, Task<Void, Never>?
      ) in
      guard !resolved else { return (nil, nil) }
      resolved = true
      let continuation = self.continuation
      self.continuation = nil
      if continuation == nil { pending = result }
      let timeoutTask = self.timeoutTask
      self.timeoutTask = nil
      return (continuation, timeoutTask)
    }
    values.1?.cancel()
    values.0?.resume(with: result.mapError { $0 as any Error })
  }
}

private final class SharedTaskValueToken<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Value, any Error>?
  private var pending: Result<Value, any Error>?
  private var waiter: Task<Void, Never>?
  private var resolved = false

  func install(_ continuation: CheckedContinuation<Value, any Error>) {
    let pending = lock.withLock { () -> Result<Value, any Error>? in
      if let pending = self.pending {
        self.pending = nil
        return pending
      }
      self.continuation = continuation
      return nil
    }
    pending.map { continuation.resume(with: $0) }
  }

  func setWaiter(_ waiter: Task<Void, Never>) {
    let cancelNow = lock.withLock {
      if resolved { return true }
      self.waiter = waiter
      return false
    }
    if cancelNow { waiter.cancel() }
  }

  func resolve(_ result: Result<Value, any Error>) {
    let values = lock.withLock {
      () -> (
        CheckedContinuation<Value, any Error>?, Task<Void, Never>?
      ) in
      guard !resolved else { return (nil, nil) }
      resolved = true
      let continuation = self.continuation
      self.continuation = nil
      if continuation == nil { pending = result }
      let waiter = self.waiter
      self.waiter = nil
      return (continuation, waiter)
    }
    values.1?.cancel()
    values.0?.resume(with: result)
  }
}
