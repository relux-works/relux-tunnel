import ReluxTunnelNativeAdapter

public enum MacOSNativePackagingAnchor {
  public static var schemaVersion: UInt32 {
    NativeDependencyPackaging.schemaVersion
  }

  public static func hevLinkageSmoke() -> Bool {
    _ = NativeDependencyPackaging.hevLinkageSmoke()
    return true
  }
}
