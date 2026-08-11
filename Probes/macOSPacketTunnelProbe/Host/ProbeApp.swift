import SwiftUI

@main
struct ReluxPacketTunnelProbeApp: App {
  @State private var controller = ProbeController()

  var body: some Scene {
    WindowGroup("Relux Packet Tunnel Probe") {
      ProbeView(controller: controller)
        .task {
          if CommandLine.arguments.contains("--run-probe") {
            controller.runProbe()
          }
        }
    }
    .defaultSize(width: 680, height: 520)
  }
}
