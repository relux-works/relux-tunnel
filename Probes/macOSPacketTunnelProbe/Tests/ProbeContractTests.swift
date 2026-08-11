import Foundation
import Testing

@Test
func requestRoundTripsWithExactVersion() throws {
  let encoded = try ProbeContract.encoder.encode(ProbeRequest())
  let decoded = try ProbeContract.decoder.decode(ProbeRequest.self, from: encoded)

  #expect(decoded.protocolIdentifier == ProbeContract.identifier)
  #expect(decoded.protocolVersion == 1)
  #expect(decoded.command == .getStatus)
}

@Test
func providerResponseIsVersionedAndNeverForwardsPackets() throws {
  let request = try ProbeContract.encoder.encode(ProbeRequest())
  let encodedResponse = try ProbeMessageResponder.response(
    to: request,
    providerBundleIdentifier: "works.relux.tunnel.probe.mac.tunnel"
  )
  let response = try ProbeContract.decoder.decode(ProbeResponse.self, from: encodedResponse)

  #expect(response.protocolVersion == 1)
  #expect(response.lifecycleState == .running)
  #expect(response.packetForwarding == false)
  #expect(response.providerBundleIdentifier == "works.relux.tunnel.probe.mac.tunnel")
}

@Test
func requestRejectsProtocolVersionDrift() {
  let drifted = Data(
    #"{"command":"getStatus","protocolIdentifier":"works.relux.packet-tunnel-probe","protocolVersion":2}"#
      .utf8
  )

  #expect(throws: ProbeWireError.self) {
    try ProbeContract.decoder.decode(ProbeRequest.self, from: drifted)
  }
}

@Test
func responderRejectsOversizedMessages() {
  let oversized = Data(repeating: 0, count: ProbeContract.maximumMessageSize + 1)

  #expect(throws: ProbeWireError.oversizedMessage) {
    try ProbeMessageResponder.response(
      to: oversized,
      providerBundleIdentifier: "works.relux.tunnel.probe.mac.tunnel"
    )
  }
}
