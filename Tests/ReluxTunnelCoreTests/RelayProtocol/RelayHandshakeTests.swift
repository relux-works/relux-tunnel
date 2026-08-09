import Foundation
import ReluxTunnelCore
import Testing

@Suite("RelayProtocol v1 client handshake")
struct RelayProtocolHandshakeTests {
  private typealias P = RelayProtocolV1

  @Test("client hello uses the frozen 12-byte big-endian layout")
  func clientHelloLayout() throws {
    let configuration = try clientConfiguration(timeout: .seconds(1))
    let hello = RelayHandshakeWire.encodeClientHello(configuration: configuration)

    #expect(hello.count == P.clientHelloWidth)
    #expect(
      Array(hello) == [
        0x52, 0x4C, 0x58, 0x52,
        0x00, 0x01,
        0x00, 0x01,
        0x00, 0x00, 0x10, 0x00,
      ]
    )
  }

  @Test("every split boundary and a coalesced frame produce the same result")
  func everySplitAndCoalescedFrame() throws {
    let configuration = try clientConfiguration(timeout: .seconds(1))
    let hello = acceptedServerHello(maximumFrameBytes: P.maxFrameClientDefault)
    let frame = makeFramePrefix(length: P.minFrameLength)
    let expectedFeatures: RelayFeatureSet = [.dnsPriorityHint]

    for split in 0...P.serverHelloWidth {
      var machine = RelayClientHandshakeStateMachine(
        generation: 7,
        configuration: configuration
      )
      let first = machine.receive(Data(hello.prefix(split)), generation: 7)
      if split < P.serverHelloWidth {
        #expect(first == .needsMoreBytes(P.serverHelloWidth - split))
      } else {
        guard case .completed(let result) = first else {
          Issue.record("split \(split) did not complete at the exact boundary")
          continue
        }
        #expect(result.remainingBytes.isEmpty)
        continue
      }
      let secondChunk = Data(hello.dropFirst(split)) + frame
      let second = machine.receive(secondChunk, generation: 7)
      guard case .completed(let result) = second else {
        Issue.record("split \(split) did not complete")
        continue
      }
      #expect(result.summary.protocolVersion == P.wireVersion)
      #expect(result.summary.negotiatedFeatures == expectedFeatures)
      #expect(result.summary.effectiveLimits.effectiveMaxFrame == P.maxFrameClientDefault)
      #expect(result.remainingBytes == frame)
    }
  }

  @Test("duplicate hello detection respects the exact-boundary ownership contract")
  func duplicateHelloOwnershipAtEverySplit() throws {
    let configuration = try clientConfiguration(timeout: .seconds(1))
    let hello = acceptedServerHello(maximumFrameBytes: P.maxFrameClientDefault)
    let duplicated = hello + hello

    for split in 0...duplicated.count {
      var machine = RelayClientHandshakeStateMachine(
        generation: 8,
        configuration: configuration
      )
      let first = machine.receive(Data(duplicated.prefix(split)), generation: 8)
      if split < P.serverHelloWidth {
        #expect(first == .needsMoreBytes(P.serverHelloWidth - split))
        let second = machine.receive(Data(duplicated.dropFirst(split)), generation: 8)
        expectProgressFailure(.duplicateHello, second)
      } else if split == P.serverHelloWidth {
        guard case .completed(let result) = first else {
          Issue.record("exact-boundary hello did not complete")
          continue
        }
        #expect(result.remainingBytes.isEmpty)
      } else {
        expectProgressFailure(.duplicateHello, first)
      }
    }
  }

  @Test("server status values map to finite local reasons")
  func statusMappings() throws {
    let configuration = try clientConfiguration(timeout: .seconds(1))
    let cases: [(UInt16, RelayHandshakeFailureCode)] = [
      (P.HelloStatus.unsupportedVersion.rawValue, .unsupportedVersion),
      (P.HelloStatus.invalidClientHello.rawValue, .invalidClientHello),
      (P.HelloStatus.resourcePolicyRejected.rawValue, .resourcePolicyRejected),
      (P.HelloStatus.relayUnavailable.rawValue, .relayUnavailable),
      (UInt16.max, .relayRejected),
    ]

    for (status, expected) in cases {
      var hello = acceptedServerHello(maximumFrameBytes: P.maxFrameClientDefault)
      replaceUInt16(status, field: "status", layout: P.serverHelloLayout, in: &hello)
      #expect(
        throws: RelayHandshakeFailure(
          code: expected,
          phase: .serverHelloValidation
        )
      ) {
        try RelayHandshakeWire.decodeServerHelloExact(
          hello,
          configuration: configuration
        )
      }
    }
  }

  @Test("magic version features and maximum-frame violations fail closed")
  func validationFailures() throws {
    let configuration = try clientConfiguration(timeout: .seconds(1))

    var badMagic = acceptedServerHello(maximumFrameBytes: P.maxFrameClientDefault)
    badMagic[badMagic.startIndex] ^= UInt8.max
    expectDecodeFailure(.unknownMagic, bytes: badMagic, configuration: configuration)

    var badVersion = acceptedServerHello(maximumFrameBytes: P.maxFrameClientDefault)
    replaceUInt16(
      P.wireVersion &+ 1,
      field: "version",
      layout: P.serverHelloLayout,
      in: &badVersion
    )
    expectDecodeFailure(.unsupportedVersion, bytes: badVersion, configuration: configuration)

    let reservedFeature = RelayFeatureSet(
      rawValue: P.featuresReservedMask & (~P.featuresReservedMask &+ 1))
    let impossibleReserved = RelayHandshakeWire.encodeServerHello(
      status: .accepted,
      features: reservedFeature,
      maximumFrameBytes: P.maxFrameClientDefault
    )
    expectDecodeFailure(
      .impossibleFeatureSelection,
      bytes: impossibleReserved,
      configuration: configuration
    )

    let noFeatures = try clientConfiguration(
      requestedFeatures: [],
      timeout: .seconds(1)
    )
    expectDecodeFailure(
      .impossibleFeatureSelection,
      bytes: acceptedServerHello(maximumFrameBytes: P.maxFrameClientDefault),
      configuration: noFeatures
    )

    for invalid in [P.maxFrameFloor - 1, P.maxFrameClientHardCeiling + 1] {
      expectDecodeFailure(
        .unreasonableMaxFrame,
        bytes: acceptedServerHello(maximumFrameBytes: invalid),
        configuration: configuration
      )
    }

    let lowerClientCap = try clientConfiguration(
      maximumFrameBytes: P.maxFrameFloor,
      timeout: .seconds(1)
    )
    expectDecodeFailure(
      .unreasonableMaxFrame,
      bytes: acceptedServerHello(maximumFrameBytes: P.maxFrameFloor + 1),
      configuration: lowerClientCap
    )
  }

  @Test("exact decoder rejects truncated and extended standalone hellos")
  func exactHelloLength() throws {
    let configuration = try clientConfiguration(timeout: .seconds(1))
    let hello = acceptedServerHello(maximumFrameBytes: P.maxFrameClientDefault)

    expectDecodeFailure(
      .truncatedHello,
      bytes: Data(hello.dropLast()),
      configuration: configuration
    )
    expectDecodeFailure(
      .extendedHello,
      bytes: hello + Data([0]),
      configuration: configuration
    )
  }

  @Test("local-only limits use lower injected caps and cannot exceed schema baselines")
  func effectiveLocalLimits() throws {
    let lowerConfiguration = try clientConfiguration(
      maximumFrameBytes: P.maxFrameFloor,
      maximumUDPPayloadBytes: P.maxUDPPayloadFloor,
      maximumAssociations: P.maxAssociationsFloor,
      perAssociationQueuedBytes: P.perAssociationQueuedBytesFloor,
      aggregateQueuedBytes: P.aggregateQueuedBytesFloor,
      controlReservedBytes: P.controlReservedBytesFloor,
      dnsPriorityWeight: P.dnsPriorityWeightFloor,
      idleTimeoutMilliseconds: P.idleTimeoutFloor,
      timeout: .seconds(1)
    )
    let lower = try RelayHandshakeWire.decodeServerHelloExact(
      acceptedServerHello(maximumFrameBytes: P.maxFrameFloor),
      configuration: lowerConfiguration
    ).effectiveLimits
    #expect(lower.effectiveMaxFrame == P.maxFrameFloor)
    #expect(lower.maxUDPPayload == P.maxUDPPayloadFloor)
    #expect(lower.maxAssociations == P.maxAssociationsFloor)
    #expect(lower.perAssociationQueuedBytes == P.perAssociationQueuedBytesFloor)
    #expect(lower.aggregateQueuedBytes == P.aggregateQueuedBytesFloor)
    #expect(lower.controlReservedBytes == P.controlReservedBytesFloor)
    #expect(lower.dnsPriorityWeight == P.dnsPriorityWeightFloor)
    #expect(lower.idleTimeoutMilliseconds == P.idleTimeoutFloor)

    let raisedConfiguration = try clientConfiguration(
      maximumFrameBytes: P.maxFrameClientHardCeiling,
      maximumUDPPayloadBytes: P.maxUDPPayloadClientHardCeiling,
      maximumAssociations: P.maxAssociationsClientHardCeiling,
      perAssociationQueuedBytes: P.perAssociationQueuedBytesClientHardCeiling,
      aggregateQueuedBytes: P.aggregateQueuedBytesClientHardCeiling,
      controlReservedBytes: P.controlReservedBytesClientHardCeiling,
      dnsPriorityWeight: P.dnsPriorityWeightClientHardCeiling,
      idleTimeoutMilliseconds: P.idleTimeoutClientHardCeiling,
      timeout: .seconds(1)
    )
    let bounded = try RelayHandshakeWire.decodeServerHelloExact(
      acceptedServerHello(maximumFrameBytes: P.maxFrameClientHardCeiling),
      configuration: raisedConfiguration
    ).effectiveLimits
    #expect(bounded.effectiveMaxFrame == P.maxFrameClientHardCeiling)
    #expect(bounded.maxUDPPayload == P.maxUDPPayloadClientDefault)
    #expect(bounded.maxAssociations == P.maxAssociationsClientDefault)
    #expect(
      bounded.perAssociationQueuedBytes == P.perAssociationQueuedBytesClientDefault
    )
    #expect(bounded.aggregateQueuedBytes == P.aggregateQueuedBytesClientDefault)
    #expect(bounded.controlReservedBytes == P.controlReservedBytesClientDefault)
    #expect(bounded.dnsPriorityWeight == P.dnsPriorityWeightClientDefault)
    #expect(bounded.idleTimeoutMilliseconds == P.idleTimeoutClientDefault)
  }

  @Test("timeout EOF cancellation duplicate trailing and stale events are deterministic")
  func terminalEventsAndStaleCallbacks() throws {
    let configuration = try clientConfiguration(timeout: .seconds(1))

    var stale = RelayClientHandshakeStateMachine(generation: 11, configuration: configuration)
    #expect(stale.receive(Data([1]), generation: 10) == .staleCallbackIgnored)
    #expect(stale.timeout(generation: 10) == .staleCallbackIgnored)
    #expect(stale.receive(Data(), generation: 11) == .needsMoreBytes(P.serverHelloWidth))

    var timedOut = RelayClientHandshakeStateMachine(
      generation: 11,
      configuration: configuration
    )
    expectProgressFailure(.timedOut, timedOut.timeout(generation: 11))

    var eof = RelayClientHandshakeStateMachine(generation: 11, configuration: configuration)
    _ = eof.receive(Data([1]), generation: 11)
    expectProgressFailure(.unexpectedEOF, eof.endOfStream(generation: 11))

    var cancelled = RelayClientHandshakeStateMachine(
      generation: 11,
      configuration: configuration
    )
    expectProgressFailure(.cancelled, cancelled.cancel(generation: 11))

    var duplicate = completedMachine(configuration: configuration, generation: 11)
    expectProgressFailure(
      .duplicateHello,
      duplicate.receive(
        acceptedServerHello(maximumFrameBytes: P.maxFrameClientDefault),
        generation: 11
      )
    )

    var trailing = completedMachine(configuration: configuration, generation: 11)
    expectProgressFailure(
      .trailingHelloBytes,
      trailing.receive(Data([1]), generation: 11)
    )
  }

  @Test("configuration rejects every out-of-policy field")
  func configurationValidation() {
    expectConfigurationFailure(.maximumFrameBytes) {
      try clientConfiguration(maximumFrameBytes: P.maxFrameFloor - 1, timeout: .seconds(1))
    }
    expectConfigurationFailure(.maximumUDPPayloadBytes) {
      try clientConfiguration(
        maximumUDPPayloadBytes: P.maxUDPPayloadFloor - 1,
        timeout: .seconds(1)
      )
    }
    expectConfigurationFailure(.maximumAssociations) {
      try clientConfiguration(maximumAssociations: 0, timeout: .seconds(1))
    }
    expectConfigurationFailure(.perAssociationQueuedBytes) {
      try clientConfiguration(
        perAssociationQueuedBytes: P.perAssociationQueuedBytesFloor - 1,
        timeout: .seconds(1)
      )
    }
    expectConfigurationFailure(.aggregateQueuedBytes) {
      try clientConfiguration(
        aggregateQueuedBytes: P.aggregateQueuedBytesClientHardCeiling + 1,
        timeout: .seconds(1)
      )
    }
    expectConfigurationFailure(.controlReservedBytes) {
      try clientConfiguration(
        aggregateQueuedBytes: P.aggregateQueuedBytesFloor,
        controlReservedBytes: P.controlReservedBytesClientHardCeiling,
        timeout: .seconds(1)
      )
    }
    expectConfigurationFailure(.dnsPriorityWeight) {
      try clientConfiguration(dnsPriorityWeight: 0, timeout: .seconds(1))
    }
    expectConfigurationFailure(.idleTimeoutMilliseconds) {
      try clientConfiguration(
        idleTimeoutMilliseconds: P.idleTimeoutClientHardCeiling + 1,
        timeout: .seconds(1)
      )
    }
    expectConfigurationFailure(.requestedFeatures) {
      try clientConfiguration(
        requestedFeatures: RelayFeatureSet(rawValue: P.featuresReservedMask),
        timeout: .seconds(1)
      )
    }
    expectConfigurationFailure(.timeout) {
      try clientConfiguration(timeout: .zero)
    }
    expectConfigurationFailure(.maximumReadBytes) {
      try clientConfiguration(timeout: .seconds(1), maximumReadBytes: 0)
    }
  }

  @Test("async channel exchange handles partial IO and preserves coalesced bytes")
  func asyncChannelSuccess() async throws {
    let frame = makeFramePrefix(length: P.minFrameLength)
    let serverBytes = acceptedServerHello(maximumFrameBytes: P.maxFrameFloor) + frame
    let channel = HandshakeByteChannel(
      readChunks: strideChunks(serverBytes, width: 3),
      maximumWriteAcceptance: 2
    )
    let configuration = try clientConfiguration(
      maximumFrameBytes: P.maxFrameClientDefault,
      timeout: .seconds(1),
      maximumReadBytes: 3
    )
    let handshake = RelayClientHandshake(
      configuration: configuration,
      clock: ContinuousTunnelClock(),
      cancellation: TaskCancellationChecker()
    )

    let result = try await handshake.perform(on: channel, generation: 21)
    #expect(result.summary.effectiveLimits.effectiveMaxFrame == P.maxFrameFloor)
    #expect(result.remainingBytes == Data(frame.prefix(2)))
    #expect(
      await channel.writtenBytes()
        == RelayHandshakeWire.encodeClientHello(configuration: configuration))
    #expect(await channel.resetCount() == 0)
    #expect(await channel.closeCount() == 0)
  }

  @Test("async failures cancel reset and close the generation")
  func asyncFailureCleanup() async throws {
    var malformed = acceptedServerHello(maximumFrameBytes: P.maxFrameClientDefault)
    malformed[malformed.startIndex] ^= UInt8.max
    let malformedChannel = HandshakeByteChannel(
      readChunks: [malformed],
      maximumWriteAcceptance: P.clientHelloWidth
    )
    let configuration = try clientConfiguration(timeout: .seconds(1))
    let handshake = RelayClientHandshake(
      configuration: configuration,
      clock: ContinuousTunnelClock(),
      cancellation: TaskCancellationChecker()
    )
    await expectAsyncFailure(.unknownMagic) {
      try await handshake.perform(on: malformedChannel, generation: 31)
    }
    #expect(await malformedChannel.cancelCount() == 1)
    #expect(await malformedChannel.resetCount() == 1)
    #expect(await malformedChannel.closeCount() == 1)

    let timeoutChannel = HandshakeByteChannel(
      readChunks: [],
      maximumWriteAcceptance: P.clientHelloWidth,
      delayedRead: true
    )
    let timeoutHandshake = RelayClientHandshake(
      configuration: configuration,
      clock: ImmediateHandshakeClock(),
      cancellation: TaskCancellationChecker()
    )
    await expectAsyncFailure(.timedOut) {
      try await timeoutHandshake.perform(on: timeoutChannel, generation: 32)
    }
    #expect(await timeoutChannel.cancelCount() == 1)
    #expect(await timeoutChannel.resetCount() == 1)
    #expect(await timeoutChannel.closeCount() == 1)

    let cancellationChannel = HandshakeByteChannel(
      readChunks: [],
      maximumWriteAcceptance: P.clientHelloWidth,
      delayedRead: true
    )
    let cancellationHandshake = RelayClientHandshake(
      configuration: configuration,
      clock: ContinuousTunnelClock(),
      cancellation: TaskCancellationChecker()
    )
    let task = Task {
      try await cancellationHandshake.perform(on: cancellationChannel, generation: 33)
    }
    task.cancel()
    do {
      _ = try await task.value
      Issue.record("cancelled handshake unexpectedly succeeded")
    } catch let failure as RelayHandshakeFailure {
      #expect(failure.code == .cancelled)
    } catch {
      Issue.record("unexpected cancellation error type")
    }
    #expect(await cancellationChannel.cancelCount() >= 1)
    #expect(await cancellationChannel.resetCount() == 1)
    #expect(await cancellationChannel.closeCount() == 1)

    let invalidWriteChannel = HandshakeByteChannel(
      readChunks: [],
      maximumWriteAcceptance: 0
    )
    await expectAsyncFailure(.transportFailure, phase: .clientHelloWrite) {
      try await handshake.perform(on: invalidWriteChannel, generation: 34)
    }
    #expect(await invalidWriteChannel.cancelCount() == 1)
    #expect(await invalidWriteChannel.resetCount() == 1)
    #expect(await invalidWriteChannel.closeCount() == 1)

    let throwingWriteChannel = HandshakeByteChannel(
      readChunks: [],
      maximumWriteAcceptance: P.clientHelloWidth,
      writeFails: true
    )
    await expectAsyncFailure(.transportFailure, phase: .clientHelloWrite) {
      try await handshake.perform(on: throwingWriteChannel, generation: 35)
    }
    #expect(await throwingWriteChannel.cancelCount() == 1)
    #expect(await throwingWriteChannel.resetCount() == 1)
    #expect(await throwingWriteChannel.closeCount() == 1)

    let throwingReadChannel = HandshakeByteChannel(
      readChunks: [],
      maximumWriteAcceptance: P.clientHelloWidth,
      readFails: true
    )
    await expectAsyncFailure(.transportFailure, phase: .serverHelloRead) {
      try await handshake.perform(on: throwingReadChannel, generation: 36)
    }
    #expect(await throwingReadChannel.cancelCount() == 1)
    #expect(await throwingReadChannel.resetCount() == 1)
    #expect(await throwingReadChannel.closeCount() == 1)

    let eofChannel = HandshakeByteChannel(
      readChunks: [],
      maximumWriteAcceptance: P.clientHelloWidth
    )
    await expectAsyncFailure(.unexpectedEOF, phase: .serverHelloRead) {
      try await handshake.perform(on: eofChannel, generation: 37)
    }
    #expect(await eofChannel.cancelCount() == 1)
    #expect(await eofChannel.resetCount() == 1)
    #expect(await eofChannel.closeCount() == 1)
  }

  @Test("diagnostics never reflect attacker-controlled bytes or numeric statuses")
  func privacySafeDiagnostics() throws {
    let configuration = try clientConfiguration(timeout: .seconds(1))
    let attackerText = "evil.example secret payload"
    var bytes = Data(attackerText.utf8)
    bytes.append(Data(repeating: 0, count: max(0, P.serverHelloWidth - bytes.count)))
    bytes = Data(bytes.prefix(P.serverHelloWidth))

    do {
      _ = try RelayHandshakeWire.decodeServerHelloExact(bytes, configuration: configuration)
      Issue.record("attacker bytes unexpectedly decoded")
    } catch let failure as RelayHandshakeFailure {
      #expect(failure.description.contains(RelayHandshakeFailureCode.unknownMagic.rawValue))
      #expect(!failure.description.contains(attackerText))
      #expect(!failure.description.contains(String(UInt16.max)))
    }
  }

  private func clientConfiguration(
    maximumFrameBytes: UInt32 = P.maxFrameClientDefault,
    maximumUDPPayloadBytes: UInt16 = P.maxUDPPayloadClientDefault,
    maximumAssociations: UInt32 = P.maxAssociationsClientDefault,
    perAssociationQueuedBytes: UInt32 = P.perAssociationQueuedBytesClientDefault,
    aggregateQueuedBytes: UInt32 = P.aggregateQueuedBytesClientDefault,
    controlReservedBytes: UInt32 = P.controlReservedBytesClientDefault,
    dnsPriorityWeight: UInt8 = P.dnsPriorityWeightClientDefault,
    idleTimeoutMilliseconds: UInt32 = P.idleTimeoutClientDefault,
    requestedFeatures: RelayFeatureSet = [.dnsPriorityHint],
    timeout: Duration,
    maximumReadBytes: Int = P.serverHelloWidth
      + P.framePrefixWidth + P.envelopeHeaderWidth
  ) throws -> RelayClientHandshakeConfiguration {
    try RelayClientHandshakeConfiguration(
      maximumFrameBytes: maximumFrameBytes,
      maximumUDPPayloadBytes: maximumUDPPayloadBytes,
      maximumAssociations: maximumAssociations,
      perAssociationQueuedBytes: perAssociationQueuedBytes,
      aggregateQueuedBytes: aggregateQueuedBytes,
      controlReservedBytes: controlReservedBytes,
      dnsPriorityWeight: dnsPriorityWeight,
      idleTimeoutMilliseconds: idleTimeoutMilliseconds,
      requestedFeatures: requestedFeatures,
      timeout: timeout,
      maximumReadBytes: maximumReadBytes
    )
  }

  private func acceptedServerHello(maximumFrameBytes: UInt32) -> Data {
    RelayHandshakeWire.encodeServerHello(
      status: .accepted,
      features: [.dnsPriorityHint],
      maximumFrameBytes: maximumFrameBytes
    )
  }

  private func expectDecodeFailure(
    _ code: RelayHandshakeFailureCode,
    bytes: Data,
    configuration: RelayClientHandshakeConfiguration,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    do {
      _ = try RelayHandshakeWire.decodeServerHelloExact(
        bytes,
        configuration: configuration
      )
      Issue.record("decode unexpectedly succeeded", sourceLocation: sourceLocation)
    } catch let failure as RelayHandshakeFailure {
      #expect(failure.code == code, sourceLocation: sourceLocation)
      #expect(failure.scope == .session, sourceLocation: sourceLocation)
      #expect(failure.disposition == .closeSession, sourceLocation: sourceLocation)
    } catch {
      Issue.record("unexpected error type", sourceLocation: sourceLocation)
    }
  }

  private func expectProgressFailure(
    _ code: RelayHandshakeFailureCode,
    _ progress: RelayClientHandshakeProgress,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    guard case .failed(let failure) = progress else {
      Issue.record("expected failed progress", sourceLocation: sourceLocation)
      return
    }
    #expect(failure.code == code, sourceLocation: sourceLocation)
    #expect(failure.disposition == .closeSession, sourceLocation: sourceLocation)
  }

  private func expectConfigurationFailure(
    _ field: RelayHandshakeConfigurationField,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () throws -> RelayClientHandshakeConfiguration
  ) {
    do {
      _ = try body()
      Issue.record("configuration unexpectedly succeeded", sourceLocation: sourceLocation)
    } catch let failure as RelayHandshakeFailure {
      #expect(failure.code == .invalidConfiguration, sourceLocation: sourceLocation)
      #expect(failure.configurationField == field, sourceLocation: sourceLocation)
    } catch {
      Issue.record("unexpected configuration error", sourceLocation: sourceLocation)
    }
  }

  private func expectAsyncFailure(
    _ code: RelayHandshakeFailureCode,
    phase: RelayHandshakePhase? = nil,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () async throws -> RelayClientHandshakeResult
  ) async {
    do {
      _ = try await body()
      Issue.record("handshake unexpectedly succeeded", sourceLocation: sourceLocation)
    } catch let failure as RelayHandshakeFailure {
      #expect(failure.code == code, sourceLocation: sourceLocation)
      if let phase {
        #expect(failure.phase == phase, sourceLocation: sourceLocation)
      }
    } catch {
      Issue.record("unexpected async error type", sourceLocation: sourceLocation)
    }
  }

  private func completedMachine(
    configuration: RelayClientHandshakeConfiguration,
    generation: UInt64
  ) -> RelayClientHandshakeStateMachine {
    var machine = RelayClientHandshakeStateMachine(
      generation: generation,
      configuration: configuration
    )
    _ = machine.receive(
      acceptedServerHello(maximumFrameBytes: P.maxFrameClientDefault),
      generation: generation
    )
    return machine
  }

  private func replaceUInt16(
    _ value: UInt16,
    field name: String,
    layout: [P.WireField],
    in data: inout Data
  ) {
    let field = layout.first { $0.name == name }!
    data[field.byteOffset] = UInt8(truncatingIfNeeded: value >> 8)
    data[field.byteOffset + 1] = UInt8(truncatingIfNeeded: value)
  }

  private func makeFramePrefix(length: UInt32) -> Data {
    Data([
      UInt8(truncatingIfNeeded: length >> 24),
      UInt8(truncatingIfNeeded: length >> 16),
      UInt8(truncatingIfNeeded: length >> 8),
      UInt8(truncatingIfNeeded: length),
    ])
  }

  private func strideChunks(_ data: Data, width: Int) -> [Data] {
    stride(from: 0, to: data.count, by: width).map {
      Data(data[$0..<min($0 + width, data.count)])
    }
  }
}

private actor HandshakeByteChannel: SSHByteChannel {
  nonisolated let identity = SSHChannelIdentity(
    rawValue: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
  )

  private var readChunks: [Data]
  private let maximumWriteAcceptance: Int
  private let delayedRead: Bool
  private let readFails: Bool
  private let writeFails: Bool
  private var written = Data()
  private var cancellations = 0
  private var resets = 0
  private var closes = 0

  init(
    readChunks: [Data],
    maximumWriteAcceptance: Int,
    delayedRead: Bool = false,
    readFails: Bool = false,
    writeFails: Bool = false
  ) {
    self.readChunks = readChunks
    self.maximumWriteAcceptance = maximumWriteAcceptance
    self.delayedRead = delayedRead
    self.readFails = readFails
    self.writeFails = writeFails
  }

  func read(maximumBytes: Int) async throws -> Data? {
    guard maximumBytes > 0 else { throw CancellationError() }
    if readFails {
      throw HandshakeByteChannelInjectedFailure()
    }
    if delayedRead {
      try await Task.sleep(for: .seconds(60))
    }
    guard !readChunks.isEmpty else { return nil }
    let next = readChunks.removeFirst()
    if next.count <= maximumBytes {
      return next
    }
    let prefix = Data(next.prefix(maximumBytes))
    readChunks.insert(Data(next.dropFirst(maximumBytes)), at: 0)
    return prefix
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    if writeFails {
      throw HandshakeByteChannelInjectedFailure()
    }
    let accepted = min(bytes.count, maximumWriteAcceptance)
    written.append(bytes.prefix(accepted))
    return accepted
  }

  func finishWriting() async throws {}

  func receiveWindow() async -> SSHDeferredSemanticReport<SSHReceiveWindowSnapshot> {
    .reported(
      try! SSHReceiveWindowSnapshot(
        initialReceiveWindowBytes: 1,
        maximumAdvertisedReceiveWindowBytes: 1,
        remainingProtocolCreditBytes: 1,
        bufferedUnreadBytes: 0,
        deliveredButNotYetReturnedCreditBytes: 0,
        adjustmentCount: 0,
        cumulativeAdjustmentBytes: 0
      ))
  }

  func cancel() async {
    cancellations += 1
  }

  func reset() async {
    resets += 1
  }

  func close() async {
    closes += 1
  }

  func writtenBytes() -> Data { written }
  func cancelCount() -> Int { cancellations }
  func resetCount() -> Int { resets }
  func closeCount() -> Int { closes }
}

private struct HandshakeByteChannelInjectedFailure: Error {}

private struct ImmediateHandshakeClock: TunnelClock {
  func now() -> ContinuousClock.Instant {
    ContinuousClock().now
  }

  func sleep(for duration: Duration) async throws {}
}
