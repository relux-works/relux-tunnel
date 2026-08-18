import ReluxTunnelCore

enum ReluxProxyBuildIdentity {
  static let providerProtocolVersion: UInt16 = ProviderMessageCodec.currentVersion
  static let hostTargetName = "ReluxProxyMac"
  static let providerTargetName = "ReluxProxyMacTunnel"
}
