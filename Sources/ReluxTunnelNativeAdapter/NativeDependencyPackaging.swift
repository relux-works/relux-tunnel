import ReluxTunnelCore

/// The named boundary through which provider and harness targets consume native code.
///
/// Production HEV remains behind this module without adding a native dependency
/// to `ReluxTunnelCore`. The harmless C fixture is test evidence only.
public enum NativeDependencyPackaging: Sendable {
  public static let schemaVersion: UInt32 = 1

  /// Keeps the pinned HEV archive in every provider/harness link graph without
  /// starting global HEV state.
  public static func hevLinkageSmoke() -> HEVTrafficStatistics {
    PinnedHEVNativeRuntime().statistics()
  }
}
