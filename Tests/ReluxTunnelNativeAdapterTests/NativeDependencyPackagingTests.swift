import ReluxTunnelCore
import ReluxTunnelNativeAdapter
import Testing

@Suite("Native dependency packaging")
struct NativeDependencyPackagingTests {
  @Test("pinned binary fixture is callable beside core contracts")
  func fixtureAndCoreConsumer() {
    let configuration = TunnelConfiguration(
      profileReference: TunnelConfigurationReference(rawValue: "fixture"),
      parameters: [:]
    )

    #expect(configuration.profileReference.rawValue == "fixture")
    #expect(NativeDependencyPackaging.schemaVersion == 1)
    #expect(NativeDependencyPackaging.smoke(value: 0) == 0x524C_5854)
    #expect(NativeDependencyPackaging.smoke(value: 7) == 0x524C_5853)
  }
}
