import Foundation
import Testing

@testable import ReluxTunnelCore
@testable import ReluxTunnelMacOSAdapter
@testable import ReluxTunnelNativeAdapter

@Suite("macOS production runtime ownership")
struct MacOSProductionRuntimeOwnershipTests {
  @Test("exact returned graph authenticates, activates after settings, and releases in reverse")
  func exactGraphLifecycle() async throws {
    let trace = ProductionOwnershipTrace()
    let runtimeConfiguration = ownershipRuntimeConfiguration()
    let factory = MacOSProductionDependencyFactory(
      bindingManifestSource: { ownershipManifestData() },
      runtimeInputs: MacOSProductionRuntimeInputs(
        diagnosticsWindow: .seconds(2),
        virtualDNSEndpoints: [TunnelEndpoint(host: "192.0.2.53", port: 53)],
        maximumPendingPrivateConnections: 8,
        privateAuthenticationTimeoutMilliseconds: 1_000
      ),
      componentFactories: ownershipComponentFactories(
        trace: trace,
        runtimeConfiguration: runtimeConfiguration
      ),
      makeSelectedSSH: { _ in
        trace.record("ssh.selection")
        return MacOSSelectedSSHDependencies(
          transportFactory: OwnershipSSHTransportFactory(trace: trace),
          credentialProvider: OwnershipCredentialProvider(trace: trace),
          makeHostKeyPolicy: { _ in
            trace.record("ssh.host-policy.create")
            return OwnershipHostPolicy(trace: trace)
          },
          mapCredentialError: {
            MacOSSSHBootstrapErrorMapper.credential($0, configurationGeneration: $1)
          }
        )
      },
      makePacketBridge: { _, generation, _, _, _, _ in
        trace.record("packet.prepare-owner")
        #expect(generation == 1)
        return OwnershipPacketBridge(trace: trace)
      }
    )
    let packetFlow = OwnershipPacketFlow(trace: trace)
    let runtime = try await factory.makeRuntime(
      context: ownershipRuntimeContext(packetFlow: packetFlow)
    )

    #expect(trace.count("packet.prepare-owner") == 0)
    #expect(trace.resourceAcquisitionCount == 0)

    try await runtime.start()

    let startup = trace.events
    #expect(trace.count("ssh.transport.create") == 1)
    #expect(trace.count("ssh.host-policy.evaluate") == 1)
    #expect(trace.count("ssh.credential.lookup") == 1)
    #expect(trace.count("tcp.prepare") == 1)
    #expect(trace.count("dns.prepare") == 1)
    #expect(trace.count("packet.prepare-owner") == 1)
    #expect(trace.count("packet.descriptor") == 1)
    #expect(trace.count("packet.hev-lease") == 1)
    #expect(trace.count("packet.hev-thread") == 1)
    #expect(trace.count("packet.private-listener") == 1)
    #expect(trace.count("packet.read") == 1)
    #expect(
      startup.firstIndex(of: "settings.apply")! < startup.firstIndex(of: "packet.descriptor")!)
    #expect(
      startup.firstIndex(of: "packet.prepare-owner")!
        < startup.firstIndex(of: "settings.apply")!
    )
    #expect(
      startup[startup.startIndex..<startup.firstIndex(of: "settings.apply")!]
        .allSatisfy {
          !$0.hasPrefix("packet.descriptor") && !$0.hasPrefix("packet.hev-")
            && $0 != "packet.private-listener" && $0 != "packet.read"
        }
    )

    await runtime.stop(reason: .userInitiated)
    await runtime.stop(reason: .userInitiated)

    let cleanup = trace.events
    assertOrdered(
      [
        "tcp.close-admission", "dns.close-admission", "packet.stop", "settings.clear",
        "dns.stop", "tcp.stop", "ssh.transport.close",
      ],
      in: cleanup
    )
    #expect(trace.count("packet.stop") == 1)
    #expect(trace.count("settings.clear") == 1)
    #expect(trace.count("dns.stop") == 1)
    #expect(trace.count("tcp.stop") == 1)
    #expect(trace.count("ssh.transport.close") == 1)
  }

  private func assertOrdered(_ expected: [String], in actual: [String]) {
    var previous = -1
    for event in expected {
      guard let index = actual.firstIndex(of: event) else {
        Issue.record("missing lifecycle event: \(event)")
        return
      }
      #expect(index > previous)
      previous = index
    }
  }
}

private func ownershipComponentFactories(
  trace: ProductionOwnershipTrace,
  runtimeConfiguration: RuntimeConfigurationSnapshot
) -> MacOSProductionComponentFactories {
  MacOSProductionComponentFactories(
    makeConfigurationSource: {
      trace.record("configuration-source.create")
      return OwnershipConfigurationSource(
        trace: trace,
        configuration: runtimeConfiguration
      )
    },
    makeSSHRuntimeServices: {
      trace.record("ssh.services.create")
      return MacOSProductionSSHRuntimeServices(
        profileSource: OwnershipProfileSource(trace: trace),
        configurationBuilder: OwnershipSSHConfigurationBuilder(trace: trace),
        resolver: OwnershipResolver(),
        connector: OwnershipConnector(),
        logger: OwnershipSSHLogger(),
        observer: OwnershipSSHObserver(),
        metrics: OwnershipSSHMetrics(),
        identityGenerator: OwnershipIdentities()
      )
    },
    makeTCPFactory: {
      trace.record("tcp.factory.create")
      return OwnershipTCPFactory(trace: trace)
    },
    makeDNSFactory: {
      trace.record("dns.factory.create")
      return OwnershipDNSFactory(trace: trace)
    },
    makePrivateIngressHandler: {
      trace.record("packet.handler.create")
      return OwnershipPrivateIngressHandler()
    },
    makeSettingsPlanBuilder: {
      trace.record("settings.builder.create")
      return OwnershipSettingsBuilder(trace: trace)
    },
    makeSettingsApplier: {
      trace.record("settings.applier.create")
      return OwnershipSettingsApplier(trace: trace)
    },
    makeSnapshotStore: { OwnershipSnapshotStore() }
  )
}

private final class ProductionOwnershipTrace: @unchecked Sendable {
  private let lock = NSLock()
  private var recorded: [String] = []

  var events: [String] { lock.withLock { recorded } }

  var resourceAcquisitionCount: Int {
    lock.withLock {
      recorded.count {
        $0 == "packet.descriptor" || $0 == "packet.hev-lease"
          || $0 == "packet.hev-thread" || $0 == "packet.private-listener"
          || $0 == "packet.read"
      }
    }
  }

  func record(_ event: String) { lock.withLock { recorded.append(event) } }
  func count(_ event: String) -> Int { lock.withLock { recorded.count { $0 == event } } }
}

private struct OwnershipConfigurationSource: ConfigurationSnapshotSource {
  let trace: ProductionOwnershipTrace
  let configuration: RuntimeConfigurationSnapshot

  func loadValidatedSnapshot(
    for reference: TunnelConfigurationReference
  ) async throws -> RuntimeConfigurationSnapshot {
    trace.record("configuration.load")
    return configuration
  }
}

private struct OwnershipProfileSource: MacOSProductionSSHProfileSource {
  let trace: ProductionOwnershipTrace

  func loadProfile(
    for configuration: RuntimeConfigurationSnapshot
  ) async throws -> SSHProfileSnapshotV1 {
    trace.record("ssh.profile.load")
    return ownershipProfile(configuration: configuration)
  }
}

private struct OwnershipSSHConfigurationBuilder:
  MacOSProductionSSHConnectionConfigurationBuilding
{
  let trace: ProductionOwnershipTrace

  func makeConnectionConfiguration(
    profile: SSHProfileSnapshotV1,
    runtimeConfiguration: RuntimeConfigurationSnapshot,
    capabilities: SSHAdapterCapabilities
  ) throws -> SSHConnectionConfiguration {
    trace.record("ssh.configuration.build")
    return try SSHConnectionConfiguration(
      canonicalHostname: profile.canonicalHost.value,
      endpoint: TunnelEndpoint(host: profile.canonicalHost.value, port: profile.port),
      username: profile.account,
      profileReference: TunnelConfigurationReference(
        profileIdentifier: runtimeConfiguration.profileIdentifier
      ),
      credentialReference: SSHCredentialReference(
        rawValue: profile.credential.reference.rawValue.uuidString.lowercased()
      ),
      credentialGeneration: profile.credential.generation,
      trustRecordReference: SSHTrustRecordReference(
        rawValue: runtimeConfiguration.trustReference.rawValue.uuidString.lowercased()
      ),
      algorithms: SSHAlgorithmPolicy(
        keyExchange: ["curve25519-sha256"],
        hostKey: ["ssh-ed25519"],
        cipher: ["aes256-ctr"],
        mac: ["hmac-sha2-256"]
      ),
      timeouts: try ownershipTimeouts(),
      rekey: SSHRekeyPolicy(
        protectedByteThresholdPerDirection: 4_096,
        elapsedTimeThreshold: .milliseconds(100),
        timeout: .seconds(10)
      ),
      keepalive: SSHKeepalivePolicy(
        interval: .seconds(60),
        replyTimeout: .seconds(10),
        allowedConsecutiveMisses: 1
      )
    )
  }
}

private struct OwnershipSSHTransportFactory: SSHTransportFactory {
  let trace: ProductionOwnershipTrace
  let capabilities = ownershipCapabilities()

  func makeTransport(
    lane: SSHLaneIdentity,
    dependencies: SSHTransportDependencies
  ) async throws -> any SSHTransport {
    trace.record("ssh.transport.create")
    return OwnershipSSHTransport(
      trace: trace,
      lane: lane,
      dependencies: dependencies
    )
  }
}

private actor OwnershipSSHTransport: SSHTransport {
  let trace: ProductionOwnershipTrace
  let lane: SSHLaneIdentity
  let dependencies: SSHTransportDependencies
  var closed = false

  init(
    trace: ProductionOwnershipTrace,
    lane: SSHLaneIdentity,
    dependencies: SSHTransportDependencies
  ) {
    self.trace = trace
    self.lane = lane
    self.dependencies = dependencies
  }

  func connect(configuration: SSHConnectionConfiguration) async throws -> SSHSession {
    trace.record("ssh.transport.connect")
    let evidence = try SSHHostKeyEvidence(algorithm: "ssh-ed25519", keyBytes: Data([1]))
    let input = SSHHostKeyPolicyInput(
      canonicalHostname: configuration.canonicalHostname,
      connectedEndpoint: configuration.endpoint,
      evidence: evidence,
      lane: lane,
      trustRecordReference: configuration.trustRecordReference
    )
    let decision = try await dependencies.hostKeyPolicy.evaluate(input)
    let acceptance = try decision.acceptance(for: input)
    let credential = try await dependencies.credentialProvider.credential(
      for: SSHCredentialRequest(
        credentialReference: configuration.credentialReference,
        credentialGeneration: configuration.credentialGeneration,
        username: configuration.username,
        allowedPublicKeyAlgorithms: ["ssh-ed25519"],
        acceptedHost: acceptance
      )
    )
    credential.retire()
    trace.record("ssh.transport.ready")
    return SSHSession(
      identity: dependencies.identityGenerator.makeSessionIdentity(),
      acceptedHost: acceptance,
      negotiatedAlgorithms: ownershipNegotiatedAlgorithms(),
      keyExchangeGeneration: .unsupported
    )
  }

  func openDirectTCPIP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint,
    policy: SSHChannelPolicy
  ) async throws -> any SSHByteChannel { throw OwnershipError.notUsed }

  func openExecChannel(
    request: SSHExecRequest,
    policy: SSHChannelPolicy
  ) async throws -> any SSHExecChannel { throw OwnershipError.notUsed }

  func upload(_ request: SSHExecUploadRequest) async throws -> SSHExecExit {
    throw OwnershipError.notUsed
  }

  func requestRekey(reason: SSHClientRekeyReason) async throws {}
  func sendKeepalive() async throws -> SSHDeferredSemanticReport<Duration> { .unsupported }
  func snapshot() async -> SSHTransportSnapshot { ownershipTransportSnapshot(lane: lane) }

  func close() async {
    guard !closed else { return }
    closed = true
    trace.record("ssh.transport.close")
  }
}

private struct OwnershipHostPolicy: SSHHostKeyPolicy {
  let trace: ProductionOwnershipTrace

  func evaluate(_ input: SSHHostKeyPolicyInput) async throws -> SSHHostKeyDecision {
    trace.record("ssh.host-policy.evaluate")
    return .acceptMatch(
      input.trustRecordReference
        ?? SSHTrustRecordReference(rawValue: "missing-trust-reference")
    )
  }
}

private struct OwnershipCredentialProvider: SSHCredentialProvider {
  let trace: ProductionOwnershipTrace

  func credential(for request: SSHCredentialRequest) async throws
    -> any SSHPublicKeyCredential
  {
    trace.record("ssh.credential.lookup")
    return OwnershipCredential()
  }
}

private struct OwnershipCredential: SSHPublicKeyCredential {
  let algorithm = "ssh-ed25519"
  let publicKeyBytes = Data([1])
  func sign(_ payload: Data) async throws -> Data { Data([2]) }
}

private struct OwnershipTCPFactory: TCPConsumerFactory {
  let trace: ProductionOwnershipTrace

  func prepare(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any TCPConsumer {
    guard session is any M1SSHChannelSession else { throw OwnershipError.wrongSSHSession }
    trace.record("tcp.prepare")
    return OwnershipTCPConsumer(trace: trace)
  }
}

private final class OwnershipTCPConsumer: M1TCPIngressConsumer, @unchecked Sendable {
  let trace: ProductionOwnershipTrace
  init(trace: ProductionOwnershipTrace) { self.trace = trace }
  func openTCP(destination: TunnelEndpoint, originator: TunnelEndpoint) async throws
    -> any SSHByteChannel
  { throw OwnershipError.notUsed }
  func closeAdmission() async { trace.record("tcp.close-admission") }
  func stop() async { trace.record("tcp.stop") }
  func health() async -> TunnelRuntimeComponentHealth { .healthy }
}

private struct OwnershipDNSFactory: DNSConsumerFactory {
  let trace: ProductionOwnershipTrace

  func prepareSafeDNS(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any DNSConsumer {
    guard session is any M1SSHChannelSession else { throw OwnershipError.wrongSSHSession }
    trace.record("dns.prepare")
    return OwnershipDNSConsumer(trace: trace)
  }
}

private final class OwnershipDNSConsumer: M1DNSIngressConsumer, @unchecked Sendable {
  let trace: ProductionOwnershipTrace
  init(trace: ProductionOwnershipTrace) { self.trace = trace }
  func openTCP(destination: TunnelEndpoint, originator: TunnelEndpoint) async throws
    -> any SSHByteChannel
  { throw OwnershipError.notUsed }
  func exchangeUDP(
    _ query: Data,
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> Data { throw OwnershipError.notUsed }
  func closeAdmission() async { trace.record("dns.close-admission") }
  func stop() async { trace.record("dns.stop") }
  func health() async -> TunnelRuntimeComponentHealth { .healthy }
}

private final class OwnershipPacketBridge: PacketBridge, @unchecked Sendable {
  let trace: ProductionOwnershipTrace
  private let lock = NSLock()
  private var stopped = false

  init(trace: ProductionOwnershipTrace) { self.trace = trace }

  func start(
    packetFlow: any PacketFlow,
    configuration: PacketBridgeConfiguration
  ) async throws -> PacketFlowBridgeRunHandle {
    trace.record("packet.descriptor")
    trace.record("packet.private-listener")
    trace.record("packet.hev-lease")
    trace.record("packet.hev-thread")
    _ = try await packetFlow.readPackets()
    return PacketFlowBridgeRunHandle(completion: PacketBridgeRunCompletion())
  }

  func stop() async {
    let shouldRecord = lock.withLock { () -> Bool in
      guard !stopped else { return false }
      stopped = true
      return true
    }
    if shouldRecord { trace.record("packet.stop") }
  }

  func metrics() async -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: [:], gauges: [:])
  }
}

private final class OwnershipPacketFlow: PacketFlow, @unchecked Sendable {
  let trace: ProductionOwnershipTrace
  init(trace: ProductionOwnershipTrace) { self.trace = trace }
  func readPackets() async throws -> PacketReadBatch {
    trace.record("packet.read")
    return PacketReadBatch(results: [])
  }
  func writePackets(_ packets: [TunnelPacket]) async throws {}
}

private struct OwnershipSettingsPlan: NetworkSettingsPlan {}

private struct OwnershipSettingsBuilder: NetworkSettingsPlanBuilder {
  let trace: ProductionOwnershipTrace
  func makePlan(
    configuration: RuntimeConfigurationSnapshot,
    connectedEndpoint: TunnelEndpoint,
    runtimeGeneration: UInt64
  ) throws -> any NetworkSettingsPlan {
    trace.record("settings.plan")
    return OwnershipSettingsPlan()
  }
}

private struct OwnershipSettingsApplier: NetworkSettingsApplier {
  let trace: ProductionOwnershipTrace
  func apply(_ plan: any NetworkSettingsPlan, runtimeGeneration: UInt64) async throws {
    trace.record("settings.apply")
  }
  func clear(runtimeGeneration: UInt64) async throws { trace.record("settings.clear") }
}

private struct OwnershipSnapshotStore: RuntimeSnapshotStore {
  func publish(_ snapshot: TunnelRuntimePublishedSnapshot) async {}
}

private struct OwnershipPrivateIngressHandler: M1HEVAuthenticatedConnectionHandler {
  func acceptAuthenticatedConnection(
    _ channel: HEVSOCKSChannel,
    ingress: any M1PrivateIngressDispatching
  ) {
    channel.close()
  }
}

private struct OwnershipResolver: SSHNetworkResolver {
  func resolve(hostname: String, port: UInt16) async throws -> [SSHResolvedEndpoint] {
    throw OwnershipError.notUsed
  }
}

private struct OwnershipConnector: SSHTCPConnector {
  func connect(to endpoint: SSHResolvedEndpoint) async throws -> any SSHTCPConnection {
    throw OwnershipError.notUsed
  }
}

private struct OwnershipSSHLogger: SSHTransportLogger {
  func log(level: TunnelLogLevel, event: SSHTransportEvent) async {}
}

private struct OwnershipSSHObserver: SSHTransportObserver {
  func observe(_ event: SSHTransportEvent) async {}
}

private struct OwnershipSSHMetrics: SSHTransportMetricsSink {
  func record(_ update: SSHMetricUpdate) async {}
}

private struct OwnershipIdentities: SSHIdentityGenerator {
  func makeLaneIdentity() -> SSHLaneIdentity {
    SSHLaneIdentity(rawValue: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
  }
  func makeSessionIdentity() -> SSHSessionIdentity {
    SSHSessionIdentity(rawValue: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!)
  }
  func makeChannelIdentity() -> SSHChannelIdentity {
    SSHChannelIdentity(rawValue: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!)
  }
}

private func ownershipRuntimeConfiguration() -> RuntimeConfigurationSnapshot {
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

private func ownershipProfile(
  configuration: RuntimeConfigurationSnapshot
) -> SSHProfileSnapshotV1 {
  SSHProfileSnapshotV1(
    configurationGeneration: configuration.configurationGeneration,
    profileID: configuration.profileIdentifier,
    createdAt: SSHProfileTimestamp("2026-08-30T00:00:00.000Z"),
    updatedAt: SSHProfileTimestamp("2026-08-30T00:00:00.000Z"),
    displayName: "fixture",
    canonicalHost: SSHProfileCanonicalHost(kind: .dns, value: "fixture.example"),
    port: 22,
    account: "fixture-user",
    credential: SSHProfileCredentialReferenceV1(
      reference: configuration.credentialReference,
      generation: 1
    ),
    hostPolicy: SSHHostPolicyV1(allowedAlgorithms: [.sshEd25519], records: [])
  )
}

private func ownershipRuntimeContext(
  packetFlow: any PacketFlow
) -> TunnelRuntimeContext {
  TunnelRuntimeContext(
    configuration: TunnelConfiguration(
      profileReference: TunnelConfigurationReference(
        profileIdentifier: ownershipRuntimeConfiguration().profileIdentifier
      )
    ),
    packetFlow: packetFlow,
    dependencies: TunnelRuntimeDependencies(
      clock: ContinuousTunnelClock(),
      logger: OwnershipTunnelLogger(),
      metrics: OwnershipTunnelMetrics(),
      cancellation: TaskCancellationChecker(),
      memoryPressure: OwnershipMemoryPressure()
    )
  )
}

private struct OwnershipTunnelLogger: TunnelLogger {
  func log(level: TunnelLogLevel, message: String, fields: [String: TunnelLogField]) {}
}

private actor OwnershipTunnelMetrics: TunnelMetrics {
  func incrementCounter(named name: String, by amount: UInt64) {}
  func setGauge(named name: String, to value: Int64) {}
  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: [:], gauges: [:])
  }
}

private struct OwnershipMemoryPressure: TunnelMemoryPressureSource {
  func currentPressure() async -> TunnelMemoryPressure { .normal }
}

private func ownershipTimeouts() throws -> SSHTimeoutPolicy {
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
    upload: .seconds(1),
    channelClose: .seconds(1),
    transportClose: .seconds(1)
  )
}

private func ownershipCapabilities() -> SSHAdapterCapabilities {
  SSHAdapterCapabilities(
    features: Set(SSHAdapterFeature.allCases),
    deferredSemantics: SSHDeferredSemanticCapabilities(
      consumerDrivenReceiveWindowCredit: .unsupported,
      rfcChannelOpenFailureReasons: .unsupported,
      exactExecExitMetadata: .unsupported,
      deepRekeyAndKeepaliveObservability: .unsupported
    ),
    keyExchangeAlgorithms: ["curve25519-sha256"],
    hostKeyAlgorithms: ["ssh-ed25519"],
    cipherAlgorithms: ["aes256-ctr"],
    macAlgorithms: ["hmac-sha2-256"],
    publicKeyAuthenticationAlgorithms: ["ssh-ed25519"]
  )
}

private func ownershipNegotiatedAlgorithms() -> SSHNegotiatedAlgorithms {
  SSHNegotiatedAlgorithms(
    keyExchange: "curve25519-sha256",
    hostKey: "ssh-ed25519",
    cipherClientToServer: "aes256-ctr",
    cipherServerToClient: "aes256-ctr",
    macClientToServer: "hmac-sha2-256",
    macServerToClient: "hmac-sha2-256"
  )
}

private func ownershipTransportSnapshot(lane: SSHLaneIdentity) -> SSHTransportSnapshot {
  SSHTransportSnapshot(
    lane: lane,
    connectionState: .ready,
    negotiatedAlgorithms: ownershipNegotiatedAlgorithms(),
    keyExchangeGeneration: .unsupported,
    counters: SSHTransportCounters(
      windowAdjustments: .unsupported,
      windowAdjustmentBytes: .unsupported,
      serverRekeys: .unsupported,
      keepalivesAcknowledged: .unsupported,
      keepalivesTimedOut: .unsupported
    ),
    gauges: SSHTransportGauges(
      remainingReceiveWindowBytes: .unsupported,
      activeKeyExchange: .unsupported,
      consecutiveKeepaliveMisses: .unsupported,
      lastKeepaliveRTTNanoseconds: .unsupported
    )
  )
}

private func ownershipManifestData() -> Data {
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

private enum OwnershipError: Error {
  case notUsed
  case wrongSSHSession
}
