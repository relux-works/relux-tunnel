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

private var generatedSchemeNames: [String] {
  switch workspaceMode {
  case .macOSOnly:
    macOSOnlySchemeNames
  case .macOSAndIOS:
    macOSOnlySchemeNames + deferredSchemeNames
  }
}

private func foundationScheme(named name: String) -> Scheme {
  .scheme(name: name, shared: true)
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
  targets: [],
  schemes: generatedSchemeNames.map { foundationScheme(named: $0) },
  additionalFiles: [
    "Configuration/Base.xcconfig",
    "Configuration/Debug.xcconfig",
    "Configuration/Identity.xcconfig",
    "Configuration/Provider-Debug.xcconfig",
    "Configuration/Provider-Release.xcconfig",
    "Configuration/Release.xcconfig",
    "Configuration/Signing.example.xcconfig",
    "Configuration/Versions.xcconfig",
    "Package.swift",
  ]
)
