import Foundation

public enum ClientUDPAssociationState: String, CaseIterable, Equatable, Sendable {
  case active
  case closing
  case expired
  case closed
}

public enum ClientUDPAssociationEvent: String, CaseIterable, Equatable, Sendable {
  case admission
  case activity
  case localClose
  case remoteClose
  case remoteError
  case idleExpiry
  case expiryCompleted
  case sessionLoss
  case sessionReplacement
  case cancellation
  case providerStop
}

public struct ClientUDPAssociationTransitionRule: Equatable, Sendable {
  public let event: ClientUDPAssociationEvent
  public let from: ClientUDPAssociationState?
  public let to: ClientUDPAssociationState
  public let releasesIdentifier: Bool

  public init(
    event: ClientUDPAssociationEvent,
    from: ClientUDPAssociationState?,
    to: ClientUDPAssociationState,
    releasesIdentifier: Bool
  ) {
    self.event = event
    self.from = from
    self.to = to
    self.releasesIdentifier = releasesIdentifier
  }
}

/// Explicit client-side association lifecycle for relay protocol v1.
///
/// A local close, error, or expiry retains the identifier until a remote close
/// proves that the relay retired its state. Ending the whole generation is the
/// only other transition that releases those retained identifiers.
public enum ClientUDPAssociationTransitions {
  public static let v1: [ClientUDPAssociationTransitionRule] =
    [
      .init(event: .admission, from: nil, to: .active, releasesIdentifier: false),
      .init(event: .activity, from: .active, to: .active, releasesIdentifier: false),
      .init(event: .activity, from: .closing, to: .closing, releasesIdentifier: false),
      .init(event: .activity, from: .expired, to: .expired, releasesIdentifier: false),
      .init(event: .activity, from: .closed, to: .closed, releasesIdentifier: true),
      .init(event: .localClose, from: .active, to: .closing, releasesIdentifier: false),
      .init(event: .localClose, from: .closing, to: .closing, releasesIdentifier: false),
      .init(event: .localClose, from: .expired, to: .expired, releasesIdentifier: false),
      .init(event: .localClose, from: .closed, to: .closed, releasesIdentifier: true),
      .init(event: .remoteClose, from: .active, to: .closed, releasesIdentifier: true),
      .init(event: .remoteClose, from: .closing, to: .closed, releasesIdentifier: true),
      .init(event: .remoteClose, from: .expired, to: .closed, releasesIdentifier: true),
      .init(event: .remoteClose, from: .closed, to: .closed, releasesIdentifier: true),
      .init(event: .remoteError, from: .active, to: .closing, releasesIdentifier: false),
      .init(event: .remoteError, from: .closing, to: .closing, releasesIdentifier: false),
      .init(event: .remoteError, from: .expired, to: .expired, releasesIdentifier: false),
      .init(event: .remoteError, from: .closed, to: .closed, releasesIdentifier: true),
      .init(event: .idleExpiry, from: .active, to: .expired, releasesIdentifier: false),
      .init(event: .idleExpiry, from: .closing, to: .closing, releasesIdentifier: false),
      .init(event: .idleExpiry, from: .expired, to: .expired, releasesIdentifier: false),
      .init(event: .idleExpiry, from: .closed, to: .closed, releasesIdentifier: true),
      .init(event: .expiryCompleted, from: .active, to: .active, releasesIdentifier: false),
      .init(event: .expiryCompleted, from: .closing, to: .closing, releasesIdentifier: false),
      .init(event: .expiryCompleted, from: .expired, to: .closing, releasesIdentifier: false),
      .init(event: .expiryCompleted, from: .closed, to: .closed, releasesIdentifier: true),
    ] + terminalRules(for: .sessionLoss) + terminalRules(for: .sessionReplacement)
    + terminalRules(for: .cancellation) + terminalRules(for: .providerStop)

  private static func terminalRules(
    for event: ClientUDPAssociationEvent
  ) -> [ClientUDPAssociationTransitionRule] {
    ClientUDPAssociationState.allCases.map {
      ClientUDPAssociationTransitionRule(
        event: event,
        from: $0,
        to: .closed,
        releasesIdentifier: true
      )
    }
  }
}

public struct ClientUDPAssociationRegistryConfiguration: Equatable, Sendable {
  public static let allocatorSearchHardCeiling: UInt32 =
    RelayProtocolV1.maxAssociationsClientHardCeiling

  public let maximumAssociations: UInt32
  public let allocatorSearchLimit: UInt32
  public let idleTimeoutMilliseconds: UInt32

  public init(
    maximumAssociations: UInt32 = RelayProtocolV1.maxAssociationsClientDefault,
    allocatorSearchLimit: UInt32? = nil,
    idleTimeoutMilliseconds: UInt32 = RelayProtocolV1.idleTimeoutClientDefault
  ) throws {
    guard
      (RelayProtocolV1
        .maxAssociationsFloor...RelayProtocolV1
        .maxAssociationsClientHardCeiling).contains(maximumAssociations)
    else {
      throw ClientUDPAssociationConfigurationError.maximumAssociationsOutOfRange
    }
    let searchLimit = allocatorSearchLimit ?? maximumAssociations
    guard (1...Self.allocatorSearchHardCeiling).contains(searchLimit) else {
      throw ClientUDPAssociationConfigurationError.allocatorSearchLimitOutOfRange
    }
    guard
      (RelayProtocolV1
        .idleTimeoutFloor...RelayProtocolV1
        .idleTimeoutClientHardCeiling).contains(idleTimeoutMilliseconds)
    else {
      throw ClientUDPAssociationConfigurationError.idleTimeoutOutOfRange
    }
    self.maximumAssociations = maximumAssociations
    self.allocatorSearchLimit = searchLimit
    self.idleTimeoutMilliseconds = idleTimeoutMilliseconds
  }

  public init(
    limits: RelayEffectiveLimits,
    allocatorSearchLimit: UInt32? = nil
  ) throws {
    try self.init(
      maximumAssociations: limits.maxAssociations,
      allocatorSearchLimit: allocatorSearchLimit,
      idleTimeoutMilliseconds: limits.idleTimeoutMilliseconds
    )
  }
}

public enum ClientUDPAssociationConfigurationError: Error, Equatable, Sendable {
  case maximumAssociationsOutOfRange
  case allocatorSearchLimitOutOfRange
  case idleTimeoutOutOfRange
}

public struct ClientUDPAssociationKey: Hashable, Sendable {
  public let generation: UInt64
  public let associationID: UInt32
  public let allocation: UInt64

  public init(generation: UInt64, associationID: UInt32, allocation: UInt64) {
    self.generation = generation
    self.associationID = associationID
    self.allocation = allocation
  }
}

public enum ClientUDPAssociationAdmissionFailureReason: String, Equatable, Sendable {
  case noActiveGeneration = "no_active_generation"
  case providerStopped = "provider_stopped"
  case staleGeneration = "stale_generation"
  case associationLimit = "association_limit"
  case allocatorSearchExhausted = "allocator_search_exhausted"
  case allocationTokenExhausted = "allocation_token_exhausted"
  case handleRetiring = "handle_retiring"
}

public struct ClientUDPAssociationAdmissionFailure: Error, Equatable, Sendable {
  public let reason: ClientUDPAssociationAdmissionFailureReason
  public let shouldWriteRelayBytes = false

  public init(reason: ClientUDPAssociationAdmissionFailureReason) {
    self.reason = reason
  }
}

public enum ClientUDPAssociationCleanupReason: String, Equatable, Sendable {
  case localClose = "local_close"
  case remoteClose = "remote_close"
  case remoteError = "remote_error"
  case idleExpiry = "idle_expiry"
  case sessionLoss = "session_loss"
  case sessionReplaced = "session_replaced"
  case cancelled
  case providerStop = "provider_stop"
}

public struct ClientUDPAssociationRelayCleanup: Equatable, Sendable {
  public let key: ClientUDPAssociationKey
  public let reason: ClientUDPAssociationCleanupReason
  public let shouldSendClose: Bool

  public init(
    key: ClientUDPAssociationKey,
    reason: ClientUDPAssociationCleanupReason,
    shouldSendClose: Bool
  ) {
    self.key = key
    self.reason = reason
    self.shouldSendClose = shouldSendClose
  }
}

public struct ClientUDPAssociationCallbacks<HEVAssociation: Sendable>: Sendable {
  /// Callbacks execute after registry state is committed and must not block.
  public let closeHEV: @Sendable (HEVAssociation, ClientUDPAssociationCleanupReason) -> Void
  public let cleanupRelay: @Sendable (ClientUDPAssociationRelayCleanup) -> Void

  public init(
    closeHEV:
      @escaping @Sendable (
        HEVAssociation,
        ClientUDPAssociationCleanupReason
      ) -> Void = { _, _ in },
    cleanupRelay: @escaping @Sendable (ClientUDPAssociationRelayCleanup) -> Void = { _ in }
  ) {
    self.closeHEV = closeHEV
    self.cleanupRelay = cleanupRelay
  }
}

public enum ClientUDPAssociationEventResult: Equatable, Sendable {
  case applied(
    key: ClientUDPAssociationKey,
    from: ClientUDPAssociationState,
    to: ClientUDPAssociationState
  )
  case ignoredStaleGeneration
  case ignoredUnknownAssociation
  case ignoredState(ClientUDPAssociationState)
}

public enum ClientUDPAssociationResolution<HEVAssociation: Sendable>: Sendable {
  case resolved(HEVAssociation, ClientUDPAssociationKey)
  case staleGeneration
  case unknownAssociation
  case unavailable(ClientUDPAssociationState)
}

public enum ClientUDPAssociationGenerationResult: Equatable, Sendable {
  case activated(UInt64)
  case alreadyActive(UInt64)
  case rejectedStaleGeneration
  case rejectedProviderStopped
}

public struct ClientUDPAssociationMetrics: Equatable, Sendable {
  public fileprivate(set) var admitted: UInt64 = 0
  public fileprivate(set) var admissionRejected: UInt64 = 0
  public fileprivate(set) var activityUpdates: UInt64 = 0
  public fileprivate(set) var localCloses: UInt64 = 0
  public fileprivate(set) var remoteCloses: UInt64 = 0
  public fileprivate(set) var remoteErrors: UInt64 = 0
  public fileprivate(set) var idleExpired: UInt64 = 0
  public fileprivate(set) var expiryCompletions: UInt64 = 0
  public fileprivate(set) var sessionLosses: UInt64 = 0
  public fileprivate(set) var sessionReplacements: UInt64 = 0
  public fileprivate(set) var cancellations: UInt64 = 0
  public fileprivate(set) var providerStops: UInt64 = 0
  public fileprivate(set) var staleEvents: UInt64 = 0
  public fileprivate(set) var lateEvents: UInt64 = 0
  public fileprivate(set) var allocationCollisions: UInt64 = 0
  public fileprivate(set) var allocatorSearchExhausted: UInt64 = 0
  public fileprivate(set) var identifierWraparounds: UInt64 = 0
  public fileprivate(set) var staleTimerCallbacks: UInt64 = 0
  public fileprivate(set) var hevCleanupCallbacks: UInt64 = 0
  public fileprivate(set) var relayCleanupCallbacks: UInt64 = 0
  public fileprivate(set) var terminalCleanups: UInt64 = 0
  public fileprivate(set) var peakAssociations: UInt32 = 0

  public init() {}
}

public struct ClientUDPAssociationRegistrySnapshot: Equatable, Sendable {
  public let currentGeneration: UInt64?
  public let providerStopped: Bool
  public let associationCount: Int
  public let activeAssociations: Int
  public let closingAssociations: Int
  public let expiredAssociations: Int
  public let scheduledTimers: Int
  public let metrics: ClientUDPAssociationMetrics
}

/// Extension-owned mapping between HEV UDP associations and relay protocol IDs.
///
/// Actor isolation makes admission and every lifecycle transition atomic. The
/// registry stores no destination or payload data. At most one timer and two
/// dictionary entries exist for each admitted association.
public actor ClientUDPAssociationRegistry<HEVAssociation: Hashable & Sendable> {
  private struct Record {
    let handle: HEVAssociation
    let key: ClientUDPAssociationKey
    var state: ClientUDPAssociationState
    var deadline: ContinuousClock.Instant
    var timerEpoch: UInt64 = 0
    var timer: Task<Void, Never>?
    var cleanupInvoked = false
  }

  private struct CleanupEffect {
    let handle: HEVAssociation
    let reason: ClientUDPAssociationCleanupReason
    let relay: ClientUDPAssociationRelayCleanup
  }

  public let configuration: ClientUDPAssociationRegistryConfiguration

  private let clock: any TunnelClock
  private let callbacks: ClientUDPAssociationCallbacks<HEVAssociation>
  private var currentGeneration: UInt64?
  private var lastGeneration: UInt64
  private var isProviderStopped = false
  private var nextAssociationID: UInt32
  private var nextAllocation: UInt64 = 1
  private var recordsByID: [UInt32: Record] = [:]
  private var identifiersByHandle: [HEVAssociation: UInt32] = [:]
  private var metrics = ClientUDPAssociationMetrics()

  public init(
    generation: UInt64,
    configuration: ClientUDPAssociationRegistryConfiguration,
    clock: any TunnelClock = ContinuousTunnelClock(),
    callbacks: ClientUDPAssociationCallbacks<HEVAssociation> = .init()
  ) {
    self.configuration = configuration
    self.clock = clock
    self.callbacks = callbacks
    currentGeneration = generation
    lastGeneration = generation
    nextAssociationID = 1
  }

  internal init(
    generation: UInt64,
    configuration: ClientUDPAssociationRegistryConfiguration,
    clock: any TunnelClock,
    callbacks: ClientUDPAssociationCallbacks<HEVAssociation>,
    initialAssociationIDForTesting: UInt32
  ) {
    precondition(initialAssociationIDForTesting != 0)
    self.configuration = configuration
    self.clock = clock
    self.callbacks = callbacks
    currentGeneration = generation
    lastGeneration = generation
    nextAssociationID = initialAssociationIDForTesting
  }

  deinit {
    for record in recordsByID.values {
      record.timer?.cancel()
    }
  }

  public func admit(
    _ handle: HEVAssociation,
    generation: UInt64
  ) -> Result<ClientUDPAssociationKey, ClientUDPAssociationAdmissionFailure> {
    guard !isProviderStopped else { return reject(.providerStopped) }
    guard let currentGeneration else { return reject(.noActiveGeneration) }
    guard generation == currentGeneration else { return reject(.staleGeneration) }

    if let existingID = identifiersByHandle[handle], let existing = recordsByID[existingID] {
      guard existing.state == .active else { return reject(.handleRetiring) }
      return .success(existing.key)
    }
    guard recordsByID.count < Int(configuration.maximumAssociations) else {
      return reject(.associationLimit)
    }
    guard nextAllocation != UInt64.max else { return reject(.allocationTokenExhausted) }
    guard let associationID = allocateAssociationID() else {
      metrics.allocatorSearchExhausted = incremented(metrics.allocatorSearchExhausted)
      return reject(.allocatorSearchExhausted)
    }

    let key = ClientUDPAssociationKey(
      generation: generation,
      associationID: associationID,
      allocation: nextAllocation
    )
    nextAllocation += 1
    let deadline = clock.now().advanced(by: idleTimeout)
    var record = Record(handle: handle, key: key, state: .active, deadline: deadline)
    scheduleTimer(for: &record, sleepingFor: idleTimeout)
    recordsByID[associationID] = record
    identifiersByHandle[handle] = associationID
    metrics.admitted = incremented(metrics.admitted)
    metrics.peakAssociations = max(metrics.peakAssociations, UInt32(recordsByID.count))
    return .success(key)
  }

  public func key(
    for handle: HEVAssociation,
    generation: UInt64
  ) -> ClientUDPAssociationKey? {
    guard generation == currentGeneration,
      let associationID = identifiersByHandle[handle],
      let record = recordsByID[associationID],
      record.state == .active
    else { return nil }
    return record.key
  }

  /// Resolves a relay datagram to its HEV owner and refreshes idle activity.
  public func resolveRemoteDatagram(
    associationID: UInt32,
    generation: UInt64
  ) -> ClientUDPAssociationResolution<HEVAssociation> {
    guard generation == currentGeneration else {
      metrics.staleEvents = incremented(metrics.staleEvents)
      return .staleGeneration
    }
    guard var record = recordsByID[associationID] else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return .unknownAssociation
    }
    guard record.state == .active else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return .unavailable(record.state)
    }
    refreshActivity(&record)
    recordsByID[associationID] = record
    return .resolved(record.handle, record.key)
  }

  @discardableResult
  public func recordActivity(
    for key: ClientUDPAssociationKey
  ) -> ClientUDPAssociationEventResult {
    guard validateGeneration(key.generation) else { return .ignoredStaleGeneration }
    guard var record = recordsByID[key.associationID], record.key == key else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return .ignoredUnknownAssociation
    }
    guard record.state == .active else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return .ignoredState(record.state)
    }
    refreshActivity(&record)
    recordsByID[key.associationID] = record
    return .applied(key: key, from: .active, to: .active)
  }

  @discardableResult
  public func closeLocally(
    _ key: ClientUDPAssociationKey
  ) -> ClientUDPAssociationEventResult {
    transitionToRetiring(
      key,
      nextState: .closing,
      reason: .localClose,
      metric: \ClientUDPAssociationMetrics.localCloses
    )
  }

  @discardableResult
  public func receiveRemoteError(
    associationID: UInt32,
    generation: UInt64
  ) -> ClientUDPAssociationEventResult {
    guard let record = validatedRecord(associationID: associationID, generation: generation) else {
      return missingEventResult(generation: generation)
    }
    return transitionToRetiring(
      record.key,
      nextState: .closing,
      reason: .remoteError,
      metric: \ClientUDPAssociationMetrics.remoteErrors
    )
  }

  @discardableResult
  public func receiveRemoteClose(
    associationID: UInt32,
    generation: UInt64
  ) -> ClientUDPAssociationEventResult {
    guard validateGeneration(generation) else { return .ignoredStaleGeneration }
    guard var record = recordsByID[associationID] else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return .ignoredUnknownAssociation
    }
    let previous = record.state
    let effect = beginCleanupIfNeeded(
      record: &record,
      reason: .remoteClose,
      shouldSendClose: true
    )
    recordsByID[associationID] = record
    removeRecord(associationID)
    metrics.remoteCloses = incremented(metrics.remoteCloses)
    perform(effect)
    return .applied(key: record.key, from: previous, to: .closed)
  }

  /// Marks dispatch of expiry cleanup as complete without releasing the ID.
  /// A subsequent relay close/ack or generation teardown remains mandatory.
  @discardableResult
  public func completeExpiry(
    for key: ClientUDPAssociationKey
  ) -> ClientUDPAssociationEventResult {
    guard validateGeneration(key.generation) else { return .ignoredStaleGeneration }
    guard var record = recordsByID[key.associationID], record.key == key else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return .ignoredUnknownAssociation
    }
    guard record.state == .expired else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return .ignoredState(record.state)
    }
    record.state = .closing
    recordsByID[key.associationID] = record
    metrics.expiryCompletions = incremented(metrics.expiryCompletions)
    return .applied(key: key, from: .expired, to: .closing)
  }

  @discardableResult
  public func activateGeneration(_ generation: UInt64) -> ClientUDPAssociationGenerationResult {
    guard !isProviderStopped else { return .rejectedProviderStopped }
    if currentGeneration == generation { return .alreadyActive(generation) }
    guard generation > lastGeneration else {
      metrics.staleEvents = incremented(metrics.staleEvents)
      return .rejectedStaleGeneration
    }
    let effects = retireGeneration(reason: .sessionReplaced)
    if currentGeneration != nil {
      metrics.sessionReplacements = incremented(metrics.sessionReplacements)
    }
    currentGeneration = generation
    lastGeneration = generation
    nextAssociationID = 1
    perform(effects)
    return .activated(generation)
  }

  public func sessionLost(generation: UInt64) {
    guard validateGeneration(generation) else { return }
    let effects = retireGeneration(reason: .sessionLoss)
    currentGeneration = nil
    metrics.sessionLosses = incremented(metrics.sessionLosses)
    perform(effects)
  }

  public func cancel(generation: UInt64) {
    guard validateGeneration(generation) else { return }
    let effects = retireGeneration(reason: .cancelled)
    currentGeneration = nil
    metrics.cancellations = incremented(metrics.cancellations)
    perform(effects)
  }

  public func stopProvider() {
    guard !isProviderStopped else { return }
    let effects = retireGeneration(reason: .providerStop)
    currentGeneration = nil
    isProviderStopped = true
    metrics.providerStops = incremented(metrics.providerStops)
    perform(effects)
  }

  public func snapshot() -> ClientUDPAssociationRegistrySnapshot {
    let counts = Dictionary(grouping: recordsByID.values, by: \Record.state).mapValues(\.count)
    return ClientUDPAssociationRegistrySnapshot(
      currentGeneration: currentGeneration,
      providerStopped: isProviderStopped,
      associationCount: recordsByID.count,
      activeAssociations: counts[.active] ?? 0,
      closingAssociations: counts[.closing] ?? 0,
      expiredAssociations: counts[.expired] ?? 0,
      scheduledTimers: recordsByID.values.count { $0.timer != nil },
      metrics: metrics
    )
  }

  internal func setNextAssociationIDForTesting(_ associationID: UInt32) {
    precondition(associationID != 0)
    nextAssociationID = associationID
  }

  private var idleTimeout: Duration {
    .milliseconds(Int64(configuration.idleTimeoutMilliseconds))
  }

  private func validateGeneration(_ generation: UInt64) -> Bool {
    guard generation == currentGeneration else {
      metrics.staleEvents = incremented(metrics.staleEvents)
      return false
    }
    return true
  }

  private func validatedRecord(
    associationID: UInt32,
    generation: UInt64
  ) -> Record? {
    guard validateGeneration(generation) else { return nil }
    return recordsByID[associationID]
  }

  private func missingEventResult(generation: UInt64) -> ClientUDPAssociationEventResult {
    if generation != currentGeneration { return .ignoredStaleGeneration }
    metrics.lateEvents = incremented(metrics.lateEvents)
    return .ignoredUnknownAssociation
  }

  private func reject(
    _ reason: ClientUDPAssociationAdmissionFailureReason
  ) -> Result<ClientUDPAssociationKey, ClientUDPAssociationAdmissionFailure> {
    metrics.admissionRejected = incremented(metrics.admissionRejected)
    return .failure(ClientUDPAssociationAdmissionFailure(reason: reason))
  }

  private func allocateAssociationID() -> UInt32? {
    for _ in 0..<Int(configuration.allocatorSearchLimit) {
      let candidate = nextAssociationID
      if nextAssociationID == UInt32.max {
        nextAssociationID = 1
        metrics.identifierWraparounds = incremented(metrics.identifierWraparounds)
      } else {
        nextAssociationID += 1
      }
      if recordsByID[candidate] == nil { return candidate }
      metrics.allocationCollisions = incremented(metrics.allocationCollisions)
    }
    return nil
  }

  private func refreshActivity(_ record: inout Record) {
    record.timer?.cancel()
    record.deadline = clock.now().advanced(by: idleTimeout)
    scheduleTimer(for: &record, sleepingFor: idleTimeout)
    metrics.activityUpdates = incremented(metrics.activityUpdates)
  }

  private func scheduleTimer(for record: inout Record, sleepingFor duration: Duration) {
    let key = record.key
    let clock = self.clock
    record.timerEpoch &+= 1
    let timerEpoch = record.timerEpoch
    record.timer = Task { [weak self] in
      do {
        try await clock.sleep(for: duration)
      } catch {
        return
      }
      await self?.idleTimerFired(key, timerEpoch: timerEpoch)
    }
  }

  private func idleTimerFired(_ key: ClientUDPAssociationKey, timerEpoch: UInt64) {
    guard validateGeneration(key.generation) else { return }
    guard var record = recordsByID[key.associationID], record.key == key else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return
    }
    guard record.timer != nil, record.timerEpoch == timerEpoch else {
      metrics.staleTimerCallbacks = incremented(metrics.staleTimerCallbacks)
      return
    }
    guard record.state == .active else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return
    }
    let now = clock.now()
    guard now >= record.deadline else {
      record.timer = nil
      scheduleTimer(for: &record, sleepingFor: now.duration(to: record.deadline))
      recordsByID[key.associationID] = record
      return
    }

    let effect = beginCleanupIfNeeded(
      record: &record,
      reason: .idleExpiry,
      shouldSendClose: true
    )
    record.state = .expired
    record.timer = nil
    recordsByID[key.associationID] = record
    metrics.idleExpired = incremented(metrics.idleExpired)
    perform(effect)
  }

  private func transitionToRetiring(
    _ key: ClientUDPAssociationKey,
    nextState: ClientUDPAssociationState,
    reason: ClientUDPAssociationCleanupReason,
    metric: WritableKeyPath<ClientUDPAssociationMetrics, UInt64>
  ) -> ClientUDPAssociationEventResult {
    guard validateGeneration(key.generation) else { return .ignoredStaleGeneration }
    guard var record = recordsByID[key.associationID], record.key == key else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return .ignoredUnknownAssociation
    }
    guard record.state == .active else {
      metrics.lateEvents = incremented(metrics.lateEvents)
      return .ignoredState(record.state)
    }
    let previous = record.state
    let effect = beginCleanupIfNeeded(record: &record, reason: reason, shouldSendClose: true)
    record.state = nextState
    recordsByID[key.associationID] = record
    metrics[keyPath: metric] = incremented(metrics[keyPath: metric])
    perform(effect)
    return .applied(key: key, from: previous, to: nextState)
  }

  private func beginCleanupIfNeeded(
    record: inout Record,
    reason: ClientUDPAssociationCleanupReason,
    shouldSendClose: Bool
  ) -> CleanupEffect? {
    guard !record.cleanupInvoked else { return nil }
    record.cleanupInvoked = true
    record.timer?.cancel()
    record.timer = nil
    metrics.hevCleanupCallbacks = incremented(metrics.hevCleanupCallbacks)
    metrics.relayCleanupCallbacks = incremented(metrics.relayCleanupCallbacks)
    return CleanupEffect(
      handle: record.handle,
      reason: reason,
      relay: ClientUDPAssociationRelayCleanup(
        key: record.key,
        reason: reason,
        shouldSendClose: shouldSendClose
      )
    )
  }

  private func retireGeneration(
    reason: ClientUDPAssociationCleanupReason
  ) -> [CleanupEffect] {
    var effects: [CleanupEffect] = []
    for associationID in recordsByID.keys.sorted() {
      guard var record = recordsByID[associationID] else { continue }
      if let effect = beginCleanupIfNeeded(
        record: &record,
        reason: reason,
        shouldSendClose: false
      ) {
        effects.append(effect)
      }
      recordsByID[associationID] = record
      removeRecord(associationID)
    }
    return effects
  }

  private func removeRecord(_ associationID: UInt32) {
    guard let record = recordsByID.removeValue(forKey: associationID) else { return }
    record.timer?.cancel()
    identifiersByHandle.removeValue(forKey: record.handle)
    metrics.terminalCleanups = incremented(metrics.terminalCleanups)
  }

  private func perform(_ effect: CleanupEffect?) {
    guard let effect else { return }
    callbacks.closeHEV(effect.handle, effect.reason)
    callbacks.cleanupRelay(effect.relay)
  }

  private func perform(_ effects: [CleanupEffect]) {
    for effect in effects { perform(effect) }
  }

  private func incremented(_ value: UInt64) -> UInt64 {
    value == UInt64.max ? UInt64.max : value + 1
  }
}
