import Foundation

public enum TunnelLifecycleState: String, Codable, Equatable, Sendable {
  case disconnected
  case connecting
  case connectedFull
  case connectedDegraded
  case reasserting
  case failed
  case disconnecting
  case unknown

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    self = TunnelLifecycleState(rawValue: value) ?? .unknown
  }
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
  case invalidPayload(RuntimeProtocolErrorCode)
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
  public static let currentVersion = RuntimeMessageProtocol.currentProtocolVersion
  public static let versionKind = "version"

  public static func encodeVersionRequest(
    protocolVersion: UInt16 = currentVersion
  ) throws -> Data {
    try RuntimeJSONCodec.encode(
      ProviderVersionRequest(protocolVersion: protocolVersion),
      maximumBytes: RuntimeMessageSizeLimit.legacyVersion
    )
  }

  public static func decodeVersionResponse(_ data: Data) throws -> ProviderVersionResponse {
    try validateLegacyObject(data)
    let response: ProviderVersionResponse
    do {
      response = try JSONDecoder().decode(ProviderVersionResponse.self, from: data)
    } catch {
      throw ProviderMessageError.invalidPayload(.corruptPayload)
    }
    guard response.kind == versionKind else {
      throw ProviderMessageError.unsupportedKind(response.kind)
    }
    guard response.protocolVersion == currentVersion else {
      throw ProviderMessageError.unsupportedProtocolVersion(response.protocolVersion)
    }
    return response
  }

  static func response(to data: Data) throws -> Data {
    try validateLegacyObject(data)
    let request: ProviderVersionRequest
    do {
      request = try JSONDecoder().decode(ProviderVersionRequest.self, from: data)
    } catch {
      throw ProviderMessageError.invalidPayload(.corruptPayload)
    }
    guard request.kind == versionKind else {
      throw ProviderMessageError.unsupportedKind(request.kind)
    }
    guard request.protocolVersion == currentVersion else {
      throw ProviderMessageError.unsupportedProtocolVersion(request.protocolVersion)
    }
    return try RuntimeJSONCodec.encode(
      ProviderVersionResponse(protocolVersion: currentVersion),
      maximumBytes: RuntimeMessageSizeLimit.legacyVersion
    )
  }

  private static func validateLegacyObject(_ data: Data) throws {
    do {
      let keys = try StrictJSONValidator.validate(
        data,
        maximumBytes: RuntimeMessageSizeLimit.legacyVersion
      )
      guard keys == ["kind", "protocolVersion"] else {
        throw ProviderMessageError.invalidPayload(.corruptPayload)
      }
    } catch let error as ProviderMessageError {
      throw error
    } catch let error as RuntimeMessageCodecError {
      throw ProviderMessageError.invalidPayload(error.protocolErrorCode)
    } catch {
      throw ProviderMessageError.invalidPayload(.corruptPayload)
    }
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
