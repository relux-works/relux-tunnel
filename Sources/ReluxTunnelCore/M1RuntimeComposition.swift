import Foundation

/// TCP admission used by the private M1 packet ingress. Concrete TCP
/// implementations remain outside the composition layer.
public protocol M1TCPIngressConsumer: TCPConsumer {
  func openTCP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> any SSHByteChannel
}

/// Safe-DNS admission used by the private M1 packet ingress. Only the
/// composition-owned virtual DNS endpoints are routed here.
public protocol M1DNSIngressConsumer: DNSConsumer {
  func openTCP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> any SSHByteChannel

  func exchangeUDP(
    _ query: Data,
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> Data
}

/// Candidate-neutral channel surface retained by an authenticated M1 SSH
/// session. TCP and DNS consumers never receive the concrete transport.
public protocol M1SSHChannelSession: SSHBootstrapSession {
  func openTCP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> any SSHByteChannel
}

public enum M1PrivateIngressRequest: Sendable {
  case tcp(destination: TunnelEndpoint, originator: TunnelEndpoint)
  case udp(
    payload: Data,
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  )
}

public enum M1PrivateIngressDispatch: Sendable {
  case tcp(any SSHByteChannel)
  case dnsTCP(any SSHByteChannel)
  case dnsUDP(Data)
}

public enum M1PrivateIngressError: Error, Equatable, Sendable {
  case incompatibleTCPConsumer
  case incompatibleDNSConsumer
  case generalUDPDeferred
}

public protocol M1PrivateIngressDispatching: Sendable {
  func dispatch(_ request: M1PrivateIngressRequest) async throws
    -> M1PrivateIngressDispatch
}

/// M1's only private-ingress routing decision.
///
/// TCP CONNECT is admitted by TCP except for the explicitly supplied virtual
/// DNS endpoints. UDP is admitted only for those virtual DNS endpoints; all
/// other UDP fails closed until the later general-UDP milestone.
public struct M1PrivateIngressDispatcher: M1PrivateIngressDispatching {
  private let tcp: any M1TCPIngressConsumer
  private let dns: any M1DNSIngressConsumer
  private let virtualDNSEndpoints: Set<TunnelEndpoint>

  public init(
    tcp: any M1TCPIngressConsumer,
    dns: any M1DNSIngressConsumer,
    virtualDNSEndpoints: Set<TunnelEndpoint>
  ) {
    self.tcp = tcp
    self.dns = dns
    self.virtualDNSEndpoints = virtualDNSEndpoints
  }

  public func dispatch(
    _ request: M1PrivateIngressRequest
  ) async throws -> M1PrivateIngressDispatch {
    switch request {
    case .tcp(let destination, let originator):
      if virtualDNSEndpoints.contains(destination) {
        return .dnsTCP(
          try await dns.openTCP(destination: destination, originator: originator)
        )
      }
      return .tcp(
        try await tcp.openTCP(destination: destination, originator: originator)
      )
    case .udp(let payload, let destination, let originator):
      guard virtualDNSEndpoints.contains(destination) else {
        throw M1PrivateIngressError.generalUDPDeferred
      }
      return .dnsUDP(
        try await dns.exchangeUDP(
          payload,
          destination: destination,
          originator: originator
        )
      )
    }
  }
}

public typealias M1PacketBridgeBuilder =
  @Sendable (
    _ ingress: any M1PrivateIngressDispatching,
    _ runtimeGeneration: UInt64
  ) throws -> any PacketBridge

/// Resource-free packet-plane preflight.
///
/// The builder may construct owners but must not create descriptors, listeners,
/// native leases/threads, or PacketFlow reads. Those operations belong to the
/// returned bridge's `start` call, reached only through `activateReads`.
public struct BridgeBackedM1PacketPlaneFactory: M1PacketPlaneFactory {
  private let configuration: PacketBridgeConfiguration
  private let virtualDNSEndpoints: Set<TunnelEndpoint>
  private let makeBridge: M1PacketBridgeBuilder

  public init(
    configuration: PacketBridgeConfiguration,
    virtualDNSEndpoints: Set<TunnelEndpoint>,
    makeBridge: @escaping M1PacketBridgeBuilder
  ) {
    self.configuration = configuration
    self.virtualDNSEndpoints = virtualDNSEndpoints
    self.makeBridge = makeBridge
  }

  public func prepare(
    configuration: RuntimeConfigurationSnapshot,
    tcp: any TCPConsumer,
    dns: any DNSConsumer,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any M1PacketPlaneSession {
    guard let tcp = tcp as? any M1TCPIngressConsumer else {
      throw M1PrivateIngressError.incompatibleTCPConsumer
    }
    guard let dns = dns as? any M1DNSIngressConsumer else {
      throw M1PrivateIngressError.incompatibleDNSConsumer
    }
    let ingress = M1PrivateIngressDispatcher(
      tcp: tcp,
      dns: dns,
      virtualDNSEndpoints: virtualDNSEndpoints
    )
    let bridge = try makeBridge(ingress, runtimeGeneration)
    return BridgeBackedM1PacketPlaneSession(
      bridge: bridge,
      configuration: self.configuration,
      runtimeGeneration: runtimeGeneration,
      healthSink: healthSink
    )
  }
}

/// One-generation owner of the accepted PacketBridge.
public actor BridgeBackedM1PacketPlaneSession: M1PacketPlaneSession {
  private enum State {
    case prepared
    case activating
    case active
    case failed
    case stopped
  }

  private let bridge: any PacketBridge
  private let configuration: PacketBridgeConfiguration
  private let runtimeGeneration: UInt64
  private let healthSink: any TunnelRuntimeHealthEventSink
  private var state = State.prepared

  public init(
    bridge: any PacketBridge,
    configuration: PacketBridgeConfiguration,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) {
    self.bridge = bridge
    self.configuration = configuration
    self.runtimeGeneration = runtimeGeneration
    self.healthSink = healthSink
  }

  public func activateReads(packetFlow: any PacketFlow) async throws {
    guard state == .prepared else {
      throw PacketFlowBridgeError.alreadyActive
    }
    state = .activating
    do {
      _ = try await bridge.start(
        packetFlow: packetFlow,
        configuration: configuration
      )
      state = .active
    } catch {
      state = .failed
      await healthSink.receive(
        TunnelRuntimeHealthEvent(
          runtimeGeneration: runtimeGeneration,
          component: .packetPlane,
          health: .unhealthy
        )
      )
      throw error
    }
  }

  public func stop() async {
    guard state != .stopped else { return }
    await bridge.stop()
    state = .stopped
  }

  public func health() async -> TunnelRuntimeComponentHealth {
    switch state {
    case .prepared, .activating, .active:
      .healthy
    case .failed, .stopped:
      .unhealthy
    }
  }
}
