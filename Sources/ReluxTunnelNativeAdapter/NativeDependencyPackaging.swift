import CReluxNativeFixture
import ReluxTunnelCore

/// The named boundary through which provider and harness targets consume native code.
///
/// Production HEV and a C SSH candidate can replace the harmless fixture behind
/// this module without adding a native dependency to `ReluxTunnelCore`.
public enum NativeDependencyPackaging: Sendable {
  public static let schemaVersion: UInt32 = relux_native_fixture_schema_version()

  public static func smoke(value: UInt32) -> UInt32 {
    relux_native_fixture_mix(value)
  }

  /// Keeps the pinned HEV archive in every provider/harness link graph without
  /// starting global HEV state.
  public static func hevLinkageSmoke() -> HEVTrafficStatistics {
    PinnedHEVNativeRuntime().statistics()
  }
}
