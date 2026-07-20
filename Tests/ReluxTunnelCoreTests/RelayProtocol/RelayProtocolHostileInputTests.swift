import Foundation
import ReluxTunnelCore
import Testing

@Suite("RelayProtocol v1 deterministic hostile input")
struct RelayProtocolHostileInputTests {
  @Test("shared regression seeds preserve semantic and resource bounds")
  func hostileInputCorpus() throws {
    let corpus = try HostileCorpus.load()
    let start = ContinuousClock.now
    var summary = HostileSummary()

    for seed in corpus.seeds {
      let seedValue = try seed.parsedValue()
      var generator = HostileGenerator(state: seedValue)
      var digest = HostileDigest()
      for iteration in 0..<seed.iterations {
        let input = try mutateInput(corpus: corpus, generator: &generator)
        for direction in [RelayEnvelopeDirection.clientToRelay, .relayToClient] {
          _ = try runEnvelopeCase(
            input,
            direction: direction,
            corpus: corpus,
            generator: &generator,
            digest: &digest,
            summary: &summary
          )
        }
        if iteration.isMultiple(of: 32) {
          try runCancellationCase(digest: &digest, summary: &summary)
        }
      }
      try runDeclaredLengthBoundaryCases(
        corpus: corpus,
        digest: &digest,
        summary: &summary
      )
      #expect(digest.hex == seed.expectedSemanticDigest)
      print(
        "relay-hostile-seed language=swift id=\(seed.id) value=\(seed.value) "
          + "semanticDigest=\(digest.hex)"
      )
    }

    let duration = start.duration(to: .now)
    let milliseconds =
      duration.components.seconds * 1_000
      + duration.components.attoseconds / 1_000_000_000_000_000
    print(
      "relay-hostile-summary language=swift seeds=\(corpus.seeds.count) "
        + "cases=\(summary.cases) inputBytes=\(summary.inputBytes) "
        + "peakRetainedBytes=\(summary.peakRetainedBytes) "
        + "peakAllocatedBodyBytes=\(summary.peakAllocatedBodyBytes) "
        + "maximumBodyAllocations=\(summary.maximumBodyAllocations) "
        + "maximumProcessingIterations=\(summary.maximumProcessingIterations) "
        + "maximumProcessingIterationCeiling="
        + "\(summary.maximumProcessingIterationCeiling) "
        + "maximumChunkCount=\(summary.maximumChunkCount) "
        + "maximumDiagnosticBytes=\(summary.maximumDiagnosticBytes) "
        + "terminalRetainedBytes=\(summary.maximumTerminalRetainedBytes) "
        + "terminalOutstandingBodyBytes="
        + "\(summary.maximumTerminalOutstandingBodyBytes) "
        + "resetRetainedBytes=\(summary.maximumResetRetainedBytes) "
        + "resetOutstandingBodyBytes=\(summary.maximumResetOutstandingBodyBytes) "
        + "durationMilliseconds=\(milliseconds)"
    )
  }

  private func runDeclaredLengthBoundaryCases(
    corpus: HostileCorpus,
    digest: inout HostileDigest,
    summary: inout HostileSummary
  ) throws {
    let atCeiling = try corpus.baseInput(id: "declared-length-at-ceiling")
    let overCeiling = try corpus.baseInput(id: "declared-length-over-ceiling")
    var generator = HostileGenerator(state: 0)

    for direction in [RelayEnvelopeDirection.clientToRelay, .relayToClient] {
      let acceptedMetrics = try runEnvelopeCase(
        atCeiling,
        direction: direction,
        corpus: corpus,
        generator: &generator,
        digest: &digest,
        summary: &summary
      )
      #expect(acceptedMetrics.bodyAllocations == 1)
      #expect(acceptedMetrics.peakAllocatedBodyBytes == Int(RelayProtocolV1.maxFrameDefault))

      let rejectedMetrics = try runEnvelopeCase(
        overCeiling,
        direction: direction,
        corpus: corpus,
        generator: &generator,
        digest: &digest,
        summary: &summary
      )
      #expect(rejectedMetrics.bodyAllocations == 0)
      #expect(rejectedMetrics.peakAllocatedBodyBytes == 0)
    }
  }

  private func mutateInput(
    corpus: HostileCorpus,
    generator: inout HostileGenerator
  ) throws -> Data {
    let base = corpus.baseInputs[Int(generator.next() % UInt64(corpus.baseInputs.count))]
    var input = try decodeHostileHex(base.inputHex)
    switch generator.next() % 8 {
    case 0:
      break
    case 1:
      let index = Int(generator.next() % UInt64(input.count))
      input[index] ^= UInt8(truncatingIfNeeded: generator.next())
    case 2:
      input = Data(input.prefix(Int(generator.next() % UInt64(input.count + 1))))
    case 3:
      for _ in 0..<Int(generator.next() % 17) {
        input.append(UInt8(truncatingIfNeeded: generator.next()))
      }
    case 4:
      while input.count < RelayProtocolV1.framePrefixWidth { input.append(0) }
      let length = UInt32(truncatingIfNeeded: generator.next())
      input[0] = UInt8(truncatingIfNeeded: length >> 24)
      input[1] = UInt8(truncatingIfNeeded: length >> 16)
      input[2] = UInt8(truncatingIfNeeded: length >> 8)
      input[3] = UInt8(truncatingIfNeeded: length)
    case 5:
      let other = corpus.baseInputs[Int(generator.next() % UInt64(corpus.baseInputs.count))]
      input.append(try decodeHostileHex(other.inputHex))
    case 6:
      input = Data()
      input.reserveCapacity(corpus.maximumInputBytes)
      for _ in 0..<Int(generator.next() % UInt64(corpus.maximumInputBytes + 1)) {
        input.append(UInt8(truncatingIfNeeded: generator.next()))
      }
    default:
      input.insert(contentsOf: Data("RLXR".utf8), at: input.startIndex)
    }
    return Data(input.prefix(corpus.maximumInputBytes))
  }

  private func runEnvelopeCase(
    _ input: Data,
    direction: RelayEnvelopeDirection,
    corpus: HostileCorpus,
    generator: inout HostileGenerator,
    digest: inout HostileDigest,
    summary: inout HostileSummary
  ) throws -> RelayEnvelopeCodecMetrics {
    var decoder = try RelayEnvelopeDecoder(
      maximumFrame: RelayProtocolV1.maxFrameDefault,
      direction: direction,
      negotiatedFeatures: [.dnsPriorityHint]
    )
    let directionToken = direction == .clientToRelay ? "C" : "R"
    var failed = false
    var chunkCount = 0
    var offset = 0
    while offset < input.count {
      let width = min(
        Int(generator.next() % UInt64(corpus.maximumChunkBytes)) + 1,
        input.count - offset
      )
      let chunk = Data(input[offset..<(offset + width)])
      offset += width
      chunkCount += 1
      do {
        for frame in try decoder.consume(chunk) {
          digest.add("frame/\(directionToken)/\(frame.type.rawValue)")
          if frame.type == .udpDatagram {
            var codec = try RelayDatagramCodec(
              maximumPayloadLength: RelayProtocolV1.maxUDPPayloadClientDefault
            )
            do {
              _ = try codec.decode(frame.payload)
              digest.add("datagram/\(directionToken)/ok")
            } catch let failure as RelayDatagramFailure {
              record(
                failure,
                direction: directionToken,
                digest: &digest,
                summary: &summary
              )
              #expect(codec.metrics.decodedMaterializedBytes == 0)
            }
          }
        }
      } catch let failure as RelayEnvelopeFailure {
        record(
          failure,
          direction: directionToken,
          digest: &digest,
          summary: &summary
        )
        failed = true
        break
      }
    }
    if !failed {
      do {
        try decoder.endOfStream()
        digest.add("eof/\(directionToken)/ok")
      } catch let failure as RelayEnvelopeFailure {
        record(
          failure,
          direction: directionToken,
          digest: &digest,
          summary: &summary
        )
      }
    }

    let metrics = decoder.metrics
    #expect(metrics.retainedBytes == 0)
    #expect(metrics.allocatedBodyBytes == 0)
    #expect(
      metrics.peakRetainedBytes
        <= Int(RelayProtocolV1.maxFrameDefault) + RelayProtocolV1.framePrefixWidth
    )
    #expect(metrics.peakAllocatedBodyBytes <= Int(RelayProtocolV1.maxFrameDefault))
    #expect(metrics.bodyAllocations <= UInt64(input.count / 10 + 1))
    #expect(metrics.inputBytes <= UInt64(input.count))
    #expect(metrics.processingIterations <= processingIterationCeiling(metrics))
    summary.recordTerminal(metrics, chunkCount: chunkCount)

    decoder.reset()
    #expect(decoder.metrics == RelayEnvelopeCodecMetrics())
    #expect(decoder.isAtFrameBoundary)
    summary.recordReset(decoder.metrics)
    return metrics
  }

  private func runCancellationCase(
    digest: inout HostileDigest,
    summary: inout HostileSummary
  ) throws {
    var decoder = try RelayEnvelopeDecoder(
      maximumFrame: RelayProtocolV1.maxFrameDefault,
      direction: .clientToRelay,
      negotiatedFeatures: [.dnsPriorityHint]
    )
    _ = try decoder.consume(Data([0, 0, 0, 14, RelayProtocolV1.MessageType.ping.rawValue]))
    do {
      try decoder.cancel()
      Issue.record("hostile cancellation unexpectedly succeeded")
    } catch let failure as RelayEnvelopeFailure {
      #expect(failure.code == .cancelled)
      record(failure, direction: "C", digest: &digest, summary: &summary)
    }
    #expect(decoder.metrics.retainedBytes == 0)
    #expect(decoder.metrics.allocatedBodyBytes == 0)
    #expect(
      decoder.metrics.processingIterations <= processingIterationCeiling(decoder.metrics)
    )
    summary.recordTerminal(decoder.metrics, chunkCount: 1)
    decoder.reset()
    #expect(decoder.metrics == RelayEnvelopeCodecMetrics())
    #expect(decoder.isAtFrameBoundary)
    summary.recordReset(decoder.metrics)
  }

  private func record(
    _ failure: RelayEnvelopeFailure,
    direction: String,
    digest: inout HostileDigest,
    summary: inout HostileSummary
  ) {
    validateDiagnostic(failure.description, prefix: "relayEnvelope", summary: &summary)
    digest.add(
      "envelope/\(direction)/\(failure.code.rawValue)/\(failure.phase.rawValue)/"
        + "\(failure.scope)/\(failure.disposition)"
    )
  }

  private func record(
    _ failure: RelayDatagramFailure,
    direction: String,
    digest: inout HostileDigest,
    summary: inout HostileSummary
  ) {
    validateDiagnostic(failure.description, prefix: "relayDatagram", summary: &summary)
    digest.add(
      "datagram/\(direction)/\(failure.code.rawValue)/\(failure.phase.rawValue)/"
        + "\(failure.scope.rawValue)/\(failure.disposition.rawValue)"
    )
  }

  private func validateDiagnostic(
    _ description: String,
    prefix: String,
    summary: inout HostileSummary
  ) {
    #expect(description.utf8.count <= 160)
    #expect(description.hasPrefix("\(prefix) code="))
    #expect(!description.contains("inputHex"))
    #expect(!description.contains("RLXR"))
    summary.maximumDiagnosticBytes = max(
      summary.maximumDiagnosticBytes,
      description.utf8.count
    )
  }
}

private struct HostileCorpus: Decodable {
  let algorithm: String
  let baseInputs: [HostileBaseInput]
  let formatVersion: Int
  let maximumChunkBytes: Int
  let maximumInputBytes: Int
  let protocolVersion: UInt16
  let reproductionCommands: HostileReproductionCommands
  let seeds: [HostileSeed]

  static func load() throws -> Self {
    let testFile = URL(fileURLWithPath: #filePath)
    let root = testFile.deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let data = try Data(
      contentsOf: root.appendingPathComponent(
        "Protocol/Relay/Fuzz/v1/regression-seeds.json"
      )
    )
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(
      Set(json.keys) == [
        "algorithm", "baseInputs", "formatVersion", "maximumChunkBytes",
        "maximumInputBytes", "protocolVersion", "reproductionCommands", "seeds",
      ]
    )
    let corpus = try JSONDecoder().decode(Self.self, from: data)
    try corpus.validate()
    return corpus
  }

  private func validate() throws {
    #expect(formatVersion == 1)
    #expect(protocolVersion == RelayProtocolV1.wireVersion)
    #expect(algorithm == "lcg64-v1")
    #expect(maximumInputBytes >= 1)
    #expect(maximumInputBytes <= Int(RelayProtocolV1.maxFrameDefault))
    #expect(maximumChunkBytes >= 1 && maximumChunkBytes <= maximumInputBytes)
    #expect(!baseInputs.isEmpty && !seeds.isEmpty)
    #expect(
      !reproductionCommands.go.isEmpty && !reproductionCommands.goFuzz.isEmpty
        && !reproductionCommands.swift.isEmpty
    )
    var identifiers: Set<String> = []
    for base in baseInputs {
      #expect(validHostileIdentifier(base.id))
      #expect(base.inputHex == base.inputHex.lowercased())
      let input = try decodeHostileHex(base.inputHex)
      #expect(!input.isEmpty && input.count <= maximumInputBytes)
      #expect(identifiers.insert(base.id).inserted)
    }
    #expect(try baseInput(id: "declared-length-at-ceiling") == Data([0, 0, 0x10, 0]))
    #expect(try baseInput(id: "declared-length-over-ceiling") == Data([0, 0, 0x10, 1]))
    for seed in seeds {
      #expect(validHostileIdentifier(seed.id))
      #expect(seed.iterations >= 1 && seed.iterations <= 4_096)
      #expect(seed.expectedSemanticDigest.count == 16)
      _ = try decodeHostileHex(seed.expectedSemanticDigest)
      _ = try seed.parsedValue()
      #expect(identifiers.insert(seed.id).inserted)
    }
  }

  func baseInput(id: String) throws -> Data {
    let base = try #require(baseInputs.first { $0.id == id })
    return try decodeHostileHex(base.inputHex)
  }
}

private struct HostileBaseInput: Decodable {
  let id: String
  let inputHex: String
}

private struct HostileReproductionCommands: Decodable {
  let go: String
  let goFuzz: String
  let swift: String
}

private struct HostileSeed: Decodable {
  let expectedSemanticDigest: String
  let id: String
  let iterations: Int
  let value: String

  func parsedValue() throws -> UInt64 {
    guard
      value.hasPrefix("0x"), value.count == 18, value == value.lowercased(),
      let parsed = UInt64(value.dropFirst(2), radix: 16)
    else {
      throw HostileCorpusFailure.invalidSeed
    }
    return parsed
  }
}

private enum HostileCorpusFailure: Error {
  case invalidHex
  case invalidSeed
}

private struct HostileGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

private struct HostileDigest {
  private(set) var value: UInt64 = 14_695_981_039_346_656_037

  mutating func add(_ token: String) {
    for byte in token.utf8 {
      value ^= UInt64(byte)
      value = value &* 1_099_511_628_211
    }
    value ^= 0xff
    value = value &* 1_099_511_628_211
  }

  var hex: String { String(format: "%016llx", value) }
}

private struct HostileSummary {
  var cases = 0
  var inputBytes: UInt64 = 0
  var maximumBodyAllocations: UInt64 = 0
  var maximumChunkCount = 0
  var maximumDiagnosticBytes = 0
  var maximumProcessingIterations: UInt64 = 0
  var maximumProcessingIterationCeiling: UInt64 = 0
  var maximumResetOutstandingBodyBytes = 0
  var maximumResetRetainedBytes = 0
  var maximumTerminalOutstandingBodyBytes = 0
  var maximumTerminalRetainedBytes = 0
  var peakAllocatedBodyBytes = 0
  var peakRetainedBytes = 0

  mutating func recordTerminal(
    _ metrics: RelayEnvelopeCodecMetrics,
    chunkCount: Int
  ) {
    cases += 1
    inputBytes += metrics.inputBytes
    maximumBodyAllocations = max(maximumBodyAllocations, metrics.bodyAllocations)
    maximumChunkCount = max(maximumChunkCount, chunkCount)
    maximumProcessingIterations = max(
      maximumProcessingIterations,
      metrics.processingIterations
    )
    maximumProcessingIterationCeiling = max(
      maximumProcessingIterationCeiling,
      processingIterationCeiling(metrics)
    )
    maximumTerminalOutstandingBodyBytes = max(
      maximumTerminalOutstandingBodyBytes,
      metrics.allocatedBodyBytes
    )
    maximumTerminalRetainedBytes = max(maximumTerminalRetainedBytes, metrics.retainedBytes)
    peakAllocatedBodyBytes = max(peakAllocatedBodyBytes, metrics.peakAllocatedBodyBytes)
    peakRetainedBytes = max(peakRetainedBytes, metrics.peakRetainedBytes)
  }

  mutating func recordReset(_ metrics: RelayEnvelopeCodecMetrics) {
    maximumResetOutstandingBodyBytes = max(
      maximumResetOutstandingBodyBytes,
      metrics.allocatedBodyBytes
    )
    maximumResetRetainedBytes = max(maximumResetRetainedBytes, metrics.retainedBytes)
  }
}

private func processingIterationCeiling(_ metrics: RelayEnvelopeCodecMetrics) -> UInt64 {
  metrics.inputBytes + metrics.bodyAllocations * 3 + 1
}

private func decodeHostileHex(_ value: String) throws -> Data {
  guard value.count.isMultiple(of: 2) else { throw HostileCorpusFailure.invalidHex }
  var result = Data()
  result.reserveCapacity(value.count / 2)
  var index = value.startIndex
  while index < value.endIndex {
    let end = value.index(index, offsetBy: 2)
    guard let byte = UInt8(value[index..<end], radix: 16) else {
      throw HostileCorpusFailure.invalidHex
    }
    result.append(byte)
    index = end
  }
  return result
}

private func validHostileIdentifier(_ value: String) -> Bool {
  !value.isEmpty
    && value.allSatisfy { $0 == "-" || $0.isNumber || ($0.isLetter && $0.isLowercase) }
}
