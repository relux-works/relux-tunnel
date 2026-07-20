import Foundation
import ReluxTunnelCore
import Testing

@Suite("Versioned runtime message codecs")
struct RuntimeMessageCodecTests {
  @Test("all v1 provider and message models round-trip deterministically")
  func roundTrips() throws {
    let referenceData = try RuntimeConfigurationCodec.encode(
      RuntimeMessageFixtures.configurationReference
    )
    #expect(
      try RuntimeConfigurationCodec.decodeReference(referenceData)
        == RuntimeMessageFixtures.configurationReference
    )

    let startData = try RuntimeConfigurationCodec.encode(RuntimeMessageFixtures.startRequest)
    #expect(
      try RuntimeConfigurationCodec.decodeStartRequest(startData)
        == RuntimeMessageFixtures.startRequest
    )

    let configurationData = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.configuration)
    #expect(
      try RuntimeMessageCodec.decodeConfigurationSnapshot(configurationData)
        == RuntimeMessageFixtures.configuration
    )

    let commandData = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.command)
    #expect(try RuntimeMessageCodec.decodeCommand(commandData) == RuntimeMessageFixtures.command)

    let protocolCapabilitiesData = try RuntimeMessageCodec.encode(
      RuntimeMessageFixtures.protocolCapabilities
    )
    #expect(
      try RuntimeMessageCodec.decodeProtocolCapabilities(protocolCapabilitiesData)
        == RuntimeMessageFixtures.protocolCapabilities
    )

    let capabilitiesData = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.capabilities)
    #expect(
      try RuntimeMessageCodec.decodeCapabilitySnapshot(capabilitiesData)
        == RuntimeMessageFixtures.capabilities
    )

    let lifecycleData = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.lifecycle)
    #expect(
      try RuntimeMessageCodec.decodeLifecycleSnapshot(lifecycleData)
        == RuntimeMessageFixtures.lifecycle
    )

    let diagnosticsData = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.diagnostics)
    #expect(
      try RuntimeMessageCodec.decodeDiagnosticsSnapshot(diagnosticsData)
        == RuntimeMessageFixtures.diagnostics
    )

    let errorData = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.protocolError)
    #expect(
      try RuntimeMessageCodec.decodeProtocolError(errorData)
        == RuntimeMessageFixtures.protocolError
    )
  }

  @Test("sorted-key golden output is stable")
  func goldenOutput() throws {
    let command = RuntimeCommand(kind: .getCapabilities)
    let encoded = try RuntimeMessageCodec.encode(command)
    #expect(
      String(decoding: encoded, as: UTF8.self)
        == #"{"kind":"getCapabilities","protocolVersion":1,"schemaVersion":1}"#
    )
    #expect(try RuntimeMessageCodec.encode(command) == encoded)
  }

  @Test("unknown object fields are ignored and omitted when re-encoded")
  func unknownFields() throws {
    let encoded = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.command)
    var json = String(decoding: encoded, as: UTF8.self)
    json.removeLast()
    json += #", "futureField":{"enabled":true}}"#

    let decoded = try RuntimeMessageCodec.decodeCommand(Data(json.utf8))
    #expect(decoded == RuntimeMessageFixtures.command)
    #expect(try RuntimeMessageCodec.encode(decoded) == encoded)
  }

  @Test("old and future protocol and schema versions reject with stable errors")
  func unsupportedVersions() throws {
    let command = try RuntimeMessageCodec.encode(RuntimeCommand(kind: .getDiagnostics))
    let json = String(decoding: command, as: UTF8.self)

    for version: UInt16 in [0, 2] {
      let payload = Data(
        json.replacingOccurrences(
          of: #""protocolVersion":1"#, with: #""protocolVersion":\#(version)"#
        ).utf8)
      #expect(throws: RuntimeMessageCodecError.unsupportedProtocolVersion(version)) {
        try RuntimeMessageCodec.decodeCommand(payload)
      }
    }

    for version: UInt16 in [0, 2] {
      let payload = Data(
        json.replacingOccurrences(of: #""schemaVersion":1"#, with: #""schemaVersion":\#(version)"#)
          .utf8)
      #expect(throws: RuntimeMessageCodecError.unsupportedSchemaVersion(version)) {
        try RuntimeMessageCodec.decodeCommand(payload)
      }
    }

    let reference = try RuntimeConfigurationCodec.encode(
      RuntimeMessageFixtures.configurationReference
    )
    let oldReference = Data(
      String(decoding: reference, as: UTF8.self)
        .replacingOccurrences(of: #""schemaVersion":1"#, with: #""schemaVersion":0"#)
        .utf8
    )
    #expect(throws: RuntimeMessageCodecError.unsupportedSchemaVersion(0)) {
      try RuntimeConfigurationCodec.decodeReference(oldReference)
    }

    let startRequest = try RuntimeConfigurationCodec.encode(RuntimeMessageFixtures.startRequest)
    for version: UInt16 in [0, 2] {
      var startJSON = String(decoding: startRequest, as: UTF8.self)
      let nestedVersion = try #require(startJSON.range(of: #""schemaVersion":1"#))
      startJSON.replaceSubrange(nestedVersion, with: #""schemaVersion":\#(version)"#)

      #expect(throws: RuntimeMessageCodecError.unsupportedSchemaVersion(version)) {
        try RuntimeConfigurationCodec.decodeStartRequest(Data(startJSON.utf8))
      }
    }
  }

  @Test("unknown commands and provider-input values reject before decoding")
  func unsupportedInputs() throws {
    let unknownCommand = Data(
      #"{"kind":"restartTunnel","protocolVersion":1,"schemaVersion":1}"#.utf8
    )
    #expect(throws: RuntimeMessageCodecError.unsupportedKind) {
      try RuntimeMessageCodec.decodeCommand(unknownCommand)
    }

    let configuration = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.configuration)
    let unknownRouteMode = Data(
      String(decoding: configuration, as: UTF8.self)
        .replacingOccurrences(of: #""routeMode":"compatible""#, with: #""routeMode":"future""#)
        .utf8
    )
    #expect(throws: RuntimeMessageCodecError.unsupportedValue) {
      try RuntimeMessageCodec.decodeConfigurationSnapshot(unknownRouteMode)
    }
  }

  @Test("corrupt UTF-8 syntax numbers duplicates trailing bytes and depth reject")
  func corruptPayloads() {
    let invalidUTF8 = Data([0x7B, 0x22, 0xFF, 0x22, 0x3A, 0x31, 0x7D])
    #expect(throws: RuntimeMessageCodecError.invalidUTF8) {
      try RuntimeMessageCodec.decodeCommand(invalidUTF8)
    }

    let duplicate = Data(
      #"{"kind":"getCapabilities","kind":"getDiagnostics","protocolVersion":1,"schemaVersion":1}"#
        .utf8
    )
    #expect(throws: RuntimeMessageCodecError.duplicateKey) {
      try RuntimeMessageCodec.decodeCommand(duplicate)
    }

    let escapedDuplicate = Data(
      #"{"kind":"getCapabilities","\u006bind":"getDiagnostics","protocolVersion":1,"schemaVersion":1}"#
        .utf8
    )
    #expect(throws: RuntimeMessageCodecError.duplicateKey) {
      try RuntimeMessageCodec.decodeCommand(escapedDuplicate)
    }

    let trailing = Data(
      #"{"kind":"getCapabilities","protocolVersion":1,"schemaVersion":1}x"#.utf8
    )
    #expect(throws: RuntimeMessageCodecError.corruptPayload) {
      try RuntimeMessageCodec.decodeCommand(trailing)
    }

    let corruptNumber = Data(
      #"{"kind":"getCapabilities","protocolVersion":01,"schemaVersion":1}"#.utf8
    )
    #expect(throws: RuntimeMessageCodecError.corruptPayload) {
      try RuntimeMessageCodec.decodeCommand(corruptNumber)
    }

    let corruptExponent = Data(
      #"{"kind":"getCapabilities","protocolVersion":1e9999,"schemaVersion":1}"#.utf8
    )
    #expect(throws: RuntimeMessageCodecError.corruptPayload) {
      try RuntimeMessageCodec.decodeCommand(corruptExponent)
    }

    let nesting =
      String(repeating: "[", count: RuntimeMessageProtocol.maximumNestingDepth)
      + String(repeating: "]", count: RuntimeMessageProtocol.maximumNestingDepth)
    let excessive = Data(
      "{\"kind\":\"getCapabilities\",\"protocolVersion\":1,\"schemaVersion\":1,\"future\":\(nesting)}"
        .utf8
    )
    #expect(
      throws: RuntimeMessageCodecError.excessiveNesting(
        maximumDepth: RuntimeMessageProtocol.maximumNestingDepth
      )
    ) {
      try RuntimeMessageCodec.decodeCommand(excessive)
    }
  }

  @Test("missing required fields and encoded or decoded oversize payloads reject")
  func requiredAndSizeBounds() throws {
    let missingTCP = Data(
      #"{"healthy":true,"kind":"capabilitySnapshot","protocolVersion":1,"routeMode":"compatible","routesInstalled":true,"runtimeGeneration":1,"safeDNS":true,"schemaVersion":1,"snapshotSequence":1,"udp":false}"#
        .utf8
    )
    #expect(throws: RuntimeMessageCodecError.corruptPayload) {
      try RuntimeMessageCodec.decodeCapabilitySnapshot(missingTCP)
    }

    let oversizedCommand = Data(
      repeating: UInt8(ascii: " "),
      count: RuntimeMessageSizeLimit.command + 1
    )
    #expect(
      throws: RuntimeMessageCodecError.payloadTooLarge(
        maximumBytes: RuntimeMessageSizeLimit.command,
        actualBytes: RuntimeMessageSizeLimit.command + 1
      )
    ) {
      try RuntimeMessageCodec.decodeCommand(oversizedCommand)
    }

    let fittingDiagnostics = diagnosticsSnapshot(metricCount: 1_500)
    let fittingData = try encodeWithoutSizeLimit(fittingDiagnostics)
    #expect(fittingData.count <= RuntimeMessageSizeLimit.diagnosticsSnapshot)
    #expect(try RuntimeMessageCodec.encode(fittingDiagnostics) == fittingData)

    let oversizedDiagnostics = diagnosticsSnapshot(metricCount: 2_000)
    let oversizedData = try encodeWithoutSizeLimit(oversizedDiagnostics)
    #expect(oversizedData.count > RuntimeMessageSizeLimit.diagnosticsSnapshot)
    #expect(
      throws: RuntimeMessageCodecError.payloadTooLarge(
        maximumBytes: RuntimeMessageSizeLimit.diagnosticsSnapshot,
        actualBytes: oversizedData.count
      )
    ) {
      try RuntimeMessageCodec.encode(oversizedDiagnostics)
    }
  }

  @Test("diagnostics default absent aggregates to empty while position remains required")
  func diagnosticsDefaultsAndRequiredFields() throws {
    let minimal = Data(
      #"{"kind":"diagnosticsSnapshot","protocolVersion":1,"runtimeGeneration":3,"schemaVersion":1,"snapshotSequence":4}"#
        .utf8
    )
    let diagnostics = try RuntimeMessageCodec.decodeDiagnosticsSnapshot(minimal)
    #expect(diagnostics.runtimeGeneration == 3)
    #expect(diagnostics.snapshotSequence == 4)
    #expect(diagnostics.counters.isEmpty)
    #expect(diagnostics.gauges.isEmpty)
    #expect(diagnostics.histograms.isEmpty)
    #expect(diagnostics.errors.isEmpty)

    let missingGeneration = Data(
      #"{"kind":"diagnosticsSnapshot","protocolVersion":1,"schemaVersion":1,"snapshotSequence":4}"#
        .utf8
    )
    #expect(throws: RuntimeMessageCodecError.corruptPayload) {
      try RuntimeMessageCodec.decodeDiagnosticsSnapshot(missingGeneration)
    }

    let nullCounters = Data(
      #"{"counters":null,"kind":"diagnosticsSnapshot","protocolVersion":1,"runtimeGeneration":3,"schemaVersion":1,"snapshotSequence":4}"#
        .utf8
    )
    #expect(throws: RuntimeMessageCodecError.corruptPayload) {
      try RuntimeMessageCodec.decodeDiagnosticsSnapshot(nullCounters)
    }
  }

  @Test("configuration shapes cannot carry private-key or passphrase bytes")
  func secretFieldsAreUnrepresentable() throws {
    let runtimeConfiguration = RuntimeMessageFixtures.startRequest.tunnelConfiguration
    #expect(Mirror(reflecting: runtimeConfiguration).children.count == 1)

    let encoded = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.configuration)
    let json = String(decoding: encoded, as: UTF8.self)
    for prohibited in [
      "privateKey", "private_key", "passphrase", "password", "BEGIN PRIVATE KEY",
    ] {
      #expect(!json.localizedCaseInsensitiveContains(prohibited))
    }

    let malicious = Data(
      #"{"configurationGeneration":7,"credentialReference":"-----BEGIN PRIVATE KEY-----","kind":"configurationSnapshot","profileIdentifier":"11111111-1111-1111-1111-111111111111","profileRevision":"22222222-2222-2222-2222-222222222222","protocolVersion":1,"routeMode":"compatible","schemaVersion":1,"trustReference":"passphrase"}"#
        .utf8
    )
    #expect(throws: RuntimeMessageCodecError.corruptPayload) {
      try RuntimeMessageCodec.decodeConfigurationSnapshot(malicious)
    }
  }

  @Test("TCP safe DNS UDP route and health remain independent without a full-mode claim")
  func independentCapabilities() throws {
    let snapshot = RuntimeCapabilitySnapshot(
      runtimeGeneration: 1,
      snapshotSequence: 0,
      tcp: true,
      safeDNS: true,
      udp: false,
      routeMode: .compatible,
      routesInstalled: true,
      healthy: true
    )
    let json = String(decoding: try RuntimeMessageCodec.encode(snapshot), as: UTF8.self)
    #expect(snapshot.tcp)
    #expect(snapshot.safeDNS)
    #expect(!snapshot.udp)
    #expect(snapshot.routesInstalled)
    #expect(snapshot.healthy)
    #expect(!json.contains("full"))
    #expect(!json.contains("connectedFull"))
  }

  @Test("unknown output modes and lifecycle values project all capabilities false")
  func unknownOutputProjection() throws {
    let capabilities = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.capabilities)
    let futureMode = Data(
      String(decoding: capabilities, as: UTF8.self)
        .replacingOccurrences(of: #""routeMode":"compatible""#, with: #""routeMode":"failClosed""#)
        .utf8
    )
    let projectedCapabilities = try RuntimeMessageCodec.decodeCapabilitySnapshot(futureMode)
    #expect(projectedCapabilities.routeMode == .unknown)
    #expect(!projectedCapabilities.tcp)
    #expect(!projectedCapabilities.safeDNS)
    #expect(!projectedCapabilities.udp)
    #expect(!projectedCapabilities.routesInstalled)
    #expect(!projectedCapabilities.healthy)

    let lifecycle = try RuntimeMessageCodec.encode(RuntimeMessageFixtures.lifecycle)
    let futureLifecycle = Data(
      String(decoding: lifecycle, as: UTF8.self)
        .replacingOccurrences(
          of: #""lifecycleState":"connectedDegraded""#,
          with: #""lifecycleState":"futureState""#
        )
        .utf8
    )
    let projectedLifecycle = try RuntimeMessageCodec.decodeLifecycleSnapshot(futureLifecycle)
    #expect(projectedLifecycle.lifecycleState == .unknown)
    #expect(!projectedLifecycle.tcp)
    #expect(!projectedLifecycle.safeDNS)
    #expect(!projectedLifecycle.udp)
    #expect(!projectedLifecycle.routesInstalled)
    #expect(!projectedLifecycle.healthy)

    let futureRouteState = Data(
      String(decoding: lifecycle, as: UTF8.self)
        .replacingOccurrences(
          of: #""routeState":"installed""#, with: #""routeState":"futureState""#
        )
        .utf8
    )
    let projectedRouteState = try RuntimeMessageCodec.decodeLifecycleSnapshot(futureRouteState)
    #expect(projectedRouteState.routeState == .unknown)
    #expect(!projectedRouteState.tcp)
    #expect(!projectedRouteState.safeDNS)
    #expect(!projectedRouteState.udp)
    #expect(!projectedRouteState.routesInstalled)
    #expect(!projectedRouteState.healthy)
  }

  @Test("snapshot ordering rejects lower generations and non-increasing sequences")
  func snapshotOrdering() {
    let current = RuntimeSnapshotPosition(runtimeGeneration: 4, snapshotSequence: 8)
    #expect(current.isNewer(than: nil))
    #expect(
      RuntimeSnapshotPosition(runtimeGeneration: 5, snapshotSequence: 0).isNewer(than: current))
    #expect(
      RuntimeSnapshotPosition(runtimeGeneration: 4, snapshotSequence: 9).isNewer(than: current))
    #expect(
      !RuntimeSnapshotPosition(runtimeGeneration: 4, snapshotSequence: 8).isNewer(than: current))
    #expect(
      !RuntimeSnapshotPosition(runtimeGeneration: 4, snapshotSequence: 7).isNewer(than: current))
    #expect(
      !RuntimeSnapshotPosition(runtimeGeneration: 3, snapshotSequence: 100).isNewer(than: current))
    #expect(RuntimeMessageFixtures.capabilities.position.runtimeGeneration == 9)
    #expect(RuntimeMessageFixtures.lifecycle.position.snapshotSequence == 4)
    #expect(RuntimeMessageFixtures.diagnostics.position.snapshotSequence == 5)
  }

  @Test("redacted runtime errors accept finite codes and reject free-form text")
  func redactedErrors() throws {
    #expect(try RedactedRuntimeErrorCode("route_clear_failed").rawValue == "route_clear_failed")
    #expect(throws: RuntimeMessageCodecError.unsupportedValue) {
      try RedactedRuntimeErrorCode("ssh.example:22 connection failed")
    }
    #expect(throws: RuntimeMessageCodecError.unsupportedValue) {
      try RedactedRuntimeErrorCode(String(repeating: "x", count: 65))
    }

    let encoded = String(
      decoding: try RuntimeMessageCodec.encode(RuntimeMessageFixtures.protocolError),
      as: UTF8.self
    )
    #expect(!encoded.contains("message"))
    #expect(!encoded.contains("underlying"))

    let invalidMetricName = RuntimeDiagnosticsSnapshot(
      runtimeGeneration: 1,
      snapshotSequence: 0,
      counters: ["ssh.example:22": 1]
    )
    #expect(throws: RuntimeMessageCodecError.unsupportedValue) {
      try RuntimeMessageCodec.encode(invalidMetricName)
    }
  }

  private func diagnosticsSnapshot(metricCount: Int) -> RuntimeDiagnosticsSnapshot {
    RuntimeDiagnosticsSnapshot(
      runtimeGeneration: 1,
      snapshotSequence: 1,
      counters: Dictionary(
        uniqueKeysWithValues: (0..<metricCount).map {
          ("metric_\($0)", UInt64.max)
        }
      )
    )
  }

  private func encodeWithoutSizeLimit<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }
}

@Suite("Legacy provider version compatibility")
struct LegacyProviderVersionCompatibilityTests {
  @Test("legacy request and response keep the exact two-field v1 encoding")
  func exactLegacyEncoding() async throws {
    let request = try ProviderMessageCodec.encodeVersionRequest()
    #expect(
      String(decoding: request, as: UTF8.self)
        == #"{"kind":"version","protocolVersion":1}"#
    )

    let response = try await makeLegacyProvider().handleAppMessage(request)
    #expect(response == request)
    #expect(
      try ProviderMessageCodec.decodeVersionResponse(response)
        == ProviderVersionResponse(protocolVersion: 1)
    )
  }

  @Test("legacy messages reject additive fields duplicates and oversize input")
  func strictLegacyInput() async {
    let extra = Data(
      #"{"kind":"version","protocolVersion":1,"schemaVersion":1}"#.utf8
    )
    await #expect(throws: ProviderMessageError.invalidPayload(.corruptPayload)) {
      try await makeLegacyProvider().handleAppMessage(extra)
    }

    let duplicate = Data(
      #"{"kind":"version","kind":"version","protocolVersion":1}"#.utf8
    )
    await #expect(throws: ProviderMessageError.invalidPayload(.duplicateKey)) {
      try await makeLegacyProvider().handleAppMessage(duplicate)
    }

    let oversized = Data(
      repeating: UInt8(ascii: " "),
      count: RuntimeMessageSizeLimit.legacyVersion + 1
    )
    await #expect(throws: ProviderMessageError.invalidPayload(.payloadTooLarge)) {
      try await makeLegacyProvider().handleAppMessage(oversized)
    }
  }

  private func makeLegacyProvider() -> TunnelProviderAdapter {
    TunnelProviderAdapter(
      packetFlow: LegacyPacketFlow(),
      runtimeFactory: LegacyRuntimeFactory(),
      dependencies: TunnelRuntimeDependencies(
        clock: ContinuousTunnelClock(),
        logger: LegacyLogger(),
        metrics: LegacyMetrics(),
        cancellation: TaskCancellationChecker(),
        memoryPressure: LegacyMemoryPressureSource()
      )
    )
  }
}

private actor LegacyPacketFlow: PacketFlow {
  func readPackets() async throws -> PacketReadBatch { PacketReadBatch(results: []) }
  func writePackets(_ packets: [TunnelPacket]) async throws {}
}

private struct LegacyRuntimeFactory: TunnelRuntimeFactory {
  func makeRuntime(context: TunnelRuntimeContext) async throws -> any TunnelRuntime {
    LegacyRuntime()
  }
}

private final class LegacyRuntime: TunnelRuntime, Sendable {
  func start() async throws {}
  func stop(reason: ProviderStopReason) async {}
  func lifecycleState() async -> TunnelLifecycleState { .disconnected }
}

private struct LegacyLogger: TunnelLogger {
  func log(level: TunnelLogLevel, message: String, fields: [String: TunnelLogField]) {}
}

private actor LegacyMetrics: TunnelMetrics {
  func incrementCounter(named name: String, by amount: UInt64) {}
  func setGauge(named name: String, to value: Int64) {}
  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: [:], gauges: [:])
  }
}

private struct LegacyMemoryPressureSource: TunnelMemoryPressureSource {
  func currentPressure() async -> TunnelMemoryPressure { .normal }
}
