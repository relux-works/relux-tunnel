import ReluxAppleUITestShared
import XCTest

extension ReluxUITest {
  @MainActor
  protocol PageElement {
    func waitForAppearance(timeout: TimeInterval)
  }

  @MainActor
  protocol ComponentElement {
    func waitForReadiness(timeout: TimeInterval)
  }
}

extension XCUIElement {
  @MainActor
  func waitForLabel(_ expected: String, timeout: TimeInterval) -> Bool {
    XCTWaiter.wait(
      for: [
        XCTNSPredicateExpectation(
          predicate: NSPredicate(format: "label == %@", expected),
          object: self
        )
      ],
      timeout: timeout
    ) == .completed
  }
}
