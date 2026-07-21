import CoreFoundation
import Foundation
@preconcurrency import NetworkExtension
import ReluxTunnelCore

/// iOS host seam for the shared owned-manager repository.
public enum IOSHostVPNRepository {
  public static func make(
    identity: PlatformVPNIdentity,
    clock: any TunnelClock = ContinuousTunnelClock(),
    operationTimeout: Duration = .seconds(15)
  ) throws -> OwnedVPNManagerRepository {
    guard identity.platform == .iOS else {
      throw VPNManagerRepositoryError.invalidPlatformIdentity
    }
    return OwnedVPNManagerRepository(
      identity: identity,
      client: IOSVPNPreferencesClient(),
      clock: clock,
      operationTimeout: operationTimeout
    )
  }

  public static func production(
    clock: any TunnelClock = ContinuousTunnelClock(),
    operationTimeout: Duration = .seconds(15)
  ) throws -> OwnedVPNManagerRepository {
    try make(
      identity: PlatformVPNIdentity.production(for: .iOS),
      clock: clock,
      operationTimeout: operationTimeout
    )
  }
}

public final class IOSVPNPreferencesClient: VPNPreferencesClient, @unchecked Sendable {
  public init() {}

  public func loadAllFromPreferences(
    completion:
      @escaping @Sendable (
        Result<[any VPNPreferencesManager]?, VPNPreferencePlatformError>
      ) -> Void
  ) {
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error {
        completion(.failure(VPNPreferencePlatformError(error)))
      } else {
        completion(.success(managers?.map(IOSVPNPreferencesManager.init)))
      }
    }
  }

  public func makeManager() -> any VPNPreferencesManager {
    IOSVPNPreferencesManager(NETunnelProviderManager())
  }
}

private final class IOSVPNPreferencesManager: VPNPreferencesManager, @unchecked Sendable {
  private let manager: NETunnelProviderManager

  init(_ manager: NETunnelProviderManager) {
    self.manager = manager
  }

  var snapshot: VPNManagerSnapshot {
    let tunnelProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol
    return VPNManagerSnapshot(
      protocolKind: manager.protocolConfiguration == nil
        ? .none : (tunnelProtocol == nil ? .other : .tunnelProvider),
      providerBundleIdentifier: tunnelProtocol?.providerBundleIdentifier,
      serverAddress: tunnelProtocol?.serverAddress,
      disconnectOnSleep: tunnelProtocol?.disconnectOnSleep ?? false,
      includeAllNetworks: tunnelProtocol?.includeAllNetworks ?? false,
      excludeLocalNetworks: tunnelProtocol?.excludeLocalNetworks ?? false,
      enforceRoutes: tunnelProtocol?.enforceRoutes ?? false,
      providerConfiguration: tunnelProtocol?.providerConfiguration?.mapValues(
        IOSVPNProviderConfigurationCodec.decode
      ),
      localizedDescription: manager.localizedDescription,
      isEnabled: manager.isEnabled,
      isOnDemandEnabled: manager.isOnDemandEnabled,
      hasOnDemandRules: !(manager.onDemandRules?.isEmpty ?? true),
      hasAppRules: false,
      sessionStatus: VPNManagerSessionStatus(manager.connection.status)
    )
  }

  var hostSession: (any VPNHostSession)? {
    guard let session = manager.connection as? NETunnelProviderSession else { return nil }
    return IOSVPNHostSession(manager: manager, session: session)
  }

  func applyCanonicalConfiguration(_ configuration: CanonicalVPNManagerConfiguration) {
    let tunnelProtocol = NETunnelProviderProtocol()
    tunnelProtocol.providerBundleIdentifier = configuration.providerBundleIdentifier
    tunnelProtocol.serverAddress = configuration.serverAddress
    tunnelProtocol.disconnectOnSleep = configuration.disconnectOnSleep
    tunnelProtocol.includeAllNetworks = configuration.includeAllNetworks
    tunnelProtocol.excludeLocalNetworks = configuration.excludeLocalNetworks
    tunnelProtocol.enforceRoutes = configuration.enforceRoutes
    tunnelProtocol.providerConfiguration = configuration.providerConfiguration.compactMapValues(
      IOSVPNProviderConfigurationCodec.encode
    )
    manager.protocolConfiguration = tunnelProtocol
    manager.localizedDescription = configuration.localizedDescription
    manager.isOnDemandEnabled = false
    manager.onDemandRules = nil
  }

  func setEnabled(_ enabled: Bool) {
    manager.isEnabled = enabled
  }

  func saveToPreferences(
    completion: @escaping @Sendable (VPNPreferencePlatformError?) -> Void
  ) {
    manager.saveToPreferences { error in
      completion(error.map(VPNPreferencePlatformError.init))
    }
  }

  func removeFromPreferences(
    completion: @escaping @Sendable (VPNPreferencePlatformError?) -> Void
  ) {
    manager.removeFromPreferences { error in
      completion(error.map(VPNPreferencePlatformError.init))
    }
  }

  func stopTunnel() {
    manager.connection.stopVPNTunnel()
  }

  func observeTerminalStatus(
    completion: @escaping @Sendable (VPNManagerSessionStatus) -> Void
  ) -> any VPNPreferenceObservation {
    IOSVPNStatusObservation(connection: manager.connection, completion: completion)
  }
}

private final class IOSVPNHostSession: VPNHostSession, @unchecked Sendable {
  private let manager: NETunnelProviderManager
  private let session: NETunnelProviderSession

  init(manager: NETunnelProviderManager, session: NETunnelProviderSession) {
    self.manager = manager
    self.session = session
  }

  var status: VPNManagerSessionStatus {
    VPNManagerSessionStatus(session.status)
  }

  func startTunnel(options: [String: Data]) throws {
    try IOSVPNHostSessionStartAdapter.start {
      try session.startTunnel(options: options.mapValues { $0 as NSData })
    }
  }

  func stopTunnel() {
    session.stopTunnel()
  }

  func sendProviderMessage(
    _ message: Data,
    responseHandler: @escaping @Sendable (Data?) -> Void
  ) throws {
    try session.sendProviderMessage(message, responseHandler: responseHandler)
  }

  func fetchLastDisconnectError(
    completion: @escaping @Sendable (VPNPlatformError?) -> Void
  ) {
    session.fetchLastDisconnectError { error in
      completion(
        error.map {
          let platformError = $0 as NSError
          return VPNPlatformError(domain: platformError.domain, code: platformError.code)
        }
      )
    }
  }

  func observeStatusChanges(
    notification: @escaping @Sendable () -> Void
  ) -> any VPNPreferenceObservation {
    IOSVPNNotificationObservation(connection: session, notification: notification)
  }
}

enum IOSVPNHostSessionStartAdapter {
  static func start(_ operation: () throws -> Void) throws {
    do {
      try operation()
    } catch {
      throw VPNPreferencePlatformError(error)
    }
  }
}

private final class IOSVPNNotificationObservation: VPNPreferenceObservation, @unchecked Sendable {
  private let lock = NSLock()
  private var token: (any NSObjectProtocol)?

  init(
    connection: NEVPNConnection,
    notification: @escaping @Sendable () -> Void
  ) {
    token = NotificationCenter.default.addObserver(
      forName: .NEVPNStatusDidChange,
      object: connection,
      queue: nil
    ) { _ in
      notification()
    }
  }

  func cancel() {
    let token = lock.withLock {
      defer { self.token = nil }
      return self.token
    }
    if let token { NotificationCenter.default.removeObserver(token) }
  }

  deinit {
    cancel()
  }
}

final class IOSVPNStatusObservation: VPNPreferenceObservation, @unchecked Sendable {
  private let lock = NSLock()
  private let unregister: (any NSObjectProtocol) -> Void
  private var token: (any NSObjectProtocol)?
  private var retired = false

  convenience init(
    connection: NEVPNConnection,
    completion: @escaping @Sendable (VPNManagerSessionStatus) -> Void
  ) {
    self.init(
      status: { [weak connection] in
        guard let connection else { return .invalid }
        return VPNManagerSessionStatus(connection.status)
      },
      register: { notification in
        NotificationCenter.default.addObserver(
          forName: .NEVPNStatusDidChange,
          object: connection,
          queue: nil
        ) { _ in
          notification()
        }
      },
      unregister: { token in
        NotificationCenter.default.removeObserver(token)
      },
      completion: completion
    )
  }

  init(
    status: @escaping @Sendable () -> VPNManagerSessionStatus,
    register: (@escaping @Sendable () -> Void) -> any NSObjectProtocol,
    unregister: @escaping (any NSObjectProtocol) -> Void,
    completion: @escaping @Sendable (VPNManagerSessionStatus) -> Void
  ) {
    self.unregister = unregister

    let registeredToken = register { [weak self] in
      self?.resolveIfTerminal(status(), completion: completion)
    }
    let retireRegisteredToken = lock.withLock { () -> Bool in
      guard !retired else { return true }
      token = registeredToken
      return false
    }
    if retireRegisteredToken {
      unregister(registeredToken)
    }

    // The observer is installed before this authoritative read. This closes both
    // transition windows: a synchronous notification is accepted before the token
    // returns, and a notification-free transition during registration is seen here.
    resolveIfTerminal(status(), completion: completion)
  }

  func cancel() {
    let token: (any NSObjectProtocol)?
    lock.lock()
    guard !retired else {
      lock.unlock()
      return
    }
    retired = true
    token = self.token
    self.token = nil
    lock.unlock()
    if let token { unregister(token) }
  }

  deinit {
    cancel()
  }

  private func resolveIfTerminal(
    _ status: VPNManagerSessionStatus,
    completion: @escaping @Sendable (VPNManagerSessionStatus) -> Void
  ) {
    guard status.isTerminal else { return }
    resolve(status, completion: completion)
  }

  private func resolve(
    _ status: VPNManagerSessionStatus,
    completion: @escaping @Sendable (VPNManagerSessionStatus) -> Void
  ) {
    let token: (any NSObjectProtocol)?
    lock.lock()
    guard !retired else {
      lock.unlock()
      return
    }
    retired = true
    token = self.token
    self.token = nil
    lock.unlock()
    if let token { unregister(token) }
    completion(status)
  }
}

enum IOSVPNProviderConfigurationCodec {
  static func decode(_ platformValue: Any) -> VPNProviderConfigurationValue {
    switch platformValue {
    case let value as String:
      return .string(value)
    case let value as Data:
      return .data(value)
    case let value as NSNumber where CFGetTypeID(value) != CFBooleanGetTypeID():
      switch String(cString: value.objCType) {
      case "c", "s", "i", "l", "q":
        guard let exact = Int(exactly: value.int64Value) else { return .unsupported }
        return .integer(exact)
      case "C", "S", "I", "L", "Q":
        let exact = value.uint64Value
        return exact <= UInt64(Int.max)
          ? .integer(Int(exact)) : .unsignedInteger(exact)
      default:
        return .unsupported
      }
    default:
      return .unsupported
    }
  }

  static func encode(_ value: VPNProviderConfigurationValue) -> Any? {
    switch value {
    case .string(let value): value
    case .integer(let value): NSNumber(value: value)
    case .unsignedInteger(let value): NSNumber(value: value)
    case .data(let value): value
    case .unsupported: nil
    }
  }
}

extension VPNManagerSessionStatus {
  fileprivate init(_ status: NEVPNStatus) {
    switch status {
    case .invalid: self = .invalid
    case .disconnected: self = .disconnected
    case .connecting: self = .connecting
    case .connected: self = .connected
    case .reasserting: self = .reasserting
    case .disconnecting: self = .disconnecting
    @unknown default: self = .invalid
    }
  }
}

extension VPNPreferencePlatformError {
  fileprivate init(_ error: any Error) {
    let error = error as NSError
    let kind: Kind
    if error.domain == NEVPNErrorDomain {
      switch error.code {
      case NEVPNError.configurationInvalid.rawValue: kind = .configurationInvalid
      case NEVPNError.configurationDisabled.rawValue: kind = .configurationDisabled
      case NEVPNError.connectionFailed.rawValue: kind = .connectionFailed
      case NEVPNError.configurationStale.rawValue: kind = .configurationStale
      case NEVPNError.configurationReadWriteFailed.rawValue: kind = .readWriteFailed
      case NEVPNError.configurationUnknown.rawValue: kind = .unknown
      default: kind = .other
      }
    } else {
      kind = .other
    }
    self.init(kind: kind, domain: error.domain, code: error.code)
  }
}
