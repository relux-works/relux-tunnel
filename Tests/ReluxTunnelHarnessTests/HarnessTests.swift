import Foundation
import ReluxTunnelCore
import Testing

@testable import ReluxTunnelHarnessSupport

@Suite("ReluxTunnelHarness")
struct HarnessTests {
  @Test("macOS harness registers the pinned libssh2 candidate capabilities")
  func libSSH2CandidateRegistration() {
    let capabilities = LibSSH2HarnessRegistration.capabilities
    #expect(capabilities.features.contains(.hostKeyBeforeAuthentication))
    #expect(capabilities.features.contains(.explicitRekey))
    #expect(capabilities.deferredSemantics.consumerDrivenReceiveWindowCredit == .unsupported)
    #expect(capabilities.deferredSemantics.exactExecExitMetadata == .unsupported)
  }

  @Test("argument parser rejects missing and unknown subcommands")
  func argumentValidationCommands() {
    #expect(throws: HarnessArgumentError.missingCommand) {
      try HarnessArgumentParser.parse(arguments: [], registeredCommands: ["smoke"])
    }
    #expect(throws: HarnessArgumentError.unknownCommand("packet")) {
      try HarnessArgumentParser.parse(arguments: ["packet"], registeredCommands: ["smoke"])
    }
  }

  @Test("argument parser requires exactly one structured configuration input")
  func argumentValidationConfiguration() {
    #expect(throws: HarnessArgumentError.missingConfiguration) {
      try HarnessArgumentParser.parse(arguments: ["smoke"], registeredCommands: ["smoke"])
    }
    #expect(throws: HarnessArgumentError.duplicateConfiguration) {
      try HarnessArgumentParser.parse(
        arguments: [
          "smoke", "--configuration", "fixture.json",
          "--configuration-json", "{}",
        ],
        registeredCommands: ["smoke"]
      )
    }
    #expect(throws: HarnessArgumentError.missingOptionValue("--configuration")) {
      try HarnessArgumentParser.parse(
        arguments: ["smoke", "--configuration"],
        registeredCommands: ["smoke"]
      )
    }
  }

  @Test("configuration schema versions fail closed")
  func configurationSchemaValidation() throws {
    let unsupported = makeConfiguration(schemaVersion: 999)
    let data = try HarnessConfigurationCodec.encode(unsupported)

    #expect(throws: HarnessConfigurationError.unsupportedSchemaVersion(999)) {
      try HarnessConfigurationCodec.decode(data)
    }
  }

  @Test("configuration rejects a non-opaque runtime profile reference")
  func configurationProfileReferenceValidation() throws {
    let encoded = try HarnessConfigurationCodec.encode(makeConfiguration())
    let invalid = Data(
      String(decoding: encoded, as: UTF8.self)
        .replacingOccurrences(
          of: "11111111-1111-1111-1111-111111111111",
          with: "raw-profile-or-secret"
        )
        .utf8
    )

    #expect(throws: HarnessConfigurationError.invalidProfileReference) {
      try HarnessConfigurationCodec.decode(invalid)
    }
  }

  @Test("signals map to shell-standard exit codes")
  func signalExitCodes() {
    #expect(HarnessCancellationReason.interrupt.exitCode == .interrupted)
    #expect(HarnessCancellationReason.terminate.exitCode == .terminated)
  }

  @Test("smoke output is deterministic, versioned, and privacy safe")
  func smokeResultSchema() async throws {
    let configuration = makeConfiguration()
    let first = await runSmoke(configuration: configuration)
    let second = await runSmoke(configuration: configuration)

    #expect(first.exitCode == .success)
    #expect(first.standardError.isEmpty)
    #expect(first.standardOutput == second.standardOutput)

    let result = try JSONDecoder().decode(
      HarnessResultDocument.self,
      from: first.standardOutput
    )
    #expect(result.schemaVersion == HarnessResultSchema.currentVersion)
    #expect(result.metrics.schemaVersion == HarnessMetricSchema.currentVersion)
    #expect(result.metrics.counters == ["harness.smoke.runs": 1])
    #expect(
      result.metrics.gauges == [
        "harness.hev.linked": 1,
        "harness.libssh2.linked": 1,
        "harness.native_fixture.schema_version": 1,
      ]
    )
    #expect(result.command == "smoke")
    #expect(result.status == "succeeded")
    #expect(result.durationNanoseconds == 0)
    #expect(result.sourceRevision == "0123456789abcdef")
    #expect(result.dependencyRevisions == ["fixture": "abcdef"])
    #expect(result.configuration.profileReference == "<redacted>")
    #expect(result.configuration.parameters["mode"] == "noop")
    #expect(result.configuration.parameters["destination"] == "<redacted>")
    #expect(
      result.platform
        == HarnessPlatformMetadata(
          operatingSystem: "macOS",
          operatingSystemVersion: "test",
          architecture: "test-arch"
        )
    )
  }

  @Test("normal exit cleans files, sockets, and managed tasks")
  func normalExitCleanup() async throws {
    let recorder = ResourceRecorder()
    let command = ResourceCommand(name: "cleanup", recorder: recorder, blocks: false)
    let application = try makeApplication(commands: [command])

    let response = await application.run(
      arguments: try arguments(command: "cleanup"),
      cancellationSource: StreamHarnessCancellationSource()
    )

    #expect(response.exitCode == .success)
    try await expectResourcesCleaned(recorder)
  }

  @Test("signal cancellation uses signal exit code and cleans all resources")
  func cancellationCleanup() async throws {
    let recorder = ResourceRecorder()
    let command = ResourceCommand(name: "cancel", recorder: recorder, blocks: true)
    let application = try makeApplication(commands: [command])
    let cancellation = StreamHarnessCancellationSource()
    let invocationArguments = try arguments(command: "cancel")

    let run = Task {
      await application.run(
        arguments: invocationArguments,
        cancellationSource: cancellation
      )
    }
    try await waitUntil { await recorder.hasStarted }
    cancellation.cancel(reason: .terminate)
    let response = await run.value

    #expect(response.exitCode == .terminated)
    #expect(response.standardOutput.isEmpty)
    try await expectResourcesCleaned(recorder)
  }

  @Test("subcommands receive every packet and SSH experiment seam")
  func dependencyInjection() async throws {
    let recorder = DependencyRecorder()
    let command = DependencyCommand(recorder: recorder)
    let metrics = HarnessMetricsStore()
    let dependencies = HarnessCommandDependencies(
      runtime: TunnelRuntimeDependencies(
        clock: RecordingClock(recorder: recorder),
        logger: SilentHarnessLogger(),
        metrics: metrics,
        cancellation: TaskCancellationChecker(),
        memoryPressure: RecordingPressureSource(recorder: recorder)
      ),
      sshTransports: RecordingTransportFactory(recorder: recorder),
      packetEndpoints: RecordingPacketFactory(recorder: recorder),
      faultPolicy: RecordingFaultPolicy(recorder: recorder)
    )
    let registry = try HarnessCommandRegistry(commands: [command])
    let application = HarnessApplication(
      registry: registry,
      dependencies: dependencies,
      readPlatform: fixedPlatform
    )

    let response = await application.run(
      arguments: try arguments(command: command.name),
      cancellationSource: StreamHarnessCancellationSource()
    )
    let snapshot = await recorder.snapshot()

    #expect(response.exitCode == .success)
    #expect(snapshot.clockRead)
    #expect(snapshot.transportCreated)
    #expect(snapshot.packetEndpointCreated)
    #expect(snapshot.runtimeComposed)
    #expect(snapshot.pressureRead)
    #expect(snapshot.faultOperations == [.makePacketEndpoint, .makeSSHTransport])
  }

  private func runSmoke(configuration: HarnessConfigurationDocument) async
    -> HarnessApplicationResponse
  {
    let application = try! makeApplication(commands: [SmokeHarnessCommand()])
    return await application.run(
      arguments: try! arguments(command: "smoke", configuration: configuration),
      cancellationSource: StreamHarnessCancellationSource()
    )
  }

  private func makeApplication(commands: [any HarnessCommand]) throws -> HarnessApplication {
    let dependencies = HarnessCommandDependencies(
      runtime: TunnelRuntimeDependencies(
        clock: FixedClock(),
        logger: SilentHarnessLogger(),
        metrics: HarnessMetricsStore(),
        cancellation: TaskCancellationChecker(),
        memoryPressure: NormalHarnessMemoryPressureSource()
      ),
      sshTransports: UnavailableHarnessSSHTransportFactory(),
      packetEndpoints: UnavailableHarnessPacketEndpointFactory(),
      faultPolicy: NoHarnessFaultPolicy()
    )
    return HarnessApplication(
      registry: try HarnessCommandRegistry(commands: commands),
      dependencies: dependencies,
      readPlatform: fixedPlatform
    )
  }

  private func arguments(
    command: String,
    configuration: HarnessConfigurationDocument = makeConfiguration()
  ) throws -> [String] {
    let data = try HarnessConfigurationCodec.encode(configuration)
    return [command, "--configuration-json", String(decoding: data, as: UTF8.self)]
  }

  private func expectResourcesCleaned(_ recorder: ResourceRecorder) async throws {
    let snapshot = await recorder.snapshot()
    let directory = try #require(snapshot.directory)
    let socket = try #require(snapshot.socket)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    #expect(!FileManager.default.fileExists(atPath: socket.path))
    #expect(snapshot.managedTaskCancelled)
  }
}

private func makeConfiguration(
  schemaVersion: UInt16 = HarnessConfigurationSchema.currentVersion
) -> HarnessConfigurationDocument {
  HarnessConfigurationDocument(
    schemaVersion: schemaVersion,
    seed: 42,
    sourceRevision: "0123456789abcdef",
    dependencyRevisions: ["fixture": "abcdef"],
    profileReference: HarnessConfigurationValue(
      value: "11111111-1111-1111-1111-111111111111",
      privacy: .sensitive
    ),
    parameters: [
      "destination": HarnessConfigurationValue(value: "example.test", privacy: .sensitive),
      "mode": HarnessConfigurationValue(value: "noop", privacy: .public),
    ]
  )
}

private func fixedPlatform() -> HarnessPlatformMetadata {
  HarnessPlatformMetadata(
    operatingSystem: "macOS",
    operatingSystemVersion: "test",
    architecture: "test-arch"
  )
}

private struct FixedClock: TunnelClock {
  private let instant = ContinuousClock().now

  func now() -> ContinuousClock.Instant {
    instant
  }

  func sleep(for duration: Duration) async throws {
    try await Task.sleep(for: duration)
  }
}

private actor ResourceRecorder {
  private(set) var directory: URL?
  private(set) var socket: URL?
  private(set) var managedTaskCancelled = false
  private(set) var hasStarted = false

  func record(directory: URL, socket: URL) {
    self.directory = directory
    self.socket = socket
    hasStarted = true
  }

  func recordManagedTaskCancellation() {
    managedTaskCancelled = true
  }

  func snapshot() -> (directory: URL?, socket: URL?, managedTaskCancelled: Bool) {
    (directory, socket, managedTaskCancelled)
  }
}

private struct ResourceCommand: HarnessCommand {
  let name: String
  let recorder: ResourceRecorder
  let blocks: Bool

  func run(context: HarnessCommandContext) async throws {
    let directory = try await context.resources.makeTemporaryDirectory(prefix: "relux-test")
    let marker = directory.appendingPathComponent("marker")
    try Data("fixture".utf8).write(to: marker)
    let socket = directory.appendingPathComponent("fixture.sock")
    try await context.resources.bindUnixDatagramSocket(at: socket)
    await context.resources.startTask {
      do {
        try await Task.sleep(for: .seconds(3_600))
      } catch {
        await recorder.recordManagedTaskCancellation()
      }
    }
    await recorder.record(directory: directory, socket: socket)

    if blocks {
      try await Task.sleep(for: .seconds(3_600))
    }
  }
}

private func waitUntil(
  _ predicate: @escaping @Sendable () async -> Bool
) async throws {
  for _ in 0..<10_000 {
    if await predicate() {
      return
    }
    await Task.yield()
  }
  struct TimedOut: Error {}
  throw TimedOut()
}

private struct DependencySnapshot: Sendable {
  let clockRead: Bool
  let transportCreated: Bool
  let packetEndpointCreated: Bool
  let runtimeComposed: Bool
  let pressureRead: Bool
  let faultOperations: [HarnessFaultOperation]
}

private actor DependencyRecorder {
  private var clockRead = false
  private var transportCreated = false
  private var packetEndpointCreated = false
  private var runtimeComposed = false
  private var pressureRead = false
  private var faultOperations: [HarnessFaultOperation] = []

  func recordClock() { clockRead = true }
  func recordTransport() { transportCreated = true }
  func recordPacketEndpoint() { packetEndpointCreated = true }
  func recordRuntimeComposition() { runtimeComposed = true }
  func recordPressure() { pressureRead = true }
  func recordFault(_ operation: HarnessFaultOperation) { faultOperations.append(operation) }

  func snapshot() -> DependencySnapshot {
    DependencySnapshot(
      clockRead: clockRead,
      transportCreated: transportCreated,
      packetEndpointCreated: packetEndpointCreated,
      runtimeComposed: runtimeComposed,
      pressureRead: pressureRead,
      faultOperations: faultOperations
    )
  }
}

private final class RecordingClock: TunnelClock, @unchecked Sendable {
  private let recorder: DependencyRecorder
  private let instant = ContinuousClock().now

  init(recorder: DependencyRecorder) {
    self.recorder = recorder
  }

  func now() -> ContinuousClock.Instant {
    Task { await recorder.recordClock() }
    return instant
  }

  func sleep(for duration: Duration) async throws {
    try await Task.sleep(for: duration)
  }
}

private struct RecordingPressureSource: TunnelMemoryPressureSource {
  let recorder: DependencyRecorder

  func currentPressure() async -> TunnelMemoryPressure {
    await recorder.recordPressure()
    return .critical
  }
}

private struct RecordingFaultPolicy: HarnessFaultPolicy {
  let recorder: DependencyRecorder

  func evaluate(_ operation: HarnessFaultOperation) async throws {
    await recorder.recordFault(operation)
  }
}

private struct RecordingTransportFactory: HarnessSSHTransportFactory {
  let recorder: DependencyRecorder

  func makeSSHTransport() async throws -> any SSHTransport {
    await recorder.recordTransport()
    return TestSSHTransport()
  }
}

private struct RecordingPacketFactory: HarnessPacketEndpointFactory {
  let recorder: DependencyRecorder

  func makePacketFlow() async throws -> any PacketFlow {
    await recorder.recordPacketEndpoint()
    return TestPacketFlow()
  }
}

private struct DependencyCommand: HarnessCommand {
  let name = "dependencies"
  let recorder: DependencyRecorder

  func run(context: HarnessCommandContext) async throws {
    _ = context.dependencies.runtime.clock.now()
    _ = await context.dependencies.runtime.memoryPressure.currentPressure()
    let composition = HarnessCoreComposition(dependencies: context.dependencies)
    let runtime = try await composition.makeRuntime(
      configuration: try context.configuration.tunnelConfiguration(),
      factory: RecordingRuntimeFactory(recorder: recorder)
    )
    try await runtime.start()
    let transport = try await composition.makeSSHTransport()
    await transport.close()
  }
}

private struct RecordingRuntimeFactory: TunnelRuntimeFactory {
  let recorder: DependencyRecorder

  func makeRuntime(context: TunnelRuntimeContext) async throws -> any TunnelRuntime {
    _ = try await context.packetFlow.readPackets()
    await recorder.recordRuntimeComposition()
    return TestRuntime()
  }
}

private actor TestRuntime: TunnelRuntime {
  func start() async throws {}
  func stop(reason: ProviderStopReason) async {}
  func lifecycleState() async -> TunnelLifecycleState { .disconnected }
}

private actor TestPacketFlow: PacketFlow {
  func readPackets() async throws -> PacketReadBatch { PacketReadBatch(results: []) }
  func writePackets(_ packets: [TunnelPacket]) async throws {}
}

private actor TestSSHTransport: SSHTransport {
  private let lane = SSHLaneIdentity(
    rawValue: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
  )

  func connect(configuration: SSHConnectionConfiguration) async throws -> SSHSession {
    throw HarnessUnavailableDependencyError.sshTransport
  }

  func openDirectTCPIP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint,
    policy: SSHChannelPolicy
  ) async throws -> any SSHByteChannel {
    throw HarnessUnavailableDependencyError.sshTransport
  }

  func openExecChannel(
    request: SSHExecRequest,
    policy: SSHChannelPolicy
  ) async throws -> any SSHExecChannel {
    throw HarnessUnavailableDependencyError.sshTransport
  }

  func upload(_ request: SSHExecUploadRequest) async throws -> SSHExecExit {
    throw HarnessUnavailableDependencyError.sshTransport
  }

  func requestRekey(reason: SSHClientRekeyReason) async throws {}

  func sendKeepalive() async throws -> SSHDeferredSemanticReport<Duration> { .unsupported }

  func snapshot() -> SSHTransportSnapshot {
    SSHTransportSnapshot(
      lane: lane,
      connectionState: .idle,
      negotiatedAlgorithms: nil,
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

  func close() {}
}
