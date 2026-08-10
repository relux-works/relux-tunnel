import Foundation
import ReluxTunnelCore
import ReluxTunnelLibSSH2Adapter

public enum HarnessExitCode: Int32, Equatable, Sendable {
  case success = 0
  case failure = 1
  case usage = 64
  case interrupted = 130
  case terminated = 143
}

public enum HarnessCancellationReason: Equatable, Sendable {
  case interrupt
  case terminate
  case task

  public var exitCode: HarnessExitCode {
    switch self {
    case .interrupt, .task:
      .interrupted
    case .terminate:
      .terminated
    }
  }
}

public protocol HarnessCancellationSource: Sendable {
  func waitForCancellation() async -> HarnessCancellationReason
}

public struct HarnessFaultOperation: Hashable, RawRepresentable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public static let smokeStart = Self(rawValue: "smoke.start")
  public static let smokeFinish = Self(rawValue: "smoke.finish")
  public static let makePacketEndpoint = Self(rawValue: "packet-endpoint.make")
  public static let makeSSHTransport = Self(rawValue: "ssh-transport.make")
}

public protocol HarnessFaultPolicy: Sendable {
  func evaluate(_ operation: HarnessFaultOperation) async throws
}

public struct NoHarnessFaultPolicy: HarnessFaultPolicy {
  public init() {}

  public func evaluate(_ operation: HarnessFaultOperation) async throws {}
}

public protocol HarnessSSHTransportFactory: Sendable {
  func makeSSHTransport() async throws -> any SSHTransport
}

public protocol HarnessPacketEndpointFactory: Sendable {
  func makePacketFlow() async throws -> any PacketFlow
}

public enum HarnessUnavailableDependencyError: Error, Equatable {
  case sshTransport
  case packetEndpoint
}

public struct UnavailableHarnessSSHTransportFactory: HarnessSSHTransportFactory {
  public init() {}

  public func makeSSHTransport() async throws -> any SSHTransport {
    throw HarnessUnavailableDependencyError.sshTransport
  }
}

public enum LibSSH2HarnessRegistration {
  public static let capabilities = LibSSH2TransportFactory().capabilities
}

/// Registers the same candidate factory used by the macOS provider while
/// retaining all candidate-neutral dependencies as harness injection points.
public struct LibSSH2HarnessSSHTransportFactory: HarnessSSHTransportFactory {
  public let capabilities: SSHAdapterCapabilities
  private let factory: LibSSH2TransportFactory
  private let lane: SSHLaneIdentity
  private let dependencies: SSHTransportDependencies

  public init(
    lane: SSHLaneIdentity,
    dependencies: SSHTransportDependencies,
    maximumTransportBufferBytes: Int = 256 * 1_024
  ) {
    let factory = LibSSH2TransportFactory(
      maximumTransportBufferBytes: maximumTransportBufferBytes
    )
    self.factory = factory
    capabilities = factory.capabilities
    self.lane = lane
    self.dependencies = dependencies
  }

  public func makeSSHTransport() async throws -> any SSHTransport {
    try await factory.makeTransport(lane: lane, dependencies: dependencies)
  }
}

public struct UnavailableHarnessPacketEndpointFactory: HarnessPacketEndpointFactory {
  public init() {}

  public func makePacketFlow() async throws -> any PacketFlow {
    throw HarnessUnavailableDependencyError.packetEndpoint
  }
}

public struct HarnessCommandDependencies: Sendable {
  public let runtime: TunnelRuntimeDependencies
  public let sshTransports: any HarnessSSHTransportFactory
  public let packetEndpoints: any HarnessPacketEndpointFactory
  public let faultPolicy: any HarnessFaultPolicy

  public init(
    runtime: TunnelRuntimeDependencies,
    sshTransports: any HarnessSSHTransportFactory,
    packetEndpoints: any HarnessPacketEndpointFactory,
    faultPolicy: any HarnessFaultPolicy
  ) {
    self.runtime = runtime
    self.sshTransports = sshTransports
    self.packetEndpoints = packetEndpoints
    self.faultPolicy = faultPolicy
  }
}

/// Builds the same `TunnelRuntimeContext` consumed by packet-tunnel providers.
public struct HarnessCoreComposition: Sendable {
  public let dependencies: HarnessCommandDependencies

  public init(dependencies: HarnessCommandDependencies) {
    self.dependencies = dependencies
  }

  public func makeRuntime(
    configuration: TunnelConfiguration,
    factory: any TunnelRuntimeFactory
  ) async throws -> any TunnelRuntime {
    try await dependencies.faultPolicy.evaluate(.makePacketEndpoint)
    let packetFlow = try await dependencies.packetEndpoints.makePacketFlow()
    return try await factory.makeRuntime(
      context: TunnelRuntimeContext(
        configuration: configuration,
        packetFlow: packetFlow,
        dependencies: dependencies.runtime
      )
    )
  }

  public func makeSSHTransport() async throws -> any SSHTransport {
    try await dependencies.faultPolicy.evaluate(.makeSSHTransport)
    return try await dependencies.sshTransports.makeSSHTransport()
  }
}

public struct HarnessCommandContext: Sendable {
  public let configuration: HarnessConfigurationDocument
  public let dependencies: HarnessCommandDependencies
  public let resources: HarnessResourceScope

  public init(
    configuration: HarnessConfigurationDocument,
    dependencies: HarnessCommandDependencies,
    resources: HarnessResourceScope
  ) {
    self.configuration = configuration
    self.dependencies = dependencies
    self.resources = resources
  }
}

public protocol HarnessCommand: Sendable {
  var name: String { get }
  func run(context: HarnessCommandContext) async throws
}

public enum HarnessCommandRegistryError: Error, Equatable {
  case duplicateCommand(String)
  case invalidCommandName(String)
}

public struct HarnessCommandRegistry: Sendable {
  private let commands: [String: any HarnessCommand]

  public init(commands: [any HarnessCommand]) throws {
    var registered: [String: any HarnessCommand] = [:]
    for command in commands {
      guard Self.isValid(name: command.name) else {
        throw HarnessCommandRegistryError.invalidCommandName(command.name)
      }
      guard registered[command.name] == nil else {
        throw HarnessCommandRegistryError.duplicateCommand(command.name)
      }
      registered[command.name] = command
    }
    self.commands = registered
  }

  public var names: [String] {
    commands.keys.sorted()
  }

  public func command(named name: String) -> (any HarnessCommand)? {
    commands[name]
  }

  private static func isValid(name: String) -> Bool {
    guard let first = name.first, first.isLowercase else {
      return false
    }
    return name.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }
  }
}
