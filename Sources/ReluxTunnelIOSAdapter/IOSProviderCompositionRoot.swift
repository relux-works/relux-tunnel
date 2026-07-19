import Darwin
import Foundation
import NetworkExtension
import ReluxTunnelCore

public enum IOSPacketFlowAdapterError: Error {
  case writeRejected
}

/// Public-API adapter for the iOS provider's `NEPacketTunnelFlow`.
public final class IOSPacketFlowAdapter: PacketFlow, @unchecked Sendable {
  private let packetFlow: NEPacketTunnelFlow

  public init(packetFlow: NEPacketTunnelFlow) {
    self.packetFlow = packetFlow
  }

  public func readPackets() async throws -> [TunnelPacket] {
    await withCheckedContinuation { continuation in
      packetFlow.readPackets { packets, protocols in
        let result = zip(packets, protocols).compactMap { packet, protocolNumber in
          switch protocolNumber.int32Value {
          case AF_INET:
            TunnelPacket(payload: packet, addressFamily: .ipv4)
          case AF_INET6:
            TunnelPacket(payload: packet, addressFamily: .ipv6)
          default:
            nil
          }
        }
        continuation.resume(returning: result)
      }
    }
  }

  public func writePackets(_ packets: [TunnelPacket]) async throws {
    let payloads = packets.map(\.payload)
    let protocols = packets.map { packet in
      switch packet.addressFamily {
      case .ipv4:
        NSNumber(value: AF_INET)
      case .ipv6:
        NSNumber(value: AF_INET6)
      }
    }
    guard packetFlow.writePackets(payloads, withProtocols: protocols) else {
      throw IOSPacketFlowAdapterError.writeRejected
    }
  }
}

/// Thin iOS composition root. The concrete provider subclass is a later task.
public struct IOSProviderCompositionRoot: TunnelProviderLifecycle {
  private let adapter: TunnelProviderAdapter

  public init(
    packetFlow: any PacketFlow,
    runtimeFactory: any TunnelRuntimeFactory,
    dependencies: TunnelRuntimeDependencies
  ) {
    adapter = TunnelProviderAdapter(
      packetFlow: packetFlow,
      runtimeFactory: runtimeFactory,
      dependencies: dependencies
    )
  }

  public init(
    packetTunnelFlow: NEPacketTunnelFlow,
    runtimeFactory: any TunnelRuntimeFactory,
    dependencies: TunnelRuntimeDependencies
  ) {
    self.init(
      packetFlow: IOSPacketFlowAdapter(packetFlow: packetTunnelFlow),
      runtimeFactory: runtimeFactory,
      dependencies: dependencies
    )
  }

  public func start(configuration: TunnelConfiguration) async throws {
    try await adapter.start(configuration: configuration)
  }

  public func stop(reason: ProviderStopReason) async {
    await adapter.stop(reason: reason)
  }

  public func handleAppMessage(_ message: Data) async throws -> Data {
    try await adapter.handleAppMessage(message)
  }

  public func lifecyclePhase() async -> ProviderLifecyclePhase {
    await adapter.lifecyclePhase()
  }
}
