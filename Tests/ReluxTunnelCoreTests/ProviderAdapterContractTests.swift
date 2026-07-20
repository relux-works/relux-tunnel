import Foundation
import ReluxTunnelCore
import ReluxTunnelIOSAdapter
import ReluxTunnelMacOSAdapter
import Testing

@Suite("Provider adapter contracts")
struct ProviderAdapterContractTests {
  @Test("both provider adapters link the pinned native fixture")
  func nativePackagingAnchors() {
    #expect(IOSNativePackagingAnchor.schemaVersion == 1)
    #expect(MacOSNativePackagingAnchor.schemaVersion == 1)
    #expect(IOSNativePackagingAnchor.hevLinkageSmoke())
    #expect(MacOSNativePackagingAnchor.hevLinkageSmoke())
  }

  @Test("both roots route exactly the four read-only v1 commands", arguments: AdapterSeam.allCases)
  func readOnlyRouting(seam: AdapterSeam) async throws {
    let fixture = try await ProviderFixture.make(seam: seam)
    try await fixture.root.start(configuration: testConfiguration)
    await fixture.publishSnapshot(generation: 42, sequence: 7)

    let protocolID = requestID(1)
    let protocolData = try await fixture.root.handleAppMessage(
      RuntimeMessageCodec.encode(
        RuntimeCommand(kind: .getProtocolCapabilities, requestID: protocolID)
      )
    )
    let protocolSnapshot = try RuntimeMessageCodec.decodeProtocolCapabilities(protocolData)
    #expect(protocolSnapshot.requestID == protocolID)
    #expect(
      Set(protocolSnapshot.kinds.map(\.kind))
        == Set([
          .getProtocolCapabilities, .getRuntimeSnapshot, .getCapabilities, .getDiagnostics,
          .protocolCapabilities, .runtimeSnapshot, .capabilitySnapshot, .diagnosticsSnapshot,
          .protocolError,
        ])
    )
    #expect(!protocolSnapshot.kinds.contains { $0.kind == .configurationSnapshot })

    let runtimeID = requestID(2)
    let runtime = try RuntimeMessageCodec.decodeLifecycleSnapshot(
      await fixture.send(kind: .getRuntimeSnapshot, requestID: runtimeID)
    )
    #expect(runtime.requestID == runtimeID)
    #expect(runtime.runtimeGeneration == 42)
    #expect(runtime.snapshotSequence == 7)

    let capabilityID = requestID(3)
    let capabilities = try RuntimeMessageCodec.decodeCapabilitySnapshot(
      await fixture.send(kind: .getCapabilities, requestID: capabilityID)
    )
    #expect(capabilities.requestID == capabilityID)
    #expect(capabilities.tcp)
    #expect(capabilities.safeDNS)
    #expect(!capabilities.udp)

    let diagnosticsID = requestID(4)
    let diagnostics = try RuntimeMessageCodec.decodeDiagnosticsSnapshot(
      await fixture.send(kind: .getDiagnostics, requestID: diagnosticsID)
    )
    #expect(diagnostics.requestID == diagnosticsID)
    #expect(diagnostics.runtimeGeneration == 42)
    let diagnosticJSON = String(
      decoding: try RuntimeMessageCodec.encode(diagnostics), as: UTF8.self)
    #expect(!diagnosticJSON.contains("example.com"))
    #expect(!diagnosticJSON.contains("private_key"))

    for response in [
      protocolData, try RuntimeMessageCodec.encode(runtime),
      try RuntimeMessageCodec.encode(capabilities), try RuntimeMessageCodec.encode(diagnostics),
    ] {
      #expect(response.count <= RuntimeMessageSizeLimit.diagnosticsSnapshot)
      #expect(!String(decoding: response, as: UTF8.self).contains("secret"))
    }

    var rollingResponse = Data()
    for index in 0..<300 {
      rollingResponse = await fixture.send(
        kind: .getProtocolCapabilities,
        requestID: requestID(UInt16(index + 1_000))
      )
    }
    #expect(
      try RuntimeMessageCodec.decodeProtocolCapabilities(rollingResponse).kind
        == .protocolCapabilities
    )
    await fixture.root.stop(reason: .system)
  }

  @Test(
    "malformed future mutating and missing-request inputs receive one bounded error",
    arguments: AdapterSeam.allCases
  )
  func strictRoutingErrors(seam: AdapterSeam) async throws {
    let fixture = try await ProviderFixture.make(seam: seam)
    try await fixture.root.start(configuration: testConfiguration)

    let cases: [(Data, RuntimeProtocolErrorCode)] = [
      (Data("{".utf8), .corruptPayload),
      (
        Data(repeating: UInt8(ascii: "x"), count: RuntimeMessageSizeLimit.command + 1),
        .payloadTooLarge
      ),
      (
        Data(
          #"{"kind":"getCapabilities","kind":"getDiagnostics","protocolVersion":1,"requestID":"00000000-0000-0000-0000-000000000010","schemaVersion":1}"#
            .utf8
        ),
        .duplicateKey
      ),
      (
        Data(
          #"{"kind":"setConfiguration","protocolVersion":1,"requestID":"00000000-0000-0000-0000-000000000011","schemaVersion":1}"#
            .utf8
        ),
        .unsupportedKind
      ),
      (
        Data(
          #"{"kind":"getCapabilities","protocolVersion":2,"requestID":"00000000-0000-0000-0000-000000000012","schemaVersion":1}"#
            .utf8
        ),
        .unsupportedProtocolVersion
      ),
      (
        Data(
          #"{"kind":"getCapabilities","protocolVersion":1,"requestID":"00000000-0000-0000-0000-000000000013","schemaVersion":2}"#
            .utf8
        ),
        .unsupportedSchemaVersion
      ),
      (
        try RuntimeMessageCodec.encode(RuntimeCommand(kind: .getCapabilities)),
        .unsupportedValue
      ),
    ]

    for (payload, expectedCode) in cases {
      let probe = CallbackProbe<Data>()
      fixture.root.handleAppMessage(payload) { probe.record($0) }
      let response = await probe.next()
      #expect(try RuntimeMessageCodec.decodeProtocolError(response).code == expectedCode)
      #expect(response.count <= RuntimeMessageSizeLimit.protocolError)
      #expect(probe.count == 1)
    }

    await fixture.root.stop(reason: .system)
  }

  @Test(
    "duplicate concurrent nil-handler and retired-generation callbacks stay isolated",
    arguments: AdapterSeam.allCases
  )
  func concurrentAndRetiredRouting(seam: AdapterSeam) async throws {
    let sourceGate = AsyncGate()
    let snapshotSource = GatedSnapshotSource(gate: sourceGate)
    let fixture = try await ProviderFixture.make(seam: seam, snapshotSource: snapshotSource)
    await snapshotSource.set(snapshot(generation: 50, sequence: 1))
    try await fixture.root.start(configuration: testConfiguration)

    let identifier = requestID(20)
    let command = try RuntimeMessageCodec.encode(
      RuntimeCommand(kind: .getCapabilities, requestID: identifier)
    )
    let first = CallbackProbe<Data>()
    fixture.root.handleAppMessage(command) { first.record($0) }
    await snapshotSource.waitUntilRequested()

    let duplicate = CallbackProbe<Data>()
    fixture.root.handleAppMessage(command) { duplicate.record($0) }
    let duplicateError = try RuntimeMessageCodec.decodeProtocolError(await duplicate.next())
    #expect(duplicateError.requestID == identifier)
    #expect(duplicateError.code == .unsupportedValue)
    #expect(duplicate.count == 1)

    fixture.root.handleAppMessage(command, responseHandler: nil)
    await fixture.root.stop(reason: .system)

    let retired = try RuntimeMessageCodec.decodeProtocolError(await first.next())
    #expect(retired.requestID == identifier)
    #expect(retired.code == .unsupportedValue)
    #expect(first.count == 1)
    await sourceGate.open()

    await snapshotSource.set(snapshot(generation: 51, sequence: 0))
    try await fixture.root.start(configuration: testConfiguration)
    let acceptedAgain = try RuntimeMessageCodec.decodeCapabilitySnapshot(
      try await fixture.root.handleAppMessage(command)
    )
    #expect(acceptedAgain.runtimeGeneration == 51)
    await fixture.root.stop(reason: .system)
  }

  @Test("every public Apple stop reason maps identically", arguments: AdapterSeam.allCases)
  func appleStopReasons(seam: AdapterSeam) async throws {
    let recorder = RuntimeRecorder()
    let fixture = try await ProviderFixture.make(
      seam: seam,
      runtimeFactory: TestRuntimeFactory {
        TestRuntime(recorder: recorder)
      }
    )

    for rawReason in Array(0...17) + [99] {
      try await fixture.root.start(configuration: testConfiguration)
      await stop(root: fixture.root, rawReason: rawReason)
      let expected: ProviderStopReason
      switch rawReason {
      case 1: expected = .userInitiated
      case 2: expected = .providerFailure
      default: expected = .platform(code: rawReason)
      }
      #expect(await recorder.lastStopReason() == expected)
    }
  }

  @Test(
    "stop during start completes start before stop and maps startup Apple reasons",
    arguments: AdapterSeam.allCases, [7, 14]
  )
  func stopWinsStart(seam: AdapterSeam, rawReason: Int) async throws {
    let events = CallbackOrderRecorder()
    let startGate = AsyncGate()
    let runtime = TestRuntime(startGate: startGate, cancelReleasesStart: true)
    let fixture = try await ProviderFixture.make(
      seam: seam,
      runtimeFactory: TestRuntimeFactory { runtime }
    )

    fixture.root.start(configuration: testConfiguration) { error in
      events.record(.start(error?.code))
    }
    await runtime.waitUntilStartEntered()
    fixture.root.stop(rawReason: rawReason) {
      events.record(.stop)
    }

    await events.waitForCount(2)
    #expect(events.events == [.start(ProviderNSErrorCode.startCancelled.rawValue), .stop])
    #expect(await runtime.stopReason() == .startupFailure)
    #expect(await fixture.root.lifecyclePhase() == .idle)
  }

  @Test(
    "the injected 60-second startup budget cancels and joins rollback",
    arguments: AdapterSeam.allCases)
  func startupDeadline(seam: AdapterSeam) async throws {
    let clock = ManualProviderClock()
    let startGate = AsyncGate()
    let runtime = TestRuntime(startGate: startGate, cancelReleasesStart: true)
    let fixture = try await ProviderFixture.make(
      seam: seam,
      runtimeFactory: TestRuntimeFactory { runtime },
      clock: clock
    )

    let completion = CallbackProbe<NSError?>()
    fixture.root.start(configuration: testConfiguration) { completion.record($0) }
    await runtime.waitUntilStartEntered()
    await clock.waitUntilRegistered(.seconds(60))
    clock.fire(.seconds(60))
    let error = await completion.next()

    #expect(error?.domain == ProviderNSErrorCode.errorDomain)
    #expect(error?.code == ProviderNSErrorCode.startupTimedOut.rawValue)
    #expect(await runtime.stopReason() == .startupFailure)
    #expect(completion.count == 1)
    #expect(await fixture.root.lifecyclePhase() == .idle)
  }

  @Test(
    "cleanup expiry force-closes handles and records redacted evidence",
    arguments: AdapterSeam.allCases)
  func cleanupDeadline(seam: AdapterSeam) async throws {
    let clock = ManualProviderClock()
    let stopGate = AsyncGate()
    let runtime = TestRuntime(stopGate: stopGate)
    let fixture = try await ProviderFixture.make(
      seam: seam,
      runtimeFactory: TestRuntimeFactory { runtime },
      clock: clock,
      cleanupBudget: .seconds(10)
    )
    try await fixture.root.start(configuration: testConfiguration)

    let completion = CallbackProbe<Void>()
    fixture.root.stop(rawReason: 17) { completion.record(()) }
    await runtime.waitUntilStopEntered()
    await clock.waitUntilRegistered(.seconds(10))
    clock.fire(.seconds(10))
    _ = await completion.next()

    #expect(runtime.forceCloseCount == 1)
    #expect(runtime.cancelCount >= 1)
    #expect(completion.count == 1)
    #expect(await fixture.root.lifecyclePhase() == .idle)
    let diagnostics = try fixture.diagnosticsStore.snapshot()
    #expect(diagnostics.gauges["provider_stop_reason_code"] == 17)
    #expect(diagnostics.counters["provider_cleanup_deadline_exceeded_total"] == 1)
    #expect(
      diagnostics.errors.contains {
        $0.domain == .runtimeInvariant && $0.code.rawValue == "cleanup_deadline_exceeded"
      }
    )
  }

  @Test(
    "provider failure cancels once and later system stop joins cleanup",
    arguments: AdapterSeam.allCases
  )
  func providerFailureHandoff(seam: AdapterSeam) async throws {
    let stopGate = AsyncGate()
    let runtime = TestRuntime(stopGate: stopGate)
    let fixture = try await ProviderFixture.make(
      seam: seam,
      runtimeFactory: TestRuntimeFactory { runtime }
    )
    try await fixture.root.start(configuration: testConfiguration)

    let cancellation = CallbackProbe<NSError>()
    fixture.root.providerDidFail(.runtimeStartupFailed) { cancellation.record($0) }
    fixture.root.providerDidFail(.internalInvariant) { cancellation.record($0) }
    let error = await cancellation.next()
    #expect(error.domain == ProviderNSErrorCode.errorDomain)
    #expect(error.code == ProviderNSErrorCode.runtimeStartupFailed.rawValue)
    #expect(error.userInfo.isEmpty)
    await runtime.waitUntilStopEntered()

    let stopped = CallbackProbe<Void>()
    fixture.root.stop(rawReason: 2) { stopped.record(()) }
    await stopGate.open()
    _ = await stopped.next()

    #expect(cancellation.count == 1)
    #expect(stopped.count == 1)
    #expect(await runtime.stopReason() == .providerFailure)
    #expect(await fixture.root.lifecyclePhase() == .idle)
  }

  @Test(
    "one hundred cycles release every runtime and callback gate", arguments: AdapterSeam.allCases)
  func repeatedLifecycleBaseline(seam: AdapterSeam) async throws {
    let ledger = LifetimeLedger()
    let fixture = try await ProviderFixture.make(
      seam: seam,
      runtimeFactory: TestRuntimeFactory {
        TestRuntime(ledger: ledger)
      }
    )

    for cycle in 0..<100 {
      try await fixture.root.start(configuration: testConfiguration)
      await fixture.root.stop(reason: .system)
      await ledger.waitUntilDestroyed(cycle + 1)
      #expect(ledger.active == 0)
    }
    #expect(ledger.created == 100)
    #expect(ledger.destroyed == 100)
    #expect(await fixture.root.lifecyclePhase() == .idle)
  }
}

enum AdapterSeam: String, CaseIterable, CustomTestStringConvertible {
  case iOS
  case macOS

  var testDescription: String { rawValue }
}

private struct ProviderFixture {
  let root: any TunnelProviderLifecycle
  let snapshotStore: LatestRuntimeSnapshotStore
  let diagnosticsStore: RuntimeDiagnosticsStore

  static func make(
    seam: AdapterSeam,
    runtimeFactory: any TunnelRuntimeFactory = TestRuntimeFactory { TestRuntime() },
    snapshotSource: (any ProviderRuntimeSnapshotSource)? = nil,
    clock: any TunnelClock = ContinuousTunnelClock(),
    cleanupBudget: Duration = .seconds(10)
  ) async throws -> ProviderFixture {
    let snapshotStore = LatestRuntimeSnapshotStore()
    let diagnosticsStore = RuntimeDiagnosticsStore(runtimeGeneration: 42)
    let diagnosticsRecorder = diagnosticsStore.recorder()
    let source = snapshotSource ?? snapshotStore
    let dependencies = testDependencies(clock: clock)
    let root: any TunnelProviderLifecycle
    switch seam {
    case .iOS:
      root = IOSProviderCompositionRoot(
        packetFlow: TestPacketFlow(),
        runtimeFactory: runtimeFactory,
        dependencies: dependencies,
        snapshotSource: source,
        diagnosticsSource: diagnosticsStore,
        lifecycleDiagnostics: diagnosticsRecorder,
        cleanupBudget: cleanupBudget
      )
    case .macOS:
      root = MacOSProviderCompositionRoot(
        packetFlow: TestPacketFlow(),
        runtimeFactory: runtimeFactory,
        dependencies: dependencies,
        snapshotSource: source,
        diagnosticsSource: diagnosticsStore,
        lifecycleDiagnostics: diagnosticsRecorder,
        cleanupBudget: cleanupBudget
      )
    }
    return ProviderFixture(
      root: root,
      snapshotStore: snapshotStore,
      diagnosticsStore: diagnosticsStore
    )
  }

  func publishSnapshot(generation: UInt64, sequence: UInt64) async {
    await snapshotStore.publish(snapshot(generation: generation, sequence: sequence))
  }

  func send(kind: RuntimeCommandKind, requestID: OpaqueRuntimeRequestIdentifier) async -> Data {
    do {
      return try await root.handleAppMessage(
        RuntimeMessageCodec.encode(RuntimeCommand(kind: kind, requestID: requestID))
      )
    } catch {
      Issue.record("Unexpected app-message error: \(error)")
      return Data()
    }
  }
}

private func snapshot(generation: UInt64, sequence: UInt64) -> TunnelRuntimePublishedSnapshot {
  TunnelRuntimePublishedSnapshot(
    lifecycle: RuntimeLifecycleSnapshot(
      runtimeGeneration: generation,
      snapshotSequence: sequence,
      lifecycleState: .connectedDegraded,
      routeState: .installed,
      tcp: true,
      safeDNS: true,
      udp: false,
      routeMode: .compatible,
      routesInstalled: true,
      healthy: true
    ),
    capabilities: RuntimeCapabilitySnapshot(
      runtimeGeneration: generation,
      snapshotSequence: sequence,
      tcp: true,
      safeDNS: true,
      udp: false,
      routeMode: .compatible,
      routesInstalled: true,
      healthy: true
    )
  )
}

private let testConfiguration = TunnelConfiguration(
  profileReference: TunnelConfigurationReference(
    profileIdentifier: OpaqueProfileIdentifier(
      UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    )
  )
)

private func requestID(_ suffix: UInt16) -> OpaqueRuntimeRequestIdentifier {
  var uuid = UUID().uuid
  uuid.14 = UInt8(truncatingIfNeeded: suffix >> 8)
  uuid.15 = UInt8(truncatingIfNeeded: suffix)
  return OpaqueRuntimeRequestIdentifier(UUID(uuid: uuid))
}

private func stop(root: any TunnelProviderLifecycle, rawReason: Int) async {
  let completion = CallbackProbe<Void>()
  root.stop(rawReason: rawReason) { completion.record(()) }
  _ = await completion.next()
  #expect(completion.count == 1)
}

private final class TestRuntimeFactory: TunnelRuntimeFactory, @unchecked Sendable {
  private let makeRuntime: @Sendable () -> TestRuntime

  init(_ makeRuntime: @escaping @Sendable () -> TestRuntime) {
    self.makeRuntime = makeRuntime
  }

  func makeRuntime(context: TunnelRuntimeContext) async throws -> any TunnelRuntime {
    let runtime = makeRuntime()
    context.cleanupRegistry.register(runtime)
    return runtime
  }
}

private final class TestRuntime: TunnelRuntime, ProviderCleanupControllable, @unchecked Sendable {
  private let lock = NSLock()
  private let startEntered = AsyncChannel<Void>()
  private let stopEntered = AsyncChannel<Void>()
  private let startGate: AsyncGate?
  private let stopGate: AsyncGate?
  private let cancelReleasesStart: Bool
  private let recorder: RuntimeRecorder?
  private let ledger: LifetimeLedger?
  private var recordedStopReason: ProviderStopReason?
  private var _cancelCount = 0
  private var _forceCloseCount = 0

  init(
    startGate: AsyncGate? = nil,
    stopGate: AsyncGate? = nil,
    cancelReleasesStart: Bool = false,
    recorder: RuntimeRecorder? = nil,
    ledger: LifetimeLedger? = nil
  ) {
    self.startGate = startGate
    self.stopGate = stopGate
    self.cancelReleasesStart = cancelReleasesStart
    self.recorder = recorder
    self.ledger = ledger
    ledger?.createdRuntime()
  }

  deinit {
    ledger?.destroyedRuntime()
  }

  func start() async throws {
    await startEntered.send(())
    if let startGate { await startGate.wait() }
  }

  func stop(reason: ProviderStopReason) async {
    lock.withLock { recordedStopReason = reason }
    await recorder?.recordStop(reason)
    await stopEntered.send(())
    if let stopGate { await stopGate.wait() }
  }

  func lifecycleState() async -> TunnelLifecycleState { .disconnected }

  func cancelProviderWork() {
    lock.withLock { _cancelCount += 1 }
    if cancelReleasesStart {
      Task { await startGate?.open() }
    }
  }

  func forceCloseProviderHandle() {
    lock.withLock { _forceCloseCount += 1 }
    Task {
      await startGate?.open()
      await stopGate?.open()
    }
  }

  func waitUntilStartEntered() async { _ = await startEntered.next() }
  func waitUntilStopEntered() async { _ = await stopEntered.next() }
  func stopReason() async -> ProviderStopReason? { lock.withLock { recordedStopReason } }

  var cancelCount: Int { lock.withLock { _cancelCount } }
  var forceCloseCount: Int { lock.withLock { _forceCloseCount } }
}

private actor RuntimeRecorder {
  private var stopReasons: [ProviderStopReason] = []

  func recordStop(_ reason: ProviderStopReason) {
    stopReasons.append(reason)
  }

  func lastStopReason() -> ProviderStopReason? { stopReasons.last }
}

private actor GatedSnapshotSource: ProviderRuntimeSnapshotSource {
  private let gate: AsyncGate
  private let requested = AsyncChannel<Void>()
  private var value: TunnelRuntimePublishedSnapshot?

  init(gate: AsyncGate) {
    self.gate = gate
  }

  func set(_ value: TunnelRuntimePublishedSnapshot) {
    self.value = value
  }

  func latestProviderSnapshot() async -> TunnelRuntimePublishedSnapshot? {
    await requested.send(())
    await gate.wait()
    return value
  }

  func waitUntilRequested() async { _ = await requested.next() }
}

private actor AsyncGate {
  private var isOpen = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func wait() async {
    guard !isOpen else { return }
    await withCheckedContinuation { waiters.append($0) }
  }

  func open() {
    isOpen = true
    let waiters = self.waiters
    self.waiters.removeAll()
    for waiter in waiters { waiter.resume() }
  }
}

private actor AsyncChannel<Value: Sendable> {
  private var values: [Value] = []
  private var waiters: [CheckedContinuation<Value, Never>] = []

  func send(_ value: Value) {
    if waiters.isEmpty {
      values.append(value)
    } else {
      waiters.removeFirst().resume(returning: value)
    }
  }

  func next() async -> Value {
    if !values.isEmpty { return values.removeFirst() }
    return await withCheckedContinuation { waiters.append($0) }
  }
}

private final class CallbackProbe<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private let channel = AsyncChannel<Value>()
  private var _count = 0

  func record(_ value: Value) {
    lock.withLock { _count += 1 }
    Task { await channel.send(value) }
  }

  func next() async -> Value { await channel.next() }
  var count: Int { lock.withLock { _count } }
}

private enum CallbackEvent: Equatable, Sendable {
  case start(Int?)
  case stop
}

private final class CallbackOrderRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private let changed = AsyncChannel<Void>()
  private var _events: [CallbackEvent] = []

  func record(_ event: CallbackEvent) {
    lock.withLock { _events.append(event) }
    Task { await changed.send(()) }
  }

  func waitForCount(_ count: Int) async {
    while events.count < count { _ = await changed.next() }
  }

  var events: [CallbackEvent] { lock.withLock { _events } }
}

private final class ManualProviderClock: TunnelClock, @unchecked Sendable {
  private let lock = NSLock()
  private var sleepers: [Duration: [UUID: CheckedContinuation<Void, any Error>]] = [:]
  private var registrationWaiters: [Duration: [CheckedContinuation<Void, Never>]] = [:]
  private let instant = ContinuousClock().now

  func now() -> ContinuousClock.Instant { instant }

  func sleep(for duration: Duration) async throws {
    let identifier = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, any Error>) in
        let waiters: [CheckedContinuation<Void, Never>] = lock.withLock {
          if Task<Never, Never>.isCancelled {
            continuation.resume(throwing: CancellationError())
            return []
          }
          sleepers[duration, default: [:]][identifier] = continuation
          return registrationWaiters.removeValue(forKey: duration) ?? []
        }
        for waiter in waiters { waiter.resume() }
      }
    } onCancel: {
      let continuation = self.lock.withLock {
        self.sleepers[duration]?.removeValue(forKey: identifier)
      }
      continuation?.resume(throwing: CancellationError())
    }
  }

  func waitUntilRegistered(_ duration: Duration) async {
    let alreadyRegistered = lock.withLock {
      !(sleepers[duration]?.isEmpty ?? true)
    }
    if alreadyRegistered { return }
    await withCheckedContinuation { continuation in
      let resumeNow = lock.withLock {
        if !(sleepers[duration]?.isEmpty ?? true) { return true }
        registrationWaiters[duration, default: []].append(continuation)
        return false
      }
      if resumeNow { continuation.resume() }
    }
  }

  func fire(_ duration: Duration) {
    let continuations = lock.withLock {
      Array(sleepers.removeValue(forKey: duration)?.values ?? [:].values)
    }
    for continuation in continuations { continuation.resume() }
  }
}

private final class LifetimeLedger: @unchecked Sendable {
  private let lock = NSLock()
  private let destructionEvents = AsyncChannel<Void>()
  private var _created = 0
  private var _destroyed = 0

  func createdRuntime() { lock.withLock { _created += 1 } }
  func destroyedRuntime() {
    lock.withLock { _destroyed += 1 }
    Task { await destructionEvents.send(()) }
  }

  func waitUntilDestroyed(_ target: Int) async {
    while destroyed < target { _ = await destructionEvents.next() }
  }
  var created: Int { lock.withLock { _created } }
  var destroyed: Int { lock.withLock { _destroyed } }
  var active: Int { lock.withLock { _created - _destroyed } }
}

private actor TestPacketFlow: PacketFlow {
  func readPackets() async throws -> PacketReadBatch { PacketReadBatch(results: []) }
  func writePackets(_ packets: [TunnelPacket]) async throws {}
}

private struct TestLogger: TunnelLogger {
  func log(level: TunnelLogLevel, message: String, fields: [String: TunnelLogField]) {}
}

private actor TestMetrics: TunnelMetrics {
  func incrementCounter(named name: String, by amount: UInt64) {}
  func setGauge(named name: String, to value: Int64) {}
  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: [:], gauges: [:])
  }
}

private struct TestMemoryPressureSource: TunnelMemoryPressureSource {
  func currentPressure() async -> TunnelMemoryPressure { .normal }
}

private func testDependencies(clock: any TunnelClock) -> TunnelRuntimeDependencies {
  TunnelRuntimeDependencies(
    clock: clock,
    logger: TestLogger(),
    metrics: TestMetrics(),
    cancellation: TaskCancellationChecker(),
    memoryPressure: TestMemoryPressureSource()
  )
}
