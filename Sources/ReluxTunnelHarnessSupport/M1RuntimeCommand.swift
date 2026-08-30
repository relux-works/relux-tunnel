import Darwin
import Foundation
import ReluxTunnelCore

public enum M1RuntimeHarnessScenario: String, CaseIterable, Sendable {
  case success
  case authenticationFailure = "authentication-failure"
  case packetFailure = "packet-failure"
  case dnsFailure = "dns-failure"
  case routeApplyFailure = "route-apply-failure"
  case midSessionSSHFailure = "mid-session-ssh-failure"
  case midSessionDNSFailure = "mid-session-dns-failure"

  fileprivate var isStartupFailure: Bool {
    switch self {
    case .authenticationFailure, .packetFailure, .dnsFailure, .routeApplyFailure:
      true
    case .success, .midSessionSSHFailure, .midSessionDNSFailure:
      false
    }
  }

  fileprivate var exitCode: HarnessExitCode {
    switch self {
    case .success:
      .success
    case .authenticationFailure:
      .m1AuthenticationFailure
    case .packetFailure:
      .m1PacketFailure
    case .dnsFailure:
      .m1DNSFailure
    case .routeApplyFailure:
      .m1RouteApplyFailure
    case .midSessionSSHFailure, .midSessionDNSFailure:
      .m1MandatoryFailure
    }
  }
}

public enum M1RuntimeHarnessError: Error, Equatable, CustomStringConvertible,
  HarnessExitCodeProvidingError
{
  case invalidFixture
  case unsupportedScenario
  case invalidRepetitionCount
  case faultScenarioMustRunOnce
  case sensitiveControlParameter
  case profileReferenceMustBeSensitive
  case missingDependencyRevision
  case injected(M1RuntimeHarnessScenario)
  case injectionNotObserved
  case runtimeInvariant
  case trafficInvariant
  case diagnosticsInvariant
  case resourceGrowth
  case privacyInvariant
  case hostLifetimeInvariant

  public var harnessExitCode: HarnessExitCode {
    switch self {
    case .unsupportedScenario, .invalidRepetitionCount, .faultScenarioMustRunOnce,
      .sensitiveControlParameter, .profileReferenceMustBeSensitive,
      .missingDependencyRevision, .invalidFixture:
      .usage
    case .injected(let scenario):
      scenario.exitCode
    case .injectionNotObserved, .runtimeInvariant, .trafficInvariant,
      .diagnosticsInvariant, .resourceGrowth, .privacyInvariant,
      .hostLifetimeInvariant:
      .failure
    }
  }

  public var description: String {
    switch self {
    case .invalidFixture:
      "m1-runtime invalid fixture"
    case .unsupportedScenario:
      "m1-runtime unsupported scenario"
    case .invalidRepetitionCount:
      "m1-runtime repetitions must be in 1...8"
    case .faultScenarioMustRunOnce:
      "m1-runtime failure scenarios require repetitions=1"
    case .sensitiveControlParameter:
      "m1-runtime control parameters must be public"
    case .profileReferenceMustBeSensitive:
      "m1-runtime profile reference must be sensitive"
    case .missingDependencyRevision:
      "m1-runtime required dependency revision is missing"
    case .injected(let scenario):
      "m1-runtime injected \(scenario.rawValue)"
    case .injectionNotObserved:
      "m1-runtime configured injection was not observed"
    case .runtimeInvariant:
      "m1-runtime lifecycle invariant failed"
    case .trafficInvariant:
      "m1-runtime traffic invariant failed"
    case .diagnosticsInvariant:
      "m1-runtime diagnostics invariant failed"
    case .resourceGrowth:
      "m1-runtime resource growth detected"
    case .privacyInvariant:
      "m1-runtime privacy invariant failed"
    case .hostLifetimeInvariant:
      "m1-runtime retained simulated host owner"
    }
  }
}

public struct M1RuntimeHarnessCommand: HarnessCommand {
  public static let maximumRepetitions = 8
  public let name = "m1-runtime"

  public init() {}

  public func run(context: HarnessCommandContext) async throws {
    let fixture = try M1HarnessFixture(configuration: context.configuration)
    let sessionFactory = DeterministicHarnessSessionFactory { runtimeContext, generation in
      guard let packetFlow = runtimeContext.packetFlow as? M1HarnessPacketFlow else {
        throw M1RuntimeHarnessError.runtimeInvariant
      }
      let generationFixture = M1HarnessGeneration(
        scenario: fixture.scenario,
        generation: generation,
        profileIdentifier: runtimeContext.configuration.profileReference.profileIdentifier,
        packetFlow: packetFlow,
        environment: runtimeContext.dependencies
      )
      fixture.registry.insert(generationFixture)
      return generationFixture.dependencies()
    }
    for expectedGeneration in 1...fixture.repetitions {
      var hostOwner: M1HarnessHostOwner? = M1HarnessHostOwner(
        dependencies: context.dependencies,
        sessionFactory: sessionFactory
      )
      weak let weakHostOwner = hostOwner

      let runtime = try await hostOwner!.makeRuntime(
        configuration: try context.configuration.tunnelConfiguration(),
      )
      guard
        let coordinator = runtime as? TunnelRuntimeCoordinator,
        coordinator.runtimeGeneration == UInt64(expectedGeneration),
        let generationFixture = fixture.registry.generation(UInt64(expectedGeneration))
      else {
        throw M1RuntimeHarnessError.runtimeInvariant
      }

      do {
        try await runtime.start()
      } catch {
        guard fixture.scenario.isStartupFailure,
          generationFixture.injectionWasObserved()
        else {
          throw error
        }
        try await generationFixture.verifyAfterStop(runtime: runtime)
        throw M1RuntimeHarnessError.injected(fixture.scenario)
      }

      guard !fixture.scenario.isStartupFailure else {
        await runtime.stop(reason: .startupFailure)
        throw M1RuntimeHarnessError.injectionNotObserved
      }
      try await generationFixture.verifyReady(runtime: runtime)

      hostOwner = nil
      guard weakHostOwner == nil else {
        await runtime.stop(reason: .providerFailure)
        throw M1RuntimeHarnessError.hostLifetimeInvariant
      }

      try await generationFixture.exchangeRepresentativeTraffic()
      try generationFixture.requestAndVerifyDiagnostics()

      switch fixture.scenario {
      case .midSessionSSHFailure, .midSessionDNSFailure:
        try await generationFixture.injectMandatoryLoss()
        try await generationFixture.awaitMandatoryFailure(runtime: runtime)
        await runtime.stop(reason: .providerFailure)
        try await generationFixture.verifyAfterStop(runtime: runtime)
        throw M1RuntimeHarnessError.injected(fixture.scenario)
      case .success:
        await runtime.stop(reason: .userInitiated)
        try await generationFixture.verifyAfterStop(runtime: runtime)
      case .authenticationFailure, .packetFailure, .dnsFailure, .routeApplyFailure:
        throw M1RuntimeHarnessError.injectionNotObserved
      }
    }

    let metrics = context.dependencies.runtime.metrics
    await metrics.incrementCounter(
      named: "harness.m1.generations_total",
      by: UInt64(fixture.repetitions)
    )
    await metrics.incrementCounter(
      named: "harness.m1.tcp_fixture_exchanges_total",
      by: UInt64(fixture.repetitions)
    )
    await metrics.incrementCounter(
      named: "harness.m1.dns_fixture_exchanges_total",
      by: UInt64(fixture.repetitions)
    )
    for resource in ["descriptor", "task", "channel", "socket", "native_runtime"] {
      await metrics.setGauge(named: "harness.m1.\(resource)_growth", to: 0)
    }
    await metrics.setGauge(named: "harness.m1.host_owner_retained", to: 0)
  }
}

public struct M1RuntimeHarnessPacketEndpointFactory: HarnessPacketEndpointFactory {
  public init() {}

  public func makePacketFlow() async throws -> any PacketFlow {
    M1HarnessPacketFlow()
  }
}

private let m1DNSFixtureEndpoint = TunnelEndpoint(host: "192.0.2.53", port: 53)
private let m1TCPFixtureEndpoint = TunnelEndpoint(host: "198.51.100.80", port: 443)
private let m1OriginatorFixtureEndpoint = TunnelEndpoint(host: "192.0.2.2", port: 49_152)
private let m1TCPRequest = Data("GET /fixture HTTP/1.0\r\n\r\n".utf8)
private let m1TCPResponse = Data("HTTP/1.0 204 Fixture\r\n\r\n".utf8)
private let m1DNSQuery = Data([0x12, 0x34, 0x01, 0x00])
private let m1DNSResponse = Data([0x12, 0x34, 0x81, 0x80])

/// Simulates the containing host's ownership of the composition/bootstrap
/// boundary. The returned runtime must retain everything needed for forwarding
/// because this owner is released immediately after readiness.
private final class M1HarnessHostOwner {
  private let composition: HarnessCoreComposition
  private let sessionFactory: DeterministicHarnessSessionFactory

  init(
    dependencies: HarnessCommandDependencies,
    sessionFactory: DeterministicHarnessSessionFactory
  ) {
    composition = HarnessCoreComposition(dependencies: dependencies)
    self.sessionFactory = sessionFactory
  }

  func makeRuntime(
    configuration: TunnelConfiguration
  ) async throws -> any TunnelRuntime {
    try await composition.makeRuntime(
      configuration: configuration,
      factory: sessionFactory
    )
  }
}

private struct M1HarnessFixture {
  static let requiredDependencyRevisions = [
    "fixture-manifest", "packet-bridge", "runtime-contract",
  ]

  let scenario: M1RuntimeHarnessScenario
  let repetitions: Int
  let registry = M1HarnessGenerationRegistry()

  init(configuration: HarnessConfigurationDocument) throws {
    guard configuration.profileReference.privacy == .sensitive else {
      throw M1RuntimeHarnessError.profileReferenceMustBeSensitive
    }
    guard
      let scenarioValue = configuration.parameters["scenario"],
      let repetitionsValue = configuration.parameters["repetitions"]
    else {
      throw M1RuntimeHarnessError.invalidFixture
    }
    guard scenarioValue.privacy == .public, repetitionsValue.privacy == .public else {
      throw M1RuntimeHarnessError.sensitiveControlParameter
    }
    guard let scenario = M1RuntimeHarnessScenario(rawValue: scenarioValue.value) else {
      throw M1RuntimeHarnessError.unsupportedScenario
    }
    guard let repetitions = Int(repetitionsValue.value),
      (1...M1RuntimeHarnessCommand.maximumRepetitions).contains(repetitions)
    else {
      throw M1RuntimeHarnessError.invalidRepetitionCount
    }
    guard scenario == .success || repetitions == 1 else {
      throw M1RuntimeHarnessError.faultScenarioMustRunOnce
    }
    guard
      Self.requiredDependencyRevisions.allSatisfy({
        configuration.dependencyRevisions[$0]?.isEmpty == false
      })
    else {
      throw M1RuntimeHarnessError.missingDependencyRevision
    }
    self.scenario = scenario
    self.repetitions = repetitions
  }
}

private final class M1HarnessGenerationRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var generations: [UInt64: M1HarnessGeneration] = [:]

  func insert(_ generation: M1HarnessGeneration) {
    lock.withLock { generations[generation.runtimeGeneration] = generation }
  }

  func generation(_ runtimeGeneration: UInt64) -> M1HarnessGeneration? {
    lock.withLock { generations[runtimeGeneration] }
  }
}

private final class M1HarnessProbe: @unchecked Sendable {
  private let lock = NSLock()
  private var events: [String] = []
  private var snapshots: [TunnelRuntimePublishedSnapshot] = []
  private var ingress: (any M1PrivateIngressDispatching)?
  private var sshSession: M1HarnessSSHSession?
  private var dnsConsumer: M1HarnessDNSConsumer?
  private var openDescriptors: Set<Int32> = []
  private var liveChannels = 0
  private var liveNativeRuntimes = 0

  func record(_ event: String) {
    lock.withLock { events.append(event) }
  }

  func contains(_ event: String) -> Bool {
    lock.withLock { events.contains(event) }
  }

  func allEvents() -> [String] {
    lock.withLock { events }
  }

  func record(_ snapshot: TunnelRuntimePublishedSnapshot) {
    lock.withLock { snapshots.append(snapshot) }
  }

  func allSnapshots() -> [TunnelRuntimePublishedSnapshot] {
    lock.withLock { snapshots }
  }

  func setIngress(_ ingress: any M1PrivateIngressDispatching) {
    lock.withLock { self.ingress = ingress }
  }

  func capturedIngress() -> (any M1PrivateIngressDispatching)? {
    lock.withLock { ingress }
  }

  func setSSHSession(_ session: M1HarnessSSHSession) {
    lock.withLock { sshSession = session }
  }

  func capturedSSHSession() -> M1HarnessSSHSession? {
    lock.withLock { sshSession }
  }

  func setDNSConsumer(_ consumer: M1HarnessDNSConsumer) {
    lock.withLock { dnsConsumer = consumer }
  }

  func capturedDNSConsumer() -> M1HarnessDNSConsumer? {
    lock.withLock { dnsConsumer }
  }

  func opened(_ pair: PacketBridgeSocketPair) {
    lock.withLock {
      openDescriptors.insert(pair.bridgeDescriptor)
      openDescriptors.insert(pair.hevDescriptor)
    }
  }

  func closed(_ descriptor: Int32) {
    _ = lock.withLock { openDescriptors.remove(descriptor) }
  }

  func channelOpened() {
    lock.withLock { liveChannels += 1 }
  }

  func channelClosed() {
    lock.withLock { liveChannels -= 1 }
  }

  func nativeRuntimeStarted() {
    lock.withLock { liveNativeRuntimes += 1 }
  }

  func nativeRuntimeStopped() {
    lock.withLock { liveNativeRuntimes -= 1 }
  }

  func hasBalancedResources(activePacketReads: Int) -> Bool {
    lock.withLock {
      openDescriptors.isEmpty && liveChannels == 0 && liveNativeRuntimes == 0
        && activePacketReads == 0
    }
  }
}

private final class M1HarnessGeneration: @unchecked Sendable {
  let runtimeGeneration: UInt64
  private let scenario: M1RuntimeHarnessScenario
  private let profileIdentifier: OpaqueProfileIdentifier
  private let packetFlow: M1HarnessPacketFlow
  private let environment: TunnelRuntimeDependencies
  private let probe = M1HarnessProbe()
  private let diagnostics: RuntimeDiagnosticsStore
  private let recorder: RuntimeDiagnosticsRecorder

  init(
    scenario: M1RuntimeHarnessScenario,
    generation: UInt64,
    profileIdentifier: OpaqueProfileIdentifier,
    packetFlow: M1HarnessPacketFlow,
    environment: TunnelRuntimeDependencies
  ) {
    self.scenario = scenario
    runtimeGeneration = generation
    self.profileIdentifier = profileIdentifier
    self.environment = environment
    self.packetFlow = packetFlow
    diagnostics = RuntimeDiagnosticsStore(runtimeGeneration: generation)
    recorder = diagnostics.recorder()
  }

  func dependencies() -> TunnelRuntimeCoordinatorDependencies {
    let packetFactory = BridgeBackedM1PacketPlaneFactory(
      configuration: PacketBridgeConfiguration(
        mtu: 1_500,
        sendBufferBytes: 32_768,
        receiveBufferBytes: 32_768,
        maximumWorkCount: 64,
        workTimeBudget: .milliseconds(5),
        diagnosticsWindow: .seconds(1)
      ),
      virtualDNSEndpoints: [m1DNSFixtureEndpoint]
    ) { [probe, recorder, scenario, environment] ingress, generation in
      probe.setIngress(ingress)
      let bridge = PacketFlowBridge(
        socketIO: M1HarnessTrackingSocketIO(probe: probe),
        descriptorConsumer: M1HarnessDescriptorConsumer(probe: probe),
        clock: environment.clock,
        logger: environment.logger,
        metrics: recorder,
        runIDSource: M1HarnessRunIDSource(generation: generation),
        lifecycleBarrier: M1HarnessPacketBarrier(scenario: scenario, probe: probe)
      )
      return M1HarnessIngressBridge(bridge: bridge, probe: probe)
    }
    return TunnelRuntimeCoordinatorDependencies(
      configurationSource: M1HarnessConfigurationSource(
        profileIdentifier: profileIdentifier,
        probe: probe
      ),
      sshBootstrap: M1HarnessSSHBootstrap(
        scenario: scenario,
        probe: probe,
        recorder: recorder
      ),
      tcpFactory: M1HarnessTCPFactory(probe: probe, recorder: recorder),
      dnsFactory: M1HarnessDNSFactory(
        scenario: scenario,
        probe: probe,
        recorder: recorder
      ),
      packetPlaneFactory: packetFactory,
      settingsPlanBuilder: M1HarnessSettingsBuilder(probe: probe),
      settingsApplier: M1HarnessSettingsApplier(
        scenario: scenario,
        probe: probe,
        recorder: recorder
      ),
      snapshotStore: M1HarnessSnapshotStore(probe: probe)
    )
  }

  func injectionWasObserved() -> Bool {
    switch scenario {
    case .authenticationFailure:
      probe.contains("ssh.authenticate.injected")
    case .packetFailure:
      probe.contains("packet.activate.injected")
    case .dnsFailure:
      probe.contains("dns.prepare.injected")
    case .routeApplyFailure:
      probe.contains("route.apply.injected")
    case .midSessionSSHFailure:
      probe.contains("ssh.loss.injected")
    case .midSessionDNSFailure:
      probe.contains("dns.loss.injected")
    case .success:
      false
    }
  }

  func verifyReady(runtime: any TunnelRuntime) async throws {
    guard await runtime.lifecycleState() == .connectedDegraded,
      let latest = probe.allSnapshots().last,
      latest.lifecycle.lifecycleState == .connectedDegraded,
      latest.lifecycle.tcp,
      latest.lifecycle.safeDNS,
      !latest.lifecycle.udp,
      latest.lifecycle.routesInstalled,
      latest.lifecycle.healthy
    else {
      throw M1RuntimeHarnessError.runtimeInvariant
    }
    try requireOrderedEvents([
      "configuration.load", "ssh.authenticate", "tcp.prepare", "dns.prepare",
      "packet.prepare", "route.plan", "route.apply", "packet.activate",
    ])
  }

  func exchangeRepresentativeTraffic() async throws {
    guard let ingress = probe.capturedIngress() else {
      throw M1RuntimeHarnessError.trafficInvariant
    }
    let tcpDispatch = try await ingress.dispatch(
      .tcp(destination: m1TCPFixtureEndpoint, originator: m1OriginatorFixtureEndpoint)
    )
    guard case .tcp(let channel) = tcpDispatch else {
      throw M1RuntimeHarnessError.trafficInvariant
    }
    let written = try await channel.writeSome(m1TCPRequest)
    try await channel.finishWriting()
    let response = try await channel.read(maximumBytes: 4_096)
    await channel.close()
    guard written == m1TCPRequest.count, response == m1TCPResponse else {
      throw M1RuntimeHarnessError.trafficInvariant
    }

    let dnsDispatch = try await ingress.dispatch(
      .udp(
        payload: m1DNSQuery,
        destination: m1DNSFixtureEndpoint,
        originator: m1OriginatorFixtureEndpoint
      )
    )
    guard case .dnsUDP(let dnsResponse) = dnsDispatch, dnsResponse == m1DNSResponse else {
      throw M1RuntimeHarnessError.trafficInvariant
    }
    probe.record("traffic.complete")
  }

  func requestAndVerifyDiagnostics() throws {
    let snapshot = try diagnostics.snapshot()
    guard snapshot.runtimeGeneration == runtimeGeneration,
      snapshot.counters["tcp_flows_opened_total"] == 1,
      snapshot.counters["tcp_flows_closed_total"] == 1,
      snapshot.counters["tcp_bytes_sent_total"] == UInt64(m1TCPRequest.count),
      snapshot.counters["tcp_bytes_received_total"] == UInt64(m1TCPResponse.count),
      snapshot.counters["dns_result_success_total"] == 1,
      snapshot.gauges["route_installed"] == 1
    else {
      throw M1RuntimeHarnessError.diagnosticsInvariant
    }
    let encoded = try JSONEncoder().encode(snapshot)
    guard let text = String(data: encoded, encoding: .utf8),
      !text.contains(m1TCPFixtureEndpoint.host),
      !text.contains(m1DNSFixtureEndpoint.host),
      !text.contains(profileIdentifier.rawValue.uuidString)
    else {
      throw M1RuntimeHarnessError.privacyInvariant
    }
    probe.record("diagnostics.snapshot")
  }

  func injectMandatoryLoss() async throws {
    switch scenario {
    case .midSessionSSHFailure:
      guard let session = probe.capturedSSHSession() else {
        throw M1RuntimeHarnessError.injectionNotObserved
      }
      await session.injectLoss()
    case .midSessionDNSFailure:
      guard let dns = probe.capturedDNSConsumer() else {
        throw M1RuntimeHarnessError.injectionNotObserved
      }
      await dns.injectLoss()
    case .success, .authenticationFailure, .packetFailure, .dnsFailure,
      .routeApplyFailure:
      throw M1RuntimeHarnessError.injectionNotObserved
    }
  }

  func awaitMandatoryFailure(runtime: any TunnelRuntime) async throws {
    guard injectionWasObserved() else {
      throw M1RuntimeHarnessError.runtimeInvariant
    }

    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(1))
    while await runtime.lifecycleState() != .failed, clock.now < deadline {
      await Task.yield()
    }
    guard await runtime.lifecycleState() == .failed else {
      throw M1RuntimeHarnessError.runtimeInvariant
    }
  }

  func verifyAfterStop(runtime: any TunnelRuntime) async throws {
    let activeReads = await packetFlow.activeReadCount()
    guard probe.hasBalancedResources(activePacketReads: activeReads) else {
      throw M1RuntimeHarnessError.resourceGrowth
    }
    let state = await runtime.lifecycleState()
    guard state == .disconnected || state == .failed else {
      throw M1RuntimeHarnessError.runtimeInvariant
    }
    let lifecycles = probe.allSnapshots().map(\.lifecycle.lifecycleState)
    guard lifecycles.first == .connecting,
      lifecycles.contains(.disconnecting),
      lifecycles.last == state
    else {
      throw M1RuntimeHarnessError.runtimeInvariant
    }
  }

  private func requireOrderedEvents(_ expected: [String]) throws {
    let events = probe.allEvents()
    var previous = -1
    for event in expected {
      guard let index = events.firstIndex(of: event), index > previous else {
        throw M1RuntimeHarnessError.runtimeInvariant
      }
      previous = index
    }
  }
}

private struct M1HarnessConfigurationSource: ConfigurationSnapshotSource {
  let profileIdentifier: OpaqueProfileIdentifier
  let probe: M1HarnessProbe

  func loadValidatedSnapshot(
    for reference: TunnelConfigurationReference
  ) async throws -> RuntimeConfigurationSnapshot {
    guard reference.profileIdentifier == profileIdentifier else {
      throw M1RuntimeHarnessError.invalidFixture
    }
    probe.record("configuration.load")
    return RuntimeConfigurationSnapshot(
      configurationGeneration: 1,
      profileIdentifier: profileIdentifier,
      profileRevision: OpaqueProfileRevision(
        UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
      ),
      credentialReference: OpaqueCredentialReference(
        UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
      ),
      trustReference: OpaqueTrustReference(
        UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
      )
    )
  }
}

private enum M1HarnessInjectedError: Error {
  case authentication
  case dns
  case packet
  case route
}

private struct M1HarnessSSHBootstrap: SSHBootstrap {
  let scenario: M1RuntimeHarnessScenario
  let probe: M1HarnessProbe
  let recorder: RuntimeDiagnosticsRecorder

  func authenticate(
    configuration: RuntimeConfigurationSnapshot,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any SSHBootstrapSession {
    probe.record("ssh.authenticate")
    if scenario == .authenticationFailure {
      recorder.recordError(.sshCredentialRejected)
      probe.record("ssh.authenticate.injected")
      throw M1HarnessInjectedError.authentication
    }
    let session = M1HarnessSSHSession(
      generation: runtimeGeneration,
      healthSink: healthSink,
      probe: probe,
      recorder: recorder
    )
    probe.setSSHSession(session)
    return session
  }
}

private actor M1HarnessSSHSession: M1SSHChannelSession {
  nonisolated let connectedEndpoint = TunnelEndpoint(host: "203.0.113.22", port: 22)
  private let generation: UInt64
  private let healthSink: any TunnelRuntimeHealthEventSink
  private let probe: M1HarnessProbe
  private let recorder: RuntimeDiagnosticsRecorder
  private var healthy = true

  init(
    generation: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink,
    probe: M1HarnessProbe,
    recorder: RuntimeDiagnosticsRecorder
  ) {
    self.generation = generation
    self.healthSink = healthSink
    self.probe = probe
    self.recorder = recorder
  }

  func openTCP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> any SSHByteChannel {
    guard healthy else { throw M1HarnessInjectedError.authentication }
    recorder.recordTCPFlowOpened()
    probe.channelOpened()
    return M1HarnessSSHByteChannel(probe: probe, recorder: recorder)
  }

  func injectLoss() async {
    healthy = false
    recorder.recordError(.sshSessionLost)
    probe.record("ssh.loss.injected")
    await healthSink.receive(
      TunnelRuntimeHealthEvent(
        runtimeGeneration: generation,
        component: .ssh,
        health: .unhealthy
      )
    )
  }

  func close() async {
    healthy = false
    probe.record("ssh.close")
  }

  func health() async -> TunnelRuntimeComponentHealth {
    healthy ? .healthy : .unhealthy
  }
}

private actor M1HarnessSSHByteChannel: SSHByteChannel {
  nonisolated let identity = SSHChannelIdentity(
    rawValue: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
  )
  private let probe: M1HarnessProbe
  private let recorder: RuntimeDiagnosticsRecorder
  private var responseAvailable = true
  private var closed = false

  init(probe: M1HarnessProbe, recorder: RuntimeDiagnosticsRecorder) {
    self.probe = probe
    self.recorder = recorder
  }

  func read(maximumBytes: Int) async throws -> Data? {
    guard !closed, responseAvailable, maximumBytes >= m1TCPResponse.count else { return nil }
    responseAvailable = false
    recorder.recordTCPBytes(sent: 0, received: UInt64(m1TCPResponse.count))
    return m1TCPResponse
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    guard !closed, !bytes.isEmpty else { throw M1HarnessInjectedError.authentication }
    recorder.recordTCPBytes(sent: UInt64(bytes.count), received: 0)
    return bytes.count
  }

  func finishWriting() async throws {}
  func receiveWindow() async -> SSHDeferredSemanticReport<SSHReceiveWindowSnapshot> {
    .notReported
  }
  func cancel() async { await close() }
  func reset() async { await close() }
  func close() async {
    guard !closed else { return }
    closed = true
    recorder.recordTCPFlowClosed()
    probe.channelClosed()
  }
}

private struct M1HarnessTCPFactory: TCPConsumerFactory {
  let probe: M1HarnessProbe
  let recorder: RuntimeDiagnosticsRecorder

  func prepare(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any TCPConsumer {
    guard let session = session as? any M1SSHChannelSession else {
      throw M1RuntimeHarnessError.runtimeInvariant
    }
    probe.record("tcp.prepare")
    return M1HarnessTCPConsumer(session: session, probe: probe)
  }
}

private actor M1HarnessTCPConsumer: M1TCPIngressConsumer {
  private let session: any M1SSHChannelSession
  private let probe: M1HarnessProbe
  private var accepting = true

  init(session: any M1SSHChannelSession, probe: M1HarnessProbe) {
    self.session = session
    self.probe = probe
  }

  func openTCP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> any SSHByteChannel {
    guard accepting else { throw M1RuntimeHarnessError.trafficInvariant }
    return try await session.openTCP(destination: destination, originator: originator)
  }

  func closeAdmission() async {
    accepting = false
    probe.record("tcp.close-admission")
  }
  func stop() async { probe.record("tcp.stop") }
  func health() async -> TunnelRuntimeComponentHealth { accepting ? .healthy : .unhealthy }
}

private struct M1HarnessDNSFactory: DNSConsumerFactory {
  let scenario: M1RuntimeHarnessScenario
  let probe: M1HarnessProbe
  let recorder: RuntimeDiagnosticsRecorder

  func prepareSafeDNS(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any DNSConsumer {
    probe.record("dns.prepare")
    if scenario == .dnsFailure {
      recorder.recordError(.dnsUpstreamTimeout)
      probe.record("dns.prepare.injected")
      throw M1HarnessInjectedError.dns
    }
    guard let session = session as? any M1SSHChannelSession else {
      throw M1RuntimeHarnessError.runtimeInvariant
    }
    let consumer = M1HarnessDNSConsumer(
      session: session,
      generation: runtimeGeneration,
      healthSink: healthSink,
      probe: probe,
      recorder: recorder
    )
    probe.setDNSConsumer(consumer)
    return consumer
  }
}

private actor M1HarnessDNSConsumer: M1DNSIngressConsumer {
  private let session: any M1SSHChannelSession
  private let generation: UInt64
  private let healthSink: any TunnelRuntimeHealthEventSink
  private let probe: M1HarnessProbe
  private let recorder: RuntimeDiagnosticsRecorder
  private var accepting = true

  init(
    session: any M1SSHChannelSession,
    generation: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink,
    probe: M1HarnessProbe,
    recorder: RuntimeDiagnosticsRecorder
  ) {
    self.session = session
    self.generation = generation
    self.healthSink = healthSink
    self.probe = probe
    self.recorder = recorder
  }

  func openTCP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> any SSHByteChannel {
    guard accepting else { throw M1RuntimeHarnessError.trafficInvariant }
    return try await session.openTCP(destination: destination, originator: originator)
  }

  func exchangeUDP(
    _ query: Data,
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> Data {
    guard accepting, query == m1DNSQuery, destination == m1DNSFixtureEndpoint else {
      recorder.recordDNSResult(.malformed, latencyMilliseconds: 1)
      throw M1RuntimeHarnessError.trafficInvariant
    }
    recorder.recordDNSResult(.success, latencyMilliseconds: 1)
    return m1DNSResponse
  }

  func injectLoss() async {
    accepting = false
    recorder.recordError(.dnsUpstreamTimeout)
    probe.record("dns.loss.injected")
    await healthSink.receive(
      TunnelRuntimeHealthEvent(
        runtimeGeneration: generation,
        component: .dns,
        health: .unhealthy
      )
    )
  }

  func closeAdmission() async {
    accepting = false
    probe.record("dns.close-admission")
  }
  func stop() async { probe.record("dns.stop") }
  func health() async -> TunnelRuntimeComponentHealth { accepting ? .healthy : .unhealthy }
}

private struct M1HarnessSettingsPlan: NetworkSettingsPlan {}

private struct M1HarnessSettingsBuilder: NetworkSettingsPlanBuilder {
  let probe: M1HarnessProbe
  func makePlan(
    configuration: RuntimeConfigurationSnapshot,
    connectedEndpoint: TunnelEndpoint,
    runtimeGeneration: UInt64
  ) throws -> any NetworkSettingsPlan {
    probe.record("route.plan")
    return M1HarnessSettingsPlan()
  }
}

private struct M1HarnessSettingsApplier: NetworkSettingsApplier {
  let scenario: M1RuntimeHarnessScenario
  let probe: M1HarnessProbe
  let recorder: RuntimeDiagnosticsRecorder

  func apply(_ plan: any NetworkSettingsPlan, runtimeGeneration: UInt64) async throws {
    probe.record("route.apply")
    if scenario == .routeApplyFailure {
      recorder.recordError(.networkSettingsApplyFailed)
      probe.record("route.apply.injected")
      throw M1HarnessInjectedError.route
    }
    recorder.recordRoute(mode: .compatible, installed: true)
  }

  func clear(runtimeGeneration: UInt64) async throws {
    recorder.recordRoute(mode: .compatible, installed: false)
    probe.record("route.clear")
  }
}

private struct M1HarnessSnapshotStore: RuntimeSnapshotStore {
  let probe: M1HarnessProbe
  func publish(_ snapshot: TunnelRuntimePublishedSnapshot) async {
    probe.record(snapshot)
  }
}

private actor M1HarnessPacketFlow: PacketFlow {
  private var activeReads = 0
  private var shutDown = false

  func readPackets() async throws -> PacketReadBatch {
    guard !shutDown else { throw PacketFlowError.adapterShutDown }
    activeReads += 1
    defer { activeReads -= 1 }
    try await Task.sleep(for: .seconds(3_600))
    return PacketReadBatch(results: [])
  }

  func writePackets(_ packets: [TunnelPacket]) async throws {}
  func shutdown() async { shutDown = true }
  func activeReadCount() -> Int { activeReads }
}

private struct M1HarnessTrackingSocketIO: PacketBridgeSocketIO {
  private let base = DarwinPacketBridgeSocketIO()
  let probe: M1HarnessProbe

  func makeDatagramSocketPair() throws -> PacketBridgeSocketPair {
    let pair = try base.makeDatagramSocketPair()
    probe.opened(pair)
    return pair
  }
  func descriptorFlags(for descriptor: Int32) throws -> Int32 {
    try base.descriptorFlags(for: descriptor)
  }
  func setDescriptorFlags(_ flags: Int32, for descriptor: Int32) throws {
    try base.setDescriptorFlags(flags, for: descriptor)
  }
  func statusFlags(for descriptor: Int32) throws -> Int32 {
    try base.statusFlags(for: descriptor)
  }
  func setStatusFlags(_ flags: Int32, for descriptor: Int32) throws {
    try base.setStatusFlags(flags, for: descriptor)
  }
  func setSocketBuffer(
    _ buffer: PacketBridgeSocketBuffer,
    bytes: Int32,
    for descriptor: Int32
  ) throws {
    try base.setSocketBuffer(buffer, bytes: bytes, for: descriptor)
  }
  func socketBuffer(
    _ buffer: PacketBridgeSocketBuffer,
    for descriptor: Int32
  ) throws -> Int32 {
    try base.socketBuffer(buffer, for: descriptor)
  }
  func sendDatagram(
    on descriptor: Int32,
    bytes: UnsafeRawBufferPointer
  ) throws -> Int {
    try base.sendDatagram(on: descriptor, bytes: bytes)
  }
  func receiveDatagram(
    on descriptor: Int32,
    into bytes: UnsafeMutableRawBufferPointer
  ) throws -> PacketBridgeReceiveResult {
    try base.receiveDatagram(on: descriptor, into: bytes)
  }
  func closeDescriptor(_ descriptor: Int32) throws {
    try base.closeDescriptor(descriptor)
    probe.closed(descriptor)
  }
}

private struct M1HarnessDescriptorConsumer: DescriptorBorrowConsumer {
  let probe: M1HarnessProbe
  func beginBorrowing(
    _ descriptor: Int32
  ) async throws -> any DescriptorBorrowHandle {
    probe.nativeRuntimeStarted()
    return M1HarnessBorrowHandle(probe: probe)
  }
}

private actor M1HarnessBorrowHandle: DescriptorBorrowHandle {
  private let probe: M1HarnessProbe
  private var stopped = false
  init(probe: M1HarnessProbe) { self.probe = probe }
  func requestStop() async {
    guard !stopped else { return }
    stopped = true
    probe.nativeRuntimeStopped()
  }
  func waitForReturn() async {
    if !stopped { await requestStop() }
  }
}

private struct M1HarnessRunIDSource: PacketBridgeRunIDSource {
  let generation: UInt64
  func nextRunID() -> String { "m1-fixture-\(generation)" }
}

private struct M1HarnessPacketBarrier: PacketBridgeLifecycleBarrier {
  let scenario: M1RuntimeHarnessScenario
  let probe: M1HarnessProbe
  func reach(_ stage: PacketBridgeLifecycleStage) async throws {
    if stage == .configurationValidated, scenario == .packetFailure {
      probe.record("packet.activate.injected")
      throw M1HarnessInjectedError.packet
    }
  }
}

private actor M1HarnessIngressBridge: PacketBridge {
  private let bridge: PacketFlowBridge
  private let probe: M1HarnessProbe

  init(bridge: PacketFlowBridge, probe: M1HarnessProbe) {
    self.bridge = bridge
    self.probe = probe
    probe.record("packet.prepare")
  }

  func start(
    packetFlow: any PacketFlow,
    configuration: PacketBridgeConfiguration
  ) async throws -> PacketFlowBridgeRunHandle {
    probe.record("packet.activate")
    return try await bridge.start(packetFlow: packetFlow, configuration: configuration)
  }
  func stop() async {
    await bridge.stop()
    probe.record("packet.stop")
  }
  func metrics() async -> TunnelMetricsSnapshot { await bridge.metrics() }
}
