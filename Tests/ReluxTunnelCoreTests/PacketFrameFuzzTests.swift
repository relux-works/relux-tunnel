import Darwin
import Foundation
import ReluxTunnelCore
import Testing

@Suite("Packet frame deterministic fuzz and allocation bounds", .serialized)
struct PacketFrameFuzzTests {
  @Test("seed manifest covers required frame classes and prior regressions")
  func seedManifest() {
    let seeds = PacketFrameFuzzCorpus.seeds
    #expect(Set(seeds.map(\.id)).count == seeds.count)
    let categories = seeds.reduce(into: Set<PacketFrameCorpusCategory>()) {
      $0.formUnion($1.categories)
    }
    #expect(categories == Set(PacketFrameCorpusCategory.allCases))
    #expect(seeds.first(where: { $0.id == "one-byte" })?.frame.count == 1)
    #expect(seeds.first(where: { $0.id == "two-byte" })?.frame.count == 2)
    #expect(seeds.first(where: { $0.id == "three-byte" })?.frame.count == 3)
    #expect(
      seeds.first(where: { $0.categories.contains(.exactMTU) })?.frame.count
        == PacketFrameFuzzCorpus.maximumDatagramBytes
    )
    #expect(
      seeds.first(where: { $0.categories.contains(.overMTU) })?.frame.count
        == PacketFrameFuzzCorpus.maximumDatagramBytes + 1
    )
  }

  @Test("coalesced arbitrary bytes split deterministically without declared-length allocation")
  func coalescedInputSplitter() {
    let configuration = PacketFrameFuzzConfiguration.current()
    let maximum = PacketFrameFuzzCorpus.maximumDatagramBytes
    let adversarial =
      Data([0xff, 0xff, 0xff, 0xff])
      + Data(repeating: 0xa5, count: maximum + 8)
    let adversarialFrames = PacketFrameCoalescedInput.split(
      adversarial,
      maximumDatagramBytes: maximum
    )
    #expect(adversarialFrames.map(\.count) == [maximum + 1])

    let generated = PacketFrameFuzzCorpus.generatedFrames(
      seed: configuration.seed,
      iterations: configuration.iterations,
      mtu: PacketFrameFuzzCorpus.mtu,
      includeOversized: true
    )
    let encoded = PacketFrameCoalescedInput.encode(generated)
    let replay = PacketFrameCoalescedInput.split(encoded, maximumDatagramBytes: maximum)
    #expect(replay == generated)
    #expect(replay.allSatisfy { $0.count <= maximum + 1 })
    #expect(replay.reduce(0) { $0 + $1.count } <= encoded.count)

    var generator = SplitMix64(seed: configuration.seed ^ 0xc0a1_e5ce_d)
    for iteration in 0..<configuration.iterations {
      let arbitrary = generator.bytes(count: generator.nextInt(upperBound: maximum * 2 + 1))
      let split = PacketFrameCoalescedInput.split(
        arbitrary,
        maximumDatagramBytes: maximum
      )
      let replaySplit = PacketFrameCoalescedInput.split(
        arbitrary,
        maximumDatagramBytes: maximum
      )
      #expect(split == replaySplit, "seed=\(configuration.seed) iteration=\(iteration)")
      #expect(split.allSatisfy { $0.count <= maximum + 1 })
      #expect(split.reduce(0) { $0 + $1.count } <= arbitrary.count)
    }
  }

  @Test("fixture minimization preserves a replayable invariant violation")
  func fixtureMinimization() {
    let input = Data([0xaa, 0xbb, 0xde, 0xad, 0xbe, 0xef, 0xcc, 0xdd])
    let marker = Data([0xde, 0xad, 0xbe, 0xef])
    let minimized = PacketFrameFixtureMinimizer.minimize(input) { candidate in
      candidate.range(of: marker) != nil
    }
    #expect(minimized == marker)
    #expect(packetFrameHex(minimized) == "deadbeef")
  }

  @Test(
    "reverse parser replays hostile corpus with bounded runtime, allocation, and counters",
    .timeLimit(.minutes(1))
  )
  func reverseHostileCorpus() async throws {
    let fuzz = PacketFrameFuzzConfiguration.current()
    let mtu = PacketFrameFuzzCorpus.mtu
    let maximum = mtu + 4
    let generated = PacketFrameFuzzCorpus.generatedFrames(
      seed: fuzz.seed,
      iterations: fuzz.iterations,
      mtu: mtu,
      includeOversized: false
    )
    let corpus =
      PacketFrameFuzzCorpus.seeds
      .filter { !$0.categories.contains(.overMTU) }
      .map(\.frame) + generated
    let expected = corpus.map { PacketFrameFuzzCorpus.classify($0, mtu: mtu) }
    let expectedMalformed = malformedCounts(expected)
    let expectedPackets = expected.compactMap { disposition -> TunnelPacket? in
      guard case .valid(let packet) = disposition else { return nil }
      return packet
    }
    #expect(
      expected.allSatisfy { disposition in
        if case .oversized = disposition { return false }
        return true
      })
    #expect(corpus.reduce(0) { $0 + $1.count } <= corpus.count * maximum)

    let fixture = BridgeFixture(mtu: mtu, maximumWorkCount: 32)
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    fixture.socketIO.enqueueReceives(corpus.map { .datagram($0) })

    let baselineAllocation = currentMallocBytesInUse()
    var peakAllocation = baselineAllocation
    var previousReceived: UInt64 = 0
    let started = ContinuousClock().now
    var processed = 0
    while processed < corpus.count {
      fixture.readinessFactory.latest?.signal(.readable)
      let target = min(corpus.count, processed + fixture.configuration.maximumWorkCount)
      #expect(
        await eventually {
          let metrics = await fixture.bridge.metrics()
          return metrics.counters["packet_bridge_reverse_datagrams_received_total"]
            == UInt64(target)
        },
        "replay seed=\(fuzz.seed) frame_index=\(processed)"
      )
      let expectedWritten = expected.prefix(target).reduce(into: 0) { count, disposition in
        if case .valid = disposition {
          count += 1
        }
      }
      #expect(await eventually { await flow.writtenPackets.count == expectedWritten })
      let metrics = await fixture.bridge.metrics()
      let received = metrics.counters["packet_bridge_reverse_datagrams_received_total"] ?? 0
      #expect(received >= previousReceived)
      previousReceived = received
      processed = target
      peakAllocation = max(peakAllocation, currentMallocBytesInUse())
    }
    let elapsed = started.duration(to: ContinuousClock().now)

    let metrics = await fixture.bridge.metrics()
    #expect(
      metrics.counters["packet_bridge_reverse_datagrams_received_total"] == UInt64(corpus.count))
    #expect(
      metrics.counters["packet_bridge_reverse_drop_malformed_total"]
        == UInt64(expectedMalformed.values.reduce(0, +))
    )
    #expect(await flow.writtenPackets == expectedPackets)
    #expect(metrics.gauges["packet_bridge_reverse_datagram_max_bytes"] == Int64(maximum))
    for reason in PacketFrameMalformedReason.allCases {
      #expect(expectedMalformed[reason, default: 0] > 0, "reason=\(reason.rawValue)")
    }
    assertPrivacySafe(fixture.logger.messages)
    await fixture.bridge.stop()

    let elapsedMilliseconds = durationMilliseconds(elapsed)
    let allocationGrowth =
      peakAllocation >= baselineAllocation
      ? peakAllocation - baselineAllocation : 0
    #expect(elapsedMilliseconds <= fuzz.runtimeCeilingMilliseconds)
    #expect(allocationGrowth <= fuzz.allocationCeilingBytes)
    print(
      "PACKET_FRAME_FUZZ_REPORT direction=reverse seed=\(fuzz.seed) "
        + "iterations=\(fuzz.iterations) duration_ms=\(elapsedMilliseconds) "
        + "peak_allocation_bytes=\(allocationGrowth) revision=\(fuzz.sourceRevision) "
        + malformedReport(expectedMalformed)
    )
  }

  @Test(
    "forward framing rejects hostile typed packets before bounded datagram allocation",
    .timeLimit(.minutes(1))
  )
  func forwardHostileCorpus() async throws {
    let fuzz = PacketFrameFuzzConfiguration.current()
    let mtu = PacketFrameFuzzCorpus.mtu
    let generated = PacketFrameFuzzCorpus.generatedFrames(
      seed: fuzz.seed ^ 0xf0_12_a4_d,
      iterations: fuzz.iterations,
      mtu: mtu,
      includeOversized: false
    )
    let inputs: [(PacketReadResult, Bool)] = generated.enumerated().map { index, bytes in
      if index.isMultiple(of: 7) {
        return (.malformed(.unsupportedAddressFamily(Int32.max)), false)
      }
      let family: PacketAddressFamily = index.isMultiple(of: 2) ? .ipv4 : .ipv6
      let payload = Data(bytes.prefix(mtu))
      let isValid =
        payload.first.map { first in
          first >> 4 == (family == .ipv4 ? 4 : 6)
        } ?? false
      return (.packet(TunnelPacket(payload: payload, addressFamily: family)), isValid)
    }
    let expectedMalformed = inputs.reduce(0) { $0 + ($1.1 ? 0 : 1) }
    let expectedFrames = inputs.compactMap { result, isValid -> Data? in
      guard isValid, case .packet(let packet) = result else { return nil }
      let family = packet.addressFamily == .ipv4 ? AF_INET : AF_INET6
      return fuzzFamilyWord(family) + packet.payload
    }

    let fixture = BridgeFixture(mtu: mtu, maximumWorkCount: 32)
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    let baselineAllocation = currentMallocBytesInUse()
    var peakAllocation = baselineAllocation
    let started = ContinuousClock().now
    var processed = 0
    while processed < inputs.count {
      let upperBound = min(inputs.count, processed + 32)
      await flow.enqueue(PacketReadBatch(results: inputs[processed..<upperBound].map(\.0)))
      let expectedSent = inputs[..<upperBound].reduce(0) { $0 + ($1.1 ? 1 : 0) }
      #expect(
        await eventually {
          let metrics = await fixture.bridge.metrics()
          return metrics.counters["packet_bridge_forward_packets_received_total"]
            == UInt64(upperBound)
            && fixture.socketIO.sentDatagrams.count == expectedSent
        },
        "replay seed=\(fuzz.seed) packet_index=\(processed)"
      )
      processed = upperBound
      peakAllocation = max(peakAllocation, currentMallocBytesInUse())
    }
    let elapsed = started.duration(to: ContinuousClock().now)
    let metrics = await fixture.bridge.metrics()
    #expect(fixture.socketIO.sentDatagrams == expectedFrames)
    #expect(fixture.socketIO.sentDatagrams.allSatisfy { $0.count <= mtu + 4 })
    #expect(
      metrics.counters["packet_bridge_forward_packets_received_total"] == UInt64(inputs.count))
    #expect(
      metrics.counters["packet_bridge_forward_drop_malformed_total"] == UInt64(expectedMalformed))
    #expect(
      metrics.counters["packet_bridge_forward_datagrams_sent_total"] == UInt64(expectedFrames.count)
    )
    assertPrivacySafe(fixture.logger.messages)
    await fixture.bridge.stop()

    let elapsedMilliseconds = durationMilliseconds(elapsed)
    let allocationGrowth =
      peakAllocation >= baselineAllocation
      ? peakAllocation - baselineAllocation : 0
    #expect(elapsedMilliseconds <= fuzz.runtimeCeilingMilliseconds)
    #expect(allocationGrowth <= fuzz.allocationCeilingBytes)
    print(
      "PACKET_FRAME_FUZZ_REPORT direction=forward seed=\(fuzz.seed) "
        + "iterations=\(fuzz.iterations) duration_ms=\(elapsedMilliseconds) "
        + "peak_allocation_bytes=\(allocationGrowth) revision=\(fuzz.sourceRevision) "
        + "malformed=\(expectedMalformed)"
    )
  }

  @Test("over-MTU replay fixtures are fatal before forwarding or packet writes")
  func oversizedReplayFixtures() async throws {
    let overMTU = try #require(
      PacketFrameFuzzCorpus.seeds.first { $0.categories.contains(.overMTU) }
    )
    let maximum = PacketFrameFuzzCorpus.maximumDatagramBytes

    do {
      let fixture = BridgeFixture(mtu: PacketFrameFuzzCorpus.mtu)
      let flow = FakePacketFlow(events: fixture.events)
      let handle = try await fixture.bridge.start(
        packetFlow: flow,
        configuration: fixture.configuration
      )
      fixture.socketIO.enqueueReceives([
        .datagram(
          Data(overMTU.frame.prefix(maximum)),
          fullBytes: overMTU.frame.count,
          truncated: true
        )
      ])
      fixture.readinessFactory.latest?.signal(.readable)
      await #expect(
        throws: PacketFlowBridgeError.messageTooLarge(
          direction: .reverse,
          datagramBytes: overMTU.frame.count,
          configuredMaximumBytes: maximum
        )
      ) {
        try await handle.waitForTermination()
      }
      #expect(await flow.writeAttemptCount == 0)
    }

    do {
      let fixture = BridgeFixture(mtu: PacketFrameFuzzCorpus.mtu)
      let flow = FakePacketFlow(events: fixture.events)
      let handle = try await fixture.bridge.start(
        packetFlow: flow,
        configuration: fixture.configuration
      )
      let payload = Data(overMTU.frame.dropFirst(4))
      await flow.enqueue(
        PacketReadBatch(results: [
          .packet(TunnelPacket(payload: payload, addressFamily: .ipv6))
        ])
      )
      await #expect(
        throws: PacketFlowBridgeError.messageTooLarge(
          direction: .forward,
          datagramBytes: overMTU.frame.count,
          configuredMaximumBytes: maximum
        )
      ) {
        try await handle.waitForTermination()
      }
      #expect(fixture.socketIO.sentDatagrams.isEmpty)
    }
  }

  @Test("boundary MTUs preserve exact frames", arguments: [1, 68, 576, 1_280, 1_500, 9_000])
  func boundaryMTUs(mtu: Int) async throws {
    let payload = Data([0x45]) + Data(repeating: 0xa5, count: mtu - 1)
    let fixture = BridgeFixture(mtu: mtu)
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    await flow.enqueue(
      PacketReadBatch(results: [
        .packet(TunnelPacket(payload: payload, addressFamily: .ipv4))
      ])
    )
    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 1 })
    #expect(fixture.socketIO.sentDatagrams == [fuzzFamilyWord(AF_INET) + payload])

    fixture.socketIO.enqueueReceives([.datagram(fuzzFamilyWord(AF_INET) + payload)])
    fixture.readinessFactory.latest?.signal(.readable)
    #expect(await eventually { await flow.writtenPackets.count == 1 })
    #expect(await flow.writtenPackets == [TunnelPacket(payload: payload, addressFamily: .ipv4)])
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.gauges["packet_bridge_forward_datagram_max_bytes"] == Int64(mtu + 4))
    #expect(metrics.gauges["packet_bridge_reverse_datagram_max_bytes"] == Int64(mtu + 4))
    await fixture.bridge.stop()
  }
}

private func malformedCounts(
  _ dispositions: [PacketFrameDisposition]
) -> [PacketFrameMalformedReason: Int] {
  dispositions.reduce(into: [:]) { counts, disposition in
    if case .malformed(let reason) = disposition {
      counts[reason, default: 0] += 1
    }
  }
}

private func malformedReport(_ counts: [PacketFrameMalformedReason: Int]) -> String {
  PacketFrameMalformedReason.allCases
    .map { "\($0.rawValue)=\(counts[$0, default: 0])" }
    .joined(separator: " ")
}

private func durationMilliseconds(_ duration: Duration) -> Int {
  let components = duration.components
  let seconds = components.seconds.multipliedReportingOverflow(by: 1_000)
  guard !seconds.overflow else { return .max }
  let attoseconds = components.attoseconds / 1_000_000_000_000_000
  let total = seconds.partialValue.addingReportingOverflow(Int64(attoseconds))
  guard !total.overflow else { return .max }
  return Int(clamping: total.partialValue)
}

private func assertPrivacySafe(_ messages: [FakeTunnelLogger.Message]) {
  let forbidden = [
    "payload", "packet", "destination", "address", "hostname", "port", "credential",
  ]
  for message in messages {
    #expect(
      message.fields.keys.allSatisfy { key in
        forbidden.allSatisfy { !key.localizedCaseInsensitiveContains($0) }
      })
  }
}
