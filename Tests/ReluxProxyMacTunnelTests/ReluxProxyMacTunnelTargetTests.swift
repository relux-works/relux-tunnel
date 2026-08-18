import Foundation
import ReluxTunnelCore
import Testing

@Suite("ReluxProxyMacTunnel target contract")
struct ReluxProxyMacTunnelTargetTests {
  @Test("provider plist declares the packet-tunnel system extension")
  func infoPlist() throws {
    let plist = try TargetContractSupport.plist(at: "App/ReluxProxyMacTunnel/Info.plist")
    let extensionDictionary = try #require(plist["NetworkExtension"] as? [String: Any])
    let providerClasses = try #require(
      extensionDictionary["NEProviderClasses"] as? [String: String]
    )

    #expect(plist["CFBundleIdentifier"] as? String == "$(PRODUCT_BUNDLE_IDENTIFIER)")
    #expect(plist["CFBundlePackageType"] as? String == "SYSX")
    #expect(plist["CFBundleShortVersionString"] as? String == "$(MARKETING_VERSION)")
    #expect(plist["CFBundleVersion"] as? String == "$(CURRENT_PROJECT_VERSION)")
    #expect(
      providerClasses["com.apple.networkextension.packet-tunnel"]
        == "$(PRODUCT_MODULE_NAME).PacketTunnelProvider")
  }

  @Test("development and Developer ID provider entitlements match r12")
  func entitlements() throws {
    let development = try TargetContractSupport.plist(
      at: "Configuration/Entitlements/ReluxProxyMacTunnel-Development.entitlements"
    )
    let developerID = try TargetContractSupport.plist(
      at: "Configuration/Entitlements/ReluxProxyMacTunnel-DeveloperID.entitlements"
    )
    let expectedKeys: Set<String> = [
      "com.apple.developer.networking.networkextension",
      "com.apple.security.app-sandbox",
      "com.apple.security.network.client",
      "com.apple.security.network.server",
    ]

    #expect(Set(development.keys) == expectedKeys)
    #expect(Set(developerID.keys) == expectedKeys)
    #expect(
      TargetContractSupport.stringArray(
        development,
        key: "com.apple.developer.networking.networkextension"
      ) == ["packet-tunnel-provider"])
    #expect(
      TargetContractSupport.stringArray(
        developerID,
        key: "com.apple.developer.networking.networkextension"
      ) == ["packet-tunnel-provider-systemextension"])
    for entitlements in [development, developerID] {
      #expect(entitlements["com.apple.developer.system-extension.install"] == nil)
      #expect(entitlements["com.apple.security.application-groups"] == nil)
      #expect(entitlements["keychain-access-groups"] == nil)
      #expect(
        entitlements["com.apple.security.temporary-exception.files.absolute-path.read-write"]
          == nil)
    }
  }

  @Test("provider configurations preserve the target-owned entitlement seam")
  func targetOwnedEntitlementConfiguration() throws {
    let identity = try TargetContractSupport.xcconfig(at: "Configuration/Identity.xcconfig")

    #expect(
      identity["RELUX_MACOS_PROVIDER_ENTITLEMENTS"]
        == "Configuration/Entitlements/ReluxProxyMacTunnel-Development.entitlements")
    for configuration in ["Debug", "Release"] {
      let values = try TargetContractSupport.xcconfig(
        at: "Configuration/MacProvider-\(configuration).xcconfig"
      )
      #expect(values["CODE_SIGN_ENTITLEMENTS"] == "$(RELUX_MACOS_PROVIDER_ENTITLEMENTS)")
      #expect(
        values["PROVISIONING_PROFILE_SPECIFIER"]
          == "$(RELUX_MACOS_PROVIDER_PROFILE_SPECIFIER)")
    }
  }

  @Test("provider exposes only compile-only lifecycle and version messaging")
  func minimalLifecycle() throws {
    let source = try TargetContractSupport.text(
      at: "App/ReluxProxyMacTunnel/Sources/PacketTunnelProvider.swift"
    )

    #expect(source.contains("import NetworkExtension"))
    #expect(source.contains("override func startTunnel"))
    #expect(source.contains("override func handleAppMessage"))
    #expect(source.contains("override func stopTunnel"))
    #expect(source.contains("ProviderMessageCodec.response"))
    for forbidden in [
      "packetFlow", "setTunnelNetworkSettings", "readPackets", "SSH", "HEV", "route", "DNS",
    ] {
      #expect(!source.contains(forbidden))
    }
  }

  @Test("version message rejects incompatible requests")
  func versionMessage() throws {
    let request = try ProviderMessageCodec.encodeVersionRequest()
    let response = try ProviderMessageCodec.response(to: request)
    #expect(
      try ProviderMessageCodec.decodeVersionResponse(response).protocolVersion
        == ReluxProxyBuildIdentity.providerProtocolVersion)

    let incompatible = try ProviderMessageCodec.encodeVersionRequest(protocolVersion: 2)
    #expect(throws: ProviderMessageError.unsupportedProtocolVersion(2)) {
      try ProviderMessageCodec.response(to: incompatible)
    }
  }
}
