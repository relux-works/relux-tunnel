import Foundation

public enum RelayEnvelopeDirection: String, Equatable, Sendable {
  case clientToRelay
  case relayToClient
}

public struct RelayEnvelope: Equatable, Sendable {
  public let type: RelayProtocolV1.MessageType
  public let flags: UInt8
  public let associationID: UInt32
  public let payload: Data

  public init(
    type: RelayProtocolV1.MessageType,
    flags: UInt8 = 0,
    associationID: UInt32,
    payload: Data = Data()
  ) {
    self.type = type
    self.flags = flags
    self.associationID = associationID
    self.payload = payload
  }
}

public struct RelayEnvelopeMetadata: Equatable, Sendable {
  public let type: RelayProtocolV1.MessageType
  public let flags: UInt8
  public let associationID: UInt32
  public let payloadLength: Int
  public let direction: RelayEnvelopeDirection

  public init(
    type: RelayProtocolV1.MessageType,
    flags: UInt8,
    associationID: UInt32,
    payloadLength: Int,
    direction: RelayEnvelopeDirection
  ) {
    self.type = type
    self.flags = flags
    self.associationID = associationID
    self.payloadLength = payloadLength
    self.direction = direction
  }
}

/// A hook for message-specific admission checks that need only bounded envelope
/// metadata. Thrown values are deliberately collapsed to `metadataRejected`.
public typealias RelayEnvelopeMetadataValidator =
  @Sendable (RelayEnvelopeMetadata) throws -> Void

public enum RelayEnvelopeFailureCode: String, CaseIterable, Equatable, Sendable {
  case invalidConfiguration
  case frameLengthBelowMinimum
  case frameLengthExceedsMaximum
  case arithmeticOverflow
  case unknownMessageType
  case reservedFlags
  case invalidFlags
  case invalidDirection
  case invalidAssociationID
  case invalidPayloadLength
  case metadataRejected
  case unexpectedEOF
  case cancelled
  case malformedState
}

public enum RelayEnvelopePhase: String, Equatable, Sendable {
  case configuration
  case encoding
  case prefix
  case header
  case metadata
  case body
  case terminal
}

public struct RelayEnvelopeFailure: Error, Equatable, Sendable, CustomStringConvertible {
  public let code: RelayEnvelopeFailureCode
  public let phase: RelayEnvelopePhase
  public let scope = "session"
  public let disposition = "closeSession"

  public init(code: RelayEnvelopeFailureCode, phase: RelayEnvelopePhase) {
    self.code = code
    self.phase = phase
  }

  public var description: String {
    "relayEnvelope code=\(code.rawValue) phase=\(phase.rawValue) "
      + "scope=\(scope) disposition=\(disposition)"
  }
}

public struct RelayEnvelopeCodecMetrics: Equatable, Sendable {
  public fileprivate(set) var inputBytes: UInt64 = 0
  public fileprivate(set) var outputBytes: UInt64 = 0
  public fileprivate(set) var outputFrames: UInt64 = 0
  public fileprivate(set) var retainedBytes: Int = 0
  public fileprivate(set) var peakRetainedBytes: Int = 0
  public fileprivate(set) var bodyAllocations: UInt64 = 0
  public fileprivate(set) var allocatedBodyBytes: Int = 0
  public fileprivate(set) var peakAllocatedBodyBytes: Int = 0
  public fileprivate(set) var processingIterations: UInt64 = 0
  public fileprivate(set) var discardedBytes: UInt64 = 0
  public fileprivate(set) var failures: UInt64 = 0

  public init() {}
}

public struct RelayEnvelopeWrite: Equatable, Sendable {
  /// The prefix/header and payload are separate so callers can retry only an
  /// unwritten suffix without first copying payload bytes into a larger buffer.
  public let slices: [Data]
  public let byteCount: Int

  fileprivate init(header: Data, payload: Data) {
    slices = payload.isEmpty ? [header] : [header, payload]
    byteCount = header.count + payload.count
  }

  public var bytes: Data {
    slices.reduce(into: Data()) { $0.append($1) }
  }
}

public enum RelayEnvelopeWire {
  public static func frameLength(
    payloadLength: UInt64,
    maximumFrame: UInt32
  ) throws -> UInt32 {
    guard
      maximumFrame >= RelayProtocolV1.minFrameLength,
      maximumFrame <= RelayProtocolV1.maxFrameHardCeiling
    else {
      throw RelayEnvelopeFailure(code: .invalidConfiguration, phase: .configuration)
    }
    let headerWidth = UInt64(RelayProtocolV1.envelopeHeaderWidth)
    let (length, overflow) = payloadLength.addingReportingOverflow(headerWidth)
    guard !overflow, length <= UInt64(UInt32.max) else {
      throw RelayEnvelopeFailure(code: .arithmeticOverflow, phase: .encoding)
    }
    guard length <= UInt64(maximumFrame) else {
      throw RelayEnvelopeFailure(code: .frameLengthExceedsMaximum, phase: .encoding)
    }
    return UInt32(length)
  }
}

public struct RelayEnvelopeEncoder: Sendable {
  public let maximumFrame: UInt32
  public let direction: RelayEnvelopeDirection
  public let negotiatedFeatures: RelayFeatureSet
  public private(set) var metrics = RelayEnvelopeCodecMetrics()
  private let metadataValidator: RelayEnvelopeMetadataValidator?

  public init(
    maximumFrame: UInt32,
    direction: RelayEnvelopeDirection,
    negotiatedFeatures: RelayFeatureSet = [],
    metadataValidator: RelayEnvelopeMetadataValidator? = nil
  ) throws {
    guard
      maximumFrame >= RelayProtocolV1.minFrameLength,
      maximumFrame <= RelayProtocolV1.maxFrameHardCeiling,
      negotiatedFeatures.rawValue & RelayProtocolV1.featuresReservedMask == 0
    else {
      throw RelayEnvelopeFailure(code: .invalidConfiguration, phase: .configuration)
    }
    self.maximumFrame = maximumFrame
    self.direction = direction
    self.negotiatedFeatures = negotiatedFeatures
    self.metadataValidator = metadataValidator
  }

  public mutating func encode(_ envelope: RelayEnvelope) throws -> RelayEnvelopeWrite {
    do {
      let frameLength = try RelayEnvelopeWire.frameLength(
        payloadLength: UInt64(envelope.payload.count),
        maximumFrame: maximumFrame
      )
      let metadata = RelayEnvelopeMetadata(
        type: envelope.type,
        flags: envelope.flags,
        associationID: envelope.associationID,
        payloadLength: envelope.payload.count,
        direction: direction
      )
      try validateRelayEnvelopeMetadata(
        metadata,
        negotiatedFeatures: negotiatedFeatures,
        hook: metadataValidator,
        phase: .encoding
      )

      var header = Data()
      header.reserveCapacity(
        RelayProtocolV1.framePrefixWidth + RelayProtocolV1.envelopeHeaderWidth
      )
      appendBigEndian(frameLength, to: &header)
      header.append(envelope.type.rawValue)
      header.append(envelope.flags)
      appendBigEndian(envelope.associationID, to: &header)

      let write = RelayEnvelopeWrite(header: header, payload: envelope.payload)
      metrics.outputFrames += 1
      metrics.outputBytes += UInt64(write.byteCount)
      return write
    } catch let failure as RelayEnvelopeFailure {
      metrics.failures += 1
      throw failure
    } catch {
      metrics.failures += 1
      throw RelayEnvelopeFailure(code: .metadataRejected, phase: .metadata)
    }
  }
}

public struct RelayEnvelopeDecoder: Sendable {
  private enum State: Sendable {
    case receiving
    case ended
    case failed(RelayEnvelopeFailure)
  }

  public let maximumFrame: UInt32
  public let direction: RelayEnvelopeDirection
  public let negotiatedFeatures: RelayFeatureSet
  public private(set) var metrics = RelayEnvelopeCodecMetrics()

  private let metadataValidator: RelayEnvelopeMetadataValidator?
  private var state: State = .receiving
  private var prefix: [UInt8] = []
  private var body = Data()
  private var expectedBodyLength: Int?
  private var headerValidated = false

  /// True only when the next byte starts a fresh frame-length prefix. Session
  /// policy uses this to classify a post-handshake `RLXR` prefix without
  /// adding handshake lookahead or weakening incremental framing.
  public var isAtFrameBoundary: Bool {
    if case .receiving = state {
      return prefix.isEmpty && body.isEmpty && expectedBodyLength == nil
    }
    return false
  }

  public init(
    maximumFrame: UInt32,
    direction: RelayEnvelopeDirection,
    negotiatedFeatures: RelayFeatureSet = [],
    metadataValidator: RelayEnvelopeMetadataValidator? = nil
  ) throws {
    guard
      maximumFrame >= RelayProtocolV1.minFrameLength,
      maximumFrame <= RelayProtocolV1.maxFrameHardCeiling,
      negotiatedFeatures.rawValue & RelayProtocolV1.featuresReservedMask == 0
    else {
      throw RelayEnvelopeFailure(code: .invalidConfiguration, phase: .configuration)
    }
    self.maximumFrame = maximumFrame
    self.direction = direction
    self.negotiatedFeatures = negotiatedFeatures
    self.metadataValidator = metadataValidator
    prefix.reserveCapacity(RelayProtocolV1.framePrefixWidth)
  }

  public mutating func consume(_ bytes: Data) throws -> [RelayEnvelope] {
    switch state {
    case .failed(let failure):
      throw failure
    case .ended:
      guard bytes.isEmpty else {
        metrics.inputBytes += UInt64(bytes.count)
        throw terminalFailure(.malformedState, phase: .terminal)
      }
      return []
    case .receiving:
      break
    }

    guard !bytes.isEmpty else { return [] }
    metrics.inputBytes += UInt64(bytes.count)
    let outputBytesBeforeConsume = metrics.outputBytes
    let outputFramesBeforeConsume = metrics.outputFrames
    var frames: [RelayEnvelope] = []

    do {
      for byte in bytes {
        metrics.processingIterations += 1
        if expectedBodyLength == nil {
          prefix.append(byte)
          updateRetainedMetrics()
          if prefix.count == RelayProtocolV1.framePrefixWidth {
            metrics.processingIterations += 1
            try acceptPrefix()
          }
          continue
        }

        body.append(byte)
        updateRetainedMetrics()
        if !headerValidated, body.count == RelayProtocolV1.envelopeHeaderWidth {
          metrics.processingIterations += 1
          try validateCurrentHeader()
          headerValidated = true
        }
        if body.count == expectedBodyLength {
          metrics.processingIterations += 1
          frames.append(try finishCurrentFrame())
        } else if let expectedBodyLength, body.count > expectedBodyLength {
          throw RelayEnvelopeFailure(code: .malformedState, phase: .body)
        }
      }
      return frames
    } catch let failure as RelayEnvelopeFailure {
      metrics.outputBytes = outputBytesBeforeConsume
      metrics.outputFrames = outputFramesBeforeConsume
      throw terminalize(failure)
    } catch {
      metrics.outputBytes = outputBytesBeforeConsume
      metrics.outputFrames = outputFramesBeforeConsume
      throw terminalize(
        RelayEnvelopeFailure(code: .metadataRejected, phase: .metadata)
      )
    }
  }

  public mutating func endOfStream() throws {
    switch state {
    case .failed(let failure):
      throw failure
    case .ended:
      return
    case .receiving:
      guard prefix.isEmpty, body.isEmpty, expectedBodyLength == nil else {
        throw terminalFailure(.unexpectedEOF, phase: .terminal)
      }
      state = .ended
    }
  }

  public mutating func cancel() throws {
    switch state {
    case .failed(let failure):
      throw failure
    case .ended:
      return
    case .receiving:
      throw terminalFailure(.cancelled, phase: .terminal)
    }
  }

  public mutating func reset() {
    state = .receiving
    clearScratch()
    metrics = RelayEnvelopeCodecMetrics()
  }

  private mutating func acceptPrefix() throws {
    guard prefix.count == RelayProtocolV1.framePrefixWidth else {
      throw RelayEnvelopeFailure(code: .malformedState, phase: .prefix)
    }
    let length = prefix.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    guard length >= RelayProtocolV1.minFrameLength else {
      throw RelayEnvelopeFailure(code: .frameLengthBelowMinimum, phase: .prefix)
    }
    guard length <= maximumFrame else {
      throw RelayEnvelopeFailure(code: .frameLengthExceedsMaximum, phase: .prefix)
    }
    guard UInt64(length) <= UInt64(Int.max) else {
      throw RelayEnvelopeFailure(code: .arithmeticOverflow, phase: .prefix)
    }

    expectedBodyLength = Int(length)
    body.reserveCapacity(Int(length))
    metrics.bodyAllocations += 1
    metrics.allocatedBodyBytes = Int(length)
    metrics.peakAllocatedBodyBytes = max(
      metrics.peakAllocatedBodyBytes,
      metrics.allocatedBodyBytes
    )
  }

  private mutating func validateCurrentHeader() throws {
    guard
      let expectedBodyLength,
      body.count == RelayProtocolV1.envelopeHeaderWidth,
      expectedBodyLength >= RelayProtocolV1.envelopeHeaderWidth
    else {
      throw RelayEnvelopeFailure(code: .malformedState, phase: .header)
    }
    guard let type = RelayProtocolV1.MessageType(rawValue: body[body.startIndex]) else {
      throw RelayEnvelopeFailure(code: .unknownMessageType, phase: .header)
    }
    let flagsIndex = body.index(after: body.startIndex)
    let associationStart = body.index(flagsIndex, offsetBy: 1)
    let associationEnd = body.index(
      associationStart,
      offsetBy: MemoryLayout<UInt32>.size
    )
    let associationID = body[associationStart..<associationEnd].reduce(UInt32(0)) {
      ($0 << 8) | UInt32($1)
    }
    let metadata = RelayEnvelopeMetadata(
      type: type,
      flags: body[flagsIndex],
      associationID: associationID,
      payloadLength: expectedBodyLength - RelayProtocolV1.envelopeHeaderWidth,
      direction: direction
    )
    try validateRelayEnvelopeMetadata(
      metadata,
      negotiatedFeatures: negotiatedFeatures,
      hook: metadataValidator,
      phase: .header
    )
  }

  private mutating func finishCurrentFrame() throws -> RelayEnvelope {
    guard
      let expectedBodyLength,
      body.count == expectedBodyLength,
      headerValidated
    else {
      throw RelayEnvelopeFailure(code: .malformedState, phase: .body)
    }
    guard let type = RelayProtocolV1.MessageType(rawValue: body[body.startIndex]) else {
      throw RelayEnvelopeFailure(code: .unknownMessageType, phase: .header)
    }
    let flagsIndex = body.index(after: body.startIndex)
    let associationStart = body.index(flagsIndex, offsetBy: 1)
    let payloadStart = body.index(
      associationStart,
      offsetBy: MemoryLayout<UInt32>.size
    )
    let associationID = body[associationStart..<payloadStart].reduce(UInt32(0)) {
      ($0 << 8) | UInt32($1)
    }
    let frame = RelayEnvelope(
      type: type,
      flags: body[flagsIndex],
      associationID: associationID,
      payload: Data(body[payloadStart...])
    )
    metrics.outputFrames += 1
    metrics.outputBytes += UInt64(
      RelayProtocolV1.framePrefixWidth + expectedBodyLength
    )
    clearScratch()
    updateRetainedMetrics()
    return frame
  }

  private mutating func terminalFailure(
    _ code: RelayEnvelopeFailureCode,
    phase: RelayEnvelopePhase
  ) -> RelayEnvelopeFailure {
    terminalize(RelayEnvelopeFailure(code: code, phase: phase))
  }

  private mutating func terminalize(
    _ failure: RelayEnvelopeFailure
  ) -> RelayEnvelopeFailure {
    state = .failed(failure)
    clearScratch()
    metrics.retainedBytes = 0
    metrics.discardedBytes = metrics.inputBytes - metrics.outputBytes
    metrics.failures += 1
    return failure
  }

  private mutating func clearScratch() {
    prefix.removeAll(keepingCapacity: false)
    prefix.reserveCapacity(RelayProtocolV1.framePrefixWidth)
    body.removeAll(keepingCapacity: false)
    expectedBodyLength = nil
    headerValidated = false
    metrics.allocatedBodyBytes = 0
  }

  private mutating func updateRetainedMetrics() {
    metrics.retainedBytes = prefix.count + body.count
    metrics.peakRetainedBytes = max(
      metrics.peakRetainedBytes,
      metrics.retainedBytes
    )
  }
}

private func validateRelayEnvelopeMetadata(
  _ metadata: RelayEnvelopeMetadata,
  negotiatedFeatures: RelayFeatureSet,
  hook: RelayEnvelopeMetadataValidator?,
  phase: RelayEnvelopePhase
) throws {
  guard metadata.flags & RelayProtocolV1.envelopeFlagsReservedMask == 0 else {
    throw RelayEnvelopeFailure(code: .reservedFlags, phase: phase)
  }
  if metadata.flags != 0 {
    guard
      metadata.flags == RelayProtocolV1.envelopeFlagDNSPriority,
      metadata.type == .udpDatagram,
      metadata.direction == .clientToRelay,
      negotiatedFeatures.contains(.dnsPriorityHint)
    else {
      throw RelayEnvelopeFailure(code: .invalidFlags, phase: phase)
    }
  }
  guard
    let generated = RelayProtocolV1.messageMetadata.first(where: {
      $0.type == metadata.type
    })
  else {
    throw RelayEnvelopeFailure(code: .unknownMessageType, phase: phase)
  }
  switch generated.direction {
  case .both:
    break
  case .clientToRelay:
    guard metadata.direction == .clientToRelay else {
      throw RelayEnvelopeFailure(code: .invalidDirection, phase: phase)
    }
  case .relayToClient:
    guard metadata.direction == .relayToClient else {
      throw RelayEnvelopeFailure(code: .invalidDirection, phase: phase)
    }
  }
  switch generated.associationID {
  case .zero:
    guard metadata.associationID == 0 else {
      throw RelayEnvelopeFailure(code: .invalidAssociationID, phase: phase)
    }
  case .nonzero:
    guard metadata.associationID != 0 else {
      throw RelayEnvelopeFailure(code: .invalidAssociationID, phase: phase)
    }
  }
  if generated.payloadShape == .fixed {
    guard metadata.payloadLength == generated.fixedPayloadWidth else {
      throw RelayEnvelopeFailure(code: .invalidPayloadLength, phase: phase)
    }
  }
  guard let hook else { return }
  do {
    try hook(metadata)
  } catch {
    throw RelayEnvelopeFailure(code: .metadataRejected, phase: .metadata)
  }
}

private func appendBigEndian(_ value: UInt32, to bytes: inout Data) {
  bytes.append(UInt8(truncatingIfNeeded: value >> 24))
  bytes.append(UInt8(truncatingIfNeeded: value >> 16))
  bytes.append(UInt8(truncatingIfNeeded: value >> 8))
  bytes.append(UInt8(truncatingIfNeeded: value))
}
