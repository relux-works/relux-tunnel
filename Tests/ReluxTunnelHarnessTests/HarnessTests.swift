import Darwin
import Foundation
import ReluxTunnelCore
import Testing

@testable import ReluxTunnelHarnessSupport

@Suite("ReluxTunnelHarness", .serialized)
struct HarnessTests {
  @Test("macOS harness registers the pinned libssh2 candidate capabilities")
  func libSSH2CandidateRegistration() {
    let capabilities = LibSSH2HarnessRegistration.capabilities
    #expect(capabilities.features.contains(.hostKeyBeforeAuthentication))
    #expect(capabilities.features.contains(.explicitRekey))
    #expect(capabilities.deferredSemantics.consumerDrivenReceiveWindowCredit == .unsupported)
    #expect(capabilities.deferredSemantics.exactExecExitMetadata == .unsupported)
  }

  @Test("argument parser rejects missing and unknown subcommands")
  func argumentValidationCommands() {
    #expect(throws: HarnessArgumentError.missingCommand) {
      try HarnessArgumentParser.parse(arguments: [], registeredCommands: ["smoke"])
    }
    #expect(throws: HarnessArgumentError.unknownCommand("packet")) {
      try HarnessArgumentParser.parse(arguments: ["packet"], registeredCommands: ["smoke"])
    }
  }

  @Test("argument parser requires exactly one structured configuration input")
  func argumentValidationConfiguration() {
    #expect(throws: HarnessArgumentError.missingConfiguration) {
      try HarnessArgumentParser.parse(arguments: ["smoke"], registeredCommands: ["smoke"])
    }
    #expect(throws: HarnessArgumentError.duplicateConfiguration) {
      try HarnessArgumentParser.parse(
        arguments: [
          "smoke", "--configuration", "fixture.json",
          "--configuration-json", "{}",
        ],
        registeredCommands: ["smoke"]
      )
    }
    #expect(throws: HarnessArgumentError.missingOptionValue("--configuration")) {
      try HarnessArgumentParser.parse(
        arguments: ["smoke", "--configuration"],
        registeredCommands: ["smoke"]
      )
    }
  }

  @Test("configuration schema versions fail closed")
  func configurationSchemaValidation() throws {
    let unsupported = makeConfiguration(schemaVersion: 999)
    let data = try HarnessConfigurationCodec.encode(unsupported)

    #expect(throws: HarnessConfigurationError.unsupportedSchemaVersion(999)) {
      try HarnessConfigurationCodec.decode(data)
    }
  }

  @Test("configuration rejects a non-opaque runtime profile reference")
  func configurationProfileReferenceValidation() throws {
    let encoded = try HarnessConfigurationCodec.encode(makeConfiguration())
    let invalid = Data(
      String(decoding: encoded, as: UTF8.self)
        .replacingOccurrences(
          of: "11111111-1111-1111-1111-111111111111",
          with: "raw-profile-or-secret"
        )
        .utf8
    )

    #expect(throws: HarnessConfigurationError.invalidProfileReference) {
      try HarnessConfigurationCodec.decode(invalid)
    }
  }

  @Test("signals map to shell-standard exit codes")
  func signalExitCodes() {
    #expect(HarnessCancellationReason.interrupt.exitCode == .interrupted)
    #expect(HarnessCancellationReason.terminate.exitCode == .terminated)
  }

  @Test("smoke output is deterministic, versioned, and privacy safe")
  func smokeResultSchema() async throws {
    let configuration = makeConfiguration()
    let first = await runSmoke(configuration: configuration)
    let second = await runSmoke(configuration: configuration)

    #expect(first.exitCode == .success)
    #expect(first.standardError.isEmpty)
    #expect(first.standardOutput == second.standardOutput)

    let result = try JSONDecoder().decode(
      HarnessResultDocument.self,
      from: first.standardOutput
    )
    #expect(result.schemaVersion == HarnessResultSchema.currentVersion)
    #expect(result.metrics.schemaVersion == HarnessMetricSchema.currentVersion)
    #expect(result.metrics.counters == ["harness.smoke.runs": 1])
    #expect(
      result.metrics.gauges == [
        "harness.hev.linked": 1,
        "harness.libssh2.linked": 1,
        "harness.native_fixture.schema_version": 1,
      ]
    )
    #expect(result.command == "smoke")
    #expect(result.status == "succeeded")
    #expect(result.durationNanoseconds == 0)
    #expect(result.sourceRevision == "0123456789abcdef")
    #expect(result.dependencyRevisions == ["fixture": "abcdef"])
    #expect(result.configuration.profileReference == "<redacted>")
    #expect(result.configuration.parameters["mode"] == "noop")
    #expect(result.configuration.parameters["destination"] == "<redacted>")
    #expect(
      result.platform
        == HarnessPlatformMetadata(
          operatingSystem: "macOS",
          operatingSystemVersion: "test",
          architecture: "test-arch"
        )
    )
  }

  @Test("normal exit cleans files, sockets, and managed tasks")
  func normalExitCleanup() async throws {
    let recorder = ResourceRecorder()
    let command = ResourceCommand(name: "cleanup", recorder: recorder, blocks: false)
    let application = try makeApplication(commands: [command])

    let response = await application.run(
      arguments: try arguments(command: "cleanup"),
      cancellationSource: StreamHarnessCancellationSource()
    )

    #expect(response.exitCode == .success)
    try await expectResourcesCleaned(recorder)
  }

  @Test(
    "signal cancellation uses signal exit code and cleans all resources",
    arguments: 1...50
  )
  func cancellationCleanup(iteration: Int) async throws {
    let recorder = ResourceRecorder()
    let command = ResourceCommand(
      name: "cancel-\(iteration)",
      recorder: recorder,
      blocks: true
    )
    let application = try makeApplication(commands: [command])
    let cancellation = StreamHarnessCancellationSource()
    let invocationArguments = try arguments(command: command.name)

    let run = Task {
      let response = await application.run(
        arguments: invocationArguments,
        cancellationSource: cancellation
      )
      await recorder.recordCompletion(response)
      return response
    }
    try await recorder.waitUntilStarted()
    cancellation.cancel(reason: .terminate)
    let response = await run.value

    #expect(response.exitCode == .terminated)
    #expect(response.standardOutput.isEmpty)
    try await expectResourcesCleaned(recorder)
  }

  @Test(
    "startup failure completes readiness waiters and cleans partial resources",
    arguments: 1...50
  )
  func startupFailureCompletesReadiness(iteration: Int) async throws {
    let recorder = ResourceRecorder()
    let command = ResourceCommand(
      name: "fail-before-ready-\(iteration)",
      recorder: recorder,
      blocks: false,
      failureBeforeReadiness: .injectedBeforeReadiness
    )
    let application = try makeApplication(commands: [command])
    let invocationArguments = try arguments(command: command.name)

    let run = Task {
      let response = await application.run(
        arguments: invocationArguments,
        cancellationSource: StreamHarnessCancellationSource()
      )
      await recorder.recordCompletion(response)
      return response
    }

    do {
      try await recorder.waitUntilStarted()
      Issue.record("startup failure unexpectedly published readiness")
    } catch let error as ResourceReadinessError {
      #expect(
        error
          == .completedBeforeReadiness(
            exitCode: .failure,
            diagnostic: "injectedBeforeReadiness\n"
          )
      )
    } catch {
      Issue.record("unexpected readiness error: \(error)")
    }

    let response = await run.value
    let snapshot = await recorder.snapshot()
    let directory = try #require(snapshot.directory)
    #expect(response.exitCode == .failure)
    #expect(response.standardError == "injectedBeforeReadiness\n")
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    #expect(snapshot.socket == nil)
    #expect(snapshot.managedTaskCancellationCount == 0)
    #expect(snapshot.pendingReadinessWaiterCount == 0)
  }

  @Test("readiness wait cancellation before registration cannot leak", arguments: 1...50)
  func readinessCancellationBeforeRegistration(iteration: Int) async {
    let recorder = ResourceRecorder()
    let waiter = Task {
      withUnsafeCurrentTask { task in
        task?.cancel()
      }
      try await recorder.waitUntilStarted()
    }

    await #expect(throws: CancellationError.self) {
      try await waiter.value
    }
    #expect(await recorder.pendingReadinessWaiterCount == 0)
  }

  @Test("registered readiness wait cancellation removes its continuation")
  func registeredReadinessCancellation() async {
    let registration = AsyncStream<Void>.makeStream()
    let recorder = ResourceRecorder {
      registration.continuation.yield()
      registration.continuation.finish()
    }
    let waiter = Task {
      try await recorder.waitUntilStarted()
    }
    var registrations = registration.stream.makeAsyncIterator()

    _ = await registrations.next()
    waiter.cancel()

    await #expect(throws: CancellationError.self) {
      try await waiter.value
    }
    #expect(await recorder.pendingReadinessWaiterCount == 0)
  }

  @Test("subcommands receive every packet and SSH experiment seam")
  func dependencyInjection() async throws {
    let recorder = DependencyRecorder()
    let command = DependencyCommand(recorder: recorder)
    let metrics = HarnessMetricsStore()
    let dependencies = HarnessCommandDependencies(
      runtime: TunnelRuntimeDependencies(
        clock: RecordingClock(recorder: recorder),
        logger: SilentHarnessLogger(),
        metrics: metrics,
        cancellation: TaskCancellationChecker(),
        memoryPressure: RecordingPressureSource(recorder: recorder)
      ),
      sshTransports: RecordingTransportFactory(recorder: recorder),
      packetEndpoints: RecordingPacketFactory(recorder: recorder),
      faultPolicy: RecordingFaultPolicy(recorder: recorder)
    )
    let registry = try HarnessCommandRegistry(commands: [command])
    let application = HarnessApplication(
      registry: registry,
      dependencies: dependencies,
      readPlatform: fixedPlatform
    )

    let response = await application.run(
      arguments: try arguments(command: command.name),
      cancellationSource: StreamHarnessCancellationSource()
    )
    let snapshot = await recorder.snapshot()

    #expect(response.exitCode == .success)
    #expect(snapshot.clockRead)
    #expect(snapshot.transportCreated)
    #expect(snapshot.packetEndpointCreated)
    #expect(snapshot.runtimeComposed)
    #expect(snapshot.pressureRead)
    #expect(snapshot.faultOperations == [.makePacketEndpoint, .makeSSHTransport])
  }

  @Test("MTU matrix configuration rejects output outside task temp at the production call site")
  func matrixProductionPathRejectsUnsafeOutput() async throws {
    let configuration = makeConfiguration(parameters: [
      "output_path": HarnessConfigurationValue(
        value: "/Users/Shared/mtu-matrix.json", privacy: .sensitive
      )
    ])
    let context = HarnessCommandContext(
      configuration: configuration,
      dependencies: HarnessDefaults.dependencies(),
      resources: HarnessResourceScope()
    )

    await #expect(throws: MTUMatrixError.unsafeOutputPath) {
      try await MTUMatrixHarnessCommand().run(context: context)
    }
    #expect(!FileManager.default.fileExists(atPath: "/Users/Shared/mtu-matrix.json"))
  }

  @Test("MTU matrix production path rejects a task-temp symlink escape")
  func matrixProductionPathRejectsSymlinkEscape() async throws {
    let fileManager = FileManager.default
    let taskTemp = URL(fileURLWithPath: fileManager.currentDirectoryPath)
      .appendingPathComponent(".temp/TASK-260715-gyg51r-symlink-test", isDirectory: true)
    let external = fileManager.temporaryDirectory
      .appendingPathComponent("TASK-260715-gyg51r-external-\(UUID().uuidString)", isDirectory: true)
    let link = taskTemp.appendingPathComponent("escape", isDirectory: true)
    try fileManager.createDirectory(at: taskTemp, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: external, withIntermediateDirectories: true)
    try fileManager.createSymbolicLink(at: link, withDestinationURL: external)
    defer {
      try? fileManager.removeItem(at: taskTemp)
      try? fileManager.removeItem(at: external)
    }
    let escapedOutput = link.appendingPathComponent("matrix.json")
    let configuration = makeConfiguration(parameters: [
      "output_path": HarnessConfigurationValue(value: escapedOutput.path, privacy: .sensitive)
    ])
    let context = HarnessCommandContext(
      configuration: configuration,
      dependencies: HarnessDefaults.dependencies(),
      resources: HarnessResourceScope()
    )

    await #expect(throws: MTUMatrixError.unsafeOutputPath) {
      try await MTUMatrixHarnessCommand().run(context: context)
    }
    #expect(!fileManager.fileExists(atPath: external.appendingPathComponent("matrix.json").path))
  }

  @Test("MTU matrix production path rejects a project temp root symlink to system temp")
  func matrixProductionPathRejectsProjectTempRootSymlink() async throws {
    let fileManager = FileManager.default
    let originalWorkingDirectory = fileManager.currentDirectoryPath
    let project = fileManager.temporaryDirectory
      .appendingPathComponent("TASK-260715-gyg51r-project-\(UUID().uuidString)", isDirectory: true)
    let external = URL(fileURLWithPath: "/tmp", isDirectory: true)
      .appendingPathComponent(
        "TASK-260715-gyg51r-root-external-\(UUID().uuidString)", isDirectory: true
      )
    try fileManager.createDirectory(at: project, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: external, withIntermediateDirectories: true)
    try fileManager.createSymbolicLink(
      at: project.appendingPathComponent(".temp", isDirectory: true),
      withDestinationURL: external
    )
    #expect(fileManager.changeCurrentDirectoryPath(project.path))
    defer {
      _ = fileManager.changeCurrentDirectoryPath(originalWorkingDirectory)
      try? fileManager.removeItem(at: project)
      try? fileManager.removeItem(at: external)
    }
    let configuration = makeConfiguration(parameters: [
      "output_path": HarnessConfigurationValue(value: ".temp/matrix.json", privacy: .sensitive),
      "packets_per_row": HarnessConfigurationValue(value: "64", privacy: .public),
    ])

    let response = try await makeApplication(commands: [MTUMatrixHarnessCommand()]).run(
      arguments: try arguments(command: "mtu-matrix", configuration: configuration),
      cancellationSource: StreamHarnessCancellationSource()
    )

    #expect(response.exitCode != .success)
    #expect(!fileManager.fileExists(atPath: external.appendingPathComponent("matrix.json").path))
  }

  @Test("MTU matrix production path rejects a post-parse parent replacement")
  func matrixProductionPathRejectsPostParseParentReplacement() async throws {
    let fileManager = FileManager.default
    let taskTemp = URL(fileURLWithPath: fileManager.currentDirectoryPath)
      .appendingPathComponent(".temp/TASK-260715-gyg51r-swap-test", isDirectory: true)
    let displaced = taskTemp.deletingLastPathComponent()
      .appendingPathComponent("TASK-260715-gyg51r-swap-original", isDirectory: true)
    let external = fileManager.temporaryDirectory
      .appendingPathComponent(
        "TASK-260715-gyg51r-swap-external-\(UUID().uuidString)", isDirectory: true
      )
    try fileManager.createDirectory(at: taskTemp, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: external, withIntermediateDirectories: true)
    defer {
      try? fileManager.removeItem(at: taskTemp)
      try? fileManager.removeItem(at: displaced)
      try? fileManager.removeItem(at: external)
    }
    let output = taskTemp.appendingPathComponent("matrix.json")
    let configuration = makeConfiguration(parameters: [
      "output_path": HarnessConfigurationValue(value: output.path, privacy: .sensitive),
      "packets_per_row": HarnessConfigurationValue(value: "2048", privacy: .public),
    ])
    let application = try makeApplication(commands: [MTUMatrixHarnessCommand()])
    let commandArguments = try arguments(command: "mtu-matrix", configuration: configuration)
    let run = Task {
      await application.run(
        arguments: commandArguments,
        cancellationSource: StreamHarnessCancellationSource()
      )
    }
    try await Task.sleep(for: .milliseconds(20))
    try fileManager.moveItem(at: taskTemp, to: displaced)
    try fileManager.createSymbolicLink(at: taskTemp, withDestinationURL: external)

    let response = await run.value

    #expect(response.exitCode != .success)
    #expect(!fileManager.fileExists(atPath: external.appendingPathComponent("matrix.json").path))
  }

  @Test("MTU matrix production path rejects a post-parse ancestor replacement")
  func matrixProductionPathRejectsPostParseAncestorReplacement() async throws {
    let fileManager = FileManager.default
    let originalWorkingDirectory = fileManager.currentDirectoryPath
    let testRoot = fileManager.temporaryDirectory
      .appendingPathComponent(
        "TASK-260715-gyg51r-ancestor-test-\(UUID().uuidString)", isDirectory: true
      )
    let ancestor = testRoot.appendingPathComponent("mutable-ancestor", isDirectory: true)
    let project = ancestor.appendingPathComponent("project", isDirectory: true)
    let external = fileManager.temporaryDirectory
      .appendingPathComponent(
        "TASK-260715-gyg51r-ancestor-external-\(UUID().uuidString)", isDirectory: true
      )
    let externalProjectTemp = external.appendingPathComponent("project/.temp", isDirectory: true)
    try fileManager.createDirectory(
      at: project.appendingPathComponent(".temp", isDirectory: true),
      withIntermediateDirectories: true
    )
    try fileManager.createDirectory(at: externalProjectTemp, withIntermediateDirectories: true)
    #expect(fileManager.changeCurrentDirectoryPath(project.path))
    defer {
      _ = fileManager.changeCurrentDirectoryPath(originalWorkingDirectory)
      try? fileManager.removeItem(at: testRoot)
      try? fileManager.removeItem(at: external)
    }
    let configuration = makeConfiguration(parameters: [
      "output_path": HarnessConfigurationValue(value: ".temp/matrix.json", privacy: .sensitive),
      "packets_per_row": HarnessConfigurationValue(value: "64", privacy: .public),
    ])
    let command = MTUMatrixHarnessCommand(afterConfigurationParsed: {
      let swapResult = Darwin.renameatx_np(
        AT_FDCWD, ancestor.path, AT_FDCWD, external.path, UInt32(RENAME_SWAP)
      )
      precondition(swapResult == 0, "renameatx_np swap failed with errno \(errno)")
    })
    let application = try makeApplication(commands: [command])
    let commandArguments = try arguments(command: "mtu-matrix", configuration: configuration)
    let response = await application.run(
      arguments: commandArguments,
      cancellationSource: StreamHarnessCancellationSource()
    )

    #expect(response.exitCode != .success)
    #expect(response.standardError.contains(MTUMatrixError.unsafeOutputPath.description))
    let swappedExternalOutput = ancestor.appendingPathComponent("project/.temp/matrix.json")
    #expect(!fileManager.fileExists(atPath: swappedExternalOutput.path))
  }

  @Test("MTU matrix production path supports the advertised 64-packet lower bound")
  func matrixProductionPathSupportsMinimumPacketCount() async throws {
    let output = URL(fileURLWithPath: "/tmp/TASK-260715-gyg51r-minimum-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: output) }
    let configuration = makeConfiguration(parameters: [
      "output_path": HarnessConfigurationValue(value: output.path, privacy: .sensitive),
      "packets_per_row": HarnessConfigurationValue(value: "64", privacy: .public),
    ])

    let response = try await makeApplication(commands: [MTUMatrixHarnessCommand()]).run(
      arguments: try arguments(command: "mtu-matrix", configuration: configuration),
      cancellationSource: StreamHarnessCancellationSource()
    )

    #expect(response.exitCode == .success, Comment(rawValue: response.standardError))
    let report = try JSONDecoder().decode(MTUMatrixReport.self, from: Data(contentsOf: output))
    #expect(report.rows.count == 36)
    #expect(report.rows.allSatisfy { $0.packetsAttempted == 64 })
  }

  @Test("MTU matrix packet ceiling fails closed instead of widening the bounded run")
  func matrixPacketCeiling() throws {
    let configuration = makeConfiguration(parameters: [
      "output_path": HarnessConfigurationValue(value: "/tmp/matrix.json", privacy: .sensitive),
      "packets_per_row": HarnessConfigurationValue(value: "2049", privacy: .public),
    ])
    #expect(throws: MTUMatrixError.invalidPacketCount) {
      try MTUMatrixRunConfiguration.parse(configuration)
    }
  }

  @Test("MTU matrix analysis rejects unexplained nominal loss")
  func matrixRejectsNominalLoss() {
    let row = makeMatrixRow(pressure: .nominal, drops: 1)
    #expect(throws: MTUMatrixError.nominalLoss(row: row.id, count: 1)) {
      try MTUMatrixAnalysis.validate([row])
    }
  }

  @Test("MTU matrix analysis rejects pressure rows that do not induce a drop")
  func matrixRejectsMissingPressureEffect() {
    let row = makeMatrixRow(pressure: .constrainedBuffer, drops: 0)
    #expect(throws: MTUMatrixError.pressureDidNotDrop(row: row.id)) {
      try MTUMatrixAnalysis.validate([row])
    }
  }

  @Test("MTU matrix analysis rejects total pressure loss")
  func matrixRejectsTotalPressureLoss() {
    let row = makeMatrixRow(pressure: .constrainedBuffer, drops: 2)
    #expect(throws: MTUMatrixError.unboundedPressureLoss(row: row.id)) {
      try MTUMatrixAnalysis.validate([row])
    }
  }

  @Test("MTU matrix analysis rejects inconsistent pressure accounting")
  func matrixRejectsInconsistentPressureAccounting() {
    let row = makeMatrixRow(pressure: .receiverStall, drops: 1, receiveQueueDrops: 0)
    #expect(throws: MTUMatrixError.invalidDropAccounting(row: row.id)) {
      try MTUMatrixAnalysis.validate([row])
    }
  }

  @Test("MTU matrix analysis rejects an incorrect reason")
  func matrixRejectsIncorrectDropReason() {
    let row = makeMatrixRow(
      pressure: .constrainedBuffer,
      drops: 1,
      dropReason: "sender_socket_refusal"
    )
    #expect(throws: MTUMatrixError.invalidDropReason(row: row.id)) {
      try MTUMatrixAnalysis.validate([row])
    }
  }

  @Test("MTU matrix analysis rejects a missing pressure reason")
  func matrixRejectsMissingDropReason() {
    let row = makeMatrixRow(pressure: .receiverStall, drops: 1, dropReason: nil)
    #expect(throws: MTUMatrixError.invalidDropReason(row: row.id)) {
      try MTUMatrixAnalysis.validate([row])
    }
  }

  @Test("MTU matrix analysis rejects failed lifecycle recovery")
  func matrixRejectsFailedRecovery() {
    let row = makeMatrixRow(pressure: .receiverStall, drops: 1, recovery: false)
    #expect(throws: MTUMatrixError.recoveryFailed(row: row.id)) {
      try MTUMatrixAnalysis.validate([row])
    }
  }

  @Test("bounded loopback MTU matrix emits all physical Mac rows and named gaps")
  func matrixEndToEnd() async throws {
    let output = URL(fileURLWithPath: "/tmp/TASK-260715-gyg51r-test-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: output) }
    let configuration = makeConfiguration(parameters: [
      "output_path": HarnessConfigurationValue(value: output.path, privacy: .sensitive),
      "packets_per_row": HarnessConfigurationValue(value: "128", privacy: .public),
    ])
    let application = try makeApplication(commands: [MTUMatrixHarnessCommand()])

    let response = await application.run(
      arguments: try arguments(command: "mtu-matrix", configuration: configuration),
      cancellationSource: StreamHarnessCancellationSource()
    )

    #expect(response.exitCode == .success)
    #expect(response.standardError.isEmpty)
    let report = try JSONDecoder().decode(
      MTUMatrixReport.self, from: Data(contentsOf: output)
    )
    #expect(report.rows.count == 36)
    #expect(Set(report.rows.map(\.mtu)) == [1_500, 4_096, 8_500])
    #expect(Set(report.rows.map(\.family)) == Set(MTUMatrixFamily.allCases))
    #expect(Set(report.rows.map(\.pressure)) == Set(MTUMatrixPressure.allCases))
    #expect(
      report.rows.filter { $0.pressure == .nominal || $0.pressure == .mixed }.allSatisfy {
        $0.drops == 0
      })
    #expect(
      report.rows.filter { $0.pressure == .constrainedBuffer || $0.pressure == .receiverStall }
        .allSatisfy { $0.drops > 0 })
    #expect(report.rows.allSatisfy { $0.recoveryProbeSucceeded })
    #expect(report.rows.allSatisfy { $0.ownedDescriptorDelta == 0 && $0.taskDelta == nil })
    #expect(report.rows.allSatisfy { $0.descriptorLifecycleMethod.contains("Darwin.close") })
    #expect(report.rows.allSatisfy { $0.taskLifecycleAvailability.hasPrefix("unavailable:") })
    #expect(report.rows.allSatisfy { $0.logicalBatchGroups == ($0.packetsSent + 31) / 32 })
    #expect(report.gaps.contains { $0.row == "NAT64" && $0.status == "unavailable" })
    #expect(
      report.gaps.contains {
        $0.row == "iPhone physical matrix" && $0.status == "deferred-unavailable"
      })
  }

  @Test("repeated MTU matrix runs have no monotonic descriptor or task growth")
  func repeatedMatrixResourceLifecycle() async throws {
    for iteration in 0..<3 {
      let output = URL(
        fileURLWithPath: "/tmp/TASK-260715-gyg51r-lifecycle-\(UUID().uuidString).json"
      )
      defer { try? FileManager.default.removeItem(at: output) }
      let configuration = makeConfiguration(parameters: [
        "output_path": HarnessConfigurationValue(value: output.path, privacy: .sensitive),
        "packets_per_row": HarnessConfigurationValue(value: "128", privacy: .public),
      ])
      let response = try await makeApplication(commands: [MTUMatrixHarnessCommand()]).run(
        arguments: try arguments(command: "mtu-matrix", configuration: configuration),
        cancellationSource: StreamHarnessCancellationSource()
      )
      #expect(response.exitCode == .success, "iteration \(iteration)")
      let report = try JSONDecoder().decode(
        MTUMatrixReport.self, from: Data(contentsOf: output)
      )
      #expect(report.rows.allSatisfy { $0.ownedDescriptorDelta == 0 }, "iteration \(iteration)")
      #expect(report.rows.allSatisfy { $0.taskDelta == nil }, "iteration \(iteration)")
    }
  }

  private func runSmoke(configuration: HarnessConfigurationDocument) async
    -> HarnessApplicationResponse
  {
    let application = try! makeApplication(commands: [SmokeHarnessCommand()])
    return await application.run(
      arguments: try! arguments(command: "smoke", configuration: configuration),
      cancellationSource: StreamHarnessCancellationSource()
    )
  }

  private func makeApplication(commands: [any HarnessCommand]) throws -> HarnessApplication {
    let dependencies = HarnessCommandDependencies(
      runtime: TunnelRuntimeDependencies(
        clock: FixedClock(),
        logger: SilentHarnessLogger(),
        metrics: HarnessMetricsStore(),
        cancellation: TaskCancellationChecker(),
        memoryPressure: NormalHarnessMemoryPressureSource()
      ),
      sshTransports: UnavailableHarnessSSHTransportFactory(),
      packetEndpoints: UnavailableHarnessPacketEndpointFactory(),
      faultPolicy: NoHarnessFaultPolicy()
    )
    return HarnessApplication(
      registry: try HarnessCommandRegistry(commands: commands),
      dependencies: dependencies,
      readPlatform: fixedPlatform
    )
  }

  private func arguments(
    command: String,
    configuration: HarnessConfigurationDocument = makeConfiguration()
  ) throws -> [String] {
    let data = try HarnessConfigurationCodec.encode(configuration)
    return [command, "--configuration-json", String(decoding: data, as: UTF8.self)]
  }

  private func expectResourcesCleaned(_ recorder: ResourceRecorder) async throws {
    let snapshot = await recorder.snapshot()
    let directory = try #require(snapshot.directory)
    let socket = try #require(snapshot.socket)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    #expect(!FileManager.default.fileExists(atPath: socket.path))
    #expect(snapshot.managedTaskCancellationCount == 1)
  }
}

private func makeConfiguration(
  schemaVersion: UInt16 = HarnessConfigurationSchema.currentVersion,
  parameters: [String: HarnessConfigurationValue]? = nil
) -> HarnessConfigurationDocument {
  HarnessConfigurationDocument(
    schemaVersion: schemaVersion,
    seed: 42,
    sourceRevision: "0123456789abcdef",
    dependencyRevisions: ["fixture": "abcdef"],
    profileReference: HarnessConfigurationValue(
      value: "11111111-1111-1111-1111-111111111111",
      privacy: .sensitive
    ),
    parameters: parameters ?? [
      "destination": HarnessConfigurationValue(value: "example.test", privacy: .sensitive),
      "mode": HarnessConfigurationValue(value: "noop", privacy: .public),
    ]
  )
}

private func makeMatrixRow(
  pressure: MTUMatrixPressure,
  drops: Int,
  recovery: Bool = true,
  receiveQueueDrops: Int? = nil,
  dropReason: String? = "__automatic__"
) -> MTUMatrixRow {
  let queueDrops = receiveQueueDrops ?? drops
  let resolvedDropReason =
    dropReason == "__automatic__"
    ? (drops == 0 ? nil : "socket_receive_queue_overflow") : dropReason
  return MTUMatrixRow(
    id: "test-row",
    family: .ipv4,
    mtu: 1_500,
    pressure: pressure,
    trafficGenerator: "test",
    durationNanoseconds: 1,
    requestedSendBufferBytes: 4_096,
    effectiveSendBufferBytes: 4_096,
    requestedReceiveBufferBytes: 4_096,
    effectiveReceiveBufferBytes: 4_096,
    packetsAttempted: 2,
    packetsSent: 2,
    packetsReceived: 2 - drops,
    bytesSent: 128,
    bytesReceived: drops == 0 ? 128 : 64,
    logicalBatchGroups: 1,
    drops: drops,
    sendFailures: 0,
    receiveQueueDrops: queueDrops,
    sendFailureErrnos: [:],
    dropReason: resolvedDropReason,
    latencyP50Nanoseconds: 1,
    latencyP95Nanoseconds: 1,
    packetsPerSecond: 1,
    throughputBitsPerSecond: 1,
    cpuUserNanoseconds: 1,
    cpuSystemNanoseconds: 1,
    sendSyscalls: 2,
    receiveSyscalls: 2,
    fragmentationObservation: "test",
    configuredMaximumDatagramBytes: 1_472,
    maximumDatagramBytes: 1_472,
    recoveryProbeSucceeded: recovery,
    ownedDescriptorDelta: 0,
    descriptorLifecycleMethod: "test fixture",
    taskDelta: nil,
    taskLifecycleAvailability: "unavailable: test fixture"
  )
}

private func fixedPlatform() -> HarnessPlatformMetadata {
  HarnessPlatformMetadata(
    operatingSystem: "macOS",
    operatingSystemVersion: "test",
    architecture: "test-arch"
  )
}

private struct FixedClock: TunnelClock {
  private let instant = ContinuousClock().now

  func now() -> ContinuousClock.Instant {
    instant
  }

  func sleep(for duration: Duration) async throws {
    try await Task.sleep(for: duration)
  }
}

private enum ResourceReadinessError: Error, Equatable {
  case completedBeforeReadiness(exitCode: HarnessExitCode, diagnostic: String)
}

private actor ResourceRecorder {
  private enum ReadinessState {
    case pending
    case ready
    case terminal(ResourceReadinessError)
  }

  private typealias ReadinessContinuation = CheckedContinuation<Void, any Error>

  private(set) var directory: URL?
  private(set) var socket: URL?
  private var managedTaskCancellationCount = 0
  private var readinessState = ReadinessState.pending
  private var readinessWaiters: [UUID: ReadinessContinuation] = [:]
  private let onReadinessWaiterRegistered: @Sendable () -> Void

  init(onReadinessWaiterRegistered: @escaping @Sendable () -> Void = {}) {
    self.onReadinessWaiterRegistered = onReadinessWaiterRegistered
  }

  func record(directory: URL) {
    self.directory = directory
  }

  func record(socket: URL) {
    self.socket = socket
  }

  func recordReadiness() {
    guard case .pending = readinessState else {
      return
    }
    readinessState = .ready
    completeReadinessWaiters(with: .success(()))
  }

  func recordCompletion(_ response: HarnessApplicationResponse) {
    guard case .pending = readinessState else {
      return
    }
    let error = ResourceReadinessError.completedBeforeReadiness(
      exitCode: response.exitCode,
      diagnostic: response.standardError
    )
    readinessState = .terminal(error)
    completeReadinessWaiters(with: .failure(error))
  }

  func waitUntilStarted() async throws {
    let waiterID = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        registerReadinessWaiter(continuation, id: waiterID)
      }
    } onCancel: {
      Task {
        await self.cancelReadinessWaiter(id: waiterID)
      }
    }
  }

  func recordManagedTaskCancellation() {
    managedTaskCancellationCount += 1
  }

  var pendingReadinessWaiterCount: Int {
    readinessWaiters.count
  }

  func snapshot() -> (
    directory: URL?,
    socket: URL?,
    managedTaskCancellationCount: Int,
    pendingReadinessWaiterCount: Int
  ) {
    (directory, socket, managedTaskCancellationCount, readinessWaiters.count)
  }

  private func registerReadinessWaiter(
    _ continuation: ReadinessContinuation,
    id: UUID
  ) {
    if Task.isCancelled {
      continuation.resume(throwing: CancellationError())
      return
    }

    switch readinessState {
    case .pending:
      readinessWaiters[id] = continuation
      onReadinessWaiterRegistered()
    case .ready:
      continuation.resume()
    case .terminal(let error):
      continuation.resume(throwing: error)
    }
  }

  private func cancelReadinessWaiter(id: UUID) {
    readinessWaiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
  }

  private func completeReadinessWaiters(with result: Result<Void, any Error>) {
    let waiters = readinessWaiters.values
    readinessWaiters.removeAll()
    for waiter in waiters {
      waiter.resume(with: result)
    }
  }
}

private enum ResourceCommandError: Error {
  case injectedBeforeReadiness
}

private struct ResourceCommand: HarnessCommand {
  let name: String
  let recorder: ResourceRecorder
  let blocks: Bool
  var failureBeforeReadiness: ResourceCommandError?

  init(
    name: String,
    recorder: ResourceRecorder,
    blocks: Bool,
    failureBeforeReadiness: ResourceCommandError? = nil
  ) {
    self.name = name
    self.recorder = recorder
    self.blocks = blocks
    self.failureBeforeReadiness = failureBeforeReadiness
  }

  func run(context: HarnessCommandContext) async throws {
    let directory = try await context.resources.makeTemporaryDirectory(prefix: "relux-test")
    await recorder.record(directory: directory)
    let marker = directory.appendingPathComponent("marker")
    try Data("fixture".utf8).write(to: marker)
    if let failureBeforeReadiness {
      throw failureBeforeReadiness
    }
    let socket = directory.appendingPathComponent("fixture.sock")
    try await context.resources.bindUnixDatagramSocket(at: socket)
    await recorder.record(socket: socket)
    await context.resources.startTask {
      do {
        try await Task.sleep(for: .seconds(3_600))
      } catch {
        await recorder.recordManagedTaskCancellation()
      }
    }
    await recorder.recordReadiness()

    if blocks {
      try await Task.sleep(for: .seconds(3_600))
    }
  }
}

private struct DependencySnapshot: Sendable {
  let clockRead: Bool
  let transportCreated: Bool
  let packetEndpointCreated: Bool
  let runtimeComposed: Bool
  let pressureRead: Bool
  let faultOperations: [HarnessFaultOperation]
}

private actor DependencyRecorder {
  private var clockRead = false
  private var transportCreated = false
  private var packetEndpointCreated = false
  private var runtimeComposed = false
  private var pressureRead = false
  private var faultOperations: [HarnessFaultOperation] = []

  func recordClock() { clockRead = true }
  func recordTransport() { transportCreated = true }
  func recordPacketEndpoint() { packetEndpointCreated = true }
  func recordRuntimeComposition() { runtimeComposed = true }
  func recordPressure() { pressureRead = true }
  func recordFault(_ operation: HarnessFaultOperation) { faultOperations.append(operation) }

  func snapshot() -> DependencySnapshot {
    DependencySnapshot(
      clockRead: clockRead,
      transportCreated: transportCreated,
      packetEndpointCreated: packetEndpointCreated,
      runtimeComposed: runtimeComposed,
      pressureRead: pressureRead,
      faultOperations: faultOperations
    )
  }
}

private final class RecordingClock: TunnelClock, @unchecked Sendable {
  private let recorder: DependencyRecorder
  private let instant = ContinuousClock().now

  init(recorder: DependencyRecorder) {
    self.recorder = recorder
  }

  func now() -> ContinuousClock.Instant {
    Task { await recorder.recordClock() }
    return instant
  }

  func sleep(for duration: Duration) async throws {
    try await Task.sleep(for: duration)
  }
}

private struct RecordingPressureSource: TunnelMemoryPressureSource {
  let recorder: DependencyRecorder

  func currentPressure() async -> TunnelMemoryPressure {
    await recorder.recordPressure()
    return .critical
  }
}

private struct RecordingFaultPolicy: HarnessFaultPolicy {
  let recorder: DependencyRecorder

  func evaluate(_ operation: HarnessFaultOperation) async throws {
    await recorder.recordFault(operation)
  }
}

private struct RecordingTransportFactory: HarnessSSHTransportFactory {
  let recorder: DependencyRecorder

  func makeSSHTransport() async throws -> any SSHTransport {
    await recorder.recordTransport()
    return TestSSHTransport()
  }
}

private struct RecordingPacketFactory: HarnessPacketEndpointFactory {
  let recorder: DependencyRecorder

  func makePacketFlow() async throws -> any PacketFlow {
    await recorder.recordPacketEndpoint()
    return TestPacketFlow()
  }
}

private struct DependencyCommand: HarnessCommand {
  let name = "dependencies"
  let recorder: DependencyRecorder

  func run(context: HarnessCommandContext) async throws {
    _ = context.dependencies.runtime.clock.now()
    _ = await context.dependencies.runtime.memoryPressure.currentPressure()
    let composition = HarnessCoreComposition(dependencies: context.dependencies)
    let runtime = try await composition.makeRuntime(
      configuration: try context.configuration.tunnelConfiguration(),
      factory: RecordingRuntimeFactory(recorder: recorder)
    )
    try await runtime.start()
    let transport = try await composition.makeSSHTransport()
    await transport.close()
  }
}

private struct RecordingRuntimeFactory: TunnelRuntimeFactory {
  let recorder: DependencyRecorder

  func makeRuntime(context: TunnelRuntimeContext) async throws -> any TunnelRuntime {
    _ = try await context.packetFlow.readPackets()
    await recorder.recordRuntimeComposition()
    return TestRuntime()
  }
}

private actor TestRuntime: TunnelRuntime {
  func start() async throws {}
  func stop(reason: ProviderStopReason) async {}
  func lifecycleState() async -> TunnelLifecycleState { .disconnected }
}

private actor TestPacketFlow: PacketFlow {
  func readPackets() async throws -> PacketReadBatch { PacketReadBatch(results: []) }
  func writePackets(_ packets: [TunnelPacket]) async throws {}
}

private actor TestSSHTransport: SSHTransport {
  private let lane = SSHLaneIdentity(
    rawValue: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
  )

  func connect(configuration: SSHConnectionConfiguration) async throws -> SSHSession {
    throw HarnessUnavailableDependencyError.sshTransport
  }

  func openDirectTCPIP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint,
    policy: SSHChannelPolicy
  ) async throws -> any SSHByteChannel {
    throw HarnessUnavailableDependencyError.sshTransport
  }

  func openExecChannel(
    request: SSHExecRequest,
    policy: SSHChannelPolicy
  ) async throws -> any SSHExecChannel {
    throw HarnessUnavailableDependencyError.sshTransport
  }

  func upload(_ request: SSHExecUploadRequest) async throws -> SSHExecExit {
    throw HarnessUnavailableDependencyError.sshTransport
  }

  func requestRekey(reason: SSHClientRekeyReason) async throws {}

  func sendKeepalive() async throws -> SSHDeferredSemanticReport<Duration> { .unsupported }

  func snapshot() -> SSHTransportSnapshot {
    SSHTransportSnapshot(
      lane: lane,
      connectionState: .idle,
      negotiatedAlgorithms: nil,
      keyExchangeGeneration: .unsupported,
      counters: SSHTransportCounters(
        windowAdjustments: .unsupported,
        windowAdjustmentBytes: .unsupported,
        serverRekeys: .unsupported,
        keepalivesAcknowledged: .unsupported,
        keepalivesTimedOut: .unsupported
      ),
      gauges: SSHTransportGauges(
        remainingReceiveWindowBytes: .unsupported,
        activeKeyExchange: .unsupported,
        consecutiveKeepaliveMisses: .unsupported,
        lastKeepaliveRTTNanoseconds: .unsupported
      )
    )
  }

  func close() {}
}
