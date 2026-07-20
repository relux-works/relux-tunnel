import Darwin
import Foundation
import ReluxTunnelCore
import Testing

@Suite("PacketFlowBridge deterministic fault injection")
struct PacketFlowBridgeFaultTests {
  @Test("forward malformed packets count as work and preserve the valid boundary")
  func forwardMalformedWork() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    let valid = Data([0x45, 0xaa, 0xbb])

    await flow.enqueue(
      PacketReadBatch(results: [
        .packet(TunnelPacket(payload: Data(), addressFamily: .ipv4)),
        .packet(TunnelPacket(payload: Data([0x60]), addressFamily: .ipv4)),
        .malformed(.unsupportedAddressFamily(Int32.max)),
        .packet(TunnelPacket(payload: valid, addressFamily: .ipv4)),
      ]))

    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 1 })
    #expect(fixture.socketIO.sentDatagrams == [familyWord(AF_INET) + valid])
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_forward_packets_received_total"] == 4)
    #expect(metrics.counters["packet_bridge_forward_drop_malformed_total"] == 3)
    #expect(metrics.counters["packet_bridge_forward_datagrams_sent_total"] == 1)
    #expect(metrics.counters["packet_bridge_forward_payload_bytes_received_total"] == 3)
    await fixture.bridge.stop()
  }

  @Test("pre-send checked 4+MTU ceiling is fatal without a syscall or side storage")
  func forwardSyntheticMessageTooLarge() async throws {
    let fixture = BridgeFixture(mtu: 4)
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    let oversized = TunnelPacket(payload: Data([0x45, 1, 2, 3, 4]), addressFamily: .ipv4)
    await flow.enqueue(PacketReadBatch(results: [.packet(oversized)]))

    await #expect(
      throws: PacketFlowBridgeError.messageTooLarge(
        direction: .forward,
        datagramBytes: 9,
        configuredMaximumBytes: 8
      )
    ) {
      try await handle.waitForTermination()
    }
    #expect(fixture.socketIO.sentDatagrams.isEmpty)
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_fatal_message_too_large_total"] == 1)
    #expect(metrics.gauges["packet_bridge_forward_datagram_max_bytes"] == 9)
  }

  @Test("zero and positive short datagram sends are fatal and never retried", arguments: [0, 2])
  func shortDatagramSend(actualBytes: Int) async throws {
    let fixture = BridgeFixture()
    fixture.socketIO.enqueueSends([.short(actualBytes)])
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    await flow.enqueue(
      PacketReadBatch(results: [
        .packet(TunnelPacket(payload: Data([0x45, 1]), addressFamily: .ipv4))
      ]))

    await #expect(
      throws: PacketFlowBridgeError.shortDatagramSend(
        expectedBytes: 6,
        actualBytes: actualBytes
      )
    ) {
      try await handle.waitForTermination()
    }
    #expect(fixture.socketIO.sentDatagrams.count == 1)
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_fatal_socket_error_total"] == 1)
    #expect(metrics.counters["packet_bridge_forward_datagrams_sent_total"] == 0)
  }

  @Test("EAGAIN and EWOULDBLOCK normalize while ENOBUFS drops without retry")
  func forwardBackpressureNormalization() async throws {
    let fixture = BridgeFixture()
    fixture.socketIO.enqueueSends([
      .error(EAGAIN),
      .error(EWOULDBLOCK),
      .error(ENOBUFS),
      .full,
    ])
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    let packet = PacketReadResult.packet(
      TunnelPacket(payload: Data([0x45, 1]), addressFamily: .ipv4))
    await flow.enqueue(PacketReadBatch(results: [packet, packet, packet, packet]))

    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 4 })
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_forward_drop_would_block_total"] == 2)
    #expect(metrics.counters["packet_bridge_forward_drop_no_buffer_total"] == 1)
    #expect(metrics.counters["packet_bridge_forward_datagrams_sent_total"] == 1)
    #expect(metrics.counters["packet_bridge_terminal_failure_total"] == 0)
    #expect(fixture.logger.messages.allSatisfy { $0.message != "packet_bridge.fatal" })
    await fixture.bridge.stop()
  }

  @Test("unclassified forward errno is one fatal transition without retry")
  func forwardPersistentError() async throws {
    let fixture = BridgeFixture()
    fixture.socketIO.enqueueSends([.error(EIO), .full])
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    await flow.enqueue(
      PacketReadBatch(results: [
        .packet(TunnelPacket(payload: Data([0x45, 1]), addressFamily: .ipv4))
      ]))

    await #expect(
      throws: PacketFlowBridgeError.socketError(operation: .send, errno: EIO)
    ) {
      try await handle.waitForTermination()
    }
    #expect(fixture.socketIO.sentDatagrams.count == 1)
    #expect(fixture.logger.messages.filter { $0.message == "packet_bridge.fatal" }.count == 1)
  }

  @Test("reverse framing covers every malformed length and family/version rule")
  func reverseMalformedRules() async throws {
    let fixture = BridgeFixture(maximumWorkCount: 16)
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    let ipv4 = Data([0x45, 0x10])
    let ipv6 = Data([0x60, 0x20, 0x30])
    fixture.socketIO.enqueueReceives([
      .datagram(Data()),
      .datagram(Data([0])),
      .datagram(Data([0, 0])),
      .datagram(Data([0, 0, 0])),
      .datagram(familyWord(AF_INET)),
      .datagram(familyWord(Int32.max) + Data([0x45])),
      .datagram(familyWord(AF_INET) + Data([0x60])),
      .datagram(familyWord(AF_INET6) + Data([0x45])),
      .datagram(familyWord(AF_INET) + ipv4),
      .datagram(familyWord(AF_INET6) + ipv6),
    ])
    fixture.readinessFactory.latest?.signal(.readable)

    #expect(await eventually { await flow.writtenPackets.count == 2 })
    #expect(
      await flow.writtenBatches == [
        [
          TunnelPacket(payload: ipv4, addressFamily: .ipv4),
          TunnelPacket(payload: ipv6, addressFamily: .ipv6),
        ]
      ]
    )
    #expect(
      await eventually {
        let snapshot = await fixture.bridge.metrics()
        return snapshot.counters["packet_bridge_reverse_batches_written_total"] == 1
      })
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_reverse_datagrams_received_total"] == 10)
    #expect(metrics.counters["packet_bridge_reverse_drop_malformed_total"] == 8)
    #expect(metrics.counters["packet_bridge_fatal_peer_eof_total"] == 0)
    #expect(metrics.counters["packet_bridge_reverse_batches_written_total"] == 1)
    await fixture.bridge.stop()
  }

  @Test("reverse would-block spellings and ENOBUFS end drains without claiming packet loss")
  func reverseBackpressureNormalization() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    fixture.socketIO.enqueueReceives([.error(EAGAIN), .error(EWOULDBLOCK), .error(ENOBUFS)])

    fixture.readinessFactory.latest?.signal(.readable)
    #expect(
      await eventually {
        let snapshot = await fixture.bridge.metrics()
        return snapshot.counters["packet_bridge_reverse_drain_would_block_total"] == 1
      })
    fixture.readinessFactory.latest?.signal(.readable)
    #expect(
      await eventually {
        let snapshot = await fixture.bridge.metrics()
        return snapshot.counters["packet_bridge_reverse_drain_would_block_total"] == 2
      })
    fixture.readinessFactory.latest?.signal(.readable)
    #expect(
      await eventually {
        let snapshot = await fixture.bridge.metrics()
        return snapshot.counters["packet_bridge_reverse_receive_no_buffer_total"] == 1
      })

    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_reverse_datagrams_received_total"] == 0)
    #expect(metrics.counters["packet_bridge_reverse_drop_malformed_total"] == 0)
    #expect(fixture.socketIO.receiveAttemptCount == 3)
    await fixture.bridge.stop()
  }

  @Test("reverse MSG_TRUNC reports the full observed size and fails before write")
  func reverseTruncation() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    fixture.socketIO.enqueueReceives([
      .datagram(Data(repeating: 0x45, count: 24), fullBytes: 31, truncated: true)
    ])
    fixture.readinessFactory.latest?.signal(.readable)

    await #expect(
      throws: PacketFlowBridgeError.messageTooLarge(
        direction: .reverse,
        datagramBytes: 31,
        configuredMaximumBytes: 24
      )
    ) {
      try await handle.waitForTermination()
    }
    #expect(await flow.writeAttemptCount == 0)
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.gauges["packet_bridge_reverse_datagram_max_bytes"] == 31)
    #expect(metrics.counters["packet_bridge_fatal_message_too_large_total"] == 1)
  }

  @Test("reverse full datagram size over 4+MTU is fatal even without MSG_TRUNC")
  func reverseObservedOversize() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    fixture.socketIO.enqueueReceives([
      .datagram(Data(repeating: 0x45, count: 24), fullBytes: 25, truncated: false)
    ])
    fixture.readinessFactory.latest?.signal(.readable)

    await #expect(
      throws: PacketFlowBridgeError.messageTooLarge(
        direction: .reverse,
        datagramBytes: 25,
        configuredMaximumBytes: 24
      )
    ) {
      try await handle.waitForTermination()
    }
    #expect(fixture.socketIO.receiveAttemptCount == 1)
    #expect(await flow.writeAttemptCount == 0)
  }

  @Test("reverse EMSGSIZE errno is fatal without retry")
  func reverseMessageTooLargeErrno() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    fixture.socketIO.enqueueReceives([.error(EMSGSIZE), .error(EAGAIN)])
    fixture.readinessFactory.latest?.signal(.readable)

    await #expect(
      throws: PacketFlowBridgeError.messageTooLarge(
        direction: .reverse,
        datagramBytes: 24,
        configuredMaximumBytes: 24
      )
    ) {
      try await handle.waitForTermination()
    }
    #expect(fixture.socketIO.receiveAttemptCount == 1)
  }

  @Test("readiness peer close is exact peer EOF and closes only after borrow return")
  func readinessPeerClosed() async throws {
    let fixture = BridgeFixture(autoReturnBorrowOnStop: false)
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    fixture.readinessFactory.latest?.signal(.peerClosed)
    #expect(
      await eventually {
        if case .failing = await fixture.bridge.lifecycleState() { return true }
        return false
      })
    #expect(fixture.socketIO.closeAttempts.isEmpty)
    fixture.consumer.latest?.returnNow()

    await #expect(
      throws: PacketFlowBridgeError.peerEOF(operation: .readiness)
    ) {
      try await handle.waitForTermination()
    }
    #expect(fixture.socketIO.closeAttempts == [101, 100])
  }

  @Test("unexpected HEV return is peer EOF and remains the primary error")
  func unexpectedBorrowReturn() async throws {
    let fixture = BridgeFixture(autoReturnBorrowOnStop: false)
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    fixture.consumer.latest?.returnNow()

    await #expect(
      throws: PacketFlowBridgeError.peerEOF(operation: .descriptorBorrow)
    ) {
      try await handle.waitForTermination()
    }
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_fatal_peer_eof_total"] == 1)
    #expect(fixture.consumer.latest?.snapshot().stopRequestCount == 1)
    #expect(fixture.socketIO.closeAttempts == [101, 100])
  }

  @Test("PacketFlow read errors are fatal and do not schedule another read")
  func packetFlowReadFailure() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    await flow.enqueueError(.writeRejected)

    await #expect(
      throws: PacketFlowBridgeError.packetFlowFailure(operation: .packetFlowRead)
    ) {
      try await handle.waitForTermination()
    }
    #expect(await flow.readCallCount == 1)
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_fatal_packet_flow_error_total"] == 1)
  }

  @Test("failed closes are attempted once, preserve success, and omit descriptors from logs")
  func closeFailuresAreNotRetried() async throws {
    let fixture = BridgeFixture()
    fixture.socketIO.failClose(descriptor: 100)
    fixture.socketIO.failClose(descriptor: 101)
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )

    await fixture.bridge.stop()
    try await handle.waitForTermination()

    #expect(fixture.socketIO.closeAttempts == [101, 100])
    #expect(fixture.socketIO.closedDescriptors.isEmpty)
    let metrics = await fixture.bridge.metrics()
    #expect(metrics.counters["packet_bridge_cleanup_close_error_total"] == 2)
    let warnings = fixture.logger.messages.filter { $0.message == "packet_bridge.close_failed" }
    #expect(warnings.count == 2)
    #expect(warnings.allSatisfy { !$0.fields.keys.contains("descriptor") })
    #expect(
      warnings.allSatisfy { !$0.fields.values.contains { $0.value == "100" || $0.value == "101" } })
  }

  @Test("all endpoint buffer readbacks remain asymmetric and clamping logs once")
  func endpointSpecificBufferGauges() async throws {
    let fixture = BridgeFixture(sendBufferBytes: 5000, receiveBufferBytes: 6000)
    fixture.socketIO.setEffectiveBuffer(.send, descriptor: 100, bytes: 1000)
    fixture.socketIO.setEffectiveBuffer(.receive, descriptor: 100, bytes: 2000)
    fixture.socketIO.setEffectiveBuffer(.send, descriptor: 101, bytes: 3000)
    fixture.socketIO.setEffectiveBuffer(.receive, descriptor: 101, bytes: 4000)
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)

    let gauges = await fixture.bridge.metrics().gauges
    #expect(gauges["packet_bridge_socket_a_send_buffer_requested_bytes"] == 5000)
    #expect(gauges["packet_bridge_socket_a_send_buffer_effective_bytes"] == 1000)
    #expect(gauges["packet_bridge_socket_a_receive_buffer_requested_bytes"] == 6000)
    #expect(gauges["packet_bridge_socket_a_receive_buffer_effective_bytes"] == 2000)
    #expect(gauges["packet_bridge_socket_b_send_buffer_requested_bytes"] == 5000)
    #expect(gauges["packet_bridge_socket_b_send_buffer_effective_bytes"] == 3000)
    #expect(gauges["packet_bridge_socket_b_receive_buffer_requested_bytes"] == 6000)
    #expect(gauges["packet_bridge_socket_b_receive_buffer_effective_bytes"] == 4000)
    #expect(gauges["packet_bridge_configured_mtu_bytes"] == 20)
    #expect(gauges["packet_bridge_configured_max_datagram_bytes"] == 24)
    #expect(
      fixture.logger.messages.filter { $0.message == "packet_bridge.socket_buffer_clamped" }.count
        == 1)
    await fixture.bridge.stop()
  }

  @Test("drop summaries are window-limited and flush unsummarized drops at stop")
  func dropSummaryRateLimiting() async throws {
    let clock = ManualTunnelClock()
    let fixture = BridgeFixture(
      diagnosticsWindow: .seconds(10),
      clock: clock
    )
    fixture.socketIO.enqueueSends([.error(EAGAIN), .error(EAGAIN), .error(ENOBUFS)])
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    let packet = PacketReadResult.packet(
      TunnelPacket(payload: Data([0x45, 1]), addressFamily: .ipv4))

    await flow.enqueue(PacketReadBatch(results: [packet]))
    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 1 })
    #expect(fixture.logger.messages.filter { $0.message == "packet_bridge.drop_summary" }.isEmpty)

    clock.advance(by: .seconds(10))
    await flow.enqueue(PacketReadBatch(results: [packet]))
    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 2 })
    #expect(
      fixture.logger.messages.filter { $0.message == "packet_bridge.drop_summary" }.count == 1)

    await flow.enqueue(PacketReadBatch(results: [packet]))
    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 3 })
    #expect(
      fixture.logger.messages.filter { $0.message == "packet_bridge.drop_summary" }.count == 1)

    await fixture.bridge.stop()
    #expect(
      fixture.logger.messages.filter { $0.message == "packet_bridge.drop_summary" }.count == 2)
    #expect(clock.sleepCallCount == 0)
  }

  @Test("run counters saturate at UInt64.max and log saturation once")
  func saturatingCounters() async throws {
    let fixture = BridgeFixture()
    let flow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(packetFlow: flow, configuration: fixture.configuration)
    let anomaly = PacketFlowError.packetProtocolCardinalityMismatch(
      packetCount: Int.max,
      protocolCount: 0
    )

    await flow.enqueueError(anomaly)
    await flow.enqueueError(anomaly)
    await flow.enqueueError(anomaly)

    #expect(
      await eventually {
        let snapshot = await fixture.bridge.metrics()
        return snapshot.counters["packet_bridge_forward_drop_malformed_total"] == UInt64.max
      })
    #expect(
      fixture.logger.messages.filter { $0.message == "packet_bridge.metric_saturated" }.count
        == 1)
    await fixture.bridge.stop()
  }

  @Test("counters and maxima are monotonic within a run and reset for the next run")
  func runScopedMetricArithmetic() async throws {
    let fixture = BridgeFixture()
    let firstFlow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(
      packetFlow: firstFlow,
      configuration: fixture.configuration
    )
    await firstFlow.enqueue(
      PacketReadBatch(results: [
        .packet(TunnelPacket(payload: Data([0x45]), addressFamily: .ipv4))
      ]))
    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 1 })
    let firstSnapshot = await fixture.bridge.metrics()

    await firstFlow.enqueue(
      PacketReadBatch(results: [
        .packet(TunnelPacket(payload: Data([0x45, 1, 2]), addressFamily: .ipv4))
      ]))
    #expect(await eventually { fixture.socketIO.sentDatagrams.count == 2 })
    let secondSnapshot = await fixture.bridge.metrics()
    let firstCount = firstSnapshot.counters["packet_bridge_forward_packets_received_total"] ?? 0
    let secondCount = secondSnapshot.counters["packet_bridge_forward_packets_received_total"] ?? 0
    #expect(secondCount >= firstCount)
    #expect(secondSnapshot.gauges["packet_bridge_forward_datagram_max_bytes"] == 7)
    await fixture.bridge.stop()

    let secondFlow = FakePacketFlow(events: fixture.events)
    _ = try await fixture.bridge.start(
      packetFlow: secondFlow,
      configuration: fixture.configuration
    )
    let newRun = await fixture.bridge.metrics()
    #expect(newRun.counters["packet_bridge_start_total"] == 1)
    #expect(newRun.counters["packet_bridge_forward_packets_received_total"] == 0)
    #expect(newRun.counters["packet_bridge_forward_datagrams_sent_total"] == 0)
    #expect(newRun.gauges["packet_bridge_forward_datagram_max_bytes"] == 0)
    await fixture.bridge.stop()
  }

  @Test("metric schema has the exact names and units")
  func exactMetricSchemaUnits() {
    let counters: [String: PacketBridgeMetricUnit] = [
      "packet_bridge_forward_packets_received_total": .packets,
      "packet_bridge_forward_payload_bytes_received_total": .bytes,
      "packet_bridge_forward_datagrams_sent_total": .datagrams,
      "packet_bridge_forward_datagram_bytes_sent_total": .bytes,
      "packet_bridge_reverse_datagrams_received_total": .datagrams,
      "packet_bridge_reverse_datagram_bytes_received_total": .bytes,
      "packet_bridge_reverse_packets_written_total": .packets,
      "packet_bridge_reverse_payload_bytes_written_total": .bytes,
      "packet_bridge_reverse_batches_written_total": .batches,
      "packet_bridge_forward_budget_count_yield_total": .events,
      "packet_bridge_forward_budget_time_yield_total": .events,
      "packet_bridge_reverse_budget_count_yield_total": .events,
      "packet_bridge_reverse_budget_time_yield_total": .events,
      "packet_bridge_forward_drop_malformed_total": .packets,
      "packet_bridge_reverse_drop_malformed_total": .datagrams,
      "packet_bridge_forward_drop_would_block_total": .packets,
      "packet_bridge_reverse_drain_would_block_total": .events,
      "packet_bridge_forward_drop_no_buffer_total": .packets,
      "packet_bridge_reverse_receive_no_buffer_total": .events,
      "packet_bridge_fatal_message_too_large_total": .events,
      "packet_bridge_fatal_peer_eof_total": .events,
      "packet_bridge_fatal_socket_error_total": .events,
      "packet_bridge_fatal_packet_flow_error_total": .events,
      "packet_bridge_reverse_drop_write_rejected_packets_total": .packets,
      "packet_bridge_cleanup_close_error_total": .events,
      "packet_bridge_cancellation_total": .events,
      "packet_bridge_startup_failure_total": .runs,
      "packet_bridge_terminal_failure_total": .runs,
      "packet_bridge_start_total": .runs,
      "packet_bridge_stop_total": .runs,
    ]
    let gauges: [String: PacketBridgeMetricUnit] = [
      "packet_bridge_forward_datagram_max_bytes": .bytes,
      "packet_bridge_reverse_datagram_max_bytes": .bytes,
      "packet_bridge_socket_a_send_buffer_requested_bytes": .bytes,
      "packet_bridge_socket_a_send_buffer_effective_bytes": .bytes,
      "packet_bridge_socket_a_receive_buffer_requested_bytes": .bytes,
      "packet_bridge_socket_a_receive_buffer_effective_bytes": .bytes,
      "packet_bridge_socket_b_send_buffer_requested_bytes": .bytes,
      "packet_bridge_socket_b_send_buffer_effective_bytes": .bytes,
      "packet_bridge_socket_b_receive_buffer_requested_bytes": .bytes,
      "packet_bridge_socket_b_receive_buffer_effective_bytes": .bytes,
      "packet_bridge_configured_mtu_bytes": .bytes,
      "packet_bridge_configured_max_datagram_bytes": .bytes,
    ]

    #expect(PacketBridgeMetricSchema.counters == counters)
    #expect(PacketBridgeMetricSchema.gauges == gauges)
    #expect(PacketBridgeMetricSchema.version == 1)
  }

  @Test("all bridge logs expose only public privacy-safe fields")
  func privacySafeLogs() async throws {
    let fixture = BridgeFixture()
    fixture.socketIO.enqueueSends([.error(EIO)])
    let flow = FakePacketFlow(events: fixture.events)
    let handle = try await fixture.bridge.start(
      packetFlow: flow,
      configuration: fixture.configuration
    )
    await flow.enqueue(
      PacketReadBatch(results: [
        .packet(TunnelPacket(payload: Data([0x45, 0xde, 0xad]), addressFamily: .ipv4))
      ]))
    _ = try? await handle.waitForTermination()

    let forbiddenKeyFragments = [
      "payload", "packet_bytes", "address", "hostname", "destination", "port", "credential",
      "descriptor", "raw_configuration", "file_descriptor", "fd",
    ]
    for message in fixture.logger.messages {
      for (name, field) in message.fields {
        #expect(forbiddenKeyFragments.allSatisfy { !name.contains($0) })
        if case .sensitive = field.privacy {
          Issue.record("bridge log field \(name) was marked sensitive instead of being omitted")
        }
        #expect(!field.value.contains("dead"))
      }
    }
  }
}

final class ManualTunnelClock: TunnelClock, @unchecked Sendable {
  private let lock = NSLock()
  private var instant = ContinuousClock().now
  private var sleeps = 0

  var sleepCallCount: Int { lock.withLock { sleeps } }

  func now() -> ContinuousClock.Instant {
    lock.withLock { instant }
  }

  func sleep(for duration: Duration) async throws {
    lock.withLock { sleeps += 1 }
    try Task<Never, Never>.checkCancellation()
    advance(by: duration)
  }

  func advance(by duration: Duration) {
    lock.withLock { instant = instant.advanced(by: duration) }
  }
}
