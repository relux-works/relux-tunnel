import ReluxTunnelNativeAdapter

public enum IOSNativePackagingAnchor {
  public static var schemaVersion: UInt32 {
    NativeDependencyPackaging.schemaVersion
  }

  public static func hevLinkageSmoke() -> Bool {
    _ = NativeDependencyPackaging.hevLinkageSmoke()
    return true
  }
}
