// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "ReluxTunnel",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "ReluxAppleUITestShared", targets: ["ReluxAppleUITestShared"]),
    .library(name: "ReluxTunnelCore", targets: ["ReluxTunnelCore"]),
    .library(name: "ReluxTunnelLibSSH2Adapter", targets: ["ReluxTunnelLibSSH2Adapter"]),
    .library(name: "ReluxTunnelNativeAdapter", targets: ["ReluxTunnelNativeAdapter"]),
    .library(name: "ReluxTunnelIOSAdapter", targets: ["ReluxTunnelIOSAdapter"]),
    .library(name: "ReluxTunnelMacOSAdapter", targets: ["ReluxTunnelMacOSAdapter"]),
    .executable(name: "ReluxTunnelHarness", targets: ["ReluxTunnelHarness"]),
    .executable(name: "relux-snapshot-diff", targets: ["ReluxSnapshotDiff"]),
  ],
  targets: [
    .target(name: "ReluxAppleUITestShared"),
    .target(name: "ReluxSnapshotDiffSupport"),
    .executableTarget(
      name: "ReluxSnapshotDiff",
      dependencies: ["ReluxSnapshotDiffSupport"]
    ),
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
      name: "ReluxTunnelLibSSH2Adapter",
      dependencies: [
        "ReluxTunnelCore",
        "ReluxLibSSH2",
      ],
      linkerSettings: [
        .linkedFramework("Security"),
        .linkedFramework("CoreFoundation"),
      ]
    ),
    .target(
      name: "ReluxTunnelNativeAdapter",
      dependencies: [
        "ReluxTunnelCore",
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
        "ReluxTunnelLibSSH2Adapter",
        "ReluxTunnelNativeAdapter",
      ],
      linkerSettings: [.linkedFramework("Security")]
    ),
    .target(
      name: "ReluxTunnelHarnessSupport",
      dependencies: [
        "ReluxTunnelCore",
        "ReluxTunnelLibSSH2Adapter",
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
      name: "ReluxAppleUITestSharedTests",
      dependencies: ["ReluxAppleUITestShared"]
    ),
    .testTarget(
      name: "ReluxSnapshotDiffSupportTests",
      dependencies: ["ReluxSnapshotDiffSupport"]
    ),
    .testTarget(
      name: "ReluxTunnelLibSSH2AdapterTests",
      dependencies: [
        "ReluxTunnelCore",
        "ReluxTunnelLibSSH2Adapter",
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
        "CReluxNativeFixture",
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
