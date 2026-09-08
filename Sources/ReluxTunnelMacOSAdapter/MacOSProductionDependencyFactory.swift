import CoreFoundation
import CryptoKit
import Foundation
import ReluxTunnelCore
import ReluxTunnelLibSSH2Adapter
import ReluxTunnelNativeAdapter

public enum MacOSProductionBindingError: Error, Equatable, Sendable {
  case manifestAbsent
  case manifestUnreadable
  case digestMismatch
  case malformedManifest
  case incompatibleSchema
  case compositionNotPermitted
  case staleOrSupersededBinding(String)
  case resourceDigestMismatch(String)
  case pinMismatch(String)
  case mandatoryCapabilityMissing(String)
  case incompatibleBinding(String)
}

public struct MacOSAcceptedM0Bindings: Sendable {
  public static let manifestSHA256 =
    "40333862b46b7af04cdd966ade91e8c9cc917e573c6601e26e7fa956d11ae161"

  public let packetBridgeConfiguration: PacketBridgeConfiguration
  public let internalSOCKSConfiguration: InternalSOCKSConfiguration
  public let sshTransportBufferBytes: Int
  public let sshInitialReceiveWindowBytes: Int
  public let sshReadBufferBytes: Int
  public let sshQueuedWriteBytes: Int
  public let sshWriteCallBytes: Int

  fileprivate init(
    packetBridgeConfiguration: PacketBridgeConfiguration,
    internalSOCKSConfiguration: InternalSOCKSConfiguration,
    sshTransportBufferBytes: Int,
    sshInitialReceiveWindowBytes: Int,
    sshReadBufferBytes: Int,
    sshQueuedWriteBytes: Int,
    sshWriteCallBytes: Int
  ) {
    self.packetBridgeConfiguration = packetBridgeConfiguration
    self.internalSOCKSConfiguration = internalSOCKSConfiguration
    self.sshTransportBufferBytes = sshTransportBufferBytes
    self.sshInitialReceiveWindowBytes = sshInitialReceiveWindowBytes
    self.sshReadBufferBytes = sshReadBufferBytes
    self.sshQueuedWriteBytes = sshQueuedWriteBytes
    self.sshWriteCallBytes = sshWriteCallBytes
  }
}

/// Runtime gate for the sole accepted M0 binding artifact.
///
/// Production always verifies the immutable artifact digest before decoding.
/// Semantic validation is intentionally retained as a second fail-closed layer
/// so a future digest update cannot silently authorize a stale or incomplete
/// binding shape.
public enum MacOSProductionBindingManifestValidator {
  public static func validate(
    _ data: Data,
    diagnosticsWindow: Duration
  ) throws -> MacOSAcceptedM0Bindings {
    try validate(
      data,
      diagnosticsWindow: diagnosticsWindow,
      expectedDigest: MacOSAcceptedM0Bindings.manifestSHA256
    )
  }

  static func validate(
    _ data: Data,
    diagnosticsWindow: Duration,
    expectedDigest: String?
  ) throws -> MacOSAcceptedM0Bindings {
    guard !data.isEmpty else { throw MacOSProductionBindingError.manifestAbsent }
    if let expectedDigest, sha256(data) != expectedDigest {
      throw MacOSProductionBindingError.digestMismatch
    }
    guard diagnosticsWindow > .zero else {
      throw MacOSProductionBindingError.incompatibleBinding("diagnosticsWindow")
    }

    let root: [String: Any]
    do {
      guard
        let value = try JSONSerialization.jsonObject(
          with: data,
          options: [.fragmentsAllowed]
        ) as? [String: Any]
      else {
        throw MacOSProductionBindingError.malformedManifest
      }
      root = value
    } catch let error as MacOSProductionBindingError {
      throw error
    } catch {
      throw MacOSProductionBindingError.malformedManifest
    }

    guard int(root["schemaVersion"]) == 1,
      string(root["schemaIdentifier"]) == "relux.m0-production-bindings/1",
      string(root["taskId"]) == "TASK-260720-1qhxqa"
    else {
      throw MacOSProductionBindingError.incompatibleSchema
    }
    guard bool(root["productionCompositionPermitted"]) == true else {
      throw MacOSProductionBindingError.compositionNotPermitted
    }

    let runtime = try object(root["runtimeContract"])
    try validateEvidence(
      runtime,
      label: "runtimeContract",
      taskID: "TASK-260715-30zng6",
      outcomeDigest: "c13bbb54a455da89f3e66121c81532b298eab73fac30b6d14d2e2df43fff8851",
      reviewDigest: "7a64ad098efd8cff52e0c6d144763b29e4d4008aab8e0967ce805c6134b0b756"
    )
    guard string(runtime["schema"]) == "m1-runtime-contract/1" else {
      throw MacOSProductionBindingError.incompatibleSchema
    }

    let inputs = try array(root["acceptedInputs"])
    guard inputs.count == 3 else {
      throw MacOSProductionBindingError.incompatibleBinding("acceptedInputs")
    }
    var byKind: [String: [String: Any]] = [:]
    for rawInput in inputs {
      let input = try object(rawInput)
      guard let kind = string(input["kind"]), byKind[kind] == nil else {
        throw MacOSProductionBindingError.incompatibleBinding("acceptedInputs")
      }
      byKind[kind] = input
    }

    let graph = try requiredInput(
      byKind,
      kind: "generatedProjectArchitecture",
      taskID: "TASK-260715-nphtib",
      outcomeDigest: "63faf7a35b1c3554bbe5c23def6edddb9bc8454d40bfc1fb94071e1461f23ddd",
      reviewDigest: "d9278fb1baec644d27c2fbd4a263758dee8f583b796f9c8ae7cc5e2e80985679"
    )
    try requireCapability(
      graph,
      "static HEV and libssh2 linkage with system-only dynamic dependencies"
    )
    let graphPins = try object(graph["sourceOrBinaryPins"])
    try requirePin(
      graphPins,
      "acceptedRepositoryRevision",
      "069e23bdbbef71be194762d275b003a40a6cfc72"
    )
    try requirePin(
      graphPins,
      "acceptedGraphRevision",
      "7dc73ac6e7325f86a4a178a0558619f0fc9d1490"
    )

    let packet = try requiredInput(
      byKind,
      kind: "packetBridgeAndHEV",
      taskID: "TASK-260715-2jatnd",
      outcomeDigest: "f2dc587541386cdc5eb7e10328adda21b8bbba3af32d5c722e62616a2abca173",
      reviewDigest: "73de6f96adadbd4b9469e26d760c3edbe6bd56120b97ab4f3d752812d3df8246"
    )
    try requireCapability(
      packet,
      "public PacketFlowAdapterBoundary and PacketFlowBridge.start call path"
    )
    try requireCapability(
      packet,
      "single process HEV lease, join-before-close lifecycle, exact traffic accounting, and zero owned-resource cleanup"
    )
    let packetPins = try object(packet["sourceOrBinaryPins"])
    try requirePin(
      packetPins,
      "hevSocks5Tunnel",
      "ad7600497931205105b08367bd1b450048157e40"
    )
    try requirePin(
      packetPins,
      "hevSocks5Core",
      "c234519072ff5b928b90b304da9a666bcb440455"
    )
    try requirePin(packetPins, "binaryTarget", "HevSocks5Tunnel")
    let packetBindings = try object(packet["bindings"])
    guard
      let mtuBytes = int(packetBindings["mtuBytes"]), mtuBytes == 1_500,
      let sendBufferBytes = int(packetBindings["socketSendBufferRequestedBytes"]),
      sendBufferBytes == 32_768,
      let receiveBufferBytes = int(packetBindings["socketReceiveBufferRequestedBytes"]),
      receiveBufferBytes == 32_768,
      let pumpPacketBudget = int(packetBindings["pumpPacketBudget"]), pumpPacketBudget == 64,
      let pumpTimeBudgetMilliseconds = int(packetBindings["pumpTimeBudgetMilliseconds"]),
      pumpTimeBudgetMilliseconds == 5,
      string(packetBindings["hevSocks5UDPMode"]) == "tcp",
      let taskStackBytes = int(packetBindings["hevTaskStackBytes"]),
      taskStackBytes == 24_576,
      let tcpBufferBytes = int(packetBindings["hevTCPBufferBytesPerSession"]),
      tcpBufferBytes == 4_096,
      let udpCopyBufferCount = int(packetBindings["hevUDPCopyBufferCount"]),
      udpCopyBufferCount == 2,
      let maximumSessionCount = int(packetBindings["hevMaximumSessionCount"]),
      maximumSessionCount == 500
    else {
      throw MacOSProductionBindingError.incompatibleBinding("packetBridgeAndHEV")
    }

    let ssh = try requiredInput(
      byKind,
      kind: "sshEngine",
      taskID: "TASK-260715-1gjxer",
      outcomeDigest: "f1d2369a694c7a6f6642cff4324b46a6727b7a6aef3d65a9cf13ee8821ea2282",
      reviewDigest: "3583369777a0d897ef2a156ddddeea92cd15b5c0b3b290582015667a37044a31"
    )
    try requireCapability(
      ssh,
      "host-key policy receives raw evidence before credential lookup and fails closed"
    )
    try requireCapability(
      ssh,
      "real relux-server compatibility through the selected LibSSH2TransportFactory"
    )
    let sshPins = try object(ssh["sourceOrBinaryPins"])
    try requirePin(sshPins, "selectedAdapter", "ReluxTunnelLibSSH2Adapter")
    try requirePin(sshPins, "binaryTarget", "ReluxLibSSH2")
    try requirePin(
      sshPins,
      "libssh2Commit",
      "a34302491c164d53c900fec9b3cbb050ecebe719"
    )
    try requirePin(
      sshPins,
      "libssh2ArchiveSha256",
      "744ba3e9a8e7a877038e94a74459340052a105ad599605a5b6d0d6bc5ec2c87c"
    )
    try requirePin(sshPins, "opensslTag", "openssl-3.5.7")
    try requirePin(
      sshPins,
      "patchSha256",
      "79e2464813e3c3add9486b2fb8c9e50004b48b246bbc771b5dd1675a152fa30e"
    )
    let sshBindings = try object(ssh["bindings"])
    let receiveWindow = try object(sshBindings["initialReceiveWindowBytes"])
    guard
      let transportBufferBytes = int(sshBindings["transportBufferBytes"]),
      transportBufferBytes == 65_536,
      let readBufferBytes = int(sshBindings["readBufferBytes"]),
      readBufferBytes == 16_384,
      let queuedWriteBytes = int(sshBindings["queuedWriteBytes"]),
      queuedWriteBytes == 32_768,
      let writeCallBytes = int(sshBindings["writeCallBytes"]),
      writeCallBytes == 8_192,
      int(sshBindings["pendingOperationLimit"]) == 64,
      let initialReceiveWindowBytes = int(receiveWindow["acceptedM0Value"]),
      initialReceiveWindowBytes == 65_536
    else {
      throw MacOSProductionBindingError.incompatibleBinding("sshEngine")
    }

    let checks = try array(root["compatibilityChecks"]).map(object)
    let requiredChecks: Set<String> = [
      "M1-CONTRACT-SCHEMA", "M1-GRAPH-DIRECTION", "M1-CANDIDATE-NEUTRAL-CORE",
      "M1-PACKET-ACTIVATION-ORDER", "M1-SSH-BEFORE-ROUTES", "M1-BOUND-VALUES",
      "M1-DEFERRED-NOT-PROMOTED", "M1-SOLE-BINDING-SOURCE",
    ]
    let passingChecks = Set(
      checks.compactMap { check -> String? in
        guard string(check["result"]) == "pass" else { return nil }
        return string(check["id"])
      }
    )
    guard passingChecks == requiredChecks else {
      throw MacOSProductionBindingError.mandatoryCapabilityMissing(
        "compatibilityChecks"
      )
    }

    let consumer = try object(root["consumerContract"])
    guard
      string(consumer["taskId"]) == "TASK-260715-3ejhyy",
      string(consumer["soleM0BindingSource"])
        == "Configuration/TASK-260720-1qhxqa_m0-production-bindings-v1.json",
      string(consumer["productionCallSite"])?.contains("before construction") == true,
      string(consumer["failureBehavior"])?.contains("do not construct") == true
    else {
      throw MacOSProductionBindingError.incompatibleBinding("consumerContract")
    }

    return MacOSAcceptedM0Bindings(
      packetBridgeConfiguration: PacketBridgeConfiguration(
        mtu: mtuBytes,
        sendBufferBytes: sendBufferBytes,
        receiveBufferBytes: receiveBufferBytes,
        maximumWorkCount: pumpPacketBudget,
        workTimeBudget: .milliseconds(pumpTimeBudgetMilliseconds),
        diagnosticsWindow: diagnosticsWindow
      ),
      internalSOCKSConfiguration: InternalSOCKSConfiguration(
        mtuBytes: mtuBytes,
        taskStackSizeBytes: taskStackBytes,
        tcpBufferSizeBytes: tcpBufferBytes,
        udpCopyBufferCount: udpCopyBufferCount,
        maximumSessionCount: maximumSessionCount
      ),
      sshTransportBufferBytes: transportBufferBytes,
      sshInitialReceiveWindowBytes: initialReceiveWindowBytes,
      sshReadBufferBytes: readBufferBytes,
      sshQueuedWriteBytes: queuedWriteBytes,
      sshWriteCallBytes: writeCallBytes
    )
  }

  private static func validateEvidence(
    _ evidence: [String: Any],
    label: String,
    taskID: String,
    outcomeDigest: String,
    reviewDigest: String
  ) throws {
    guard string(evidence["taskId"]) == taskID else {
      throw MacOSProductionBindingError.incompatibleBinding(label)
    }
    if let digest = string(evidence["sha256"]) {
      guard digest == outcomeDigest else {
        throw MacOSProductionBindingError.resourceDigestMismatch(label)
      }
    } else {
      let outcome = try object(evidence["acceptedOutcome"])
      guard string(outcome["sha256"]) == outcomeDigest else {
        throw MacOSProductionBindingError.resourceDigestMismatch(label)
      }
    }
    let verdict = try object(evidence["reviewerVerdict"])
    guard string(verdict["sha256"]) == reviewDigest else {
      throw MacOSProductionBindingError.resourceDigestMismatch(label)
    }
    guard string(verdict["verdict"]) == "accepted" else {
      throw MacOSProductionBindingError.staleOrSupersededBinding(label)
    }
    let supersession = try object(evidence["supersession"])
    guard string(supersession["status"]) == "current",
      supersession["supersededBy"] is NSNull
    else {
      throw MacOSProductionBindingError.staleOrSupersededBinding(label)
    }
  }

  private static func requiredInput(
    _ inputs: [String: [String: Any]],
    kind: String,
    taskID: String,
    outcomeDigest: String,
    reviewDigest: String
  ) throws -> [String: Any] {
    guard let input = inputs[kind] else {
      throw MacOSProductionBindingError.incompatibleBinding(kind)
    }
    try validateEvidence(
      input,
      label: kind,
      taskID: taskID,
      outcomeDigest: outcomeDigest,
      reviewDigest: reviewDigest
    )
    return input
  }

  private static func requireCapability(
    _ input: [String: Any],
    _ capability: String
  ) throws {
    let capabilities = try array(input["requiredCapabilities"])
    guard capabilities.contains(where: { string($0) == capability }) else {
      throw MacOSProductionBindingError.mandatoryCapabilityMissing(capability)
    }
  }

  private static func requirePin(
    _ pins: [String: Any],
    _ name: String,
    _ value: String
  ) throws {
    guard string(pins[name]) == value else {
      throw MacOSProductionBindingError.pinMismatch(name)
    }
  }

  private static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func object(_ value: Any?) throws -> [String: Any] {
    guard let value = value as? [String: Any] else {
      throw MacOSProductionBindingError.malformedManifest
    }
    return value
  }

  private static func array(_ value: Any?) throws -> [Any] {
    guard let value = value as? [Any] else {
      throw MacOSProductionBindingError.malformedManifest
    }
    return value
  }

  private static func string(_ value: Any?) -> String? { value as? String }
  private static func bool(_ value: Any?) -> Bool? {
    guard let number = value as? NSNumber,
      CFGetTypeID(number) == CFBooleanGetTypeID()
    else { return nil }
    return number.boolValue
  }
  private static func int(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID()
    else { return nil }
    let decimal = number.decimalValue
    var source = decimal
    var integral = Decimal()
    NSDecimalRound(&integral, &source, 0, .plain)
    guard integral == decimal else { return nil }
    return Int(NSDecimalNumber(decimal: decimal).stringValue)
  }
}

public struct MacOSProductionRuntimeInputs: Sendable {
  public let diagnosticsWindow: Duration
  public let virtualDNSEndpoints: Set<TunnelEndpoint>
  public let maximumPendingPrivateConnections: Int
  public let privateAuthenticationTimeoutMilliseconds: Int

  public init(
    diagnosticsWindow: Duration,
    virtualDNSEndpoints: Set<TunnelEndpoint>,
    maximumPendingPrivateConnections: Int,
    privateAuthenticationTimeoutMilliseconds: Int
  ) {
    self.diagnosticsWindow = diagnosticsWindow
    self.virtualDNSEndpoints = virtualDNSEndpoints
    self.maximumPendingPrivateConnections = maximumPendingPrivateConnections
    self.privateAuthenticationTimeoutMilliseconds =
      privateAuthenticationTimeoutMilliseconds
  }
}

public struct MacOSProductionComponentFactories: Sendable {
  public let makeConfigurationSource: @Sendable () throws -> any ConfigurationSnapshotSource
  public let makeSSHRuntimeServices: @Sendable () throws -> MacOSProductionSSHRuntimeServices
  public let makeTCPFactory: @Sendable () throws -> any TCPConsumerFactory
  public let makeDNSFactory: @Sendable () throws -> any DNSConsumerFactory
  public let makePrivateIngressHandler:
    @Sendable () throws -> any M1HEVAuthenticatedConnectionHandler
  public let makeSettingsPlanBuilder: @Sendable () throws -> any NetworkSettingsPlanBuilder
  public let makeSettingsApplier: @Sendable () throws -> any NetworkSettingsApplier
  public let makeSnapshotStore: @Sendable () throws -> any RuntimeSnapshotStore

  public init(
    makeConfigurationSource:
      @escaping @Sendable () throws
      -> any ConfigurationSnapshotSource,
    makeSSHRuntimeServices:
      @escaping @Sendable () throws
      -> MacOSProductionSSHRuntimeServices,
    makeTCPFactory: @escaping @Sendable () throws -> any TCPConsumerFactory,
    makeDNSFactory: @escaping @Sendable () throws -> any DNSConsumerFactory,
    makePrivateIngressHandler:
      @escaping @Sendable () throws
      -> any M1HEVAuthenticatedConnectionHandler,
    makeSettingsPlanBuilder:
      @escaping @Sendable () throws
      -> any NetworkSettingsPlanBuilder,
    makeSettingsApplier: @escaping @Sendable () throws -> any NetworkSettingsApplier,
    makeSnapshotStore: @escaping @Sendable () throws -> any RuntimeSnapshotStore
  ) {
    self.makeConfigurationSource = makeConfigurationSource
    self.makeSSHRuntimeServices = makeSSHRuntimeServices
    self.makeTCPFactory = makeTCPFactory
    self.makeDNSFactory = makeDNSFactory
    self.makePrivateIngressHandler = makePrivateIngressHandler
    self.makeSettingsPlanBuilder = makeSettingsPlanBuilder
    self.makeSettingsApplier = makeSettingsApplier
    self.makeSnapshotStore = makeSnapshotStore
  }
}

/// macOS-only production factory entry point.
///
/// Manifest validation completes before any component factory closure runs.
/// Every `makeRuntime` call then creates one fresh coordinator dependency graph
/// and one monotonically increasing runtime generation.
public actor MacOSProductionDependencyFactory: TunnelRuntimeFactory {
  public typealias BindingManifestSource = @Sendable () throws -> Data?

  typealias SelectedSSHBuilder =
    @Sendable (MacOSAcceptedM0Bindings) -> MacOSSelectedSSHDependencies
  typealias PacketBridgeBuilder =
    @Sendable (
      _ ingress: any M1PrivateIngressDispatching,
      _ runtimeGeneration: UInt64,
      _ bindings: MacOSAcceptedM0Bindings,
      _ inputs: MacOSProductionRuntimeInputs,
      _ handler: any M1HEVAuthenticatedConnectionHandler,
      _ environment: TunnelRuntimeDependencies
    ) throws -> any PacketBridge

  private let bindingManifestSource: BindingManifestSource
  private let runtimeInputs: MacOSProductionRuntimeInputs
  private let componentFactories: MacOSProductionComponentFactories
  private let makeSelectedSSH: SelectedSSHBuilder
  private let makePacketBridge: PacketBridgeBuilder
  private var latestGeneration: UInt64

  public init(
    bindingManifestSource: @escaping BindingManifestSource,
    runtimeInputs: MacOSProductionRuntimeInputs,
    componentFactories: MacOSProductionComponentFactories,
    initialGeneration: UInt64 = 0
  ) {
    self.bindingManifestSource = bindingManifestSource
    self.runtimeInputs = runtimeInputs
    self.componentFactories = componentFactories
    makeSelectedSSH = { bindings in
      MacOSSelectedSSHDependencies(
        transportFactory: MacOSProviderSSHConfiguration.makeTransportFactory(
          maximumTransportBufferBytes: bindings.sshTransportBufferBytes
        ),
        credentialProvider: MacOSProviderSSHConfiguration.makeCredentialProvider(),
        makeHostKeyPolicy: {
          try MacOSProviderSSHConfiguration.makeHostKeyPolicy(snapshot: $0)
        },
        mapCredentialError: {
          MacOSSSHBootstrapErrorMapper.credential($0, configurationGeneration: $1)
        }
      )
    }
    makePacketBridge = Self.productionPacketBridge
    latestGeneration = initialGeneration
  }

  init(
    bindingManifestSource: @escaping BindingManifestSource,
    runtimeInputs: MacOSProductionRuntimeInputs,
    componentFactories: MacOSProductionComponentFactories,
    initialGeneration: UInt64 = 0,
    makeSelectedSSH: @escaping SelectedSSHBuilder,
    makePacketBridge: @escaping PacketBridgeBuilder
  ) {
    self.bindingManifestSource = bindingManifestSource
    self.runtimeInputs = runtimeInputs
    self.componentFactories = componentFactories
    self.makeSelectedSSH = makeSelectedSSH
    self.makePacketBridge = makePacketBridge
    latestGeneration = initialGeneration
  }

  public func makeRuntime(
    context: TunnelRuntimeContext
  ) async throws -> any TunnelRuntime {
    let manifest: Data
    do {
      guard let loaded = try bindingManifestSource() else {
        throw MacOSProductionBindingError.manifestAbsent
      }
      manifest = loaded
    } catch let error as MacOSProductionBindingError {
      throw error
    } catch {
      throw MacOSProductionBindingError.manifestUnreadable
    }
    let bindings = try MacOSProductionBindingManifestValidator.validate(
      manifest,
      diagnosticsWindow: runtimeInputs.diagnosticsWindow
    )
    guard runtimeInputs.maximumPendingPrivateConnections > 0,
      runtimeInputs.privateAuthenticationTimeoutMilliseconds > 0,
      !runtimeInputs.virtualDNSEndpoints.isEmpty
    else {
      throw MacOSProductionBindingError.incompatibleBinding("runtimeInputs")
    }
    guard latestGeneration < UInt64.max else {
      throw TunnelRuntimeCoordinatorError.generationExhausted
    }
    let generation = latestGeneration + 1

    let channelPolicy: SSHChannelPolicy
    do {
      channelPolicy = try SSHChannelPolicy(
        initialReceiveWindowBytes: bindings.sshInitialReceiveWindowBytes,
        consumerReceiveWindowCredit: .unsupported,
        maximumBufferedReadBytes: bindings.sshReadBufferBytes,
        maximumQueuedWriteBytes: bindings.sshQueuedWriteBytes,
        maximumWriteCallBytes: bindings.sshWriteCallBytes
      )
    } catch {
      throw MacOSProductionBindingError.incompatibleBinding("sshChannelPolicy")
    }

    // Selected security dependencies are root-owned and created only after the
    // manifest gate. Public component factories cannot replace or omit them.
    let selectedSSH = makeSelectedSSH(bindings)
    let configurationSource = try componentFactories.makeConfigurationSource()
    let sshServices = try componentFactories.makeSSHRuntimeServices()
    let sshBootstrap = MacOSProductionSSHBootstrap(
      selected: selectedSSH,
      services: sshServices,
      environment: context.dependencies,
      channelPolicy: channelPolicy
    )
    let tcpFactory = try componentFactories.makeTCPFactory()
    let dnsFactory = try componentFactories.makeDNSFactory()
    let settingsPlanBuilder = try componentFactories.makeSettingsPlanBuilder()
    let settingsApplier = try componentFactories.makeSettingsApplier()
    let snapshotStore = try componentFactories.makeSnapshotStore()
    let privateIngressHandler = try componentFactories.makePrivateIngressHandler()
    let environment = context.dependencies
    let inputs = runtimeInputs
    let bridgeBuilder = makePacketBridge
    let packetPlaneFactory = BridgeBackedM1PacketPlaneFactory(
      configuration: bindings.packetBridgeConfiguration,
      virtualDNSEndpoints: inputs.virtualDNSEndpoints
    ) { ingress, _ in
      try bridgeBuilder(
        ingress,
        generation,
        bindings,
        inputs,
        privateIngressHandler,
        environment
      )
    }

    latestGeneration = generation
    return TunnelRuntimeCoordinator(
      runtimeGeneration: generation,
      context: context,
      dependencies: TunnelRuntimeCoordinatorDependencies(
        configurationSource: configurationSource,
        sshBootstrap: sshBootstrap,
        tcpFactory: tcpFactory,
        dnsFactory: dnsFactory,
        packetPlaneFactory: packetPlaneFactory,
        settingsPlanBuilder: settingsPlanBuilder,
        settingsApplier: settingsApplier,
        snapshotStore: snapshotStore
      )
    )
  }

  private static func productionPacketBridge(
    ingress: any M1PrivateIngressDispatching,
    runtimeGeneration: UInt64,
    bindings: MacOSAcceptedM0Bindings,
    inputs: MacOSProductionRuntimeInputs,
    handler: any M1HEVAuthenticatedConnectionHandler,
    environment: TunnelRuntimeDependencies
  ) throws -> any PacketBridge {
    let adapter = M1HEVSOCKSConnectionAdapter(ingress: ingress, handler: handler)
    let boundaryFactory = HEVLoopbackSOCKSBoundaryFactory(
      adapter: adapter,
      maximumPendingConnections: inputs.maximumPendingPrivateConnections,
      authenticationTimeoutMilliseconds: inputs.privateAuthenticationTimeoutMilliseconds
    )
    let descriptorConsumer = HEVDescriptorBorrowConsumer(
      configuration: bindings.internalSOCKSConfiguration,
      boundaryFactory: boundaryFactory,
      logger: environment.logger,
      metrics: environment.metrics
    )
    _ = runtimeGeneration
    return PacketFlowBridge(
      descriptorConsumer: descriptorConsumer,
      clock: environment.clock,
      logger: environment.logger,
      metrics: environment.metrics
    )
  }
}
