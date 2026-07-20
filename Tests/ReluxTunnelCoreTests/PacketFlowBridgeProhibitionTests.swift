import Foundation
import Testing

@Suite("PacketFlowBridge explicit prohibitions")
struct PacketFlowBridgeProhibitionTests {
  @Test("bridge and adapters contain no private utun or descriptor-discovery mechanism")
  func noPrivateDescriptorAccess() throws {
    let source = try productionSource()
    let forbidden = [
      "com.apple.net.utun_control",
      "UTUN_CONTROL_NAME",
      "CTLIOCGINFO",
      "SYSPROTO_CONTROL",
      "getdtablesize(",
      "proc_pidfdinfo(",
      "SCM_RIGHTS",
      "Darwin.dup(",
      "dup2(",
      "F_DUPFD",
      "Task.detached",
    ]

    for token in forbidden {
      #expect(!source.contains(token), "forbidden production token: \(token)")
    }
  }

  @Test("bridge contains no retry queue, side buffer, wall clock, or arbitrary sleep")
  func boundedStorageAndMonotonicSchedulingOnly() throws {
    let bridge = try source(named: "Sources/ReluxTunnelCore/PacketFlowBridge.swift")
    let forbidden = [
      "retryQueue",
      "retryList",
      "overflowCache",
      "sideBuffer",
      "Task.sleep",
      "usleep(",
      "Darwin.sleep(",
      "Date()",
      "CFAbsoluteTimeGetCurrent",
      "DispatchTime.now",
    ]

    for token in forbidden {
      #expect(!bridge.contains(token), "forbidden bridge token: \(token)")
    }
    #expect(bridge.contains("var frame = [UInt8](repeating: 0, count: maximumDatagramBytes)"))
    #expect(bridge.contains("var buffer = [UInt8](repeating: 0, count: maximumDatagramBytes)"))
  }

  @Test("platform adapters use the public readPackets/writePackets boundary")
  func publicPacketFlowBoundaryOnly() throws {
    for path in [
      "Sources/ReluxTunnelIOSAdapter/IOSProviderCompositionRoot.swift",
      "Sources/ReluxTunnelMacOSAdapter/MacOSProviderCompositionRoot.swift",
    ] {
      let adapter = try source(named: path)
      #expect(adapter.contains("packetFlow.readPackets"))
      #expect(adapter.contains("packetFlow.writePackets"))
      #expect(!adapter.contains("value(forKey:"))
      #expect(!adapter.contains("perform(Selector"))
    }
  }

  private func productionSource() throws -> String {
    try [
      "Sources/ReluxTunnelCore/PacketFlowBridge.swift",
      "Sources/ReluxTunnelCore/DarwinPacketBridgeIO.swift",
      "Sources/ReluxTunnelCore/PacketFlowAdapterBoundary.swift",
      "Sources/ReluxTunnelIOSAdapter/IOSProviderCompositionRoot.swift",
      "Sources/ReluxTunnelMacOSAdapter/MacOSProviderCompositionRoot.swift",
    ].map(source(named:)).joined(separator: "\n")
  }

  private func source(named path: String) throws -> String {
    let testFile = URL(fileURLWithPath: #filePath)
    let root =
      testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
  }
}
