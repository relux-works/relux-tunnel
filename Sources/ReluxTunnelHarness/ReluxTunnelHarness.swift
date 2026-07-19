import Darwin
import Foundation
import ReluxTunnelHarnessSupport

@main
enum ReluxTunnelHarnessMain {
  static func main() async {
    let application = HarnessApplication(
      registry: HarnessDefaults.registry(),
      dependencies: HarnessDefaults.dependencies()
    )
    let response = await application.run(
      arguments: Array(CommandLine.arguments.dropFirst()),
      cancellationSource: SignalHarnessCancellationSource()
    )

    if !response.standardOutput.isEmpty {
      FileHandle.standardOutput.write(response.standardOutput)
    }
    if !response.standardError.isEmpty,
      let errorData = response.standardError.data(using: .utf8)
    {
      FileHandle.standardError.write(errorData)
    }
    Darwin.exit(response.exitCode.rawValue)
  }
}
