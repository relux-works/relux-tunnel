import Foundation
import ReluxTunnelCore

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
    try! HarnessCommandRegistry(commands: [SmokeHarnessCommand()])
  }
}
