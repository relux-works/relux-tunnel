import Foundation
import ReluxTunnelCore
import Testing

@Suite("RelayProtocol v1 envelope codec")
struct RelayProtocolByteCodecTests {
  private typealias P = RelayProtocolV1

  @Test("encoder emits exact network-order bytes and write slices")
  func encoderExactWireAndSlices() throws {
    var encoder = try RelayEnvelopeEncoder(
      maximumFrame: P.maxFrameDefault,
      direction: .clientToRelay,
      negotiatedFeatures: [.dnsPriorityHint]
    )
    let frame = RelayEnvelope(
      type: .udpDatagram,
      flags: P.envelopeFlagDNSPriority,
      associationID: 0x0102_0304,
      payload: Data([0xAA, 0xBB, 0xCC])
    )

    let write = try encoder.encode(frame)
    #expect(write.slices.count == 2)
    #expect(write.byteCount == 13)
    #expect(
      Array(write.bytes) == [
        0x00, 0x00, 0x00, 0x09,
        0x10, 0x01,
        0x01, 0x02, 0x03, 0x04,
        0xAA, 0xBB, 0xCC,
      ]
    )
    #expect(encoder.metrics.outputFrames == 1)
    #expect(encoder.metrics.outputBytes == 13)
    #expect(encoder.metrics.failures == 0)
  }

  @Test("every legal payload size encodes without truncation")
  func everyLegalPayloadSize() throws {
    let maximumFrame: UInt32 = P.maxFrameFloor
    for payloadLength in 0...Int(maximumFrame) - P.envelopeHeaderWidth {
      var encoder = try RelayEnvelopeEncoder(
        maximumFrame: maximumFrame,
        direction: .clientToRelay
      )
      let write = try encoder.encode(
        RelayEnvelope(
          type: .udpDatagram,
          associationID: 1,
          payload: Data(repeating: UInt8(truncatingIfNeeded: payloadLength), count: payloadLength)
        )
      )
      let expectedLength = UInt32(P.envelopeHeaderWidth + payloadLength)
      #expect(readUInt32(write.bytes.prefix(4)) == expectedLength)
      #expect(write.byteCount == P.framePrefixWidth + Int(expectedLength))
    }
  }

  @Test("encoder arithmetic and negotiated cap checks are explicit")
  func encoderLengthFailures() throws {
    expectWireFailure(.arithmeticOverflow) {
      try RelayEnvelopeWire.frameLength(
        payloadLength: UInt64.max,
        maximumFrame: P.maxFrameHardCeiling
      )
    }
    expectWireFailure(.frameLengthExceedsMaximum) {
      try RelayEnvelopeWire.frameLength(
        payloadLength: UInt64(P.maxFrameDefault),
        maximumFrame: P.maxFrameDefault
      )
    }
    expectWireFailure(.invalidConfiguration) {
      try RelayEnvelopeWire.frameLength(payloadLength: 0, maximumFrame: 5)
    }
  }

  @Test("every stream split and coalesced sequence preserves ordered frames")
  func everySplitAndCoalescedFrames() throws {
    let frames = legalClientFrames()
    let wire = try encode(frames, direction: .clientToRelay)

    for split in 0...wire.count {
      var decoder = try RelayEnvelopeDecoder(
        maximumFrame: P.maxFrameDefault,
        direction: .clientToRelay,
        negotiatedFeatures: [.dnsPriorityHint]
      )
      var decoded = try decoder.consume(Data(wire.prefix(split)))
      decoded += try decoder.consume(Data(wire.dropFirst(split)))
      #expect(decoded == frames)
      try decoder.endOfStream()
      expectReconciled(decoder.metrics)
    }

    var oneByte = try RelayEnvelopeDecoder(
      maximumFrame: P.maxFrameDefault,
      direction: .clientToRelay,
      negotiatedFeatures: [.dnsPriorityHint]
    )
    var decoded: [RelayEnvelope] = []
    for byte in wire {
      decoded += try oneByte.consume(Data([byte]))
    }
    #expect(decoded == frames)
    expectReconciled(oneByte.metrics)
  }

  @Test("every prefix and body boundary of a maximum accepted frame is deterministic")
  func everyMaximumFrameSplit() throws {
    let maximumFrame = P.maxFrameFloor
    let frame = RelayEnvelope(
      type: .udpDatagram,
      associationID: UInt32.max,
      payload: Data(repeating: 0xA5, count: Int(maximumFrame) - P.envelopeHeaderWidth)
    )
    let wire = try encode([frame], maximumFrame: maximumFrame, direction: .clientToRelay)

    for split in 0...wire.count {
      var decoder = try RelayEnvelopeDecoder(
        maximumFrame: maximumFrame,
        direction: .clientToRelay
      )
      let first = try decoder.consume(Data(wire.prefix(split)))
      let second = try decoder.consume(Data(wire.dropFirst(split)))
      #expect(first + second == [frame])
      #expect(
        decoder.metrics.peakRetainedBytes
          <= Int(maximumFrame) + P.framePrefixWidth
      )
      expectReconciled(decoder.metrics)
    }
  }

  @Test("decoder rejects framing and metadata violations terminally")
  func terminalValidationFailures() throws {
    try expectDecodeFailure(.frameLengthBelowMinimum, wire: prefix(5))

    var oversized = try RelayEnvelopeDecoder(
      maximumFrame: 32,
      direction: .clientToRelay
    )
    let oversizedPrefix = prefix(33)
    expectFailure(.frameLengthExceedsMaximum) {
      _ = try oversized.consume(oversizedPrefix)
    }
    #expect(oversized.metrics.bodyAllocations == 0)
    #expect(oversized.metrics.peakRetainedBytes == P.framePrefixWidth)
    #expect(oversized.metrics.retainedBytes == 0)
    #expect(oversized.metrics.discardedBytes == UInt64(oversizedPrefix.count))

    try expectDecodeFailure(
      .unknownMessageType,
      wire: rawFrame(type: 0xFF, associationID: 1)
    )
    try expectDecodeFailure(
      .reservedFlags,
      wire: rawFrame(type: P.MessageType.closeAssociation.rawValue, flags: 0x02, associationID: 1)
    )
    try expectDecodeFailure(
      .invalidFlags,
      wire: rawFrame(type: P.MessageType.closeAssociation.rawValue, flags: 0x01, associationID: 1),
      features: [.dnsPriorityHint]
    )
    try expectDecodeFailure(
      .invalidDirection,
      wire: rawFrame(type: P.MessageType.pong.rawValue, payload: Data(repeating: 1, count: 8)),
      direction: .clientToRelay
    )
    try expectDecodeFailure(
      .invalidAssociationID,
      wire: rawFrame(type: P.MessageType.udpDatagram.rawValue, associationID: 0)
    )
    try expectDecodeFailure(
      .invalidPayloadLength,
      wire: rawFrame(type: P.MessageType.ping.rawValue, payload: Data(repeating: 1, count: 7))
    )

    var transactional = try RelayEnvelopeDecoder(
      maximumFrame: P.maxFrameDefault,
      direction: .clientToRelay
    )
    var validThenInvalid = try encode(
      [RelayEnvelope(type: .closeSession, associationID: 0)],
      direction: .clientToRelay
    )
    validThenInvalid.append(prefix(5))
    expectFailure(.frameLengthBelowMinimum) {
      _ = try transactional.consume(validThenInvalid)
    }
    #expect(transactional.metrics.outputFrames == 0)
    #expect(transactional.metrics.outputBytes == 0)
    #expect(transactional.metrics.discardedBytes == UInt64(validThenInvalid.count))
  }

  @Test("relay-to-client metadata direction accepts only relay messages")
  func relayDirectionMatrix() throws {
    let frames = [
      RelayEnvelope(type: .udpError, associationID: 1, payload: Data([0, 1])),
      RelayEnvelope(type: .pong, associationID: 0, payload: Data(repeating: 7, count: 8)),
      RelayEnvelope(type: .closeAssociation, associationID: 1),
      RelayEnvelope(type: .closeSession, associationID: 0),
    ]
    let wire = try encode(frames, direction: .relayToClient)
    var decoder = try RelayEnvelopeDecoder(
      maximumFrame: P.maxFrameDefault,
      direction: .relayToClient
    )
    #expect(try decoder.consume(wire) == frames)

    var encoder = try RelayEnvelopeEncoder(
      maximumFrame: P.maxFrameDefault,
      direction: .relayToClient
    )
    expectFailure(.invalidDirection) {
      _ = try encoder.encode(legalClientFrames()[1])
    }
  }

  @Test("EOF cancellation reset and malformed post-EOF state are deterministic")
  func terminalEventsAndReset() throws {
    var prefixEOF = try RelayEnvelopeDecoder(
      maximumFrame: P.maxFrameDefault,
      direction: .clientToRelay
    )
    _ = try prefixEOF.consume(Data([0, 0, 0]))
    expectFailure(.unexpectedEOF) { try prefixEOF.endOfStream() }
    expectFailure(.unexpectedEOF) { _ = try prefixEOF.consume(Data([1])) }
    #expect(prefixEOF.metrics.failures == 1)

    let ping = legalClientFrames()[1]
    let pingWire = try encode([ping], direction: .clientToRelay)
    var bodyEOF = try RelayEnvelopeDecoder(
      maximumFrame: P.maxFrameDefault,
      direction: .clientToRelay
    )
    _ = try bodyEOF.consume(Data(pingWire.dropLast()))
    expectFailure(.unexpectedEOF) { try bodyEOF.endOfStream() }

    var cancelled = try RelayEnvelopeDecoder(
      maximumFrame: P.maxFrameDefault,
      direction: .clientToRelay
    )
    _ = try cancelled.consume(Data(pingWire.prefix(5)))
    expectFailure(.cancelled) { try cancelled.cancel() }
    #expect(cancelled.metrics.retainedBytes == 0)
    #expect(cancelled.metrics.discardedBytes == 5)

    cancelled.reset()
    #expect(cancelled.metrics == RelayEnvelopeCodecMetrics())
    #expect(try cancelled.consume(pingWire) == [ping])

    var ended = try RelayEnvelopeDecoder(
      maximumFrame: P.maxFrameDefault,
      direction: .clientToRelay
    )
    try ended.endOfStream()
    try ended.endOfStream()
    #expect(try ended.consume(Data()).isEmpty)
    expectFailure(.malformedState) { _ = try ended.consume(Data([0])) }
  }

  @Test("metadata hook is bounded and hook text stays private")
  func metadataHookAndPrivacy() throws {
    enum Rejection: Error { case includesNoRemoteText }
    var decoder = try RelayEnvelopeDecoder(
      maximumFrame: P.maxFrameDefault,
      direction: .clientToRelay,
      metadataValidator: { metadata in
        #expect(metadata.payloadLength == 8)
        #expect(metadata.associationID == 0)
        throw Rejection.includesNoRemoteText
      }
    )
    let pingWire = try encode([legalClientFrames()[1]], direction: .clientToRelay)
    do {
      _ = try decoder.consume(pingWire)
      Issue.record("metadata rejection did not fail")
    } catch let failure as RelayEnvelopeFailure {
      #expect(failure.code == .metadataRejected)
      #expect(!failure.description.contains("includesNoRemoteText"))
      #expect(!failure.description.contains("payload"))
      #expect(!failure.description.contains("destination"))
    }
  }

  @Test("deterministic chunk properties reconcile byte and frame metrics")
  func deterministicChunkProperties() throws {
    let frames = legalClientFrames()
    let wire = try encode(frames, direction: .clientToRelay)

    for seed in UInt64(1)...64 {
      var generator = LCG(state: seed)
      var decoder = try RelayEnvelopeDecoder(
        maximumFrame: P.maxFrameDefault,
        direction: .clientToRelay,
        negotiatedFeatures: [.dnsPriorityHint]
      )
      var offset = 0
      var output: [RelayEnvelope] = []
      while offset < wire.count {
        let width = min(Int(generator.next() % 17) + 1, wire.count - offset)
        output += try decoder.consume(wire.subdata(in: offset..<(offset + width)))
        offset += width
        expectReconciled(decoder.metrics)
      }
      #expect(output == frames)
      #expect(decoder.metrics.outputFrames == UInt64(frames.count))
      #expect(decoder.metrics.failures == 0)
    }
  }

  private func legalClientFrames() -> [RelayEnvelope] {
    [
      RelayEnvelope(
        type: .udpDatagram,
        flags: P.envelopeFlagDNSPriority,
        associationID: 0x0102_0304,
        payload: Data([1, 2, 3, 4, 5])
      ),
      RelayEnvelope(
        type: .ping,
        associationID: 0,
        payload: Data([0, 1, 2, 3, 4, 5, 6, 7])
      ),
      RelayEnvelope(type: .closeAssociation, associationID: UInt32.max),
      RelayEnvelope(type: .closeSession, associationID: 0),
    ]
  }

  private func encode(
    _ frames: [RelayEnvelope],
    maximumFrame: UInt32 = P.maxFrameDefault,
    direction: RelayEnvelopeDirection
  ) throws -> Data {
    var encoder = try RelayEnvelopeEncoder(
      maximumFrame: maximumFrame,
      direction: direction,
      negotiatedFeatures: [.dnsPriorityHint]
    )
    return try frames.reduce(into: Data()) {
      $0.append(try encoder.encode($1).bytes)
    }
  }

  private func expectDecodeFailure(
    _ code: RelayEnvelopeFailureCode,
    wire: Data,
    direction: RelayEnvelopeDirection = .clientToRelay,
    features: RelayFeatureSet = []
  ) throws {
    var decoder = try RelayEnvelopeDecoder(
      maximumFrame: P.maxFrameDefault,
      direction: direction,
      negotiatedFeatures: features
    )
    expectFailure(code) { _ = try decoder.consume(wire) }
    #expect(decoder.metrics.failures == 1)
    #expect(decoder.metrics.retainedBytes == 0)
    #expect(decoder.metrics.inputBytes == decoder.metrics.discardedBytes)
  }

  private func rawFrame(
    type: UInt8,
    flags: UInt8 = 0,
    associationID: UInt32 = 0,
    payload: Data = Data()
  ) -> Data {
    let length = UInt32(P.envelopeHeaderWidth + payload.count)
    var wire = prefix(length)
    wire.append(type)
    wire.append(flags)
    wire.append(UInt8(truncatingIfNeeded: associationID >> 24))
    wire.append(UInt8(truncatingIfNeeded: associationID >> 16))
    wire.append(UInt8(truncatingIfNeeded: associationID >> 8))
    wire.append(UInt8(truncatingIfNeeded: associationID))
    wire.append(payload)
    return wire
  }

  private func prefix(_ length: UInt32) -> Data {
    Data([
      UInt8(truncatingIfNeeded: length >> 24),
      UInt8(truncatingIfNeeded: length >> 16),
      UInt8(truncatingIfNeeded: length >> 8),
      UInt8(truncatingIfNeeded: length),
    ])
  }

  private func readUInt32(_ bytes: Data.SubSequence) -> UInt32 {
    bytes.reduce(0) { ($0 << 8) | UInt32($1) }
  }

  private func expectFailure(
    _ code: RelayEnvelopeFailureCode,
    _ operation: () throws -> Void
  ) {
    do {
      try operation()
      Issue.record("expected failure \(code.rawValue)")
    } catch let failure as RelayEnvelopeFailure {
      #expect(failure.code == code)
      #expect(failure.scope == "session")
      #expect(failure.disposition == "closeSession")
    } catch {
      Issue.record("unexpected error type: \(error)")
    }
  }

  private func expectWireFailure<T>(
    _ code: RelayEnvelopeFailureCode,
    _ operation: () throws -> T
  ) {
    expectFailure(code) { _ = try operation() }
  }

  private func expectReconciled(_ metrics: RelayEnvelopeCodecMetrics) {
    #expect(
      metrics.inputBytes
        == metrics.outputBytes + UInt64(metrics.retainedBytes) + metrics.discardedBytes
    )
  }
}

private struct LCG {
  var state: UInt64

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1
    return state
  }
}
