import ReluxAppleUITestShared
import XCTest

extension ReluxUITest {
  @MainActor
  final class PageManager {
    let app: XCUIApplication
    let fixtureHost: ReluxUITest.Page.FixtureHost

    init(fixture: ReluxUITestFixture) {
      #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
      #endif
      let app = XCUIApplication()
      let configuration = ReluxUITest.LaunchConfiguration(fixture: fixture)
      app.launchArguments = configuration.arguments
      app.launchEnvironment = configuration.environment
      self.app = app
      fixtureHost = .init(app: app)
    }

    func launch() {
      app.launch()
    }

    func terminate() {
      app.terminate()
    }

    func capture(step: Int, name: String) {
      let attachment = XCTAttachment(screenshot: app.screenshot())
      let attachmentName = String(format: "Step_%02d__%@", step, Self.safeName(name))
      attachment.name = attachmentName
      attachment.lifetime = .keepAlways
      XCTContext.runActivity(named: attachmentName) { activity in
        activity.add(attachment)
      }
    }

    private static func safeName(_ value: String) -> String {
      value.map { character in
        character.isLetter || character.isNumber ? character : "_"
      }.reduce(into: "") { $0.append($1) }
    }
  }
}
