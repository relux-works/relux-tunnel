import Foundation

/// Shared compile-time namespace for containing apps and Apple UI-test targets.
public enum ReluxUITest {}

extension ReluxUITest {
  public enum Identifier {
    public enum FixtureHost {
      public static let page = "Test fixture host Root page"
      public static let fixtureName = "Test fixture host Fixture name label"
      public static let fixtureCategory = "Test fixture host Fixture category label"
      public static let safetyBoundary = "Test fixture host Safety boundary label"
      public static let confirmButton = "Test fixture host Confirm fixture button"
      public static let confirmation = "Test fixture host Confirmation label"
    }
  }
}

extension ReluxUITest {
  public enum Timeout {
    public static let short: TimeInterval = 2
    public static let standard: TimeInterval = 5
    public static let launch: TimeInterval = 10
  }
}
