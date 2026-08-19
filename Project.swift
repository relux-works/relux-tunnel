import ProjectDescription

private enum WorkspaceMode {
  case macOSOnly
  case macOSAndIOS
}

// ADR-024/ADR-027 keep iOS deferred. The iOS-resume task changes this checked-in
// input only when it adds the corresponding targets and scheme actions.
private let workspaceMode: WorkspaceMode = .macOSOnly

private let macOSOnlySchemeNames = [
  "ReluxProxyMac",
  "ReluxProxyMacTunnel",
  "ReluxTunnelCore",
  "ReluxTunnelHarness",
  "relux-relay",
  "relux-relay-protocol-test",
]

private let deferredSchemeNames = [
  "ReluxProxyIOS",
  "ReluxProxyIOSTunnel",
]

private let macOSDeploymentTargets: DeploymentTargets = .macOS("15.0")
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
  targets: macOSTargets,
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
