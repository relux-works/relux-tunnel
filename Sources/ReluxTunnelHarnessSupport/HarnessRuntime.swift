import Darwin
import Dispatch
import Foundation
import ReluxTunnelCore

public actor HarnessMetricsStore: TunnelMetrics {
  private var counters: [String: UInt64] = [:]
  private var gauges: [String: Int64] = [:]

  public init() {}

  public func incrementCounter(named name: String, by amount: UInt64) {
    counters[name, default: 0] &+= amount
  }

  public func setGauge(named name: String, to value: Int64) {
    gauges[name] = value
  }

  public func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(
      schemaVersion: HarnessMetricSchema.currentVersion,
      counters: counters,
      gauges: gauges
    )
  }
}

public struct SilentHarnessLogger: TunnelLogger {
  public init() {}

  public func log(
    level: TunnelLogLevel,
    message: String,
    fields: [String: TunnelLogField]
  ) {}
}

public struct NormalHarnessMemoryPressureSource: TunnelMemoryPressureSource {
  public init() {}

  public func currentPressure() async -> TunnelMemoryPressure {
    .normal
  }
}

public final class StreamHarnessCancellationSource: HarnessCancellationSource, @unchecked Sendable {
  private let stream: AsyncStream<HarnessCancellationReason>
  private let continuation: AsyncStream<HarnessCancellationReason>.Continuation

  public init() {
    let pair = AsyncStream<HarnessCancellationReason>.makeStream()
    stream = pair.stream
    continuation = pair.continuation
  }

  public func cancel(reason: HarnessCancellationReason) {
    continuation.yield(reason)
    continuation.finish()
  }

  public func waitForCancellation() async -> HarnessCancellationReason {
    for await reason in stream {
      return reason
    }
    return .task
  }
}

public final class SignalHarnessCancellationSource: HarnessCancellationSource, @unchecked Sendable {
  private let source: StreamHarnessCancellationSource
  private let signalSources: [DispatchSourceSignal]

  public init() {
    source = StreamHarnessCancellationSource()
    Darwin.signal(SIGINT, SIG_IGN)
    Darwin.signal(SIGTERM, SIG_IGN)

    let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
    let terminate = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
    interrupt.setEventHandler { [source] in
      source.cancel(reason: .interrupt)
    }
    terminate.setEventHandler { [source] in
      source.cancel(reason: .terminate)
    }
    interrupt.resume()
    terminate.resume()
    signalSources = [interrupt, terminate]
  }

  deinit {
    for signalSource in signalSources {
      signalSource.cancel()
    }
  }

  public func waitForCancellation() async -> HarnessCancellationReason {
    await source.waitForCancellation()
  }
}

public struct HarnessPlatformMetadata: Codable, Equatable, Sendable {
  public let operatingSystem: String
  public let operatingSystemVersion: String
  public let architecture: String

  public init(operatingSystem: String, operatingSystemVersion: String, architecture: String) {
    self.operatingSystem = operatingSystem
    self.operatingSystemVersion = operatingSystemVersion
    self.architecture = architecture
  }

  public static func current() -> Self {
    var system = utsname()
    uname(&system)
    let architecture = withUnsafePointer(to: &system.machine) { pointer in
      pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(cString: $0)
      }
    }
    return Self(
      operatingSystem: "macOS",
      operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
      architecture: architecture
    )
  }
}

public struct HarnessMetricsDocument: Codable, Equatable, Sendable {
  public let schemaVersion: UInt16
  public let counters: [String: UInt64]
  public let gauges: [String: Int64]

  public init(snapshot: TunnelMetricsSnapshot) {
    schemaVersion = snapshot.schemaVersion
    counters = snapshot.counters
    gauges = snapshot.gauges
  }
}

public struct HarnessResultDocument: Codable, Equatable, Sendable {
  public let schemaVersion: UInt16
  public let command: String
  public let status: String
  public let seed: UInt64
  public let sourceRevision: String
  public let dependencyRevisions: [String: String]
  public let configuration: HarnessRecordedConfiguration
  public let durationNanoseconds: UInt64
  public let platform: HarnessPlatformMetadata
  public let metrics: HarnessMetricsDocument

  public init(
    command: String,
    configuration: HarnessConfigurationDocument,
    durationNanoseconds: UInt64,
    platform: HarnessPlatformMetadata,
    metrics: TunnelMetricsSnapshot
  ) {
    schemaVersion = HarnessResultSchema.currentVersion
    self.command = command
    status = "succeeded"
    seed = configuration.seed
    sourceRevision = configuration.sourceRevision
    dependencyRevisions = configuration.dependencyRevisions
    self.configuration = configuration.recordedConfiguration()
    self.durationNanoseconds = durationNanoseconds
    self.platform = platform
    self.metrics = HarnessMetricsDocument(snapshot: metrics)
  }
}

public struct HarnessApplicationResponse: Equatable, Sendable {
  public let exitCode: HarnessExitCode
  public let standardOutput: Data
  public let standardError: String

  public init(exitCode: HarnessExitCode, standardOutput: Data = Data(), standardError: String = "")
  {
    self.exitCode = exitCode
    self.standardOutput = standardOutput
    self.standardError = standardError
  }
}

public enum HarnessArgumentError: Error, Equatable, CustomStringConvertible {
  case missingCommand
  case unknownCommand(String)
  case missingConfiguration
  case missingOptionValue(String)
  case duplicateConfiguration
  case unexpectedArgument(String)

  public var description: String {
    switch self {
    case .missingCommand:
      "missing subcommand"
    case .unknownCommand(let command):
      "unknown subcommand: \(command)"
    case .missingConfiguration:
      "one of --configuration or --configuration-json is required"
    case .missingOptionValue(let option):
      "missing value for \(option)"
    case .duplicateConfiguration:
      "configuration input may be supplied only once"
    case .unexpectedArgument(let argument):
      "unexpected argument: \(argument)"
    }
  }
}

public enum HarnessConfigurationInput: Equatable, Sendable {
  case file(String)
  case json(String)
}

public struct HarnessInvocation: Equatable, Sendable {
  public let command: String
  public let configuration: HarnessConfigurationInput
}

public enum HarnessArgumentParser {
  public static func parse(
    arguments: [String],
    registeredCommands: [String]
  ) throws -> HarnessInvocation {
    guard let command = arguments.first else {
      throw HarnessArgumentError.missingCommand
    }
    guard registeredCommands.contains(command) else {
      throw HarnessArgumentError.unknownCommand(command)
    }

    var configuration: HarnessConfigurationInput?
    var index = 1
    while index < arguments.count {
      let option = arguments[index]
      guard option == "--configuration" || option == "--configuration-json" else {
        throw HarnessArgumentError.unexpectedArgument(option)
      }
      guard configuration == nil else {
        throw HarnessArgumentError.duplicateConfiguration
      }
      let valueIndex = index + 1
      guard valueIndex < arguments.count else {
        throw HarnessArgumentError.missingOptionValue(option)
      }
      let value = arguments[valueIndex]
      configuration = option == "--configuration" ? .file(value) : .json(value)
      index += 2
    }

    guard let configuration else {
      throw HarnessArgumentError.missingConfiguration
    }
    return HarnessInvocation(command: command, configuration: configuration)
  }
}

private struct HarnessCommandFailure: Sendable {
  let message: String
  let exitCode: HarnessExitCode

  init(_ error: any Error) {
    message = String(describing: error)
    exitCode = (error as? any HarnessExitCodeProvidingError)?.harnessExitCode ?? .failure
  }
}

private enum HarnessRunEvent: Sendable {
  case commandSucceeded
  case commandFailed(HarnessCommandFailure)
  case cancelled(HarnessCancellationReason)
}

public struct HarnessApplication: Sendable {
  public typealias FileReader = @Sendable (String) throws -> Data
  public typealias PlatformReader = @Sendable () -> HarnessPlatformMetadata

  private let registry: HarnessCommandRegistry
  private let dependencies: HarnessCommandDependencies
  private let readFile: FileReader
  private let readPlatform: PlatformReader

  public init(
    registry: HarnessCommandRegistry,
    dependencies: HarnessCommandDependencies,
    readFile: @escaping FileReader = { try Data(contentsOf: URL(fileURLWithPath: $0)) },
    readPlatform: @escaping PlatformReader = HarnessPlatformMetadata.current
  ) {
    self.registry = registry
    self.dependencies = dependencies
    self.readFile = readFile
    self.readPlatform = readPlatform
  }

  public func run(
    arguments: [String],
    cancellationSource: any HarnessCancellationSource
  ) async -> HarnessApplicationResponse {
    let invocation: HarnessInvocation
    do {
      invocation = try HarnessArgumentParser.parse(
        arguments: arguments,
        registeredCommands: registry.names
      )
    } catch {
      return usageResponse(error)
    }

    guard let command = registry.command(named: invocation.command) else {
      return usageResponse(HarnessArgumentError.unknownCommand(invocation.command))
    }

    let configuration: HarnessConfigurationDocument
    do {
      let data: Data
      switch invocation.configuration {
      case .file(let path):
        data = try readFile(path)
      case .json(let json):
        data = Data(json.utf8)
      }
      configuration = try HarnessConfigurationCodec.decode(data)
    } catch {
      return usageResponse(error)
    }

    let resources = HarnessResourceScope()
    let startedAt = dependencies.runtime.clock.now()
    let context = HarnessCommandContext(
      configuration: configuration,
      dependencies: dependencies,
      resources: resources
    )

    let firstEvent = await withTaskGroup(of: HarnessRunEvent.self) { group in
      group.addTask {
        do {
          try await command.run(context: context)
          return .commandSucceeded
        } catch {
          return .commandFailed(HarnessCommandFailure(error))
        }
      }
      group.addTask {
        .cancelled(await cancellationSource.waitForCancellation())
      }

      let event =
        await group.next()
        ?? .commandFailed(HarnessCommandFailure(HarnessInternalError.commandProducedNoResult))
      group.cancelAll()
      await group.waitForAll()
      return event
    }

    await resources.cleanup()
    let duration = startedAt.duration(to: dependencies.runtime.clock.now())

    switch firstEvent {
    case .commandSucceeded:
      let metrics = await dependencies.runtime.metrics.snapshot()
      let result = HarnessResultDocument(
        command: invocation.command,
        configuration: configuration,
        durationNanoseconds: duration.nonnegativeNanoseconds,
        platform: readPlatform(),
        metrics: metrics
      )
      do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var output = try encoder.encode(result)
        output.append(0x0A)
        return HarnessApplicationResponse(exitCode: .success, standardOutput: output)
      } catch {
        return HarnessApplicationResponse(exitCode: .failure, standardError: "\(error)\n")
      }
    case .commandFailed(let failure):
      return HarnessApplicationResponse(
        exitCode: failure.exitCode,
        standardError: "\(failure.message)\n"
      )
    case .cancelled(let reason):
      return HarnessApplicationResponse(exitCode: reason.exitCode)
    }
  }

  private func usageResponse(_ error: any Error) -> HarnessApplicationResponse {
    let commands = registry.names.joined(separator: ", ")
    return HarnessApplicationResponse(
      exitCode: .usage,
      standardError:
        "error: \(error)\nusage: ReluxTunnelHarness <\(commands)> (--configuration <path> | --configuration-json <json>)\n"
    )
  }
}

private enum HarnessInternalError: Error {
  case commandProducedNoResult
}

extension Duration {
  fileprivate var nonnegativeNanoseconds: UInt64 {
    let components = self.components
    guard components.seconds >= 0, components.attoseconds >= 0 else {
      return 0
    }
    let seconds = UInt64(components.seconds)
    let nanoseconds = UInt64(components.attoseconds / 1_000_000_000)
    let (secondNanoseconds, secondsOverflow) = seconds.multipliedReportingOverflow(
      by: 1_000_000_000)
    let (total, additionOverflow) = secondNanoseconds.addingReportingOverflow(nanoseconds)
    return secondsOverflow || additionOverflow ? UInt64.max : total
  }
}
