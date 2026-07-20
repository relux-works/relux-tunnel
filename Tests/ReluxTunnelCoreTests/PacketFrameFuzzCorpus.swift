import Darwin
import Foundation
import ReluxTunnelCore

enum PacketFrameCorpusCategory: String, CaseIterable, Sendable {
  case ipv4
  case ipv6
  case empty
  case undersized
  case unknownFamily
  case exactMTU
  case overMTU
  case regression
}

struct PacketFrameCorpusSeed: Sendable {
  let id: String
  let categories: Set<PacketFrameCorpusCategory>
  let frame: Data
}

enum PacketFrameMalformedReason: String, CaseIterable, Sendable {
  case shortHeader
  case emptyPayload
  case unknownFamily
  case payloadVersionMismatch
}

enum PacketFrameDisposition: Equatable, Sendable {
  case valid(TunnelPacket)
  case malformed(PacketFrameMalformedReason)
  case oversized(observedBytes: Int)
}

enum PacketFrameFuzzCorpus {
  static let mtu = 1_500
  static let maximumDatagramBytes = mtu + 4

  static let seeds: [PacketFrameCorpusSeed] = [
    .init(
      id: "ipv4-minimum",
      categories: [.ipv4],
      frame: fuzzFamilyWord(AF_INET) + Data([0x45])
    ),
    .init(
      id: "ipv6-minimum",
      categories: [.ipv6],
      frame: fuzzFamilyWord(AF_INET6) + Data([0x60])
    ),
    .init(id: "empty-datagram", categories: [.empty, .regression], frame: Data()),
    .init(id: "one-byte", categories: [.undersized], frame: Data([0xff])),
    .init(id: "two-byte", categories: [.undersized], frame: Data([0xff, 0xff])),
    .init(
      id: "three-byte",
      categories: [.undersized],
      frame: Data([0xff, 0xff, 0xff])
    ),
    .init(
      id: "unknown-family",
      categories: [.unknownFamily],
      frame: fuzzFamilyWord(Int32.max) + Data([0x45])
    ),
    .init(
      id: "exact-mtu-ipv4",
      categories: [.ipv4, .exactMTU],
      frame: fuzzFamilyWord(AF_INET)
        + Data([0x45])
        + Data(repeating: 0xa5, count: mtu - 1)
    ),
    .init(
      id: "over-mtu-ipv6",
      categories: [.ipv6, .overMTU],
      frame: fuzzFamilyWord(AF_INET6)
        + Data([0x60])
        + Data(repeating: 0x5a, count: mtu)
    ),
    .init(
      id: "regression-family-only",
      categories: [.regression],
      frame: fuzzFamilyWord(AF_INET)
    ),
    .init(
      id: "regression-ipv4-family-ipv6-payload",
      categories: [.regression],
      frame: fuzzFamilyWord(AF_INET) + Data([0x60, 0xde, 0xad])
    ),
    .init(
      id: "regression-ipv6-family-ipv4-payload",
      categories: [.regression],
      frame: fuzzFamilyWord(AF_INET6) + Data([0x45, 0xbe, 0xef])
    ),
  ]

  static func classify(_ frame: Data, mtu: Int) -> PacketFrameDisposition {
    let (maximumDatagramBytes, overflow) = mtu.addingReportingOverflow(4)
    if overflow || frame.count > maximumDatagramBytes {
      return .oversized(observedBytes: frame.count)
    }
    guard frame.count >= 4 else {
      return .malformed(.shortHeader)
    }
    guard frame.count > 4 else {
      return .malformed(.emptyPayload)
    }

    let family =
      (UInt32(frame[frame.startIndex]) << 24)
      | (UInt32(frame[frame.startIndex + 1]) << 16)
      | (UInt32(frame[frame.startIndex + 2]) << 8)
      | UInt32(frame[frame.startIndex + 3])
    let addressFamily: PacketAddressFamily
    let expectedVersion: UInt8
    if family == UInt32(AF_INET) {
      addressFamily = .ipv4
      expectedVersion = 4
    } else if family == UInt32(AF_INET6) {
      addressFamily = .ipv6
      expectedVersion = 6
    } else {
      return .malformed(.unknownFamily)
    }

    let payload = Data(frame.dropFirst(4))
    guard payload[0] >> 4 == expectedVersion else {
      return .malformed(.payloadVersionMismatch)
    }
    return .valid(TunnelPacket(payload: payload, addressFamily: addressFamily))
  }

  static func generatedFrames(
    seed: UInt64,
    iterations: Int,
    mtu: Int,
    includeOversized: Bool
  ) -> [Data] {
    let maximumDatagramBytes = mtu + 4
    let largest = maximumDatagramBytes + (includeOversized ? 1 : 0)
    var generator = SplitMix64(seed: seed)
    return (0..<iterations).map { iteration in
      let length: Int
      switch iteration % 16 {
      case 0: length = 0
      case 1: length = 1
      case 2: length = 2
      case 3: length = 3
      case 4: length = 4
      case 5: length = maximumDatagramBytes
      case 6 where includeOversized: length = maximumDatagramBytes + 1
      default: length = generator.nextInt(upperBound: largest + 1)
      }
      var bytes = generator.bytes(count: length)
      if length >= 5, iteration % 4 != 0 {
        let ipv6 = iteration.isMultiple(of: 2)
        let family = fuzzFamilyWord(ipv6 ? AF_INET6 : AF_INET)
        bytes.replaceSubrange(0..<4, with: family)
        if iteration % 4 == 1 {
          bytes[4] = ipv6 ? 0x60 : 0x45
        }
      }
      return bytes
    }
  }
}

struct PacketFrameFuzzConfiguration: Sendable {
  static let defaultSeed: UInt64 = 0x52_48_38_49_33
  static let defaultIterations = 512
  static let maximumIterations = 50_000
  static let defaultRuntimeCeilingMilliseconds = 5_000
  static let defaultAllocationCeilingBytes = 32 * 1_024 * 1_024

  let seed: UInt64
  let iterations: Int
  let runtimeCeilingMilliseconds: Int
  let allocationCeilingBytes: UInt64
  let sourceRevision: String

  static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
    Self(
      seed: parseSeed(environment["RELUX_PACKET_FUZZ_SEED"]) ?? defaultSeed,
      iterations: boundedInt(
        environment["RELUX_PACKET_FUZZ_ITERATIONS"],
        defaultValue: defaultIterations,
        upperBound: maximumIterations
      ),
      runtimeCeilingMilliseconds: boundedInt(
        environment["RELUX_PACKET_FUZZ_RUNTIME_MS"],
        defaultValue: defaultRuntimeCeilingMilliseconds,
        upperBound: 60_000
      ),
      allocationCeilingBytes: UInt64(
        boundedInt(
          environment["RELUX_PACKET_FUZZ_ALLOCATION_BYTES"],
          defaultValue: defaultAllocationCeilingBytes,
          upperBound: 512 * 1_024 * 1_024
        )
      ),
      sourceRevision: environment["RELUX_PACKET_FUZZ_REVISION"] ?? "unspecified"
    )
  }

  private static func parseSeed(_ value: String?) -> UInt64? {
    guard let value else { return nil }
    if value.lowercased().hasPrefix("0x") {
      return UInt64(value.dropFirst(2), radix: 16)
    }
    return UInt64(value)
  }

  private static func boundedInt(
    _ value: String?,
    defaultValue: Int,
    upperBound: Int
  ) -> Int {
    guard let value, let parsed = Int(value), parsed > 0 else {
      return defaultValue
    }
    return min(parsed, upperBound)
  }
}

enum PacketFrameCoalescedInput {
  static let lengthPrefixBytes = 4

  /// Test-only length-prefixed splitter. Declared lengths are never used for
  /// allocation: each materialized datagram is capped at `ceiling + 1`, while
  /// the cursor advances only across bytes that already exist in `input`.
  static func split(_ input: Data, maximumDatagramBytes: Int) -> [Data] {
    guard maximumDatagramBytes >= 0, maximumDatagramBytes < Int.max else {
      return []
    }
    let materializedCeiling = UInt64(maximumDatagramBytes + 1)
    var frames: [Data] = []
    var cursor = 0
    while input.count - cursor >= lengthPrefixBytes {
      let start = input.startIndex + cursor
      let declaredLength =
        (UInt64(input[start]) << 24)
        | (UInt64(input[start + 1]) << 16)
        | (UInt64(input[start + 2]) << 8)
        | UInt64(input[start + 3])
      cursor += lengthPrefixBytes
      let available = input.count - cursor
      let existingLength = min(declaredLength, UInt64(available))
      let materializedLength = Int(min(existingLength, materializedCeiling))
      let payloadStart = input.startIndex + cursor
      frames.append(Data(input[payloadStart..<(payloadStart + materializedLength)]))
      cursor += Int(existingLength)
    }
    return frames
  }

  static func encode(_ frames: [Data]) -> Data {
    frames.reduce(into: Data()) { output, frame in
      let length = UInt32(clamping: frame.count)
      output.append(contentsOf: [
        UInt8(truncatingIfNeeded: length >> 24),
        UInt8(truncatingIfNeeded: length >> 16),
        UInt8(truncatingIfNeeded: length >> 8),
        UInt8(truncatingIfNeeded: length),
      ])
      output.append(frame)
    }
  }
}

enum PacketFrameFixtureMinimizer {
  static func minimize(_ input: Data, stillFails: (Data) -> Bool) -> Data {
    guard stillFails(input) else { return input }
    var candidate = input
    var granularity = 2
    while candidate.count > 1 {
      let chunkSize = max(1, candidate.count / granularity)
      var reduced = false
      var lowerBound = 0
      while lowerBound < candidate.count {
        let upperBound = min(candidate.count, lowerBound + chunkSize)
        var trial = candidate
        trial.removeSubrange(lowerBound..<upperBound)
        if stillFails(trial) {
          candidate = trial
          granularity = max(2, granularity - 1)
          reduced = true
          break
        }
        lowerBound = upperBound
      }
      if !reduced {
        guard granularity < candidate.count else { break }
        granularity = min(candidate.count, granularity * 2)
      }
    }
    return candidate
  }
}

struct SplitMix64: Sendable {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9e37_79b9_7f4a_7c15
    var value = state
    value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
    value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
    return value ^ (value >> 31)
  }

  mutating func nextInt(upperBound: Int) -> Int {
    guard upperBound > 1 else { return 0 }
    return Int(next() % UInt64(upperBound))
  }

  mutating func bytes(count: Int) -> Data {
    var result = Data(count: count)
    result.withUnsafeMutableBytes { rawBuffer in
      guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
      for index in 0..<count {
        bytes[index] = UInt8(truncatingIfNeeded: next())
      }
    }
    return result
  }
}

func fuzzFamilyWord(_ family: Int32) -> Data {
  let value = UInt32(family)
  return Data([
    UInt8(truncatingIfNeeded: value >> 24),
    UInt8(truncatingIfNeeded: value >> 16),
    UInt8(truncatingIfNeeded: value >> 8),
    UInt8(truncatingIfNeeded: value),
  ])
}

func packetFrameHex(_ data: Data) -> String {
  data.map { String(format: "%02x", $0) }.joined()
}

func currentMallocBytesInUse() -> UInt64 {
  var statistics = malloc_statistics_t()
  malloc_zone_statistics(nil, &statistics)
  return UInt64(statistics.size_in_use)
}
