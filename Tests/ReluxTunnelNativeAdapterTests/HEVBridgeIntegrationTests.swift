import CryptoKit
import Darwin
import Dispatch
import Foundation
import ReluxTunnelCore
import ReluxTunnelMacOSAdapter
import ReluxTunnelNativeAdapter
import Testing

extension HEVIntegrationTests {
  @Test("real HEV translates concurrent IPv4 and IPv6 TCP streams, half-close, and reset")
  func realHEVTCPMatrix() async throws {
    let harness = RealHEVBridgeHarness()
    let handle = try await harness.start()

    var ipv4 = TCPPeer.ipv4(
      source: [10, 42, 0, 2],
      destination: [198, 51, 100, 40],
      sourcePort: 40_001,
      destinationPort: 8_080,
      initialSequence: 1_000
    )
    var ipv6 = TCPPeer.ipv6(
      source: ipv6Address(lastWord: 2),
      destination: ipv6Address(lastWord: 0x80),
      sourcePort: 40_002,
      destinationPort: 8_443,
      initialSequence: 2_000
    )

    try harness.driver.deliver(ipv4.synPacket())
    try harness.driver.deliver(ipv6.synPacket())
    try await ipv4.acceptSYNACK(from: harness.driver)
    try await ipv6.acceptSYNACK(from: harness.driver)
    try harness.driver.deliver(ipv4.ackPacket())
    try harness.driver.deliver(ipv6.ackPacket())

    let first = try await harness.adapter.nextSession()
    let second = try await harness.adapter.nextSession()
    let sessions = Dictionary(
      uniqueKeysWithValues: [first, second].map {
        ($0.request.destinationPort, $0)
      })
    let ipv4Session = try #require(sessions[ipv4.destinationPort])
    let ipv6Session = try #require(sessions[ipv6.destinationPort])

    #expect(ipv4Session.request.command == .connect)
    #expect(ipv4Session.request.address == ipv4.destination)
    #expect(ipv6Session.request.command == .connect)
    #expect(ipv6Session.request.address == ipv6.destination)

    let ipv4Outbound = Data("small-ipv4".utf8)
    let ipv6Outbound = Data(repeating: 0x6a, count: 1_024)
    try harness.driver.deliver(ipv4.dataPacket(ipv4Outbound))
    try harness.driver.deliver(ipv6.dataPacket(ipv6Outbound))
    #expect(try await ipv4Session.readExactly(ipv4Outbound.count) == ipv4Outbound)
    #expect(try await ipv6Session.readExactly(ipv6Outbound.count) == ipv6Outbound)

    let ipv4Inbound = Data(repeating: 0x4b, count: 257)
    let ipv6Inbound = Data("reply-ipv6".utf8)
    try await ipv4Session.write(ipv4Inbound)
    try await ipv6Session.write(ipv6Inbound)
    try await ipv4.acceptPayload(ipv4Inbound, from: harness.driver)
    try await ipv6.acceptPayload(ipv6Inbound, from: harness.driver)
    try harness.driver.deliver(ipv4.ackPacket())
    try harness.driver.deliver(ipv6.ackPacket())

    try harness.driver.deliver(ipv4.finPacket())
    #expect(try await ipv4Session.readEOF())
    try await ipv4Session.shutdownWrite()
    try await ipv4.acceptFIN(from: harness.driver)
    try harness.driver.deliver(ipv4.ackPacket())

    try harness.driver.deliver(ipv6.resetPacket())
    #expect(try await ipv6Session.readEOF())

    ipv4Session.close()
    ipv6Session.close()
    await harness.stop(handle)
    let bridgeMetrics = await harness.bridge.metrics()
    #expect(bridgeMetrics.counters["packet_bridge_terminal_failure_total"] == 0)
    #expect(bridgeMetrics.counters["packet_bridge_forward_datagrams_sent_total", default: 0] >= 10)
    #expect(bridgeMetrics.counters["packet_bridge_reverse_packets_written_total", default: 0] >= 6)
    let nativeMetrics = await harness.metrics.snapshot()
    #expect(nativeMetrics.gauges["hev_transmitted_packets", default: 0] > 0)
    #expect(nativeMetrics.gauges["hev_received_packets", default: 0] > 0)
    harness.adapter.closeAll()
    harness.driver.releaseLateRead()
  }

  @Test("real HEV exposes UDP-in-TCP framing and rejects an unowned SOCKS client")
  func realHEVUDPInTCPAndInternalIngress() async throws {
    let harness = RealHEVBridgeHarness()
    let handle = try await harness.start()
    let access = try await harness.accessRecorder.nextAccess()

    let external = try connectToLoopback(port: access.port)
    defer { Darwin.close(external) }
    try sendAll(Data([5, 1, 0]), descriptor: external)
    #expect(try receiveExactly(2, descriptor: external) == Data([5, 0xff]))
    #expect(harness.adapter.acceptedCount == 0)

    let source = Data([10, 42, 0, 3])
    let destination = Data([203, 0, 113, 53])
    let payload = Data("udp-over-tcp".utf8)
    let packet = makeUDPPacket(
      family: .ipv4,
      source: source,
      destination: destination,
      sourcePort: 53_000,
      destinationPort: 53,
      payload: payload
    )
    try harness.driver.deliver(packet)

    let session = try await harness.adapter.nextSession()
    #expect(session.request.command == .forwardUDP)
    let frame = try await session.readUDPFrame()
    #expect(frame.address == destination)
    #expect(frame.port == 53)
    #expect(frame.payload == payload)

    session.close()
    await harness.stop(handle)
    let metrics = await harness.metrics.snapshot()
    #expect(metrics.gauges["hev_configured_mtu_bytes"] == 1_500)
    #expect(metrics.gauges["hev_configured_task_stack_size_bytes"] == 24_576)
    #expect(metrics.gauges["hev_configured_tcp_buffer_size_bytes"] == 4_096)
    #expect(metrics.gauges["hev_configured_udp_copy_buffer_count"] == 2)
    #expect(metrics.gauges["hev_configured_maximum_session_count"] == 1_200)
    harness.adapter.closeAll()
    harness.driver.releaseLateRead()
  }

  @Test("a stalled real HEV path accounts every bridge send or bounded drop")
  func realHEVStallIsBounded() async throws {
    let harness = RealHEVBridgeHarness(
      adapterMode: .stallAfterAuthentication,
      socketBufferBytes: 4_096
    )
    let handle = try await harness.start()
    let packetCount = 20_000
    let packet = makeUDPPacket(
      family: .ipv4,
      source: Data([10, 42, 0, 4]),
      destination: Data([192, 0, 2, 99]),
      sourcePort: 54_000,
      destinationPort: 9_999,
      payload: Data(repeating: 0x5c, count: 256)
    )
    try harness.driver.deliver(repeating: packet, count: packetCount)

    #expect(
      await eventually(timeout: .seconds(10)) {
        let snapshot = await harness.bridge.metrics()
        return snapshot.counters["packet_bridge_forward_packets_received_total"]
          == UInt64(packetCount)
      }
    )
    #expect(
      await eventually(timeout: .seconds(1)) {
        let snapshot = await harness.bridge.metrics()
        return snapshot.counters["packet_bridge_forward_datagrams_sent_total", default: 0]
          + snapshot.counters["packet_bridge_forward_drop_would_block_total", default: 0]
          + snapshot.counters["packet_bridge_forward_drop_no_buffer_total", default: 0]
          == UInt64(packetCount)
      }
    )
    let accountedSnapshot = await harness.bridge.metrics()
    let sent = accountedSnapshot.counters[
      "packet_bridge_forward_datagrams_sent_total", default: 0]
    let wouldBlock = accountedSnapshot.counters[
      "packet_bridge_forward_drop_would_block_total", default: 0]
    let noBuffer = accountedSnapshot.counters[
      "packet_bridge_forward_drop_no_buffer_total", default: 0]
    #expect(sent + wouldBlock + noBuffer == UInt64(packetCount))
    #expect(harness.driver.snapshot().queuedBatchCount == 0)
    #expect(harness.driver.snapshot().maximumOutstandingReadCount == 1)

    harness.adapter.closeAll()
    await harness.stop(handle)
    harness.driver.releaseLateRead()
  }

  @Test("bridge write failure while real HEV is active tears every boundary down")
  func realHEVBridgeFaultTeardown() async throws {
    let baseline = openDescriptorCount()
    let harness = RealHEVBridgeHarness(rejectPacketWrites: true)
    let handle = try await harness.start()
    let source = Data([10, 42, 0, 5])
    let destination = Data([198, 51, 100, 50])
    let sourcePort: UInt16 = 40_050
    let destinationPort: UInt16 = 4_432
    try harness.driver.deliver(
      makeUDPPacket(
        family: .ipv4,
        source: source,
        destination: destination,
        sourcePort: sourcePort,
        destinationPort: destinationPort,
        payload: Data("fault-request".utf8)
      )
    )
    let session = try await harness.adapter.nextSession()
    _ = try await session.readUDPFrame()
    try await session.writeUDPFrame(
      address: destination,
      port: destinationPort,
      payload: Data("fault-response".utf8)
    )
    session.close()

    await #expect(
      throws: PacketFlowBridgeError.packetFlowFailure(operation: .packetFlowWrite)
    ) {
      try await handle.waitForTermination()
    }
    #expect(
      await harness.bridge.lifecycleState()
        == .failed(
          runID: "integration-run-1",
          error: .packetFlowFailure(operation: .packetFlowWrite)
        )
    )
    let metrics = await harness.metrics.snapshot()
    #expect(metrics.counters["packet_bridge_terminal_failure_total"] == 1)
    #expect(metrics.counters["hev_main_return_total"] == 1)
    #expect(harness.accessRecorder.snapshot().starts == harness.accessRecorder.snapshot().stops)
    harness.adapter.closeAll()
    harness.driver.releaseLateRead()
    await expectHarnessOwnedResourcesReleased(
      harness,
      descriptorBaseline: baseline
    )
  }

  @Test("one hundred real HEV bridge traffic cycles restore descriptors, sessions, and reads")
  func realHEVHundredLifecycleCycles() async throws {
    _ = try await measureRealHEVLifecycle(cycles: 100)
  }

  @Test(
    "extended physical Mac lifecycle investigation emits bounded raw evidence",
    .enabled(
      if: ProcessInfo.processInfo.environment["RELUX_RUN_EXTENDED_HEV_LIFECYCLE"] == "1",
      "Runs only for explicitly authorized bounded 100/500/1000-cycle diagnostics."
    )
  )
  func extendedPhysicalMacLifecycleInvestigation() async throws {
    let provenance = try physicalMatrixProvenance(
      environment: ProcessInfo.processInfo.environment,
      manifestData: try Data(
        contentsOf: URL(fileURLWithPath: "NativeDependencies/manifest.json")
      )
    )
    let cycles = try requestedLifecycleProbeCycles(
      environment: ProcessInfo.processInfo.environment
    )
    let lifecycle = try await measureRealHEVLifecycle(cycles: cycles)
    let report = ExtendedLifecycleInvestigationReport(
      schemaVersion: 2,
      taskID: "TASK-260715-135rr8",
      generatedAtUTC: ISO8601DateFormatter().string(from: Date()),
      sourceRevision: provenance.candidateTreeOID,
      hevRevision: provenance.hevRevision,
      hevMacOSArtifactSHA256: provenance.hevMacOSArtifactSHA256,
      segmentSampleCount: 100,
      increaseCycles: lifecycle.samples.enumerated().dropFirst().compactMap { index, sample in
        sample.physicalFootprintBytes > lifecycle.samples[index - 1].physicalFootprintBytes
          ? sample.cycle : nil
      },
      segments: lifecycleSegments(samples: lifecycle.samples, segmentSampleCount: 100),
      lifecycle: lifecycle
    )
    let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(
        ".temp/TASK-260715-135rr8/TASK-260715-135rr8_lifecycle-\(cycles)-\(provenance.runID).json"
      )
    try FileManager.default.createDirectory(
      at: output.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(report).write(to: output, options: .atomic)
  }

  @Test(
    "physical Mac HEV memory and concurrency matrix emits bounded raw evidence",
    .enabled(
      if: ProcessInfo.processInfo.environment["RELUX_RUN_PHYSICAL_MEMORY_MATRIX"] == "1",
      "Runs only for the explicitly authorized physical-Mac evidence pass."
    )
  )
  func physicalMemoryAndConcurrencyMatrix() async throws {
    let provenance = try physicalMatrixProvenance(
      environment: ProcessInfo.processInfo.environment,
      manifestData: try Data(
        contentsOf: URL(fileURLWithPath: "NativeDependencies/manifest.json")
      )
    )
    let lifecycle = try await measureRealHEVLifecycle(cycles: 500)
    let initial = try physicalProcessSnapshot()
    let harness = RealHEVBridgeHarness(
      adapterMode: .stallAfterAuthentication,
      maximumSessionCount: 500
    )
    let handle = try await harness.start()
    var rows: [PhysicalMemoryMatrixRow] = []
    var nextFlow = 0
    var stopReason =
      "Stopped at the explicitly narrowed 500-session configuration limit; 1200 was not forced."

    for target in [100, 250, 500] {
      let admitted = try await admitMatrixFlows(
        nextFlow..<target,
        harness: harness,
        expectedStartingCount: harness.adapter.acceptedCount
      )
      nextFlow = target
      let reachedTarget = admitted == target
      let process = try physicalProcessSnapshot()
      let bridge = await harness.bridge.metrics()
      rows.append(
        PhysicalMemoryMatrixRow(
          stage: reachedTarget ? "staged" : "measured-safe-ceiling",
          requestedFlowCount: target,
          flowCount: admitted,
          traffic: "idle UDP-in-TCP sessions established by unique loopback IPv4 flows",
          physicalFootprintBytes: process.physicalFootprintBytes,
          peakPhysicalFootprintBytes: process.peakPhysicalFootprintBytes,
          availableMemoryBytes: process.availableMemoryBytes,
          availableMemoryAvailability: process.availableMemoryAvailability,
          hevSessions: harness.adapter.liveChannelCount,
          configuredTaskStackBytesPerSession: 24_576,
          configuredTCPBufferBytesPerSession: 4_096,
          bridgeSocketBufferBytes: 16_384,
          queuedBytes: nil,
          queuedBytesAvailability:
            "unknown: pinned HEV exposes session and traffic counters but no queue-byte gauge",
          descriptors: process.descriptors,
          swiftTasks: nil,
          swiftTasksAvailability:
            "unavailable: public Swift runtime APIs expose no process-wide live Task count",
          processThreads: process.threads,
          drops: matrixDropCount(bridge),
          failures: []
        )
      )
      if !reachedTarget {
        stopReason =
          "Stopped early while staging \(target): only \(admitted) live HEV sessions were admitted within the bounded 5-second probe. Rows 500 and configured 1200 were not forced."
        break
      }
    }

    harness.adapter.closeAll()
    await harness.stop(handle)
    harness.driver.releaseLateRead()
    await expectHarnessOwnedResourcesReleased(harness, descriptorBaseline: initial.descriptors)
    let report = PhysicalMemoryMatrixReport(
      schemaVersion: 2,
      taskID: "TASK-260715-135rr8",
      generatedAtUTC: ISO8601DateFormatter().string(from: Date()),
      device: physicalDeviceDescription(),
      platform: ProcessInfo.processInfo.operatingSystemVersionString,
      architecture: physicalArchitecture(),
      sourceRevision: provenance.candidateTreeOID,
      dependencyRevisions: [
        "hev-socks5-tunnel.revision": provenance.hevRevision,
        "hev-socks5-tunnel.source_sha256": provenance.hevSourceSHA256,
        "hev-socks5-tunnel.macos_artifact_sha256": provenance.hevMacOSArtifactSHA256,
        "ReluxTunnelNativeAdapter.tree": provenance.candidateTreeOID,
      ],
      exactConfiguration: [
        "address_scope": "numeric loopback only",
        "flow_stages": "100,250,500",
        "lifecycle_cycles": "500",
        "lifecycle_warmup_samples": "10",
        "lifecycle_trailing_samples": "0",
        "lifecycle_post_warmup_growth_ceiling_bytes": "262144",
        "lifecycle_owned_resource_release":
          "required on every cycle from harness-owned counters and close stages",
        "maximum_session_count": "500 (narrowed physical-run ceiling)",
        "task_stack_size_bytes": "24576",
        "tcp_buffer_size_bytes": "4096",
        "bridge_socket_buffer_bytes": "16384",
      ],
      duration:
        "500 lifecycle cycles plus stages bounded by 20 seconds each; actual suite duration is preserved in the test log",
      rows: rows,
      lifecycle: lifecycle,
      pressurePolicy: [
        "soft": "reduce new work; behavior deferred until SSH admission integration",
        "pressure": "stop admitting new work; behavior deferred until SSH admission integration",
        "critical": "stop bridge work; production HEV teardown covered, SSH orchestration deferred",
      ],
      stopReason: stopReason,
      targetAssessment: physicalTargetAssessment(rows: rows, baseline: initial),
      gaps: [
        "Physical iPhone rows are deferred with iOS.",
        "Sleep/wake is unavailable to a bounded headless SwiftPM test without changing global host state.",
        "HEV queued bytes and process-wide Swift Task count are unknown, not proxy zeros.",
        "SSH, DNS, relay, caches, and reconnect overlap are not allocated in this HEV/bridge baseline.",
      ]
    )
    let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(
        ".temp/TASK-260715-135rr8/TASK-260715-135rr8_raw-memory-matrix-\(provenance.runID).json"
      )
    try FileManager.default.createDirectory(
      at: output.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try emitEvidenceBeforeLifecycleGate(
      gatePassed: lifecycle.evidenceGatePassed,
      failureReason: lifecycle.failureReason
    ) {
      try encoder.encode(report).write(to: output, options: .atomic)
    }
  }

  @Test(
    "production bridge start refuses a zero HEV session configuration"
  )
  func productionBridgeStartRefusesZeroHEVSessionConfiguration() async {
    let harness = RealHEVBridgeHarness(
      adapterMode: .stallAfterAuthentication,
      maximumSessionCount: 0
    )
    await #expect(
      throws: PacketFlowBridgeError.descriptorBorrowFailure
    ) {
      try await harness.start()
    }
  }

  @Test("physical matrix evidence gate refuses absent, forged, and malformed provenance")
  func physicalMatrixEvidenceGateRefusesInvalidProvenance() throws {
    let actualCandidateTreeOID = try resolveWorkingCandidateTreeOID()
    let manifestData = try Data(
      contentsOf: URL(fileURLWithPath: "NativeDependencies/manifest.json")
    )
    #expect(throws: PhysicalMatrixEvidenceError.self) {
      try physicalMatrixProvenance(environment: [:], manifestData: validHEVManifestData())
    }
    #expect(throws: PhysicalMatrixEvidenceError.self) {
      try physicalMatrixProvenance(
        environment: [
          "RELUX_MATRIX_RUN_ID": "run/unsafe",
          "RELUX_CANDIDATE_TREE_OID": String(repeating: "a", count: 40),
        ],
        manifestData: validHEVManifestData()
      )
    }
    #expect(throws: PhysicalMatrixEvidenceError.self) {
      try physicalMatrixProvenance(
        environment: [
          "RELUX_MATRIX_RUN_ID": "run-01",
          "RELUX_CANDIDATE_TREE_OID": String(repeating: "a", count: 39),
        ],
        manifestData: validHEVManifestData()
      )
    }
    #expect(throws: PhysicalMatrixEvidenceError.self) {
      try physicalMatrixProvenance(
        environment: [
          "RELUX_MATRIX_RUN_ID": "run-01",
          "RELUX_CANDIDATE_TREE_OID": forgedTreeOID(differentFrom: actualCandidateTreeOID),
        ],
        manifestData: validHEVManifestData()
      )
    }
    #expect(throws: PhysicalMatrixEvidenceError.self) {
      try physicalMatrixProvenance(
        environment: [
          "RELUX_MATRIX_RUN_ID": "run-01",
          "RELUX_CANDIDATE_TREE_OID": actualCandidateTreeOID,
        ],
        manifestData: Data("{\"dependencies\":{}}".utf8)
      )
    }
    let manifestText = String(decoding: manifestData, as: UTF8.self)
    let expectedArtifactHash =
      "f6bdda3e182049877dc449c670f8a2300007461e3ac3e4c5d2c1b0394de91eee"
    #expect(manifestText.contains(expectedArtifactHash))
    let forgedArtifactManifest = Data(
      manifestText.replacingOccurrences(
        of: expectedArtifactHash,
        with: String(repeating: "0", count: 64)
      ).utf8
    )
    #expect(throws: PhysicalMatrixEvidenceError.self) {
      try physicalMatrixProvenance(
        environment: [
          "RELUX_MATRIX_RUN_ID": "run-01",
          "RELUX_CANDIDATE_TREE_OID": actualCandidateTreeOID,
        ],
        manifestData: forgedArtifactManifest
      )
    }
  }

  @Test("lifecycle trend flags rise with plateaus after warmup")
  func lifecycleTrendFlagsNonDecreasingGrowth() {
    let analysis = analyzeLifecycleFootprint(
      [10, 20, 30, 30, 40, 40],
      warmupSampleCount: 2
    )

    #expect(analysis.monotonicGrowthObserved)
    #expect(analysis.analyzedSampleCount == 4)
    #expect(analysis.increaseTransitionCount == 1)
    #expect(analysis.equalTransitionCount == 2)
    #expect(analysis.decreaseTransitionCount == 0)
    #expect(analysis.netChangeBytes == 10)
  }

  @Test("lifecycle trend ignores allocator rise confined to fixed warmup")
  func lifecycleTrendAcceptsStabilizedPostWarmupWindow() {
    let analysis = analyzeLifecycleFootprint(
      [10, 20, 30, 30, 30, 30],
      warmupSampleCount: 2
    )

    #expect(!analysis.monotonicGrowthObserved)
    #expect(analysis.increaseTransitionCount == 0)
    #expect(analysis.equalTransitionCount == 3)
    #expect(analysis.decreaseTransitionCount == 0)
    #expect(analysis.netChangeBytes == 0)
  }

  @Test("lifecycle footprint records a bounded late allocator rise without claiming release")
  func lifecycleFootprintRecordsBoundedLateRise() {
    let policy = LifecycleConvergencePolicy(
      minimumSampleCount: 8,
      trailingSampleCount: 4,
      absolutePostWarmupGrowthCeilingBytes: 64
    )
    let analysis = analyzeLifecycleFootprint(
      [10, 20, 30, 40, 40, 40, 40, 40],
      warmupSampleCount: 1,
      convergencePolicy: policy
    )

    #expect(analysis.monotonicGrowthObserved)
    #expect(analysis.residentFootprintBoundObserved)
    #expect(analysis.netChangeBytes == 20)
    #expect(analysis.trailingNetChangeBytes == 0)
    #expect(analysis.trailingIncreaseTransitionCount == 0)
  }

  @Test("lifecycle convergence accepts bounded allocator sawtooth with a release")
  func lifecycleConvergenceAcceptsBoundedOscillation() {
    let policy = LifecycleConvergencePolicy(
      minimumSampleCount: 8,
      trailingSampleCount: 4,
      absolutePostWarmupGrowthCeilingBytes: 64
    )
    let analysis = analyzeLifecycleFootprint(
      [10, 20, 30, 40, 30, 40, 30, 30],
      warmupSampleCount: 1,
      convergencePolicy: policy
    )

    #expect(analysis.boundedConvergenceObserved)
    #expect(analysis.trailingIncreaseTransitionCount == 1)
    #expect(analysis.trailingDecreaseTransitionCount == 1)
    #expect(analysis.trailingNetChangeBytes == 0)
    #expect(analysis.trailingMaximumDrawupBytes == 10)
  }

  @Test("lifecycle footprint detects a late rise hidden among plateaus")
  func lifecycleFootprintDetectsLateRiseWithPlateaus() {
    let policy = LifecycleConvergencePolicy(
      minimumSampleCount: 8,
      trailingSampleCount: 4,
      absolutePostWarmupGrowthCeilingBytes: 64
    )
    let analysis = analyzeLifecycleFootprint(
      [10, 20, 30, 40, 40, 40, 50, 50],
      warmupSampleCount: 1,
      convergencePolicy: policy
    )

    #expect(analysis.residentFootprintBoundObserved)
    #expect(analysis.monotonicGrowthObserved)
    #expect(analysis.trailingIncreaseTransitionCount == 1)
    #expect(analysis.increaseCycles == [3, 4, 7])
  }

  @Test("lifecycle convergence rejects an oversized early high-water plateau")
  func lifecycleConvergenceRejectsOversizedHighWaterPlateau() {
    let policy = LifecycleConvergencePolicy(
      minimumSampleCount: 8,
      trailingSampleCount: 4,
      absolutePostWarmupGrowthCeilingBytes: 64
    )
    let analysis = analyzeLifecycleFootprint(
      [10, 20, 100, 100, 100, 100, 100, 100],
      warmupSampleCount: 1,
      convergencePolicy: policy
    )

    #expect(!analysis.boundedConvergenceObserved)
    #expect(analysis.trailingIncreaseTransitionCount == 0)
    #expect(analysis.netChangeBytes == 80)
  }

  @Test("lifecycle convergence rejects released but linearly rising sawtooth")
  func lifecycleConvergenceRejectsUnboundedSawtooth() {
    let policy = LifecycleConvergencePolicy(
      minimumSampleCount: 8,
      trailingSampleCount: 0,
      absolutePostWarmupGrowthCeilingBytes: 32
    )
    let analysis = analyzeLifecycleFootprint(
      [10, 20, 30, 25, 40, 35, 50, 45],
      warmupSampleCount: 1,
      convergencePolicy: policy
    )

    #expect(analysis.decreaseTransitionCount == 3)
    #expect(analysis.postWarmupMaximumDrawupBytes == 30)
    #expect(analysis.netChangeBytes == 25)
    #expect(analysis.boundedConvergenceObserved)

    let narrowed = analyzeLifecycleFootprint(
      [10, 20, 30, 25, 40, 35, 70, 65],
      warmupSampleCount: 1,
      convergencePolicy: policy
    )
    #expect(narrowed.postWarmupMaximumDrawupBytes == 50)
    #expect(!narrowed.boundedConvergenceObserved)
  }

  @Test("lifecycle evidence gate rejects a missing owned-resource release")
  func lifecycleEvidenceGateRejectsMissingOwnedResourceRelease() {
    #expect(
      lifecycleEvidenceGatePassed(
        cycles: 500,
        residentFootprintBoundObserved: true,
        ownedResourceReleaseFailureCycles: []
      )
    )
    #expect(
      !lifecycleEvidenceGatePassed(
        cycles: 500,
        residentFootprintBoundObserved: true,
        ownedResourceReleaseFailureCycles: [499]
      )
    )
  }

  @Test("lifecycle evidence gate rejects fewer than 500 cycles and footprint overflow")
  func lifecycleEvidenceGateRejectsNarrowedCycleAndFootprintBounds() {
    #expect(
      !lifecycleEvidenceGatePassed(
        cycles: 499,
        residentFootprintBoundObserved: true,
        ownedResourceReleaseFailureCycles: []
      )
    )
    #expect(
      !lifecycleEvidenceGatePassed(
        cycles: 500,
        residentFootprintBoundObserved: false,
        ownedResourceReleaseFailureCycles: []
      )
    )
  }

  @Test("production matrix emission gate preserves evidence before refusing")
  func productionMatrixEmissionGateWritesBeforeFailure() {
    var evidenceWasEmitted = false

    #expect(throws: IntegrationTestError.self) {
      try emitEvidenceBeforeLifecycleGate(
        gatePassed: false,
        failureReason: "narrowed negative fixture"
      ) {
        evidenceWasEmitted = true
      }
    }
    #expect(evidenceWasEmitted)
  }

  @Test("lifecycle observer preallocates every retained sample before baseline")
  func lifecycleObserverPreallocatesRetainedSamples() {
    let samples = preallocatedLifecycleSamples(cycles: 1_000)

    #expect(samples.isEmpty)
    #expect(samples.capacity >= 1_000)
  }

  @Test("lifecycle probe cycle gate accepts only bounded diagnostic rows")
  func lifecycleProbeCycleGateRejectsWiderOrMalformedRows() throws {
    for cycles in [100, 500, 1_000] {
      #expect(
        try requestedLifecycleProbeCycles(
          environment: ["RELUX_LIFECYCLE_CYCLES": String(cycles)]
        ) == cycles
      )
    }
    #expect(throws: PhysicalMatrixEvidenceError.self) {
      try requestedLifecycleProbeCycles(environment: [:])
    }
    #expect(throws: PhysicalMatrixEvidenceError.self) {
      try requestedLifecycleProbeCycles(environment: ["RELUX_LIFECYCLE_CYCLES": "2000"])
    }
    #expect(throws: PhysicalMatrixEvidenceError.self) {
      try requestedLifecycleProbeCycles(environment: ["RELUX_LIFECYCLE_CYCLES": "many"])
    }
  }
}

private final class RealHEVBridgeHarness: @unchecked Sendable {
  let adapter: IntegrationSOCKSAdapter
  let accessRecorder = BoundaryAccessRecorder()
  let driver: IntegrationPacketFlowDriver
  let lifecycleRecorder = IntegrationLifecycleRecorder()
  let metrics = IntegrationMetrics()
  let bridge: PacketFlowBridge
  private let flow: MacOSPacketFlowAdapter

  init(
    adapterMode: IntegrationSOCKSAdapter.Mode = .respond,
    socketBufferBytes: Int = 16_384,
    rejectPacketWrites: Bool = false,
    maximumSessionCount: Int = 1_200
  ) {
    adapter = IntegrationSOCKSAdapter(mode: adapterMode)
    driver = IntegrationPacketFlowDriver(rejectWrites: rejectPacketWrites)
    flow = MacOSPacketFlowAdapter(driver: driver)
    let credentials = HEVSOCKSCredentials(
      username: "relux-integration-user",
      password: "relux-integration-password"
    )
    let factory = CapturingBoundaryFactory(
      adapter: adapter,
      credentials: credentials,
      recorder: accessRecorder
    )
    let consumer = HEVDescriptorBorrowConsumer(
      configuration: InternalSOCKSConfiguration(
        mtuBytes: 1_500,
        taskStackSizeBytes: 24_576,
        tcpBufferSizeBytes: 4_096,
        udpCopyBufferCount: 2,
        maximumSessionCount: maximumSessionCount
      ),
      boundaryFactory: factory,
      runtime: PinnedHEVNativeRuntime(),
      logger: IntegrationLogger(),
      metrics: metrics
    )
    bridge = PacketFlowBridge(
      descriptorConsumer: consumer,
      clock: ContinuousTunnelClock(),
      logger: IntegrationLogger(),
      metrics: metrics,
      runIDSource: FixedIntegrationRunIDSource(),
      lifecycleBarrier: lifecycleRecorder
    )
    configuration = PacketBridgeConfiguration(
      mtu: 1_500,
      sendBufferBytes: socketBufferBytes,
      receiveBufferBytes: socketBufferBytes,
      maximumWorkCount: 64,
      workTimeBudget: .milliseconds(5),
      diagnosticsWindow: .seconds(60)
    )
  }

  let configuration: PacketBridgeConfiguration

  func start() async throws -> PacketFlowBridgeRunHandle {
    try await bridge.start(packetFlow: flow, configuration: configuration)
  }

  func stop(_ handle: PacketFlowBridgeRunHandle) async {
    await bridge.stop()
    try? await handle.waitForTermination()
  }

  func ownedResourceSnapshot() async -> OwnedResourceSnapshot {
    let access = accessRecorder.snapshot()
    let driver = driver.snapshot()
    let recordedMetrics = await metrics.snapshot()
    return OwnedResourceSnapshot(
      boundaryStarts: access.starts,
      boundaryStops: access.stops,
      liveSOCKSChannels: adapter.liveChannelCount,
      queuedPacketBatches: driver.queuedBatchCount,
      outstandingPacketReads: driver.outstandingReadCount,
      reachedHEVDescriptorClosed: lifecycleRecorder.reached(.hevDescriptorClosed),
      reachedBridgeDescriptorClosed: lifecycleRecorder.reached(.bridgeDescriptorClosed),
      hevStartTotal: recordedMetrics.counters["hev_start_total", default: 0],
      hevMainReturnTotal: recordedMetrics.counters["hev_main_return_total", default: 0],
      cleanupCloseErrors: recordedMetrics.counters[
        "packet_bridge_cleanup_close_error_total", default: 0]
    )
  }
}

private struct PhysicalProcessSnapshot: Sendable {
  let physicalFootprintBytes: UInt64
  let peakPhysicalFootprintBytes: UInt64
  let availableMemoryBytes: UInt64?
  let availableMemoryAvailability: String
  let descriptors: Int
  let threads: Int
}

private struct PhysicalMemoryMatrixRow: Codable, Sendable {
  let stage: String
  let requestedFlowCount: Int
  let flowCount: Int
  let traffic: String
  let physicalFootprintBytes: UInt64
  let peakPhysicalFootprintBytes: UInt64
  let availableMemoryBytes: UInt64?
  let availableMemoryAvailability: String
  let hevSessions: Int
  let configuredTaskStackBytesPerSession: Int
  let configuredTCPBufferBytesPerSession: Int
  let bridgeSocketBufferBytes: Int
  let queuedBytes: UInt64?
  let queuedBytesAvailability: String
  let descriptors: Int
  let swiftTasks: Int?
  let swiftTasksAvailability: String
  let processThreads: Int
  let drops: UInt64
  let failures: [String]
}

private struct PhysicalMemoryLifecycleEvidence: Codable, Sendable {
  let cycles: Int
  let result: String
  let evidenceGatePassed: Bool
  let failureReason: String
  let cancellationPoints: String
  let initialDescriptors: Int
  let finalDescriptors: Int
  let initialThreads: Int
  let finalThreads: Int
  let initialPhysicalFootprintBytes: UInt64
  let finalPhysicalFootprintBytes: UInt64
  let warmupSampleCount: Int
  let analyzedSampleCount: Int
  let netPhysicalFootprintChangeBytes: Int64
  let increaseTransitionCount: Int
  let equalTransitionCount: Int
  let decreaseTransitionCount: Int
  let monotonicGrowthObserved: Bool
  let minimumCycleCountForConvergence: Int
  let trailingSampleCount: Int
  let absolutePostWarmupGrowthCeilingBytes: UInt64
  let trailingNetPhysicalFootprintChangeBytes: Int64
  let trailingIncreaseTransitionCount: Int
  let trailingEqualTransitionCount: Int
  let trailingDecreaseTransitionCount: Int
  let postWarmupMaximumDrawupBytes: UInt64
  let trailingMaximumDrawupBytes: UInt64
  let residentFootprintBoundObserved: Bool
  let ownedResourceReleaseSignal: String
  let ownedResourceReleaseCycleCount: Int
  let ownedResourceReleaseFailureCycles: [Int]
  let boundedConvergenceObserved: Bool
  let increaseCycles: [Int]
  let samples: [PhysicalMemoryLifecycleSample]
}

private struct PhysicalMemoryLifecycleSample: Codable, Sendable {
  let cycle: Int
  let descriptors: Int
  let processThreads: Int
  let physicalFootprintBytes: UInt64
  let liveHEVSessionsAfterCleanup: Int
  let outstandingReadsAfterCleanup: Int
  let queuedBatchesAfterCleanup: Int
  let boundaryStarts: Int
  let boundaryStops: Int
  let hevStartTotal: UInt64
  let hevMainReturnTotal: UInt64
  let reachedHEVDescriptorClosed: Bool
  let reachedBridgeDescriptorClosed: Bool
  let cleanupCloseErrors: UInt64
  let ownedResourcesReleased: Bool
}

private struct ExtendedLifecycleInvestigationReport: Codable, Sendable {
  let schemaVersion: UInt16
  let taskID: String
  let generatedAtUTC: String
  let sourceRevision: String
  let hevRevision: String
  let hevMacOSArtifactSHA256: String
  let segmentSampleCount: Int
  let increaseCycles: [Int]
  let segments: [LifecycleSegment]
  let lifecycle: PhysicalMemoryLifecycleEvidence
}

private struct LifecycleSegment: Codable, Sendable {
  let firstCycle: Int
  let lastCycle: Int
  let sampleCount: Int
  let netPhysicalFootprintChangeBytes: Int64
  let bytesPerCycle: Double
  let increaseTransitionCount: Int
  let equalTransitionCount: Int
  let decreaseTransitionCount: Int
  let initialDescriptors: Int
  let finalDescriptors: Int
  let initialThreads: Int
  let finalThreads: Int
}

private struct PhysicalMatrixProvenance: Sendable {
  let runID: String
  let candidateTreeOID: String
  let hevRevision: String
  let hevSourceSHA256: String
  let hevMacOSArtifactSHA256: String
}

private enum PhysicalMatrixEvidenceError: Error {
  case missing(String)
  case malformed(String)
  case resolutionFailed(String)
  case mismatch(String)
}

private struct PhysicalMemoryMatrixReport: Codable, Sendable {
  let schemaVersion: UInt16
  let taskID: String
  let generatedAtUTC: String
  let device: String
  let platform: String
  let architecture: String
  let sourceRevision: String
  let dependencyRevisions: [String: String]
  let exactConfiguration: [String: String]
  let duration: String
  let rows: [PhysicalMemoryMatrixRow]
  let lifecycle: PhysicalMemoryLifecycleEvidence
  let pressurePolicy: [String: String]
  let stopReason: String
  let targetAssessment: String
  let gaps: [String]
}

private func physicalMatrixProvenance(
  environment: [String: String],
  manifestData: Data
) throws -> PhysicalMatrixProvenance {
  func required(_ name: String) throws -> String {
    guard let value = environment[name], !value.isEmpty else {
      throw PhysicalMatrixEvidenceError.missing(name)
    }
    return value
  }

  let runID = try required("RELUX_MATRIX_RUN_ID")
  let candidateTreeOID = try required("RELUX_CANDIDATE_TREE_OID")
  let safeRunID = runID.allSatisfy {
    $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_")
  }
  guard safeRunID else { throw PhysicalMatrixEvidenceError.malformed("RELUX_MATRIX_RUN_ID") }
  guard isLowercaseHex(candidateTreeOID, count: 40) else {
    throw PhysicalMatrixEvidenceError.malformed("RELUX_CANDIDATE_TREE_OID")
  }
  let actualCandidateTreeOID = try resolveWorkingCandidateTreeOID()
  guard candidateTreeOID == actualCandidateTreeOID else {
    throw PhysicalMatrixEvidenceError.mismatch(
      "RELUX_CANDIDATE_TREE_OID does not match the independently resolved working tree"
    )
  }
  guard
    let root = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
    let dependencies = root["dependencies"] as? [String: Any],
    let hev = dependencies["hev-lwip"] as? [String: Any],
    let hevRevision = hev["revision"] as? String,
    let source = hev["source"] as? [String: Any],
    let hevSourceSHA256 = source["sha256"] as? String,
    let integration = hev["integration"] as? [String: Any],
    let artifactPath = integration["artifact_path"] as? String,
    let artifact = hev["artifact"] as? [String: Any],
    let artifactHashes = artifact["file_sha256"] as? [String: String],
    let expectedMacOSArtifactSHA256 = artifactHashes[
      "macos-arm64_x86_64/libhev-socks5-tunnel.a"
    ],
    isLowercaseHex(hevRevision, count: 40),
    isLowercaseHex(hevSourceSHA256, count: 64),
    isLowercaseHex(expectedMacOSArtifactSHA256, count: 64)
  else {
    throw PhysicalMatrixEvidenceError.malformed("NativeDependencies/manifest.json hev-lwip")
  }
  let artifactURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent(artifactPath, isDirectory: true)
    .appendingPathComponent("macos-arm64_x86_64/libhev-socks5-tunnel.a")
  let actualMacOSArtifactSHA256: String
  do {
    actualMacOSArtifactSHA256 = SHA256.hash(data: try Data(contentsOf: artifactURL))
      .map { String(format: "%02x", $0) }
      .joined()
  } catch {
    throw PhysicalMatrixEvidenceError.resolutionFailed(
      "unable to hash pinned macOS HEV artifact"
    )
  }
  guard actualMacOSArtifactSHA256 == expectedMacOSArtifactSHA256 else {
    throw PhysicalMatrixEvidenceError.mismatch(
      "pinned macOS HEV artifact does not match its manifest hash"
    )
  }
  return PhysicalMatrixProvenance(
    runID: runID,
    candidateTreeOID: candidateTreeOID,
    hevRevision: hevRevision,
    hevSourceSHA256: hevSourceSHA256,
    hevMacOSArtifactSHA256: actualMacOSArtifactSHA256
  )
}

private func resolveWorkingCandidateTreeOID() throws -> String {
  let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  let taskDirectory = repositoryRoot.appendingPathComponent(
    ".temp/TASK-260715-135rr8",
    isDirectory: true
  )
  let indexDirectory = taskDirectory.appendingPathComponent(
    "candidate-index-\(UUID().uuidString)",
    isDirectory: true
  )
  do {
    try FileManager.default.createDirectory(
      at: indexDirectory,
      withIntermediateDirectories: true
    )
  } catch {
    throw PhysicalMatrixEvidenceError.resolutionFailed(
      "unable to create task-local candidate index"
    )
  }
  defer { try? FileManager.default.removeItem(at: indexDirectory) }

  let indexPath = indexDirectory.appendingPathComponent("index").path
  var environment = ProcessInfo.processInfo.environment
  environment["GIT_INDEX_FILE"] = indexPath
  _ = try runCandidateGit(
    ["read-tree", "HEAD"],
    repositoryRoot: repositoryRoot,
    environment: environment
  )
  _ = try runCandidateGit(
    ["add", "-A"],
    repositoryRoot: repositoryRoot,
    environment: environment
  )
  let treeOID = try runCandidateGit(
    ["write-tree"],
    repositoryRoot: repositoryRoot,
    environment: environment
  ).trimmingCharacters(in: .whitespacesAndNewlines)
  guard isLowercaseHex(treeOID, count: 40) else {
    throw PhysicalMatrixEvidenceError.resolutionFailed(
      "git write-tree returned a malformed candidate OID"
    )
  }
  return treeOID
}

private func runCandidateGit(
  _ arguments: [String],
  repositoryRoot: URL,
  environment: [String: String]
) throws -> String {
  let process = Process()
  let standardOutput = Pipe()
  let standardError = Pipe()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = ["git"] + arguments
  process.currentDirectoryURL = repositoryRoot
  process.environment = environment
  process.standardOutput = standardOutput
  process.standardError = standardError
  do {
    try process.run()
  } catch {
    throw PhysicalMatrixEvidenceError.resolutionFailed(
      "unable to launch task-local git candidate resolver"
    )
  }
  process.waitUntilExit()
  let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
  let errorOutput = standardError.fileHandleForReading.readDataToEndOfFile()
  guard process.terminationReason == .exit, process.terminationStatus == 0 else {
    let boundedError = String(decoding: errorOutput.prefix(512), as: UTF8.self)
    throw PhysicalMatrixEvidenceError.resolutionFailed(
      "git \(arguments.first ?? "command") failed: \(boundedError)"
    )
  }
  return String(decoding: output, as: UTF8.self)
}

private func forgedTreeOID(differentFrom actual: String) -> String {
  let candidate = String(repeating: "0", count: 40)
  return candidate == actual ? String(repeating: "f", count: 40) : candidate
}

private func validHEVManifestData() -> Data {
  Data(
    """
    {"dependencies":{"hev-lwip":{"revision":"\(String(repeating: "a", count: 40))","source":{"sha256":"\(String(repeating: "b", count: 64))"}}}}
    """.utf8
  )
}

private func isLowercaseHex(_ value: String, count: Int) -> Bool {
  value.count == count
    && value.allSatisfy { character in
      character.isNumber || ("a"..."f").contains(character)
    }
}

private func measureRealHEVLifecycle(cycles: Int) async throws
  -> PhysicalMemoryLifecycleEvidence
{
  var acceptedSessions = 0
  var samples = preallocatedLifecycleSamples(cycles: cycles)
  let initial = try physicalProcessSnapshot()

  for iteration in 0..<cycles {
    let descriptorBaseline = openDescriptorCount()
    let harness = RealHEVBridgeHarness(adapterMode: .stallAfterAuthentication)
    let handle = try await harness.start()
    try harness.driver.deliver(
      makeUDPPacket(
        family: .ipv4,
        source: Data([10, 43, UInt8(iteration / 250), UInt8(iteration % 250 + 1)]),
        destination: Data([192, 0, 2, 1]),
        sourcePort: UInt16(55_000 + iteration),
        destinationPort: 7,
        payload: Data([UInt8(truncatingIfNeeded: iteration)])
      )
    )
    #expect(
      await eventually(timeout: .seconds(3)) {
        harness.adapter.acceptedCount == 1
      },
      "cycle \(iteration) did not reach the real SOCKS boundary"
    )
    acceptedSessions += harness.adapter.acceptedCount

    harness.adapter.closeAll()
    await harness.stop(handle)
    harness.driver.releaseLateRead()
    let driver = harness.driver.snapshot()
    let access = harness.accessRecorder.snapshot()
    let metrics = await harness.metrics.snapshot()
    #expect(driver.outstandingReadCount == 0)
    #expect(driver.queuedBatchCount == 0)
    #expect(harness.adapter.liveChannelCount == 0)
    #expect(access.starts == 1)
    #expect(access.stops == 1)
    #expect(metrics.counters["hev_start_total"] == 1)
    #expect(metrics.counters["hev_main_return_total"] == 1)
    #expect(await harness.bridge.lifecycleState() == .stopped(lastRunID: "integration-run-1"))
    let ownedResources = await expectHarnessOwnedResourcesReleased(
      harness,
      descriptorBaseline: descriptorBaseline
    )
    let process = try physicalProcessSnapshot()
    samples.append(
      PhysicalMemoryLifecycleSample(
        cycle: iteration + 1,
        descriptors: process.descriptors,
        processThreads: process.threads,
        physicalFootprintBytes: process.physicalFootprintBytes,
        liveHEVSessionsAfterCleanup: ownedResources.liveSOCKSChannels,
        outstandingReadsAfterCleanup: ownedResources.outstandingPacketReads,
        queuedBatchesAfterCleanup: ownedResources.queuedPacketBatches,
        boundaryStarts: ownedResources.boundaryStarts,
        boundaryStops: ownedResources.boundaryStops,
        hevStartTotal: ownedResources.hevStartTotal,
        hevMainReturnTotal: ownedResources.hevMainReturnTotal,
        reachedHEVDescriptorClosed: ownedResources.reachedHEVDescriptorClosed,
        reachedBridgeDescriptorClosed: ownedResources.reachedBridgeDescriptorClosed,
        cleanupCloseErrors: ownedResources.cleanupCloseErrors,
        ownedResourcesReleased: ownedResources.allReleased
      )
    )
  }

  let final = try physicalProcessSnapshot()
  let footprintAnalysis = analyzeLifecycleFootprint(
    samples.map(\.physicalFootprintBytes),
    warmupSampleCount: 10,
    convergencePolicy: .physicalHEVLifecycle
  )
  #expect(acceptedSessions == cycles)
  let ownedResourceReleaseFailureCycles = samples.compactMap {
    $0.ownedResourcesReleased ? nil : $0.cycle
  }
  let evidenceGatePassed = lifecycleEvidenceGatePassed(
    cycles: cycles,
    residentFootprintBoundObserved: footprintAnalysis.residentFootprintBoundObserved,
    ownedResourceReleaseFailureCycles: ownedResourceReleaseFailureCycles
  )
  let failureReason =
    evidenceGatePassed
    ? "none"
    : "lifecycle evidence gate failed: cycles=\(cycles)/\(footprintAnalysis.convergencePolicy.minimumSampleCount), resident-footprint-bound=\(footprintAnalysis.residentFootprintBoundObserved), post-warmup maximum drawup=\(footprintAnalysis.postWarmupMaximumDrawupBytes)/\(footprintAnalysis.convergencePolicy.absolutePostWarmupGrowthCeilingBytes), owned-resource-release failures=\(ownedResourceReleaseFailureCycles)"
  return PhysicalMemoryLifecycleEvidence(
    cycles: cycles,
    result:
      evidenceGatePassed
      ? "measured in this emitting process; every lifecycle-owned resource was released and resident physical-footprint drawup stayed within the fixed bound"
      : "measured in this emitting process; raw evidence was preserved before the lifecycle evidence gate failed",
    evidenceGatePassed: evidenceGatePassed,
    failureReason: failureReason,
    cancellationPoints:
      "covered by PacketFlowBridge lifecycle/fault suites at pre-borrow, active read, and stop",
    initialDescriptors: initial.descriptors,
    finalDescriptors: final.descriptors,
    initialThreads: initial.threads,
    finalThreads: final.threads,
    initialPhysicalFootprintBytes: initial.physicalFootprintBytes,
    finalPhysicalFootprintBytes: final.physicalFootprintBytes,
    warmupSampleCount: footprintAnalysis.warmupSampleCount,
    analyzedSampleCount: footprintAnalysis.analyzedSampleCount,
    netPhysicalFootprintChangeBytes: footprintAnalysis.netChangeBytes,
    increaseTransitionCount: footprintAnalysis.increaseTransitionCount,
    equalTransitionCount: footprintAnalysis.equalTransitionCount,
    decreaseTransitionCount: footprintAnalysis.decreaseTransitionCount,
    monotonicGrowthObserved: footprintAnalysis.monotonicGrowthObserved,
    minimumCycleCountForConvergence: footprintAnalysis.convergencePolicy.minimumSampleCount,
    trailingSampleCount: footprintAnalysis.convergencePolicy.trailingSampleCount,
    absolutePostWarmupGrowthCeilingBytes: footprintAnalysis.convergencePolicy
      .absolutePostWarmupGrowthCeilingBytes,
    trailingNetPhysicalFootprintChangeBytes: footprintAnalysis.trailingNetChangeBytes,
    trailingIncreaseTransitionCount: footprintAnalysis.trailingIncreaseTransitionCount,
    trailingEqualTransitionCount: footprintAnalysis.trailingEqualTransitionCount,
    trailingDecreaseTransitionCount: footprintAnalysis.trailingDecreaseTransitionCount,
    postWarmupMaximumDrawupBytes: footprintAnalysis.postWarmupMaximumDrawupBytes,
    trailingMaximumDrawupBytes: footprintAnalysis.trailingMaximumDrawupBytes,
    residentFootprintBoundObserved: footprintAnalysis.residentFootprintBoundObserved,
    ownedResourceReleaseSignal:
      "per-cycle harness-owned boundary start/stop, live HEV channel, queued batch, outstanding read, HEV/bridge descriptor-close stage, and cleanup-close-error counters",
    ownedResourceReleaseCycleCount: samples.count - ownedResourceReleaseFailureCycles.count,
    ownedResourceReleaseFailureCycles: ownedResourceReleaseFailureCycles,
    boundedConvergenceObserved: evidenceGatePassed,
    increaseCycles: footprintAnalysis.increaseCycles,
    samples: samples
  )
}

private func lifecycleEvidenceGatePassed(
  cycles: Int,
  residentFootprintBoundObserved: Bool,
  ownedResourceReleaseFailureCycles: [Int]
) -> Bool {
  cycles >= LifecycleConvergencePolicy.physicalHEVLifecycle.minimumSampleCount
    && residentFootprintBoundObserved
    && ownedResourceReleaseFailureCycles.isEmpty
}

private func emitEvidenceBeforeLifecycleGate(
  gatePassed: Bool,
  failureReason: String,
  emit: () throws -> Void
) throws {
  try emit()
  guard gatePassed else {
    throw IntegrationTestError.fixture(failureReason)
  }
}

private func preallocatedLifecycleSamples(cycles: Int) -> [PhysicalMemoryLifecycleSample] {
  var samples: [PhysicalMemoryLifecycleSample] = []
  samples.reserveCapacity(max(0, cycles))
  return samples
}

private func requestedLifecycleProbeCycles(environment: [String: String]) throws -> Int {
  guard
    let rawCycles = environment["RELUX_LIFECYCLE_CYCLES"],
    let cycles = Int(rawCycles),
    [100, 500, 1_000].contains(cycles)
  else {
    throw PhysicalMatrixEvidenceError.malformed("RELUX_LIFECYCLE_CYCLES")
  }
  return cycles
}

private func lifecycleSegments(
  samples: [PhysicalMemoryLifecycleSample],
  segmentSampleCount: Int
) -> [LifecycleSegment] {
  guard segmentSampleCount > 1 else { return [] }
  return stride(from: 0, to: samples.count, by: segmentSampleCount).compactMap { start in
    let end = min(start + segmentSampleCount, samples.count)
    let segment = Array(samples[start..<end])
    guard let first = segment.first, let last = segment.last else { return nil }
    let analysis = analyzeLifecycleFootprint(
      segment.map(\.physicalFootprintBytes),
      warmupSampleCount: 0
    )
    let transitions = max(1, segment.count - 1)
    return LifecycleSegment(
      firstCycle: first.cycle,
      lastCycle: last.cycle,
      sampleCount: segment.count,
      netPhysicalFootprintChangeBytes: analysis.netChangeBytes,
      bytesPerCycle: Double(analysis.netChangeBytes) / Double(transitions),
      increaseTransitionCount: analysis.increaseTransitionCount,
      equalTransitionCount: analysis.equalTransitionCount,
      decreaseTransitionCount: analysis.decreaseTransitionCount,
      initialDescriptors: first.descriptors,
      finalDescriptors: last.descriptors,
      initialThreads: first.processThreads,
      finalThreads: last.processThreads
    )
  }
}

private struct LifecycleConvergencePolicy: Equatable, Sendable {
  let minimumSampleCount: Int
  let trailingSampleCount: Int
  let absolutePostWarmupGrowthCeilingBytes: UInt64

  static let physicalHEVLifecycle = LifecycleConvergencePolicy(
    minimumSampleCount: 500,
    trailingSampleCount: 0,
    absolutePostWarmupGrowthCeilingBytes: 256 * 1_024
  )
}

private struct LifecycleFootprintAnalysis: Equatable, Sendable {
  let warmupSampleCount: Int
  let analyzedSampleCount: Int
  let netChangeBytes: Int64
  let increaseTransitionCount: Int
  let equalTransitionCount: Int
  let decreaseTransitionCount: Int
  let monotonicGrowthObserved: Bool
  let convergencePolicy: LifecycleConvergencePolicy
  let trailingNetChangeBytes: Int64
  let trailingIncreaseTransitionCount: Int
  let trailingEqualTransitionCount: Int
  let trailingDecreaseTransitionCount: Int
  let postWarmupMaximumDrawupBytes: UInt64
  let trailingMaximumDrawupBytes: UInt64
  let residentFootprintBoundObserved: Bool
  let boundedConvergenceObserved: Bool
  let increaseCycles: [Int]
}

private func analyzeLifecycleFootprint(
  _ samples: [UInt64],
  warmupSampleCount: Int,
  convergencePolicy: LifecycleConvergencePolicy = .physicalHEVLifecycle
) -> LifecycleFootprintAnalysis {
  let appliedWarmup = min(max(0, warmupSampleCount), samples.count)
  let analyzed = Array(samples.dropFirst(appliedWarmup))
  var increases = 0
  var equals = 0
  var decreases = 0
  var increaseCycles: [Int] = []
  for (offset, transition) in zip(analyzed, analyzed.dropFirst()).enumerated() {
    let (previous, next) = transition
    if next > previous {
      increases += 1
      increaseCycles.append(appliedWarmup + offset + 2)
    } else if next == previous {
      equals += 1
    } else {
      decreases += 1
    }
  }
  let netChange: Int64
  if let first = analyzed.first, let last = analyzed.last {
    netChange =
      last >= first
      ? Int64(clamping: last - first)
      : -Int64(clamping: first - last)
  } else {
    netChange = 0
  }
  let trailingSampleCount = min(
    max(0, convergencePolicy.trailingSampleCount),
    analyzed.count
  )
  let trailing = Array(analyzed.suffix(trailingSampleCount))
  var trailingIncreases = 0
  var trailingEquals = 0
  var trailingDecreases = 0
  for (previous, next) in zip(trailing, trailing.dropFirst()) {
    if next > previous {
      trailingIncreases += 1
    } else if next == previous {
      trailingEquals += 1
    } else {
      trailingDecreases += 1
    }
  }
  let trailingNetChange: Int64
  if let first = trailing.first, let last = trailing.last {
    trailingNetChange =
      last >= first
      ? Int64(clamping: last - first)
      : -Int64(clamping: first - last)
  } else {
    trailingNetChange = 0
  }
  let postWarmupMaximumDrawup = maximumDrawup(analyzed)
  let trailingMaximumDrawup = maximumDrawup(trailing)
  let withinGrowthCeiling =
    postWarmupMaximumDrawup <= convergencePolicy.absolutePostWarmupGrowthCeilingBytes
    && trailingMaximumDrawup <= convergencePolicy.absolutePostWarmupGrowthCeilingBytes
  let residentFootprintBoundObserved =
    samples.count >= convergencePolicy.minimumSampleCount
    && trailingSampleCount == convergencePolicy.trailingSampleCount
    && withinGrowthCeiling
  return LifecycleFootprintAnalysis(
    warmupSampleCount: appliedWarmup,
    analyzedSampleCount: analyzed.count,
    netChangeBytes: netChange,
    increaseTransitionCount: increases,
    equalTransitionCount: equals,
    decreaseTransitionCount: decreases,
    monotonicGrowthObserved: analyzed.count > 1 && increases > 0 && decreases == 0,
    convergencePolicy: convergencePolicy,
    trailingNetChangeBytes: trailingNetChange,
    trailingIncreaseTransitionCount: trailingIncreases,
    trailingEqualTransitionCount: trailingEquals,
    trailingDecreaseTransitionCount: trailingDecreases,
    postWarmupMaximumDrawupBytes: postWarmupMaximumDrawup,
    trailingMaximumDrawupBytes: trailingMaximumDrawup,
    residentFootprintBoundObserved: residentFootprintBoundObserved,
    boundedConvergenceObserved: residentFootprintBoundObserved,
    increaseCycles: increaseCycles
  )
}

private func maximumDrawup(_ samples: [UInt64]) -> UInt64 {
  guard var runningMinimum = samples.first else { return 0 }
  var maximum: UInt64 = 0
  for sample in samples.dropFirst() {
    runningMinimum = min(runningMinimum, sample)
    maximum = max(maximum, sample - runningMinimum)
  }
  return maximum
}

private func physicalProcessSnapshot() throws -> PhysicalProcessSnapshot {
  var virtualMemory = task_vm_info_data_t()
  var virtualMemoryCount = mach_msg_type_number_t(
    MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
  )
  let virtualMemoryStatus = withUnsafeMutablePointer(to: &virtualMemory) { pointer in
    pointer.withMemoryRebound(to: integer_t.self, capacity: Int(virtualMemoryCount)) {
      task_info(
        mach_task_self_,
        task_flavor_t(TASK_VM_INFO),
        $0,
        &virtualMemoryCount
      )
    }
  }
  guard virtualMemoryStatus == KERN_SUCCESS else {
    throw IntegrationTestError.fixture("task_info(TASK_VM_INFO)=\(virtualMemoryStatus)")
  }
  var taskInfo = proc_taskinfo()
  let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.size)
  let read = withUnsafeMutablePointer(to: &taskInfo) {
    proc_pidinfo(getpid(), PROC_PIDTASKINFO, 0, $0, taskInfoSize)
  }
  guard read == taskInfoSize else {
    throw IntegrationTestError.systemCall("proc_pidinfo(PROC_PIDTASKINFO)", errno)
  }
  return PhysicalProcessSnapshot(
    physicalFootprintBytes: virtualMemory.phys_footprint,
    peakPhysicalFootprintBytes: UInt64(max(0, virtualMemory.ledger_phys_footprint_peak)),
    availableMemoryBytes: nil,
    availableMemoryAvailability:
      "unavailable: os_proc_available_memory is explicitly unavailable on macOS in the public SDK; no host-memory proxy substituted",
    descriptors: openDescriptorCount(),
    threads: Int(taskInfo.pti_threadnum)
  )
}

private func makeMatrixUDPPacket(_ index: Int) -> IPPacket {
  makeUDPPacket(
    family: .ipv4,
    source: Data([10, 44, UInt8((index / 250) + 1), UInt8((index % 250) + 1)]),
    destination: Data([192, 0, 2, 44]),
    sourcePort: UInt16(10_000 + index),
    destinationPort: 9,
    payload: Data([UInt8(truncatingIfNeeded: index)])
  )
}

private func admitMatrixFlows(
  _ indexes: Range<Int>,
  harness: RealHEVBridgeHarness,
  expectedStartingCount: Int
) async throws -> Int {
  var expected = expectedStartingCount
  for index in indexes {
    try harness.driver.deliver(makeMatrixUDPPacket(index))
    let targetExpected = expected + 1
    let admitted = await eventually(timeout: .milliseconds(500)) {
      harness.adapter.acceptedCount == targetExpected
    }
    guard admitted else { return harness.adapter.acceptedCount }
    expected += 1
  }
  return harness.adapter.acceptedCount
}

private func matrixDropCount(_ snapshot: TunnelMetricsSnapshot) -> UInt64 {
  snapshot.counters["packet_bridge_forward_drop_would_block_total", default: 0]
    + snapshot.counters["packet_bridge_forward_drop_no_buffer_total", default: 0]
    + snapshot.counters["packet_bridge_forward_drop_invalid_packet_total", default: 0]
}

private func physicalTargetAssessment(
  rows: [PhysicalMemoryMatrixRow], baseline: PhysicalProcessSnapshot
) -> String {
  guard let steady = rows.last else { return "unknown: no measured rows" }
  let delta =
    steady.physicalFootprintBytes >= baseline.physicalFootprintBytes
    ? steady.physicalFootprintBytes - baseline.physicalFootprintBytes : 0
  let target = UInt64(30 * 1_024 * 1_024)
  return delta <= target
    ? "Met for incremental HEV/bridge footprint: \(delta) bytes at \(steady.flowCount) sessions; remaining 30 MiB envelope \(target - delta) bytes. SSH/DNS/relay/cache/reconnect allocations remain unmeasured."
    : "Not met: incremental HEV/bridge footprint \(delta) bytes exceeds 30 MiB by \(delta - target) bytes; no remaining budget may be claimed."
}

private func physicalDeviceDescription() -> String {
  var size = 0
  guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 1 else {
    return "Physical Apple-silicon Mac (model unavailable)"
  }
  var bytes = [CChar](repeating: 0, count: size)
  guard sysctlbyname("hw.model", &bytes, &size, nil, 0) == 0 else {
    return "Physical Apple-silicon Mac (model unavailable)"
  }
  let model = String(
    decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self
  )
  return "Physical Apple-silicon Mac (\(model); stable identifiers omitted)"
}

private func physicalArchitecture() -> String {
  var system = utsname()
  uname(&system)
  return withUnsafePointer(to: &system.machine) { pointer in
    pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
  }
}

private struct OwnedResourceSnapshot: Sendable, CustomStringConvertible {
  let boundaryStarts: Int
  let boundaryStops: Int
  let liveSOCKSChannels: Int
  let queuedPacketBatches: Int
  let outstandingPacketReads: Int
  let reachedHEVDescriptorClosed: Bool
  let reachedBridgeDescriptorClosed: Bool
  let hevStartTotal: UInt64
  let hevMainReturnTotal: UInt64
  let cleanupCloseErrors: UInt64

  var allReleased: Bool {
    boundaryStarts == 1 && boundaryStops == 1 && liveSOCKSChannels == 0
      && queuedPacketBatches == 0 && outstandingPacketReads == 0
      && reachedHEVDescriptorClosed && reachedBridgeDescriptorClosed
      && hevStartTotal == 1 && hevMainReturnTotal == 1
      && cleanupCloseErrors == 0
  }

  var description: String {
    "boundary starts/stops=\(boundaryStarts)/\(boundaryStops), "
      + "live SOCKS channels=\(liveSOCKSChannels), "
      + "queued packet batches=\(queuedPacketBatches), "
      + "outstanding packet reads=\(outstandingPacketReads), "
      + "HEV/bridge descriptor-close stages="
      + "\(reachedHEVDescriptorClosed)/\(reachedBridgeDescriptorClosed), "
      + "HEV start/main-return=\(hevStartTotal)/\(hevMainReturnTotal), "
      + "cleanup close errors=\(cleanupCloseErrors)"
  }
}

@discardableResult
private func expectHarnessOwnedResourcesReleased(
  _ harness: RealHEVBridgeHarness,
  descriptorBaseline: Int
) async -> OwnedResourceSnapshot {
  let released = await eventually {
    await harness.ownedResourceSnapshot().allReleased
  }
  let resources = await harness.ownedResourceSnapshot()
  let observedDescriptorCount = openDescriptorCount()
  #expect(
    released,
    """
    Harness-owned resources were not released: \(resources). Process-global descriptor \
    diagnostics only: baseline=\(descriptorBaseline), observed=\(observedDescriptorCount), \
    delta=\(observedDescriptorCount - descriptorBaseline).
    """
  )
  return resources
}

private struct FixedIntegrationRunIDSource: PacketBridgeRunIDSource {
  func nextRunID() -> String { "integration-run-1" }
}

private struct CapturingBoundaryFactory: HEVSOCKSBoundaryFactory {
  let adapter: IntegrationSOCKSAdapter
  let credentials: HEVSOCKSCredentials
  let recorder: BoundaryAccessRecorder

  func makeBoundary() -> any HEVSOCKSBoundary {
    CapturingBoundary(
      base: HEVLoopbackSOCKSBoundary(
        adapter: adapter,
        credentials: credentials,
        maximumPendingConnections: 8,
        authenticationTimeoutMilliseconds: 2_000
      ),
      recorder: recorder
    )
  }
}

private final class CapturingBoundary: HEVSOCKSBoundary, @unchecked Sendable {
  private let base: HEVLoopbackSOCKSBoundary
  private let recorder: BoundaryAccessRecorder

  init(base: HEVLoopbackSOCKSBoundary, recorder: BoundaryAccessRecorder) {
    self.base = base
    self.recorder = recorder
  }

  func start() async throws -> HEVSOCKSAccess {
    let access = try await base.start()
    recorder.started(access)
    return access
  }

  func stop() async {
    await base.stop()
    recorder.stopped()
  }
}

private final class BoundaryAccessRecorder: @unchecked Sendable {
  struct Snapshot: Sendable {
    let starts: Int
    let stops: Int
  }

  private let lock = NSLock()
  private var accesses: [HEVSOCKSAccess] = []
  private var stopCount = 0

  func started(_ access: HEVSOCKSAccess) {
    lock.withLock { accesses.append(access) }
  }

  func stopped() {
    lock.withLock { stopCount += 1 }
  }

  func nextAccess() async throws -> HEVSOCKSAccess {
    try await waitForValue {
      self.lock.withLock { self.accesses.first }
    }
  }

  func snapshot() -> Snapshot {
    lock.withLock { Snapshot(starts: accesses.count, stops: stopCount) }
  }
}

private final class IntegrationLifecycleRecorder: PacketBridgeLifecycleBarrier,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var stages: Set<String> = []

  func reach(_ stage: PacketBridgeLifecycleStage) async throws {
    lock.withLock {
      _ = stages.insert(stage.rawValue)
    }
  }

  func reached(_ stage: PacketBridgeLifecycleStage) -> Bool {
    lock.withLock { stages.contains(stage.rawValue) }
  }
}

private final class IntegrationPacketFlowDriver: PacketFlowPlatformDriver, @unchecked Sendable {
  struct WrittenPacket: Sendable {
    let payload: Data
    let protocolNumber: Int32
  }

  struct Snapshot: Sendable {
    let writtenPackets: [WrittenPacket]
    let queuedBatchCount: Int
    let outstandingReadCount: Int
    let maximumOutstandingReadCount: Int
  }

  private typealias ReadCallback = @Sendable ([Data], [Int32]) -> Void
  private let lock = NSLock()
  private let rejectWrites: Bool
  private var callback: ReadCallback?
  private var queuedBatches: [([Data], [Int32])] = []
  private var written: [WrittenPacket] = []
  private var maximumOutstandingReads = 0

  init(rejectWrites: Bool) {
    self.rejectWrites = rejectWrites
  }

  func registerRead(
    _ callback: @escaping @Sendable ([Data], [Int32]) -> Void
  ) {
    let queued: ([Data], [Int32])? = lock.withLock {
      precondition(self.callback == nil)
      if queuedBatches.isEmpty {
        self.callback = callback
        maximumOutstandingReads = max(maximumOutstandingReads, 1)
        return nil
      }
      return queuedBatches.removeFirst()
    }
    if let queued {
      callback(queued.0, queued.1)
    }
  }

  func writePackets(_ packets: [Data], protocols: [Int32]) -> Bool {
    lock.withLock {
      written.append(
        contentsOf: zip(packets, protocols).map {
          WrittenPacket(payload: $0.0, protocolNumber: $0.1)
        }
      )
    }
    return !rejectWrites
  }

  func deliver(_ packet: IPPacket) throws {
    try deliver(packets: [packet])
  }

  func deliver(repeating packet: IPPacket, count: Int) throws {
    try deliver(packets: Array(repeating: packet, count: count))
  }

  func deliver(packets: [IPPacket]) throws {
    guard !packets.isEmpty else { return }
    let callback: ReadCallback? = lock.withLock {
      let callback = self.callback
      self.callback = nil
      if callback == nil {
        queuedBatches.append(
          (packets.map(\.bytes), packets.map(\.family.protocolNumber))
        )
      }
      return callback
    }
    callback?(packets.map(\.bytes), packets.map(\.family.protocolNumber))
  }

  func releaseLateRead() {
    let callback = lock.withLock { () -> ReadCallback? in
      let callback = self.callback
      self.callback = nil
      return callback
    }
    callback?([], [])
  }

  func snapshot() -> Snapshot {
    lock.withLock {
      Snapshot(
        writtenPackets: written,
        queuedBatchCount: queuedBatches.count,
        outstandingReadCount: callback == nil ? 0 : 1,
        maximumOutstandingReadCount: maximumOutstandingReads
      )
    }
  }
}

private final class IntegrationSOCKSAdapter: HEVSOCKSConnectionAdapter, @unchecked Sendable {
  enum Mode: Sendable {
    case respond
    case stallAfterAuthentication
  }

  private let mode: Mode
  private let lock = NSLock()
  private var sessions: [IntegrationSOCKSSession] = []
  private var stalledChannels: [HEVSOCKSChannel] = []
  private var failures: [String] = []
  private var totalAccepted = 0

  init(mode: Mode) {
    self.mode = mode
  }

  var acceptedCount: Int {
    lock.withLock { totalAccepted }
  }

  var liveChannelCount: Int {
    lock.withLock { sessions.count + stalledChannels.count }
  }

  func acceptAuthenticatedConnection(_ channel: HEVSOCKSChannel) {
    switch mode {
    case .stallAfterAuthentication:
      lock.withLock {
        totalAccepted += 1
        stalledChannels.append(channel)
      }
    case .respond:
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        do {
          let request = try channel.withBorrowedDescriptor { descriptor in
            let request = try SOCKSRequest.read(from: descriptor)
            try sendAll(
              Data([5, 0, 0, 1, 0, 0, 0, 0, 0, 0]),
              descriptor: descriptor
            )
            return request
          }
          let session = IntegrationSOCKSSession(channel: channel, request: request)
          self?.lock.withLock {
            self?.totalAccepted += 1
            self?.sessions.append(session)
          }
        } catch {
          channel.close()
          self?.lock.withLock {
            self?.failures.append(String(describing: error))
          }
        }
      }
    }
  }

  func nextSession() async throws -> IntegrationSOCKSSession {
    let result: SessionResult = try await waitForValue(timeout: .seconds(5)) {
      self.lock.withLock {
        if !self.failures.isEmpty {
          return .failure(self.failures.removeFirst())
        }
        guard !self.sessions.isEmpty else { return nil }
        return .session(self.sessions.removeFirst())
      }
    }
    return try result.get()
  }

  func closeAll() {
    let channels = lock.withLock { () -> [HEVSOCKSChannel] in
      let channels = sessions.map(\.channel) + stalledChannels
      sessions.removeAll()
      stalledChannels.removeAll()
      return channels
    }
    for channel in channels {
      channel.close()
    }
  }
}

private enum SessionResult: Sendable {
  case session(IntegrationSOCKSSession)
  case failure(String)

  func get() throws -> IntegrationSOCKSSession {
    switch self {
    case .session(let session):
      return session
    case .failure(let message):
      throw IntegrationTestError.fixture(message)
    }
  }
}

private enum SOCKSCommand: UInt8, Sendable {
  case connect = 1
  case forwardUDP = 5
}

private struct SOCKSRequest: Sendable {
  let command: SOCKSCommand
  let address: Data
  let destinationPort: UInt16

  static func read(from descriptor: Int32) throws -> SOCKSRequest {
    let header = try receiveExactly(4, descriptor: descriptor)
    guard header[0] == 5, header[2] == 0, let command = SOCKSCommand(rawValue: header[1])
    else {
      throw IntegrationTestError.fixture("invalid SOCKS request header \(Array(header))")
    }
    let addressLength: Int
    switch header[3] {
    case 1: addressLength = 4
    case 4: addressLength = 16
    default:
      throw IntegrationTestError.fixture("unexpected SOCKS address type \(header[3])")
    }
    let address = try receiveExactly(addressLength, descriptor: descriptor)
    let port = try receiveExactly(2, descriptor: descriptor)
    return SOCKSRequest(
      command: command,
      address: address,
      destinationPort: readUInt16(port, at: 0)
    )
  }
}

private final class IntegrationSOCKSSession: @unchecked Sendable {
  struct UDPFrame: Sendable {
    let address: Data
    let port: UInt16
    let payload: Data
  }

  fileprivate let channel: HEVSOCKSChannel
  let request: SOCKSRequest

  init(channel: HEVSOCKSChannel, request: SOCKSRequest) {
    self.channel = channel
    self.request = request
  }

  func readExactly(_ count: Int) async throws -> Data {
    try await blockingIO {
      try self.channel.withBorrowedDescriptor {
        try receiveExactly(count, descriptor: $0)
      }
    }
  }

  func readEOF() async throws -> Bool {
    try await blockingIO {
      try self.channel.withBorrowedDescriptor { descriptor in
        var byte: UInt8 = 0
        while true {
          let result = Darwin.recv(descriptor, &byte, 1, 0)
          if result == 0 { return true }
          if result < 0, errno == EINTR { continue }
          if result < 0, errno == ECONNRESET { return true }
          if result < 0 {
            throw IntegrationTestError.systemCall("recv EOF", errno)
          }
          return false
        }
      }
    }
  }

  func write(_ data: Data) async throws {
    try await blockingIO {
      try self.channel.withBorrowedDescriptor {
        try sendAll(data, descriptor: $0)
      }
    }
  }

  func shutdownWrite() async throws {
    try await blockingIO {
      try self.channel.withBorrowedDescriptor { descriptor in
        guard Darwin.shutdown(descriptor, SHUT_WR) == 0 else {
          throw IntegrationTestError.systemCall("shutdown", errno)
        }
      }
    }
  }

  func readUDPFrame() async throws -> UDPFrame {
    let header = try await readExactly(3)
    let payloadLength = Int(readUInt16(header, at: 0))
    let headerLength = Int(header[2])
    guard headerLength >= 10 else {
      throw IntegrationTestError.fixture("invalid UDP-in-TCP header length \(headerLength)")
    }
    let addressPart = try await readExactly(headerLength - 3)
    let addressLength: Int
    switch addressPart[0] {
    case 1: addressLength = 4
    case 4: addressLength = 16
    default:
      throw IntegrationTestError.fixture("invalid UDP-in-TCP address type")
    }
    guard addressPart.count == 1 + addressLength + 2 else {
      throw IntegrationTestError.fixture("inconsistent UDP-in-TCP address length")
    }
    return UDPFrame(
      address: Data(addressPart[1..<(1 + addressLength)]),
      port: readUInt16(addressPart, at: 1 + addressLength),
      payload: try await readExactly(payloadLength)
    )
  }

  func writeUDPFrame(address: Data, port: UInt16, payload: Data) async throws {
    let addressType: UInt8
    switch address.count {
    case 4: addressType = 1
    case 16: addressType = 4
    default:
      throw IntegrationTestError.fixture("invalid UDP-in-TCP address length")
    }
    var frame = Data()
    appendUInt16(UInt16(payload.count), to: &frame)
    frame.append(UInt8(3 + 1 + address.count + 2))
    frame.append(addressType)
    frame.append(address)
    appendUInt16(port, to: &frame)
    frame.append(payload)
    try await write(frame)
  }

  func close() {
    channel.close()
  }
}

private struct IPPacket: Sendable {
  let bytes: Data
  let family: PacketAddressFamily
}

private struct TCPPeer: Sendable {
  let family: PacketAddressFamily
  let source: Data
  let destination: Data
  let sourcePort: UInt16
  let destinationPort: UInt16
  private(set) var clientSequence: UInt32
  private(set) var serverSequence: UInt32 = 0
  private(set) var writtenIndex = 0

  static func ipv4(
    source: [UInt8],
    destination: [UInt8],
    sourcePort: UInt16,
    destinationPort: UInt16,
    initialSequence: UInt32
  ) -> TCPPeer {
    TCPPeer(
      family: .ipv4,
      source: Data(source),
      destination: Data(destination),
      sourcePort: sourcePort,
      destinationPort: destinationPort,
      clientSequence: initialSequence
    )
  }

  static func ipv6(
    source: Data,
    destination: Data,
    sourcePort: UInt16,
    destinationPort: UInt16,
    initialSequence: UInt32
  ) -> TCPPeer {
    TCPPeer(
      family: .ipv6,
      source: source,
      destination: destination,
      sourcePort: sourcePort,
      destinationPort: destinationPort,
      clientSequence: initialSequence
    )
  }

  func synPacket() -> IPPacket {
    makeTCPPacket(flags: [.syn], sequence: clientSequence, acknowledgement: 0)
  }

  mutating func acceptSYNACK(from driver: IntegrationPacketFlowDriver) async throws {
    let sourcePort = self.sourcePort
    let destinationPort = self.destinationPort
    let match = try await nextSegment(from: driver) {
      $0.sourcePort == destinationPort && $0.destinationPort == sourcePort
        && $0.flags.contains(.syn) && $0.flags.contains(.ack)
    }
    writtenIndex = match.nextIndex
    guard match.segment.acknowledgement == clientSequence + 1 else {
      throw IntegrationTestError.fixture("invalid SYN-ACK acknowledgement")
    }
    clientSequence += 1
    serverSequence = match.segment.sequence + 1
  }

  func ackPacket() -> IPPacket {
    makeTCPPacket(flags: [.ack], sequence: clientSequence, acknowledgement: serverSequence)
  }

  mutating func dataPacket(_ payload: Data) -> IPPacket {
    defer { clientSequence += UInt32(payload.count) }
    return makeTCPPacket(
      flags: [.ack, .push],
      sequence: clientSequence,
      acknowledgement: serverSequence,
      payload: payload
    )
  }

  mutating func acceptPayload(
    _ expected: Data,
    from driver: IntegrationPacketFlowDriver
  ) async throws {
    let sourcePort = self.sourcePort
    let destinationPort = self.destinationPort
    let match = try await nextSegment(from: driver) {
      $0.sourcePort == destinationPort && $0.destinationPort == sourcePort
        && !$0.payload.isEmpty
    }
    writtenIndex = match.nextIndex
    guard match.segment.payload == expected else {
      throw IntegrationTestError.fixture(
        "TCP payload mismatch: \(match.segment.payload.count) != \(expected.count)"
      )
    }
    serverSequence = match.segment.sequence + UInt32(match.segment.payload.count)
  }

  mutating func finPacket() -> IPPacket {
    defer { clientSequence += 1 }
    return makeTCPPacket(
      flags: [.ack, .fin],
      sequence: clientSequence,
      acknowledgement: serverSequence
    )
  }

  mutating func acceptFIN(from driver: IntegrationPacketFlowDriver) async throws {
    let sourcePort = self.sourcePort
    let destinationPort = self.destinationPort
    let match = try await nextSegment(from: driver) {
      $0.sourcePort == destinationPort && $0.destinationPort == sourcePort
        && $0.flags.contains(.fin)
    }
    writtenIndex = match.nextIndex
    serverSequence = match.segment.sequence + UInt32(match.segment.payload.count) + 1
  }

  func resetPacket() -> IPPacket {
    makeTCPPacket(
      flags: [.ack, .reset],
      sequence: clientSequence,
      acknowledgement: serverSequence
    )
  }

  private func makeTCPPacket(
    flags: TCPFlags,
    sequence: UInt32,
    acknowledgement: UInt32,
    payload: Data = Data()
  ) -> IPPacket {
    makeTCPPacketBytes(
      family: family,
      source: source,
      destination: destination,
      sourcePort: sourcePort,
      destinationPort: destinationPort,
      sequence: sequence,
      acknowledgement: acknowledgement,
      flags: flags,
      payload: payload
    )
  }

  private func nextSegment(
    from driver: IntegrationPacketFlowDriver,
    matching predicate: @escaping @Sendable (ParsedTCPSegment) -> Bool
  ) async throws -> (segment: ParsedTCPSegment, nextIndex: Int) {
    try await waitForValue(timeout: .seconds(5)) {
      let written = driver.snapshot().writtenPackets
      guard self.writtenIndex < written.count else { return nil }
      for index in self.writtenIndex..<written.count {
        guard let segment = parseTCPSegment(written[index].payload), predicate(segment) else {
          continue
        }
        return (segment, index + 1)
      }
      return nil
    }
  }
}

private struct TCPFlags: OptionSet, Sendable {
  let rawValue: UInt8

  static let fin = TCPFlags(rawValue: 0x01)
  static let syn = TCPFlags(rawValue: 0x02)
  static let reset = TCPFlags(rawValue: 0x04)
  static let push = TCPFlags(rawValue: 0x08)
  static let ack = TCPFlags(rawValue: 0x10)
}

private struct ParsedTCPSegment: Sendable {
  let sourcePort: UInt16
  let destinationPort: UInt16
  let sequence: UInt32
  let acknowledgement: UInt32
  let flags: TCPFlags
  let payload: Data
}

private func makeTCPPacketBytes(
  family: PacketAddressFamily,
  source: Data,
  destination: Data,
  sourcePort: UInt16,
  destinationPort: UInt16,
  sequence: UInt32,
  acknowledgement: UInt32,
  flags: TCPFlags,
  payload: Data
) -> IPPacket {
  var tcp = Data(repeating: 0, count: 20)
  writeUInt16(sourcePort, into: &tcp, at: 0)
  writeUInt16(destinationPort, into: &tcp, at: 2)
  writeUInt32(sequence, into: &tcp, at: 4)
  writeUInt32(acknowledgement, into: &tcp, at: 8)
  tcp[12] = 5 << 4
  tcp[13] = flags.rawValue
  writeUInt16(32_768, into: &tcp, at: 14)
  tcp.append(payload)
  writeUInt16(
    transportChecksum(
      family: family,
      source: source,
      destination: destination,
      protocolNumber: UInt8(IPPROTO_TCP),
      payload: tcp
    ),
    into: &tcp,
    at: 16
  )
  return IPPacket(
    bytes: wrapIP(
      family: family,
      source: source,
      destination: destination,
      protocolNumber: UInt8(IPPROTO_TCP),
      payload: tcp
    ),
    family: family
  )
}

private func makeUDPPacket(
  family: PacketAddressFamily,
  source: Data,
  destination: Data,
  sourcePort: UInt16,
  destinationPort: UInt16,
  payload: Data
) -> IPPacket {
  var udp = Data(repeating: 0, count: 8)
  writeUInt16(sourcePort, into: &udp, at: 0)
  writeUInt16(destinationPort, into: &udp, at: 2)
  writeUInt16(UInt16(8 + payload.count), into: &udp, at: 4)
  udp.append(payload)
  writeUInt16(
    transportChecksum(
      family: family,
      source: source,
      destination: destination,
      protocolNumber: UInt8(IPPROTO_UDP),
      payload: udp
    ),
    into: &udp,
    at: 6
  )
  return IPPacket(
    bytes: wrapIP(
      family: family,
      source: source,
      destination: destination,
      protocolNumber: UInt8(IPPROTO_UDP),
      payload: udp
    ),
    family: family
  )
}

private func wrapIP(
  family: PacketAddressFamily,
  source: Data,
  destination: Data,
  protocolNumber: UInt8,
  payload: Data
) -> Data {
  switch family {
  case .ipv4:
    precondition(source.count == 4 && destination.count == 4)
    var header = Data(repeating: 0, count: 20)
    header[0] = 0x45
    writeUInt16(UInt16(header.count + payload.count), into: &header, at: 2)
    writeUInt16(0x4000, into: &header, at: 6)
    header[8] = 64
    header[9] = protocolNumber
    header.replaceSubrange(12..<16, with: source)
    header.replaceSubrange(16..<20, with: destination)
    writeUInt16(internetChecksum(header), into: &header, at: 10)
    header.append(payload)
    return header
  case .ipv6:
    precondition(source.count == 16 && destination.count == 16)
    var header = Data(repeating: 0, count: 40)
    header[0] = 0x60
    writeUInt16(UInt16(payload.count), into: &header, at: 4)
    header[6] = protocolNumber
    header[7] = 64
    header.replaceSubrange(8..<24, with: source)
    header.replaceSubrange(24..<40, with: destination)
    header.append(payload)
    return header
  }
}

private func transportChecksum(
  family: PacketAddressFamily,
  source: Data,
  destination: Data,
  protocolNumber: UInt8,
  payload: Data
) -> UInt16 {
  var pseudo = Data()
  pseudo.append(source)
  pseudo.append(destination)
  switch family {
  case .ipv4:
    pseudo.append(contentsOf: [0, protocolNumber])
    appendUInt16(UInt16(payload.count), to: &pseudo)
  case .ipv6:
    appendUInt32(UInt32(payload.count), to: &pseudo)
    pseudo.append(contentsOf: [0, 0, 0, protocolNumber])
  }
  pseudo.append(payload)
  return internetChecksum(pseudo)
}

private func internetChecksum(_ data: Data) -> UInt16 {
  var sum: UInt32 = 0
  var index = 0
  while index + 1 < data.count {
    sum += UInt32(data[index]) << 8 | UInt32(data[index + 1])
    index += 2
  }
  if index < data.count {
    sum += UInt32(data[index]) << 8
  }
  while sum > 0xffff {
    sum = (sum & 0xffff) + (sum >> 16)
  }
  return ~UInt16(sum)
}

private func parseTCPSegment(_ packet: Data) -> ParsedTCPSegment? {
  guard let first = packet.first else { return nil }
  let version = first >> 4
  let offset: Int
  let protocolNumber: UInt8
  if version == 4 {
    guard packet.count >= 20 else { return nil }
    offset = Int(first & 0x0f) * 4
    protocolNumber = packet[9]
  } else if version == 6 {
    guard packet.count >= 40 else { return nil }
    offset = 40
    protocolNumber = packet[6]
  } else {
    return nil
  }
  guard protocolNumber == UInt8(IPPROTO_TCP), packet.count >= offset + 20 else {
    return nil
  }
  let tcpHeaderLength = Int(packet[offset + 12] >> 4) * 4
  guard tcpHeaderLength >= 20, packet.count >= offset + tcpHeaderLength else {
    return nil
  }
  return ParsedTCPSegment(
    sourcePort: readUInt16(packet, at: offset),
    destinationPort: readUInt16(packet, at: offset + 2),
    sequence: readUInt32(packet, at: offset + 4),
    acknowledgement: readUInt32(packet, at: offset + 8),
    flags: TCPFlags(rawValue: packet[offset + 13]),
    payload: Data(packet[(offset + tcpHeaderLength)...])
  )
}

private func ipv6Address(lastWord: UInt16) -> Data {
  var bytes = Data([0x20, 0x01, 0x0d, 0xb8] + Array(repeating: 0, count: 12))
  writeUInt16(lastWord, into: &bytes, at: 14)
  return bytes
}

extension PacketAddressFamily {
  fileprivate var protocolNumber: Int32 {
    self == .ipv4 ? AF_INET : AF_INET6
  }
}

private func connectToLoopback(port: UInt16) throws -> Int32 {
  let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
  guard descriptor >= 0 else {
    throw IntegrationTestError.systemCall("socket", errno)
  }
  var address = sockaddr_in()
  address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
  address.sin_family = sa_family_t(AF_INET)
  address.sin_port = port.bigEndian
  address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
  let result = withUnsafePointer(to: &address) { pointer in
    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  guard result == 0 else {
    let code = errno
    Darwin.close(descriptor)
    throw IntegrationTestError.systemCall("connect", code)
  }
  return descriptor
}

private func sendAll(_ data: Data, descriptor: Int32) throws {
  var offset = 0
  while offset < data.count {
    let sent = data.withUnsafeBytes {
      Darwin.send(descriptor, $0.baseAddress! + offset, data.count - offset, 0)
    }
    if sent > 0 {
      offset += sent
    } else if sent < 0, errno == EINTR {
      continue
    } else {
      throw IntegrationTestError.systemCall("send", errno)
    }
  }
}

private func receiveExactly(_ count: Int, descriptor: Int32) throws -> Data {
  var data = Data(repeating: 0, count: count)
  var offset = 0
  while offset < count {
    let received = data.withUnsafeMutableBytes {
      Darwin.recv(descriptor, $0.baseAddress! + offset, count - offset, 0)
    }
    if received > 0 {
      offset += received
    } else if received < 0, errno == EINTR {
      continue
    } else {
      throw IntegrationTestError.systemCall("recv", received == 0 ? ECONNRESET : errno)
    }
  }
  return data
}

private func blockingIO<T: Sendable>(
  _ operation: @escaping @Sendable () throws -> T
) async throws -> T {
  try await withCheckedThrowingContinuation { continuation in
    DispatchQueue.global(qos: .userInitiated).async {
      continuation.resume(with: Result { try operation() })
    }
  }
}

private func waitForValue<T: Sendable>(
  timeout: Duration = .seconds(3),
  _ operation: @escaping @Sendable () -> T?
) async throws -> T {
  let clock = ContinuousClock()
  let deadline = clock.now.advanced(by: timeout)
  while clock.now < deadline {
    if let value = operation() { return value }
    try await Task.sleep(for: .milliseconds(2))
  }
  throw IntegrationTestError.timeout
}

private func eventually(
  timeout: Duration = .seconds(3),
  _ operation: @escaping @Sendable () async -> Bool
) async -> Bool {
  let clock = ContinuousClock()
  let deadline = clock.now.advanced(by: timeout)
  while clock.now < deadline {
    if await operation() { return true }
    try? await Task.sleep(for: .milliseconds(2))
  }
  return await operation()
}

private func openDescriptorCount() -> Int {
  let upperBound = getdtablesize()
  return (0..<upperBound).reduce(into: 0) { count, descriptor in
    errno = 0
    if fcntl(descriptor, F_GETFD) >= 0 || errno != EBADF {
      count += 1
    }
  }
}

private actor IntegrationMetrics: TunnelMetrics {
  private var counters: [String: UInt64] = [:]
  private var gauges: [String: Int64] = [:]

  func incrementCounter(named name: String, by amount: UInt64) {
    counters[name, default: 0] += amount
  }

  func setGauge(named name: String, to value: Int64) {
    gauges[name] = value
  }

  func snapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(schemaVersion: 1, counters: counters, gauges: gauges)
  }
}

private struct IntegrationLogger: TunnelLogger {
  func log(
    level: TunnelLogLevel,
    message: String,
    fields: [String: TunnelLogField]
  ) {}
}

private enum IntegrationTestError: Error, CustomStringConvertible {
  case fixture(String)
  case systemCall(String, Int32)
  case timeout

  var description: String {
    switch self {
    case .fixture(let message):
      return message
    case .systemCall(let operation, let code):
      return "\(operation) failed with errno \(code)"
    case .timeout:
      return "timed out waiting for integration event"
    }
  }
}

private func appendUInt16(_ value: UInt16, to data: inout Data) {
  data.append(UInt8(truncatingIfNeeded: value >> 8))
  data.append(UInt8(truncatingIfNeeded: value))
}

private func appendUInt32(_ value: UInt32, to data: inout Data) {
  data.append(UInt8(truncatingIfNeeded: value >> 24))
  data.append(UInt8(truncatingIfNeeded: value >> 16))
  data.append(UInt8(truncatingIfNeeded: value >> 8))
  data.append(UInt8(truncatingIfNeeded: value))
}

private func writeUInt16(_ value: UInt16, into data: inout Data, at index: Int) {
  data[index] = UInt8(truncatingIfNeeded: value >> 8)
  data[index + 1] = UInt8(truncatingIfNeeded: value)
}

private func writeUInt32(_ value: UInt32, into data: inout Data, at index: Int) {
  data[index] = UInt8(truncatingIfNeeded: value >> 24)
  data[index + 1] = UInt8(truncatingIfNeeded: value >> 16)
  data[index + 2] = UInt8(truncatingIfNeeded: value >> 8)
  data[index + 3] = UInt8(truncatingIfNeeded: value)
}

private func readUInt16(_ data: Data, at index: Int) -> UInt16 {
  UInt16(data[index]) << 8 | UInt16(data[index + 1])
}

private func readUInt32(_ data: Data, at index: Int) -> UInt32 {
  UInt32(data[index]) << 24 | UInt32(data[index + 1]) << 16
    | UInt32(data[index + 2]) << 8 | UInt32(data[index + 3])
}
