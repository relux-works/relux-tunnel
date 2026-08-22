import ReluxAppleUITestShared
import XCTest

@MainActor
final class ReluxUITestSmokeTests: XCTestCase {
  func testDiagnosticFixtureProducesStepScreenshots() {
    let fixture = ReluxUITestFixture.diagnosticPopulated
    let pages = ReluxUITest.PageManager(fixture: fixture)
    addTeardownBlock { pages.terminate() }

    pages.launch()
    pages.fixtureHost.waitForAppearance()
    pages.fixtureHost.waitForFixture(fixture)
    pages.capture(step: 1, name: "diagnostic_fixture_ready")

    pages.fixtureHost.confirmFixture()
    pages.capture(step: 2, name: "diagnostic_fixture_confirmed")
  }
}
