import CReluxNativeFixture
import Foundation
import ReluxTunnelCore
import ReluxTunnelNativeAdapter
import Testing

@Suite("Native dependency packaging")
struct NativeDependencyPackagingTests {
  @Test("pinned binary fixture is callable beside core contracts")
  func fixtureAndCoreConsumer() {
    let profileID = OpaqueProfileIdentifier(
      UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    )
    let configuration = TunnelConfiguration(
      profileReference: TunnelConfigurationReference(profileIdentifier: profileID)
    )

    #expect(configuration.profileReference.profileIdentifier == profileID)
    #expect(NativeDependencyPackaging.schemaVersion == 1)
    #expect(relux_native_fixture_schema_version() == 1)
    #expect(relux_native_fixture_mix(0) == 0x524C_5854)
    #expect(relux_native_fixture_mix(7) == 0x524C_5853)
  }
}
