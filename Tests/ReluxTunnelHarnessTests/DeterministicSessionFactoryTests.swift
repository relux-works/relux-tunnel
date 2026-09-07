import Foundation
import ReluxTunnelCore
import Testing

@testable import ReluxTunnelHarnessSupport

@Suite("Deterministic harness session factory")
struct DeterministicSessionFactoryTests {
  @Test("harness root uses candidate-neutral runtime factory with deterministic generations")
  func candidateNeutralGenerations() async throws {
    let probe = HarnessGenerationProbe()
    let factory = DeterministicHarnessSessionFactory { _, generation in
      probe.record(generation)
      return harnessDependencies()
    }
    assertCandidateNeutral(factory)

    let first = try await factory.makeRuntime(context: harnessContext())
    let second = try await factory.makeRuntime(context: harnessContext())

    #expect((first as? TunnelRuntimeCoordinator)?.runtimeGeneration == 1)
    #expect((second as? TunnelRuntimeCoordinator)?.runtimeGeneration == 2)
    #expect(probe.generations == [1, 2])
  }

  @Test("failed deterministic substitution does not consume a generation")
  func failedSubstitutionDoesNotConsumeGeneration() async throws {
    let probe = HarnessGenerationProbe(failFirst: true)
    let factory = DeterministicHarnessSessionFactory { _, generation in
      try probe.recordOrFail(generation)
      return harnessDependencies()
    }

    await #expect(throws: HarnessFactoryTestError.injected) {
      _ = try await factory.makeRuntime(context: harnessContext())
    }
    let retry = try await factory.makeRuntime(context: harnessContext())

    #expect((retry as? TunnelRuntimeCoordinator)?.runtimeGeneration == 1)
    #expect(probe.generations == [1, 1])
  }

  @Test("exact harness graph preserves pure prepare and repeated reverse cleanup")
  func exactHarnessOwnership() async throws {
    let trace = HarnessOwnershipTrace()
    let factory = DeterministicHarnessSessionFactory { _, generation in
      trace.record("graph.create")
      #expect(generation == 1)
      return harnessOwnershipDependencies(trace: trace)
    }
    let runtime = try await factory.makeRuntime(
      context: harnessOwnershipContext(trace: trace)
    )

    #expect(trace.count("packet.prepare") == 0)
    #expect(trace.count("packet.read") == 0)
    try await runtime.start()

    let startup = trace.events
    #expect(trace.count("ssh.authenticate") == 1)
    #expect(trace.count("tcp.prepare") == 1)
    #expect(trace.count("dns.prepare") == 1)
    #expect(trace.count("packet.prepare") == 1)
    #expect(trace.count("settings.apply") == 1)
    #expect(trace.count("packet.activate") == 1)
    #expect(trace.count("packet.read") == 1)
    #expect(startup.firstIndex(of: "packet.prepare")! < startup.firstIndex(of: "settings.apply")!)
    #expect(startup.firstIndex(of: "settings.apply")! < startup.firstIndex(of: "packet.activate")!)

    await runtime.stop(reason: .userInitiated)
    await runtime.stop(reason: .userInitiated)

    assertHarnessOrder(
      [
        "tcp.close-admission", "dns.close-admission", "packet.stop", "settings.clear",
        "dns.stop", "tcp.stop", "ssh.close",
      ],
      in: trace.events
    )
    #expect(trace.count("packet.stop") == 1)
    #expect(trace.count("settings.clear") == 1)
    #expect(trace.count("dns.stop") == 1)
    #expect(trace.count("tcp.stop") == 1)
    #expect(trace.count("ssh.close") == 1)
  }

  private func assertCandidateNeutral(_ factory: any TunnelRuntimeFactory) {}
}

private func assertHarnessOrder(_ expected: [String], in actual: [String]) {
  var previous = -1
  for event in expected {
    guard let index = actual.firstIndex(of: event) else {
      Issue.record("missing harness lifecycle event: \(event)")
      return
    }
    #expect(index > previous)
    previous = index
  }
}

private enum HarnessFactoryTestError: Error {
  case injected
  case notUsed
}

private final class HarnessGenerationProbe: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [UInt64] = []
  private var shouldFail: Bool

  init(failFirst: Bool = false) {
    shouldFail = failFirst
  }

  var generations: [UInt64] { lock.withLock { values } }

  func record(_ generation: UInt64) {
    lock.withLock { values.append(generation) }
  }

  func recordOrFail(_ generation: UInt64) throws {
    let fail = lock.withLock { () -> Bool in
      values.append(generation)
      defer { shouldFail = false }
      return shouldFail
    }
    if fail { throw HarnessFactoryTestError.injected }
  }
}

private func harnessContext() -> TunnelRuntimeContext {
  let profileID = OpaqueProfileIdentifier(
    UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
  )
  return TunnelRuntimeContext(
    configuration: TunnelConfiguration(
      profileReference: TunnelConfigurationReference(profileIdentifier: profileID)
    ),
    packetFlow: HarnessFactoryPacketFlow(),
    dependencies: TunnelRuntimeDependencies(
      clock: ContinuousTunnelClock(),
      logger: HarnessFactoryLogger(),
      metrics: HarnessFactoryMetrics(),
      cancellation: TaskCancellationChecker(),
      memoryPressure: HarnessFactoryMemoryPressure()
    )
  )
}

private func harnessDependencies() -> TunnelRuntimeCoordinatorDependencies {
  TunnelRuntimeCoordinatorDependencies(
    configurationSource: HarnessFactoryConfigurationSource(),
    sshBootstrap: HarnessFactorySSHBootstrap(),
    tcpFactory: HarnessFactoryTCPFactory(),
    dnsFactory: HarnessFactoryDNSFactory(),
    packetPlaneFactory: HarnessFactoryPacketPlaneFactory(),
    settingsPlanBuilder: HarnessFactorySettingsBuilder(),
    settingsApplier: HarnessFactorySettingsApplier(),
    snapshotStore: HarnessFactorySnapshotStore()
  )
}

private final class HarnessFactoryPacketFlow: PacketFlow, @unchecked Sendable {
  func readPackets() async throws -> PacketReadBatch { PacketReadBatch(results: []) }
  func writePackets(_ packets: [TunnelPacket]) async throws {}
}

private struct HarnessFactoryConfigurationSource: ConfigurationSnapshotSource {
  func loadValidatedSnapshot(
    for reference: TunnelConfigurationReference
  ) async throws -> RuntimeConfigurationSnapshot { throw HarnessFactoryTestError.notUsed }
}

private struct HarnessFactorySSHBootstrap: SSHBootstrap {
  func authenticate(
    configuration: RuntimeConfigurationSnapshot,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any SSHBootstrapSession { throw HarnessFactoryTestError.notUsed }
}

private struct HarnessFactoryTCPFactory: TCPConsumerFactory {
  func prepare(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any TCPConsumer { throw HarnessFactoryTestError.notUsed }
}

private struct HarnessFactoryDNSFactory: DNSConsumerFactory {
  func prepareSafeDNS(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any DNSConsumer { throw HarnessFactoryTestError.notUsed }
}

private struct HarnessFactoryPacketPlaneFactory: M1PacketPlaneFactory {
  func prepare(
    configuration: RuntimeConfigurationSnapshot,
    tcp: any TCPConsumer,
    dns: any DNSConsumer,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any M1PacketPlaneSession { throw HarnessFactoryTestError.notUsed }
}

private struct HarnessFactorySettingsPlan: NetworkSettingsPlan {}
private struct HarnessFactorySettingsBuilder: NetworkSettingsPlanBuilder {
  func makePlan(
    configuration: RuntimeConfigurationSnapshot,
    connectedEndpoint: TunnelEndpoint,
    runtimeGeneration: UInt64
  ) throws -> any NetworkSettingsPlan { HarnessFactorySettingsPlan() }
}

private struct HarnessFactorySettingsApplier: NetworkSettingsApplier {
  func apply(_ plan: any NetworkSettingsPlan, runtimeGeneration: UInt64) async throws {}
  func clear(runtimeGeneration: UInt64) async throws {}
}

private struct HarnessFactorySnapshotStore: RuntimeSnapshotStore {
  func publish(_ snapshot: TunnelRuntimePublishedSnapshot) async {}
}

private struct HarnessFactoryLogger: TunnelLogger {
  func log(
    level: TunnelLogLevel,
    message: String,
    fields: [String: TunnelLogField]
  ) {}
}

private actor HarnessFactoryMetrics: TunnelMetrics {
  func incrementCounter(named name: String, by amount: UInt64) {}
  func setGauge(named name: String, to value: Int64) {}
  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: [:], gauges: [:])
  }
}

private struct HarnessFactoryMemoryPressure: TunnelMemoryPressureSource {
  func currentPressure() async -> TunnelMemoryPressure { .normal }
}

private final class HarnessOwnershipTrace: @unchecked Sendable {
  private let lock = NSLock()
  private var recorded: [String] = []
  var events: [String] { lock.withLock { recorded } }
  func record(_ event: String) { lock.withLock { recorded.append(event) } }
  func count(_ event: String) -> Int { lock.withLock { recorded.count { $0 == event } } }
}

private func harnessOwnershipContext(trace: HarnessOwnershipTrace) -> TunnelRuntimeContext {
  TunnelRuntimeContext(
    configuration: TunnelConfiguration(
      profileReference: TunnelConfigurationReference(
        profileIdentifier: harnessOwnershipSnapshot().profileIdentifier
      )
    ),
    packetFlow: HarnessOwnershipPacketFlow(trace: trace),
    dependencies: TunnelRuntimeDependencies(
      clock: ContinuousTunnelClock(),
      logger: HarnessFactoryLogger(),
      metrics: HarnessFactoryMetrics(),
      cancellation: TaskCancellationChecker(),
      memoryPressure: HarnessFactoryMemoryPressure()
    )
  )
}

private func harnessOwnershipDependencies(
  trace: HarnessOwnershipTrace
) -> TunnelRuntimeCoordinatorDependencies {
  TunnelRuntimeCoordinatorDependencies(
    configurationSource: HarnessOwnershipConfigurationSource(trace: trace),
    sshBootstrap: HarnessOwnershipSSHBootstrap(trace: trace),
    tcpFactory: HarnessOwnershipTCPFactory(trace: trace),
    dnsFactory: HarnessOwnershipDNSFactory(trace: trace),
    packetPlaneFactory: HarnessOwnershipPacketFactory(trace: trace),
    settingsPlanBuilder: HarnessOwnershipSettingsBuilder(trace: trace),
    settingsApplier: HarnessOwnershipSettingsApplier(trace: trace),
    snapshotStore: HarnessFactorySnapshotStore()
  )
}

private func harnessOwnershipSnapshot() -> RuntimeConfigurationSnapshot {
  RuntimeConfigurationSnapshot(
    configurationGeneration: 1,
    profileIdentifier: OpaqueProfileIdentifier(
      UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    ),
    profileRevision: OpaqueProfileRevision(
      UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
    ),
    credentialReference: OpaqueCredentialReference(
      UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
    ),
    trustReference: OpaqueTrustReference(
      UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    )
  )
}

private struct HarnessOwnershipConfigurationSource: ConfigurationSnapshotSource {
  let trace: HarnessOwnershipTrace
  func loadValidatedSnapshot(
    for reference: TunnelConfigurationReference
  ) async throws -> RuntimeConfigurationSnapshot {
    trace.record("configuration.load")
    return harnessOwnershipSnapshot()
  }
}

private struct HarnessOwnershipSSHBootstrap: SSHBootstrap {
  let trace: HarnessOwnershipTrace
  func authenticate(
    configuration: RuntimeConfigurationSnapshot,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any SSHBootstrapSession {
    trace.record("ssh.authenticate")
    return HarnessOwnershipSSHSession(trace: trace)
  }
}

private actor HarnessOwnershipSSHSession: SSHBootstrapSession {
  nonisolated let connectedEndpoint = TunnelEndpoint(host: "198.51.100.10", port: 22)
  let trace: HarnessOwnershipTrace
  var closed = false
  init(trace: HarnessOwnershipTrace) { self.trace = trace }
  func close() async {
    guard !closed else { return }
    closed = true
    trace.record("ssh.close")
  }
  func health() async -> TunnelRuntimeComponentHealth { closed ? .unhealthy : .healthy }
}

private struct HarnessOwnershipTCPFactory: TCPConsumerFactory {
  let trace: HarnessOwnershipTrace
  func prepare(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any TCPConsumer {
    trace.record("tcp.prepare")
    return HarnessOwnershipTCPConsumer(trace: trace)
  }
}

private final class HarnessOwnershipTCPConsumer: TCPConsumer, @unchecked Sendable {
  let trace: HarnessOwnershipTrace
  init(trace: HarnessOwnershipTrace) { self.trace = trace }
  func closeAdmission() async { trace.record("tcp.close-admission") }
  func stop() async { trace.record("tcp.stop") }
  func health() async -> TunnelRuntimeComponentHealth { .healthy }
}

private struct HarnessOwnershipDNSFactory: DNSConsumerFactory {
  let trace: HarnessOwnershipTrace
  func prepareSafeDNS(
    session: any SSHBootstrapSession,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any DNSConsumer {
    trace.record("dns.prepare")
    return HarnessOwnershipDNSConsumer(trace: trace)
  }
}

private final class HarnessOwnershipDNSConsumer: DNSConsumer, @unchecked Sendable {
  let trace: HarnessOwnershipTrace
  init(trace: HarnessOwnershipTrace) { self.trace = trace }
  func closeAdmission() async { trace.record("dns.close-admission") }
  func stop() async { trace.record("dns.stop") }
  func health() async -> TunnelRuntimeComponentHealth { .healthy }
}

private struct HarnessOwnershipPacketFactory: M1PacketPlaneFactory {
  let trace: HarnessOwnershipTrace
  func prepare(
    configuration: RuntimeConfigurationSnapshot,
    tcp: any TCPConsumer,
    dns: any DNSConsumer,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any M1PacketPlaneSession {
    trace.record("packet.prepare")
    return HarnessOwnershipPacketSession(trace: trace)
  }
}

private actor HarnessOwnershipPacketSession: M1PacketPlaneSession {
  let trace: HarnessOwnershipTrace
  var stopped = false
  init(trace: HarnessOwnershipTrace) { self.trace = trace }
  func activateReads(packetFlow: any PacketFlow) async throws {
    trace.record("packet.activate")
    _ = try await packetFlow.readPackets()
  }
  func stop() async {
    guard !stopped else { return }
    stopped = true
    trace.record("packet.stop")
  }
  func health() async -> TunnelRuntimeComponentHealth { stopped ? .unhealthy : .healthy }
}

private final class HarnessOwnershipPacketFlow: PacketFlow, @unchecked Sendable {
  let trace: HarnessOwnershipTrace
  init(trace: HarnessOwnershipTrace) { self.trace = trace }
  func readPackets() async throws -> PacketReadBatch {
    trace.record("packet.read")
    return PacketReadBatch(results: [])
  }
  func writePackets(_ packets: [TunnelPacket]) async throws {}
}

private struct HarnessOwnershipSettingsPlan: NetworkSettingsPlan {}

private struct HarnessOwnershipSettingsBuilder: NetworkSettingsPlanBuilder {
  let trace: HarnessOwnershipTrace
  func makePlan(
    configuration: RuntimeConfigurationSnapshot,
    connectedEndpoint: TunnelEndpoint,
    runtimeGeneration: UInt64
  ) throws -> any NetworkSettingsPlan {
    trace.record("settings.plan")
    return HarnessOwnershipSettingsPlan()
  }
}

private struct HarnessOwnershipSettingsApplier: NetworkSettingsApplier {
  let trace: HarnessOwnershipTrace
  func apply(_ plan: any NetworkSettingsPlan, runtimeGeneration: UInt64) async throws {
    trace.record("settings.apply")
  }
  func clear(runtimeGeneration: UInt64) async throws { trace.record("settings.clear") }
}
