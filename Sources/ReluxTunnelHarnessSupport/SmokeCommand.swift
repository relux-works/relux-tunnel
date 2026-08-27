import Foundation
import ReluxTunnelCore
import ReluxTunnelLibSSH2Adapter
import ReluxTunnelNativeAdapter

public struct SmokeHarnessCommand: HarnessCommand {
  public let name = "smoke"

  public init() {}

  public func run(context: HarnessCommandContext) async throws {
    try await context.dependencies.faultPolicy.evaluate(.smokeStart)

    let directory = try await context.resources.makeTemporaryDirectory(prefix: "relux-smoke")
    let marker = directory.appendingPathComponent("run.marker")
    try Data("relux-smoke\n".utf8).write(to: marker, options: .atomic)

    let socket = directory.appendingPathComponent("packet.sock")
    try await context.resources.bindUnixDatagramSocket(at: socket)
    await context.resources.startTask {
      do {
        try await context.dependencies.runtime.clock.sleep(for: .seconds(3_600))
      } catch {
        // Cleanup cancellation is the expected task lifetime boundary.
      }
    }

    await context.dependencies.runtime.metrics.incrementCounter(named: "harness.smoke.runs", by: 1)
    await context.dependencies.runtime.metrics.setGauge(
      named: "harness.native_fixture.schema_version",
      to: Int64(NativeDependencyPackaging.schemaVersion)
    )
    _ = NativeDependencyPackaging.hevLinkageSmoke()
    await context.dependencies.runtime.metrics.setGauge(
      named: "harness.hev.linked",
      to: 1
    )
    await context.dependencies.runtime.metrics.setGauge(
      named: "harness.libssh2.linked",
      to: LibSSH2PackagingAnchor.linkageSmoke() ? 1 : 0
    )
    try await context.dependencies.faultPolicy.evaluate(.smokeFinish)
  }
}

public enum HarnessDefaults {
  public static func dependencies() -> HarnessCommandDependencies {
    HarnessCommandDependencies(
      runtime: TunnelRuntimeDependencies(
        clock: ContinuousTunnelClock(),
        logger: SilentHarnessLogger(),
        metrics: HarnessMetricsStore(),
        cancellation: TaskCancellationChecker(),
        memoryPressure: NormalHarnessMemoryPressureSource()
      ),
      sshTransports: UnavailableHarnessSSHTransportFactory(),
      packetEndpoints: UnavailableHarnessPacketEndpointFactory(),
      faultPolicy: NoHarnessFaultPolicy()
    )
  }

  public static func registry() -> HarnessCommandRegistry {
    // The built-in list is explicit so command names stay reviewable and stable.
    try! HarnessCommandRegistry(commands: [SmokeHarnessCommand(), MTUMatrixHarnessCommand()])
  }
}
