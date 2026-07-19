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
    .library(name: "ReluxTunnelIOSAdapter", targets: ["ReluxTunnelIOSAdapter"]),
    .library(name: "ReluxTunnelMacOSAdapter", targets: ["ReluxTunnelMacOSAdapter"]),
    .executable(name: "ReluxTunnelHarness", targets: ["ReluxTunnelHarness"]),
  ],
  targets: [
    .target(name: "ReluxTunnelCore"),
    .target(name: "ReluxTunnelIOSAdapter", dependencies: ["ReluxTunnelCore"]),
    .target(name: "ReluxTunnelMacOSAdapter", dependencies: ["ReluxTunnelCore"]),
    .target(
      name: "ReluxTunnelHarnessSupport",
      dependencies: ["ReluxTunnelCore"]
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
  ]
)
