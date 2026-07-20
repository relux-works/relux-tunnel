import Foundation

public enum PacketAddressFamily: Codable, Hashable, Sendable {
  case ipv4
  case ipv6
}

public struct TunnelPacket: Equatable, Sendable {
  public let payload: Data
  public let addressFamily: PacketAddressFamily

  public init(payload: Data, addressFamily: PacketAddressFamily) {
    self.payload = payload
    self.addressFamily = addressFamily
  }
}

/// The result for one packet position in an `NEPacketTunnelFlow` callback batch.
///
/// Malformed results deliberately contain no packet payload or destination data.
public enum PacketReadResult: Equatable, Sendable {
  case packet(TunnelPacket)
  case malformed(PacketReadAnomaly)
}

public enum PacketReadAnomaly: Equatable, Sendable {
  case emptyPayload(expectedFamily: PacketAddressFamily)
  case unsupportedAddressFamily(Int32)
  case payloadVersionMismatch(
    expectedFamily: PacketAddressFamily,
    actualVersion: UInt8
  )
}

/// One callback batch in callback order, with packet boundaries preserved.
public struct PacketReadBatch: Equatable, Sendable {
  public let results: [PacketReadResult]

  public init(results: [PacketReadResult]) {
    self.results = results
  }

}

/// Privacy-safe metric work produced by inspecting a read result.
///
/// The contract exposes only a counter name and aggregate amount. It cannot
/// carry packet bytes, endpoints, or other payload-derived fields.
public struct PacketFlowMetricIncrement: Equatable, Sendable {
  public let counterName: String
  public let amount: UInt64

  public init(counterName: String, amount: UInt64) {
    self.counterName = counterName
    self.amount = amount
  }
}

public enum PacketFlowMetricName {
  public static let forwardDropMalformed =
    "packet_bridge_forward_drop_malformed_total"
}

public enum PacketFlowError: Error, Equatable, Sendable {
  case readAlreadyPending
  case adapterShutDown
  case packetProtocolCardinalityMismatch(packetCount: Int, protocolCount: Int)
  case writeRejected

  public var metricIncrements: [PacketFlowMetricIncrement] {
    switch self {
    case .packetProtocolCardinalityMismatch(let packetCount, _)
    where packetCount > 0:
      [
        PacketFlowMetricIncrement(
          counterName: PacketFlowMetricName.forwardDropMalformed,
          amount: UInt64(packetCount)
        )
      ]
    case .readAlreadyPending,
      .adapterShutDown,
      .packetProtocolCardinalityMismatch,
      .writeRejected:
      []
    }
  }
}

extension PacketReadBatch {
  public var metricIncrements: [PacketFlowMetricIncrement] {
    let malformedCount = results.reduce(into: UInt64.zero) { count, result in
      if case .malformed = result {
        count += 1
      }
    }
    guard malformedCount > 0 else {
      return []
    }
    return [
      PacketFlowMetricIncrement(
        counterName: PacketFlowMetricName.forwardDropMalformed,
        amount: malformedCount
      )
    ]
  }
}

/// Injectable public-API callback seam used by both platform adapters.
public protocol PacketFlowPlatformDriver: AnyObject, Sendable {
  func registerRead(
    _ callback: @escaping @Sendable ([Data], [Int32]) -> Void
  )
  func writePackets(_ packets: [Data], protocols: [Int32]) -> Bool
}

/// Platform-neutral view of `NEPacketTunnelFlow`.
public protocol PacketFlow: AnyObject, Sendable {
  func readPackets() async throws -> PacketReadBatch
  func writePackets(_ packets: [TunnelPacket]) async throws
  func shutdown() async
}

extension PacketFlow {
  public func shutdown() async {}
}

/// Caller-owned packet bridge limits. No value here is a production default.
public struct PacketBridgeConfiguration: Equatable, Sendable {
  public let mtu: Int
  public let sendBufferBytes: Int
  public let receiveBufferBytes: Int
  public let maximumReadBatch: Int
  public let readTimeBudget: Duration

  public init(
    mtu: Int,
    sendBufferBytes: Int,
    receiveBufferBytes: Int,
    maximumReadBatch: Int,
    readTimeBudget: Duration
  ) {
    self.mtu = mtu
    self.sendBufferBytes = sendBufferBytes
    self.receiveBufferBytes = receiveBufferBytes
    self.maximumReadBatch = maximumReadBatch
    self.readTimeBudget = readTimeBudget
  }
}

/// Public packet-flow-to-bridge seam from ADR-003.
///
/// Implementations may expose only their owned documented descriptor to HEV;
/// the contract deliberately has no utun discovery surface.
public protocol PacketBridge: AnyObject, Sendable {
  func start(
    packetFlow: any PacketFlow,
    configuration: PacketBridgeConfiguration
  ) async throws
  func stop() async
  func metrics() async -> TunnelMetricsSnapshot
}
