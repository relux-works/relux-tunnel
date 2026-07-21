import Foundation
import Synchronization
import Testing

@testable import ReluxTunnelCore

@Suite("Privacy-safe runtime diagnostics")
struct RuntimeDiagnosticsTests {
  @Test("schema v1 contains exactly the reviewed aggregate names")
  func goldenSchema() {
    let localCounters = [
      "coordinator_transition_connected_degraded_total",
      "coordinator_transition_connected_full_total",
      "coordinator_transition_connecting_total",
      "coordinator_transition_disconnected_total",
      "coordinator_transition_disconnecting_total",
      "coordinator_transition_failed_total",
      "coordinator_transition_reasserting_total",
      "coordinator_transition_unknown_total",
      "diagnostics_ingestion_drop_total",
      "diagnostics_rejected_metric_update_total",
      "provider_cleanup_deadline_exceeded_total",
      "dns_drop_queue_full_total",
      "dns_result_malformed_total",
      "dns_result_name_error_total",
      "dns_result_no_data_total",
      "dns_result_other_failure_total",
      "dns_result_refused_total",
      "dns_result_server_failure_total",
      "dns_result_success_total",
      "dns_result_timeout_total",
      "hev_main_failure_total",
      "hev_main_return_total",
      "hev_start_total",
      "hev_startup_failure_total",
      "hev_stop_request_total",
      "memory_sample_total",
      "tcp_bytes_received_total",
      "tcp_bytes_sent_total",
      "tcp_drop_admission_limit_total",
      "tcp_drop_queued_byte_limit_total",
      "tcp_flows_closed_total",
      "tcp_flows_opened_total",
    ]
    let packetCounters = [
      "packet_bridge_cancellation_total",
      "packet_bridge_cleanup_close_error_total",
      "packet_bridge_fatal_message_too_large_total",
      "packet_bridge_fatal_packet_flow_error_total",
      "packet_bridge_fatal_peer_eof_total",
      "packet_bridge_fatal_socket_error_total",
      "packet_bridge_forward_budget_count_yield_total",
      "packet_bridge_forward_budget_time_yield_total",
      "packet_bridge_forward_datagram_bytes_sent_total",
      "packet_bridge_forward_datagrams_sent_total",
      "packet_bridge_forward_drop_malformed_total",
      "packet_bridge_forward_drop_no_buffer_total",
      "packet_bridge_forward_drop_would_block_total",
      "packet_bridge_forward_packets_received_total",
      "packet_bridge_forward_payload_bytes_received_total",
      "packet_bridge_reverse_batches_written_total",
      "packet_bridge_reverse_budget_count_yield_total",
      "packet_bridge_reverse_budget_time_yield_total",
      "packet_bridge_reverse_datagram_bytes_received_total",
      "packet_bridge_reverse_datagrams_received_total",
      "packet_bridge_reverse_drain_would_block_total",
      "packet_bridge_reverse_drop_malformed_total",
      "packet_bridge_reverse_drop_write_rejected_packets_total",
      "packet_bridge_reverse_packets_written_total",
      "packet_bridge_reverse_payload_bytes_written_total",
      "packet_bridge_reverse_receive_no_buffer_total",
      "packet_bridge_start_total",
      "packet_bridge_startup_failure_total",
      "packet_bridge_stop_total",
      "packet_bridge_terminal_failure_total",
    ]
    let sshCounters = [
      "ssh_authentication_attempts_total",
      "ssh_authentication_rejected_total",
      "ssh_authentication_succeeded_total",
      "ssh_channel_open_failed_total",
      "ssh_channels_cancelled_total",
      "ssh_channels_closed_gracefully_total",
      "ssh_channels_reset_total",
      "ssh_client_byte_rekeys_total",
      "ssh_client_time_rekeys_total",
      "ssh_connect_attempts_total",
      "ssh_connect_failed_total",
      "ssh_connect_succeeded_total",
      "ssh_direct_channels_opened_total",
      "ssh_exec_channels_opened_total",
      "ssh_explicit_rekeys_total",
      "ssh_host_algorithm_rejected_total",
      "ssh_host_changed_rejected_total",
      "ssh_host_first_use_accepted_total",
      "ssh_host_match_accepted_total",
      "ssh_host_unknown_rejected_total",
      "ssh_keepalives_acknowledged_total",
      "ssh_keepalives_sent_total",
      "ssh_keepalives_timed_out_total",
      "ssh_operations_cancelled_total",
      "ssh_operations_timed_out_total",
      "ssh_payload_bytes_received_total",
      "ssh_payload_bytes_sent_total",
      "ssh_protected_bytes_received_total",
      "ssh_protected_bytes_sent_total",
      "ssh_rekeys_failed_total",
      "ssh_rekeys_succeeded_total",
      "ssh_server_rekeys_total",
      "ssh_window_adjustment_bytes_total",
      "ssh_window_adjustments_total",
      "ssh_write_backpressure_waits_total",
    ]
    let tcpCounters =
      RuntimeTCPAdapterCounter.allCases.map(\.rawValue)
      + [
        "tcp_pressure_reject_flow_capacity_total",
        "tcp_pressure_reject_handshake_capacity_total",
        "tcp_pressure_reject_identifier_capacity_total",
        "tcp_pressure_reject_opening_capacity_total",
        "tcp_pressure_reject_queued_byte_capacity_total",
        "tcp_pressure_reject_session_unavailable_total",
      ]
      + TCPFlowTerminalReason.allCases.map { "tcp_terminal_\($0.rawValue)_total" }
    let localGauges = [
      "component_coordinator_health_code",
      "component_dns_health_code",
      "component_hev_health_code",
      "component_packet_bridge_health_code",
      "component_route_health_code",
      "component_ssh_health_code",
      "component_tcp_health_code",
      "coordinator_transition_connected_degraded_uptime_milliseconds",
      "coordinator_transition_connected_full_uptime_milliseconds",
      "coordinator_transition_connecting_uptime_milliseconds",
      "coordinator_transition_disconnected_uptime_milliseconds",
      "coordinator_transition_disconnecting_uptime_milliseconds",
      "coordinator_transition_failed_uptime_milliseconds",
      "coordinator_transition_reasserting_uptime_milliseconds",
      "coordinator_transition_unknown_uptime_milliseconds",
      "hev_configured_maximum_session_count",
      "hev_configured_mtu_bytes",
      "hev_configured_task_stack_size_bytes",
      "hev_configured_tcp_buffer_size_bytes",
      "hev_configured_udp_copy_buffer_count",
      "hev_received_bytes",
      "hev_received_packets",
      "hev_transmitted_bytes",
      "hev_transmitted_packets",
      "memory_available_bytes",
      "memory_available_min_bytes",
      "memory_physical_footprint_bytes",
      "memory_physical_footprint_peak_bytes",
      "provider_stop_reason_code",
      "route_installed",
      "route_mode_compatible",
      "route_mode_unknown",
      "tcp_active_flows",
      "tcp_peak_flows",
    ]
    let packetGauges = [
      "packet_bridge_configured_max_datagram_bytes",
      "packet_bridge_configured_mtu_bytes",
      "packet_bridge_forward_datagram_max_bytes",
      "packet_bridge_reverse_datagram_max_bytes",
      "packet_bridge_socket_a_receive_buffer_effective_bytes",
      "packet_bridge_socket_a_receive_buffer_requested_bytes",
      "packet_bridge_socket_a_send_buffer_effective_bytes",
      "packet_bridge_socket_a_send_buffer_requested_bytes",
      "packet_bridge_socket_b_receive_buffer_effective_bytes",
      "packet_bridge_socket_b_receive_buffer_requested_bytes",
      "packet_bridge_socket_b_send_buffer_effective_bytes",
      "packet_bridge_socket_b_send_buffer_requested_bytes",
    ]
    let sshGauges = [
      "ssh_active_key_exchange",
      "ssh_buffered_read_bytes",
      "ssh_consecutive_keepalive_misses",
      "ssh_last_keepalive_rtt_nanoseconds",
      "ssh_open_direct_channels",
      "ssh_open_exec_channels",
      "ssh_pending_channel_opens",
      "ssh_pending_reads",
      "ssh_pending_writes",
      "ssh_queued_write_bytes",
      "ssh_remaining_receive_window_bytes",
    ]
    let tcpGauges = RuntimeTCPAdapterGauge.allCases.map(\.rawValue)

    #expect(RuntimeDiagnosticsSchema.version == 1)
    #expect(
      RuntimeDiagnosticsSchema.counterNames
        == (localCounters + packetCounters + sshCounters + tcpCounters).sorted()
    )
    #expect(
      RuntimeDiagnosticsSchema.gaugeNames
        == (localGauges + packetGauges + sshGauges + tcpGauges).sorted()
    )
    #expect(
      RuntimeDiagnosticsSchema.histogramNames == [
        "dns_latency_milliseconds", "tcp_channel_open_latency_milliseconds",
      ]
    )
    #expect(
      RuntimeDiagnosticsSchema.dnsLatencyBucketUpperBoundsMilliseconds
        == [1, 5, 10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000, UInt64.max]
    )
    #expect(RuntimeDiagnosticsSchema.maximumErrors == 10)
    #expect(RuntimeDiagnosticsSchema.maximumPendingUpdates == 256)
    #expect(RuntimeDiagnosticsSchema.counterNames.count == 139)
    #expect(RuntimeDiagnosticsSchema.gaugeNames.count == 75)
    #expect(
      RuntimeDiagnosticsSchema.errorCodes.map { "\($0.domain.rawValue):\($0.rawValue)" } == [
        "configuration:configuration_invalid",
        "sshTrust:ssh_trust_rejected",
        "sshCredential:ssh_credential_rejected",
        "sshTransport:ssh_session_lost",
        "tcp:tcp_flow_failed",
        "dns:dns_upstream_timeout",
        "packetPlane:packet_plane_failed",
        "networkSettings:network_settings_apply_failed",
        "runtimeInvariant:runtime_invariant_violated",
        "runtimeInvariant:cleanup_deadline_exceeded",
        "protocol:protocol_unsupported",
      ]
    )
    print("RUNTIME_DIAGNOSTICS_SCHEMA counters=139 gauges=75 histograms=2 errors=11")
    #expect(
      (RuntimeDiagnosticsSchema.counterNames + RuntimeDiagnosticsSchema.gaugeNames
        + RuntimeDiagnosticsSchema.histogramNames).allSatisfy {
          !$0.isEmpty && $0.utf8.count <= RuntimeDiagnosticsSnapshot.maximumMetricNameUTF8Bytes
            && $0.utf8.allSatisfy {
              (UInt8(ascii: "a")...UInt8(ascii: "z")).contains($0)
                || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0)
                || $0 == UInt8(ascii: "_")
            }
        }
    )
  }

  @Test("populated snapshot recursively contains only approved stable fields")
  func snapshotFieldAllowlist() throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: 1)
    let recorder = store.recorder()
    recorder.recordDNSResult(.timeout, latencyMilliseconds: 25)
    recorder.recordError(.dnsUpstreamTimeout)
    let snapshot = try store.snapshot()
    let data = try RuntimeMessageCodec.encode(snapshot)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let approvedFields: Set<String> = [
      "protocolVersion", "kind", "schemaVersion", "runtimeGeneration", "snapshotSequence",
      "counters", "gauges", "histograms", "errors",
    ]
    let approvedStoredProperties = approvedFields.union(["requestID"])

    #expect(Set(object.keys) == approvedFields)
    #expect(
      Set(Mirror(reflecting: snapshot).children.compactMap(\.label)) == approvedStoredProperties
    )
    #expect(object["kind"] as? String == "diagnosticsSnapshot")
    #expect(object["schemaVersion"] as? Int == 1)

    let histograms = try #require(object["histograms"] as? [String: Any])
    #expect(
      Set(histograms.keys) == [
        "dns_latency_milliseconds", "tcp_channel_open_latency_milliseconds",
      ]
    )
    let histogram = try #require(
      histograms["dns_latency_milliseconds"] as? [String: Any]
    )
    #expect(Set(histogram.keys) == ["unit", "buckets"])
    let buckets = try #require(histogram["buckets"] as? [[String: Any]])
    #expect(!buckets.isEmpty)
    #expect(buckets.allSatisfy { Set($0.keys) == ["upperBound", "count"] })

    let errors = try #require(object["errors"] as? [[String: Any]])
    #expect(errors.count == 1)
    #expect(errors.allSatisfy { Set($0.keys) == ["domain", "code"] })
    #expect(errors.first?["domain"] as? String == "dns")
    #expect(errors.first?["code"] as? String == "dns_upstream_timeout")

    let typedHistogram = try #require(snapshot.histograms["dns_latency_milliseconds"])
    let typedBucket = try #require(typedHistogram.buckets.first)
    let typedError = try #require(snapshot.errors.first)
    #expect(
      Set(Mirror(reflecting: typedHistogram).children.compactMap(\.label)) == ["unit", "buckets"])
    #expect(
      Set(Mirror(reflecting: typedBucket).children.compactMap(\.label)) == ["upperBound", "count"])
    #expect(Set(Mirror(reflecting: typedError).children.compactMap(\.label)) == ["domain", "code"])
  }

  @Test("generation reset rejects stale handles and preserves monotonic counters")
  func generationsAndMonotonicity() async throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: 7)
    let oldRecorder = store.recorder()
    await oldRecorder.incrementCounter(named: "packet_bridge_start_total", by: 3)
    await oldRecorder.incrementCounter(named: "packet_bridge_start_total", by: UInt64.max)
    let oldSnapshot = try store.snapshot()
    #expect(oldSnapshot.runtimeGeneration == 7)
    #expect(oldSnapshot.snapshotSequence == 0)
    #expect(oldSnapshot.counters["packet_bridge_start_total"] == UInt64.max)

    let newRecorder = try store.beginGeneration(8)
    await oldRecorder.incrementCounter(named: "packet_bridge_start_total", by: 100)
    await newRecorder.incrementCounter(named: "packet_bridge_start_total", by: 2)
    let first = try store.snapshot()
    let second = try store.snapshot()
    #expect(first.runtimeGeneration == 8)
    #expect(first.snapshotSequence == 0)
    #expect(second.snapshotSequence == 1)
    #expect(first.counters["packet_bridge_start_total"] == 2)
    #expect(second.counters["packet_bridge_start_total"] == 2)
    #expect(throws: RuntimeDiagnosticsStoreError.generationMustIncrease(current: 8, proposed: 8)) {
      try store.beginGeneration(8)
    }
    #expect(throws: RuntimeDiagnosticsStoreError.generationMustIncrease(current: 8, proposed: 7)) {
      try store.beginGeneration(7)
    }

    let exhausted = RuntimeDiagnosticsStore(
      runtimeGeneration: 9,
      initialSnapshotSequenceForTesting: UInt64.max,
      snapshotConstructionHook: nil
    )
    #expect(try exhausted.snapshot().snapshotSequence == UInt64.max)
    #expect(throws: RuntimeDiagnosticsStoreError.snapshotSequenceExhausted(runtimeGeneration: 9)) {
      try exhausted.snapshot()
    }
  }

  @Test("concurrent updates and requests return consistent bounded snapshots")
  func concurrentUpdatesAndSnapshots() async throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: 21)
    let recorder = store.recorder()
    let workerCount = 8
    let updatesPerWorker = 2_000
    var observed: [RuntimeDiagnosticsSnapshot] = []

    await withTaskGroup(of: [RuntimeDiagnosticsSnapshot].self) { group in
      for _ in 0..<workerCount {
        group.addTask {
          for _ in 0..<updatesPerWorker {
            recorder.recordQueueDrop(.tcpAdmissionLimit)
            recorder.recordDNSResult(.success, latencyMilliseconds: 25)
            recorder.recordTCPFlowOpened()
            recorder.recordTCPFlowClosed()
          }
          return []
        }
      }
      group.addTask {
        var snapshots: [RuntimeDiagnosticsSnapshot] = []
        for _ in 0..<200 {
          if let snapshot = try? store.snapshot() {
            snapshots.append(snapshot)
          }
          await Task.yield()
        }
        return snapshots
      }
      for await snapshots in group {
        observed.append(contentsOf: snapshots)
      }
    }

    let snapshot = try store.snapshot()
    let expectedMaximum = UInt64(workerCount * updatesPerWorker)
    let admittedDrops = try #require(snapshot.counters["tcp_drop_admission_limit_total"])
    let dnsResults = try #require(snapshot.counters["dns_result_success_total"])
    let opened = try #require(snapshot.counters["tcp_flows_opened_total"])
    let closed = try #require(snapshot.counters["tcp_flows_closed_total"])
    let active = try #require(snapshot.gauges["tcp_active_flows"])
    let peak = try #require(snapshot.gauges["tcp_peak_flows"])
    #expect(admittedDrops > 0 && admittedDrops <= expectedMaximum)
    #expect(dnsResults > 0 && dnsResults <= expectedMaximum)
    #expect(opened > 0 && opened <= expectedMaximum)
    #expect(closed <= opened)
    #expect(active == Int64(opened - closed))
    #expect(peak >= active && peak <= Int64(opened))
    #expect(Set(snapshot.counters.keys) == Set(RuntimeDiagnosticsSchema.counterNames))
    #expect(Set(snapshot.gauges.keys) == Set(RuntimeDiagnosticsSchema.gaugeNames))

    let ordered = observed.sorted { $0.snapshotSequence < $1.snapshotSequence }
    for pair in zip(ordered, ordered.dropFirst()) {
      #expect(pair.1.snapshotSequence > pair.0.snapshotSequence)
      #expect(
        pair.1.counters["tcp_drop_admission_limit_total"]
          ?? 0 >= pair.0.counters["tcp_drop_admission_limit_total"] ?? 0
      )
      #expect(
        pair.1.counters["diagnostics_ingestion_drop_total"]
          ?? 0 >= pair.0.counters["diagnostics_ingestion_drop_total"] ?? 0
      )
      #expect(pair.1.runtimeGeneration == 21)
    }
    #expect(
      try RuntimeMessageCodec.encode(snapshot).count < RuntimeMessageSizeLimit.diagnosticsSnapshot)
  }

  @Test("unknown high-cardinality labels are discarded without retention")
  func highCardinalityUpdatesAreDiscarded() async throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: 1)
    let recorder = store.recorder()
    for index in 0..<10_000 {
      await recorder.incrementCounter(named: "destination_\(index)", by: 1)
      await recorder.setGauge(named: "flow_\(index)", to: 1)
      recorder.recordError(
        RedactedRuntimeError(
          domain: .tcp,
          code: try RedactedRuntimeErrorCode("error_\(index)")
        )
      )
    }
    await recorder.setGauge(named: "ssh_pending_reads", to: -1)

    let snapshot = try store.snapshot()
    #expect(snapshot.counters.count == 139)
    #expect(snapshot.gauges.count == 75)
    let rejected = try #require(
      snapshot.counters["diagnostics_rejected_metric_update_total"]
    )
    let ingestionDrops = try #require(snapshot.counters["diagnostics_ingestion_drop_total"])
    #expect(rejected + ingestionDrops == 30_001)
    #expect(snapshot.errors.isEmpty)
    #expect(!snapshot.counters.keys.contains { $0.hasPrefix("destination_") })
    #expect(!snapshot.gauges.keys.contains { $0.hasPrefix("flow_") })
  }

  @Test(
    "bounded sink enqueue never stalls packet or SSH progress behind a snapshot",
    .timeLimit(.minutes(1))
  )
  func nonBlockingBoundedIngestion() async throws {
    let (snapshotEntered, snapshotEnteredContinuation) = AsyncStream<Void>.makeStream()
    let releaseSnapshot = DispatchSemaphore(value: 0)
    let shouldBlockSnapshot = Atomic<Bool>(true)
    let store = RuntimeDiagnosticsStore(
      runtimeGeneration: 3,
      initialSnapshotSequenceForTesting: 0,
      snapshotConstructionHook: {
        guard shouldBlockSnapshot.exchange(false, ordering: .relaxed) else { return }
        snapshotEnteredContinuation.yield()
        releaseSnapshot.wait()
      }
    )
    let recorder = store.recorder()
    let snapshotTask = Task.detached { try store.snapshot() }
    defer { releaseSnapshot.signal() }

    var snapshotEnteredIterator = snapshotEntered.makeAsyncIterator()
    _ = await snapshotEnteredIterator.next()

    let packetProgress = Task.detached {
      recorder.recordQueueDrop(.tcpAdmissionLimit)
    }
    let sshProgress = Task.detached {
      await recorder.record(.increment(.connectAttempts, by: 1))
    }
    await packetProgress.value
    await sshProgress.value

    for _ in 0..<RuntimeDiagnosticsSchema.maximumPendingUpdates {
      recorder.recordQueueDrop(.tcpAdmissionLimit)
    }
    recorder.recordQueueDrop(.tcpAdmissionLimit)

    releaseSnapshot.signal()
    let blockedSnapshot = try await snapshotTask.value
    let drainedSnapshot = try store.snapshot()
    #expect(blockedSnapshot.snapshotSequence == 0)
    #expect(blockedSnapshot.counters["tcp_drop_admission_limit_total"] == 0)
    #expect(drainedSnapshot.snapshotSequence == 1)
    #expect(drainedSnapshot.counters["tcp_drop_admission_limit_total"] == 255)
    #expect(drainedSnapshot.counters["ssh_connect_attempts_total"] == 1)
    #expect(drainedSnapshot.counters["diagnostics_ingestion_drop_total"] == 3)
  }

  @Test("typed sources project aggregate health flow DNS route memory SSH and errors")
  func typedSourceProjection() async throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: 4)
    let recorder = store.recorder()
    recorder.recordStateTransition(to: .connecting, atUptimeMilliseconds: 120)
    recorder.recordStateTransition(to: .connectedDegraded, atUptimeMilliseconds: 480)
    recorder.recordHealth(.healthy, for: .packetBridge)
    recorder.recordHealth(.unhealthy, for: .dns)
    recorder.recordRoute(mode: .compatible, installed: true)
    recorder.recordMemorySample(
      physicalFootprintBytes: 30_000_000,
      availableMemoryBytes: 80_000_000
    )
    recorder.recordMemorySample(
      physicalFootprintBytes: 28_000_000,
      availableMemoryBytes: 70_000_000
    )
    recorder.recordDNSResult(.nameError, latencyMilliseconds: 80)
    await recorder.record(.increment(.payloadBytesSent, by: 700))
    await recorder.record(.set(.openDirectChannels, to: 3))
    recorder.recordError(.dnsUpstreamTimeout)

    let snapshot = try store.snapshot()
    #expect(snapshot.counters["coordinator_transition_connecting_total"] == 1)
    #expect(snapshot.counters["coordinator_transition_connected_degraded_total"] == 1)
    #expect(snapshot.gauges["coordinator_transition_connecting_uptime_milliseconds"] == 120)
    #expect(snapshot.gauges["component_packet_bridge_health_code"] == 1)
    #expect(snapshot.gauges["component_dns_health_code"] == 2)
    #expect(snapshot.gauges["route_mode_compatible"] == 1)
    #expect(snapshot.gauges["route_installed"] == 1)
    #expect(snapshot.counters["memory_sample_total"] == 2)
    #expect(snapshot.gauges["memory_physical_footprint_bytes"] == 28_000_000)
    #expect(snapshot.gauges["memory_physical_footprint_peak_bytes"] == 30_000_000)
    #expect(snapshot.gauges["memory_available_min_bytes"] == 70_000_000)
    #expect(snapshot.counters["dns_result_name_error_total"] == 1)
    #expect(snapshot.counters["ssh_payload_bytes_sent_total"] == 700)
    #expect(snapshot.gauges["ssh_open_direct_channels"] == 3)
    #expect(snapshot.errors.count == 1)
    #expect(snapshot.errors.first?.domain == .dns)

    let histogram = try #require(snapshot.histograms["dns_latency_milliseconds"])
    #expect(histogram.unit == .milliseconds)
    #expect(histogram.buckets.first { $0.upperBound == 50 }?.count == 0)
    #expect(histogram.buckets.first { $0.upperBound == 100 }?.count == 1)
    #expect(histogram.buckets.last?.count == 1)
  }

  @Test("maximum aggregate state remains well below the wire bound")
  func maximumEncodedSize() async throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: UInt64.max)
    let recorder = store.recorder()
    for name in RuntimeDiagnosticsSchema.counterNames {
      await recorder.incrementCounter(named: name, by: UInt64.max)
    }
    for name in RuntimeDiagnosticsSchema.gaugeNames {
      await recorder.setGauge(named: name, to: Int64.max)
    }
    for code in RuntimeDiagnosticsSchema.errorCodes {
      recorder.recordError(code)
    }

    let snapshot = try store.snapshot()
    let encoded = try RuntimeMessageCodec.encode(snapshot)
    #expect(snapshot.errors.count == RuntimeDiagnosticsSchema.maximumErrors)
    #expect(encoded.count < 16 * 1_024)
    #expect(encoded.count < RuntimeDiagnosticsSnapshot.maximumEncodedSize)
    print("RUNTIME_DIAGNOSTICS_MAX_ENCODED_BYTES \(encoded.count)")
  }

  @Test("populated output rejects prohibited nested values and identifiers")
  func redactionBoundary() async throws {
    let store = RuntimeDiagnosticsStore(runtimeGeneration: 1)
    let recorder = store.recorder()
    await recorder.incrementCounter(named: "private_key", by: 1)
    await recorder.setGauge(named: "destination_ip", to: 1)
    recorder.recordError(
      RedactedRuntimeError(
        domain: .configuration,
        code: try RedactedRuntimeErrorCode("private_key")
      )
    )
    recorder.recordDNSResult(.timeout, latencyMilliseconds: 25)
    recorder.recordError(.dnsUpstreamTimeout)
    let snapshot = try store.snapshot()
    let encoded = String(decoding: try RuntimeMessageCodec.encode(snapshot), as: UTF8.self)
    let reflected = String(reflecting: snapshot)
    let prohibited = [
      "privateKey", "private_key", "passphrase", "password", "dnsName", "dns_name",
      "destinationHostname", "destination_hostname", "destinationIP", "destination_ip",
      "localAddress", "local_address", "shellStdin", "shell_stdin", "packetPayload",
      "packet_payload", "trafficSample", "traffic_sample", "laneID", "lane_id", "runID",
      "run_id", "BEGIN PRIVATE KEY", "secret.example", "203.0.113.19", "10.0.0.7",
    ]

    for value in prohibited {
      #expect(!encoded.localizedCaseInsensitiveContains(value))
      #expect(!reflected.localizedCaseInsensitiveContains(value))
    }
    #expect(snapshot.errors.count == 1)
    #expect(snapshot.errors.first?.code.rawValue == "dns_upstream_timeout")
    #expect(snapshot.counters["diagnostics_rejected_metric_update_total"] == 3)
    #expect(!encoded.contains("requestID"))
    #expect(!encoded.contains("-"))
  }
}
