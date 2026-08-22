import ProjectDescription

private enum WorkspaceMode {
  case macOSOnly
  case macOSAndIOS
}

// ADR-024/ADR-027 keep the iOS product deferred. The cross-platform fixture hosts
// below are isolated test products: they do not embed a provider or depend on a
// production adapter, and the iOS row runs only in Simulator.
private let workspaceMode: WorkspaceMode = .macOSOnly

private let macOSOnlySchemeNames = [
  "ReluxProxyMac",
  "ReluxProxyMacTunnel",
  "ReluxTunnelCore",
  "ReluxTunnelHarness",
  "relux-relay",
  "relux-relay-protocol-test",
  "ReluxProxyMacUITests",
  "ReluxProxyIOSUITests",
]

private let deferredSchemeNames = [
  "ReluxProxyIOS",
  "ReluxProxyIOSTunnel",
]

private let macOSDeploymentTargets: DeploymentTargets = .macOS("15.0")
private let iOSDeploymentTargets: DeploymentTargets = .iOS("18.0")
private let verifiedRelayBundleInput: Path = ".build/relay/relay-assets-v1"

private func targetSettings(
  debugXCConfig: Path,
  releaseXCConfig: Path,
  additionalBaseSettings: SettingsDictionary = [:]
) -> Settings {
  .settings(
    base: [
      "SWIFT_STRICT_CONCURRENCY": "complete",
      "SWIFT_VERSION": "6.0",
    ].merging(additionalBaseSettings) { _, additional in additional },
    configurations: [
      .debug(name: "Debug", xcconfig: debugXCConfig),
      .release(name: "Release", xcconfig: releaseXCConfig),
    ],
    defaultSettings: .recommended
  )
}

private let testTargetSettings: Settings = .settings(
  base: [
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_VERSION": "6.0",
  ],
  defaultSettings: .recommended
)

private let macOSTargets: [Target] = [
  .target(
    name: "ReluxProxyMac",
    destinations: [.mac],
    product: .app,
    bundleId: "$(RELUX_MACOS_HOST_BUNDLE_ID)",
    deploymentTargets: macOSDeploymentTargets,
    infoPlist: "App/ReluxProxyMac/Info.plist",
    sources: [
      "App/ReluxProxyMac/Sources/**",
      "App/Shared/**",
    ],
    dependencies: [
      .target(name: "ReluxProxyMacTunnel"),
      .package(product: "ReluxAppleUITestShared"),
      .package(product: "ReluxTunnelCore"),
    ],
    settings: targetSettings(
      debugXCConfig: "Configuration/MacHost-Debug.xcconfig",
      releaseXCConfig: "Configuration/MacHost-Release.xcconfig"
    )
  ),
  .target(
    name: "ReluxProxyMacTunnel",
    destinations: [.mac],
    product: .systemExtension,
    bundleId: "$(RELUX_MACOS_PROVIDER_BUNDLE_ID)",
    deploymentTargets: macOSDeploymentTargets,
    infoPlist: "App/ReluxProxyMacTunnel/Info.plist",
    sources: [
      "App/ReluxProxyMacTunnel/Sources/**",
      "App/Shared/**",
    ],
    resources: [
      .folderReference(path: verifiedRelayBundleInput)
    ],
    dependencies: [
      .package(product: "ReluxTunnelMacOSAdapter")
    ],
    settings: targetSettings(
      debugXCConfig: "Configuration/MacProvider-Debug.xcconfig",
      releaseXCConfig: "Configuration/MacProvider-Release.xcconfig",
      additionalBaseSettings: [
        "PRODUCT_NAME": "$(RELUX_MACOS_PROVIDER_BUNDLE_ID)"
      ]
    )
  ),
  .target(
    name: "ReluxProxyMacTests",
    destinations: [.mac],
    product: .unitTests,
    bundleId: "$(RELUX_MACOS_HOST_BUNDLE_ID).tests",
    deploymentTargets: macOSDeploymentTargets,
    infoPlist: "Tests/ReluxProxyTargetContractSupport/Info.plist",
    sources: [
      "Tests/ReluxProxyMacTests/**",
      "Tests/ReluxProxyTargetContractSupport/**",
      "App/Shared/**",
    ],
    dependencies: [.package(product: "ReluxTunnelCore")],
    settings: testTargetSettings
  ),
  .target(
    name: "ReluxProxyMacTunnelTests",
    destinations: [.mac],
    product: .unitTests,
    bundleId: "$(RELUX_MACOS_PROVIDER_BUNDLE_ID).tests",
    deploymentTargets: macOSDeploymentTargets,
    infoPlist: "Tests/ReluxProxyTargetContractSupport/Info.plist",
    sources: [
      "Tests/ReluxProxyMacTunnelTests/**",
      "Tests/ReluxProxyTargetContractSupport/**",
      "App/Shared/**",
    ],
    dependencies: [.package(product: "ReluxTunnelCore")],
    settings: testTargetSettings
  ),
]

private let appleUITestInfrastructureTargets: [Target] = [
  .target(
    name: "ReluxProxyMacUITestFixtureHost",
    destinations: [.mac],
    product: .app,
    bundleId: "works.relux.tunnel.uitest-fixture.mac",
    deploymentTargets: macOSDeploymentTargets,
    infoPlist: .extendingDefault(with: [
      "CFBundleDisplayName": "Relux UI Fixture"
    ]),
    sources: ["App/ReluxUITestFixtureHost/**"],
    dependencies: [.package(product: "ReluxAppleUITestShared")],
    settings: testTargetSettings
  ),
  .target(
    name: "ReluxProxyMacUITests",
    destinations: [.mac],
    product: .uiTests,
    bundleId: "works.relux.tunnel.uitests.mac",
    deploymentTargets: macOSDeploymentTargets,
    infoPlist: .default,
    sources: ["Tests/ReluxAppleUITestsShared/**"],
    dependencies: [
      .target(name: "ReluxProxyMacUITestFixtureHost"),
      .package(product: "ReluxAppleUITestShared"),
    ],
    settings: testTargetSettings
  ),
  .target(
    name: "ReluxProxyIOSUITestFixtureHost",
    destinations: [.iPhone],
    product: .app,
    bundleId: "works.relux.tunnel.uitest-fixture.ios",
    deploymentTargets: iOSDeploymentTargets,
    infoPlist: .extendingDefault(with: [
      "CFBundleDisplayName": "Relux UI Fixture",
      "UILaunchScreen": [:],
    ]),
    sources: ["App/ReluxUITestFixtureHost/**"],
    dependencies: [.package(product: "ReluxAppleUITestShared")],
    settings: testTargetSettings
  ),
  .target(
    name: "ReluxProxyIOSUITests",
    destinations: [.iPhone],
    product: .uiTests,
    bundleId: "works.relux.tunnel.uitests.ios",
    deploymentTargets: iOSDeploymentTargets,
    infoPlist: .default,
    sources: ["Tests/ReluxAppleUITestsShared/**"],
    dependencies: [
      .target(name: "ReluxProxyIOSUITestFixtureHost"),
      .package(product: "ReluxAppleUITestShared"),
    ],
    settings: testTargetSettings
  ),
]

private var generatedSchemeNames: [String] {
  switch workspaceMode {
  case .macOSOnly:
    macOSOnlySchemeNames
  case .macOSAndIOS:
    macOSOnlySchemeNames + deferredSchemeNames
  }
}

private func foundationScheme(named name: String) -> Scheme {
  switch name {
  case "ReluxProxyMac":
    .scheme(
      name: name,
      shared: true,
      buildAction: .buildAction(targets: ["ReluxProxyMac"]),
      testAction: .targets(["ReluxProxyMacTests", "ReluxProxyMacTunnelTests"]),
      runAction: .runAction(executable: "ReluxProxyMac"),
      archiveAction: .archiveAction(configuration: "Release")
    )
  case "ReluxProxyMacTunnel":
    .scheme(
      name: name,
      shared: true,
      buildAction: .buildAction(targets: ["ReluxProxyMacTunnel"]),
      testAction: .targets(["ReluxProxyMacTunnelTests"])
    )
  case "ReluxProxyMacUITests":
    .scheme(
      name: name,
      shared: true,
      buildAction: .buildAction(targets: [
        "ReluxProxyMacUITestFixtureHost",
        "ReluxProxyMacUITests",
      ]),
      testAction: .targets(["ReluxProxyMacUITests"])
    )
  case "ReluxProxyIOSUITests":
    .scheme(
      name: name,
      shared: true,
      buildAction: .buildAction(targets: [
        "ReluxProxyIOSUITestFixtureHost",
        "ReluxProxyIOSUITests",
      ]),
      testAction: .targets(["ReluxProxyIOSUITests"])
    )
  default:
    .scheme(name: name, shared: true)
  }
}

let project = Project(
  name: "ReluxTunnelApp",
  organizationName: "Relux Works, LLC",
  options: .options(automaticSchemesOptions: .disabled),
  packages: [
    .local(path: ".")
  ],
  settings: .settings(
    configurations: [
      .debug(name: "Debug", xcconfig: "Configuration/Debug.xcconfig"),
      .release(name: "Release", xcconfig: "Configuration/Release.xcconfig"),
    ],
    defaultSettings: .recommended,
    defaultConfiguration: "Debug"
  ),
  targets: macOSTargets + appleUITestInfrastructureTargets,
  schemes: generatedSchemeNames.map { foundationScheme(named: $0) },
  additionalFiles: [
    "Configuration/Base.xcconfig",
    "Configuration/Debug.xcconfig",
    "Configuration/Identity.xcconfig",
    "Configuration/MacHost-Debug.xcconfig",
    "Configuration/MacHost-Release.xcconfig",
    "Configuration/MacProvider-Debug.xcconfig",
    "Configuration/MacProvider-Release.xcconfig",
    "Configuration/Provider-Debug.xcconfig",
    "Configuration/Provider-Release.xcconfig",
    "Configuration/Release.xcconfig",
    "Configuration/Signing.example.xcconfig",
    "Configuration/Versions.xcconfig",
    "Package.swift",
  ]
)
