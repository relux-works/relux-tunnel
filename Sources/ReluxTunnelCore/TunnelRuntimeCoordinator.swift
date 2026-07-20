import Foundation

public enum TunnelRuntimeStartupPhase: String, Equatable, Sendable {
  case configuration
  case sshAuthentication
  case consumers
  case networkSettings
  case packetReads
}

public enum TunnelRuntimeCoordinatorState: Equatable, Sendable {
  case disconnected
  case starting(TunnelRuntimeStartupPhase)
  case usableTCPDNS
  case stopping
  case failed
}

public enum TunnelRuntimeMandatoryComponent: String, CaseIterable, Equatable, Sendable {
  case ssh
  case tcp
  case dns
  case packetPlane
}

public enum TunnelRuntimeComponentHealth: Equatable, Sendable {
  case healthy
  case unhealthy
}

public struct TunnelRuntimeHealthEvent: Equatable, Sendable {
  public let runtimeGeneration: UInt64
  public let component: TunnelRuntimeMandatoryComponent
  public let health: TunnelRuntimeComponentHealth

  public init(
    runtimeGeneration: UInt64,
    component: TunnelRuntimeMandatoryComponent,
    health: TunnelRuntimeComponentHealth
  ) {
    self.runtimeGeneration = runtimeGeneration
    self.component = component
    self.health = health
  }
}

public protocol TunnelRuntimeHealthEventSink: AnyObject, Sendable {
  func receive(_ event: TunnelRuntimeHealthEvent) async
}

public protocol TunnelRuntimeHealthProviding: AnyObject, Sendable {
  func health() async -> TunnelRuntimeComponentHealth
}

public protocol ConfigurationSnapshotSource: Sendable {
  func loadValidatedSnapshot(
    for reference: TunnelConfigurationReference
  ) async throws -> RuntimeConfigurationSnapshot
}

public protocol SSHBootstrapSession: TunnelRuntimeHealthProviding {
  var connectedEndpoint: TunnelEndpoint { get }
  func close() async
}

public protocol SSHBootstrap: Sendable {
  func authenticate(
    configuration: RuntimeConfigurationSnapshot,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any SSHBootstrapSession
}

public protocol TCPConsumer: TunnelRuntimeHealthProviding {
  func closeAdmission() async
  func stop() async
}

public protocol TCPConsumerFactory: Sendable {
  func prepare(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any TCPConsumer
}

public protocol DNSConsumer: TunnelRuntimeHealthProviding {
  func closeAdmission() async
  func stop() async
}

public protocol DNSConsumerFactory: Sendable {
  /// Returns only after safe DNS is ready with an SSH-only upstream.
  func prepareSafeDNS(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any DNSConsumer
}

public protocol M1PacketPlaneSession: TunnelRuntimeHealthProviding {
  /// Activates the private packet plane and returns only after packet reads are registered.
  func activateReads(packetFlow: any PacketFlow) async throws

  /// Stops reads, bridge pumps, native work, sockets, and private admission.
  func stop() async
}

public protocol M1PacketPlaneFactory: Sendable {
  /// Performs preparation without acquiring packet reads or native runtime resources.
  func prepare(
    configuration: RuntimeConfigurationSnapshot,
    tcp: any TCPConsumer,
    dns: any DNSConsumer,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any M1PacketPlaneSession
}

public protocol NetworkSettingsPlan: Sendable {}

public protocol NetworkSettingsPlanBuilder: Sendable {
  func makePlan(
    configuration: RuntimeConfigurationSnapshot,
    connectedEndpoint: TunnelEndpoint,
    runtimeGeneration: UInt64
  ) throws -> any NetworkSettingsPlan
}

public enum NetworkSettingsCommitDisposition: Equatable, Sendable {
  case notCommitted
  case committed
  case uncertain
}

/// Apply errors can provide a definitive commit disposition. Unknown errors are
/// conservatively treated as uncertain and require a clear request.
public protocol NetworkSettingsCommitDescribingError: Error, Sendable {
  var commitDisposition: NetworkSettingsCommitDisposition { get }
}

public protocol NetworkSettingsApplier: Sendable {
  func apply(
    _ plan: any NetworkSettingsPlan,
    runtimeGeneration: UInt64
  ) async throws

  func clear(runtimeGeneration: UInt64) async throws
}

public struct TunnelRuntimePublishedSnapshot: Equatable, Sendable {
  public let lifecycle: RuntimeLifecycleSnapshot
  public let capabilities: RuntimeCapabilitySnapshot

  public init(
    lifecycle: RuntimeLifecycleSnapshot,
    capabilities: RuntimeCapabilitySnapshot
  ) {
    precondition(lifecycle.position == capabilities.position)
    self.lifecycle = lifecycle
    self.capabilities = capabilities
  }

  public var position: RuntimeSnapshotPosition {
    lifecycle.position
  }
}

public protocol RuntimeSnapshotStore: Sendable {
  func publish(_ snapshot: TunnelRuntimePublishedSnapshot) async
}

/// Provider-instance snapshot authority. Older generations and repeated or
/// out-of-order sequence values cannot replace the active immutable snapshot.
public actor LatestRuntimeSnapshotStore: RuntimeSnapshotStore {
  private var latestSnapshot: TunnelRuntimePublishedSnapshot?

  public init() {}

  public func publish(_ snapshot: TunnelRuntimePublishedSnapshot) {
    guard snapshot.position.isNewer(than: latestSnapshot?.position) else {
      return
    }
    latestSnapshot = snapshot
  }

  public func latest() -> TunnelRuntimePublishedSnapshot? {
    latestSnapshot
  }
}

extension LatestRuntimeSnapshotStore: ProviderRuntimeSnapshotSource {
  public func latestProviderSnapshot() -> TunnelRuntimePublishedSnapshot? {
    latestSnapshot
  }
}

public struct TunnelRuntimeCoordinatorDependencies: Sendable {
  public let configurationSource: any ConfigurationSnapshotSource
  public let sshBootstrap: any SSHBootstrap
  public let tcpFactory: any TCPConsumerFactory
  public let dnsFactory: any DNSConsumerFactory
  public let packetPlaneFactory: any M1PacketPlaneFactory
  public let settingsPlanBuilder: any NetworkSettingsPlanBuilder
  public let settingsApplier: any NetworkSettingsApplier
  public let snapshotStore: any RuntimeSnapshotStore

  public init(
    configurationSource: any ConfigurationSnapshotSource,
    sshBootstrap: any SSHBootstrap,
    tcpFactory: any TCPConsumerFactory,
    dnsFactory: any DNSConsumerFactory,
    packetPlaneFactory: any M1PacketPlaneFactory,
    settingsPlanBuilder: any NetworkSettingsPlanBuilder,
    settingsApplier: any NetworkSettingsApplier,
    snapshotStore: any RuntimeSnapshotStore
  ) {
    self.configurationSource = configurationSource
    self.sshBootstrap = sshBootstrap
    self.tcpFactory = tcpFactory
    self.dnsFactory = dnsFactory
    self.packetPlaneFactory = packetPlaneFactory
    self.settingsPlanBuilder = settingsPlanBuilder
    self.settingsApplier = settingsApplier
    self.snapshotStore = snapshotStore
  }
}

public enum TunnelRuntimeCoordinatorError: Error, Equatable, Sendable {
  case generationAlreadyConsumed
  case generationExhausted
  case startupFailed(RedactedRuntimeError)
}

struct TunnelRuntimeCoordinatorResourceFootprint: Equatable, Sendable {
  let retainsConfigurationReference: Bool
  let retainsConfigurationSnapshot: Bool
  let retainsSSHSession: Bool
  let retainsTCPConsumer: Bool
  let retainsDNSConsumer: Bool
  let retainsPacketPlane: Bool
  let settingsRequireClear: Bool
  let retainsStartupTask: Bool
  let retainsCleanupTask: Bool
}

/// Creates exactly one coordinator object for each monotonically increasing
/// provider runtime generation.
public actor TunnelRuntimeCoordinatorFactory: TunnelRuntimeFactory {
  private let coordinatorDependencies: TunnelRuntimeCoordinatorDependencies
  private var latestGeneration: UInt64

  public init(
    dependencies: TunnelRuntimeCoordinatorDependencies,
    initialGeneration: UInt64 = 0
  ) {
    coordinatorDependencies = dependencies
    latestGeneration = initialGeneration
  }

  public func makeRuntime(context: TunnelRuntimeContext) throws -> any TunnelRuntime {
    guard latestGeneration < UInt64.max else {
      throw TunnelRuntimeCoordinatorError.generationExhausted
    }
    latestGeneration += 1
    return TunnelRuntimeCoordinator(
      runtimeGeneration: latestGeneration,
      context: context,
      dependencies: coordinatorDependencies
    )
  }
}

/// Extension-owned, single-generation M1 lifecycle coordinator.
///
/// The actor is the sole writer of lifecycle state and retained resources. Its
/// tracked startup task is cancelled by stop, and every acquired resource is
/// retained before the next cancellation check so cleanup cannot miss a late
/// acquisition.
public actor TunnelRuntimeCoordinator: TunnelRuntime, TunnelRuntimeHealthEventSink {
  public nonisolated let runtimeGeneration: UInt64

  private enum Termination {
    case cancelled
    case stopped(ProviderStopReason)
    case failed(RedactedRuntimeError)
  }

  private enum SettingsState {
    case notRequested
    case uncertain
    case committed
    case clearFailed

    var requiresClear: Bool {
      switch self {
      case .uncertain, .committed, .clearFailed:
        true
      case .notRequested:
        false
      }
    }

    var routesInstalled: Bool {
      switch self {
      case .uncertain, .committed, .clearFailed:
        true
      case .notRequested:
        false
      }
    }
  }

  private let packetFlow: any PacketFlow
  private let environment: TunnelRuntimeDependencies
  private let dependencies: TunnelRuntimeCoordinatorDependencies
  private let cleanupRegistry: ProviderCleanupRegistry
  private let startupCompletionHandoffHook: (@Sendable (TunnelRuntimeCoordinator) async -> Void)?

  private var configurationReference: TunnelConfigurationReference?
  private var configurationSnapshot: RuntimeConfigurationSnapshot?
  private var sshSession: (any SSHBootstrapSession)?
  private var tcpConsumer: (any TCPConsumer)?
  private var dnsConsumer: (any DNSConsumer)?
  private var packetPlane: (any M1PacketPlaneSession)?
  private var settingsState = SettingsState.notRequested

  private var state = TunnelRuntimeCoordinatorState.disconnected
  private var termination: Termination?
  private var primaryFailure: RedactedRuntimeError?
  private var nextSnapshotSequence: UInt64? = 0
  private var lastSnapshot: TunnelRuntimePublishedSnapshot?
  private var startupTask: Task<Void, Error>?
  private var cleanupTask: Task<Void, Never>?
  private var generationConsumed = false

  public init(
    runtimeGeneration: UInt64,
    context: TunnelRuntimeContext,
    dependencies: TunnelRuntimeCoordinatorDependencies
  ) {
    self.runtimeGeneration = runtimeGeneration
    packetFlow = context.packetFlow
    environment = context.dependencies
    cleanupRegistry = context.cleanupRegistry
    configurationReference = context.configuration.profileReference
    self.dependencies = dependencies
    startupCompletionHandoffHook = nil
  }

  internal init(
    runtimeGeneration: UInt64,
    context: TunnelRuntimeContext,
    dependencies: TunnelRuntimeCoordinatorDependencies,
    startupCompletionHandoffHook:
      (@Sendable (TunnelRuntimeCoordinator) async -> Void)?
  ) {
    self.runtimeGeneration = runtimeGeneration
    packetFlow = context.packetFlow
    environment = context.dependencies
    cleanupRegistry = context.cleanupRegistry
    configurationReference = context.configuration.profileReference
    self.dependencies = dependencies
    self.startupCompletionHandoffHook = startupCompletionHandoffHook
  }

  public func start() async throws {
    guard !generationConsumed else {
      throw TunnelRuntimeCoordinatorError.generationAlreadyConsumed
    }
    generationConsumed = true
    state = .starting(.configuration)

    let operation = Task { [weak self] in
      guard let self else { throw CancellationError() }
      try await self.runStartup()
    }
    startupTask = operation

    do {
      try await withTaskCancellationHandler {
        await publishCurrentState()
        try await operation.value
      } onCancel: {
        operation.cancel()
      }
      await startupCompletionHandoffHook?(self)
      try checkCancellationAndOwnership(allowUsable: true)
      startupTask = nil
    } catch {
      startupTask = nil
      let thrownError = classifyStartupError(error)
      await joinCleanup()
      throw thrownError
    }
  }

  public func stop(reason: ProviderStopReason) async {
    if state == .failed {
      if let cleanupTask {
        await cleanupTask.value
      }
      return
    }

    if state == .disconnected {
      if let cleanupTask {
        await cleanupTask.value
        return
      }
      guard !generationConsumed else { return }
      generationConsumed = true
      recordTermination(for: reason)
      state = .stopping
      await publishCurrentState()
      await joinCleanup()
      return
    }

    recordTermination(for: reason)

    let operation = startupTask
    operation?.cancel()
    await transitionToStopping()
    if let operation {
      _ = await operation.result
    }
    await joinCleanup()
  }

  private func recordTermination(for reason: ProviderStopReason) {
    guard termination == nil else { return }
    switch reason {
    case .startupFailure:
      setFailure(Self.error(domain: .runtimeInvariant, code: "startup_failed"))
    case .providerFailure:
      setFailure(Self.error(domain: .runtimeInvariant, code: "provider_failure"))
    case .userInitiated, .system, .platform:
      termination = .stopped(reason)
    }
  }

  public func lifecycleState() -> TunnelLifecycleState {
    switch state {
    case .disconnected:
      .disconnected
    case .starting:
      .connecting
    case .usableTCPDNS:
      .connectedDegraded
    case .stopping:
      .disconnecting
    case .failed:
      .failed
    }
  }

  public func coordinatorState() -> TunnelRuntimeCoordinatorState {
    state
  }

  public func latestSnapshot() -> TunnelRuntimePublishedSnapshot? {
    lastSnapshot
  }

  func resourceFootprint() -> TunnelRuntimeCoordinatorResourceFootprint {
    TunnelRuntimeCoordinatorResourceFootprint(
      retainsConfigurationReference: configurationReference != nil,
      retainsConfigurationSnapshot: configurationSnapshot != nil,
      retainsSSHSession: sshSession != nil,
      retainsTCPConsumer: tcpConsumer != nil,
      retainsDNSConsumer: dnsConsumer != nil,
      retainsPacketPlane: packetPlane != nil,
      settingsRequireClear: settingsState.requiresClear,
      retainsStartupTask: startupTask != nil,
      retainsCleanupTask: cleanupTask != nil
    )
  }

  public func receive(_ event: TunnelRuntimeHealthEvent) async {
    guard event.runtimeGeneration == runtimeGeneration else { return }
    guard event.health == .unhealthy else { return }
    guard state != .disconnected, state != .stopping, state != .failed else { return }

    setFailure(Self.healthFailure(for: event.component))
    startupTask?.cancel()
    await transitionToStopping()

    // A startup owner joins cleanup after its in-flight acquisition settles.
    // Once usable, no acquisition is in flight and cleanup can begin now.
    if startupTask == nil {
      _ = beginCleanup()
    }
  }

  private func runStartup() async throws {
    try checkCancellationAndOwnership()
    guard let reference = configurationReference else {
      throw TunnelRuntimeCoordinatorError.startupFailed(
        Self.error(domain: .configuration, code: "configuration_invalid")
      )
    }

    configurationSnapshot = try await mapped(
      fallback: Self.error(domain: .configuration, code: "configuration_invalid")
    ) {
      try await dependencies.configurationSource.loadValidatedSnapshot(for: reference)
    }
    try checkCancellationAndOwnership()
    guard configurationSnapshot?.profileIdentifier == reference.profileIdentifier,
      configurationSnapshot?.routeMode == .compatible
    else {
      throw TunnelRuntimeCoordinatorError.startupFailed(
        Self.error(domain: .configuration, code: "configuration_invalid")
      )
    }

    try await transitionDuringStartup(to: .sshAuthentication)
    guard let configurationSnapshot else {
      throw TunnelRuntimeCoordinatorError.startupFailed(
        Self.error(domain: .runtimeInvariant, code: "resource_missing")
      )
    }
    sshSession = try await mapped(
      fallback: Self.error(domain: .sshTransport, code: "ssh_session_lost")
    ) {
      try await dependencies.sshBootstrap.authenticate(
        configuration: configurationSnapshot,
        runtimeGeneration: runtimeGeneration,
        healthSink: self
      )
    }
    registerCleanupControl(sshSession)
    try checkCancellationAndOwnership()

    try await transitionDuringStartup(to: .consumers)
    guard let sshSession else {
      throw TunnelRuntimeCoordinatorError.startupFailed(
        Self.error(domain: .runtimeInvariant, code: "resource_missing")
      )
    }
    tcpConsumer = try await mapped(
      fallback: Self.error(domain: .tcp, code: "tcp_flow_failed")
    ) {
      try await dependencies.tcpFactory.prepare(
        session: sshSession,
        runtimeGeneration: runtimeGeneration,
        healthSink: self
      )
    }
    registerCleanupControl(tcpConsumer)
    try checkCancellationAndOwnership()

    dnsConsumer = try await mapped(
      fallback: Self.error(domain: .dns, code: "dns_upstream_timeout")
    ) {
      try await dependencies.dnsFactory.prepareSafeDNS(
        session: sshSession,
        runtimeGeneration: runtimeGeneration,
        healthSink: self
      )
    }
    registerCleanupControl(dnsConsumer)
    try checkCancellationAndOwnership()

    guard let tcpConsumer, let dnsConsumer else {
      throw TunnelRuntimeCoordinatorError.startupFailed(
        Self.error(domain: .runtimeInvariant, code: "resource_missing")
      )
    }
    packetPlane = try await mapped(
      fallback: Self.error(domain: .packetPlane, code: "packet_plane_failed")
    ) {
      try await dependencies.packetPlaneFactory.prepare(
        configuration: configurationSnapshot,
        tcp: tcpConsumer,
        dns: dnsConsumer,
        runtimeGeneration: runtimeGeneration,
        healthSink: self
      )
    }
    registerCleanupControl(packetPlane)
    try checkCancellationAndOwnership()
    try await requireMandatoryHealth()

    let settingsPlan: any NetworkSettingsPlan
    do {
      settingsPlan = try dependencies.settingsPlanBuilder.makePlan(
        configuration: configurationSnapshot,
        connectedEndpoint: sshSession.connectedEndpoint,
        runtimeGeneration: runtimeGeneration
      )
    } catch {
      throw map(error, fallback: Self.error(domain: .networkSettings, code: "settings_invalid"))
    }

    try await transitionDuringStartup(to: .networkSettings)
    settingsState = .uncertain
    do {
      try await dependencies.settingsApplier.apply(
        settingsPlan,
        runtimeGeneration: runtimeGeneration
      )
      settingsState = .committed
    } catch {
      if let described = error as? any NetworkSettingsCommitDescribingError {
        switch described.commitDisposition {
        case .notCommitted:
          settingsState = .notRequested
        case .committed:
          settingsState = .committed
        case .uncertain:
          settingsState = .uncertain
        }
      }
      throw map(
        error,
        fallback: Self.error(domain: .networkSettings, code: "network_settings_apply_failed")
      )
    }
    try checkCancellationAndOwnership()

    try await transitionDuringStartup(to: .packetReads)
    guard let packetPlane else {
      throw TunnelRuntimeCoordinatorError.startupFailed(
        Self.error(domain: .runtimeInvariant, code: "resource_missing")
      )
    }
    do {
      try await packetPlane.activateReads(packetFlow: packetFlow)
    } catch {
      throw map(
        error,
        fallback: Self.error(domain: .packetPlane, code: "packet_plane_failed")
      )
    }
    try checkCancellationAndOwnership()
    try await requireMandatoryHealth()
    try checkCancellationAndOwnership()

    state = .usableTCPDNS
    await publishCurrentState()
    try checkCancellationAndOwnership(allowUsable: true)
  }

  private func transitionDuringStartup(to phase: TunnelRuntimeStartupPhase) async throws {
    try checkCancellationAndOwnership()
    state = .starting(phase)
    await publishCurrentState()
    try checkCancellationAndOwnership()
  }

  private func requireMandatoryHealth() async throws {
    let checks: [(TunnelRuntimeMandatoryComponent, any TunnelRuntimeHealthProviding)] = [
      (.ssh, requireResource(sshSession)),
      (.tcp, requireResource(tcpConsumer)),
      (.dns, requireResource(dnsConsumer)),
      (.packetPlane, requireResource(packetPlane)),
    ]
    for (component, provider) in checks {
      let health = await provider.health()
      try checkCancellationAndOwnership()
      guard health == .healthy else {
        throw TunnelRuntimeCoordinatorError.startupFailed(Self.healthFailure(for: component))
      }
    }
  }

  private func requireResource<T>(_ resource: T?) -> T {
    guard let resource else {
      preconditionFailure("Coordinator health check requested before acquisition")
    }
    return resource
  }

  private func registerCleanupControl<T>(_ resource: T?) {
    guard let controllable = resource as? any ProviderCleanupControllable else { return }
    cleanupRegistry.register(controllable)
  }

  private func mapped<T>(
    fallback: RedactedRuntimeError,
    operation: () async throws -> T
  ) async throws -> T {
    try checkCancellationAndOwnership()
    do {
      return try await operation()
    } catch {
      throw map(error, fallback: fallback)
    }
  }

  private func map(_ error: any Error, fallback: RedactedRuntimeError) -> any Error {
    if error is CancellationError {
      return CancellationError()
    }
    if let error = error as? TunnelRuntimeCoordinatorError {
      return error
    }
    return TunnelRuntimeCoordinatorError.startupFailed(fallback)
  }

  private func checkCancellationAndOwnership(allowUsable: Bool = false) throws {
    try Task<Never, Never>.checkCancellation()
    try environment.cancellation.checkCancellation()
    let isOwnedState: Bool
    switch state {
    case .starting:
      isOwnedState = true
    case .usableTCPDNS:
      isOwnedState = allowUsable
    case .disconnected, .stopping, .failed:
      isOwnedState = false
    }
    guard isOwnedState, termination == nil else {
      throw CancellationError()
    }
  }

  private func classifyStartupError(_ error: any Error) -> any Error {
    if error is CancellationError {
      if case .failed(let failure) = termination {
        return TunnelRuntimeCoordinatorError.startupFailed(failure)
      }
      if termination == nil {
        termination = .cancelled
      }
      return CancellationError()
    }
    if case .startupFailed(let failure) = error as? TunnelRuntimeCoordinatorError {
      setFailure(failure)
      return error
    }
    let fallback = Self.error(domain: .runtimeInvariant, code: "startup_failed")
    setFailure(fallback)
    return TunnelRuntimeCoordinatorError.startupFailed(fallback)
  }

  private func setFailure(_ failure: RedactedRuntimeError) {
    if primaryFailure == nil {
      primaryFailure = failure
    }
    if termination == nil {
      termination = .failed(failure)
    }
  }

  private func transitionToStopping() async {
    guard state != .stopping, state != .disconnected, state != .failed else { return }
    state = .stopping
    await publishCurrentState()
  }

  @discardableResult
  private func beginCleanup() -> Task<Void, Never> {
    if let cleanupTask {
      return cleanupTask
    }
    let task = Task { [weak self] in
      guard let self else { return }
      await self.performCleanup()
    }
    cleanupTask = task
    return task
  }

  private func joinCleanup() async {
    if let cleanupTask {
      await cleanupTask.value
      return
    }
    guard state != .disconnected, state != .failed else { return }
    if state != .stopping {
      await transitionToStopping()
    }
    let task = beginCleanup()
    await task.value
  }

  private func performCleanup() async {
    await tcpConsumer?.closeAdmission()
    await dnsConsumer?.closeAdmission()

    if let packetPlane {
      await packetPlane.stop()
      self.packetPlane = nil
    }

    if settingsState.requiresClear {
      do {
        try await dependencies.settingsApplier.clear(runtimeGeneration: runtimeGeneration)
        settingsState = .notRequested
      } catch {
        settingsState = .clearFailed
        let clearFailure = Self.error(
          domain: .networkSettings,
          code: "network_settings_clear_failed"
        )
        if primaryFailure == nil {
          primaryFailure = clearFailure
        }
      }
    }

    if let dnsConsumer {
      await dnsConsumer.stop()
      self.dnsConsumer = nil
    }
    if let tcpConsumer {
      await tcpConsumer.stop()
      self.tcpConsumer = nil
    }
    if let sshSession {
      await sshSession.close()
      self.sshSession = nil
    }

    configurationSnapshot = nil
    configurationReference = nil
    startupTask = nil

    if settingsState == .clearFailed || isFailureTermination {
      state = .failed
    } else {
      state = .disconnected
      primaryFailure = nil
    }
    await publishCurrentState()
    cleanupTask = nil
  }

  private var isFailureTermination: Bool {
    switch termination {
    case .failed:
      true
    case .cancelled, .stopped, nil:
      false
    }
  }

  private func publishCurrentState() async {
    guard let sequence = nextSnapshotSequence else { return }
    nextSnapshotSequence = sequence == UInt64.max ? nil : sequence + 1

    let lifecycleState = lifecycleState()
    let routesInstalled = settingsState.routesInstalled
    let routeState: RuntimeRouteState
    switch settingsState {
    case .notRequested:
      routeState = .notInstalled
    case .uncertain, .committed:
      routeState = .installed
    case .clearFailed:
      routeState = .clearFailed
    }
    let usable = state == .usableTCPDNS
    let healthy = usable
    let error = state == .failed ? primaryFailure : nil

    let lifecycle = RuntimeLifecycleSnapshot(
      runtimeGeneration: runtimeGeneration,
      snapshotSequence: sequence,
      lifecycleState: lifecycleState,
      routeState: routeState,
      tcp: usable,
      safeDNS: usable,
      udp: false,
      routeMode: .compatible,
      routesInstalled: routesInstalled,
      healthy: healthy,
      error: error
    )
    let capabilities = RuntimeCapabilitySnapshot(
      runtimeGeneration: runtimeGeneration,
      snapshotSequence: sequence,
      tcp: usable,
      safeDNS: usable,
      udp: false,
      routeMode: .compatible,
      routesInstalled: routesInstalled,
      healthy: healthy
    )
    let snapshot = TunnelRuntimePublishedSnapshot(
      lifecycle: lifecycle,
      capabilities: capabilities
    )
    lastSnapshot = snapshot
    await dependencies.snapshotStore.publish(snapshot)
  }

  private static func healthFailure(
    for component: TunnelRuntimeMandatoryComponent
  ) -> RedactedRuntimeError {
    switch component {
    case .ssh:
      error(domain: .sshTransport, code: "ssh_session_lost")
    case .tcp:
      error(domain: .tcp, code: "tcp_flow_failed")
    case .dns:
      error(domain: .dns, code: "dns_upstream_timeout")
    case .packetPlane:
      error(domain: .packetPlane, code: "packet_plane_failed")
    }
  }

  private static func error(
    domain: RuntimeErrorDomain,
    code: String
  ) -> RedactedRuntimeError {
    guard let code = try? RedactedRuntimeErrorCode(code) else {
      preconditionFailure("Coordinator error catalog contains an invalid token")
    }
    return RedactedRuntimeError(domain: domain, code: code)
  }
}
