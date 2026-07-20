import Foundation
import NetworkExtension
import ReluxTunnelCore

/// Public-API adapter for the macOS provider's `NEPacketTunnelFlow`.
public final class MacOSPacketFlowAdapter: PacketFlow, @unchecked Sendable {
  private let boundary: PacketFlowAdapterBoundary

  public init(packetFlow: NEPacketTunnelFlow) {
    boundary = PacketFlowAdapterBoundary(
      driver: MacOSNEPacketFlowDriver(packetFlow: packetFlow)
    )
  }

  public init(driver: any PacketFlowPlatformDriver) {
    boundary = PacketFlowAdapterBoundary(driver: driver)
  }

  public func readPackets() async throws -> PacketReadBatch {
    try await boundary.readPackets()
  }

  public func writePackets(_ packets: [TunnelPacket]) async throws {
    try boundary.writePackets(packets)
  }

  public func shutdown() async {
    boundary.shutDown()
  }
}

private final class MacOSNEPacketFlowDriver: PacketFlowPlatformDriver, @unchecked Sendable {
  private let packetFlow: NEPacketTunnelFlow

  init(packetFlow: NEPacketTunnelFlow) {
    self.packetFlow = packetFlow
  }

  func registerRead(
    _ callback: @escaping @Sendable ([Data], [Int32]) -> Void
  ) {
    packetFlow.readPackets { packets, protocols in
      callback(packets, protocols.map(\.int32Value))
    }
  }

  func writePackets(_ packets: [Data], protocols: [Int32]) -> Bool {
    packetFlow.writePackets(
      packets,
      withProtocols: protocols.map { NSNumber(value: $0) }
    )
  }
}

/// Thin macOS composition root. The concrete provider subclass is a later task.
public struct MacOSProviderCompositionRoot: TunnelProviderLifecycle {
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
      packetFlow: MacOSPacketFlowAdapter(packetFlow: packetTunnelFlow),
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
