import Foundation
import ReluxTunnelCore
import Testing

@Suite("ReluxProxyMac target contract")
struct ReluxProxyMacTargetTests {
  @Test("host plist owns identity version floor and Sparkle launcher seam")
  func infoPlist() throws {
    let plist = try TargetContractSupport.plist(at: "App/ReluxProxyMac/Info.plist")

    #expect(plist["CFBundleIdentifier"] as? String == "$(PRODUCT_BUNDLE_IDENTIFIER)")
    #expect(plist["CFBundlePackageType"] as? String == "APPL")
    #expect(plist["CFBundleShortVersionString"] as? String == "$(MARKETING_VERSION)")
    #expect(plist["CFBundleVersion"] as? String == "$(CURRENT_PROJECT_VERSION)")
    #expect(plist["LSMinimumSystemVersion"] as? String == "$(MACOSX_DEPLOYMENT_TARGET)")
    #expect(plist["SUEnableInstallerLauncherService"] as? Bool == true)
  }

  @Test("development and Developer ID host entitlements match r12")
  func entitlements() throws {
    let development = try TargetContractSupport.plist(
      at: "Configuration/Entitlements/ReluxProxyMac-Development.entitlements"
    )
    let developerID = try TargetContractSupport.plist(
      at: "Configuration/Entitlements/ReluxProxyMac-DeveloperID.entitlements"
    )
    let expectedKeys: Set<String> = [
      "com.apple.developer.networking.networkextension",
      "com.apple.developer.system-extension.install",
      "com.apple.security.app-sandbox",
      "com.apple.security.network.client",
      "com.apple.security.temporary-exception.mach-lookup.global-name",
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
    #expect(
      TargetContractSupport.stringArray(
        development,
        key: "com.apple.security.temporary-exception.mach-lookup.global-name"
      ) == ["$(PRODUCT_BUNDLE_IDENTIFIER)-spks", "$(PRODUCT_BUNDLE_IDENTIFIER)-spki"])
    for entitlements in [development, developerID] {
      #expect(entitlements["com.apple.security.application-groups"] == nil)
      #expect(entitlements["keychain-access-groups"] == nil)
    }
  }

  @Test("host embeds exactly the approved provider target")
  func embedding() throws {
    let project = try TargetContractSupport.text(at: "Project.swift")
    let hostStart = try #require(project.range(of: "name: \"ReluxProxyMac\""))
    let providerDefinitionStart = try #require(
      project.range(
        of: "\n  .target(\n    name: \"ReluxProxyMacTunnel\"",
        range: hostStart.upperBound..<project.endIndex)
    )
    let hostDefinition = String(
      project[hostStart.lowerBound..<providerDefinitionStart.lowerBound]
    )

    #expect(hostDefinition.contains("product: .app"))
    #expect(hostDefinition.contains("bundleId: \"$(RELUX_MACOS_HOST_BUNDLE_ID)\""))
    #expect(
      hostDefinition.components(separatedBy: "name: \"ReluxProxyMacTunnel\"").count - 1 == 1)
    #expect(!hostDefinition.contains("ReluxProxyIOS"))

    let providerDefinition = String(project[providerDefinitionStart.lowerBound...])
    #expect(providerDefinition.contains("product: .systemExtension"))
    #expect(
      providerDefinition.contains("\"PRODUCT_NAME\": \"$(RELUX_MACOS_PROVIDER_BUNDLE_ID)\""))
  }

  @Test("target identities and development profiles match r12")
  func identityMatrix() throws {
    let identity = try TargetContractSupport.xcconfig(at: "Configuration/Identity.xcconfig")
    let signing = try TargetContractSupport.xcconfig(
      at: "Configuration/Signing.example.xcconfig"
    )
    let project = try TargetContractSupport.text(at: "Project.swift")

    #expect(identity["RELUX_MACOS_HOST_BUNDLE_ID"] == "works.relux.tunnel.mac")
    #expect(
      identity["RELUX_MACOS_PROVIDER_BUNDLE_ID"] == "works.relux.tunnel.mac.tunnel")
    #expect(identity["RELUX_DEVELOPMENT_TEAM"] == "262RZ595FP")
    #expect(signing["CODE_SIGN_STYLE"] == "Automatic")
    #expect(
      signing["RELUX_MACOS_HOST_PROFILE_SPECIFIER"]
        == "Mac Team Provisioning Profile: works.relux.tunnel.mac")
    #expect(
      signing["RELUX_MACOS_PROVIDER_PROFILE_SPECIFIER"]
        == "Mac Team Provisioning Profile: works.relux.tunnel.mac.tunnel")
    #expect(
      project.contains("private let macOSDeploymentTargets: DeploymentTargets = .macOS(\"15.0\")"))
  }

  @Test("host configurations preserve the target-owned entitlement seam")
  func targetOwnedEntitlementConfiguration() throws {
    let identity = try TargetContractSupport.xcconfig(at: "Configuration/Identity.xcconfig")

    #expect(
      identity["RELUX_MACOS_HOST_ENTITLEMENTS"]
        == "Configuration/Entitlements/ReluxProxyMac-Development.entitlements")
    for configuration in ["Debug", "Release"] {
      let values = try TargetContractSupport.xcconfig(
        at: "Configuration/MacHost-\(configuration).xcconfig"
      )
      #expect(values["CODE_SIGN_ENTITLEMENTS"] == "$(RELUX_MACOS_HOST_ENTITLEMENTS)")
      #expect(
        values["PROVISIONING_PROFILE_SPECIFIER"]
          == "$(RELUX_MACOS_HOST_PROFILE_SPECIFIER)")
    }
  }

  @Test("host and provider share the Core compatibility version")
  func versionCompatibility() {
    #expect(ReluxProxyBuildIdentity.providerProtocolVersion == ProviderMessageCodec.currentVersion)
    #expect(ReluxProxyBuildIdentity.providerProtocolVersion == 1)
  }
}
