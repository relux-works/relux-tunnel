import Foundation

public enum PacketAddressFamily: Codable, Sendable {
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

/// Platform-neutral view of `NEPacketTunnelFlow`.
public protocol PacketFlow: AnyObject, Sendable {
  func readPackets() async throws -> [TunnelPacket]
  func writePackets(_ packets: [TunnelPacket]) async throws
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
