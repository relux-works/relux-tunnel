import Foundation
@preconcurrency import NetworkExtension
import ReluxTunnelCore

/// macOS provider integration for the complete profile snapshot stored by
/// `NETunnelProviderProtocol`. This adapter has no App Group or Keychain path.
public final class MacOSSSHProfileSnapshotLoader: @unchecked Sendable {
  private let loader: SSHProfileRuntimeSnapshotLoader

  public init(loader: SSHProfileRuntimeSnapshotLoader = SSHProfileRuntimeSnapshotLoader()) {
    self.loader = loader
  }

  public func capture(
    from protocolConfiguration: NEVPNProtocol?,
    startRequest: RuntimeStartRequest? = nil
  ) throws -> SSHProfileSnapshotV1 {
    guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
      throw SSHProfileSnapshotLoaderError.profileCorrupt
    }
    return try capture(from: tunnelProtocol, startRequest: startRequest)
  }

  public func capture(
    from tunnelProtocol: NETunnelProviderProtocol,
    startRequest: RuntimeStartRequest? = nil
  ) throws -> SSHProfileSnapshotV1 {
    let configuration = tunnelProtocol.providerConfiguration?.mapValues(
      MacOSVPNProviderConfigurationCodec.decode
    )
    return try loader.capture(from: configuration, startRequest: startRequest)
  }
}
