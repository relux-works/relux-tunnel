import Foundation
import ReluxAppleUITestShared
import Testing

@Suite("Shared Apple UI-test contract")
struct ReluxAppleUITestSharedTests {
  @Test("every required fixture category is represented")
  func fixtureCoverage() {
    #expect(
      Set(ReluxUITestFixture.allCases.map(\.category)) == Set(ReluxUITestFixtureCategory.allCases))
  }

  @Test("typed launch configuration round trips", arguments: ReluxUITestFixture.allCases)
  func configurationRoundTrip(_ fixture: ReluxUITestFixture) throws {
    let configuration = ReluxUITest.LaunchConfiguration(fixture: fixture)
    #expect(
      try ReluxUITest.LaunchConfiguration.parse(
        arguments: configuration.arguments,
        environment: configuration.environment
      ) == configuration
    )
  }

  @Test("fixture launch fails closed without the non-networked boundary")
  func requiresNonNetworkedBoundary() {
    let configuration = ReluxUITest.LaunchConfiguration(fixture: .privacyRedacted)
    #expect(throws: ReluxUITest.LaunchConfigurationError.networkBoundaryRequired) {
      try ReluxUITest.LaunchConfiguration.parse(
        arguments: configuration.arguments,
        environment: [:]
      )
    }
  }

  @Test("fixture data uses synthetic public labels only")
  func fixtureValuesAreSynthetic() {
    for fixture in ReluxUITestFixture.allCases {
      #expect(!fixture.rawValue.contains("@"))
      #expect(!fixture.rawValue.contains("."))
      #expect(!fixture.displayName.isEmpty)
    }
  }
}
