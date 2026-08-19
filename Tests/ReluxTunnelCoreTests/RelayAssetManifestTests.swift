import Foundation
import Testing

@testable import ReluxTunnelCore

@Suite("Bundled relay asset manifest")
struct RelayAssetManifestTests {
  private let catalog = RelayAssetCatalog.bundled

  @Test("contains the exact stable four-platform matrix")
  func exactMatrix() {
    #expect(catalog.schemaVersion == 1)
    #expect(catalog.relayProtocolVersion == 1)
    #expect(
      catalog.assets.map(\.platform) == [
        RelayRemotePlatform(operatingSystem: .darwin, architecture: .amd64),
        RelayRemotePlatform(operatingSystem: .darwin, architecture: .arm64),
        RelayRemotePlatform(operatingSystem: .linux, architecture: .amd64),
        RelayRemotePlatform(operatingSystem: .linux, architecture: .arm64),
      ])
    #expect(Set(catalog.assets.map(\.fileName)).count == 4)
    #expect(Set(catalog.assets.map(\.bundleLocation)).count == 4)
  }

  @Test(
    "normalizes documented uname handoff values",
    arguments: [
      ("Darwin", "x86_64", "relux-relay-darwin-amd64"),
      ("macOS", "amd64", "relux-relay-darwin-amd64"),
      ("darwin\n", "aarch64\n", "relux-relay-darwin-arm64"),
      ("Linux", "x86_64", "relux-relay-linux-amd64"),
      ("linux", "amd64", "relux-relay-linux-amd64"),
      ("LINUX", "aarch64", "relux-relay-linux-arm64"),
      ("linux\n", "arm64\n", "relux-relay-linux-arm64"),
    ])
  func normalization(osName: String, machineName: String, fileName: String) throws {
    #expect(
      try catalog.asset(
        operatingSystemName: osName,
        machineHardwareName: machineName
      ).fileName == fileName)
  }

  @Test("rejects unsupported handoff values")
  func unsupportedValues() {
    #expect(throws: RelayAssetLookupError.unsupportedOperatingSystem) {
      try catalog.asset(operatingSystemName: "FreeBSD", machineHardwareName: "amd64")
    }
    #expect(throws: RelayAssetLookupError.unsupportedArchitecture) {
      try catalog.asset(operatingSystemName: "Linux", machineHardwareName: "riscv64")
    }
  }

  @Test("binds every entry to immutable identity and provenance metadata")
  func identityAndProvenance() {
    #expect(catalog.buildProvenance.kind == "taskBoardResource")
    #expect(catalog.buildProvenance.taskID == "TASK-260715-24icoz")
    #expect(
      catalog.buildProvenance.archiveSHA256
        == "1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e")
    #expect(catalog.supplyChain.kind == "repositoryGenerated")
    #expect(catalog.supplyChain.taskID == "TASK-260715-vtot05")
    #expect(catalog.supplyChain.manifestLinkageSHA256.count == 64)
    #expect(catalog.supplyChain.provenanceSHA256.count == 64)
    #expect(catalog.supplyChain.inventorySHA256.count == 64)
    #expect(catalog.supplyChain.noticesSHA256.count == 64)

    for asset in catalog.assets {
      #expect(asset.byteSize > 0)
      #expect(asset.sha256.count == 64)
      #expect(asset.relayProtocolVersion == 1)
      #expect(asset.buildIdentity.schemaVersion == 1)
      #expect(asset.buildIdentity.relayProtocolVersion == 1)
      #expect(asset.buildIdentity.relayVersion == "0.1.0")
      #expect(
        asset.buildIdentity.sourceCommit == "58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096")
      #expect(asset.buildIdentity.operatingSystem == asset.platform.operatingSystem)
      #expect(asset.buildIdentity.architecture == asset.platform.architecture)
      #expect(asset.buildIdentity.selfSHA256 == asset.sha256)
      #expect(asset.buildProvenanceReference == "#/buildProvenance")
      #expect(asset.sourceProvenanceReference == "#/supplyChain")
      #expect(asset.bundleLocation == "relay-assets-v1/\(asset.fileName)")
    }
  }
}
