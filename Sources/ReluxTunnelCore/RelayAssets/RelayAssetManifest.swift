import Foundation

public enum RelayRemoteOperatingSystem: String, CaseIterable, Sendable {
  case darwin
  case linux

  fileprivate init(handoffValue: String) throws {
    switch handoffValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "darwin", "macos": self = .darwin
    case "linux": self = .linux
    default: throw RelayAssetLookupError.unsupportedOperatingSystem
    }
  }
}

public enum RelayRemoteArchitecture: String, CaseIterable, Sendable {
  case amd64
  case arm64

  fileprivate init(handoffValue: String) throws {
    switch handoffValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "amd64", "x86_64": self = .amd64
    case "arm64", "aarch64": self = .arm64
    default: throw RelayAssetLookupError.unsupportedArchitecture
    }
  }
}

public struct RelayRemotePlatform: Hashable, Sendable {
  public let operatingSystem: RelayRemoteOperatingSystem
  public let architecture: RelayRemoteArchitecture

  public init(
    operatingSystem: RelayRemoteOperatingSystem,
    architecture: RelayRemoteArchitecture
  ) {
    self.operatingSystem = operatingSystem
    self.architecture = architecture
  }

  public init(operatingSystemName: String, machineHardwareName: String) throws {
    operatingSystem = try RelayRemoteOperatingSystem(handoffValue: operatingSystemName)
    architecture = try RelayRemoteArchitecture(handoffValue: machineHardwareName)
  }
}

public struct RelayAssetBuildIdentity: Equatable, Sendable {
  public let schemaVersion: Int
  public let relayProtocolVersion: Int
  public let relayVersion: String
  public let sourceCommit: String
  public let operatingSystem: RelayRemoteOperatingSystem
  public let architecture: RelayRemoteArchitecture
  public let selfSHA256: String
}

public struct RelayAssetBuildProvenance: Equatable, Sendable {
  public let kind: String
  public let taskID: String
  public let resourceName: String
  public let archiveSHA256: String
}

public struct RelayBundledAsset: Equatable, Sendable {
  public let platform: RelayRemotePlatform
  public let fileName: String
  public let bundleLocation: String
  public let byteSize: Int
  public let sha256: String
  public let relayProtocolVersion: Int
  public let buildIdentity: RelayAssetBuildIdentity
  public let buildProvenanceReference: String
}

public enum RelayAssetLookupError: Error, Equatable, Sendable {
  case unsupportedOperatingSystem
  case unsupportedArchitecture
  case unsupportedPlatform
  case bundledResourceMissing
}

public struct RelayAssetCatalog: Sendable {
  public static let bundled = RelayAssetCatalog(
    schemaVersion: generatedSchemaVersion,
    relayProtocolVersion: generatedProtocolVersion,
    buildProvenance: generatedBuildProvenance,
    assets: generatedAssets)

  public let schemaVersion: Int
  public let relayProtocolVersion: Int
  public let buildProvenance: RelayAssetBuildProvenance
  public let assets: [RelayBundledAsset]

  private let assetsByPlatform: [RelayRemotePlatform: RelayBundledAsset]

  private init(
    schemaVersion: Int,
    relayProtocolVersion: Int,
    buildProvenance: RelayAssetBuildProvenance,
    assets: [RelayBundledAsset]
  ) {
    precondition(schemaVersion == 1)
    precondition(relayProtocolVersion == 1)
    precondition(assets.count == 4)
    let indexed = Dictionary(uniqueKeysWithValues: assets.map { ($0.platform, $0) })
    precondition(indexed.count == assets.count)
    precondition(
      assets.allSatisfy { asset in
        asset.relayProtocolVersion == relayProtocolVersion
          && asset.buildIdentity.relayProtocolVersion == relayProtocolVersion
          && asset.platform.operatingSystem == asset.buildIdentity.operatingSystem
          && asset.platform.architecture == asset.buildIdentity.architecture
          && asset.sha256 == asset.buildIdentity.selfSHA256
      })
    self.schemaVersion = schemaVersion
    self.relayProtocolVersion = relayProtocolVersion
    self.buildProvenance = buildProvenance
    self.assets = assets
    assetsByPlatform = indexed
  }

  public func asset(for platform: RelayRemotePlatform) throws -> RelayBundledAsset {
    guard let asset = assetsByPlatform[platform] else {
      throw RelayAssetLookupError.unsupportedPlatform
    }
    return asset
  }

  public func asset(
    operatingSystemName: String,
    machineHardwareName: String
  ) throws -> RelayBundledAsset {
    try asset(
      for: RelayRemotePlatform(
        operatingSystemName: operatingSystemName,
        machineHardwareName: machineHardwareName))
  }

  public func bundledURL(for platform: RelayRemotePlatform) throws -> URL {
    let asset = try asset(for: platform)
    guard
      let resourceURL = Bundle.main.url(
        forResource: asset.fileName,
        withExtension: nil,
        subdirectory: "relay-assets-v1")
    else {
      throw RelayAssetLookupError.bundledResourceMissing
    }
    return resourceURL
  }
}
