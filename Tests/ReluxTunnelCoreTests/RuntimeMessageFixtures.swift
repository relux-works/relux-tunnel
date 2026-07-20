import Foundation
import ReluxTunnelCore

enum RuntimeMessageFixtures {
  static let profileID = OpaqueProfileIdentifier(
    UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  )
  static let profileRevision = OpaqueProfileRevision(
    UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  )
  static let credentialReference = OpaqueCredentialReference(
    UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  )
  static let trustReference = OpaqueTrustReference(
    UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
  )
  static let requestID = OpaqueRuntimeRequestIdentifier(
    UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
  )

  static let configurationReference = TunnelConfigurationReference(
    profileIdentifier: profileID
  )

  static let startRequest = RuntimeStartRequest(
    configurationReference: configurationReference
  )

  static let configuration = RuntimeConfigurationSnapshot(
    requestID: requestID,
    configurationGeneration: 7,
    profileIdentifier: profileID,
    profileRevision: profileRevision,
    credentialReference: credentialReference,
    trustReference: trustReference
  )

  static let command = RuntimeCommand(kind: .getCapabilities, requestID: requestID)

  static let protocolCapabilities = RuntimeProtocolCapabilitiesSnapshot(
    requestID: requestID,
    kinds: RuntimeMessageKind.allCases.map {
      RuntimeKindCapability(kind: $0, schemaVersions: .currentSchema)
    }
  )

  static let capabilities = RuntimeCapabilitySnapshot(
    requestID: requestID,
    runtimeGeneration: 9,
    snapshotSequence: 3,
    tcp: true,
    safeDNS: true,
    udp: false,
    routeMode: .compatible,
    routesInstalled: true,
    healthy: true
  )

  static let runtimeError = RedactedRuntimeError(
    domain: .sshTransport,
    code: try! RedactedRuntimeErrorCode("session_lost")
  )

  static let lifecycle = RuntimeLifecycleSnapshot(
    requestID: requestID,
    runtimeGeneration: 9,
    snapshotSequence: 4,
    lifecycleState: .connectedDegraded,
    routeState: .installed,
    tcp: true,
    safeDNS: true,
    udp: false,
    routeMode: .compatible,
    routesInstalled: true,
    healthy: true,
    error: nil
  )

  static let diagnostics = RuntimeDiagnosticsSnapshot(
    requestID: requestID,
    runtimeGeneration: 9,
    snapshotSequence: 5,
    counters: ["packets_read": 10],
    gauges: ["active_flows": 2],
    histograms: [
      "dns_latency": RuntimeDiagnosticHistogram(
        unit: .milliseconds,
        buckets: [
          RuntimeDiagnosticBucket(upperBound: 10, count: 3),
          RuntimeDiagnosticBucket(upperBound: 100, count: 7),
        ]
      )
    ],
    errors: [runtimeError]
  )

  static let protocolError = RuntimeProtocolError(
    requestID: requestID,
    code: .unsupportedSchemaVersion
  )
}
