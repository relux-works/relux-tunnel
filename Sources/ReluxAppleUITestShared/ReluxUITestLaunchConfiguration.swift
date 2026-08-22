import Foundation

extension ReluxUITest {
  public enum LaunchKey {
    public static let enabled = "RELUX_UI_TEST_MODE"
    public static let fixture = "RELUX_UI_TEST_FIXTURE"
    public static let schemaVersion = "RELUX_UI_TEST_SCHEMA_VERSION"
    public static let networkMode = "RELUX_UI_TEST_NETWORK_MODE"
  }

  public struct LaunchConfiguration: Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let requiredNetworkMode = "disabled"

    public let fixture: ReluxUITestFixture

    public init(fixture: ReluxUITestFixture) {
      self.fixture = fixture
    }

    public var arguments: [String] {
      Self.argumentPairs([
        (LaunchKey.enabled, "true"),
        (LaunchKey.fixture, fixture.rawValue),
        (LaunchKey.schemaVersion, String(Self.currentSchemaVersion)),
      ])
    }

    public var environment: [String: String] {
      [LaunchKey.networkMode: Self.requiredNetworkMode]
    }

    public static func parse(
      arguments: [String],
      environment: [String: String]
    ) throws -> LaunchConfiguration {
      let values = argumentValues(arguments)
      guard values[LaunchKey.enabled] == "true" else {
        throw LaunchConfigurationError.fixtureModeRequired
      }
      guard environment[LaunchKey.networkMode] == requiredNetworkMode else {
        throw LaunchConfigurationError.networkBoundaryRequired
      }
      guard values[LaunchKey.schemaVersion] == String(currentSchemaVersion) else {
        throw LaunchConfigurationError.unsupportedSchema
      }
      guard
        let rawFixture = values[LaunchKey.fixture],
        let fixture = ReluxUITestFixture(rawValue: rawFixture)
      else {
        throw LaunchConfigurationError.unknownFixture
      }
      return LaunchConfiguration(fixture: fixture)
    }

    private static func argumentPairs(_ pairs: [(String, String)]) -> [String] {
      pairs.flatMap { key, value in ["-\(key)", value] }
    }

    private static func argumentValues(_ arguments: [String]) -> [String: String] {
      var values: [String: String] = [:]
      var index = arguments.startIndex
      while index < arguments.endIndex {
        let argument = arguments[index]
        let next = arguments.index(after: index)
        if argument.hasPrefix("-"), next < arguments.endIndex {
          values[String(argument.dropFirst())] = arguments[next]
          index = arguments.index(after: next)
        } else {
          index = next
        }
      }
      return values
    }
  }

  public enum LaunchConfigurationError: Error, Equatable {
    case fixtureModeRequired
    case networkBoundaryRequired
    case unsupportedSchema
    case unknownFixture
  }
}
