import Foundation

public enum TunnelLifecycleState: String, Codable, Equatable, Sendable {
  case disconnected
  case connecting
  case connectedFull
  case connectedDegraded
  case reasserting
  case failed
  case disconnecting
  case unknown

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    self = TunnelLifecycleState(rawValue: value) ?? .unknown
  }
}

public enum ProviderStopReason: Equatable, Sendable {
  case userInitiated
  case system
  case startupFailure
  case providerFailure
  case platform(code: Int)

  /// Maps the public `NEProviderStopReason` raw value without importing
  /// NetworkExtension into the candidate-neutral core target.
  public static func apple(rawValue: Int, duringStartup: Bool) -> Self {
    switch rawValue {
    case 1:
      .userInitiated
    case 2:
      .providerFailure
    case 7 where duringStartup, 14 where duringStartup:
      .startupFailure
    default:
      .platform(code: rawValue)
    }
  }
}

public enum ProviderLifecyclePhase: Equatable, Sendable {
  case idle
  case starting
  case running
  case stopping
}

/// Synchronous cancellation and force-close seam for handles whose platform
/// APIs can be interrupted without waiting for an async callback.
public protocol ProviderCleanupControllable: AnyObject, Sendable {
  func cancelProviderWork()
  func forceCloseProviderHandle()
}

/// Fixed-capacity, generation-scoped cleanup fan-out.
///
/// A handle registered after retirement is cancelled and force-closed
/// immediately, which prevents a late startup callback from escaping into a
/// newer generation.
public final class ProviderCleanupRegistry: @unchecked Sendable {
  public static let maximumHandles = 64

  private enum State {
    case accepting
    case cancelling
    case retired
  }

  private let lock = NSLock()
  private var state = State.accepting
  private var handles: [ObjectIdentifier: any ProviderCleanupControllable] = [:]

  public init() {}

  @discardableResult
  public func register(_ handle: any ProviderCleanupControllable) -> Bool {
    let action: RegistrationAction = lock.withLock {
      switch state {
      case .accepting where handles.count < Self.maximumHandles:
        handles[ObjectIdentifier(handle)] = handle
        return .accepted
      case .accepting, .cancelling:
        return .cancelAndForceClose
      case .retired:
        return .cancelAndForceClose
      }
    }
    if action == .cancelAndForceClose {
      handle.cancelProviderWork()
      handle.forceCloseProviderHandle()
      return false
    }
    return true
  }

  public func cancelAll() {
    let snapshot: [any ProviderCleanupControllable] = lock.withLock {
      guard state != .retired else { return [] }
      state = .cancelling
      return Array(handles.values)
    }
    for handle in snapshot {
      handle.cancelProviderWork()
    }
  }

  public func forceCloseAll() {
    let snapshot: [any ProviderCleanupControllable] = lock.withLock {
      state = .retired
      let snapshot = Array(handles.values)
      handles.removeAll(keepingCapacity: false)
      return snapshot
    }
    for handle in snapshot {
      handle.cancelProviderWork()
      handle.forceCloseProviderHandle()
    }
  }

  public func retireAfterGracefulCleanup() {
    lock.withLock {
      state = .retired
      handles.removeAll(keepingCapacity: false)
    }
  }

  var registeredHandleCount: Int {
    lock.withLock { handles.count }
  }

  private enum RegistrationAction {
    case accepted
    case cancelAndForceClose
  }
}

public struct TunnelRuntimeContext: Sendable {
  public let configuration: TunnelConfiguration
  public let packetFlow: any PacketFlow
  public let dependencies: TunnelRuntimeDependencies
  public let cleanupRegistry: ProviderCleanupRegistry

  public init(
    configuration: TunnelConfiguration,
    packetFlow: any PacketFlow,
    dependencies: TunnelRuntimeDependencies,
    cleanupRegistry: ProviderCleanupRegistry = ProviderCleanupRegistry()
  ) {
    self.configuration = configuration
    self.packetFlow = packetFlow
    self.dependencies = dependencies
    self.cleanupRegistry = cleanupRegistry
  }
}

/// Shared runtime generation owned by the provider, not the containing app.
public protocol TunnelRuntime: AnyObject, Sendable {
  func start() async throws
  func stop(reason: ProviderStopReason) async
  func lifecycleState() async -> TunnelLifecycleState
}

public protocol TunnelRuntimeFactory: Sendable {
  func makeRuntime(context: TunnelRuntimeContext) async throws -> any TunnelRuntime
}

public protocol ProviderRuntimeSnapshotSource: Sendable {
  func latestProviderSnapshot() async -> TunnelRuntimePublishedSnapshot?
}

public protocol ProviderDiagnosticsSnapshotSource: Sendable {
  func providerDiagnosticsSnapshot(
    requestID: OpaqueRuntimeRequestIdentifier?
  ) async throws -> RuntimeDiagnosticsSnapshot
}

public protocol ProviderLifecycleDiagnosticsSink: Sendable {
  func recordProviderStopReason(rawValue: Int)
  func recordProviderCleanupDeadlineExceeded()
}

public typealias ProviderStartCompletionHandler = @Sendable (NSError?) -> Void
public typealias ProviderStopCompletionHandler = @Sendable () -> Void
public typealias ProviderMessageResponseHandler = @Sendable (Data) -> Void
public typealias ProviderCancelTunnelHandler = @Sendable (NSError) -> Void

/// Provider-facing lifecycle seam used identically by both platform roots.
public protocol TunnelProviderLifecycle: Sendable {
  func start(configuration: TunnelConfiguration) async throws
  func stop(reason: ProviderStopReason) async
  func handleAppMessage(_ message: Data) async throws -> Data
  func lifecyclePhase() async -> ProviderLifecyclePhase

  func start(
    configuration: TunnelConfiguration,
    completionHandler: @escaping ProviderStartCompletionHandler
  )
  func stop(
    rawReason: Int,
    completionHandler: @escaping ProviderStopCompletionHandler
  )
  func handleAppMessage(
    _ message: Data,
    responseHandler: ProviderMessageResponseHandler?
  )
  func providerDidFail(
    _ errorCode: ProviderNSErrorCode,
    cancelTunnelWithError: @escaping ProviderCancelTunnelHandler
  )
}

public enum ProviderNSErrorCode: Int, CaseIterable, Sendable {
  case configurationInvalid = 1001
  case configurationSchemaUnsupported = 1002
  case startReferenceMismatch = 1003
  case lifecycleBusy = 1004
  case startCancelled = 1005
  case startupTimedOut = 1006
  case runtimeStartupFailed = 1007
  case networkSettingsFailed = 1008
  case internalInvariant = 1009

  public static let errorDomain = "works.relux.tunnel.provider"

  public var nsError: NSError {
    NSError(domain: Self.errorDomain, code: rawValue, userInfo: [:])
  }
}

public enum ProviderAdapterError: Error, Equatable, Sendable {
  case lifecycleBusy(ProviderLifecyclePhase)
  case startCancelled
  case startupTimedOut
  case runtimeStartupFailed
  case generationExhausted

  public var nsError: NSError {
    switch self {
    case .lifecycleBusy:
      ProviderNSErrorCode.lifecycleBusy.nsError
    case .startCancelled:
      ProviderNSErrorCode.startCancelled.nsError
    case .startupTimedOut:
      ProviderNSErrorCode.startupTimedOut.nsError
    case .runtimeStartupFailed:
      ProviderNSErrorCode.runtimeStartupFailed.nsError
    case .generationExhausted:
      ProviderNSErrorCode.internalInvariant.nsError
    }
  }
}

public enum ProviderMessageError: Error, Equatable {
  case unsupportedProtocolVersion(UInt16)
  case unsupportedKind(String)
  case invalidPayload(RuntimeProtocolErrorCode)
}

public struct ProviderVersionRequest: Codable, Equatable, Sendable {
  public let protocolVersion: UInt16
  public let kind: String

  public init(protocolVersion: UInt16 = ProviderMessageCodec.currentVersion) {
    self.protocolVersion = protocolVersion
    kind = ProviderMessageCodec.versionKind
  }
}

public struct ProviderVersionResponse: Codable, Equatable, Sendable {
  public let protocolVersion: UInt16
  public let kind: String

  public init(protocolVersion: UInt16) {
    self.protocolVersion = protocolVersion
    kind = ProviderMessageCodec.versionKind
  }
}

/// Frozen compatibility codec for the pre-v1 discovery message.
public enum ProviderMessageCodec {
  public static let currentVersion = RuntimeMessageProtocol.currentProtocolVersion
  public static let versionKind = "version"

  public static func encodeVersionRequest(
    protocolVersion: UInt16 = currentVersion
  ) throws -> Data {
    try RuntimeJSONCodec.encode(
      ProviderVersionRequest(protocolVersion: protocolVersion),
      maximumBytes: RuntimeMessageSizeLimit.legacyVersion
    )
  }

  public static func decodeVersionResponse(_ data: Data) throws -> ProviderVersionResponse {
    try validateLegacyObject(data)
    let response: ProviderVersionResponse
    do {
      response = try JSONDecoder().decode(ProviderVersionResponse.self, from: data)
    } catch {
      throw ProviderMessageError.invalidPayload(.corruptPayload)
    }
    guard response.kind == versionKind else {
      throw ProviderMessageError.unsupportedKind(response.kind)
    }
    guard response.protocolVersion == currentVersion else {
      throw ProviderMessageError.unsupportedProtocolVersion(response.protocolVersion)
    }
    return response
  }

  static func response(to data: Data) throws -> Data {
    try validateLegacyObject(data)
    let request: ProviderVersionRequest
    do {
      request = try JSONDecoder().decode(ProviderVersionRequest.self, from: data)
    } catch {
      throw ProviderMessageError.invalidPayload(.corruptPayload)
    }
    guard request.kind == versionKind else {
      throw ProviderMessageError.unsupportedKind(request.kind)
    }
    guard request.protocolVersion == currentVersion else {
      throw ProviderMessageError.unsupportedProtocolVersion(request.protocolVersion)
    }
    return try RuntimeJSONCodec.encode(
      ProviderVersionResponse(protocolVersion: currentVersion),
      maximumBytes: RuntimeMessageSizeLimit.legacyVersion
    )
  }

  static func isVersionCandidate(_ data: Data) -> Bool {
    guard data.count <= RuntimeMessageSizeLimit.legacyVersion else { return false }
    struct KindHeader: Decodable { let kind: String }
    return (try? JSONDecoder().decode(KindHeader.self, from: data).kind) == versionKind
  }

  private static func validateLegacyObject(_ data: Data) throws {
    do {
      let keys = try StrictJSONValidator.validate(
        data,
        maximumBytes: RuntimeMessageSizeLimit.legacyVersion
      )
      guard keys == ["kind", "protocolVersion"] else {
        throw ProviderMessageError.invalidPayload(.corruptPayload)
      }
    } catch let error as ProviderMessageError {
      throw error
    } catch let error as RuntimeMessageCodecError {
      throw ProviderMessageError.invalidPayload(error.protocolErrorCode)
    } catch {
      throw ProviderMessageError.invalidPayload(.corruptPayload)
    }
  }
}

private final class ProviderOnceGate<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var handler: (@Sendable (Value) -> Void)?

  init(_ handler: @escaping @Sendable (Value) -> Void) {
    self.handler = handler
  }

  func complete(_ value: Value) {
    let callback = lock.withLock {
      let callback = handler
      handler = nil
      return callback
    }
    callback?(value)
  }
}

private final class ProviderFirstResult<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var result: Value?
  private var continuation: CheckedContinuation<Value, Never>?

  func wait() async -> Value {
    await withCheckedContinuation { continuation in
      let immediate = lock.withLock { () -> Value? in
        if let result { return result }
        self.continuation = continuation
        return nil
      }
      if let immediate {
        continuation.resume(returning: immediate)
      }
    }
  }

  func resolve(_ value: Value) {
    let continuation = lock.withLock { () -> CheckedContinuation<Value, Never>? in
      guard result == nil else { return nil }
      result = value
      let continuation = self.continuation
      self.continuation = nil
      return continuation
    }
    continuation?.resume(returning: value)
  }
}

private final class ProviderRetirementSignal: @unchecked Sendable {
  private let lock = NSLock()
  private var isRetired = false
  private var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]

  func wait() async throws {
    let identifier = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, any Error>) in
        let result: RetirementRegistration = lock.withLock {
          if isRetired { return .retired }
          if Task<Never, Never>.isCancelled { return .cancelled }
          waiters[identifier] = continuation
          return .registered
        }
        switch result {
        case .registered:
          break
        case .retired:
          continuation.resume()
        case .cancelled:
          continuation.resume(throwing: CancellationError())
        }
      }
    } onCancel: {
      let continuation = self.lock.withLock {
        self.waiters.removeValue(forKey: identifier)
      }
      continuation?.resume(throwing: CancellationError())
    }
  }

  func retire() {
    let waiters: [CheckedContinuation<Void, any Error>] = lock.withLock {
      guard !isRetired else { return [] }
      isRetired = true
      let waiters = Array(self.waiters.values)
      self.waiters.removeAll()
      return waiters
    }
    for waiter in waiters { waiter.resume() }
  }

  private enum RetirementRegistration {
    case registered
    case retired
    case cancelled
  }
}

/// Synchronous, exactly-once admission for provider-failure callbacks.
///
/// `providerDidFail` hands its work to the actor through an unstructured task,
/// and those tasks are not ordered against one another. Claiming admission on
/// the caller's thread keeps the first call the one that cancels the tunnel,
/// and drops every later or concurrent call before it can reach the actor.
private final class ProviderFailureAdmission: @unchecked Sendable {
  private let lock = NSLock()
  private var isClaimed = false

  func claim() -> Bool {
    lock.withLock {
      guard !isClaimed else { return false }
      isClaimed = true
      return true
    }
  }

  func releaseForNewGeneration() {
    lock.withLock { isClaimed = false }
  }
}

private struct UnavailableProviderSnapshotSource: ProviderRuntimeSnapshotSource {
  func latestProviderSnapshot() async -> TunnelRuntimePublishedSnapshot? { nil }
}

private struct UnavailableProviderDiagnosticsSource: ProviderDiagnosticsSnapshotSource {
  func providerDiagnosticsSnapshot(
    requestID: OpaqueRuntimeRequestIdentifier?
  ) async throws -> RuntimeDiagnosticsSnapshot {
    throw ProviderAdapterError.runtimeStartupFailed
  }
}

/// Shared provider-side router, lifecycle joiner, and bounded cleanup owner.
public actor TunnelProviderAdapter: TunnelProviderLifecycle {
  private static let maximumRememberedRequestIDs = 256

  private struct ActiveGeneration {
    let identifier: UInt64
    let cleanupRegistry: ProviderCleanupRegistry
    let retirementSignal: ProviderRetirementSignal
    var runtime: (any TunnelRuntime)?
  }

  private enum StartRaceResult: Sendable {
    case succeeded
    case failed(ProviderAdapterError)
    case deadline
  }

  private enum CleanupRaceResult: Sendable {
    case graceful
    case deadline
  }

  private enum SnapshotLookupResult: Sendable {
    case value(TunnelRuntimePublishedSnapshot?)
    case retired
  }

  private enum DiagnosticsLookupResult: Sendable {
    case value(Result<RuntimeDiagnosticsSnapshot, ProviderAdapterError>)
    case retired
  }

  private let packetFlow: any PacketFlow
  private let runtimeFactory: any TunnelRuntimeFactory
  private let dependencies: TunnelRuntimeDependencies
  private let snapshotSource: any ProviderRuntimeSnapshotSource
  private let diagnosticsSource: any ProviderDiagnosticsSnapshotSource
  private let lifecycleDiagnostics: (any ProviderLifecycleDiagnosticsSink)?
  private let startBudget: Duration
  private let cleanupBudget: Duration
  private let failureAdmission = ProviderFailureAdmission()

  private var activeGeneration: ActiveGeneration?
  private var latestGeneration: UInt64 = 0
  private var phase: ProviderLifecyclePhase = .idle
  private var cleanupTask: Task<CleanupRaceResult, Never>?
  private var cleanupGeneration: UInt64?
  private var pendingStartGate: ProviderOnceGate<NSError?>?
  private var awaitingSystemStopAfterProviderFailure = false

  private var requestLedgerGeneration: UInt64?
  private var activeRequestIDs: Set<UUID> = []
  private var recentRequestIDs: Set<UUID> = []
  private var recentRequestOrder: [UUID] = []
  private var pendingMessageGates: [UUID: ProviderOnceGate<Data>] = [:]

  public init(
    packetFlow: any PacketFlow,
    runtimeFactory: any TunnelRuntimeFactory,
    dependencies: TunnelRuntimeDependencies
  ) {
    self.init(
      packetFlow: packetFlow,
      runtimeFactory: runtimeFactory,
      dependencies: dependencies,
      snapshotSource: UnavailableProviderSnapshotSource(),
      diagnosticsSource: UnavailableProviderDiagnosticsSource()
    )
  }

  public init(
    packetFlow: any PacketFlow,
    runtimeFactory: any TunnelRuntimeFactory,
    dependencies: TunnelRuntimeDependencies,
    snapshotSource: any ProviderRuntimeSnapshotSource,
    diagnosticsSource: any ProviderDiagnosticsSnapshotSource,
    lifecycleDiagnostics: (any ProviderLifecycleDiagnosticsSink)? = nil,
    startBudget: Duration = .seconds(60),
    cleanupBudget: Duration = .seconds(10)
  ) {
    precondition(startBudget > .zero)
    precondition(cleanupBudget > .zero)
    self.packetFlow = packetFlow
    self.runtimeFactory = runtimeFactory
    self.dependencies = dependencies
    self.snapshotSource = snapshotSource
    self.diagnosticsSource = diagnosticsSource
    self.lifecycleDiagnostics = lifecycleDiagnostics
    self.startBudget = startBudget
    self.cleanupBudget = cleanupBudget
  }

  public func start(configuration: TunnelConfiguration) async throws {
    try await startGeneration(configuration: configuration)
  }

  public nonisolated func start(
    configuration: TunnelConfiguration,
    completionHandler: @escaping ProviderStartCompletionHandler
  ) {
    let gate = ProviderOnceGate<NSError?>(completionHandler)
    Task { [weak self] in
      guard let self else {
        gate.complete(ProviderNSErrorCode.internalInvariant.nsError)
        return
      }
      await self.startWithGate(configuration: configuration, gate: gate)
    }
  }

  private func startWithGate(
    configuration: TunnelConfiguration,
    gate: ProviderOnceGate<NSError?>
  ) async {
    guard pendingStartGate == nil else {
      gate.complete(ProviderNSErrorCode.lifecycleBusy.nsError)
      return
    }
    pendingStartGate = gate
    do {
      try await startGeneration(configuration: configuration)
      gate.complete(nil)
    } catch let error as ProviderAdapterError {
      gate.complete(error.nsError)
    } catch {
      gate.complete(ProviderNSErrorCode.runtimeStartupFailed.nsError)
    }
    if pendingStartGate === gate {
      pendingStartGate = nil
    }
  }

  private func startGeneration(configuration: TunnelConfiguration) async throws {
    guard phase == .idle, !awaitingSystemStopAfterProviderFailure else {
      throw ProviderAdapterError.lifecycleBusy(phase)
    }
    guard latestGeneration < UInt64.max else {
      throw ProviderAdapterError.generationExhausted
    }

    latestGeneration += 1
    let generation = latestGeneration
    failureAdmission.releaseForNewGeneration()
    let registry = ProviderCleanupRegistry()
    if let controllable = packetFlow as? any ProviderCleanupControllable {
      registry.register(controllable)
    }
    activeGeneration = ActiveGeneration(
      identifier: generation,
      cleanupRegistry: registry,
      retirementSignal: ProviderRetirementSignal(),
      runtime: nil
    )
    resetRequestLedger(for: generation)
    phase = .starting

    let context = TunnelRuntimeContext(
      configuration: configuration,
      packetFlow: packetFlow,
      dependencies: dependencies,
      cleanupRegistry: registry
    )
    let operation = Task { [runtimeFactory, weak self] () -> StartRaceResult in
      do {
        let runtime = try await runtimeFactory.makeRuntime(context: context)
        guard self != nil else {
          if let controllable = runtime as? any ProviderCleanupControllable {
            registry.register(controllable)
          }
          registry.forceCloseAll()
          Task { await runtime.stop(reason: .startupFailure) }
          return .failed(.startCancelled)
        }
        guard
          await self?.install(
            runtime: runtime,
            generation: generation,
            registry: registry
          ) == true
        else {
          Task { await runtime.stop(reason: .startupFailure) }
          return .failed(.startCancelled)
        }
        try await runtime.start()
        return .succeeded
      } catch is CancellationError {
        return .failed(.startCancelled)
      } catch let error as ProviderAdapterError {
        return .failed(error)
      } catch {
        return .failed(.runtimeStartupFailed)
      }
    }

    let outcome = await raceStart(operation)
    switch outcome {
    case .succeeded:
      guard phase == .starting, activeGeneration?.identifier == generation else {
        await joinCleanupIfPresent(generation: generation)
        throw ProviderAdapterError.startCancelled
      }
      phase = .running
    case .failed(let error):
      await stopAndJoin(
        reason: error == .startCancelled ? .system : .startupFailure,
        generation: generation,
        keepStoppingAfterCleanup: false
      )
      throw error
    case .deadline:
      operation.cancel()
      await stopAndJoin(
        reason: .startupFailure,
        generation: generation,
        keepStoppingAfterCleanup: false
      )
      throw ProviderAdapterError.startupTimedOut
    }
  }

  private func install(
    runtime: any TunnelRuntime,
    generation: UInt64,
    registry: ProviderCleanupRegistry
  ) -> Bool {
    guard phase == .starting, activeGeneration?.identifier == generation else {
      if let controllable = runtime as? any ProviderCleanupControllable {
        registry.register(controllable)
      }
      return false
    }
    if let controllable = runtime as? any ProviderCleanupControllable {
      activeGeneration?.cleanupRegistry.register(controllable)
    }
    activeGeneration?.runtime = runtime
    return true
  }

  private func raceStart(_ operation: Task<StartRaceResult, Never>) async -> StartRaceResult {
    let first = ProviderFirstResult<StartRaceResult>()
    Task {
      first.resolve(await operation.value)
    }
    let deadline = Task { [clock = dependencies.clock, startBudget] in
      do {
        try await clock.sleep(for: startBudget)
        first.resolve(.deadline)
      } catch {
        // Cancellation means startup won the race.
      }
    }
    let result = await first.wait()
    if case .deadline = result {
      operation.cancel()
    } else {
      deadline.cancel()
    }
    return result
  }

  public func stop(reason: ProviderStopReason) async {
    await performStop(reason: reason, gate: nil)
  }

  public nonisolated func stop(
    rawReason: Int,
    completionHandler: @escaping ProviderStopCompletionHandler
  ) {
    let gate = ProviderOnceGate<Void> { _ in completionHandler() }
    Task { [weak self] in
      guard let self else {
        gate.complete(())
        return
      }
      await self.stopWithRawReason(rawReason, gate: gate)
    }
  }

  private func stopWithRawReason(
    _ rawReason: Int,
    gate: ProviderOnceGate<Void>
  ) async {
    lifecycleDiagnostics?.recordProviderStopReason(rawValue: rawReason)
    let reason = ProviderStopReason.apple(rawValue: rawReason, duringStartup: phase == .starting)
    await performStop(reason: reason, gate: gate)
  }

  private func performStop(
    reason: ProviderStopReason,
    gate: ProviderOnceGate<Void>?
  ) async {
    if awaitingSystemStopAfterProviderFailure {
      if let cleanupTask {
        _ = await cleanupTask.value
        finalizeCleanup(
          generation: cleanupGeneration,
          keepStoppingAfterCleanup: true
        )
      }
      pendingStartGate?.complete(ProviderNSErrorCode.startCancelled.nsError)
      pendingStartGate = nil
      awaitingSystemStopAfterProviderFailure = false
      phase = .idle
      gate?.complete(())
      return
    }

    guard let generation = activeGeneration?.identifier else {
      phase = .idle
      pendingStartGate?.complete(ProviderNSErrorCode.startCancelled.nsError)
      pendingStartGate = nil
      gate?.complete(())
      return
    }

    await stopAndJoin(
      reason: reason,
      generation: generation,
      keepStoppingAfterCleanup: false
    )
    pendingStartGate?.complete(ProviderNSErrorCode.startCancelled.nsError)
    pendingStartGate = nil
    gate?.complete(())
  }

  private func stopAndJoin(
    reason: ProviderStopReason,
    generation: UInt64,
    keepStoppingAfterCleanup: Bool
  ) async {
    guard activeGeneration?.identifier == generation || cleanupGeneration == generation else {
      return
    }
    let operation = beginCleanup(reason: reason, generation: generation)
    _ = await operation.value
    finalizeCleanup(
      generation: generation,
      keepStoppingAfterCleanup: keepStoppingAfterCleanup
    )
  }

  private func joinCleanupIfPresent(generation: UInt64) async {
    guard cleanupGeneration == generation, let cleanupTask else { return }
    _ = await cleanupTask.value
    finalizeCleanup(generation: generation, keepStoppingAfterCleanup: false)
  }

  private func beginCleanup(
    reason: ProviderStopReason,
    generation: UInt64
  ) -> Task<CleanupRaceResult, Never> {
    if cleanupGeneration == generation, let cleanupTask {
      return cleanupTask
    }

    phase = .stopping
    retireRequestLedger(generation: generation)
    activeGeneration?.retirementSignal.retire()
    let runtime = activeGeneration?.identifier == generation ? activeGeneration?.runtime : nil
    let registry =
      activeGeneration?.identifier == generation
      ? activeGeneration?.cleanupRegistry : nil
    registry?.cancelAll()

    let operation = Task { [clock = dependencies.clock, cleanupBudget, lifecycleDiagnostics] in
      guard let registry else { return CleanupRaceResult.graceful }
      guard let runtime else {
        registry.retireAfterGracefulCleanup()
        return .graceful
      }

      let first = ProviderFirstResult<CleanupRaceResult>()
      let graceful = Task {
        await runtime.stop(reason: reason)
        first.resolve(.graceful)
      }
      let deadline = Task {
        do {
          try await clock.sleep(for: cleanupBudget)
          first.resolve(.deadline)
        } catch {
          // Cancellation means graceful cleanup won the race.
        }
      }

      let result = await first.wait()
      switch result {
      case .graceful:
        deadline.cancel()
        registry.retireAfterGracefulCleanup()
      case .deadline:
        graceful.cancel()
        registry.forceCloseAll()
        lifecycleDiagnostics?.recordProviderCleanupDeadlineExceeded()
      }
      return result
    }
    cleanupGeneration = generation
    cleanupTask = operation
    return operation
  }

  private func finalizeCleanup(
    generation: UInt64?,
    keepStoppingAfterCleanup: Bool
  ) {
    guard let generation, cleanupGeneration == generation else { return }
    activeGeneration = nil
    cleanupTask = nil
    cleanupGeneration = nil
    phase = keepStoppingAfterCleanup ? .stopping : .idle
  }

  public nonisolated func providerDidFail(
    _ errorCode: ProviderNSErrorCode,
    cancelTunnelWithError: @escaping ProviderCancelTunnelHandler
  ) {
    guard failureAdmission.claim() else { return }
    Task { [weak self] in
      await self?.handleProviderFailure(
        errorCode,
        cancelTunnelWithError: cancelTunnelWithError
      )
    }
  }

  private func handleProviderFailure(
    _ errorCode: ProviderNSErrorCode,
    cancelTunnelWithError: ProviderCancelTunnelHandler
  ) async {
    let generation = activeGeneration?.identifier ?? latestGeneration
    cancelTunnelWithError(errorCode.nsError)

    awaitingSystemStopAfterProviderFailure = true
    guard activeGeneration?.identifier == generation else {
      phase = .stopping
      return
    }
    await stopAndJoin(
      reason: .providerFailure,
      generation: generation,
      keepStoppingAfterCleanup: true
    )
    pendingStartGate?.complete(errorCode.nsError)
    pendingStartGate = nil
  }

  public func handleAppMessage(_ message: Data) async throws -> Data {
    if message.count > RuntimeMessageSizeLimit.command {
      throw ProviderMessageError.invalidPayload(.payloadTooLarge)
    }
    if ProviderMessageCodec.isVersionCandidate(message) {
      return try ProviderMessageCodec.response(to: message)
    }
    return await routeMessage(message)
  }

  public nonisolated func handleAppMessage(
    _ message: Data,
    responseHandler: ProviderMessageResponseHandler?
  ) {
    let gate = responseHandler.map(ProviderOnceGate<Data>.init)
    Task { [weak self] in
      let response: Data
      if ProviderMessageCodec.isVersionCandidate(message) {
        do {
          response = try ProviderMessageCodec.response(to: message)
        } catch let error as ProviderMessageError {
          response = Self.protocolErrorResponse(
            requestID: nil,
            code: Self.protocolCode(for: error)
          )
        } catch {
          response = Self.protocolErrorResponse(requestID: nil, code: .corruptPayload)
        }
      } else {
        response =
          await self?.routeMessage(message, gate: gate)
          ?? Self.protocolErrorResponse(requestID: nil, code: .corruptPayload)
      }
      gate?.complete(response)
    }
  }

  private func routeMessage(
    _ message: Data,
    gate: ProviderOnceGate<Data>? = nil
  ) async -> Data {
    let command: RuntimeCommand
    do {
      command = try RuntimeMessageCodec.decodeCommand(message)
    } catch let error as RuntimeMessageCodecError {
      return Self.protocolErrorResponse(requestID: nil, code: error.protocolErrorCode)
    } catch {
      return Self.protocolErrorResponse(requestID: nil, code: .corruptPayload)
    }

    guard let requestID = command.requestID else {
      return Self.protocolErrorResponse(requestID: nil, code: .unsupportedValue)
    }
    guard phase == .running, let generation = activeGeneration?.identifier else {
      return Self.protocolErrorResponse(requestID: requestID, code: .unsupportedValue)
    }
    guard reserveRequest(requestID.rawValue, generation: generation) else {
      return Self.protocolErrorResponse(requestID: requestID, code: .unsupportedValue)
    }
    if let gate {
      pendingMessageGates[requestID.rawValue] = gate
    }

    let response: Data
    do {
      switch command.kind {
      case .getProtocolCapabilities:
        response = try RuntimeMessageCodec.encode(
          RuntimeProtocolCapabilitiesSnapshot(
            requestID: requestID,
            kinds: Self.readOnlyCapabilities
          )
        )
      case .getRuntimeSnapshot:
        guard let snapshot = await lookupSnapshot(generation: generation) else {
          throw ProviderAdapterError.runtimeStartupFailed
        }
        response = try RuntimeMessageCodec.encode(
          RuntimeLifecycleSnapshot(
            requestID: requestID,
            runtimeGeneration: snapshot.lifecycle.runtimeGeneration,
            snapshotSequence: snapshot.lifecycle.snapshotSequence,
            lifecycleState: snapshot.lifecycle.lifecycleState,
            routeState: snapshot.lifecycle.routeState,
            tcp: snapshot.lifecycle.tcp,
            safeDNS: snapshot.lifecycle.safeDNS,
            udp: snapshot.lifecycle.udp,
            routeMode: snapshot.lifecycle.routeMode,
            routesInstalled: snapshot.lifecycle.routesInstalled,
            healthy: snapshot.lifecycle.healthy,
            error: snapshot.lifecycle.error
          )
        )
      case .getCapabilities:
        guard let snapshot = await lookupSnapshot(generation: generation) else {
          throw ProviderAdapterError.runtimeStartupFailed
        }
        response = try RuntimeMessageCodec.encode(
          RuntimeCapabilitySnapshot(
            requestID: requestID,
            runtimeGeneration: snapshot.capabilities.runtimeGeneration,
            snapshotSequence: snapshot.capabilities.snapshotSequence,
            tcp: snapshot.capabilities.tcp,
            safeDNS: snapshot.capabilities.safeDNS,
            udp: snapshot.capabilities.udp,
            routeMode: snapshot.capabilities.routeMode,
            routesInstalled: snapshot.capabilities.routesInstalled,
            healthy: snapshot.capabilities.healthy
          )
        )
      case .getDiagnostics:
        guard
          let diagnostics = await lookupDiagnostics(
            requestID: requestID,
            generation: generation
          )
        else {
          throw ProviderAdapterError.startCancelled
        }
        response = try RuntimeMessageCodec.encode(
          diagnostics
        )
      }
    } catch let error as RuntimeMessageCodecError {
      finishRequest(requestID.rawValue, generation: generation)
      return Self.protocolErrorResponse(requestID: requestID, code: error.protocolErrorCode)
    } catch {
      finishRequest(requestID.rawValue, generation: generation)
      return Self.protocolErrorResponse(requestID: requestID, code: .corruptPayload)
    }

    guard phase == .running, activeGeneration?.identifier == generation else {
      finishRequest(requestID.rawValue, generation: generation)
      return Self.protocolErrorResponse(requestID: requestID, code: .unsupportedValue)
    }
    finishRequest(requestID.rawValue, generation: generation)
    return response
  }

  private func lookupSnapshot(generation: UInt64) async -> TunnelRuntimePublishedSnapshot? {
    guard activeGeneration?.identifier == generation else { return nil }
    guard let signal = activeGeneration?.retirementSignal else { return nil }
    let first = ProviderFirstResult<SnapshotLookupResult>()
    Task { [snapshotSource] in
      first.resolve(.value(await snapshotSource.latestProviderSnapshot()))
    }
    let retirement = Task {
      do {
        try await signal.wait()
        first.resolve(.retired)
      } catch {
        // The source won and removed this retirement subscription.
      }
    }
    let result = await first.wait()
    if case .value = result { retirement.cancel() }
    switch result {
    case .value(let snapshot):
      return snapshot
    case .retired:
      return nil
    }
  }

  private func lookupDiagnostics(
    requestID: OpaqueRuntimeRequestIdentifier,
    generation: UInt64
  ) async -> RuntimeDiagnosticsSnapshot? {
    guard activeGeneration?.identifier == generation else { return nil }
    guard let signal = activeGeneration?.retirementSignal else { return nil }
    let first = ProviderFirstResult<DiagnosticsLookupResult>()
    Task { [diagnosticsSource] in
      do {
        first.resolve(
          .value(
            .success(
              try await diagnosticsSource.providerDiagnosticsSnapshot(requestID: requestID)
            ))
        )
      } catch {
        first.resolve(.value(.failure(.runtimeStartupFailed)))
      }
    }
    let retirement = Task {
      do {
        try await signal.wait()
        first.resolve(.retired)
      } catch {
        // The source won and removed this retirement subscription.
      }
    }
    let result = await first.wait()
    if case .value = result { retirement.cancel() }
    switch result {
    case .value(.success(let snapshot)):
      return snapshot
    case .value(.failure), .retired:
      return nil
    }
  }

  private static let readOnlyCapabilities: [RuntimeKindCapability] = [
    .init(kind: .getProtocolCapabilities, schemaVersions: .currentSchema),
    .init(kind: .getRuntimeSnapshot, schemaVersions: .currentSchema),
    .init(kind: .getCapabilities, schemaVersions: .currentSchema),
    .init(kind: .getDiagnostics, schemaVersions: .currentSchema),
    .init(kind: .protocolCapabilities, schemaVersions: .currentSchema),
    .init(kind: .runtimeSnapshot, schemaVersions: .currentSchema),
    .init(kind: .capabilitySnapshot, schemaVersions: .currentSchema),
    .init(kind: .diagnosticsSnapshot, schemaVersions: .currentSchema),
    .init(kind: .protocolError, schemaVersions: .currentSchema),
  ]

  private static func protocolErrorResponse(
    requestID: OpaqueRuntimeRequestIdentifier?,
    code: RuntimeProtocolErrorCode
  ) -> Data {
    let error = RuntimeProtocolError(requestID: requestID, code: code)
    guard let encoded = try? RuntimeMessageCodec.encode(error) else {
      preconditionFailure("The fixed v1 protocol error must fit its encoded bound")
    }
    return encoded
  }

  private static func protocolCode(for error: ProviderMessageError) -> RuntimeProtocolErrorCode {
    switch error {
    case .unsupportedProtocolVersion:
      .unsupportedProtocolVersion
    case .unsupportedKind:
      .unsupportedKind
    case .invalidPayload(let code):
      code
    }
  }

  private func resetRequestLedger(for generation: UInt64) {
    requestLedgerGeneration = generation
    activeRequestIDs.removeAll(keepingCapacity: true)
    recentRequestIDs.removeAll(keepingCapacity: true)
    recentRequestOrder.removeAll(keepingCapacity: true)
    pendingMessageGates.removeAll(keepingCapacity: true)
  }

  private func retireRequestLedger(generation: UInt64) {
    guard requestLedgerGeneration == generation else { return }
    let pendingGates = pendingMessageGates
    pendingMessageGates.removeAll(keepingCapacity: false)
    for (requestID, gate) in pendingGates {
      gate.complete(
        Self.protocolErrorResponse(
          requestID: OpaqueRuntimeRequestIdentifier(requestID),
          code: .unsupportedValue
        )
      )
    }
    requestLedgerGeneration = nil
    activeRequestIDs.removeAll(keepingCapacity: false)
    recentRequestIDs.removeAll(keepingCapacity: false)
    recentRequestOrder.removeAll(keepingCapacity: false)
  }

  private func reserveRequest(_ requestID: UUID, generation: UInt64) -> Bool {
    guard requestLedgerGeneration == generation,
      activeRequestIDs.count < Self.maximumRememberedRequestIDs,
      !activeRequestIDs.contains(requestID),
      !recentRequestIDs.contains(requestID)
    else { return false }
    activeRequestIDs.insert(requestID)
    return true
  }

  private func finishRequest(_ requestID: UUID, generation: UInt64) {
    guard requestLedgerGeneration == generation, activeRequestIDs.remove(requestID) != nil else {
      return
    }
    pendingMessageGates.removeValue(forKey: requestID)
    recentRequestIDs.insert(requestID)
    recentRequestOrder.append(requestID)
    if recentRequestOrder.count > Self.maximumRememberedRequestIDs {
      let retired = recentRequestOrder.removeFirst()
      recentRequestIDs.remove(retired)
    }
  }

  public func lifecyclePhase() async -> ProviderLifecyclePhase {
    phase
  }
}
