import Foundation
import ReluxTunnelCore
import Testing

@testable import ReluxTunnelLibSSH2Adapter

/// Candidate selection is test data. Every row is dispatched through the same
/// driver surface; a candidate without an adapter is retained as explicit red
/// evidence instead of being replaced by a green fixture implementation.
extension LibSSH2AdapterIntegrationTests {
  @Suite("Tier-1 candidate-neutral SSH transport conformance", .serialized)
  struct SSHTransportConformanceTests {
    @Test(
      "every M0 viability gate",
      arguments: SSHConformanceCandidate.allCases,
      SSHM0Gate.allCases
    )
    func mandatoryGate(candidate: SSHConformanceCandidate, gate: SSHM0Gate) async throws {
      try await candidate.run(gate)
    }

    @Test(
      "every M3 deferred semantic has an explicit evidence state",
      arguments: SSHConformanceCandidate.allCases
    )
    func deferredStates(candidate: SSHConformanceCandidate) async throws {
      try await candidate.runDeferredStateContract()
    }

    @Test(
      "every cancellation and timeout cleanup scope",
      arguments: SSHConformanceCandidate.allCases,
      SSHCancellationSite.allCases
    )
    func cancellationSite(
      candidate: SSHConformanceCandidate,
      site: SSHCancellationSite
    ) async throws {
      try await candidate.runCancellation(site)
    }
  }
}

enum SSHConformanceCandidate: String, CaseIterable, CustomTestStringConvertible, Sendable {
  case libSSH2Adapter
  case reluxNIOSSHAdapterUnavailable

  var testDescription: String { rawValue }

  func run(_ gate: SSHM0Gate) async throws {
    switch self {
    case .libSSH2Adapter:
      try await LibSSH2ConformanceDriver().run(gate)
    case .reluxNIOSSHAdapterUnavailable:
      withKnownIssue(
        "ReluxNIOSSH has no SSHTransport adapter target; candidate remains red without emulation"
      ) {
        Issue.record(
          "\(gate.rawValue) cannot run: production ReluxNIOSSHAdapter is absent; adapter delivery is owned outside this test task"
        )
      }
    }
  }

  func runDeferredStateContract() async throws {
    switch self {
    case .libSSH2Adapter:
      let capabilities = LibSSH2TransportFactory().capabilities.deferredSemantics
      #expect(capabilities.consumerDrivenReceiveWindowCredit == .unsupported)
      #expect(capabilities.rfcChannelOpenFailureReasons == .unsupported)
      #expect(capabilities.exactExecExitMetadata == .unsupported)
      #expect(capabilities.deepRekeyAndKeepaliveObservability == .unsupported)
      for requirement in [
        SSHConformanceRequirement.consumerDrivenReceiveWindowCredit,
        .rfcChannelOpenFailureReasons,
        .exactExecExitMetadata,
        .deepRekeyAndKeepaliveObservability,
      ] {
        #expect(requirement.tier == .m3Deferred(ownerTaskID: "TASK-260728-3cveay"))
      }
      try await LibSSH2AdapterIntegrationTests().deferredRuntimeStatesAreExplicit()
      try await LibSSH2AdapterIntegrationTests().rejectedOpenPreservesExistingSibling()
      LibSSH2BridgeTests().deferredCapabilitiesAreNeverFabricated()
    case .reluxNIOSSHAdapterUnavailable:
      withKnownIssue(
        "ReluxNIOSSH cannot disclose runtime deferred states until its SSHTransport adapter exists"
      ) {
        Issue.record(
          "all four M3 states are red at the adapter boundary; exact-value work remains mapped to TASK-260728-3cveay"
        )
      }
    }
  }

  func runCancellation(_ site: SSHCancellationSite) async throws {
    switch self {
    case .libSSH2Adapter:
      try await LibSSH2ConformanceDriver().runCancellation(site)
    case .reluxNIOSSHAdapterUnavailable:
      withKnownIssue(
        "ReluxNIOSSH has no SSHTransport adapter target; candidate remains red without emulation"
      ) {
        Issue.record("\(site.rawValue) cleanup cannot run without the production adapter")
      }
    }
  }
}

enum SSHM0Gate: String, CaseIterable, CustomTestStringConvertible, Sendable {
  case appleIntegrationAndInjection
  case approvedAlgorithmsAndHostBeforeAuthentication
  case directExecUploadAndChannelIsolation
  case boundedBuffersBackpressureAndWindows
  case clientAndServerRekey
  case keepaliveSchedulingAndFailure
  case lifecycleResourceBaselines
  case privacySafeErrors
  case mandatoryMetrics

  var testDescription: String { rawValue }
}

enum SSHCancellationSite: String, CaseIterable, CustomTestStringConvertible, Sendable {
  case resolution
  case connect
  case initialKeyExchange
  case hostDecision
  case credentialLookup
  case authentication
  case channelOpen
  case read
  case write
  case eof
  case exec
  case upload
  case rekey
  case keepalive
  case close

  var testDescription: String { rawValue }
}

private struct LibSSH2ConformanceDriver {
  private let integration = LibSSH2AdapterIntegrationTests()
  private let bridge = LibSSH2BridgeTests()

  func run(_ gate: SSHM0Gate) async throws {
    switch gate {
    case .appleIntegrationAndInjection:
      #expect(LibSSH2PackagingAnchor.linkageSmoke())
      let capabilities = LibSSH2TransportFactory().capabilities
      #expect(capabilities.features == Set(SSHAdapterFeature.allCases))

    case .approvedAlgorithmsAndHostBeforeAuthentication:
      try await integration.mandatoryHostPolicyOrdering()
      try await integration.approvedAlgorithmCompatibilityMatrix()
      try await integration.ed25519ExternalSignerAuthentication()
      try await integration.disallowedCredentialAlgorithm()
      try await integration.serverRejectsUnapprovedPublicKey()

    case .directExecUploadAndChannelIsolation:
      try await integration.successfulM0FlowsAndLifecycleBaseline()
      try await integration.channelScopedFailureCleanup()
      try await integration.rejectedOpenPreservesExistingSibling()
      try await integration.concurrentSameChannelWrites()

    case .boundedBuffersBackpressureAndWindows:
      try await bridge.boundedOutboundBridge()
      try await bridge.boundedInboundBridge()
      try await bridge.concurrentSocketProgressIsSerialized()
      try await bridge.sessionOperationGateIsSerializedAndBounded()
      try await integration.channelOperationPressureIsBounded()

    case .clientAndServerRekey:
      try await integration.automaticProtectedByteRekey()
      try await integration.automaticElapsedTimeRekey()
      try await integration.serverInitiatedRekeyPreservesActiveTraffic()
      try await integration.rekeyCoalescingAndOpenScheduling()
      try await integration.rekeyAdmissionUsesBoundedDeadline()

    case .keepaliveSchedulingAndFailure:
      try await integration.automaticKeepaliveSurvivesLongRekey()
      try await integration.automaticKeepaliveFatalFailureDoesNotSelfJoinTeardown()
      try await integration.socketFailureDuringKeepaliveOwnsTeardown()

    case .lifecycleResourceBaselines:
      try await bridge.repeatedHandshakeCleanup()
      try await integration.channelClosePressureReturnsBaseline()
      try await integration.successfulM0FlowsAndLifecycleBaseline()

    case .privacySafeErrors:
      try await integration.productionPublicDiagnosticsExcludePrivacySentinels()
      try await integration.socketFailureDuringOpenOwnsTeardown()
      try await integration.socketFailureDuringReadOwnsTeardown()
      try await integration.socketFailureDuringWriteOwnsTeardown()
      try await integration.socketFailureDuringKeepaliveOwnsTeardown()

    case .mandatoryMetrics:
      try await integration.mandatoryMetricsReconcile()
    }
  }

  func runCancellation(_ site: SSHCancellationSite) async throws {
    // Each row exercises the real adapter's corresponding owned cleanup scope.
    // Where the operation is driven by an injected deadline, the timeout path
    // invokes the same cancellation handler and teardown join as caller cancel.
    switch site {
    case .resolution:
      try await bridge.repeatedConnectCancellation()
    case .connect:
      try await bridge.lateConnectorResultIsClosed()
    case .initialKeyExchange:
      try await bridge.repeatedHandshakeCleanup()
    case .hostDecision:
      try await integration.hostDecisionCancellationRestoresBaseline()
    case .credentialLookup:
      try await integration.credentialLookupCancellationRestoresBaseline()
    case .authentication:
      try await integration.authenticationTimeoutCancelsSigner()
    case .channelOpen:
      try await integration.channelOpenCancellationRestoresBaseline()
    case .read:
      try await integration.operationScopedReadCancellationWithoutIdleTimeout()
    case .write:
      try await integration.writeAndEOFCancellationRestoreBaseline()
    case .eof:
      try await integration.writeAndEOFCancellationRestoreBaseline()
    case .exec:
      try await integration.execRequestCancellationRestoresBaseline()
    case .upload:
      try await integration.nonCooperativeUploadSourceTimeout()
    case .rekey:
      try await integration.rekeyCoalescingAndOpenScheduling()
    case .keepalive:
      try await integration.keepaliveCancellationRestoresBaseline()
    case .close:
      try await integration.connectedNonCooperativeSocketCloseEventuallyRestoresBaseline()
    }
  }
}
