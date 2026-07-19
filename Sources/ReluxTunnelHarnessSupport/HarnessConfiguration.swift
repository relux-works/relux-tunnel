import Foundation
import ReluxTunnelCore

public enum HarnessConfigurationSchema {
  public static let currentVersion: UInt16 = 1
}

public enum HarnessResultSchema {
  public static let currentVersion: UInt16 = 1
}

public enum HarnessMetricSchema {
  public static let currentVersion: UInt16 = 1
}

public enum HarnessConfigurationPrivacy: String, Codable, Sendable {
  case `public`
  case sensitive
}

public struct HarnessConfigurationValue: Codable, Equatable, Sendable {
  public let value: String
  public let privacy: HarnessConfigurationPrivacy

  public init(value: String, privacy: HarnessConfigurationPrivacy) {
    self.value = value
    self.privacy = privacy
  }
}

public struct HarnessConfigurationDocument: Codable, Equatable, Sendable {
  public let schemaVersion: UInt16
  public let seed: UInt64
  public let sourceRevision: String
  public let dependencyRevisions: [String: String]
  public let profileReference: HarnessConfigurationValue
  public let parameters: [String: HarnessConfigurationValue]

  public init(
    schemaVersion: UInt16 = HarnessConfigurationSchema.currentVersion,
    seed: UInt64,
    sourceRevision: String,
    dependencyRevisions: [String: String],
    profileReference: HarnessConfigurationValue,
    parameters: [String: HarnessConfigurationValue] = [:]
  ) {
    self.schemaVersion = schemaVersion
    self.seed = seed
    self.sourceRevision = sourceRevision
    self.dependencyRevisions = dependencyRevisions
    self.profileReference = profileReference
    self.parameters = parameters
  }

  public func tunnelConfiguration() -> TunnelConfiguration {
    TunnelConfiguration(
      profileReference: TunnelConfigurationReference(rawValue: profileReference.value),
      parameters: parameters.mapValues(\.value)
    )
  }

  public func recordedConfiguration() -> HarnessRecordedConfiguration {
    HarnessRecordedConfiguration(
      profileReference: profileReference.recordedValue,
      parameters: parameters.mapValues(\.recordedValue)
    )
  }
}

public struct HarnessRecordedConfiguration: Codable, Equatable, Sendable {
  public let profileReference: String
  public let parameters: [String: String]

  public init(profileReference: String, parameters: [String: String]) {
    self.profileReference = profileReference
    self.parameters = parameters
  }
}

extension HarnessConfigurationValue {
  fileprivate var recordedValue: String {
    switch privacy {
    case .public:
      value
    case .sensitive:
      "<redacted>"
    }
  }
}

public enum HarnessConfigurationError: Error, Equatable, CustomStringConvertible {
  case unsupportedSchemaVersion(UInt16)
  case emptySourceRevision
  case emptyDependencyName
  case emptyDependencyRevision(String)
  case emptyProfileReference
  case emptyParameterName

  public var description: String {
    switch self {
    case .unsupportedSchemaVersion(let version):
      "unsupported configuration schema version: \(version)"
    case .emptySourceRevision:
      "sourceRevision must not be empty"
    case .emptyDependencyName:
      "dependency revision names must not be empty"
    case .emptyDependencyRevision(let name):
      "dependency revision for \(name) must not be empty"
    case .emptyProfileReference:
      "profileReference.value must not be empty"
    case .emptyParameterName:
      "configuration parameter names must not be empty"
    }
  }
}

public enum HarnessConfigurationCodec {
  public static func decode(_ data: Data) throws -> HarnessConfigurationDocument {
    let configuration = try JSONDecoder().decode(HarnessConfigurationDocument.self, from: data)
    try validate(configuration)
    return configuration
  }

  public static func encode(_ configuration: HarnessConfigurationDocument) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(configuration)
  }

  public static func validate(_ configuration: HarnessConfigurationDocument) throws {
    guard configuration.schemaVersion == HarnessConfigurationSchema.currentVersion else {
      throw HarnessConfigurationError.unsupportedSchemaVersion(configuration.schemaVersion)
    }
    guard !configuration.sourceRevision.isEmpty else {
      throw HarnessConfigurationError.emptySourceRevision
    }
    guard !configuration.profileReference.value.isEmpty else {
      throw HarnessConfigurationError.emptyProfileReference
    }
    guard !configuration.dependencyRevisions.keys.contains("") else {
      throw HarnessConfigurationError.emptyDependencyName
    }
    if let emptyRevision = configuration.dependencyRevisions.first(where: { $0.value.isEmpty }) {
      throw HarnessConfigurationError.emptyDependencyRevision(emptyRevision.key)
    }
    guard !configuration.parameters.keys.contains("") else {
      throw HarnessConfigurationError.emptyParameterName
    }
  }
}
