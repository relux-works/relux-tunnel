import Foundation

public enum TunnelLifecycleState: String, Codable, Sendable {
  case disconnected
  case connecting
  case connectedFull
  case connectedDegraded
  case reasserting
  case failed
  case disconnecting
}

public enum ProviderStopReason: Equatable, Sendable {
  case userInitiated
  case system
  case startupFailure
  case providerFailure
  case platform(code: Int)
}

public enum ProviderLifecyclePhase: Equatable, Sendable {
  case idle
  case starting
  case running
  case stopping
}

public struct TunnelRuntimeContext: Sendable {
  public let configuration: TunnelConfiguration
  public let packetFlow: any PacketFlow
  public let dependencies: TunnelRuntimeDependencies

  public init(
    configuration: TunnelConfiguration,
    packetFlow: any PacketFlow,
    dependencies: TunnelRuntimeDependencies
  ) {
    self.configuration = configuration
    self.packetFlow = packetFlow
    self.dependencies = dependencies
  }
}

/// Shared runtime generation owned by the provider, not the containing app.
public protocol TunnelRuntime: AnyObject, Sendable {
  func start() async throws
  func stop(reason: ProviderStopReason) async
  func lifecycleState() async -> TunnelLifecycleState
}

public protocol TunnelRuntimeFactory: Sendable {
  func makeRuntime(context: TunnelRuntimeContext) async throws -> any TunnelRuntime
}

/// Provider-facing lifecycle and version-message seam used by both platforms.
public protocol TunnelProviderLifecycle: Sendable {
  func start(configuration: TunnelConfiguration) async throws
  func stop(reason: ProviderStopReason) async
  func handleAppMessage(_ message: Data) async throws -> Data
  func lifecyclePhase() async -> ProviderLifecyclePhase
}

public enum ProviderAdapterError: Error, Equatable {
  case lifecycleBusy(ProviderLifecyclePhase)
}

public enum ProviderMessageError: Error, Equatable {
  case unsupportedProtocolVersion(UInt16)
  case unsupportedKind(String)
}

public struct ProviderVersionRequest: Codable, Equatable, Sendable {
  public let protocolVersion: UInt16
  public let kind: String

  public init(protocolVersion: UInt16 = ProviderMessageCodec.currentVersion) {
    self.protocolVersion = protocolVersion
    kind = ProviderMessageCodec.versionKind
  }
}

public struct ProviderVersionResponse: Codable, Equatable, Sendable {
  public let protocolVersion: UInt16
  public let kind: String

  public init(protocolVersion: UInt16) {
    self.protocolVersion = protocolVersion
    kind = ProviderMessageCodec.versionKind
  }
}

/// Minimal M0 app-message codec. Additional message semantics belong to later specs.
public enum ProviderMessageCodec {
  public static let currentVersion: UInt16 = 1
  public static let versionKind = "version"

  public static func encodeVersionRequest(
    protocolVersion: UInt16 = currentVersion
  ) throws -> Data {
    try encoder().encode(ProviderVersionRequest(protocolVersion: protocolVersion))
  }

  public static func decodeVersionResponse(_ data: Data) throws -> ProviderVersionResponse {
    try JSONDecoder().decode(ProviderVersionResponse.self, from: data)
  }

  static func response(to data: Data) throws -> Data {
    let request = try JSONDecoder().decode(ProviderVersionRequest.self, from: data)
    guard request.kind == versionKind else {
      throw ProviderMessageError.unsupportedKind(request.kind)
    }
    guard request.protocolVersion == currentVersion else {
      throw ProviderMessageError.unsupportedProtocolVersion(request.protocolVersion)
    }
    return try encoder().encode(ProviderVersionResponse(protocolVersion: currentVersion))
  }

  private static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }
}

/// Shared, generation-safe lifecycle implementation behind both provider roots.
public actor TunnelProviderAdapter: TunnelProviderLifecycle {
  private let packetFlow: any PacketFlow
  private let runtimeFactory: any TunnelRuntimeFactory
  private let dependencies: TunnelRuntimeDependencies

  private var activeRuntime: (any TunnelRuntime)?
  private var generation: UInt64 = 0
  private var phase: ProviderLifecyclePhase = .idle

  public init(
    packetFlow: any PacketFlow,
    runtimeFactory: any TunnelRuntimeFactory,
    dependencies: TunnelRuntimeDependencies
  ) {
    self.packetFlow = packetFlow
    self.runtimeFactory = runtimeFactory
    self.dependencies = dependencies
  }

  public func start(configuration: TunnelConfiguration) async throws {
    guard phase == .idle else {
      throw ProviderAdapterError.lifecycleBusy(phase)
    }

    phase = .starting
    generation &+= 1
    let startGeneration = generation

    do {
      let runtime = try await runtimeFactory.makeRuntime(
        context: TunnelRuntimeContext(
          configuration: configuration,
          packetFlow: packetFlow,
          dependencies: dependencies
        )
      )
      activeRuntime = runtime
      try await runtime.start()

      guard generation == startGeneration, activeRuntime === runtime else {
        throw CancellationError()
      }
      phase = .running
    } catch {
      if generation == startGeneration {
        let runtime = activeRuntime
        activeRuntime = nil
        phase = .idle
        await runtime?.stop(reason: .startupFailure)
      }
      throw error
    }
  }

  public func stop(reason: ProviderStopReason) async {
    generation &+= 1
    let stopGeneration = generation
    let runtime = activeRuntime
    activeRuntime = nil
    phase = .stopping

    await runtime?.stop(reason: reason)

    if generation == stopGeneration {
      phase = .idle
    }
  }

  public func handleAppMessage(_ message: Data) async throws -> Data {
    try ProviderMessageCodec.response(to: message)
  }

  public func lifecyclePhase() async -> ProviderLifecyclePhase {
    phase
  }
}
