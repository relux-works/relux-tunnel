import SwiftUI

struct ProbeView: View {
  let controller: ProbeController

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Disposable Packet-Tunnel Entitlement Probe")
        .font(.title2)
      Text(
        "No packets are read, forwarded, or routed. The provider only answers one versioned app message."
      )
      .font(.body)
      .foregroundStyle(.secondary)

      LabeledContent("Phase", value: controller.phase.label)
      LabeledContent("VPN status", value: controller.vpnStatus)
      LabeledContent("Provider response", value: controller.providerResponse)

      HStack {
        Button("Save and Reload Configuration") {
          controller.configure()
        }
        .disabled(controller.phase.isBusy)

        Button("Run Probe") {
          controller.runProbe()
        }
        .buttonStyle(.borderedProminent)
        .disabled(controller.phase.isBusy)

        Button("Stop") {
          controller.stop()
        }
        .disabled(!controller.phase.canStop)
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Probe controls")

      Divider()

      Text("Lifecycle")
        .font(.headline)
      ScrollView {
        Text(controller.lifecycleText)
          .font(.system(.body, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
      .accessibilityLabel("Provider lifecycle events")

      if let failure = controller.failure {
        Text("Failure: \(failure)")
          .foregroundStyle(.red)
          .accessibilityLabel("Probe failure: \(failure)")
      }
    }
    .padding(24)
  }
}
