import Foundation
@preconcurrency import NetworkExtension
import OSLog

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private enum State {
    case stopped
    case running
    case stopping
  }

  private static let logger = Logger(
    subsystem: "works.relux.tunnel.probe.mac.tunnel",
    category: "provider-lifecycle"
  )
  private let stateLock = NSLock()
  private var state: State = .stopped

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    stateLock.withLock { state = .running }
    Self.logger.info("lifecycle=started packet-forwarding=false")
    completionHandler(nil)
  }

  override func handleAppMessage(
    _ messageData: Data,
    completionHandler: ((Data?) -> Void)?
  ) {
    let isRunning = stateLock.withLock { state == .running }
    guard isRunning else {
      Self.logger.error("message=rejected provider-state=not-running")
      completionHandler?(nil)
      return
    }

    do {
      let response = try ProbeMessageResponder.response(
        to: messageData,
        providerBundleIdentifier: "works.relux.tunnel.probe.mac.tunnel"
      )
      Self.logger.info("message=v1-response packet-forwarding=false")
      completionHandler?(response)
    } catch {
      Self.logger.error("message=rejected invalid-or-unsupported-payload")
      completionHandler?(nil)
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    stateLock.withLock { state = .stopping }
    Self.logger.info("lifecycle=stopping outstanding-work=0")
    stateLock.withLock { state = .stopped }
    Self.logger.info("lifecycle=stopped outstanding-work=0")
    completionHandler()
  }
}
