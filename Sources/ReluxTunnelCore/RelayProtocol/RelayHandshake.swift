import Foundation

public struct RelayFeatureSet: OptionSet, Equatable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let dnsPriorityHint = RelayFeatureSet(
    rawValue: RelayProtocolV1.featureDNSPriorityHint
  )
}

public struct RelayEffectiveLimits: Equatable, Sendable {
  public let effectiveMaxFrame: UInt32
  public let maxUDPPayload: UInt16
  public let maxAssociations: UInt32
  public let perAssociationQueuedBytes: UInt32
  public let aggregateQueuedBytes: UInt32
  public let controlReservedBytes: UInt32
  public let dnsPriorityWeight: UInt8
  public let idleTimeoutMilliseconds: UInt32

  public init(
    effectiveMaxFrame: UInt32,
    maxUDPPayload: UInt16,
    maxAssociations: UInt32,
    perAssociationQueuedBytes: UInt32,
    aggregateQueuedBytes: UInt32,
    controlReservedBytes: UInt32,
    dnsPriorityWeight: UInt8,
    idleTimeoutMilliseconds: UInt32
  ) {
    self.effectiveMaxFrame = effectiveMaxFrame
    self.maxUDPPayload = maxUDPPayload
    self.maxAssociations = maxAssociations
    self.perAssociationQueuedBytes = perAssociationQueuedBytes
    self.aggregateQueuedBytes = aggregateQueuedBytes
    self.controlReservedBytes = controlReservedBytes
    self.dnsPriorityWeight = dnsPriorityWeight
    self.idleTimeoutMilliseconds = idleTimeoutMilliseconds
  }
}

public enum RelayHandshakeConfigurationField: String, Equatable, Sendable {
  case maximumFrameBytes
  case maximumUDPPayloadBytes
  case maximumAssociations
  case perAssociationQueuedBytes
  case aggregateQueuedBytes
  case controlReservedBytes
  case dnsPriorityWeight
  case idleTimeoutMilliseconds
  case requestedFeatures
  case timeout
  case maximumReadBytes
}

public struct RelayClientHandshakeConfiguration: Equatable, Sendable {
  public let maximumFrameBytes: UInt32
  public let maximumUDPPayloadBytes: UInt16
  public let maximumAssociations: UInt32
  public let perAssociationQueuedBytes: UInt32
  public let aggregateQueuedBytes: UInt32
  public let controlReservedBytes: UInt32
  public let dnsPriorityWeight: UInt8
  public let idleTimeoutMilliseconds: UInt32
  public let requestedFeatures: RelayFeatureSet
  public let timeout: Duration
  public let maximumReadBytes: Int

  public init(
    maximumFrameBytes: UInt32 = RelayProtocolV1.maxFrameClientDefault,
    maximumUDPPayloadBytes: UInt16 = RelayProtocolV1.maxUDPPayloadClientDefault,
    maximumAssociations: UInt32 = RelayProtocolV1.maxAssociationsClientDefault,
    perAssociationQueuedBytes: UInt32 =
      RelayProtocolV1.perAssociationQueuedBytesClientDefault,
    aggregateQueuedBytes: UInt32 = RelayProtocolV1.aggregateQueuedBytesClientDefault,
    controlReservedBytes: UInt32 = RelayProtocolV1.controlReservedBytesClientDefault,
    dnsPriorityWeight: UInt8 = RelayProtocolV1.dnsPriorityWeightClientDefault,
    idleTimeoutMilliseconds: UInt32 = RelayProtocolV1.idleTimeoutClientDefault,
    requestedFeatures: RelayFeatureSet = [.dnsPriorityHint],
    timeout: Duration,
    maximumReadBytes: Int = RelayProtocolV1.serverHelloWidth
      + RelayProtocolV1.framePrefixWidth + RelayProtocolV1.envelopeHeaderWidth
  ) throws {
    self.maximumFrameBytes = maximumFrameBytes
    self.maximumUDPPayloadBytes = maximumUDPPayloadBytes
    self.maximumAssociations = maximumAssociations
    self.perAssociationQueuedBytes = perAssociationQueuedBytes
    self.aggregateQueuedBytes = aggregateQueuedBytes
    self.controlReservedBytes = controlReservedBytes
    self.dnsPriorityWeight = dnsPriorityWeight
    self.idleTimeoutMilliseconds = idleTimeoutMilliseconds
    self.requestedFeatures = requestedFeatures
    self.timeout = timeout
    self.maximumReadBytes = maximumReadBytes
    try validate()
  }

  private func validate() throws {
    try require(
      maximumFrameBytes,
      in: RelayProtocolV1.maxFrameFloor...RelayProtocolV1.maxFrameClientHardCeiling,
      field: .maximumFrameBytes
    )
    try require(
      maximumUDPPayloadBytes,
      in: RelayProtocolV1
        .maxUDPPayloadFloor...RelayProtocolV1
        .maxUDPPayloadClientHardCeiling,
      field: .maximumUDPPayloadBytes
    )
    try require(
      maximumAssociations,
      in: RelayProtocolV1
        .maxAssociationsFloor...RelayProtocolV1
        .maxAssociationsClientHardCeiling,
      field: .maximumAssociations
    )
    try require(
      perAssociationQueuedBytes,
      in: RelayProtocolV1
        .perAssociationQueuedBytesFloor...RelayProtocolV1
        .perAssociationQueuedBytesClientHardCeiling,
      field: .perAssociationQueuedBytes
    )
    try require(
      aggregateQueuedBytes,
      in: RelayProtocolV1
        .aggregateQueuedBytesFloor...RelayProtocolV1
        .aggregateQueuedBytesClientHardCeiling,
      field: .aggregateQueuedBytes
    )
    try require(
      controlReservedBytes,
      in: RelayProtocolV1
        .controlReservedBytesFloor...RelayProtocolV1
        .controlReservedBytesClientHardCeiling,
      field: .controlReservedBytes
    )
    guard controlReservedBytes <= aggregateQueuedBytes else {
      throw RelayHandshakeFailure.invalidConfiguration(.controlReservedBytes)
    }
    try require(
      dnsPriorityWeight,
      in: RelayProtocolV1
        .dnsPriorityWeightFloor...RelayProtocolV1
        .dnsPriorityWeightClientHardCeiling,
      field: .dnsPriorityWeight
    )
    try require(
      idleTimeoutMilliseconds,
      in: RelayProtocolV1
        .idleTimeoutFloor...RelayProtocolV1
        .idleTimeoutClientHardCeiling,
      field: .idleTimeoutMilliseconds
    )
    guard requestedFeatures.rawValue & RelayProtocolV1.featuresReservedMask == 0 else {
      throw RelayHandshakeFailure.invalidConfiguration(.requestedFeatures)
    }
    guard timeout > .zero else {
      throw RelayHandshakeFailure.invalidConfiguration(.timeout)
    }
    guard maximumReadBytes > 0 else {
      throw RelayHandshakeFailure.invalidConfiguration(.maximumReadBytes)
    }
  }

  private func require<T: Comparable>(
    _ value: T,
    in range: ClosedRange<T>,
    field: RelayHandshakeConfigurationField
  ) throws {
    guard range.contains(value) else {
      throw RelayHandshakeFailure.invalidConfiguration(field)
    }
  }

  fileprivate var clientFlags: UInt16 {
    var flags: UInt16 = 0
    if requestedFeatures.contains(.dnsPriorityHint) {
      flags |= RelayProtocolV1.helloFlagDNSPriorityHint
    }
    return flags
  }

  fileprivate func effectiveLimits(maxFrame: UInt32) -> RelayEffectiveLimits {
    RelayEffectiveLimits(
      effectiveMaxFrame: maxFrame,
      maxUDPPayload: min(
        maximumUDPPayloadBytes,
        RelayProtocolV1.maxUDPPayloadClientDefault
      ),
      maxAssociations: min(
        maximumAssociations,
        RelayProtocolV1.maxAssociationsClientDefault
      ),
      perAssociationQueuedBytes: min(
        perAssociationQueuedBytes,
        RelayProtocolV1.perAssociationQueuedBytesClientDefault
      ),
      aggregateQueuedBytes: min(
        aggregateQueuedBytes,
        RelayProtocolV1.aggregateQueuedBytesClientDefault
      ),
      controlReservedBytes: min(
        controlReservedBytes,
        RelayProtocolV1.controlReservedBytesClientDefault
      ),
      dnsPriorityWeight: min(
        dnsPriorityWeight,
        RelayProtocolV1.dnsPriorityWeightClientDefault
      ),
      idleTimeoutMilliseconds: min(
        idleTimeoutMilliseconds,
        RelayProtocolV1.idleTimeoutClientDefault
      )
    )
  }
}

public enum RelayHandshakeFailureCode: String, CaseIterable, Equatable, Sendable {
  case invalidConfiguration
  case unknownMagic
  case unsupportedVersion
  case invalidClientHello
  case resourcePolicyRejected
  case relayUnavailable
  case relayRejected
  case reservedClientFlags
  case impossibleFeatureSelection
  case unreasonableMaxFrame
  case truncatedHello
  case extendedHello
  case duplicateHello
  case trailingHelloBytes
  case timedOut
  case unexpectedEOF
  case cancelled
  case transportFailure
}

public enum RelayHandshakePhase: String, Equatable, Sendable {
  case configuration
  case clientHelloWrite
  case clientHelloValidation
  case serverHelloRead
  case serverHelloValidation
  case terminal
}

public enum RelayHandshakeScope: String, Equatable, Sendable {
  case session
}

public enum RelayHandshakeDisposition: String, Equatable, Sendable {
  case closeSession
}

public struct RelayHandshakeFailure: Error, Equatable, Sendable, CustomStringConvertible {
  public let code: RelayHandshakeFailureCode
  public let phase: RelayHandshakePhase
  public let scope: RelayHandshakeScope
  public let disposition: RelayHandshakeDisposition
  public let configurationField: RelayHandshakeConfigurationField?

  public init(
    code: RelayHandshakeFailureCode,
    phase: RelayHandshakePhase,
    configurationField: RelayHandshakeConfigurationField? = nil
  ) {
    self.code = code
    self.phase = phase
    self.scope = .session
    self.disposition = .closeSession
    self.configurationField = configurationField
  }

  public static func invalidConfiguration(
    _ field: RelayHandshakeConfigurationField
  ) -> RelayHandshakeFailure {
    RelayHandshakeFailure(
      code: .invalidConfiguration,
      phase: .configuration,
      configurationField: field
    )
  }

  public var description: String {
    if let configurationField {
      return "relayHandshake code=\(code.rawValue) phase=\(phase.rawValue) "
        + "field=\(configurationField.rawValue) scope=\(scope.rawValue) "
        + "disposition=\(disposition.rawValue)"
    }
    return "relayHandshake code=\(code.rawValue) phase=\(phase.rawValue) "
      + "scope=\(scope.rawValue) disposition=\(disposition.rawValue)"
  }
}

public struct RelayHandshakeSummary: Equatable, Sendable {
  public let protocolVersion: UInt16
  public let negotiatedFeatures: RelayFeatureSet
  public let effectiveLimits: RelayEffectiveLimits

  public init(
    protocolVersion: UInt16,
    negotiatedFeatures: RelayFeatureSet,
    effectiveLimits: RelayEffectiveLimits
  ) {
    self.protocolVersion = protocolVersion
    self.negotiatedFeatures = negotiatedFeatures
    self.effectiveLimits = effectiveLimits
  }
}

public struct RelayClientHandshakeResult: Equatable, Sendable {
  public let summary: RelayHandshakeSummary
  /// Bytes read after the exact server hello. After the duplicate-magic guard,
  /// they belong to the envelope decoder.
  public let remainingBytes: Data

  public init(summary: RelayHandshakeSummary, remainingBytes: Data) {
    self.summary = summary
    self.remainingBytes = remainingBytes
  }
}

public enum RelayClientHandshakeProgress: Equatable, Sendable {
  case needsMoreBytes(Int)
  case completed(RelayClientHandshakeResult)
  case failed(RelayHandshakeFailure)
  case staleCallbackIgnored
}

public enum RelayHandshakeWire {
  public static func encodeClientHello(
    configuration: RelayClientHandshakeConfiguration
  ) -> Data {
    var bytes = Data()
    bytes.reserveCapacity(RelayProtocolV1.clientHelloWidth)
    bytes.append(contentsOf: RelayProtocolV1.magic)
    appendBigEndian(RelayProtocolV1.wireVersion, to: &bytes)
    appendBigEndian(configuration.clientFlags, to: &bytes)
    appendBigEndian(configuration.maximumFrameBytes, to: &bytes)
    precondition(bytes.count == RelayProtocolV1.clientHelloWidth)
    return bytes
  }

  public static func encodeServerHello(
    version: UInt16 = RelayProtocolV1.wireVersion,
    status: RelayProtocolV1.HelloStatus,
    features: RelayFeatureSet,
    maximumFrameBytes: UInt32
  ) -> Data {
    var bytes = Data()
    bytes.reserveCapacity(RelayProtocolV1.serverHelloWidth)
    bytes.append(contentsOf: RelayProtocolV1.magic)
    appendBigEndian(version, to: &bytes)
    appendBigEndian(status.rawValue, to: &bytes)
    appendBigEndian(features.rawValue, to: &bytes)
    appendBigEndian(maximumFrameBytes, to: &bytes)
    precondition(bytes.count == RelayProtocolV1.serverHelloWidth)
    return bytes
  }

  public static func decodeServerHelloExact(
    _ bytes: Data,
    configuration: RelayClientHandshakeConfiguration
  ) throws -> RelayHandshakeSummary {
    guard bytes.count >= RelayProtocolV1.serverHelloWidth else {
      throw RelayHandshakeFailure(code: .truncatedHello, phase: .serverHelloValidation)
    }
    guard bytes.count == RelayProtocolV1.serverHelloWidth else {
      throw RelayHandshakeFailure(code: .extendedHello, phase: .serverHelloValidation)
    }

    var cursor = RelayHandshakeByteCursor(bytes: bytes)
    let magic = try cursor.readBytes(count: RelayProtocolV1.magic.count)
    guard magic.elementsEqual(RelayProtocolV1.magic) else {
      throw RelayHandshakeFailure(code: .unknownMagic, phase: .serverHelloValidation)
    }
    let version = try cursor.readUInt16()
    guard version == RelayProtocolV1.wireVersion else {
      throw RelayHandshakeFailure(code: .unsupportedVersion, phase: .serverHelloValidation)
    }
    let rawStatus = try cursor.readUInt16()
    guard rawStatus == RelayProtocolV1.HelloStatus.accepted.rawValue else {
      throw statusFailure(rawStatus)
    }
    let rawFeatures = try cursor.readUInt32()
    guard rawFeatures & RelayProtocolV1.featuresReservedMask == 0 else {
      throw RelayHandshakeFailure(
        code: .impossibleFeatureSelection,
        phase: .serverHelloValidation
      )
    }
    let features = RelayFeatureSet(rawValue: rawFeatures)
    guard configuration.requestedFeatures.isSuperset(of: features) else {
      throw RelayHandshakeFailure(
        code: .impossibleFeatureSelection,
        phase: .serverHelloValidation
      )
    }
    let maximumFrameBytes = try cursor.readUInt32()
    guard
      (RelayProtocolV1.maxFrameFloor...RelayProtocolV1.maxFrameClientHardCeiling)
        .contains(maximumFrameBytes),
      maximumFrameBytes <= configuration.maximumFrameBytes
    else {
      throw RelayHandshakeFailure(code: .unreasonableMaxFrame, phase: .serverHelloValidation)
    }
    return RelayHandshakeSummary(
      protocolVersion: version,
      negotiatedFeatures: features,
      effectiveLimits: configuration.effectiveLimits(maxFrame: maximumFrameBytes)
    )
  }

  private static func statusFailure(_ rawStatus: UInt16) -> RelayHandshakeFailure {
    let code: RelayHandshakeFailureCode =
      switch RelayProtocolV1.HelloStatus(
        rawValue: rawStatus
      ) {
      case .unsupportedVersion:
        .unsupportedVersion
      case .invalidClientHello:
        .invalidClientHello
      case .resourcePolicyRejected:
        .resourcePolicyRejected
      case .relayUnavailable:
        .relayUnavailable
      case .accepted, .none:
        .relayRejected
      }
    return RelayHandshakeFailure(code: code, phase: .serverHelloValidation)
  }

  private static func appendBigEndian(_ value: UInt16, to bytes: inout Data) {
    bytes.append(UInt8(truncatingIfNeeded: value >> 8))
    bytes.append(UInt8(truncatingIfNeeded: value))
  }

  private static func appendBigEndian(_ value: UInt32, to bytes: inout Data) {
    bytes.append(UInt8(truncatingIfNeeded: value >> 24))
    bytes.append(UInt8(truncatingIfNeeded: value >> 16))
    bytes.append(UInt8(truncatingIfNeeded: value >> 8))
    bytes.append(UInt8(truncatingIfNeeded: value))
  }
}

public struct RelayClientHandshakeStateMachine: Sendable {
  private enum State: Sendable {
    case awaitingServerHello
    case completed(RelayClientHandshakeResult)
    case failed(RelayHandshakeFailure)
  }

  public let generation: UInt64
  public let configuration: RelayClientHandshakeConfiguration
  private var state: State = .awaitingServerHello
  private var helloBytes = Data()

  public init(generation: UInt64, configuration: RelayClientHandshakeConfiguration) {
    self.generation = generation
    self.configuration = configuration
    helloBytes.reserveCapacity(RelayProtocolV1.serverHelloWidth)
  }

  public var clientHello: Data {
    RelayHandshakeWire.encodeClientHello(configuration: configuration)
  }

  public mutating func receive(
    _ bytes: Data,
    generation callbackGeneration: UInt64
  ) -> RelayClientHandshakeProgress {
    guard callbackGeneration == generation else {
      return .staleCallbackIgnored
    }
    switch state {
    case .failed(let failure):
      return .failed(failure)
    case .completed(let result):
      guard !bytes.isEmpty else { return .completed(result) }
      return fail(
        beginsWithHelloMagic(bytes)
          ? .duplicateHello : .trailingHelloBytes,
        phase: .terminal
      )
    case .awaitingServerHello:
      break
    }

    let needed = RelayProtocolV1.serverHelloWidth - helloBytes.count
    let consumed = min(needed, bytes.count)
    helloBytes.append(bytes.prefix(consumed))
    guard helloBytes.count == RelayProtocolV1.serverHelloWidth else {
      return .needsMoreBytes(RelayProtocolV1.serverHelloWidth - helloBytes.count)
    }

    do {
      let summary = try RelayHandshakeWire.decodeServerHelloExact(
        helloBytes,
        configuration: configuration
      )
      let remainingBytes = Data(bytes.dropFirst(consumed))
      guard !beginsWithHelloMagic(remainingBytes) else {
        return fail(.duplicateHello, phase: .terminal)
      }
      let result = RelayClientHandshakeResult(
        summary: summary,
        remainingBytes: remainingBytes
      )
      state = .completed(result)
      helloBytes.removeAll(keepingCapacity: false)
      return .completed(result)
    } catch let failure as RelayHandshakeFailure {
      state = .failed(failure)
      helloBytes.removeAll(keepingCapacity: false)
      return .failed(failure)
    } catch {
      return fail(.transportFailure, phase: .serverHelloValidation)
    }
  }

  public mutating func endOfStream(
    generation callbackGeneration: UInt64
  ) -> RelayClientHandshakeProgress {
    terminalEvent(
      generation: callbackGeneration,
      code: .unexpectedEOF,
      phase: .serverHelloRead
    )
  }

  public mutating func timeout(
    generation callbackGeneration: UInt64
  ) -> RelayClientHandshakeProgress {
    terminalEvent(
      generation: callbackGeneration,
      code: .timedOut,
      phase: .serverHelloRead
    )
  }

  public mutating func cancel(
    generation callbackGeneration: UInt64
  ) -> RelayClientHandshakeProgress {
    terminalEvent(
      generation: callbackGeneration,
      code: .cancelled,
      phase: .terminal
    )
  }

  private mutating func terminalEvent(
    generation callbackGeneration: UInt64,
    code: RelayHandshakeFailureCode,
    phase: RelayHandshakePhase
  ) -> RelayClientHandshakeProgress {
    guard callbackGeneration == generation else { return .staleCallbackIgnored }
    switch state {
    case .awaitingServerHello:
      return fail(code, phase: phase)
    case .completed(let result):
      return .completed(result)
    case .failed(let failure):
      return .failed(failure)
    }
  }

  private mutating func fail(
    _ code: RelayHandshakeFailureCode,
    phase: RelayHandshakePhase
  ) -> RelayClientHandshakeProgress {
    let failure = RelayHandshakeFailure(code: code, phase: phase)
    state = .failed(failure)
    helloBytes.removeAll(keepingCapacity: false)
    return .failed(failure)
  }

  private func beginsWithHelloMagic(_ bytes: Data) -> Bool {
    guard !bytes.isEmpty else { return false }
    let prefixCount = min(bytes.count, RelayProtocolV1.magic.count)
    return bytes.prefix(prefixCount).elementsEqual(
      RelayProtocolV1.magic.prefix(prefixCount)
    )
  }
}

public struct RelayClientHandshake: Sendable {
  private enum DeadlineElapsed: Error {
    case elapsed
  }

  public let configuration: RelayClientHandshakeConfiguration
  private let clock: any TunnelClock
  private let cancellation: any TunnelCancellationChecking

  public init(
    configuration: RelayClientHandshakeConfiguration,
    clock: any TunnelClock,
    cancellation: any TunnelCancellationChecking
  ) {
    self.configuration = configuration
    self.clock = clock
    self.cancellation = cancellation
  }

  public func perform(
    on channel: any SSHByteChannel,
    generation: UInt64
  ) async throws -> RelayClientHandshakeResult {
    do {
      return try await withTaskCancellationHandler {
        try await withThrowingTaskGroup(of: RelayClientHandshakeResult.self) { group in
          group.addTask {
            try await exchange(on: channel, generation: generation)
          }
          group.addTask {
            try await clock.sleep(for: configuration.timeout)
            throw DeadlineElapsed.elapsed
          }
          do {
            guard let first = try await group.next() else {
              throw RelayHandshakeFailure(
                code: .transportFailure,
                phase: .serverHelloRead
              )
            }
            group.cancelAll()
            return first
          } catch {
            group.cancelAll()
            await channel.cancel()
            throw error
          }
        }
      } onCancel: {
        Task { await channel.cancel() }
      }
    } catch {
      await channel.reset()
      await channel.close()
      if error is DeadlineElapsed {
        throw RelayHandshakeFailure(code: .timedOut, phase: .serverHelloRead)
      }
      if error is CancellationError || cancellation.isCancelled {
        throw RelayHandshakeFailure(code: .cancelled, phase: .terminal)
      }
      if let failure = error as? RelayHandshakeFailure {
        throw failure
      }
      throw RelayHandshakeFailure(code: .transportFailure, phase: .serverHelloRead)
    }
  }

  private func exchange(
    on channel: any SSHByteChannel,
    generation: UInt64
  ) async throws -> RelayClientHandshakeResult {
    try cancellation.checkCancellation()
    var remainingHello = RelayHandshakeWire.encodeClientHello(configuration: configuration)
    while !remainingHello.isEmpty {
      try cancellation.checkCancellation()
      let accepted: Int
      do {
        accepted = try await channel.writeSome(remainingHello)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        throw RelayHandshakeFailure(code: .transportFailure, phase: .clientHelloWrite)
      }
      guard accepted > 0, accepted <= remainingHello.count else {
        throw RelayHandshakeFailure(code: .transportFailure, phase: .clientHelloWrite)
      }
      remainingHello.removeFirst(accepted)
    }

    var machine = RelayClientHandshakeStateMachine(
      generation: generation,
      configuration: configuration
    )
    while true {
      try cancellation.checkCancellation()
      let bytes: Data?
      do {
        bytes = try await channel.read(maximumBytes: configuration.maximumReadBytes)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        throw RelayHandshakeFailure(code: .transportFailure, phase: .serverHelloRead)
      }
      guard let bytes else {
        if case .failed(let failure) = machine.endOfStream(generation: generation) {
          throw failure
        }
        throw RelayHandshakeFailure(code: .unexpectedEOF, phase: .serverHelloRead)
      }
      switch machine.receive(bytes, generation: generation) {
      case .needsMoreBytes:
        continue
      case .completed(let result):
        return result
      case .failed(let failure):
        throw failure
      case .staleCallbackIgnored:
        continue
      }
    }
  }
}

private struct RelayHandshakeByteCursor {
  let bytes: Data
  var offset = 0

  mutating func readBytes(count: Int) throws -> Data {
    guard count >= 0, offset <= bytes.count, count <= bytes.count - offset else {
      throw RelayHandshakeFailure(code: .truncatedHello, phase: .serverHelloValidation)
    }
    let result = Data(bytes[offset..<(offset + count)])
    offset += count
    return result
  }

  mutating func readUInt16() throws -> UInt16 {
    let value = try readBytes(count: MemoryLayout<UInt16>.size)
    return value.reduce(0) { ($0 << 8) | UInt16($1) }
  }

  mutating func readUInt32() throws -> UInt32 {
    let value = try readBytes(count: MemoryLayout<UInt32>.size)
    return value.reduce(0) { ($0 << 8) | UInt32($1) }
  }
}
