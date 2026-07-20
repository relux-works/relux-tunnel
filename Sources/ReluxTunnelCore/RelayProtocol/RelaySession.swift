import Foundation

public enum RelaySessionPeer: String, Equatable, Sendable {
  case client
  case relay

  fileprivate var inboundDirection: RelayEnvelopeDirection {
    self == .client ? .relayToClient : .clientToRelay
  }

  fileprivate var outboundDirection: RelayEnvelopeDirection {
    self == .client ? .clientToRelay : .relayToClient
  }
}

public enum RelaySessionResponsePolicy: String, Equatable, Sendable {
  case none
  case generatedUDPErrorOnFailure
  case echoPong
  case closeAssociationAcknowledgement
  case closeSessionAcknowledgement
}

public enum RelaySessionCloseEffect: String, Equatable, Sendable {
  case none
  case closeAssociationOnMalformedDatagram
  case recordAssociationError
  case closeAssociation
  case closeSession
}

public struct RelaySessionTransition: Equatable, Sendable {
  public let type: RelayProtocolV1.MessageType
  public let direction: RelayProtocolV1.MessageDirection
  public let associationID: RelayProtocolV1.AssociationIDRule
  public let minimumPayloadBytes: Int
  public let maximumPayloadBytes: Int
  public let response: RelaySessionResponsePolicy
  public let closeEffect: RelaySessionCloseEffect
}

/// The executable v1 transition table. Direction, association-ID, and fixed
/// payload rules come from generated metadata; only state-machine effects are
/// handwritten here.
public enum RelaySessionTransitions {
  public static let v1: [RelaySessionTransition] =
    RelayProtocolV1.messageMetadata.map { metadata in
      let payloadBounds =
        metadata.payloadShape == .fixed
        ? (metadata.fixedPayloadWidth, metadata.fixedPayloadWidth)
        : (0, RelayProtocolV1.maxHEVRecordWidth)
      let policy: (RelaySessionResponsePolicy, RelaySessionCloseEffect) =
        switch metadata.type {
        case .udpDatagram:
          (.generatedUDPErrorOnFailure, .closeAssociationOnMalformedDatagram)
        case .udpError:
          (.none, .recordAssociationError)
        case .ping:
          (.echoPong, .none)
        case .pong:
          (.none, .none)
        case .closeAssociation:
          (.closeAssociationAcknowledgement, .closeAssociation)
        case .closeSession:
          (.closeSessionAcknowledgement, .closeSession)
        }
      return RelaySessionTransition(
        type: metadata.type,
        direction: metadata.direction,
        associationID: metadata.associationID,
        minimumPayloadBytes: payloadBounds.0,
        maximumPayloadBytes: payloadBounds.1,
        response: policy.0,
        closeEffect: policy.1
      )
    }

  fileprivate static func transition(
    for type: RelayProtocolV1.MessageType
  ) -> RelaySessionTransition? {
    v1.first { $0.type == type }
  }
}

public enum RelaySessionState: String, Equatable, Sendable {
  case active
  case closed
}

public enum RelaySessionFailureCode: String, CaseIterable, Equatable, Sendable {
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
  case transportFailure
  case postHandshakeHello
}

public enum RelaySessionFailurePhase: String, Equatable, Sendable {
  case envelope
  case lifecycle
}

public struct RelaySessionFailure: Error, Equatable, Sendable, CustomStringConvertible {
  public let code: RelaySessionFailureCode
  public let phase: RelaySessionFailurePhase
  public let scope = "session"
  public let disposition = "closeSession"

  public var description: String {
    "relaySession code=\(code.rawValue) phase=\(phase.rawValue) "
      + "scope=\(scope) disposition=\(disposition)"
  }
}

public enum RelaySessionTerminationReason: String, Equatable, Sendable {
  case localClose
  case peerClose
  case endOfStream
  case cancelled
  case transportFailure
  case protocolViolation
  case postHandshakeHello
}

public enum RelayRemoteAssociationError: Equatable, Sendable {
  case generated(RelayProtocolV1.UDPErrorCode)
  case unknownRelayError
}

public enum RelaySessionEvent: Equatable, Sendable {
  case datagram(associationID: UInt32, RelayDatagram)
  case udpError(associationID: UInt32, RelayRemoteAssociationError)
  case pong(Data)
}

public struct RelaySessionMetrics: Equatable, Sendable {
  public fileprivate(set) var receivedFrames: UInt64 = 0
  public fileprivate(set) var sentFrames: UInt64 = 0
  public fileprivate(set) var datagramsAccepted: UInt64 = 0
  public fileprivate(set) var datagramsRejected: UInt64 = 0
  public fileprivate(set) var pingsReceived: UInt64 = 0
  public fileprivate(set) var pongsReceived: UInt64 = 0
  public fileprivate(set) var udpErrorsReceived: UInt64 = 0
  public fileprivate(set) var udpErrorsSent: UInt64 = 0
  public fileprivate(set) var associationClosesReceived: UInt64 = 0
  public fileprivate(set) var associationClosesSent: UInt64 = 0
  public fileprivate(set) var sessionClosesReceived: UInt64 = 0
  public fileprivate(set) var sessionClosesSent: UInt64 = 0
  public fileprivate(set) var associationCleanups: UInt64 = 0
  public fileprivate(set) var sessionCleanups: UInt64 = 0
  public fileprivate(set) var staleCallbacks: UInt64 = 0
  public fileprivate(set) var lateCallbacks: UInt64 = 0
  public fileprivate(set) var sessionFailures: UInt64 = 0

  public init() {}
}

public struct RelaySessionStep: Equatable, Sendable {
  public let state: RelaySessionState
  public let outbound: [RelayEnvelope]
  public let events: [RelaySessionEvent]
  public let failure: RelaySessionFailure?
  public let staleCallbackIgnored: Bool

  fileprivate init(
    state: RelaySessionState,
    outbound: [RelayEnvelope] = [],
    events: [RelaySessionEvent] = [],
    failure: RelaySessionFailure? = nil,
    staleCallbackIgnored: Bool = false
  ) {
    self.state = state
    self.outbound = outbound
    self.events = events
    self.failure = failure
    self.staleCallbackIgnored = staleCallbackIgnored
  }
}

public typealias RelayAssociationCleanup =
  @Sendable (_ generation: UInt64, _ associationID: UInt32) -> Void
public typealias RelayGenerationCleanup =
  @Sendable (_ generation: UInt64, _ reason: RelaySessionTerminationReason) -> Void

public struct RelaySession: Sendable {
  private enum AssociationAdmission: Equatable {
    case admitted
    case unknownOrClosed
    case limitExceeded
  }

  private struct Association: Sendable {
    var isActive = true
    var localCloseSent = false
    var peerCloseReceived = false
    var cleanupInvoked = false
    var queueSaturationReported = false

    var isRetired: Bool { !isActive && localCloseSent && peerCloseReceived }
  }

  public let generation: UInt64
  public let peer: RelaySessionPeer
  public private(set) var state: RelaySessionState = .active
  public private(set) var metrics = RelaySessionMetrics()

  private var decoder: RelayEnvelopeDecoder
  private var datagramCodec: RelayDatagramCodec
  private var postHandshakeMagicPrefix = Data()
  private var associations: [UInt32: Association] = [:]
  private var sessionCloseSent = false
  private var sessionCleanupInvoked = false
  private let negotiatedFeatures: RelayFeatureSet
  private let maximumAssociations: Int
  private let queueSaturationRecoveryBytes: UInt32
  private let associationCleanup: RelayAssociationCleanup?
  private let generationCleanup: RelayGenerationCleanup?

  public init(
    generation: UInt64,
    peer: RelaySessionPeer,
    limits: RelayEffectiveLimits,
    negotiatedFeatures: RelayFeatureSet = [],
    associationCleanup: RelayAssociationCleanup? = nil,
    generationCleanup: RelayGenerationCleanup? = nil
  ) throws {
    let maximumAssociationLimit =
      peer == .client
      ? RelayProtocolV1.maxAssociationsClientHardCeiling
      : RelayProtocolV1.maxAssociationsRelayHardCeiling
    guard
      limits.maxAssociations >= RelayProtocolV1.maxAssociationsFloor,
      limits.maxAssociations <= maximumAssociationLimit
    else {
      throw RelaySessionFailure(code: .malformedState, phase: .lifecycle)
    }
    self.generation = generation
    self.peer = peer
    self.negotiatedFeatures = negotiatedFeatures
    maximumAssociations = Int(limits.maxAssociations)
    queueSaturationRecoveryBytes = limits.perAssociationQueuedBytes / 2
    self.associationCleanup = associationCleanup
    self.generationCleanup = generationCleanup
    decoder = try RelayEnvelopeDecoder(
      maximumFrame: limits.effectiveMaxFrame,
      direction: peer.inboundDirection,
      negotiatedFeatures: negotiatedFeatures
    )
    datagramCodec = try RelayDatagramCodec(
      maximumPayloadLength: limits.maxUDPPayload
    )
  }

  public mutating func receive(
    _ bytes: Data,
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    guard callbackGeneration == generation else { return staleStep() }
    guard state == .active else { return lateStep() }

    let inspected = inspectPostHandshakePrefix(bytes)
    if inspected.detected {
      return fail(.postHandshakeHello, phase: .envelope, reason: .postHandshakeHello)
    }
    guard let input = inspected.input else {
      return RelaySessionStep(state: state)
    }
    do {
      let frames = try decoder.consume(input)
      var outbound: [RelayEnvelope] = []
      var events: [RelaySessionEvent] = []
      var failure: RelaySessionFailure?
      for frame in frames {
        let step = receiveDecoded(frame)
        outbound.append(contentsOf: step.outbound)
        events.append(contentsOf: step.events)
        failure = failure ?? step.failure
      }
      return RelaySessionStep(
        state: state,
        outbound: outbound,
        events: events,
        failure: failure
      )
    } catch let envelopeFailure as RelayEnvelopeFailure {
      return fail(
        mapEnvelopeFailure(envelopeFailure.code),
        phase: .envelope,
        reason: .protocolViolation
      )
    } catch {
      return fail(.malformedState, phase: .envelope, reason: .protocolViolation)
    }
  }

  /// Handles an already-decoded frame. This repeats the transition-table
  /// checks so callers cannot bypass session policy by bypassing the stream
  /// decoder.
  public mutating func receive(
    _ frame: RelayEnvelope,
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    guard callbackGeneration == generation else { return staleStep() }
    if state == .closed {
      recordLateFrame(frame)
      return lateStep(count: false)
    }
    if let violation = validate(frame, direction: peer.inboundDirection) {
      return fail(violation, phase: .envelope, reason: .protocolViolation)
    }
    return receiveDecoded(frame)
  }

  /// Admits a locally produced frame and updates lifecycle state before the
  /// caller encodes it. Only generated finite message/error values can enter.
  public mutating func send(
    _ frame: RelayEnvelope,
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    guard callbackGeneration == generation else { return staleStep() }
    guard state == .active else { return lateStep() }
    if let violation = validate(frame, direction: peer.outboundDirection) {
      return fail(violation, phase: .envelope, reason: .protocolViolation)
    }

    var outbound: [RelayEnvelope] = []
    switch frame.type {
    case .udpDatagram:
      do {
        _ = try datagramCodec.decode(frame.payload)
      } catch {
        metrics.datagramsRejected += 1
        return RelaySessionStep(state: state)
      }
      let canSend =
        if peer == .client {
          admitClientOwnedAssociation(frame.associationID) == .admitted
        } else {
          associations[frame.associationID]?.isActive == true
        }
      guard canSend else {
        metrics.datagramsRejected += 1
        return RelaySessionStep(state: state)
      }
      emit(frame, into: &outbound)
    case .closeAssociation:
      initiateAssociationClose(frame.associationID, into: &outbound)
    case .closeSession:
      initiateSessionClose(into: &outbound)
    case .udpError, .pong:
      // These are response-only. UDP errors must pass through the generated
      // code API, and PONG must be created only by the bounded PING echo path.
      return fail(.metadataRejected, phase: .lifecycle, reason: .protocolViolation)
    case .ping:
      emit(frame, into: &outbound)
    }
    return RelaySessionStep(state: state, outbound: outbound)
  }

  /// Emits an association-local relay failure using a generated finite code.
  /// No remote or OS diagnostic string is accepted by this API.
  public mutating func reportAssociationFailure(
    associationID: UInt32,
    code: RelayProtocolV1.UDPErrorCode,
    closeAssociation: Bool,
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    guard callbackGeneration == generation else { return staleStep() }
    guard state == .active else { return lateStep() }
    guard peer == .relay, associationID != 0 else {
      return fail(.invalidDirection, phase: .lifecycle, reason: .protocolViolation)
    }
    guard code != .queueSaturated, code != .idleExpiry else {
      return fail(.metadataRejected, phase: .lifecycle, reason: .protocolViolation)
    }
    guard associations[associationID]?.isActive == true else {
      return RelaySessionStep(state: state)
    }
    var outbound: [RelayEnvelope] = []
    emitUDPError(code, associationID: associationID, into: &outbound)
    if closeAssociation {
      initiateAssociationClose(associationID, into: &outbound)
    }
    return RelaySessionStep(state: state, outbound: outbound)
  }

  /// Records a dropped relay datagram and emits at most one queue-saturation
  /// signal until the owning queue reports recovery below the configured
  /// half-cap threshold.
  public mutating func reportQueueSaturation(
    associationID: UInt32,
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    guard callbackGeneration == generation else { return staleStep() }
    guard state == .active else { return lateStep() }
    guard peer == .relay else {
      return fail(.invalidDirection, phase: .lifecycle, reason: .protocolViolation)
    }
    guard associationID != 0 else {
      return fail(.invalidAssociationID, phase: .lifecycle, reason: .protocolViolation)
    }

    metrics.datagramsRejected += 1
    guard var association = associations[associationID], association.isActive else {
      return RelaySessionStep(state: state)
    }
    guard !association.queueSaturationReported else {
      return RelaySessionStep(state: state)
    }
    association.queueSaturationReported = true
    associations[associationID] = association
    var outbound: [RelayEnvelope] = []
    emitUDPError(.queueSaturated, associationID: associationID, into: &outbound)
    return RelaySessionStep(state: state, outbound: outbound)
  }

  /// Rearms the saturation edge only after the queue is at or below 50% of
  /// the injected per-association byte cap.
  public mutating func recordAssociationQueueDepth(
    associationID: UInt32,
    queuedBytes: UInt32,
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    guard callbackGeneration == generation else { return staleStep() }
    guard state == .active else { return lateStep() }
    guard peer == .relay else {
      return fail(.invalidDirection, phase: .lifecycle, reason: .protocolViolation)
    }
    guard associationID != 0 else {
      return fail(.invalidAssociationID, phase: .lifecycle, reason: .protocolViolation)
    }
    guard
      queuedBytes <= queueSaturationRecoveryBytes,
      var association = associations[associationID],
      association.isActive
    else { return RelaySessionStep(state: state) }
    association.queueSaturationReported = false
    associations[associationID] = association
    return RelaySessionStep(state: state)
  }

  /// Applies the protocol-owned idle-expiry disposition atomically:
  /// finite error, retirement/cleanup, then one association close.
  public mutating func reportIdleExpiry(
    associationID: UInt32,
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    guard callbackGeneration == generation else { return staleStep() }
    guard state == .active else { return lateStep() }
    guard peer == .relay else {
      return fail(.invalidDirection, phase: .lifecycle, reason: .protocolViolation)
    }
    guard associationID != 0 else {
      return fail(.invalidAssociationID, phase: .lifecycle, reason: .protocolViolation)
    }
    guard associations[associationID]?.isActive == true else {
      return RelaySessionStep(state: state)
    }
    var outbound: [RelayEnvelope] = []
    emitUDPError(.idleExpiry, associationID: associationID, into: &outbound)
    initiateAssociationClose(associationID, into: &outbound)
    return RelaySessionStep(state: state, outbound: outbound)
  }

  public mutating func closeAssociation(
    _ associationID: UInt32,
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    guard callbackGeneration == generation else { return staleStep() }
    guard state == .active else { return lateStep() }
    guard associationID != 0 else {
      return fail(.invalidAssociationID, phase: .lifecycle, reason: .protocolViolation)
    }
    var outbound: [RelayEnvelope] = []
    initiateAssociationClose(associationID, into: &outbound)
    return RelaySessionStep(state: state, outbound: outbound)
  }

  public mutating func closeSession(
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    guard callbackGeneration == generation else { return staleStep() }
    guard state == .active else { return lateStep() }
    var outbound: [RelayEnvelope] = []
    initiateSessionClose(into: &outbound)
    return RelaySessionStep(state: state, outbound: outbound)
  }

  public mutating func endOfStream(
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    terminalEvent(
      generation: callbackGeneration,
      code: .unexpectedEOF,
      reason: .endOfStream
    )
  }

  public mutating func cancel(
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    terminalEvent(generation: callbackGeneration, code: .cancelled, reason: .cancelled)
  }

  public mutating func transportFailed(
    generation callbackGeneration: UInt64
  ) -> RelaySessionStep {
    terminalEvent(
      generation: callbackGeneration,
      code: .transportFailure,
      reason: .transportFailure
    )
  }

  private mutating func receiveDecoded(_ frame: RelayEnvelope) -> RelaySessionStep {
    guard state == .active else {
      recordLateFrame(frame)
      return lateStep(count: false)
    }
    metrics.receivedFrames += 1
    var outbound: [RelayEnvelope] = []
    var events: [RelaySessionEvent] = []

    switch frame.type {
    case .udpDatagram:
      handleDatagram(frame, outbound: &outbound, events: &events)
    case .udpError:
      metrics.udpErrorsReceived += 1
      guard associations[frame.associationID]?.isActive == true else {
        closeRejectedAssociation(frame.associationID, into: &outbound)
        break
      }
      let raw =
        (UInt16(frame.payload[frame.payload.startIndex]) << 8)
        | UInt16(frame.payload[frame.payload.index(after: frame.payload.startIndex)])
      let error: RelayRemoteAssociationError =
        RelayProtocolV1.UDPErrorCode(rawValue: raw).map {
          .generated($0)
        } ?? .unknownRelayError
      events.append(.udpError(associationID: frame.associationID, error))
    case .ping:
      metrics.pingsReceived += 1
      emit(
        RelayEnvelope(type: .pong, associationID: 0, payload: frame.payload),
        into: &outbound
      )
    case .pong:
      metrics.pongsReceived += 1
      events.append(.pong(frame.payload))
    case .closeAssociation:
      metrics.associationClosesReceived += 1
      receiveAssociationClose(frame.associationID, into: &outbound)
    case .closeSession:
      metrics.sessionClosesReceived += 1
      if !sessionCloseSent {
        sessionCloseSent = true
        metrics.sessionClosesSent += 1
        emit(
          RelayEnvelope(type: .closeSession, associationID: 0),
          into: &outbound
        )
      }
      terminate(reason: .peerClose)
    }
    return RelaySessionStep(state: state, outbound: outbound, events: events)
  }

  private mutating func handleDatagram(
    _ frame: RelayEnvelope,
    outbound: inout [RelayEnvelope],
    events: inout [RelaySessionEvent]
  ) {
    let datagram: RelayDatagram
    do {
      datagram = try datagramCodec.decode(frame.payload)
    } catch let failure as RelayDatagramFailure {
      metrics.datagramsRejected += 1
      if peer == .relay {
        emitUDPError(
          udpErrorCode(for: failure),
          associationID: frame.associationID,
          into: &outbound
        )
      }
      if failure.disposition == .closeAssociation {
        closeRejectedAssociation(frame.associationID, into: &outbound)
      }
      return
    } catch {
      metrics.datagramsRejected += 1
      if peer == .relay {
        emitUDPError(
          .invalidDatagram,
          associationID: frame.associationID,
          into: &outbound
        )
      }
      closeRejectedAssociation(frame.associationID, into: &outbound)
      return
    }

    if peer == .client {
      guard associations[frame.associationID]?.isActive == true else {
        metrics.datagramsRejected += 1
        closeRejectedAssociation(frame.associationID, into: &outbound)
        return
      }
    } else {
      switch admitClientOwnedAssociation(frame.associationID) {
      case .admitted:
        break
      case .unknownOrClosed:
        metrics.datagramsRejected += 1
        emitUDPError(
          .unknownOrClosedAssociation,
          associationID: frame.associationID,
          into: &outbound
        )
        closeRejectedAssociation(frame.associationID, into: &outbound)
        return
      case .limitExceeded:
        metrics.datagramsRejected += 1
        emitUDPError(
          .associationLimit,
          associationID: frame.associationID,
          into: &outbound
        )
        closeRejectedAssociation(frame.associationID, into: &outbound)
        return
      }
    }

    metrics.datagramsAccepted += 1
    events.append(.datagram(associationID: frame.associationID, datagram))
  }

  private func udpErrorCode(
    for failure: RelayDatagramFailure
  ) -> RelayProtocolV1.UDPErrorCode {
    switch failure.code {
    case .messageLengthExceedsProtocolMaximum,
      .messageLengthExceedsLocalMaximum:
      .datagramTooLarge
    case .unknownAddressType:
      .unsupportedAddress
    default:
      .invalidDatagram
    }
  }

  private mutating func closeRejectedAssociation(
    _ associationID: UInt32,
    into outbound: inout [RelayEnvelope]
  ) {
    if associations[associationID] != nil {
      initiateAssociationClose(associationID, into: &outbound)
    } else {
      metrics.associationClosesSent += 1
      emit(
        RelayEnvelope(type: .closeAssociation, associationID: associationID),
        into: &outbound
      )
    }
  }

  private mutating func admitClientOwnedAssociation(
    _ associationID: UInt32
  ) -> AssociationAdmission {
    guard associationID != 0 else { return .unknownOrClosed }
    if let existing = associations[associationID] {
      if existing.isActive { return .admitted }
      if existing.isRetired {
        associations[associationID] = Association()
        return .admitted
      }
      return .unknownOrClosed
    }

    associations = associations.filter { !$0.value.isRetired }
    guard associations.count < maximumAssociations else { return .limitExceeded }
    associations[associationID] = Association()
    return .admitted
  }

  private func validate(
    _ frame: RelayEnvelope,
    direction: RelayEnvelopeDirection
  ) -> RelaySessionFailureCode? {
    guard let transition = RelaySessionTransitions.transition(for: frame.type) else {
      return .unknownMessageType
    }
    guard frame.flags & RelayProtocolV1.envelopeFlagsReservedMask == 0 else {
      return .reservedFlags
    }
    if frame.flags != 0 {
      guard
        frame.flags == RelayProtocolV1.envelopeFlagDNSPriority,
        frame.type == .udpDatagram,
        direction == .clientToRelay,
        negotiatedFeatures.contains(.dnsPriorityHint)
      else { return .invalidFlags }
    }
    switch transition.direction {
    case .both:
      break
    case .clientToRelay:
      guard direction == .clientToRelay else { return .invalidDirection }
    case .relayToClient:
      guard direction == .relayToClient else { return .invalidDirection }
    }
    switch transition.associationID {
    case .zero:
      guard frame.associationID == 0 else { return .invalidAssociationID }
    case .nonzero:
      guard frame.associationID != 0 else { return .invalidAssociationID }
    }
    guard
      frame.payload.count >= transition.minimumPayloadBytes,
      frame.payload.count <= transition.maximumPayloadBytes
    else { return .invalidPayloadLength }
    return nil
  }

  private mutating func inspectPostHandshakePrefix(
    _ bytes: Data
  ) -> (input: Data?, detected: Bool) {
    guard !bytes.isEmpty else { return (bytes, false) }
    guard !postHandshakeMagicPrefix.isEmpty || decoder.isAtFrameBoundary else {
      return (bytes, false)
    }
    if postHandshakeMagicPrefix.isEmpty, bytes.first != RelayProtocolV1.magic.first {
      return (bytes, false)
    }

    var candidate = postHandshakeMagicPrefix
    candidate.append(bytes)
    let comparedCount = min(candidate.count, RelayProtocolV1.magic.count)
    guard
      candidate.prefix(comparedCount).elementsEqual(
        RelayProtocolV1.magic.prefix(comparedCount)
      )
    else {
      postHandshakeMagicPrefix.removeAll(keepingCapacity: false)
      return (candidate, false)
    }
    guard candidate.count < RelayProtocolV1.magic.count else {
      postHandshakeMagicPrefix.removeAll(keepingCapacity: false)
      return (nil, true)
    }
    postHandshakeMagicPrefix = candidate
    return (nil, false)
  }

  private mutating func initiateAssociationClose(
    _ associationID: UInt32,
    into outbound: inout [RelayEnvelope]
  ) {
    guard var association = associations[associationID] else { return }
    cleanupAssociationIfNeeded(associationID, association: &association)
    association.isActive = false
    guard !association.localCloseSent else {
      associations[associationID] = association
      return
    }
    association.localCloseSent = true
    associations[associationID] = association
    metrics.associationClosesSent += 1
    emit(
      RelayEnvelope(type: .closeAssociation, associationID: associationID),
      into: &outbound
    )
  }

  private mutating func receiveAssociationClose(
    _ associationID: UInt32,
    into outbound: inout [RelayEnvelope]
  ) {
    guard var association = associations[associationID] else { return }
    cleanupAssociationIfNeeded(associationID, association: &association)
    association.isActive = false
    association.peerCloseReceived = true
    if !association.localCloseSent {
      association.localCloseSent = true
      metrics.associationClosesSent += 1
      emit(
        RelayEnvelope(type: .closeAssociation, associationID: associationID),
        into: &outbound
      )
    }
    associations[associationID] = association
  }

  private mutating func cleanupAssociationIfNeeded(
    _ associationID: UInt32,
    association: inout Association
  ) {
    guard association.isActive, !association.cleanupInvoked else { return }
    association.cleanupInvoked = true
    metrics.associationCleanups += 1
    associationCleanup?(generation, associationID)
  }

  private mutating func initiateSessionClose(into outbound: inout [RelayEnvelope]) {
    if !sessionCloseSent {
      sessionCloseSent = true
      metrics.sessionClosesSent += 1
      emit(RelayEnvelope(type: .closeSession, associationID: 0), into: &outbound)
    }
    terminate(reason: .localClose)
  }

  private mutating func emitUDPError(
    _ code: RelayProtocolV1.UDPErrorCode,
    associationID: UInt32,
    into outbound: inout [RelayEnvelope]
  ) {
    let payload = Data([
      UInt8(truncatingIfNeeded: code.rawValue >> 8),
      UInt8(truncatingIfNeeded: code.rawValue),
    ])
    metrics.udpErrorsSent += 1
    emit(
      RelayEnvelope(type: .udpError, associationID: associationID, payload: payload),
      into: &outbound
    )
  }

  private mutating func emit(
    _ frame: RelayEnvelope,
    into outbound: inout [RelayEnvelope]
  ) {
    metrics.sentFrames += 1
    outbound.append(frame)
  }

  private mutating func terminalEvent(
    generation callbackGeneration: UInt64,
    code: RelaySessionFailureCode,
    reason: RelaySessionTerminationReason
  ) -> RelaySessionStep {
    guard callbackGeneration == generation else { return staleStep() }
    guard state == .active else { return lateStep() }
    return fail(code, phase: .lifecycle, reason: reason)
  }

  private mutating func fail(
    _ code: RelaySessionFailureCode,
    phase: RelaySessionFailurePhase,
    reason: RelaySessionTerminationReason
  ) -> RelaySessionStep {
    let failure = RelaySessionFailure(code: code, phase: phase)
    metrics.sessionFailures += 1
    terminate(reason: reason)
    return RelaySessionStep(state: state, failure: failure)
  }

  private mutating func terminate(reason: RelaySessionTerminationReason) {
    guard state == .active else { return }
    postHandshakeMagicPrefix.removeAll(keepingCapacity: false)
    let identifiers = associations.keys.sorted()
    for associationID in identifiers {
      guard var association = associations[associationID] else { continue }
      cleanupAssociationIfNeeded(associationID, association: &association)
      association.isActive = false
      associations[associationID] = association
    }
    state = .closed
    guard !sessionCleanupInvoked else { return }
    sessionCleanupInvoked = true
    metrics.sessionCleanups += 1
    generationCleanup?(generation, reason)
  }

  private mutating func staleStep() -> RelaySessionStep {
    metrics.staleCallbacks += 1
    return RelaySessionStep(state: state, staleCallbackIgnored: true)
  }

  private mutating func lateStep(count: Bool = true) -> RelaySessionStep {
    if count { metrics.lateCallbacks += 1 }
    return RelaySessionStep(state: state)
  }

  private mutating func recordLateFrame(_ frame: RelayEnvelope) {
    metrics.receivedFrames += 1
    metrics.lateCallbacks += 1
    switch frame.type {
    case .closeAssociation:
      metrics.associationClosesReceived += 1
    case .closeSession:
      metrics.sessionClosesReceived += 1
    default:
      break
    }
  }
}

private func mapEnvelopeFailure(
  _ code: RelayEnvelopeFailureCode
) -> RelaySessionFailureCode {
  switch code {
  case .invalidConfiguration, .malformedState:
    .malformedState
  case .frameLengthBelowMinimum:
    .frameLengthBelowMinimum
  case .frameLengthExceedsMaximum:
    .frameLengthExceedsMaximum
  case .arithmeticOverflow:
    .arithmeticOverflow
  case .unknownMessageType:
    .unknownMessageType
  case .reservedFlags:
    .reservedFlags
  case .invalidFlags:
    .invalidFlags
  case .invalidDirection:
    .invalidDirection
  case .invalidAssociationID:
    .invalidAssociationID
  case .invalidPayloadLength:
    .invalidPayloadLength
  case .metadataRejected:
    .metadataRejected
  case .unexpectedEOF:
    .unexpectedEOF
  case .cancelled:
    .cancelled
  }
}
