// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "ReluxTunnel",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "ReluxTunnelCore", targets: ["ReluxTunnelCore"]),
    .library(name: "ReluxTunnelNativeAdapter", targets: ["ReluxTunnelNativeAdapter"]),
    .library(name: "ReluxTunnelIOSAdapter", targets: ["ReluxTunnelIOSAdapter"]),
    .library(name: "ReluxTunnelMacOSAdapter", targets: ["ReluxTunnelMacOSAdapter"]),
    .executable(name: "ReluxTunnelHarness", targets: ["ReluxTunnelHarness"]),
  ],
  targets: [
    .target(name: "ReluxTunnelCore"),
    .binaryTarget(
      name: "CReluxNativeFixture",
      path: "NativeDependencies/Artifacts/ReluxNativeFixture.xcframework"
    ),
    .binaryTarget(
      name: "HevSocks5Tunnel",
      path: "NativeDependencies/Artifacts/HevSocks5Tunnel.xcframework"
    ),
    .binaryTarget(
      name: "ReluxLibSSH2",
      path: "NativeDependencies/Artifacts/ReluxLibSSH2.xcframework"
    ),
    .target(
      name: "ReluxTunnelNativeAdapter",
      dependencies: [
        "ReluxTunnelCore",
        "CReluxNativeFixture",
        "HevSocks5Tunnel",
      ]
    ),
    .target(
      name: "ReluxTunnelIOSAdapter",
      dependencies: [
        "ReluxTunnelCore",
        "ReluxTunnelNativeAdapter",
      ]
    ),
    .target(
      name: "ReluxTunnelMacOSAdapter",
      dependencies: [
        "ReluxTunnelCore",
        "ReluxTunnelNativeAdapter",
      ]
    ),
    .target(
      name: "ReluxTunnelHarnessSupport",
      dependencies: [
        "ReluxTunnelCore",
        "ReluxTunnelNativeAdapter",
      ]
    ),
    .executableTarget(
      name: "ReluxTunnelHarness",
      dependencies: [
        "ReluxTunnelCore",
        "ReluxTunnelHarnessSupport",
      ]
    ),
    .testTarget(
      name: "ReluxTunnelCoreTests",
      dependencies: [
        "ReluxTunnelCore",
        "ReluxTunnelIOSAdapter",
        "ReluxTunnelMacOSAdapter",
      ]
    ),
    .testTarget(
      name: "ReluxTunnelHarnessTests",
      dependencies: [
        "ReluxTunnelCore",
        "ReluxTunnelHarnessSupport",
      ]
    ),
    .testTarget(
      name: "ReluxTunnelNativeAdapterTests",
      dependencies: [
        "ReluxTunnelCore",
        "ReluxTunnelMacOSAdapter",
        "ReluxTunnelNativeAdapter",
      ]
    ),
    .testTarget(
      name: "ReluxLibSSH2PackagingTests",
      dependencies: ["ReluxLibSSH2"],
      linkerSettings: [
        .linkedFramework("Security"),
        .linkedFramework("CoreFoundation"),
      ]
    ),
  ]
)
