import Foundation
@preconcurrency import NetworkExtension
import OSLog
import Observation

enum ProbePhase: Equatable {
  case idle
  case configuring
  case configured
  case starting
  case messaging
  case stopping
  case succeeded
  case failed

  var label: String {
    switch self {
    case .idle: "Idle"
    case .configuring: "Configuring"
    case .configured: "Configured"
    case .starting: "Starting provider"
    case .messaging: "Sending v1 message"
    case .stopping: "Stopping provider"
    case .succeeded: "Succeeded"
    case .failed: "Failed"
    }
  }

  var isBusy: Bool {
    switch self {
    case .configuring, .starting, .messaging, .stopping: true
    case .idle, .configured, .succeeded, .failed: false
    }
  }

  var canStop: Bool {
    switch self {
    case .starting, .messaging, .stopping: true
    case .idle, .configuring, .configured, .succeeded, .failed: false
    }
  }
}

enum ProbeControllerError: Error {
  case configurationNotReloaded
  case providerSessionUnavailable
  case providerReturnedNoData
  case responseMismatch
  case statusTimeout(expected: String, actual: String)
  case tunnelDisconnectedDuringStart
}

/// NetworkExtension preference callbacks are not concurrency-annotated. The
/// controller unwraps this value only on its main-actor isolation domain.
private struct MainActorTransfer<Value>: @unchecked Sendable {
  let value: Value
}

@MainActor
@Observable
final class ProbeController {
  private static let logger = Logger(
    subsystem: "works.relux.tunnel.probe.mac",
    category: "host-lifecycle"
  )
  private static let providerBundleIdentifier = "works.relux.tunnel.probe.mac.tunnel"
  private static let localizedDescription = "Relux Disposable Packet Tunnel Probe"

  var phase: ProbePhase = .idle
  var vpnStatus = "invalid"
  var providerResponse = "not requested"
  var lifecycleText = "idle"
  var failure: String?

  @ObservationIgnored private var activeTask: Task<Void, Never>?
  @ObservationIgnored private var manager: NETunnelProviderManager?
  @ObservationIgnored private var lifecycleEvents = ["idle"]

  func configure() {
    beginOperation {
      self.phase = .configuring
      let manager = try await self.saveAndReloadConfiguration()
      self.manager = manager
      self.record("configuration=reloaded-enabled")
      self.phase = .configured
    }
  }

  func runProbe() {
    beginOperation {
      self.phase = .configuring
      let manager = try await self.saveAndReloadConfiguration()
      self.manager = manager
      self.record("configuration=reloaded-enabled")

      guard let session = manager.connection as? NETunnelProviderSession else {
        throw ProbeControllerError.providerSessionUnavailable
      }
      if session.status == .connected || session.status == .connecting
        || session.status == .reasserting
      {
        session.stopTunnel()
        try await self.waitForStatus(.disconnected, connection: session)
      }

      self.phase = .starting
      self.record("provider=start-requested")
      try session.startTunnel(options: [
        ProbeContract.startOptionKey: NSNumber(value: ProbeContract.currentVersion)
      ])
      try await self.waitForStatus(.connected, connection: session)

      self.phase = .messaging
      let request = try ProbeContract.encoder.encode(ProbeRequest())
      let responseData = try await self.send(request, through: session)
      let response = try ProbeContract.decoder.decode(ProbeResponse.self, from: responseData)
      guard response.providerBundleIdentifier == Self.providerBundleIdentifier,
        response.lifecycleState == .running,
        !response.packetForwarding
      else {
        throw ProbeControllerError.responseMismatch
      }
      self.providerResponse =
        "v\(response.protocolVersion), running, packetForwarding=false"
      self.record("provider=response-v1-validated")

      self.phase = .stopping
      self.record("provider=stop-requested")
      session.stopTunnel()
      try await self.waitForStatus(.disconnected, connection: session)
      self.record("provider=stopped-cleanly")
      self.phase = .succeeded
    }
  }

  func stop() {
    activeTask?.cancel()
    manager?.connection.stopVPNTunnel()
    record("provider=manual-stop-requested")
  }

  private func beginOperation(_ operation: @escaping @MainActor () async throws -> Void) {
    activeTask?.cancel()
    failure = nil
    providerResponse = "not requested"
    lifecycleEvents = ["operation=begin"]
    lifecycleText = lifecycleEvents.joined(separator: "\n")
    activeTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await operation()
      } catch is CancellationError {
        self.manager?.connection.stopVPNTunnel()
        self.record("operation=cancelled-stop-requested")
        self.phase = .idle
      } catch {
        self.manager?.connection.stopVPNTunnel()
        let platformError = error as NSError
        self.failure = "\(platformError.domain)#\(platformError.code)"
        self.record("operation=failed")
        self.phase = .failed
        Self.logger.error(
          "probe failed domain=\(platformError.domain, privacy: .public) code=\(platformError.code)"
        )
      }
      self.activeTask = nil
    }
  }

  private func saveAndReloadConfiguration() async throws -> NETunnelProviderManager {
    let existingManagers = try await loadManagers()
    let configuredManager =
      existingManagers.first(where: { manager in
        guard
          let tunnelProtocol = manager.protocolConfiguration
            as? NETunnelProviderProtocol
        else { return false }
        return tunnelProtocol.providerBundleIdentifier == Self.providerBundleIdentifier
      }) ?? NETunnelProviderManager()

    let tunnelProtocol = NETunnelProviderProtocol()
    tunnelProtocol.providerBundleIdentifier = Self.providerBundleIdentifier
    tunnelProtocol.serverAddress = "relux-entitlement-probe.invalid"
    tunnelProtocol.disconnectOnSleep = false
    tunnelProtocol.includeAllNetworks = false
    tunnelProtocol.excludeLocalNetworks = true
    tunnelProtocol.enforceRoutes = false
    tunnelProtocol.providerConfiguration = [
      ProbeContract.configurationVersionKey: NSNumber(value: ProbeContract.currentVersion)
    ]

    configuredManager.protocolConfiguration = tunnelProtocol
    configuredManager.localizedDescription = Self.localizedDescription
    configuredManager.isEnabled = true
    configuredManager.isOnDemandEnabled = false
    configuredManager.onDemandRules = nil
    configuredManager.appRules = []
    try await save(configuredManager)

    let reloadedManagers = try await loadManagers()
    guard
      let reloaded = reloadedManagers.first(where: { manager in
        guard let tunnelProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol
        else { return false }
        return tunnelProtocol.providerBundleIdentifier == Self.providerBundleIdentifier
          && manager.localizedDescription == Self.localizedDescription
          && manager.isEnabled
      })
    else {
      throw ProbeControllerError.configurationNotReloaded
    }
    updateStatus(reloaded.connection.status)
    return reloaded
  }

  private func loadManagers() async throws -> [NETunnelProviderManager] {
    let transfer: MainActorTransfer<[NETunnelProviderManager]> =
      try await withCheckedThrowingContinuation { continuation in
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume(returning: MainActorTransfer(value: managers ?? []))
          }
        }
      }
    return transfer.value
  }

  private func save(_ manager: NETunnelProviderManager) async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, any Error>) in
      manager.saveToPreferences { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }
    }
  }

  private func send(_ data: Data, through session: NETunnelProviderSession) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      do {
        try session.sendProviderMessage(data) { response in
          guard let response else {
            continuation.resume(throwing: ProbeControllerError.providerReturnedNoData)
            return
          }
          continuation.resume(returning: response)
        }
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  private func waitForStatus(
    _ expected: NEVPNStatus,
    connection: NEVPNConnection,
    timeout: Duration = .seconds(20)
  ) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    var lastStatus: NEVPNStatus?
    var sawActiveTransition = false

    while true {
      try Task.checkCancellation()
      let status = connection.status
      if status != lastStatus {
        updateStatus(status)
        lastStatus = status
      }
      if status == expected || (expected == .disconnected && status == .invalid) {
        return
      }
      if status == .connecting || status == .connected || status == .reasserting {
        sawActiveTransition = true
      }
      if expected == .connected && status == .disconnected && sawActiveTransition {
        throw ProbeControllerError.tunnelDisconnectedDuringStart
      }
      if clock.now >= deadline {
        throw ProbeControllerError.statusTimeout(
          expected: Self.label(for: expected),
          actual: Self.label(for: status)
        )
      }
      try await Task.sleep(for: .milliseconds(100))
    }
  }

  private func updateStatus(_ status: NEVPNStatus) {
    let label = Self.label(for: status)
    vpnStatus = label
    record("status=\(label)")
  }

  private func record(_ event: String) {
    guard lifecycleEvents.last != event else { return }
    lifecycleEvents.append(event)
    lifecycleText = lifecycleEvents.joined(separator: "\n")
    Self.logger.info("\(event, privacy: .public)")
  }

  private static func label(for status: NEVPNStatus) -> String {
    switch status {
    case .invalid: "invalid"
    case .disconnected: "disconnected"
    case .connecting: "connecting"
    case .connected: "connected"
    case .reasserting: "reasserting"
    case .disconnecting: "disconnecting"
    @unknown default: "unknown"
    }
  }
}
