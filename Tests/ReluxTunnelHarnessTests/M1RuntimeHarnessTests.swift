import Foundation
import ReluxTunnelCore
import Testing

@testable import ReluxTunnelHarnessSupport

@Suite("M1 composed runtime harness", .serialized)
struct M1RuntimeHarnessTests {
  @Test("production command completes traffic, diagnostics, host-loss, stop, and repeated cleanup")
  func successfulComposedGenerations() async throws {
    let response = await runM1(scenario: .success, repetitions: 3)

    #expect(response.exitCode == .success)
    #expect(response.standardError.isEmpty)
    let result = try JSONDecoder().decode(
      HarnessResultDocument.self,
      from: response.standardOutput
    )
    #expect(result.command == "m1-runtime")
    #expect(result.status == "succeeded")
    #expect(result.configuration.profileReference == "<redacted>")
    #expect(result.metrics.counters["harness.m1.generations_total"] == 3)
    #expect(result.metrics.counters["harness.m1.tcp_fixture_exchanges_total"] == 3)
    #expect(result.metrics.counters["harness.m1.dns_fixture_exchanges_total"] == 3)
    #expect(result.metrics.gauges["harness.m1.descriptor_growth"] == 0)
    #expect(result.metrics.gauges["harness.m1.task_growth"] == 0)
    #expect(result.metrics.gauges["harness.m1.channel_growth"] == 0)
    #expect(result.metrics.gauges["harness.m1.socket_growth"] == 0)
    #expect(result.metrics.gauges["harness.m1.native_runtime_growth"] == 0)
    #expect(result.metrics.gauges["harness.m1.host_owner_retained"] == 0)
    #expect(!String(decoding: response.standardOutput, as: UTF8.self).contains(profileUUID))
  }

  @Test("production command emits stable codes for every mandatory failure scenario")
  func stableFailureExitCodes() async {
    let cases: [(M1RuntimeHarnessScenario, HarnessExitCode)] = [
      (.authenticationFailure, .m1AuthenticationFailure),
      (.packetFailure, .m1PacketFailure),
      (.dnsFailure, .m1DNSFailure),
      (.routeApplyFailure, .m1RouteApplyFailure),
      (.midSessionSSHFailure, .m1MandatoryFailure),
      (.midSessionDNSFailure, .m1MandatoryFailure),
    ]

    for (scenario, exitCode) in cases {
      let response = await runM1(scenario: scenario, repetitions: 1)
      #expect(response.exitCode == exitCode, "scenario: \(scenario.rawValue)")
      #expect(response.standardOutput.isEmpty)
      #expect(response.standardError == "m1-runtime injected \(scenario.rawValue)\n")
      #expect(!response.standardError.contains(profileUUID))
    }
  }

  @Test(
    "HarnessApplication.run requires coordinator-observed SSH loss before mandatory exit"
  )
  func productionEntryRequiresSSHHealthDelivery() async {
    let response = await runM1(scenario: .midSessionSSHFailure, repetitions: 1)

    #expect(response.exitCode == .m1MandatoryFailure)
    #expect(response.standardError == "m1-runtime injected mid-session-ssh-failure\n")
  }

  @Test(
    "HarnessApplication.run requires coordinator-observed DNS loss before mandatory exit"
  )
  func productionEntryRequiresDNSHealthDelivery() async {
    let response = await runM1(scenario: .midSessionDNSFailure, repetitions: 1)

    #expect(response.exitCode == .m1MandatoryFailure)
    #expect(response.standardError == "m1-runtime injected mid-session-dns-failure\n")
  }

  @Test(
    "HarnessApplication.run forwards after releasing its real composition bootstrap owner"
  )
  func productionEntryDoesNotRetainOrConsultHostOwner() async throws {
    let response = await runM1(scenario: .success, repetitions: 1)

    #expect(response.exitCode == .success)
    let result = try JSONDecoder().decode(
      HarnessResultDocument.self,
      from: response.standardOutput
    )
    #expect(result.metrics.counters["harness.m1.tcp_fixture_exchanges_total"] == 1)
    #expect(result.metrics.counters["harness.m1.dns_fixture_exchanges_total"] == 1)
    #expect(result.metrics.gauges["harness.m1.host_owner_retained"] == 0)
  }

  @Test(
    "HarnessApplication.run production gate admits exact repetition bound and rejects narrower violations"
  )
  func productionConfigurationGate() async {
    let maximum = await runM1(scenario: .success, repetitions: 8)
    #expect(maximum.exitCode == .success)

    let aboveMaximum = await runM1(
      scenario: .success,
      repetitions: 9
    )
    #expect(aboveMaximum.exitCode == .usage)
    #expect(aboveMaximum.standardError == "m1-runtime repetitions must be in 1...8\n")

    let unknown = await runM1(
      configuration: configuration(scenarioValue: "general-udp", repetitions: 1)
    )
    #expect(unknown.exitCode == .usage)
    #expect(unknown.standardError == "m1-runtime unsupported scenario\n")

    let hiddenControl = await runM1(
      configuration: configuration(
        scenarioValue: M1RuntimeHarnessScenario.success.rawValue,
        repetitions: 1,
        scenarioPrivacy: .sensitive
      )
    )
    #expect(hiddenControl.exitCode == .usage)
    #expect(hiddenControl.standardError == "m1-runtime control parameters must be public\n")

    let exposedProfile = await runM1(
      configuration: configuration(
        scenarioValue: M1RuntimeHarnessScenario.success.rawValue,
        repetitions: 1,
        profilePrivacy: .public
      )
    )
    #expect(exposedProfile.exitCode == .usage)
    #expect(exposedProfile.standardError == "m1-runtime profile reference must be sensitive\n")

    let repeatedFault = await runM1(scenario: .dnsFailure, repetitions: 2)
    #expect(repeatedFault.exitCode == .usage)
    #expect(repeatedFault.standardError == "m1-runtime failure scenarios require repetitions=1\n")

    let missingRevision = await runM1(
      configuration: configuration(
        scenarioValue: M1RuntimeHarnessScenario.success.rawValue,
        repetitions: 1,
        dependencyRevisions: ["runtime-contract": "m1-v1"]
      )
    )
    #expect(missingRevision.exitCode == .usage)
    #expect(missingRevision.standardError == "m1-runtime required dependency revision is missing\n")
  }
}

private let profileUUID = "11111111-1111-1111-1111-111111111111"

private func runM1(
  scenario: M1RuntimeHarnessScenario,
  repetitions: Int
) async -> HarnessApplicationResponse {
  await runM1(
    configuration: configuration(
      scenarioValue: scenario.rawValue,
      repetitions: repetitions
    )
  )
}

private func runM1(
  configuration: HarnessConfigurationDocument
) async -> HarnessApplicationResponse {
  let metrics = HarnessMetricsStore()
  let dependencies = HarnessCommandDependencies(
    runtime: TunnelRuntimeDependencies(
      clock: ContinuousTunnelClock(),
      logger: SilentHarnessLogger(),
      metrics: metrics,
      cancellation: TaskCancellationChecker(),
      memoryPressure: NormalHarnessMemoryPressureSource()
    ),
    sshTransports: UnavailableHarnessSSHTransportFactory(),
    packetEndpoints: M1RuntimeHarnessPacketEndpointFactory(),
    faultPolicy: NoHarnessFaultPolicy()
  )
  let application = HarnessApplication(
    registry: try! HarnessCommandRegistry(commands: [M1RuntimeHarnessCommand()]),
    dependencies: dependencies,
    readPlatform: {
      HarnessPlatformMetadata(
        operatingSystem: "fixture",
        operatingSystemVersion: "1",
        architecture: "fixture"
      )
    }
  )
  let data = try! HarnessConfigurationCodec.encode(configuration)
  return await application.run(
    arguments: ["m1-runtime", "--configuration-json", String(decoding: data, as: UTF8.self)],
    cancellationSource: StreamHarnessCancellationSource()
  )
}

private func configuration(
  scenarioValue: String,
  repetitions: Int,
  scenarioPrivacy: HarnessConfigurationPrivacy = .public,
  profilePrivacy: HarnessConfigurationPrivacy = .sensitive,
  dependencyRevisions: [String: String] = [
    "fixture-manifest": "TASK-260715-m8bi8i-v1",
    "packet-bridge": "M0-accepted",
    "runtime-contract": "M1-v1",
  ]
) -> HarnessConfigurationDocument {
  HarnessConfigurationDocument(
    seed: 26_071_508,
    sourceRevision: "TASK-260715-m8bi8i",
    dependencyRevisions: dependencyRevisions,
    profileReference: HarnessConfigurationValue(
      value: profileUUID,
      privacy: profilePrivacy
    ),
    parameters: [
      "scenario": HarnessConfigurationValue(value: scenarioValue, privacy: scenarioPrivacy),
      "repetitions": HarnessConfigurationValue(
        value: String(repetitions),
        privacy: .public
      ),
    ]
  )
}
