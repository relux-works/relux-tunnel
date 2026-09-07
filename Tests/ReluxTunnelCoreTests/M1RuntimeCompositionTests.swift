import Foundation
import Testing

@testable import ReluxTunnelCore
@testable import ReluxTunnelMacOSAdapter
@testable import ReluxTunnelNativeAdapter

@Suite("M1 runtime composition")
struct M1RuntimeCompositionTests {
  @Test("accepted binding manifest resolves exact M0 values")
  func acceptedManifest() throws {
    let bindings = try MacOSProductionBindingManifestValidator.validate(
      manifestData(),
      diagnosticsWindow: .seconds(2)
    )

    #expect(bindings.packetBridgeConfiguration.mtu == 1_500)
    #expect(bindings.packetBridgeConfiguration.sendBufferBytes == 32_768)
    #expect(bindings.packetBridgeConfiguration.receiveBufferBytes == 32_768)
    #expect(bindings.packetBridgeConfiguration.maximumWorkCount == 64)
    #expect(bindings.packetBridgeConfiguration.workTimeBudget == .milliseconds(5))
    #expect(bindings.internalSOCKSConfiguration.taskStackSizeBytes == 24_576)
    #expect(bindings.internalSOCKSConfiguration.maximumSessionCount == 500)
    #expect(bindings.sshTransportBufferBytes == 65_536)
    #expect(bindings.sshInitialReceiveWindowBytes == 65_536)
  }

  @Test("production digest gate rejects a narrowed manifest")
  func digestGateRejectsNarrowing() throws {
    var bytes = manifestData()
    bytes[bytes.startIndex] ^= 0x01
    #expect(throws: MacOSProductionBindingError.digestMismatch) {
      try MacOSProductionBindingManifestValidator.validate(
        bytes,
        diagnosticsWindow: .seconds(2)
      )
    }
  }

  @Test("semantic gates reject disabled permit, supersession, pin drift, and missing capability")
  func semanticNegativeEvidence() throws {
    let disabled = try mutatedManifest { root in
      root["productionCompositionPermitted"] = false
    }
    #expect(throws: MacOSProductionBindingError.compositionNotPermitted) {
      try semanticValidation(disabled)
    }

    let superseded = try mutatedManifest { root in
      var inputs = root["acceptedInputs"] as! [[String: Any]]
      var ssh = inputs[2]
      ssh["supersession"] = ["status": "superseded", "supersededBy": "TASK-x"]
      inputs[2] = ssh
      root["acceptedInputs"] = inputs
    }
    #expect(
      throws: MacOSProductionBindingError.staleOrSupersededBinding("sshEngine")
    ) {
      try semanticValidation(superseded)
    }

    let pinDrift = try mutatedManifest { root in
      var inputs = root["acceptedInputs"] as! [[String: Any]]
      var ssh = inputs[2]
      var pins = ssh["sourceOrBinaryPins"] as! [String: Any]
      pins["libssh2Commit"] = String(repeating: "0", count: 40)
      ssh["sourceOrBinaryPins"] = pins
      inputs[2] = ssh
      root["acceptedInputs"] = inputs
    }
    #expect(throws: MacOSProductionBindingError.pinMismatch("libssh2Commit")) {
      try semanticValidation(pinDrift)
    }

    let missingCapability = try mutatedManifest { root in
      var inputs = root["acceptedInputs"] as! [[String: Any]]
      var packet = inputs[1]
      var capabilities = packet["requiredCapabilities"] as! [String]
      capabilities.removeAll {
        $0 == "public PacketFlowAdapterBoundary and PacketFlowBridge.start call path"
      }
      packet["requiredCapabilities"] = capabilities
      inputs[1] = packet
      root["acceptedInputs"] = inputs
    }
    #expect(
      throws: MacOSProductionBindingError.mandatoryCapabilityMissing(
        "public PacketFlowAdapterBoundary and PacketFlowBridge.start call path"
      )
    ) {
      try semanticValidation(missingCapability)
    }
  }

  @Test("numeric boolean permits fail semantic and production gates before graph construction")
  func semanticBooleanTypes() async throws {
    for invalidPermit: Any in [0, 1] {
      let manifest = try mutatedManifest { root in
        root["productionCompositionPermitted"] = invalidPermit
      }
      #expect(throws: MacOSProductionBindingError.compositionNotPermitted) {
        try semanticValidation(manifest)
      }

      let probe = CompositionFactoryProbe()
      let factory = productionFactory(manifest: manifest, probe: probe)
      await #expect(throws: MacOSProductionBindingError.digestMismatch) {
        _ = try await factory.makeRuntime(context: runtimeContext())
      }
      #expect(probe.totalFactoryCalls == 0)
    }
  }

  @Test("semantic integer gate rejects booleans, fractions, and overflow")
  func semanticIntegerTypes() throws {
    for invalidSchemaVersion: Any in [true, 1.5, 1e100] {
      let manifest = try mutatedManifest { root in
        root["schemaVersion"] = invalidSchemaVersion
      }
      #expect(throws: MacOSProductionBindingError.incompatibleSchema) {
        try semanticValidation(manifest)
      }
    }

    for invalidMTU: Any in [true, 1_500.5, 1e100] {
      let manifest = try mutatedManifest { root in
        var inputs = root["acceptedInputs"] as! [[String: Any]]
        var packet = inputs[1]
        var bindings = packet["bindings"] as! [String: Any]
        bindings["mtuBytes"] = invalidMTU
        packet["bindings"] = bindings
        inputs[1] = packet
        root["acceptedInputs"] = inputs
      }
      #expect(
        throws: MacOSProductionBindingError.incompatibleBinding("packetBridgeAndHEV")
      ) {
        try semanticValidation(manifest)
      }
    }
  }

  @Test("production call site constructs nothing before manifest validation")
  func invalidManifestCannotConstructGraph() async throws {
    let probe = CompositionFactoryProbe()
    let factory = productionFactory(
      manifest: Data("{}".utf8),
      probe: probe
    )

    await #expect(throws: MacOSProductionBindingError.digestMismatch) {
      _ = try await factory.makeRuntime(context: runtimeContext())
    }
    #expect(probe.totalFactoryCalls == 0)
  }

  @Test("production distinguishes absent and unreadable manifests before construction")
  func absentAndUnreadableManifests() async throws {
    let absentProbe = CompositionFactoryProbe()
    let absent = productionFactory(manifestSource: { nil }, probe: absentProbe)
    await #expect(throws: MacOSProductionBindingError.manifestAbsent) {
      _ = try await absent.makeRuntime(context: runtimeContext())
    }
    #expect(absentProbe.totalFactoryCalls == 0)

    let unreadableProbe = CompositionFactoryProbe()
    let unreadable = productionFactory(
      manifestSource: { throw CompositionTestError.unreadable },
      probe: unreadableProbe
    )
    await #expect(throws: MacOSProductionBindingError.manifestUnreadable) {
      _ = try await unreadable.makeRuntime(context: runtimeContext())
    }
    #expect(unreadableProbe.totalFactoryCalls == 0)
  }

  @Test("production creates one selected object graph per runtime generation")
  func productionGraphPerGeneration() async throws {
    let probe = CompositionFactoryProbe()
    let factory = productionFactory(manifest: manifestData(), probe: probe)

    let first = try await factory.makeRuntime(context: runtimeContext())
    let second = try await factory.makeRuntime(context: runtimeContext())

    #expect((first as? TunnelRuntimeCoordinator)?.runtimeGeneration == 1)
    #expect((second as? TunnelRuntimeCoordinator)?.runtimeGeneration == 2)
    #expect(probe.configurationSources == 2)
    #expect(probe.sshRuntimeServices == 2)
    #expect(probe.tcpFactories == 2)
    #expect(probe.dnsFactories == 2)
    #expect(probe.settingsBuilders == 2)
    #expect(probe.settingsAppliers == 2)
    #expect(probe.snapshotStores == 2)
    #expect(probe.privateIngressHandlers == 2)
  }

  @Test("packet prepare is pure and activation is the only PacketFlow read path")
  func prepareThenActivate() async throws {
    let bridge = StartProbeBridge()
    let tcp = RoutingTCPConsumer()
    let dns = RoutingDNSConsumer()
    let factory = BridgeBackedM1PacketPlaneFactory(
      configuration: packetConfiguration(),
      virtualDNSEndpoints: [dnsEndpoint]
    ) { _, _ in bridge }
    let flow = CountingPacketFlow()

    let session = try await factory.prepare(
      configuration: runtimeSnapshot(),
      tcp: tcp,
      dns: dns,
      runtimeGeneration: 1,
      healthSink: NullHealthSink()
    )
    #expect(bridge.startCalls == 0)
    #expect(flow.readCalls == 0)
    #expect(await session.health() == .healthy)

    await #expect(throws: CompositionTestError.activationProbe) {
      try await session.activateReads(packetFlow: flow)
    }
    #expect(bridge.startCalls == 1)
    #expect(flow.readCalls == 1)
    #expect(await session.health() == .unhealthy)

    await session.stop()
    await session.stop()
    #expect(bridge.stopCalls == 1)
    #expect(await session.health() == .unhealthy)
  }

  @Test("private ingress sends only virtual DNS UDP to DNS")
  func dnsOnlyUDPDispatch() async throws {
    let tcp = RoutingTCPConsumer()
    let dns = RoutingDNSConsumer()
    let dispatcher = M1PrivateIngressDispatcher(
      tcp: tcp,
      dns: dns,
      virtualDNSEndpoints: [dnsEndpoint]
    )
    let origin = TunnelEndpoint(host: "198.51.100.7", port: 49_152)
    let web = TunnelEndpoint(host: "203.0.113.9", port: 443)

    if case .tcp = try await dispatcher.dispatch(
      .tcp(destination: web, originator: origin)
    ) {
    } else {
      Issue.record("ordinary TCP was not routed to TCP")
    }
    if case .dnsTCP = try await dispatcher.dispatch(
      .tcp(destination: dnsEndpoint, originator: origin)
    ) {
    } else {
      Issue.record("virtual DNS TCP was not routed to DNS")
    }
    if case .dnsUDP(let response) = try await dispatcher.dispatch(
      .udp(payload: Data([1, 2]), destination: dnsEndpoint, originator: origin)
    ) {
      #expect(response == Data([2, 1]))
    } else {
      Issue.record("virtual DNS UDP was not routed to DNS")
    }
    await #expect(throws: M1PrivateIngressError.generalUDPDeferred) {
      _ = try await dispatcher.dispatch(
        .udp(payload: Data([3]), destination: web, originator: origin)
      )
    }
    #expect(tcp.openCalls == 1)
    #expect(dns.tcpCalls == 1)
    #expect(dns.udpCalls == 1)
  }

  private func semanticValidation(_ data: Data) throws -> MacOSAcceptedM0Bindings {
    try MacOSProductionBindingManifestValidator.validate(
      data,
      diagnosticsWindow: .seconds(2),
      expectedDigest: nil
    )
  }

  private func mutatedManifest(
    _ mutation: (inout [String: Any]) -> Void
  ) throws -> Data {
    var root = try #require(
      JSONSerialization.jsonObject(with: manifestData()) as? [String: Any]
    )
    mutation(&root)
    return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
  }

  private func productionFactory(
    manifest: Data,
    probe: CompositionFactoryProbe
  ) -> MacOSProductionDependencyFactory {
    productionFactory(manifestSource: { manifest }, probe: probe)
  }

  private func productionFactory(
    manifestSource: @escaping MacOSProductionDependencyFactory.BindingManifestSource,
    probe: CompositionFactoryProbe
  ) -> MacOSProductionDependencyFactory {
    MacOSProductionDependencyFactory(
      bindingManifestSource: manifestSource,
      runtimeInputs: MacOSProductionRuntimeInputs(
        diagnosticsWindow: .seconds(2),
        virtualDNSEndpoints: [dnsEndpoint],
        maximumPendingPrivateConnections: 8,
        privateAuthenticationTimeoutMilliseconds: 1_000
      ),
      componentFactories: MacOSProductionComponentFactories(
        makeConfigurationSource: {
          probe.recordConfigurationSource()
          return StubConfigurationSource()
        },
        makeSSHRuntimeServices: {
          probe.recordSSHRuntimeServices()
          return stubSSHRuntimeServices()
        },
        makeTCPFactory: {
          probe.recordTCPFactory()
          return StubTCPFactory()
        },
        makeDNSFactory: {
          probe.recordDNSFactory()
          return StubDNSFactory()
        },
        makePrivateIngressHandler: {
          probe.recordPrivateIngressHandler()
          return StubPrivateIngressHandler()
        },
        makeSettingsPlanBuilder: {
          probe.recordSettingsBuilder()
          return StubSettingsPlanBuilder()
        },
        makeSettingsApplier: {
          probe.recordSettingsApplier()
          return StubSettingsApplier()
        },
        makeSnapshotStore: {
          probe.recordSnapshotStore()
          return StubSnapshotStore()
        }
      )
    )
  }
}

private let dnsEndpoint = TunnelEndpoint(host: "192.0.2.53", port: 53)

private func manifestData() -> Data {
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  return try! Data(
    contentsOf: root.appendingPathComponent(
      "Configuration/TASK-260720-1qhxqa_m0-production-bindings-v1.json"
    )
  )
}

private func runtimeSnapshot() -> RuntimeConfigurationSnapshot {
  RuntimeConfigurationSnapshot(
    configurationGeneration: 1,
    profileIdentifier: OpaqueProfileIdentifier(
      UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    ),
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

private func runtimeContext() -> TunnelRuntimeContext {
  TunnelRuntimeContext(
    configuration: TunnelConfiguration(
      profileReference: TunnelConfigurationReference(
        profileIdentifier: runtimeSnapshot().profileIdentifier
      )
    ),
    packetFlow: CountingPacketFlow(),
    dependencies: TunnelRuntimeDependencies(
      clock: ContinuousTunnelClock(),
      logger: SilentLogger(),
      metrics: EmptyMetrics(),
      cancellation: TaskCancellationChecker(),
      memoryPressure: NormalMemoryPressure()
    )
  )
}

private func packetConfiguration() -> PacketBridgeConfiguration {
  PacketBridgeConfiguration(
    mtu: 1_500,
    sendBufferBytes: 32_768,
    receiveBufferBytes: 32_768,
    maximumWorkCount: 64,
    workTimeBudget: .milliseconds(5),
    diagnosticsWindow: .seconds(2)
  )
}

private enum CompositionTestError: Error {
  case notUsed
  case activationProbe
  case unreadable
}

private final class CompositionFactoryProbe: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [String: Int] = [:]

  var totalFactoryCalls: Int { lock.withLock { values.values.reduce(0, +) } }
  var configurationSources: Int { count("configuration") }
  var sshRuntimeServices: Int { count("sshServices") }
  var tcpFactories: Int { count("tcp") }
  var dnsFactories: Int { count("dns") }
  var privateIngressHandlers: Int { count("ingressHandler") }
  var settingsBuilders: Int { count("settingsBuilder") }
  var settingsAppliers: Int { count("settingsApplier") }
  var snapshotStores: Int { count("snapshot") }

  func recordConfigurationSource() { increment("configuration") }
  func recordTCPFactory() { increment("tcp") }
  func recordDNSFactory() { increment("dns") }
  func recordSSHRuntimeServices() { increment("sshServices") }
  func recordPrivateIngressHandler() { increment("ingressHandler") }
  func recordSettingsBuilder() { increment("settingsBuilder") }
  func recordSettingsApplier() { increment("settingsApplier") }
  func recordSnapshotStore() { increment("snapshot") }

  private func increment(_ key: String) {
    lock.withLock { values[key, default: 0] += 1 }
  }

  private func count(_ key: String) -> Int {
    lock.withLock { values[key, default: 0] }
  }
}

private final class CountingPacketFlow: PacketFlow, @unchecked Sendable {
  private let lock = NSLock()
  private var reads = 0
  var readCalls: Int { lock.withLock { reads } }

  func readPackets() async throws -> PacketReadBatch {
    lock.withLock { reads += 1 }
    return PacketReadBatch(results: [])
  }

  func writePackets(_ packets: [TunnelPacket]) async throws {}
}

private final class StartProbeBridge: PacketBridge, @unchecked Sendable {
  private let lock = NSLock()
  private var starts = 0
  private var stops = 0
  var startCalls: Int { lock.withLock { starts } }
  var stopCalls: Int { lock.withLock { stops } }

  func start(
    packetFlow: any PacketFlow,
    configuration: PacketBridgeConfiguration
  ) async throws -> PacketFlowBridgeRunHandle {
    lock.withLock { starts += 1 }
    _ = try await packetFlow.readPackets()
    throw CompositionTestError.activationProbe
  }

  func stop() async { lock.withLock { stops += 1 } }
  func metrics() async -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: [:], gauges: [:])
  }
}

private final class RoutingTCPConsumer: M1TCPIngressConsumer, @unchecked Sendable {
  private let lock = NSLock()
  private var opens = 0
  var openCalls: Int { lock.withLock { opens } }

  func openTCP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> any SSHByteChannel {
    lock.withLock { opens += 1 }
    return StubSSHByteChannel()
  }

  func closeAdmission() async {}
  func stop() async {}
  func health() async -> TunnelRuntimeComponentHealth { .healthy }
}

private final class RoutingDNSConsumer: M1DNSIngressConsumer, @unchecked Sendable {
  private let lock = NSLock()
  private var tcp = 0
  private var udp = 0
  var tcpCalls: Int { lock.withLock { tcp } }
  var udpCalls: Int { lock.withLock { udp } }

  func openTCP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> any SSHByteChannel {
    lock.withLock { tcp += 1 }
    return StubSSHByteChannel()
  }

  func exchangeUDP(
    _ query: Data,
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> Data {
    lock.withLock { udp += 1 }
    return Data(query.reversed())
  }

  func closeAdmission() async {}
  func stop() async {}
  func health() async -> TunnelRuntimeComponentHealth { .healthy }
}

private final class StubSSHByteChannel: SSHByteChannel, @unchecked Sendable {
  let identity = SSHChannelIdentity(
    rawValue: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
  )
  func read(maximumBytes: Int) async throws -> Data? { nil }
  func writeSome(_ bytes: Data) async throws -> Int { bytes.count }
  func finishWriting() async throws {}
  func receiveWindow() async -> SSHDeferredSemanticReport<SSHReceiveWindowSnapshot> {
    .unsupported
  }
  func cancel() async {}
  func reset() async {}
  func close() async {}
}

private final class NullHealthSink: TunnelRuntimeHealthEventSink, @unchecked Sendable {
  func receive(_ event: TunnelRuntimeHealthEvent) async {}
}

private struct StubConfigurationSource: ConfigurationSnapshotSource {
  func loadValidatedSnapshot(
    for reference: TunnelConfigurationReference
  ) async throws -> RuntimeConfigurationSnapshot { throw CompositionTestError.notUsed }
}

private func stubSSHRuntimeServices() -> MacOSProductionSSHRuntimeServices {
  MacOSProductionSSHRuntimeServices(
    profileSource: StubSSHProfileSource(),
    configurationBuilder: StubSSHConfigurationBuilder(),
    resolver: StubSSHResolver(),
    connector: StubSSHConnector(),
    logger: StubSSHTransportLogger(),
    observer: StubSSHTransportObserver(),
    metrics: StubSSHTransportMetrics(),
    identityGenerator: StubSSHIdentityGenerator()
  )
}

private struct StubSSHProfileSource: MacOSProductionSSHProfileSource {
  func loadProfile(
    for configuration: RuntimeConfigurationSnapshot
  ) async throws -> SSHProfileSnapshotV1 { throw CompositionTestError.notUsed }
}

private struct StubSSHConfigurationBuilder:
  MacOSProductionSSHConnectionConfigurationBuilding
{
  func makeConnectionConfiguration(
    profile: SSHProfileSnapshotV1,
    runtimeConfiguration: RuntimeConfigurationSnapshot,
    capabilities: SSHAdapterCapabilities
  ) throws -> SSHConnectionConfiguration { throw CompositionTestError.notUsed }
}

private struct StubSSHResolver: SSHNetworkResolver {
  func resolve(hostname: String, port: UInt16) async throws -> [SSHResolvedEndpoint] {
    throw CompositionTestError.notUsed
  }
}

private struct StubSSHConnector: SSHTCPConnector {
  func connect(to endpoint: SSHResolvedEndpoint) async throws -> any SSHTCPConnection {
    throw CompositionTestError.notUsed
  }
}

private struct StubSSHTransportLogger: SSHTransportLogger {
  func log(level: TunnelLogLevel, event: SSHTransportEvent) async {}
}

private struct StubSSHTransportObserver: SSHTransportObserver {
  func observe(_ event: SSHTransportEvent) async {}
}

private struct StubSSHTransportMetrics: SSHTransportMetricsSink {
  func record(_ update: SSHMetricUpdate) async {}
}

private struct StubSSHIdentityGenerator: SSHIdentityGenerator {
  func makeLaneIdentity() -> SSHLaneIdentity {
    SSHLaneIdentity(rawValue: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!)
  }

  func makeSessionIdentity() -> SSHSessionIdentity {
    SSHSessionIdentity(rawValue: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!)
  }

  func makeChannelIdentity() -> SSHChannelIdentity {
    SSHChannelIdentity(rawValue: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!)
  }
}

private struct StubPrivateIngressHandler: M1HEVAuthenticatedConnectionHandler {
  func acceptAuthenticatedConnection(
    _ channel: HEVSOCKSChannel,
    ingress: any M1PrivateIngressDispatching
  ) {
    channel.close()
  }
}

private struct StubTCPFactory: TCPConsumerFactory {
  func prepare(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any TCPConsumer { throw CompositionTestError.notUsed }
}

private struct StubDNSFactory: DNSConsumerFactory {
  func prepareSafeDNS(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any DNSConsumer { throw CompositionTestError.notUsed }
}

private struct StubSettingsPlan: NetworkSettingsPlan {}
private struct StubSettingsPlanBuilder: NetworkSettingsPlanBuilder {
  func makePlan(
    configuration: RuntimeConfigurationSnapshot,
    connectedEndpoint: TunnelEndpoint,
    runtimeGeneration: UInt64
  ) throws -> any NetworkSettingsPlan { StubSettingsPlan() }
}

private struct StubSettingsApplier: NetworkSettingsApplier {
  func apply(_ plan: any NetworkSettingsPlan, runtimeGeneration: UInt64) async throws {}
  func clear(runtimeGeneration: UInt64) async throws {}
}

private struct StubSnapshotStore: RuntimeSnapshotStore {
  func publish(_ snapshot: TunnelRuntimePublishedSnapshot) async {}
}

private struct SilentLogger: TunnelLogger {
  func log(
    level: TunnelLogLevel,
    message: String,
    fields: [String: TunnelLogField]
  ) {}
}

private actor EmptyMetrics: TunnelMetrics {
  func incrementCounter(named name: String, by amount: UInt64) {}
  func setGauge(named name: String, to value: Int64) {}
  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: [:], gauges: [:])
  }
}

private struct NormalMemoryPressure: TunnelMemoryPressureSource {
  func currentPressure() async -> TunnelMemoryPressure { .normal }
}
