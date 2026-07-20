import Foundation
import ReluxTunnelCore
import ReluxTunnelIOSAdapter
import ReluxTunnelMacOSAdapter
import Testing

@Suite("Provider adapter contracts")
struct ProviderAdapterContractTests {
  @Test("iOS root satisfies the shared lifecycle contract")
  func iOSLifecycleContract() async throws {
    try await exerciseLifecycleContract { packetFlow, factory, dependencies in
      IOSProviderCompositionRoot(
        packetFlow: packetFlow,
        runtimeFactory: factory,
        dependencies: dependencies
      )
    }
  }

  @Test("macOS root satisfies the shared lifecycle contract")
  func macOSLifecycleContract() async throws {
    try await exerciseLifecycleContract { packetFlow, factory, dependencies in
      MacOSProviderCompositionRoot(
        packetFlow: packetFlow,
        runtimeFactory: factory,
        dependencies: dependencies
      )
    }
  }

  @Test("both roots return the same version message")
  func sharedVersionMessageContract() async throws {
    let iOS = makeIOSRoot()
    let macOS = makeMacOSRoot()
    let request = try ProviderMessageCodec.encodeVersionRequest()

    let iOSData = try await iOS.handleAppMessage(request)
    let macOSData = try await macOS.handleAppMessage(request)

    #expect(iOSData == macOSData)
    #expect(
      try ProviderMessageCodec.decodeVersionResponse(iOSData)
        == ProviderVersionResponse(protocolVersion: ProviderMessageCodec.currentVersion)
    )
  }

  @Test("both provider adapters link the pinned native fixture")
  func nativePackagingAnchors() {
    #expect(IOSNativePackagingAnchor.schemaVersion == 1)
    #expect(MacOSNativePackagingAnchor.schemaVersion == 1)
  }

  @Test("both roots reject unsupported message versions")
  func unsupportedVersionContract() async throws {
    let request = try ProviderMessageCodec.encodeVersionRequest(protocolVersion: 999)

    await #expect(throws: ProviderMessageError.unsupportedProtocolVersion(999)) {
      try await makeIOSRoot().handleAppMessage(request)
    }
    await #expect(throws: ProviderMessageError.unsupportedProtocolVersion(999)) {
      try await makeMacOSRoot().handleAppMessage(request)
    }
  }

  private func exerciseLifecycleContract(
    makeRoot: (
      any PacketFlow,
      any TunnelRuntimeFactory,
      TunnelRuntimeDependencies
    ) -> any TunnelProviderLifecycle
  ) async throws {
    let recorder = RuntimeRecorder()
    let packetFlow = MockPacketFlow()
    let factory = MockRuntimeFactory(recorder: recorder, expectedPacketFlow: packetFlow)
    let root = makeRoot(packetFlow, factory, testDependencies())
    let configuration = TunnelConfiguration(
      profileReference: TunnelConfigurationReference(rawValue: "profile-ref"),
      parameters: ["fixture": "contract"]
    )

    #expect(await root.lifecyclePhase() == .idle)
    try await root.start(configuration: configuration)
    #expect(await root.lifecyclePhase() == .running)

    await root.stop(reason: .platform(code: 7))
    #expect(await root.lifecyclePhase() == .idle)

    let snapshot = await recorder.snapshot()
    #expect(snapshot.configuration == configuration)
    #expect(snapshot.receivedExpectedPacketFlow)
    #expect(snapshot.events == [.started, .stopped(.platform(code: 7))])
  }

  private func makeIOSRoot() -> IOSProviderCompositionRoot {
    IOSProviderCompositionRoot(
      packetFlow: MockPacketFlow(),
      runtimeFactory: MockRuntimeFactory(recorder: RuntimeRecorder()),
      dependencies: testDependencies()
    )
  }

  private func makeMacOSRoot() -> MacOSProviderCompositionRoot {
    MacOSProviderCompositionRoot(
      packetFlow: MockPacketFlow(),
      runtimeFactory: MockRuntimeFactory(recorder: RuntimeRecorder()),
      dependencies: testDependencies()
    )
  }
}

private enum RuntimeEvent: Equatable, Sendable {
  case started
  case stopped(ProviderStopReason)
}

private struct RuntimeSnapshot: Sendable {
  let events: [RuntimeEvent]
  let configuration: TunnelConfiguration?
  let receivedExpectedPacketFlow: Bool
}

private actor RuntimeRecorder {
  private var events: [RuntimeEvent] = []
  private var configuration: TunnelConfiguration?
  private var receivedExpectedPacketFlow = false

  func recordContext(_ context: TunnelRuntimeContext, expectedPacketFlow: any PacketFlow) {
    configuration = context.configuration
    receivedExpectedPacketFlow = context.packetFlow === expectedPacketFlow
  }

  func record(_ event: RuntimeEvent) {
    events.append(event)
  }

  func snapshot() -> RuntimeSnapshot {
    RuntimeSnapshot(
      events: events,
      configuration: configuration,
      receivedExpectedPacketFlow: receivedExpectedPacketFlow
    )
  }
}

private final class MockRuntime: TunnelRuntime, Sendable {
  let recorder: RuntimeRecorder

  init(recorder: RuntimeRecorder) {
    self.recorder = recorder
  }

  func start() async throws {
    await recorder.record(.started)
  }

  func stop(reason: ProviderStopReason) async {
    await recorder.record(.stopped(reason))
  }

  func lifecycleState() async -> TunnelLifecycleState {
    .disconnected
  }
}

private struct MockRuntimeFactory: TunnelRuntimeFactory {
  let recorder: RuntimeRecorder
  let expectedPacketFlow: (any PacketFlow)?

  init(recorder: RuntimeRecorder, expectedPacketFlow: (any PacketFlow)? = nil) {
    self.recorder = recorder
    self.expectedPacketFlow = expectedPacketFlow
  }

  func makeRuntime(context: TunnelRuntimeContext) async throws -> any TunnelRuntime {
    if let expectedPacketFlow {
      await recorder.recordContext(context, expectedPacketFlow: expectedPacketFlow)
    }
    return MockRuntime(recorder: recorder)
  }
}

private actor MockPacketFlow: PacketFlow {
  func readPackets() async throws -> PacketReadBatch {
    PacketReadBatch(results: [])
  }

  func writePackets(_ packets: [TunnelPacket]) async throws {}
}

private struct TestLogger: TunnelLogger {
  func log(
    level: TunnelLogLevel,
    message: String,
    fields: [String: TunnelLogField]
  ) {}
}

private actor TestMetrics: TunnelMetrics {
  func incrementCounter(named name: String, by amount: UInt64) {}
  func setGauge(named name: String, to value: Int64) {}

  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: [:], gauges: [:])
  }
}

private struct TestMemoryPressureSource: TunnelMemoryPressureSource {
  func currentPressure() async -> TunnelMemoryPressure {
    .normal
  }
}

private func testDependencies() -> TunnelRuntimeDependencies {
  TunnelRuntimeDependencies(
    clock: ContinuousTunnelClock(),
    logger: TestLogger(),
    metrics: TestMetrics(),
    cancellation: TaskCancellationChecker(),
    memoryPressure: TestMemoryPressureSource()
  )
}
