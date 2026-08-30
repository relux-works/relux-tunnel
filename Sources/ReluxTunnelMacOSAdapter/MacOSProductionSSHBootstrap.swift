import Foundation
import ReluxTunnelCore

/// Immutable profile lookup captured by the provider before runtime startup.
/// Live provider objects and callbacks never cross this boundary.
public protocol MacOSProductionSSHProfileSource: Sendable {
  func loadProfile(
    for configuration: RuntimeConfigurationSnapshot
  ) async throws -> SSHProfileSnapshotV1
}

/// Builds non-secret connection policy from an immutable validated profile.
/// The production root separately owns transport, host policy, and credentials.
public protocol MacOSProductionSSHConnectionConfigurationBuilding: Sendable {
  func makeConnectionConfiguration(
    profile: SSHProfileSnapshotV1,
    runtimeConfiguration: RuntimeConfigurationSnapshot,
    capabilities: SSHAdapterCapabilities
  ) throws -> SSHConnectionConfiguration
}

/// Candidate-neutral platform services required by the selected SSH adapter.
/// Security-critical host-policy and credential dependencies are deliberately
/// absent: the production root supplies those itself.
public struct MacOSProductionSSHRuntimeServices: Sendable {
  public let profileSource: any MacOSProductionSSHProfileSource
  public let configurationBuilder: any MacOSProductionSSHConnectionConfigurationBuilding
  public let resolver: any SSHNetworkResolver
  public let connector: any SSHTCPConnector
  public let logger: any SSHTransportLogger
  public let observer: any SSHTransportObserver
  public let metrics: any SSHTransportMetricsSink
  public let identityGenerator: any SSHIdentityGenerator

  public init(
    profileSource: any MacOSProductionSSHProfileSource,
    configurationBuilder: any MacOSProductionSSHConnectionConfigurationBuilding,
    resolver: any SSHNetworkResolver,
    connector: any SSHTCPConnector,
    logger: any SSHTransportLogger,
    observer: any SSHTransportObserver,
    metrics: any SSHTransportMetricsSink,
    identityGenerator: any SSHIdentityGenerator
  ) {
    self.profileSource = profileSource
    self.configurationBuilder = configurationBuilder
    self.resolver = resolver
    self.connector = connector
    self.logger = logger
    self.observer = observer
    self.metrics = metrics
    self.identityGenerator = identityGenerator
  }
}

struct MacOSSelectedSSHDependencies: Sendable {
  let transportFactory: any SSHTransportFactory
  let credentialProvider: any SSHCredentialProvider
  let makeHostKeyPolicy: @Sendable (SSHProfileSnapshotV1) throws -> any SSHHostKeyPolicy
  let mapCredentialError:
    @Sendable (MacOSCredentialResolverError, UInt64) -> SSHBootstrapProviderError
}

struct MacOSProductionSSHBootstrap: SSHBootstrap {
  let selected: MacOSSelectedSSHDependencies
  let services: MacOSProductionSSHRuntimeServices
  let environment: TunnelRuntimeDependencies
  let channelPolicy: SSHChannelPolicy

  func authenticate(
    configuration: RuntimeConfigurationSnapshot,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) async throws -> any SSHBootstrapSession {
    let profile: SSHProfileSnapshotV1
    do {
      profile = try await services.profileSource.loadProfile(for: configuration)
      try Self.validate(profile: profile, runtimeConfiguration: configuration)
    } catch let error as SSHProfileSnapshotLoaderError {
      throw SSHBootstrapErrorMapper.profile(
        error,
        configurationGeneration: configuration.configurationGeneration
      )
    } catch let error as SSHBootstrapProviderError {
      throw error
    } catch {
      throw SSHBootstrapErrorMapper.profile(
        .profileCorrupt,
        configurationGeneration: configuration.configurationGeneration
      )
    }

    let hostPolicy: any SSHHostKeyPolicy
    let connectionConfiguration: SSHConnectionConfiguration
    do {
      hostPolicy = try selected.makeHostKeyPolicy(profile)
      connectionConfiguration = try services.configurationBuilder.makeConnectionConfiguration(
        profile: profile,
        runtimeConfiguration: configuration,
        capabilities: selected.transportFactory.capabilities
      )
      try Self.validate(
        connectionConfiguration: connectionConfiguration,
        profile: profile,
        runtimeConfiguration: configuration,
        capabilities: selected.transportFactory.capabilities
      )
    } catch let error as SSHBootstrapProviderError {
      throw error
    } catch {
      throw SSHBootstrapErrorMapper.profile(
        .profileInvalidField(.providerConfiguration),
        configurationGeneration: configuration.configurationGeneration
      )
    }

    let lane = services.identityGenerator.makeLaneIdentity()
    let dependencies = SSHTransportDependencies(
      resolver: services.resolver,
      connector: services.connector,
      hostKeyPolicy: hostPolicy,
      credentialProvider: selected.credentialProvider,
      clock: environment.clock,
      cancellation: environment.cancellation,
      logger: services.logger,
      observer: services.observer,
      metrics: services.metrics,
      identityGenerator: services.identityGenerator
    )

    let transport: any SSHTransport
    do {
      transport = try await selected.transportFactory.makeTransport(
        lane: lane,
        dependencies: dependencies
      )
    } catch {
      throw Self.map(
        error,
        configurationGeneration: configuration.configurationGeneration,
        selected: selected
      )
    }

    do {
      _ = try await transport.connect(configuration: connectionConfiguration)
      return MacOSProductionSSHBootstrapSession(
        transport: transport,
        connectedEndpoint: connectionConfiguration.endpoint,
        channelPolicy: channelPolicy,
        runtimeGeneration: runtimeGeneration,
        healthSink: healthSink
      )
    } catch {
      await transport.close()
      throw Self.map(
        error,
        configurationGeneration: configuration.configurationGeneration,
        selected: selected
      )
    }
  }

  private static func validate(
    profile: SSHProfileSnapshotV1,
    runtimeConfiguration: RuntimeConfigurationSnapshot
  ) throws {
    guard profile.configurationGeneration == runtimeConfiguration.configurationGeneration else {
      throw SSHProfileSnapshotLoaderError.profileGenerationMismatch
    }
    guard profile.profileID == runtimeConfiguration.profileIdentifier else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.profileID)
    }
    guard profile.credential.reference == runtimeConfiguration.credentialReference else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.credentialReference)
    }
  }

  private static func validate(
    connectionConfiguration: SSHConnectionConfiguration,
    profile: SSHProfileSnapshotV1,
    runtimeConfiguration: RuntimeConfigurationSnapshot,
    capabilities: SSHAdapterCapabilities
  ) throws {
    let algorithms = connectionConfiguration.algorithms
    guard
      connectionConfiguration.canonicalHostname == profile.canonicalHost.value,
      connectionConfiguration.endpoint
        == TunnelEndpoint(host: profile.canonicalHost.value, port: profile.port),
      connectionConfiguration.username == profile.account,
      connectionConfiguration.profileReference.profileIdentifier
        == runtimeConfiguration.profileIdentifier,
      connectionConfiguration.credentialReference.rawValue
        == profile.credential.reference.rawValue.uuidString.lowercased(),
      connectionConfiguration.credentialGeneration == profile.credential.generation,
      connectionConfiguration.trustRecordReference?.rawValue
        == runtimeConfiguration.trustReference.rawValue.uuidString.lowercased(),
      Set(algorithms.keyExchange).isSubset(of: capabilities.keyExchangeAlgorithms),
      Set(algorithms.hostKey).isSubset(of: capabilities.hostKeyAlgorithms),
      Set(algorithms.cipher).isSubset(of: capabilities.cipherAlgorithms),
      Set(algorithms.mac).isSubset(of: capabilities.macAlgorithms),
      Set(algorithms.hostKey)
        == Set(profile.hostPolicy.allowedAlgorithms.map(\.rawValue))
    else {
      throw SSHProfileSnapshotLoaderError.profileInvalidField(.providerConfiguration)
    }
  }

  private static func map(
    _ error: any Error,
    configurationGeneration: UInt64,
    selected: MacOSSelectedSSHDependencies
  ) -> SSHBootstrapProviderError {
    if let error = error as? SSHBootstrapProviderError {
      return error
    }
    if let error = error as? MacOSCredentialResolverError {
      return selected.mapCredentialError(error, configurationGeneration)
    }
    if let error = error as? SSHTransportError {
      return SSHBootstrapErrorMapper.transport(
        error,
        configurationGeneration: configurationGeneration
      )
    }
    return SSHBootstrapErrorMapper.transport(
      error,
      stage: .algorithmNegotiation,
      configurationGeneration: configurationGeneration
    )
  }
}

private actor MacOSProductionSSHBootstrapSession: M1SSHChannelSession {
  nonisolated let connectedEndpoint: TunnelEndpoint

  private let transport: any SSHTransport
  private let channelPolicy: SSHChannelPolicy
  private let runtimeGeneration: UInt64
  private weak var healthSink: (any TunnelRuntimeHealthEventSink)?
  private var isClosed = false

  init(
    transport: any SSHTransport,
    connectedEndpoint: TunnelEndpoint,
    channelPolicy: SSHChannelPolicy,
    runtimeGeneration: UInt64,
    healthSink: any TunnelRuntimeHealthEventSink
  ) {
    self.transport = transport
    self.connectedEndpoint = connectedEndpoint
    self.channelPolicy = channelPolicy
    self.runtimeGeneration = runtimeGeneration
    self.healthSink = healthSink
  }

  func openTCP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint
  ) async throws -> any SSHByteChannel {
    guard !isClosed else {
      throw SSHBootstrapErrorMapper.sessionClose(
        .transportFailure,
        configurationGeneration: 0
      )
    }
    return try await transport.openDirectTCPIP(
      destination: destination,
      originator: originator,
      policy: channelPolicy
    )
  }

  func close() async {
    guard !isClosed else { return }
    isClosed = true
    await transport.close()
    await healthSink?.receive(
      TunnelRuntimeHealthEvent(
        runtimeGeneration: runtimeGeneration,
        component: .ssh,
        health: .unhealthy
      )
    )
  }

  func health() async -> TunnelRuntimeComponentHealth {
    isClosed ? .unhealthy : .healthy
  }
}
