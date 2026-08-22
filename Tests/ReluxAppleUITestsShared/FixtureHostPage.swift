import ReluxAppleUITestShared
import XCTest

extension ReluxUITest {
  enum Page {}
}

extension ReluxUITest.Page {
  @MainActor
  struct FixtureHost: ReluxUITest.PageElement {
    private let root: XCUIElement
    private let fixtureName: XCUIElement
    private let safetyBoundary: XCUIElement
    private let confirmButton: XCUIElement
    private let confirmation: XCUIElement

    init(app: XCUIApplication) {
      root = app.descendants(matching: .any)[ReluxUITest.Identifier.FixtureHost.page]
      fixtureName = app.staticTexts[ReluxUITest.Identifier.FixtureHost.fixtureName]
      safetyBoundary = app.staticTexts[ReluxUITest.Identifier.FixtureHost.safetyBoundary]
      confirmButton = app.buttons[ReluxUITest.Identifier.FixtureHost.confirmButton]
      confirmation = app.staticTexts[ReluxUITest.Identifier.FixtureHost.confirmation]
    }

    func waitForAppearance(timeout: TimeInterval = ReluxUITest.Timeout.launch) {
      XCTAssertTrue(root.waitForExistence(timeout: timeout), "Fixture host page did not appear")
      XCTAssertTrue(
        safetyBoundary.waitForExistence(timeout: timeout),
        "Non-networked fixture safety marker did not appear"
      )
    }

    func waitForFixture(
      _ fixture: ReluxUITestFixture,
      timeout: TimeInterval = ReluxUITest.Timeout.standard
    ) {
      XCTAssertTrue(
        fixtureName.waitForLabel(fixture.displayName, timeout: timeout),
        "Fixture label did not become \(fixture.displayName)"
      )
    }

    func confirmFixture(timeout: TimeInterval = ReluxUITest.Timeout.standard) {
      XCTAssertTrue(
        confirmButton.waitForExistence(timeout: timeout), "Confirm button did not appear")
      XCTAssertTrue(confirmButton.isHittable, "Confirm button is not hittable")
      confirmButton.tap()
      XCTAssertTrue(
        confirmation.waitForLabel("Fixture confirmed", timeout: timeout),
        "Confirmation state did not appear"
      )
    }
  }
}
