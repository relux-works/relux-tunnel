import CryptoKit
import Foundation
import ReluxTunnelCore
import Testing

@Suite("Bounded full-duplex byte pump")
struct BoundedFullDuplexBytePumpTests {
  @Test("configuration and aggregate reservations enforce fixed checked ceilings")
  func fixedCeilings() async throws {
    #expect(throws: BytePumpConfigurationError.nonPositive(.localReadChunkBytes)) {
      _ = try pumpConfiguration(localChunk: 0)
    }
    #expect(
      throws: BytePumpConfigurationError.perFlowReservationExceedsAggregate(
        perFlow: 17,
        aggregate: 16
      )
    ) {
      _ = try pumpConfiguration(localChunk: 9, remoteChunk: 8, aggregate: 16)
    }

    let budget = try BytePumpBufferBudget(maximumReservedBytes: 32)
    #expect(await budget.tryReserve(bytes: 16))
    #expect(await budget.tryReserve(bytes: 16))
    #expect(!(await budget.tryReserve(bytes: 1)))
    await budget.release(bytes: 16)
    await budget.release(bytes: 16)
    let snapshot = await budget.snapshot()
    #expect(snapshot.reservedBytes == 0)
    #expect(snapshot.peakReservedBytes == 32)
    #expect(snapshot.successfulReservations == 2)
    #expect(snapshot.deniedReservations == 1)
    #expect(snapshot.releases == 2)
    #expect(snapshot.releaseViolations == 0)
  }

  @Test("shared budget rejects excess concurrent flow capacity without queuing")
  func aggregateConcurrentCeiling() async throws {
    let configuration = try pumpConfiguration(
      localChunk: 16,
      remoteChunk: 16,
      maximumSSHWriteCall: 8,
      aggregate: 64
    )
    let budget = try BytePumpBufferBudget(maximumReservedBytes: 64)

    let first = try makeStalledPump(configuration: configuration, budget: budget)
    let firstRun = Task { try await first.pump.run() }
    #expect(
      await pumpEventually {
        first.channel.pendingReadCount == 1 && first.channel.pendingWriteCount == 1
      })

    let second = try makeStalledPump(configuration: configuration, budget: budget)
    let secondRun = Task { try await second.pump.run() }
    #expect(
      await pumpEventually {
        second.channel.pendingReadCount == 1 && second.channel.pendingWriteCount == 1
      })

    let rejected = try makeStalledPump(configuration: configuration, budget: budget)
    let rejectedOutcome = try await rejected.pump.run()
    #expect(rejectedOutcome.localToSSH.reason == .boundViolation)
    #expect(rejectedOutcome.sshToLocal.reason == .boundViolation)

    await first.pump.cancel()
    await second.pump.cancel()
    _ = try await firstRun.value
    _ = try await secondRun.value

    let snapshot = await budget.snapshot()
    #expect(snapshot.reservedBytes == 0)
    #expect(snapshot.peakReservedBytes == 64)
    #expect(snapshot.successfulReservations == 2)
    #expect(snapshot.deniedReservations == 1)
    #expect(snapshot.releases == 2)
    #expect(snapshot.releaseViolations == 0)
  }

  @Test("random fragmented bidirectional transfer preserves exact bytes and hashes")
  func randomizedBidirectionalIntegrity() async throws {
    let localPayload = deterministicBytes(count: 32_771, seed: 0x4c4f_4341_4c)
    let remotePayload = deterministicBytes(count: 29_003, seed: 0x5245_4d4f_5445)
    let local = RandomizedLocalByteStream(
      inbound: localPayload,
      seed: 0xa11c_e001,
      readPressureInterval: 5,
      writePressureInterval: 4
    )
    let channel = RandomizedSSHByteChannel(
      inbound: remotePayload,
      seed: 0x55aa_1020
    )
    let diagnostics = RecordingBytePumpDiagnostics()
    let events = RecordingBytePumpTerminalSink()
    let configuration = try pumpConfiguration(
      localChunk: 257,
      remoteChunk: 193,
      maximumSSHWriteCall: 71,
      aggregate: 450,
      fairnessOperations: 7,
      fairnessBytes: 509
    )
    let budget = try BytePumpBufferBudget(maximumReservedBytes: 450)
    let pump = try BoundedFullDuplexBytePump(
      local: local,
      channel: channel,
      configuration: configuration,
      bufferBudget: budget,
      eventSink: events,
      diagnostics: diagnostics
    )

    let outcome = try await pump.run()

    #expect(outcome.localToSSH.reason == .eof)
    #expect(outcome.sshToLocal.reason == .eof)
    #expect(channel.writtenBytes == localPayload)
    #expect(local.writtenBytes == remotePayload)
    #expect(sha256Hex(channel.writtenBytes) == sha256Hex(localPayload))
    #expect(sha256Hex(local.writtenBytes) == sha256Hex(remotePayload))
    #expect(
      sha256Hex(localPayload) == "6d440a591a2318f6333d6ce2c1cfeb68250f0818c3b55f43554633fe0d98f5ad")
    #expect(
      sha256Hex(remotePayload) == "66f02f2a49b66e79a933ae6b0be4f3719c09c0c8e72d9b91189ca11389414378"
    )
    #expect(local.maximumReadRequest <= configuration.localReadChunkBytes)
    #expect(channel.maximumReadRequest <= configuration.remoteReadChunkBytes)
    #expect(channel.maximumWriteRequest <= configuration.maximumSSHWriteCallBytes)
    #expect(diagnostics.maximumBufferedBytes(for: .localToSSH) <= 257)
    #expect(diagnostics.maximumBufferedBytes(for: .sshToLocal) <= 193)
    #expect(diagnostics.transferredBytes(for: .localToSSH) == localPayload.count)
    #expect(diagnostics.transferredBytes(for: .sshToLocal) == remotePayload.count)
    #expect(diagnostics.pressureCount(for: .localToSSH) > 0)
    #expect(diagnostics.pressureCount(for: .sshToLocal) > 0)
    #expect(await events.values.count == 2)

    let budgetSnapshot = await budget.snapshot()
    #expect(budgetSnapshot.reservedBytes == 0)
    #expect(budgetSnapshot.peakReservedBytes == 450)
    #expect(budgetSnapshot.successfulReservations == 1)
    #expect(budgetSnapshot.releases == 1)
    #expect(budgetSnapshot.releaseViolations == 0)
  }

  @Test("twelve deterministic seeds preserve ordering under changing fragmentation")
  func repeatedSeededIntegrity() async throws {
    let budget = try BytePumpBufferBudget(maximumReservedBytes: 256)
    for seed in 1...12 {
      let seed64 = UInt64(seed)
      let localPayload = deterministicBytes(
        count: 2_000 + seed * 37,
        seed: 0x5100_0000 &+ seed64
      )
      let remotePayload = deterministicBytes(
        count: 1_700 + seed * 41,
        seed: 0x5200_0000 &+ seed64
      )
      let local = RandomizedLocalByteStream(
        inbound: localPayload,
        seed: 0x6100_0000 &+ seed64,
        readPressureInterval: 3 + seed % 5,
        writePressureInterval: 2 + seed % 7
      )
      let channel = RandomizedSSHByteChannel(
        inbound: remotePayload,
        seed: 0x6200_0000 &+ seed64
      )
      let pump = try BoundedFullDuplexBytePump(
        local: local,
        channel: channel,
        configuration: pumpConfiguration(
          localChunk: 128,
          remoteChunk: 128,
          maximumSSHWriteCall: 47,
          aggregate: 256,
          fairnessOperations: 5 + seed % 4,
          fairnessBytes: 191 + seed
        ),
        bufferBudget: budget
      )

      let outcome = try await pump.run()
      #expect(outcome.localToSSH.reason == .eof)
      #expect(outcome.sshToLocal.reason == .eof)
      #expect(channel.writtenBytes == localPayload)
      #expect(local.writtenBytes == remotePayload)
      #expect(sha256Hex(channel.writtenBytes) == sha256Hex(localPayload))
      #expect(sha256Hex(local.writtenBytes) == sha256Hex(remotePayload))
      #expect(await budget.snapshot().reservedBytes == 0)
    }

    let snapshot = await budget.snapshot()
    #expect(snapshot.successfulReservations == 12)
    #expect(snapshot.releases == 12)
    #expect(snapshot.releaseViolations == 0)
  }

  @Test("SSH credit suspension retains one local chunk and resumes partial writes in order")
  func sshCreditSuspension() async throws {
    let payload = deterministicBytes(count: 41, seed: 0x4352_4544_4954)
    let local = ControllableLocalByteStream(inbound: payload, readFragment: 11)
    let channel = ControllableSSHByteChannel(
      inbound: Data(),
      firstWriteSuspends: true,
      maximumWriteAcceptance: 3
    )
    let budget = try BytePumpBufferBudget(maximumReservedBytes: 32)
    let pump = try BoundedFullDuplexBytePump(
      local: local,
      channel: channel,
      configuration: pumpConfiguration(
        localChunk: 16,
        remoteChunk: 16,
        maximumSSHWriteCall: 7,
        aggregate: 32
      ),
      bufferBudget: budget
    )

    let run = Task { try await pump.run() }
    #expect(await pumpEventually { channel.hasSuspendedWrite })
    #expect(local.readCallCount == 1)
    #expect(channel.writeCallCount == 1)
    channel.resumeFirstWrite()

    let outcome = try await run.value
    #expect(outcome.localToSSH.reason == .eof)
    #expect(outcome.sshToLocal.reason == .eof)
    #expect(channel.writtenBytes == payload)
    #expect(local.maximumReadRequest <= 16)
    #expect(await budget.snapshot().reservedBytes == 0)
  }

  @Test("fairness slices yield while continuous work still has bytes pending")
  func fairnessSlices() async throws {
    let localPayload = deterministicBytes(count: 1_024, seed: 0xfa17_0001)
    let remotePayload = deterministicBytes(count: 1_024, seed: 0xfa17_0002)
    let local = RandomizedLocalByteStream(
      inbound: localPayload,
      seed: 0x1001,
      readPressureInterval: 0,
      writePressureInterval: 0
    )
    let channel = RandomizedSSHByteChannel(inbound: remotePayload, seed: 0x1002)
    let scheduler = FirstYieldGateBytePumpScheduler()
    let diagnostics = RecordingBytePumpDiagnostics()
    let budget = try BytePumpBufferBudget(maximumReservedBytes: 128)
    let pump = try BoundedFullDuplexBytePump(
      local: local,
      channel: channel,
      configuration: pumpConfiguration(
        localChunk: 64,
        remoteChunk: 64,
        maximumSSHWriteCall: 32,
        aggregate: 128,
        fairnessOperations: 2,
        fairnessBytes: 64
      ),
      bufferBudget: budget,
      scheduler: scheduler,
      diagnostics: diagnostics
    )

    let run = Task { try await pump.run() }
    #expect(await pumpEventually { scheduler.firstYieldReached })
    #expect(channel.writtenBytes.count < localPayload.count)
    #expect(local.writtenBytes.count < remotePayload.count)

    let lifecycleProbe = ProgressProbe()
    await lifecycleProbe.advance()
    #expect(await lifecycleProbe.value == 1)
    scheduler.releaseFirstYield()

    let outcome = try await run.value
    #expect(outcome.localToSSH.reason == .eof)
    #expect(outcome.sshToLocal.reason == .eof)
    #expect(diagnostics.fairnessYieldCount(for: .localToSSH) > 0)
    #expect(diagnostics.fairnessYieldCount(for: .sshToLocal) > 0)
  }

  @Test("permanently pressured peers suspend without spin and cancellation releases once")
  func pressureCancellation() async throws {
    let local = StallLocalByteStream(
      readBehavior: .oneChunkThenStall(Data([1, 2, 3, 4])),
      writeBehavior: .accept
    )
    let channel = StallSSHByteChannel(
      readBehavior: .stall,
      writeBehavior: .stall
    )
    let budget = try BytePumpBufferBudget(maximumReservedBytes: 32)
    let pump = try BoundedFullDuplexBytePump(
      local: local,
      channel: channel,
      configuration: pumpConfiguration(
        localChunk: 16,
        remoteChunk: 16,
        maximumSSHWriteCall: 8,
        aggregate: 32
      ),
      bufferBudget: budget
    )

    let run = Task { try await pump.run() }
    #expect(
      await pumpEventually { channel.pendingReadCount == 1 && channel.pendingWriteCount == 1 })
    let readCalls = local.readCallCount
    let writeCalls = channel.writeCallCount
    for _ in 0..<100 {
      await Task.yield()
    }
    #expect(local.readCallCount == readCalls)
    #expect(channel.writeCallCount == writeCalls)

    await pump.cancel()
    let outcome = try await run.value
    #expect(outcome.localToSSH.reason == .cancelled)
    #expect(outcome.sshToLocal.reason == .cancelled)
    #expect(channel.cancelCallCount == 1)
    let snapshot = await budget.snapshot()
    #expect(snapshot.reservedBytes == 0)
    #expect(snapshot.successfulReservations == 1)
    #expect(snapshot.releases == 1)
    #expect(snapshot.releaseViolations == 0)
  }

  @Test(
    "cancellation wakes every suspending pump seam",
    arguments: PumpCancellationSite.allCases
  )
  func cancellationAtAwait(site: PumpCancellationSite) async throws {
    let fixture = try CancellationFixture(site: site)
    let run = Task { try await fixture.pump.run() }
    #expect(await pumpEventually { fixture.isSuspended })

    await fixture.pump.cancel()
    let outcome = try await run.value
    let relevant = site.direction == .localToSSH ? outcome.localToSSH : outcome.sshToLocal
    #expect(relevant.reason == .cancelled)
    #expect(await fixture.budget.snapshot().reservedBytes == 0)
  }

  @Test("a positive completion arriving after cancellation cannot revive or duplicate work")
  func lateCompletionAfterCancellation() async throws {
    let local = StallLocalByteStream(
      readBehavior: .oneChunkThenEOF(Data([9, 8, 7, 6])),
      writeBehavior: .accept
    )
    let channel = StallSSHByteChannel(
      readBehavior: .eof,
      writeBehavior: .lateSuccessOnCancel
    )
    let events = RecordingBytePumpTerminalSink()
    let budget = try BytePumpBufferBudget(maximumReservedBytes: 32)
    let pump = try BoundedFullDuplexBytePump(
      local: local,
      channel: channel,
      configuration: pumpConfiguration(
        localChunk: 16,
        remoteChunk: 16,
        maximumSSHWriteCall: 8,
        aggregate: 32
      ),
      bufferBudget: budget,
      eventSink: events
    )

    let run = Task { try await pump.run() }
    #expect(await pumpEventually { channel.pendingWriteCount == 1 })
    await pump.cancel()
    let outcome = try await run.value

    #expect(outcome.localToSSH.reason == .cancelled)
    #expect(
      outcome.sshToLocal.reason == .eof || outcome.sshToLocal.reason == .cancelled)
    #expect(local.readCallCount == 1)
    #expect(channel.writeCallCount == 1)
    #expect(await events.values.count == 2)
    #expect(await Set(events.values).count == 2)
    #expect(await budget.snapshot().reservedBytes == 0)
  }

  @Test("zero progress and invalid peer lengths terminate with stable directional reasons")
  func contractViolations() async throws {
    let zeroLocal = StallLocalByteStream(
      readBehavior: .oneChunkThenEOF(Data([1])),
      writeBehavior: .accept
    )
    let zeroChannel = StallSSHByteChannel(readBehavior: .eof, writeBehavior: .zero)
    let zeroBudget = try BytePumpBufferBudget(maximumReservedBytes: 16)
    let zeroPump = try BoundedFullDuplexBytePump(
      local: zeroLocal,
      channel: zeroChannel,
      configuration: pumpConfiguration(
        localChunk: 8,
        remoteChunk: 8,
        maximumSSHWriteCall: 8,
        aggregate: 16
      ),
      bufferBudget: zeroBudget
    )
    let zeroOutcome = try await zeroPump.run()
    #expect(zeroOutcome.localToSSH.reason == .zeroProgress)
    #expect(zeroOutcome.sshToLocal.reason == .eof)

    let oversizedLocal = StallLocalByteStream(readBehavior: .eof, writeBehavior: .accept)
    let oversizedChannel = StallSSHByteChannel(
      readBehavior: .oversized(Data(repeating: 0xaa, count: 9)),
      writeBehavior: .accept
    )
    let oversizedBudget = try BytePumpBufferBudget(maximumReservedBytes: 16)
    let oversizedPump = try BoundedFullDuplexBytePump(
      local: oversizedLocal,
      channel: oversizedChannel,
      configuration: pumpConfiguration(
        localChunk: 8,
        remoteChunk: 8,
        maximumSSHWriteCall: 8,
        aggregate: 16
      ),
      bufferBudget: oversizedBudget
    )
    let oversizedOutcome = try await oversizedPump.run()
    #expect(oversizedOutcome.localToSSH.reason == .eof)
    #expect(oversizedOutcome.sshToLocal.reason == .boundViolation)

    let closedLocal = StallLocalByteStream(readBehavior: .eof, writeBehavior: .zero)
    let closedChannel = StallSSHByteChannel(
      readBehavior: .oneChunkThenEOF(Data([1])),
      writeBehavior: .accept
    )
    let closedBudget = try BytePumpBufferBudget(maximumReservedBytes: 16)
    let closedPump = try BoundedFullDuplexBytePump(
      local: closedLocal,
      channel: closedChannel,
      configuration: pumpConfiguration(
        localChunk: 8,
        remoteChunk: 8,
        maximumSSHWriteCall: 8,
        aggregate: 16
      ),
      bufferBudget: closedBudget
    )
    let closedOutcome = try await closedPump.run()
    #expect(closedOutcome.localToSSH.reason == .eof)
    #expect(closedOutcome.sshToLocal.reason == .localClosure)
  }

  @Test(
    "read write and remote closure failures map to finite directional reasons",
    arguments: PumpFailureSite.allCases)
  func typedFailureReasons(site: PumpFailureSite) async throws {
    let fixture = try FailureFixture(site: site)
    let outcome = try await fixture.pump.run()
    let event = site.direction == .localToSSH ? outcome.localToSSH : outcome.sshToLocal
    #expect(event.reason == site.expectedReason)
    #expect(await fixture.budget.snapshot().reservedBytes == 0)
  }

  @Test("one hundred cancelled runs restore the shared resource baseline")
  func repeatedResourceBaseline() async throws {
    let budget = try BytePumpBufferBudget(maximumReservedBytes: 32)
    for _ in 0..<100 {
      let local = StallLocalByteStream(
        readBehavior: .oneChunkThenStall(Data([1])),
        writeBehavior: .accept
      )
      let channel = StallSSHByteChannel(readBehavior: .stall, writeBehavior: .stall)
      let pump = try BoundedFullDuplexBytePump(
        local: local,
        channel: channel,
        configuration: pumpConfiguration(
          localChunk: 16,
          remoteChunk: 16,
          maximumSSHWriteCall: 8,
          aggregate: 32
        ),
        bufferBudget: budget
      )
      let run = Task { try await pump.run() }
      #expect(
        await pumpEventually {
          channel.pendingReadCount == 1 && channel.pendingWriteCount == 1
        })
      await pump.cancel()
      _ = try await run.value
      #expect(await budget.snapshot().reservedBytes == 0)
    }

    let snapshot = await budget.snapshot()
    #expect(snapshot.peakReservedBytes == 32)
    #expect(snapshot.successfulReservations == 100)
    #expect(snapshot.releases == 100)
    #expect(snapshot.releaseViolations == 0)
  }
}

enum PumpCancellationSite: String, CaseIterable, Sendable {
  case localReadable
  case localWritable
  case sshRead
  case sshWrite
  case fairnessYield

  var direction: BytePumpDirection {
    switch self {
    case .localReadable, .sshWrite, .fairnessYield:
      .localToSSH
    case .localWritable, .sshRead:
      .sshToLocal
    }
  }
}

enum PumpFailureSite: String, CaseIterable, Sendable {
  case localRead
  case sshWrite
  case sshRead
  case localWrite
  case sshRemoteClosure

  var direction: BytePumpDirection {
    switch self {
    case .localRead, .sshWrite:
      .localToSSH
    case .sshRead, .localWrite, .sshRemoteClosure:
      .sshToLocal
    }
  }

  var expectedReason: BytePumpTerminalReason {
    switch self {
    case .localRead, .sshRead:
      .readError
    case .sshWrite, .localWrite:
      .writeError
    case .sshRemoteClosure:
      .remoteClosure
    }
  }
}

private struct CancellationFixture {
  let pump: BoundedFullDuplexBytePump
  let budget: BytePumpBufferBudget
  let local: StallLocalByteStream
  let channel: StallSSHByteChannel
  let scheduler: FirstYieldGateBytePumpScheduler?
  let site: PumpCancellationSite

  init(site: PumpCancellationSite) throws {
    self.site = site
    let readBehavior: StallLocalByteStream.ReadBehavior
    let writeBehavior: StallLocalByteStream.WriteBehavior
    let channelRead: StallSSHByteChannel.ReadBehavior
    let channelWrite: StallSSHByteChannel.WriteBehavior
    let scheduler: FirstYieldGateBytePumpScheduler?

    switch site {
    case .localReadable:
      readBehavior = .wouldBlockStall
      writeBehavior = .accept
      channelRead = .eof
      channelWrite = .accept
      scheduler = nil
    case .localWritable:
      readBehavior = .eof
      writeBehavior = .wouldBlockStall
      channelRead = .oneChunkThenEOF(Data([1]))
      channelWrite = .accept
      scheduler = nil
    case .sshRead:
      readBehavior = .eof
      writeBehavior = .accept
      channelRead = .stall
      channelWrite = .accept
      scheduler = nil
    case .sshWrite:
      readBehavior = .oneChunkThenEOF(Data([1]))
      writeBehavior = .accept
      channelRead = .eof
      channelWrite = .stall
      scheduler = nil
    case .fairnessYield:
      readBehavior = .oneChunkThenEOF(Data([1, 2]))
      writeBehavior = .accept
      channelRead = .eof
      channelWrite = .accept
      scheduler = FirstYieldGateBytePumpScheduler()
    }

    local = StallLocalByteStream(readBehavior: readBehavior, writeBehavior: writeBehavior)
    channel = StallSSHByteChannel(readBehavior: channelRead, writeBehavior: channelWrite)
    self.scheduler = scheduler
    budget = try BytePumpBufferBudget(maximumReservedBytes: 16)
    pump = try BoundedFullDuplexBytePump(
      local: local,
      channel: channel,
      configuration: pumpConfiguration(
        localChunk: 8,
        remoteChunk: 8,
        maximumSSHWriteCall: 8,
        aggregate: 16,
        fairnessOperations: site == .fairnessYield ? 1 : 8,
        fairnessBytes: 8
      ),
      bufferBudget: budget,
      scheduler: scheduler ?? TaskBytePumpScheduler()
    )
  }

  var isSuspended: Bool {
    switch site {
    case .localReadable:
      local.pendingReadinessCount == 1
    case .localWritable:
      local.pendingReadinessCount == 1
    case .sshRead:
      channel.pendingReadCount == 1
    case .sshWrite:
      channel.pendingWriteCount == 1
    case .fairnessYield:
      scheduler?.firstYieldReached == true
    }
  }
}

private struct FailureFixture {
  let pump: BoundedFullDuplexBytePump
  let budget: BytePumpBufferBudget

  init(site: PumpFailureSite) throws {
    let localRead: StallLocalByteStream.ReadBehavior
    let localWrite: StallLocalByteStream.WriteBehavior
    let channelRead: StallSSHByteChannel.ReadBehavior
    let channelWrite: StallSSHByteChannel.WriteBehavior

    switch site {
    case .localRead:
      localRead = .error
      localWrite = .accept
      channelRead = .eof
      channelWrite = .accept
    case .sshWrite:
      localRead = .oneChunkThenEOF(Data([1]))
      localWrite = .accept
      channelRead = .eof
      channelWrite = .error
    case .sshRead:
      localRead = .eof
      localWrite = .accept
      channelRead = .error
      channelWrite = .accept
    case .localWrite:
      localRead = .eof
      localWrite = .error
      channelRead = .oneChunkThenEOF(Data([1]))
      channelWrite = .accept
    case .sshRemoteClosure:
      localRead = .eof
      localWrite = .accept
      channelRead = .remoteClosed
      channelWrite = .accept
    }

    let local = StallLocalByteStream(readBehavior: localRead, writeBehavior: localWrite)
    let channel = StallSSHByteChannel(readBehavior: channelRead, writeBehavior: channelWrite)
    budget = try BytePumpBufferBudget(maximumReservedBytes: 16)
    pump = try BoundedFullDuplexBytePump(
      local: local,
      channel: channel,
      configuration: pumpConfiguration(
        localChunk: 8,
        remoteChunk: 8,
        maximumSSHWriteCall: 8,
        aggregate: 16
      ),
      bufferBudget: budget
    )
  }
}

private final class RandomizedLocalByteStream: LocalNonblockingByteStream,
  @unchecked Sendable
{
  private let lock = NSLock()
  private let inbound: Data
  private let readPressureInterval: Int
  private let writePressureInterval: Int
  private var generator: PumpLCG
  private var readOffset = 0
  private var output = Data()
  private var readAttempts = 0
  private var writeAttempts = 0
  private var readPressureDelivered = false
  private var writePressureDelivered = false
  private var cancelled = false
  private var largestReadRequest = 0

  init(
    inbound: Data,
    seed: UInt64,
    readPressureInterval: Int,
    writePressureInterval: Int
  ) {
    self.inbound = inbound
    generator = PumpLCG(state: seed)
    self.readPressureInterval = readPressureInterval
    self.writePressureInterval = writePressureInterval
  }

  var writtenBytes: Data { lock.withLock { output } }
  var maximumReadRequest: Int { lock.withLock { largestReadRequest } }

  func readSome(maximumBytes: Int) async throws -> LocalByteStreamReadResult {
    try Task<Never, Never>.checkCancellation()
    return lock.withLock {
      if cancelled { return .endOfStream }
      largestReadRequest = max(largestReadRequest, maximumBytes)
      readAttempts += 1
      if readPressureInterval > 0,
        readAttempts.isMultiple(of: readPressureInterval),
        !readPressureDelivered
      {
        readPressureDelivered = true
        return .wouldBlock
      }
      readPressureDelivered = false
      guard readOffset < inbound.count else { return .endOfStream }
      let fragment = min(
        maximumBytes,
        min(inbound.count - readOffset, generator.nextInt(upperBound: 97) + 1)
      )
      let bytes = inbound[readOffset..<(readOffset + fragment)]
      readOffset += fragment
      return .bytes(bytes)
    }
  }

  func writeSome(_ bytes: Data) async throws -> LocalByteStreamWriteResult {
    try Task<Never, Never>.checkCancellation()
    return lock.withLock {
      if cancelled { return .peerClosed }
      writeAttempts += 1
      if writePressureInterval > 0,
        writeAttempts.isMultiple(of: writePressureInterval),
        !writePressureDelivered
      {
        writePressureDelivered = true
        return .wouldBlock
      }
      writePressureDelivered = false
      let count = min(bytes.count, generator.nextInt(upperBound: 83) + 1)
      output.append(bytes.prefix(count))
      return .written(count)
    }
  }

  func waitForReadiness(_ readiness: LocalByteStreamReadiness) async throws
    -> LocalByteStreamReadinessEvent
  {
    try Task<Never, Never>.checkCancellation()
    await Task.yield()
    try Task<Never, Never>.checkCancellation()
    return lock.withLock { cancelled ? .peerClosed : .ready }
  }

  func cancelPendingOperations() {
    lock.withLock { cancelled = true }
  }
}

private final class RandomizedSSHByteChannel: SSHByteChannel, @unchecked Sendable {
  let identity = SSHChannelIdentity(
    rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!)

  private let lock = NSLock()
  private let inbound: Data
  private var generator: PumpLCG
  private var readOffset = 0
  private var output = Data()
  private var cancelled = false
  private var largestReadRequest = 0
  private var largestWriteRequest = 0

  init(inbound: Data, seed: UInt64) {
    self.inbound = inbound
    generator = PumpLCG(state: seed)
  }

  var writtenBytes: Data { lock.withLock { output } }
  var maximumReadRequest: Int { lock.withLock { largestReadRequest } }
  var maximumWriteRequest: Int { lock.withLock { largestWriteRequest } }

  func read(maximumBytes: Int) async throws -> Data? {
    try Task<Never, Never>.checkCancellation()
    await Task.yield()
    try Task<Never, Never>.checkCancellation()
    return lock.withLock {
      if cancelled { return nil }
      largestReadRequest = max(largestReadRequest, maximumBytes)
      guard readOffset < inbound.count else { return nil }
      let fragment = min(
        maximumBytes,
        min(inbound.count - readOffset, generator.nextInt(upperBound: 89) + 1)
      )
      let bytes = inbound[readOffset..<(readOffset + fragment)]
      readOffset += fragment
      return bytes
    }
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    try Task<Never, Never>.checkCancellation()
    await Task.yield()
    try Task<Never, Never>.checkCancellation()
    return lock.withLock {
      if cancelled { return 0 }
      largestWriteRequest = max(largestWriteRequest, bytes.count)
      let count = min(bytes.count, generator.nextInt(upperBound: 67) + 1)
      output.append(bytes.prefix(count))
      return count
    }
  }

  func finishWriting() async throws {}

  func receiveWindow() async -> SSHDeferredSemanticReport<SSHReceiveWindowSnapshot> {
    .reported(fixtureReceiveWindow())
  }

  func cancel() async {
    lock.withLock { cancelled = true }
  }

  func reset() async {}
  func close() async {}
}

private final class ControllableLocalByteStream: LocalNonblockingByteStream,
  @unchecked Sendable
{
  private let lock = NSLock()
  private let inbound: Data
  private let readFragment: Int
  private var offset = 0
  private var reads = 0
  private var largestReadRequest = 0

  init(inbound: Data, readFragment: Int) {
    self.inbound = inbound
    self.readFragment = readFragment
  }

  var readCallCount: Int { lock.withLock { reads } }
  var maximumReadRequest: Int { lock.withLock { largestReadRequest } }

  func readSome(maximumBytes: Int) async throws -> LocalByteStreamReadResult {
    lock.withLock {
      reads += 1
      largestReadRequest = max(largestReadRequest, maximumBytes)
      guard offset < inbound.count else { return .endOfStream }
      let count = min(maximumBytes, min(readFragment, inbound.count - offset))
      let bytes = inbound[offset..<(offset + count)]
      offset += count
      return .bytes(bytes)
    }
  }

  func writeSome(_ bytes: Data) async throws -> LocalByteStreamWriteResult {
    .written(bytes.count)
  }

  func waitForReadiness(_ readiness: LocalByteStreamReadiness) async throws
    -> LocalByteStreamReadinessEvent
  {
    .ready
  }

  func cancelPendingOperations() {}
}

private final class ControllableSSHByteChannel: SSHByteChannel, @unchecked Sendable {
  let identity = SSHChannelIdentity(
    rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!)

  private let lock = NSLock()
  private let inbound: Data
  private let firstWriteSuspends: Bool
  private let maximumWriteAcceptance: Int
  private var readOffset = 0
  private var output = Data()
  private var writes = 0
  private var suspendedWrite: (Data, CheckedContinuation<Int, Error>)?

  init(inbound: Data, firstWriteSuspends: Bool, maximumWriteAcceptance: Int) {
    self.inbound = inbound
    self.firstWriteSuspends = firstWriteSuspends
    self.maximumWriteAcceptance = maximumWriteAcceptance
  }

  var hasSuspendedWrite: Bool { lock.withLock { suspendedWrite != nil } }
  var writeCallCount: Int { lock.withLock { writes } }
  var writtenBytes: Data { lock.withLock { output } }

  func read(maximumBytes: Int) async throws -> Data? {
    lock.withLock {
      guard readOffset < inbound.count else { return nil }
      let count = min(maximumBytes, inbound.count - readOffset)
      let bytes = inbound[readOffset..<(readOffset + count)]
      readOffset += count
      return bytes
    }
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    let shouldSuspend = lock.withLock { () -> Bool in
      writes += 1
      return firstWriteSuspends && writes == 1
    }
    if shouldSuspend {
      return try await withCheckedThrowingContinuation { continuation in
        lock.withLock { suspendedWrite = (bytes, continuation) }
      }
    }
    return accept(bytes)
  }

  func resumeFirstWrite() {
    let suspended = lock.withLock { () -> (Data, CheckedContinuation<Int, Error>)? in
      defer { suspendedWrite = nil }
      return suspendedWrite
    }
    guard let suspended else { return }
    suspended.1.resume(returning: accept(suspended.0))
  }

  private func accept(_ bytes: Data) -> Int {
    lock.withLock {
      let count = min(bytes.count, maximumWriteAcceptance)
      output.append(bytes.prefix(count))
      return count
    }
  }

  func finishWriting() async throws {}
  func receiveWindow() async -> SSHDeferredSemanticReport<SSHReceiveWindowSnapshot> {
    .reported(fixtureReceiveWindow())
  }

  func cancel() async {
    let suspended = lock.withLock { () -> CheckedContinuation<Int, Error>? in
      defer { suspendedWrite = nil }
      return suspendedWrite?.1
    }
    suspended?.resume(throwing: CancellationError())
  }

  func reset() async {}
  func close() async {}
}

private final class StallLocalByteStream: LocalNonblockingByteStream, @unchecked Sendable {
  enum ReadBehavior {
    case eof
    case oneChunkThenEOF(Data)
    case oneChunkThenStall(Data)
    case wouldBlockStall
    case error
  }

  enum WriteBehavior {
    case accept
    case wouldBlockStall
    case zero
    case error
  }

  private let lock = NSLock()
  private let readBehavior: ReadBehavior
  private let writeBehavior: WriteBehavior
  private var readCalls = 0
  private var chunkDelivered = false
  private var cancelled = false
  private var readinessWaiters: [CheckedContinuation<LocalByteStreamReadinessEvent, Error>] = []

  init(readBehavior: ReadBehavior, writeBehavior: WriteBehavior) {
    self.readBehavior = readBehavior
    self.writeBehavior = writeBehavior
  }

  var readCallCount: Int { lock.withLock { readCalls } }
  var pendingReadinessCount: Int { lock.withLock { readinessWaiters.count } }

  func readSome(maximumBytes: Int) async throws -> LocalByteStreamReadResult {
    if case .error = readBehavior {
      lock.withLock { readCalls += 1 }
      throw PumpFixtureError.injected
    }
    return lock.withLock {
      readCalls += 1
      switch readBehavior {
      case .eof:
        return .endOfStream
      case .oneChunkThenEOF(let bytes):
        guard !chunkDelivered else { return .endOfStream }
        chunkDelivered = true
        return .bytes(bytes.prefix(maximumBytes))
      case .oneChunkThenStall(let bytes):
        guard !chunkDelivered else { return .wouldBlock }
        chunkDelivered = true
        return .bytes(bytes.prefix(maximumBytes))
      case .wouldBlockStall:
        return .wouldBlock
      case .error:
        preconditionFailure("Error behavior is handled before entering the lock")
      }
    }
  }

  func writeSome(_ bytes: Data) async throws -> LocalByteStreamWriteResult {
    switch writeBehavior {
    case .accept:
      return .written(bytes.count)
    case .wouldBlockStall:
      return .wouldBlock
    case .zero:
      return .written(0)
    case .error:
      throw PumpFixtureError.injected
    }
  }

  func waitForReadiness(_ readiness: LocalByteStreamReadiness) async throws
    -> LocalByteStreamReadinessEvent
  {
    try await withCheckedThrowingContinuation { continuation in
      lock.lock()
      if cancelled {
        lock.unlock()
        continuation.resume(returning: .peerClosed)
      } else {
        readinessWaiters.append(continuation)
        lock.unlock()
      }
    }
  }

  func cancelPendingOperations() {
    let waiters = lock.withLock {
      () -> [CheckedContinuation<LocalByteStreamReadinessEvent, Error>] in
      cancelled = true
      defer { readinessWaiters.removeAll() }
      return readinessWaiters
    }
    for waiter in waiters {
      waiter.resume(returning: .peerClosed)
    }
  }
}

private final class StallSSHByteChannel: SSHByteChannel, @unchecked Sendable {
  enum ReadBehavior {
    case eof
    case stall
    case oneChunkThenEOF(Data)
    case oversized(Data)
    case error
    case remoteClosed
  }

  enum WriteBehavior {
    case accept
    case stall
    case lateSuccessOnCancel
    case zero
    case error
  }

  let identity = SSHChannelIdentity(
    rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!)

  private let lock = NSLock()
  private let readBehavior: ReadBehavior
  private let writeBehavior: WriteBehavior
  private var readDelivered = false
  private var writes = 0
  private var cancels = 0
  private var readWaiters: [CheckedContinuation<Data?, Error>] = []
  private var writeWaiters: [(Int, CheckedContinuation<Int, Error>)] = []

  init(readBehavior: ReadBehavior, writeBehavior: WriteBehavior) {
    self.readBehavior = readBehavior
    self.writeBehavior = writeBehavior
  }

  var pendingReadCount: Int { lock.withLock { readWaiters.count } }
  var pendingWriteCount: Int { lock.withLock { writeWaiters.count } }
  var writeCallCount: Int { lock.withLock { writes } }
  var cancelCallCount: Int { lock.withLock { cancels } }

  func read(maximumBytes: Int) async throws -> Data? {
    switch readBehavior {
    case .eof:
      return nil
    case .stall:
      return try await withCheckedThrowingContinuation { continuation in
        lock.withLock { readWaiters.append(continuation) }
      }
    case .oneChunkThenEOF(let bytes):
      return lock.withLock {
        guard !readDelivered else { return nil }
        readDelivered = true
        return bytes.prefix(maximumBytes)
      }
    case .oversized(let bytes):
      return lock.withLock {
        guard !readDelivered else { return nil }
        readDelivered = true
        return bytes
      }
    case .error:
      throw PumpFixtureError.injected
    case .remoteClosed:
      throw fixtureSSHClosedError(identity: identity)
    }
  }

  func writeSome(_ bytes: Data) async throws -> Int {
    lock.withLock { writes += 1 }
    switch writeBehavior {
    case .accept:
      return bytes.count
    case .zero:
      return 0
    case .error:
      throw PumpFixtureError.injected
    case .stall, .lateSuccessOnCancel:
      return try await withCheckedThrowingContinuation { continuation in
        lock.withLock { writeWaiters.append((bytes.count, continuation)) }
      }
    }
  }

  func finishWriting() async throws {}
  func receiveWindow() async -> SSHDeferredSemanticReport<SSHReceiveWindowSnapshot> {
    .reported(fixtureReceiveWindow())
  }

  func cancel() async {
    let pending = lock.withLock {
      cancels += 1
      let reads = readWaiters
      let writes = writeWaiters
      readWaiters.removeAll()
      writeWaiters.removeAll()
      return (reads, writes)
    }
    for read in pending.0 {
      read.resume(throwing: CancellationError())
    }
    for write in pending.1 {
      switch writeBehavior {
      case .lateSuccessOnCancel:
        write.1.resume(returning: write.0)
      case .accept, .stall, .zero, .error:
        write.1.resume(throwing: CancellationError())
      }
    }
  }

  func reset() async {}
  func close() async {}
}

private final class RecordingBytePumpDiagnostics: BytePumpDiagnosticsSink,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var updates: [BytePumpDiagnosticUpdate] = []

  func record(_ update: BytePumpDiagnosticUpdate) {
    lock.withLock { updates.append(update) }
  }

  func maximumBufferedBytes(for direction: BytePumpDirection) -> Int {
    lock.withLock {
      updates.compactMap { update -> Int? in
        guard case .bufferedBytes(let candidate, let count) = update,
          candidate == direction
        else { return nil }
        return count
      }.max() ?? 0
    }
  }

  func transferredBytes(for direction: BytePumpDirection) -> Int {
    lock.withLock {
      updates.reduce(into: 0) { result, update in
        guard case .bytes(let candidate, let count) = update,
          candidate == direction
        else { return }
        result += count
      }
    }
  }

  func pressureCount(for direction: BytePumpDirection) -> Int {
    lock.withLock {
      updates.count { update in
        guard case .pressure(let candidate, _) = update else { return false }
        return candidate == direction
      }
    }
  }

  func fairnessYieldCount(for direction: BytePumpDirection) -> Int {
    lock.withLock {
      updates.count { update in
        guard case .fairnessYield(let candidate) = update else { return false }
        return candidate == direction
      }
    }
  }
}

private actor RecordingBytePumpTerminalSink: BytePumpTerminalEventSink {
  private(set) var values: [BytePumpTerminalEvent] = []

  func receive(_ event: BytePumpTerminalEvent) {
    values.append(event)
  }
}

private final class FirstYieldGateBytePumpScheduler: BytePumpScheduler,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var firstReached = false
  private var firstReleased = false
  private var waiter: CheckedContinuation<Void, Error>?

  var firstYieldReached: Bool { lock.withLock { firstReached } }

  func yield() async throws {
    let shouldWait = lock.withLock { () -> Bool in
      guard !firstReached else { return false }
      firstReached = true
      return !firstReleased
    }
    guard shouldWait else {
      try Task<Never, Never>.checkCancellation()
      await Task.yield()
      return
    }

    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        lock.lock()
        if firstReleased {
          lock.unlock()
          continuation.resume()
        } else {
          waiter = continuation
          lock.unlock()
        }
      }
    } onCancel: {
      let waiter = lock.withLock { () -> CheckedContinuation<Void, Error>? in
        defer { self.waiter = nil }
        return self.waiter
      }
      waiter?.resume(throwing: CancellationError())
    }
  }

  func releaseFirstYield() {
    let waiter = lock.withLock { () -> CheckedContinuation<Void, Error>? in
      firstReleased = true
      defer { self.waiter = nil }
      return self.waiter
    }
    waiter?.resume()
  }
}

private actor ProgressProbe {
  private(set) var value = 0

  func advance() {
    value += 1
  }
}

private struct PumpLCG {
  var state: UInt64

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }

  mutating func nextInt(upperBound: Int) -> Int {
    Int(next() % UInt64(upperBound))
  }
}

private enum PumpFixtureError: Error {
  case injected
}

private func fixtureSSHClosedError(identity: SSHChannelIdentity) -> SSHTransportError {
  try! SSHTransportError(
    code: .channelClosed,
    phase: .channelRead,
    scope: .channel(identity),
    retryDisposition: .never,
    requiresTeardown: false,
    channelOpenReason: .notApplicable
  )
}

private func deterministicBytes(count: Int, seed: UInt64) -> Data {
  var generator = PumpLCG(state: seed)
  return Data((0..<count).map { _ in UInt8(truncatingIfNeeded: generator.next() >> 24) })
}

private func sha256Hex(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func pumpConfiguration(
  localChunk: Int = 8,
  remoteChunk: Int = 8,
  maximumSSHWriteCall: Int = 8,
  aggregate: Int = 16,
  fairnessOperations: Int = 8,
  fairnessBytes: Int = 64,
  readinessWakeups: Int = 4
) throws -> BoundedFullDuplexBytePumpConfiguration {
  try BoundedFullDuplexBytePumpConfiguration(
    localReadChunkBytes: localChunk,
    remoteReadChunkBytes: remoteChunk,
    maximumSSHWriteCallBytes: maximumSSHWriteCall,
    maximumAggregateReservedBytes: aggregate,
    fairnessMaximumOperations: fairnessOperations,
    fairnessMaximumBytes: fairnessBytes,
    maximumConsecutiveReadinessWakeupsWithoutProgress: readinessWakeups
  )
}

private func makeStalledPump(
  configuration: BoundedFullDuplexBytePumpConfiguration,
  budget: BytePumpBufferBudget
) throws -> (pump: BoundedFullDuplexBytePump, channel: StallSSHByteChannel) {
  let local = StallLocalByteStream(
    readBehavior: .oneChunkThenStall(Data([1])),
    writeBehavior: .accept
  )
  let channel = StallSSHByteChannel(readBehavior: .stall, writeBehavior: .stall)
  let pump = try BoundedFullDuplexBytePump(
    local: local,
    channel: channel,
    configuration: configuration,
    bufferBudget: budget
  )
  return (pump, channel)
}

private func fixtureReceiveWindow() -> SSHReceiveWindowSnapshot {
  try! SSHReceiveWindowSnapshot(
    initialReceiveWindowBytes: 1,
    maximumAdvertisedReceiveWindowBytes: 1,
    remainingProtocolCreditBytes: 1,
    bufferedUnreadBytes: 0,
    deliveredButNotYetReturnedCreditBytes: 0,
    adjustmentCount: 0,
    cumulativeAdjustmentBytes: 0
  )
}

private func pumpEventually(
  iterations: Int = 10_000,
  _ condition: @escaping @Sendable () -> Bool
) async -> Bool {
  for _ in 0..<iterations {
    if condition() { return true }
    await Task.yield()
  }
  return condition()
}
