import Foundation
import ReluxTunnelCore
import Testing

@Suite("RelayProtocol v1 canonical conformance vectors")
struct RelayProtocolVectorTests {
  @Test("strict loader validates schema, provenance, coverage, and limit references")
  func corpusSchemaAndCoverage() throws {
    let corpus = try RelayVectorCorpusLoader.load()

    #expect(corpus.formatVersion == 1)
    #expect(corpus.protocolVersion == RelayProtocolV1.wireVersion)
    #expect(corpus.provenance.schemaSHA256 == RelayProtocolV1.schemaSHA256)
    #expect(!corpus.vectors.isEmpty)
  }

  @Test("strict loader reports the exact vector identifier without payload bytes")
  func loaderFailurePrivacy() throws {
    let original = try Data(contentsOf: RelayVectorCorpusLoader.corpusURL)
    var root = try #require(
      JSONSerialization.jsonObject(with: original) as? [String: Any]
    )
    var vectors = try #require(root["vectors"] as? [[String: Any]])
    let identifier = try #require(vectors.first?["id"] as? String)
    let inputHex = try #require(vectors.first?["inputHex"] as? String)
    vectors[0]["unknownSchemaField"] = true
    root["vectors"] = vectors
    let mutated = try JSONSerialization.data(withJSONObject: root)

    do {
      _ = try RelayVectorCorpusLoader.decode(mutated)
      Issue.record("mutated corpus unexpectedly loaded")
    } catch let failure as RelayVectorHarnessFailure {
      #expect(failure.vectorID == identifier)
      #expect(failure.description.contains(identifier))
      #expect(!failure.description.contains(inputHex))
    }
  }

  @Test("Swift codecs consume every canonical vector")
  func consumeCanonicalVectors() throws {
    let corpus = try RelayVectorCorpusLoader.load()

    for vector in corpus.vectors {
      do {
        try consume(vector)
      } catch let failure as RelayVectorHarnessFailure {
        Issue.record(failure)
      } catch {
        Issue.record(
          RelayVectorHarnessFailure(
            vectorID: vector.id,
            reason: "unexpected error type \(String(describing: type(of: error)))"
          )
        )
      }
    }
  }

  private func consume(_ vector: RelayProtocolVector) throws {
    let input = try decodeHex(vector.inputHex, vectorID: vector.id)
    switch vector.kind {
    case "clientHello":
      try consumeClientHello(vector, input: input)
    case "serverHello":
      try consumeServerHello(vector, input: input)
    case "envelope", "stream", "envelopeDatagram":
      try consumeEnvelopeInput(vector, input: input)
    case "datagram":
      try consumeDatagram(vector, input: input)
    default:
      throw RelayVectorHarnessFailure(vectorID: vector.id, reason: "unknown kind")
    }
  }

  private func consumeClientHello(_ vector: RelayProtocolVector, input: Data) throws {
    guard vector.expected.outcome == "success" else {
      // Swift owns the client side and does not expose a client-hello decoder.
      // The strict loader plus independent Python oracle audits hostile client
      // hellos; the Go consumer executes them through its production decoder.
      return
    }
    let maximumFrame = try require(vector.expected.maxFrame, vector, "missing maxFrame")
    let configuration = try RelayClientHandshakeConfiguration(
      maximumFrameBytes: maximumFrame,
      requestedFeatures: featureSet(vector.features),
      timeout: .seconds(1)
    )
    let encoded = RelayHandshakeWire.encodeClientHello(configuration: configuration)
    try require(encoded == input, vector, "client hello encoder mismatch")
  }

  private func consumeServerHello(_ vector: RelayProtocolVector, input: Data) throws {
    let configuration = try RelayClientHandshakeConfiguration(
      maximumFrameBytes: RelayProtocolV1.maxFrameClientHardCeiling,
      requestedFeatures: featureSet(vector.features),
      timeout: .seconds(1)
    )
    do {
      let result = try RelayHandshakeWire.decodeServerHelloExact(
        input,
        configuration: configuration
      )
      try require(vector.expected.outcome == "success", vector, "expected failure")
      try require(
        result.protocolVersion == vector.expected.version,
        vector,
        "server hello version mismatch"
      )
      try require(
        result.negotiatedFeatures.rawValue == vector.expected.features,
        vector,
        "server hello features mismatch"
      )
      try require(
        result.effectiveLimits.effectiveMaxFrame == vector.expected.maxFrame,
        vector,
        "server hello maxFrame mismatch"
      )
      let status = RelayProtocolV1.HelloStatus(
        rawValue: try require(vector.expected.status, vector, "missing status")
      )
      let encoded = RelayHandshakeWire.encodeServerHello(
        status: try require(status, vector, "unknown success status"),
        features: result.negotiatedFeatures,
        maximumFrameBytes: result.effectiveLimits.effectiveMaxFrame
      )
      try require(encoded == input, vector, "server hello encoder mismatch")
    } catch let failure as RelayHandshakeFailure {
      try expectHandshakeFailure(failure, vector: vector)
    }
  }

  private func consumeEnvelopeInput(_ vector: RelayProtocolVector, input: Data) throws {
    let maximumFrame = try resolvedLimit(vector.limitRefs[0], vectorID: vector.id)
    guard maximumFrame <= UInt64(UInt32.max) else {
      throw RelayVectorHarnessFailure(vectorID: vector.id, reason: "maxFrame overflow")
    }
    let direction = try envelopeDirection(vector.direction, vectorID: vector.id)
    var decoder = try RelayEnvelopeDecoder(
      maximumFrame: UInt32(maximumFrame),
      direction: direction,
      negotiatedFeatures: featureSet(vector.features)
    )
    var decoded: [RelayEnvelope] = []
    do {
      for chunk in try chunks(of: input, plan: vector.chunks, vectorID: vector.id) {
        decoded.append(contentsOf: try decoder.consume(chunk))
      }
      try decoder.endOfStream()
    } catch let failure as RelayEnvelopeFailure {
      try expectEnvelopeFailure(failure, vector: vector)
      return
    }
    var encoder = try RelayEnvelopeEncoder(
      maximumFrame: UInt32(maximumFrame),
      direction: direction,
      negotiatedFeatures: featureSet(vector.features)
    )
    if vector.kind == "envelopeDatagram", vector.expected.outcome == "failure" {
      try require(decoded.count == 1, vector, "frame count mismatch")
      let frame = try require(decoded.first, vector, "missing datagram frame")
      try require(try encoder.encode(frame).bytes == input, vector, "envelope encoder mismatch")
      try consumeDatagram(vector, input: frame.payload)
      return
    }

    try require(vector.expected.outcome == "success", vector, "expected failure")
    let expectedFrames = try require(vector.expected.frames, vector, "missing frames")
    try require(decoded.count == expectedFrames.count, vector, "frame count mismatch")

    var reencoded = Data()
    for (frame, expected) in zip(decoded, expectedFrames) {
      try expectFrame(frame, expected: expected, vector: vector)
      reencoded.append(try encoder.encode(frame).bytes)
    }
    try require(reencoded == input, vector, "envelope encoder mismatch")

    if vector.kind == "envelopeDatagram" {
      let payload = try require(decoded.first?.payload, vector, "missing datagram payload")
      try consumeDatagram(vector, input: payload)
    }
  }

  private func consumeDatagram(_ vector: RelayProtocolVector, input: Data) throws {
    let reference = vector.kind == "envelopeDatagram" ? vector.limitRefs[1] : vector.limitRefs[0]
    let maximumPayload = try resolvedLimit(reference, vectorID: vector.id)
    guard maximumPayload <= UInt64(UInt16.max) else {
      throw RelayVectorHarnessFailure(vectorID: vector.id, reason: "payload limit overflow")
    }
    var codec = try RelayDatagramCodec(maximumPayloadLength: UInt16(maximumPayload))
    do {
      let datagram = try codec.decode(input)
      try require(vector.expected.outcome == "success", vector, "expected failure")
      let expectedType = try require(vector.expected.addressType, vector, "missing address type")
      let address = try decodeHex(
        try require(vector.expected.addressHex, vector, "missing address"),
        vectorID: vector.id
      )
      let expectedAddress: RelayDatagramAddress =
        switch expectedType {
        case "IPV4": .ipv4(address)
        case "IPV6": .ipv6(address)
        case "DOMAIN": .domain(address)
        default:
          throw RelayVectorHarnessFailure(vectorID: vector.id, reason: "unknown address type")
        }
      let expected = RelayDatagram(
        endpoint: RelayDatagramEndpoint(
          address: expectedAddress,
          port: try require(vector.expected.port, vector, "missing port")
        ),
        data: try decodeHex(
          try require(vector.expected.dataHex, vector, "missing data"),
          vectorID: vector.id
        )
      )
      try require(datagram == expected, vector, "decoded datagram mismatch")
      try require(try codec.encode(datagram) == input, vector, "datagram encoder mismatch")
    } catch let failure as RelayDatagramFailure {
      try expectDatagramFailure(failure, vector: vector)
    }
  }

  private func expectFrame(
    _ frame: RelayEnvelope,
    expected: RelayExpectedFrame,
    vector: RelayProtocolVector
  ) throws {
    let metadata = RelayProtocolV1.messageMetadata.first { $0.name == expected.messageType }
    try require(metadata != nil, vector, "unknown expected message type")
    try require(frame.type == metadata?.type, vector, "message type mismatch")
    try require(frame.flags == expected.flags, vector, "flags mismatch")
    try require(frame.associationID == expected.associationID, vector, "association mismatch")
    try require(
      frame.payload == decodeHex(expected.payloadHex, vectorID: vector.id),
      vector,
      "payload mismatch"
    )
  }

  private func expectHandshakeFailure(
    _ failure: RelayHandshakeFailure,
    vector: RelayProtocolVector
  ) throws {
    try require(vector.expected.outcome == "failure", vector, "unexpected handshake failure")
    try require(failure.code.rawValue == vector.expected.code, vector, "handshake code mismatch")
    try require(failure.phase.rawValue == vector.expected.phase, vector, "handshake phase mismatch")
    try require(failure.scope.rawValue == vector.expected.scope, vector, "handshake scope mismatch")
    try require(
      failure.disposition.rawValue == vector.expected.disposition,
      vector,
      "handshake disposition mismatch"
    )
  }

  private func expectEnvelopeFailure(
    _ failure: RelayEnvelopeFailure,
    vector: RelayProtocolVector
  ) throws {
    try require(vector.expected.outcome == "failure", vector, "unexpected envelope failure")
    try require(failure.code.rawValue == vector.expected.code, vector, "envelope code mismatch")
    try require(failure.phase.rawValue == vector.expected.phase, vector, "envelope phase mismatch")
    try require(failure.scope == vector.expected.scope, vector, "envelope scope mismatch")
    try require(
      failure.disposition == vector.expected.disposition, vector, "envelope disposition mismatch")
  }

  private func expectDatagramFailure(
    _ failure: RelayDatagramFailure,
    vector: RelayProtocolVector
  ) throws {
    try require(vector.expected.outcome == "failure", vector, "unexpected datagram failure")
    try require(failure.code.rawValue == vector.expected.code, vector, "datagram code mismatch")
    try require(failure.phase.rawValue == vector.expected.phase, vector, "datagram phase mismatch")
    try require(failure.scope.rawValue == vector.expected.scope, vector, "datagram scope mismatch")
    try require(
      failure.disposition.rawValue == vector.expected.disposition,
      vector,
      "datagram disposition mismatch"
    )
  }
}

private struct RelayVectorCorpus: Decodable {
  let formatVersion: Int
  let protocolVersion: UInt16
  let provenance: RelayVectorProvenance
  let vectors: [RelayProtocolVector]
}

private struct RelayVectorProvenance: Decodable {
  let generator: String
  let generatorFormatVersion: Int
  let generatorSHA256: String
  let privacy: String
  let regenerateCommand: String
  let reviewPolicy: RelayVectorReviewPolicy
  let schemaSHA256: String
  let sources: [String]
  let task: String
}

private struct RelayVectorReviewPolicy: Decodable {
  let compatibility: String
  let identifiers: String
  let requiredConsumers: [String]
}

private struct RelayProtocolVector: Decodable {
  let chunks: [Int]
  let covers: [String]
  let direction: String
  let expected: RelayVectorExpected
  let features: [String]
  let id: String
  let inputHex: String
  let kind: String
  let limitRefs: [String]
  let protocolVersion: UInt16
}

private struct RelayVectorExpected: Decodable {
  let addressHex: String?
  let addressType: String?
  let code: String?
  let dataHex: String?
  let disposition: String?
  let features: UInt32?
  let flags: UInt16?
  let frames: [RelayExpectedFrame]?
  let maxFrame: UInt32?
  let outcome: String
  let phase: String?
  let port: UInt16?
  let scope: String?
  let status: UInt16?
  let version: UInt16?
}

private struct RelayExpectedFrame: Decodable {
  let associationID: UInt32
  let flags: UInt8
  let messageType: String
  let payloadHex: String
}

private struct RelayVectorHarnessFailure: Error, CustomStringConvertible {
  let vectorID: String
  let reason: String

  var description: String {
    "relay vector \(vectorID): \(reason)"
  }
}

private enum RelayVectorCorpusLoader {
  static let corpusURL: URL = {
    let testFile = URL(fileURLWithPath: #filePath)
    let root = testFile.deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    return root.appendingPathComponent("Protocol/Relay/Vectors/v1/corpus.json")
  }()

  static func load() throws -> RelayVectorCorpus {
    try decode(Data(contentsOf: corpusURL))
  }

  static func decode(_ data: Data) throws -> RelayVectorCorpus {
    let root = try requireObject(
      JSONSerialization.jsonObject(with: data),
      vectorID: "<corpus>"
    )
    try exactKeys(
      root,
      ["formatVersion", "protocolVersion", "provenance", "vectors"],
      vectorID: "<corpus>"
    )
    let provenance = try requireObject(root["provenance"], vectorID: "<corpus>")
    try exactKeys(
      provenance,
      [
        "generator", "generatorFormatVersion", "generatorSHA256", "privacy",
        "regenerateCommand", "reviewPolicy", "schemaSHA256", "sources", "task",
      ],
      vectorID: "<corpus>"
    )
    let review = try requireObject(provenance["reviewPolicy"], vectorID: "<corpus>")
    try exactKeys(
      review,
      ["compatibility", "identifiers", "requiredConsumers"],
      vectorID: "<corpus>"
    )
    guard let rawVectors = root["vectors"] as? [Any] else {
      throw RelayVectorHarnessFailure(vectorID: "<corpus>", reason: "vectors is not an array")
    }
    for rawVector in rawVectors {
      let object = try requireObject(rawVector, vectorID: "<unknown>")
      let identifier = object["id"] as? String ?? "<unknown>"
      try exactKeys(
        object,
        [
          "chunks", "covers", "direction", "expected", "features", "id",
          "inputHex", "kind", "limitRefs", "protocolVersion",
        ],
        vectorID: identifier
      )
      let expected = try requireObject(object["expected"], vectorID: identifier)
      try validateExpected(expected, kind: object["kind"] as? String, vectorID: identifier)
      if let frames = expected["frames"] as? [Any] {
        for frame in frames {
          try exactKeys(
            requireObject(frame, vectorID: identifier),
            ["associationID", "flags", "messageType", "payloadHex"],
            vectorID: identifier
          )
        }
      }
    }

    let corpus: RelayVectorCorpus
    do {
      corpus = try JSONDecoder().decode(RelayVectorCorpus.self, from: data)
    } catch {
      throw RelayVectorHarnessFailure(vectorID: "<corpus>", reason: "typed schema decode failed")
    }
    try validate(corpus)
    return corpus
  }

  private static func validate(_ corpus: RelayVectorCorpus) throws {
    guard corpus.formatVersion == 1 else {
      throw RelayVectorHarnessFailure(vectorID: "<corpus>", reason: "unsupported format version")
    }
    guard corpus.protocolVersion == RelayProtocolV1.wireVersion else {
      throw RelayVectorHarnessFailure(vectorID: "<corpus>", reason: "protocol version mismatch")
    }
    guard
      corpus.provenance.generator == "scripts/relay-protocol-vectors.py",
      corpus.provenance.generatorFormatVersion == 1,
      corpus.provenance.generatorSHA256.count == 64,
      corpus.provenance.privacy == "synthetic-only-rfc-reserved-endpoints",
      corpus.provenance.regenerateCommand == "make relay-protocol-vectors-generate",
      corpus.provenance.schemaSHA256 == RelayProtocolV1.schemaSHA256,
      corpus.provenance.task == "TASK-260715-1q7u14",
      Set(corpus.provenance.reviewPolicy.requiredConsumers) == [
        "Swift ReluxTunnelCoreTests", "Go relay/internal/protocol",
      ],
      !corpus.provenance.reviewPolicy.compatibility.isEmpty,
      !corpus.provenance.reviewPolicy.identifiers.isEmpty,
      !corpus.provenance.sources.isEmpty
    else {
      throw RelayVectorHarnessFailure(vectorID: "<corpus>", reason: "invalid provenance")
    }

    var identifiers: Set<String> = []
    var coverage: Set<String> = []
    for vector in corpus.vectors {
      guard
        vector.id.hasPrefix("v1."),
        vector.id.unicodeScalars.allSatisfy({
          CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-").contains($0)
        }),
        identifiers.insert(vector.id).inserted
      else {
        throw RelayVectorHarnessFailure(
          vectorID: vector.id, reason: "invalid or duplicate identifier")
      }
      guard vector.protocolVersion == corpus.protocolVersion else {
        throw RelayVectorHarnessFailure(vectorID: vector.id, reason: "protocol version mismatch")
      }
      let input = try decodeHex(vector.inputHex, vectorID: vector.id)
      guard vector.inputHex == vector.inputHex.lowercased() else {
        throw RelayVectorHarnessFailure(vectorID: vector.id, reason: "noncanonical hex")
      }
      if !vector.chunks.isEmpty {
        guard vector.chunks.allSatisfy({ $0 > 0 }), vector.chunks.reduce(0, +) == input.count else {
          throw RelayVectorHarnessFailure(vectorID: vector.id, reason: "invalid chunk plan")
        }
      }
      for reference in vector.limitRefs {
        _ = try resolvedLimit(reference, vectorID: vector.id)
      }
      guard Set(vector.features).isSubset(of: ["dnsPriorityHint"]) else {
        throw RelayVectorHarnessFailure(vectorID: vector.id, reason: "unknown feature")
      }
      coverage.formUnion(vector.covers)
    }
    let missing = requiredCoverage().subtracting(coverage)
    guard missing.isEmpty else {
      throw RelayVectorHarnessFailure(vectorID: "<corpus>", reason: "required coverage missing")
    }
  }

  private static func validateExpected(
    _ expected: [String: Any],
    kind: String?,
    vectorID: String
  ) throws {
    guard let outcome = expected["outcome"] as? String else {
      throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "missing outcome")
    }
    if outcome == "failure" {
      try exactKeys(
        expected,
        ["code", "disposition", "outcome", "phase", "scope"],
        vectorID: vectorID
      )
      return
    }
    guard outcome == "success" else {
      throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "unknown outcome")
    }
    let keys: Set<String> =
      switch kind {
      case "clientHello": ["flags", "maxFrame", "outcome", "version"]
      case "serverHello": ["features", "maxFrame", "outcome", "status", "version"]
      case "envelope", "stream": ["frames", "outcome"]
      case "datagram": ["addressHex", "addressType", "dataHex", "outcome", "port"]
      case "envelopeDatagram":
        [
          "addressHex", "addressType", "dataHex", "frames", "outcome", "port",
        ]
      default:
        throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "unknown kind")
      }
    try exactKeys(expected, keys, vectorID: vectorID)
  }

  private static func requireObject(
    _ value: Any?,
    vectorID: String
  ) throws -> [String: Any] {
    guard let object = value as? [String: Any] else {
      throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "expected object")
    }
    return object
  }

  private static func exactKeys(
    _ object: [String: Any],
    _ allowed: Set<String>,
    vectorID: String
  ) throws {
    guard Set(object.keys) == allowed else {
      throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "schema keys mismatch")
    }
  }

  private static func requiredCoverage() -> Set<String> {
    var required: Set<String> = [
      "hello:client", "hello:server", "chunk:fragmented", "chunk:coalesced",
      "failureScope:session.closeSession", "failureScope:association.closeAssociation",
      "failureScope:association.rejectDatagram", "boundary:frameBody:maximumLegal",
      "boundary:frameBody:aboveMaximumLegal", "boundary:maxFrame:belowFloor",
      "boundary:maxFrame:floor", "boundary:maxFrame:ceiling",
      "boundary:maxFrame:aboveCeiling", "boundary:payload:zero",
      "boundary:payload:maximum", "boundary:payload:aboveMaximum",
      "boundary:domain:minimum", "boundary:domain:maximum",
      "boundary:domain:aboveMaximum",
    ]
    required.formUnion(RelayProtocolV1.messageMetadata.map { "messageType:\($0.name)" })
    required.formUnion(RelayProtocolV1.addressTypeMetadata.map { "addressType:\($0.name)" })
    required.formUnion(RelayProtocolV1.helloStatusNames.map { "helloStatus:\($0.name)" })
    required.formUnion(RelayProtocolV1.udpErrorCodeNames.map { "udpError:\($0.name)" })
    for metadata in RelayProtocolV1.messageMetadata {
      let directions =
        metadata.direction == .both
        ? ["clientToRelay", "relayToClient"] : [metadata.direction.rawValue]
      required.formUnion(directions.map { "direction:\(metadata.name):\($0)" })
    }
    return required
  }
}

private func resolvedLimit(_ reference: String, vectorID: String) throws -> UInt64 {
  let parts = reference.split(separator: ".", maxSplits: 1).map(String.init)
  guard
    parts.count == 2,
    let spec = RelayProtocolV1.limits.first(where: { $0.name == parts[0] })
  else {
    throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "invalid limit reference")
  }
  switch parts[1] {
  case "floor": return spec.floor
  case "clientDefault": return spec.clientDefault
  case "relayDefault": return spec.relayDefault
  case "clientHardCeiling": return spec.clientHardCeiling
  case "relayHardCeiling": return spec.relayHardCeiling
  default:
    throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "invalid limit selector")
  }
}

private func featureSet(_ names: [String]) -> RelayFeatureSet {
  names.contains("dnsPriorityHint") ? [.dnsPriorityHint] : []
}

private func envelopeDirection(
  _ raw: String,
  vectorID: String
) throws -> RelayEnvelopeDirection {
  switch raw {
  case "clientToRelay": .clientToRelay
  case "relayToClient": .relayToClient
  default:
    throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "invalid direction")
  }
}

private func decodeHex(_ value: String, vectorID: String) throws -> Data {
  guard value.count.isMultiple(of: 2) else {
    throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "odd hex width")
  }
  var result = Data()
  result.reserveCapacity(value.count / 2)
  var index = value.startIndex
  while index < value.endIndex {
    let end = value.index(index, offsetBy: 2)
    guard let byte = UInt8(value[index..<end], radix: 16) else {
      throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "invalid hex")
    }
    result.append(byte)
    index = end
  }
  return result
}

private func chunks(
  of data: Data,
  plan: [Int],
  vectorID: String
) throws -> [Data] {
  let sizes = plan.isEmpty ? [data.count] : plan
  guard sizes.allSatisfy({ $0 > 0 }), sizes.reduce(0, +) == data.count else {
    throw RelayVectorHarnessFailure(vectorID: vectorID, reason: "invalid chunk plan")
  }
  var offset = 0
  return sizes.map { size in
    defer { offset += size }
    return Data(data[offset..<(offset + size)])
  }
}

private func require<T>(
  _ value: T?,
  _ vector: RelayProtocolVector,
  _ reason: String
) throws -> T {
  guard let value else {
    throw RelayVectorHarnessFailure(vectorID: vector.id, reason: reason)
  }
  return value
}

private func require(
  _ condition: @autoclosure () throws -> Bool,
  _ vector: RelayProtocolVector,
  _ reason: String
) throws {
  guard try condition() else {
    throw RelayVectorHarnessFailure(vectorID: vector.id, reason: reason)
  }
}
