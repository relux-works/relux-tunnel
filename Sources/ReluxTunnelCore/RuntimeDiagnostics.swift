import Foundation
import Synchronization

/// Stable component categories used by the aggregate health gauges.
///
/// The schema intentionally has no component instance, lane, flow, endpoint,
/// or request identifiers.
public enum RuntimeDiagnosticComponent: String, CaseIterable, Sendable {
  case coordinator
  case packetBridge
  case hev
  case ssh
  case tcp
  case dns
  case route
}

/// Numeric values stored in the component health gauges.
public enum RuntimeDiagnosticHealth: Int64, Sendable {
  case unknown = 0
  case healthy = 1
  case unhealthy = 2
}

/// Finite queue-drop reasons. No free-form label enters the snapshot.
public enum RuntimeQueueDropReason: String, CaseIterable, Sendable {
  case packetForwardMalformed
  case packetForwardWouldBlock
  case packetForwardNoBuffer
  case packetReverseMalformed
  case packetReverseWriteRejected
  case tcpAdmissionLimit
  case tcpQueuedByteLimit
  case dnsQueueFull
}

/// Privacy-safe DNS outcome classes. Query names and resolver endpoints are not accepted.
public enum RuntimeDNSResultClass: String, CaseIterable, Sendable {
  case success
  case noData
  case nameError
  case serverFailure
  case refused
  case timeout
  case malformed
  case otherFailure
}

/// Reviewed finite errors that diagnostics producers may publish.
///
/// The raw values are stable wire tokens. The associated domain is fixed here,
/// so an adapter cannot create a new label or attach a code to another domain.
public enum RuntimeDiagnosticErrorCode: String, CaseIterable, Sendable {
  case configurationInvalid = "configuration_invalid"
  case sshTrustRejected = "ssh_trust_rejected"
  case sshCredentialRejected = "ssh_credential_rejected"
  case sshSessionLost = "ssh_session_lost"
  case tcpFlowFailed = "tcp_flow_failed"
  case dnsUpstreamTimeout = "dns_upstream_timeout"
  case packetPlaneFailed = "packet_plane_failed"
  case networkSettingsApplyFailed = "network_settings_apply_failed"
  case runtimeInvariantViolated = "runtime_invariant_violated"
  case cleanupDeadlineExceeded = "cleanup_deadline_exceeded"
  case protocolUnsupported = "protocol_unsupported"

  public var domain: RuntimeErrorDomain {
    switch self {
    case .configurationInvalid: .configuration
    case .sshTrustRejected: .sshTrust
    case .sshCredentialRejected: .sshCredential
    case .sshSessionLost: .sshTransport
    case .tcpFlowFailed: .tcp
    case .dnsUpstreamTimeout: .dns
    case .packetPlaneFailed: .packetPlane
    case .networkSettingsApplyFailed: .networkSettings
    case .runtimeInvariantViolated, .cleanupDeadlineExceeded: .runtimeInvariant
    case .protocolUnsupported: .protocol
    }
  }

  fileprivate init?(_ error: RedactedRuntimeError) {
    guard
      let code = Self.allCases.first(where: {
        $0.domain == error.domain && $0.rawValue == error.code.rawValue
      })
    else { return nil }
    self = code
  }

  fileprivate var redactedError: RedactedRuntimeError {
    guard let code = try? RedactedRuntimeErrorCode(rawValue) else {
      preconditionFailure("Runtime diagnostic error catalog contains an invalid token")
    }
    return RedactedRuntimeError(domain: domain, code: code)
  }
}

public enum RuntimeDiagnosticsStoreError: Error, Equatable, Sendable {
  case generationMustIncrease(current: UInt64, proposed: UInt64)
  case snapshotSequenceExhausted(runtimeGeneration: UInt64)
}

/// The complete schema emitted by `RuntimeDiagnosticsStore`.
///
/// All names are finite, process-independent tokens. Updates with any other
/// name are counted and discarded without retaining the supplied name.
public enum RuntimeDiagnosticsSchema {
  public static let version = RuntimeMessageProtocol.currentSchemaVersion
  public static let maximumPendingUpdates = 256
  public static let maximumErrors = RuntimeErrorDomain.allCases.count
  public static let errorCodes = RuntimeDiagnosticErrorCode.allCases
  public static let dnsLatencyBucketUpperBoundsMilliseconds: [UInt64] = [
    1, 5, 10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000, UInt64.max,
  ]

  public static let counterNames: [String] = {
    let local = [
      "coordinator_transition_disconnected_total",
      "coordinator_transition_connecting_total",
      "coordinator_transition_connected_full_total",
      "coordinator_transition_connected_degraded_total",
      "coordinator_transition_reasserting_total",
      "coordinator_transition_failed_total",
      "coordinator_transition_disconnecting_total",
      "coordinator_transition_unknown_total",
      "diagnostics_ingestion_drop_total",
      "diagnostics_rejected_metric_update_total",
      "provider_cleanup_deadline_exceeded_total",
      "memory_sample_total",
      "hev_start_total",
      "hev_startup_failure_total",
      "hev_stop_request_total",
      "hev_main_return_total",
      "hev_main_failure_total",
      "tcp_flows_opened_total",
      "tcp_flows_closed_total",
      "tcp_bytes_sent_total",
      "tcp_bytes_received_total",
      "tcp_drop_admission_limit_total",
      "tcp_drop_queued_byte_limit_total",
      "dns_result_success_total",
      "dns_result_no_data_total",
      "dns_result_name_error_total",
      "dns_result_server_failure_total",
      "dns_result_refused_total",
      "dns_result_timeout_total",
      "dns_result_malformed_total",
      "dns_result_other_failure_total",
      "dns_drop_queue_full_total",
    ]
    let ssh = SSHMetricCounter.allCases.map(RuntimeDiagnosticsMetricMap.name)
    return Array(Set(local + PacketBridgeMetricSchema.counters.keys + ssh)).sorted()
  }()

  public static let gaugeNames: [String] = {
    let local = [
      "coordinator_transition_disconnected_uptime_milliseconds",
      "coordinator_transition_connecting_uptime_milliseconds",
      "coordinator_transition_connected_full_uptime_milliseconds",
      "coordinator_transition_connected_degraded_uptime_milliseconds",
      "coordinator_transition_reasserting_uptime_milliseconds",
      "coordinator_transition_failed_uptime_milliseconds",
      "coordinator_transition_disconnecting_uptime_milliseconds",
      "coordinator_transition_unknown_uptime_milliseconds",
      "component_coordinator_health_code",
      "component_packet_bridge_health_code",
      "component_hev_health_code",
      "component_ssh_health_code",
      "component_tcp_health_code",
      "component_dns_health_code",
      "component_route_health_code",
      "route_mode_compatible",
      "route_mode_unknown",
      "route_installed",
      "provider_stop_reason_code",
      "memory_physical_footprint_bytes",
      "memory_physical_footprint_peak_bytes",
      "memory_available_bytes",
      "memory_available_min_bytes",
      "hev_configured_mtu_bytes",
      "hev_configured_task_stack_size_bytes",
      "hev_configured_tcp_buffer_size_bytes",
      "hev_configured_udp_copy_buffer_count",
      "hev_configured_maximum_session_count",
      "hev_transmitted_packets",
      "hev_transmitted_bytes",
      "hev_received_packets",
      "hev_received_bytes",
      "tcp_active_flows",
      "tcp_peak_flows",
    ]
    let ssh = SSHMetricGauge.allCases.map(RuntimeDiagnosticsMetricMap.name)
    return Array(Set(local + PacketBridgeMetricSchema.gauges.keys + ssh)).sorted()
  }()

  public static let histogramNames = ["dns_latency_milliseconds"]

  fileprivate static let counterNameSet = Set(counterNames)
  fileprivate static let gaugeNameSet = Set(gaugeNames)
}

/// One generation-scoped update handle.
///
/// A handle from an older generation becomes a no-op after the store advances,
/// preventing late packet or SSH callbacks from contaminating the next run.
public final class RuntimeDiagnosticsRecorder: @unchecked Sendable, TunnelMetrics,
  SSHTransportMetricsSink
{
  public let runtimeGeneration: UInt64

  private let store: RuntimeDiagnosticsStore
  private let droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter

  fileprivate init(
    store: RuntimeDiagnosticsStore,
    runtimeGeneration: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    self.store = store
    self.runtimeGeneration = runtimeGeneration
    self.droppedUpdates = droppedUpdates
  }

  public func incrementCounter(named name: String, by amount: UInt64) async {
    guard RuntimeDiagnosticsSchema.counterNameSet.contains(name) else {
      store.rejectUpdate(generation: runtimeGeneration, droppedUpdates: droppedUpdates)
      return
    }
    store.incrementCounter(
      name,
      by: amount,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }

  public func setGauge(named name: String, to value: Int64) async {
    guard value >= 0, RuntimeDiagnosticsSchema.gaugeNameSet.contains(name) else {
      store.rejectUpdate(generation: runtimeGeneration, droppedUpdates: droppedUpdates)
      return
    }
    store.setGauge(
      name,
      to: value,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }

  public func snapshot() async -> TunnelMetricsSnapshot {
    await store.metricsSnapshot(generation: runtimeGeneration)
  }

  public func record(_ update: SSHMetricUpdate) async {
    switch update {
    case .increment(let counter, let amount):
      store.incrementCounter(
        RuntimeDiagnosticsMetricMap.name(counter),
        by: amount,
        generation: runtimeGeneration,
        droppedUpdates: droppedUpdates
      )
    case .set(let gauge, let value):
      store.setGauge(
        RuntimeDiagnosticsMetricMap.name(gauge),
        to: value,
        generation: runtimeGeneration,
        droppedUpdates: droppedUpdates
      )
    }
  }

  public func recordStateTransition(
    to state: TunnelLifecycleState,
    atUptimeMilliseconds: UInt64
  ) {
    store.recordStateTransition(
      to: state,
      atUptimeMilliseconds: atUptimeMilliseconds,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }

  public func recordHealth(
    _ health: RuntimeDiagnosticHealth,
    for component: RuntimeDiagnosticComponent
  ) {
    store.setGauge(
      RuntimeDiagnosticsMetricMap.healthGauge(component),
      to: health.rawValue,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }

  public func recordQueueDrop(_ reason: RuntimeQueueDropReason, by amount: UInt64 = 1) {
    store.incrementCounter(
      RuntimeDiagnosticsMetricMap.dropCounter(reason),
      by: amount,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }

  public func recordTCPFlowOpened() {
    store.recordTCPFlowOpened(generation: runtimeGeneration, droppedUpdates: droppedUpdates)
  }

  public func recordTCPFlowClosed() {
    store.recordTCPFlowClosed(generation: runtimeGeneration, droppedUpdates: droppedUpdates)
  }

  public func recordTCPBytes(sent: UInt64, received: UInt64) {
    store.incrementCounter(
      "tcp_bytes_sent_total",
      by: sent,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
    store.incrementCounter(
      "tcp_bytes_received_total",
      by: received,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }

  public func recordDNSResult(
    _ result: RuntimeDNSResultClass,
    latencyMilliseconds: UInt64
  ) {
    store.recordDNSResult(
      result,
      latencyMilliseconds: latencyMilliseconds,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }

  public func recordRoute(mode: RuntimeRouteMode, installed: Bool) {
    store.recordRoute(
      mode: mode,
      installed: installed,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }

  public func recordMemorySample(
    physicalFootprintBytes: UInt64,
    availableMemoryBytes: UInt64
  ) {
    store.recordMemorySample(
      physicalFootprintBytes: physicalFootprintBytes,
      availableMemoryBytes: availableMemoryBytes,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }

  public func recordError(_ code: RuntimeDiagnosticErrorCode) {
    store.recordError(code, generation: runtimeGeneration, droppedUpdates: droppedUpdates)
  }

  /// Compatibility boundary for callers holding a decoded runtime error.
  /// Unknown or domain-mismatched codes are counted and discarded before enqueue.
  public func recordError(_ error: RedactedRuntimeError) {
    guard let code = RuntimeDiagnosticErrorCode(error) else {
      store.rejectUpdate(generation: runtimeGeneration, droppedUpdates: droppedUpdates)
      return
    }
    recordError(code)
  }

  public func clearError(domain: RuntimeErrorDomain) {
    store.clearError(
      domain: domain,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }
}

extension RuntimeDiagnosticsRecorder: ProviderLifecycleDiagnosticsSink {
  public func recordProviderStopReason(rawValue: Int) {
    store.setGauge(
      "provider_stop_reason_code",
      to: Int64(clamping: rawValue),
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
  }

  public func recordProviderCleanupDeadlineExceeded() {
    store.incrementCounter(
      "provider_cleanup_deadline_exceeded_total",
      by: 1,
      generation: runtimeGeneration,
      droppedUpdates: droppedUpdates
    )
    recordError(.cleanupDeadlineExceeded)
  }
}

/// Generation-scoped counter used when the bounded ingestion lane is full.
/// Each generation gets a distinct instance so stale recorders cannot label a
/// newer generation's aggregate.
private final class RuntimeDiagnosticsDroppedUpdateCounter: Sendable {
  let value = Atomic<UInt64>(0)

  func increment() {
    var current = value.load(ordering: .relaxed)
    while current < UInt64.max {
      let result = value.compareExchange(
        expected: current,
        desired: current + 1,
        ordering: .relaxed
      )
      guard !result.exchanged else { return }
      current = result.original
    }
  }
}

/// Fixed-size aggregate state shared by runtime layers.
///
/// Component calls reserve one of a fixed number of pending slots without
/// waiting and enqueue a typed value on the private diagnostics lane. Snapshot
/// construction is serialized on that lane, so it cannot hold a lock needed by
/// packet or SSH executors. Callers encode the immutable result after the lane
/// has been released.
public final class RuntimeDiagnosticsStore: @unchecked Sendable {
  private enum Update: Sendable {
    case incrementCounter(String, UInt64, UInt64)
    case setGauge(String, Int64, UInt64)
    case stateTransition(TunnelLifecycleState, UInt64, UInt64)
    case tcpFlowOpened(UInt64)
    case tcpFlowClosed(UInt64)
    case dnsResult(RuntimeDNSResultClass, UInt64, UInt64)
    case route(RuntimeRouteMode, Bool, UInt64)
    case memory(UInt64, UInt64, UInt64)
    case error(RuntimeDiagnosticErrorCode, UInt64)
    case clearError(RuntimeErrorDomain, UInt64)
    case rejected(UInt64)

    var generation: UInt64 {
      switch self {
      case .incrementCounter(_, _, let generation),
        .setGauge(_, _, let generation),
        .stateTransition(_, _, let generation),
        .dnsResult(_, _, let generation),
        .route(_, _, let generation),
        .memory(_, _, let generation):
        generation
      case .tcpFlowOpened(let generation), .tcpFlowClosed(let generation),
        .error(_, let generation), .clearError(_, let generation),
        .rejected(let generation):
        generation
      }
    }
  }

  private struct State {
    var runtimeGeneration: UInt64
    var nextSnapshotSequence: UInt64?
    var counters = Dictionary(
      uniqueKeysWithValues: RuntimeDiagnosticsSchema.counterNames.map { ($0, UInt64.zero) }
    )
    var gauges = Dictionary(
      uniqueKeysWithValues: RuntimeDiagnosticsSchema.gaugeNames.map { ($0, Int64.zero) }
    )
    var dnsLatencyCounts = Array(
      repeating: UInt64.zero,
      count: RuntimeDiagnosticsSchema.dnsLatencyBucketUpperBoundsMilliseconds.count
    )
    var errors: [RuntimeErrorDomain: RuntimeDiagnosticErrorCode] = [:]
    var hasAvailableMemorySample = false
    let droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter

    init(
      runtimeGeneration: UInt64,
      nextSnapshotSequence: UInt64 = 0,
      droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter = .init()
    ) {
      self.runtimeGeneration = runtimeGeneration
      self.nextSnapshotSequence = nextSnapshotSequence
      self.droppedUpdates = droppedUpdates
    }
  }

  private let stateQueue = DispatchQueue(label: "works.relux.runtime-diagnostics")
  private let pendingUpdateSlots = DispatchSemaphore(
    value: RuntimeDiagnosticsSchema.maximumPendingUpdates
  )
  private let snapshotRequestSlot = DispatchSemaphore(value: 1)
  private let snapshotConstructionHook: (@Sendable () -> Void)?
  private var state: State

  public convenience init(runtimeGeneration: UInt64) {
    self.init(
      runtimeGeneration: runtimeGeneration,
      initialSnapshotSequenceForTesting: 0,
      snapshotConstructionHook: nil
    )
  }

  internal init(
    runtimeGeneration: UInt64,
    initialSnapshotSequenceForTesting: UInt64,
    snapshotConstructionHook: (@Sendable () -> Void)?
  ) {
    state = State(
      runtimeGeneration: runtimeGeneration,
      nextSnapshotSequence: initialSnapshotSequenceForTesting
    )
    self.snapshotConstructionHook = snapshotConstructionHook
  }

  public func recorder() -> RuntimeDiagnosticsRecorder {
    stateQueue.sync {
      RuntimeDiagnosticsRecorder(
        store: self,
        runtimeGeneration: state.runtimeGeneration,
        droppedUpdates: state.droppedUpdates
      )
    }
  }

  /// Advances to a strictly newer generation and drops all prior aggregates.
  public func beginGeneration(_ runtimeGeneration: UInt64) throws
    -> RuntimeDiagnosticsRecorder
  {
    try stateQueue.sync {
      guard runtimeGeneration > state.runtimeGeneration else {
        throw RuntimeDiagnosticsStoreError.generationMustIncrease(
          current: state.runtimeGeneration,
          proposed: runtimeGeneration
        )
      }
      state = State(runtimeGeneration: runtimeGeneration)
      return RuntimeDiagnosticsRecorder(
        store: self,
        runtimeGeneration: runtimeGeneration,
        droppedUpdates: state.droppedUpdates
      )
    }
  }

  /// Returns one immutable, self-consistent snapshot without polling any component.
  public func snapshot(
    requestID: OpaqueRuntimeRequestIdentifier? = nil
  ) throws -> RuntimeDiagnosticsSnapshot {
    snapshotRequestSlot.wait()
    defer { snapshotRequestSlot.signal() }
    return try stateQueue.sync {
      mergeDroppedUpdates()
      snapshotConstructionHook?()
      guard let sequence = state.nextSnapshotSequence else {
        throw RuntimeDiagnosticsStoreError.snapshotSequenceExhausted(
          runtimeGeneration: state.runtimeGeneration
        )
      }
      state.nextSnapshotSequence = sequence == UInt64.max ? nil : sequence + 1
      let buckets = zip(
        RuntimeDiagnosticsSchema.dnsLatencyBucketUpperBoundsMilliseconds,
        state.dnsLatencyCounts
      ).map(RuntimeDiagnosticBucket.init)
      return RuntimeDiagnosticsSnapshot(
        requestID: requestID,
        runtimeGeneration: state.runtimeGeneration,
        snapshotSequence: sequence,
        counters: state.counters,
        gauges: state.gauges,
        histograms: [
          "dns_latency_milliseconds": RuntimeDiagnosticHistogram(
            unit: .milliseconds,
            buckets: buckets
          )
        ],
        errors: state.errors.values
          .map(\.redactedError)
          .sorted { $0.domain.rawValue < $1.domain.rawValue }
      )
    }
  }

  fileprivate func incrementCounter(
    _ name: String,
    by amount: UInt64,
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    guard amount > 0 else { return }
    enqueue(.incrementCounter(name, amount, generation), droppedUpdates: droppedUpdates)
  }

  fileprivate func setGauge(
    _ name: String,
    to value: Int64,
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    enqueue(.setGauge(name, value, generation), droppedUpdates: droppedUpdates)
  }

  fileprivate func recordStateTransition(
    to lifecycleState: TunnelLifecycleState,
    atUptimeMilliseconds: UInt64,
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    enqueue(
      .stateTransition(lifecycleState, atUptimeMilliseconds, generation),
      droppedUpdates: droppedUpdates
    )
  }

  fileprivate func recordTCPFlowOpened(
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    enqueue(.tcpFlowOpened(generation), droppedUpdates: droppedUpdates)
  }

  fileprivate func recordTCPFlowClosed(
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    enqueue(.tcpFlowClosed(generation), droppedUpdates: droppedUpdates)
  }

  fileprivate func recordDNSResult(
    _ result: RuntimeDNSResultClass,
    latencyMilliseconds: UInt64,
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    enqueue(
      .dnsResult(result, latencyMilliseconds, generation),
      droppedUpdates: droppedUpdates
    )
  }

  fileprivate func recordRoute(
    mode: RuntimeRouteMode,
    installed: Bool,
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    enqueue(.route(mode, installed, generation), droppedUpdates: droppedUpdates)
  }

  fileprivate func recordMemorySample(
    physicalFootprintBytes: UInt64,
    availableMemoryBytes: UInt64,
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    enqueue(
      .memory(physicalFootprintBytes, availableMemoryBytes, generation),
      droppedUpdates: droppedUpdates
    )
  }

  fileprivate func recordError(
    _ code: RuntimeDiagnosticErrorCode,
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    enqueue(.error(code, generation), droppedUpdates: droppedUpdates)
  }

  fileprivate func clearError(
    domain: RuntimeErrorDomain,
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    enqueue(.clearError(domain, generation), droppedUpdates: droppedUpdates)
  }

  fileprivate func rejectUpdate(
    generation: UInt64,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    enqueue(.rejected(generation), droppedUpdates: droppedUpdates)
  }

  fileprivate func metricsSnapshot(generation: UInt64) async -> TunnelMetricsSnapshot {
    await withCheckedContinuation { continuation in
      guard pendingUpdateSlots.wait(timeout: .now()) == .success else {
        continuation.resume(returning: Self.emptyMetricsSnapshot())
        return
      }
      stateQueue.async { [self] in
        defer { pendingUpdateSlots.signal() }
        mergeDroppedUpdates()
        guard generation == state.runtimeGeneration else {
          continuation.resume(returning: Self.emptyMetricsSnapshot())
          return
        }
        continuation.resume(
          returning: TunnelMetricsSnapshot(
            schemaVersion: RuntimeDiagnosticsSchema.version,
            counters: state.counters,
            gauges: state.gauges
          )
        )
      }
    }
  }

  private func enqueue(
    _ update: Update,
    droppedUpdates: RuntimeDiagnosticsDroppedUpdateCounter
  ) {
    guard pendingUpdateSlots.wait(timeout: .now()) == .success else {
      droppedUpdates.increment()
      return
    }
    stateQueue.async { [self] in
      defer { pendingUpdateSlots.signal() }
      guard update.generation == state.runtimeGeneration else { return }
      apply(update)
    }
  }

  private func apply(_ update: Update) {
    switch update {
    case .incrementCounter(let name, let amount, _):
      incrementKnownCounter(name, by: amount)
    case .setGauge(let name, let value, _):
      applyGauge(name, value: value)
    case .stateTransition(let lifecycleState, let uptime, _):
      incrementKnownCounter(RuntimeDiagnosticsMetricMap.transitionCounter(lifecycleState), by: 1)
      let timeGauge = RuntimeDiagnosticsMetricMap.transitionTimeGauge(lifecycleState)
      state.gauges[timeGauge] = max(state.gauges[timeGauge] ?? 0, clampedInt64(uptime))
    case .tcpFlowOpened:
      incrementKnownCounter("tcp_flows_opened_total", by: 1)
      let current = state.gauges["tcp_active_flows"] ?? 0
      let active = current == Int64.max ? Int64.max : current + 1
      state.gauges["tcp_active_flows"] = active
      state.gauges["tcp_peak_flows"] = max(state.gauges["tcp_peak_flows"] ?? 0, active)
    case .tcpFlowClosed:
      let active = state.gauges["tcp_active_flows"] ?? 0
      guard active > 0 else {
        incrementKnownCounter("diagnostics_rejected_metric_update_total", by: 1)
        return
      }
      state.gauges["tcp_active_flows"] = active - 1
      incrementKnownCounter("tcp_flows_closed_total", by: 1)
    case .dnsResult(let result, let latency, _):
      incrementKnownCounter(RuntimeDiagnosticsMetricMap.dnsResultCounter(result), by: 1)
      for index in state.dnsLatencyCounts.indices
      where latency <= RuntimeDiagnosticsSchema.dnsLatencyBucketUpperBoundsMilliseconds[index] {
        state.dnsLatencyCounts[index] = state.dnsLatencyCounts[index].saturatingAdding(1)
      }
    case .route(let mode, let installed, _):
      state.gauges["route_mode_compatible"] = mode == .compatible ? 1 : 0
      state.gauges["route_mode_unknown"] = mode == .unknown ? 1 : 0
      state.gauges["route_installed"] = installed ? 1 : 0
    case .memory(let physicalFootprintBytes, let availableMemoryBytes, _):
      let footprint = clampedInt64(physicalFootprintBytes)
      let available = clampedInt64(availableMemoryBytes)
      incrementKnownCounter("memory_sample_total", by: 1)
      state.gauges["memory_physical_footprint_bytes"] = footprint
      state.gauges["memory_physical_footprint_peak_bytes"] = max(
        state.gauges["memory_physical_footprint_peak_bytes"] ?? 0,
        footprint
      )
      state.gauges["memory_available_bytes"] = available
      state.gauges["memory_available_min_bytes"] =
        state.hasAvailableMemorySample
        ? min(state.gauges["memory_available_min_bytes"] ?? available, available)
        : available
      state.hasAvailableMemorySample = true
    case .error(let code, _):
      state.errors[code.domain] = code
    case .clearError(let domain, _):
      state.errors.removeValue(forKey: domain)
    case .rejected:
      incrementKnownCounter("diagnostics_rejected_metric_update_total", by: 1)
    }
  }

  private func applyGauge(_ name: String, value: Int64) {
    switch name {
    case "packet_bridge_forward_datagram_max_bytes",
      "packet_bridge_reverse_datagram_max_bytes",
      "memory_physical_footprint_peak_bytes",
      "tcp_peak_flows",
      "hev_transmitted_packets",
      "hev_transmitted_bytes",
      "hev_received_packets",
      "hev_received_bytes":
      state.gauges[name] = max(state.gauges[name] ?? 0, value)
    case "memory_available_min_bytes":
      if state.hasAvailableMemorySample {
        state.gauges[name] = min(state.gauges[name] ?? value, value)
      } else {
        state.gauges[name] = value
        state.hasAvailableMemorySample = true
      }
    default:
      state.gauges[name] = value
    }
  }

  private func mergeDroppedUpdates() {
    let dropped = state.droppedUpdates.value.exchange(0, ordering: .relaxed)
    incrementKnownCounter("diagnostics_ingestion_drop_total", by: dropped)
  }

  private func incrementKnownCounter(_ name: String, by amount: UInt64) {
    state.counters[name] = (state.counters[name] ?? 0).saturatingAdding(amount)
  }

  private func clampedInt64(_ value: UInt64) -> Int64 {
    value > UInt64(Int64.max) ? Int64.max : Int64(value)
  }

  private static func emptyMetricsSnapshot() -> TunnelMetricsSnapshot {
    TunnelMetricsSnapshot(
      schemaVersion: RuntimeDiagnosticsSchema.version,
      counters: Dictionary(
        uniqueKeysWithValues: RuntimeDiagnosticsSchema.counterNames.map { ($0, 0) }
      ),
      gauges: Dictionary(
        uniqueKeysWithValues: RuntimeDiagnosticsSchema.gaugeNames.map { ($0, 0) }
      )
    )
  }
}

extension RuntimeDiagnosticsStore: ProviderDiagnosticsSnapshotSource {
  public func providerDiagnosticsSnapshot(
    requestID: OpaqueRuntimeRequestIdentifier?
  ) async throws -> RuntimeDiagnosticsSnapshot {
    try snapshot(requestID: requestID)
  }
}

private enum RuntimeDiagnosticsMetricMap {
  static func name(_ counter: SSHMetricCounter) -> String {
    switch counter {
    case .connectAttempts: "ssh_connect_attempts_total"
    case .connectSucceeded: "ssh_connect_succeeded_total"
    case .connectFailed: "ssh_connect_failed_total"
    case .operationsCancelled: "ssh_operations_cancelled_total"
    case .operationsTimedOut: "ssh_operations_timed_out_total"
    case .hostFirstUseAccepted: "ssh_host_first_use_accepted_total"
    case .hostMatchAccepted: "ssh_host_match_accepted_total"
    case .hostUnknownRejected: "ssh_host_unknown_rejected_total"
    case .hostChangedRejected: "ssh_host_changed_rejected_total"
    case .hostAlgorithmRejected: "ssh_host_algorithm_rejected_total"
    case .authenticationAttempts: "ssh_authentication_attempts_total"
    case .authenticationSucceeded: "ssh_authentication_succeeded_total"
    case .authenticationRejected: "ssh_authentication_rejected_total"
    case .directChannelsOpened: "ssh_direct_channels_opened_total"
    case .execChannelsOpened: "ssh_exec_channels_opened_total"
    case .channelOpenFailed: "ssh_channel_open_failed_total"
    case .channelsClosedGracefully: "ssh_channels_closed_gracefully_total"
    case .channelsReset: "ssh_channels_reset_total"
    case .channelsCancelled: "ssh_channels_cancelled_total"
    case .payloadBytesSent: "ssh_payload_bytes_sent_total"
    case .payloadBytesReceived: "ssh_payload_bytes_received_total"
    case .protectedBytesSent: "ssh_protected_bytes_sent_total"
    case .protectedBytesReceived: "ssh_protected_bytes_received_total"
    case .writeBackpressureWaits: "ssh_write_backpressure_waits_total"
    case .windowAdjustments: "ssh_window_adjustments_total"
    case .windowAdjustmentBytes: "ssh_window_adjustment_bytes_total"
    case .clientByteRekeys: "ssh_client_byte_rekeys_total"
    case .clientTimeRekeys: "ssh_client_time_rekeys_total"
    case .explicitRekeys: "ssh_explicit_rekeys_total"
    case .serverRekeys: "ssh_server_rekeys_total"
    case .rekeysSucceeded: "ssh_rekeys_succeeded_total"
    case .rekeysFailed: "ssh_rekeys_failed_total"
    case .keepalivesSent: "ssh_keepalives_sent_total"
    case .keepalivesAcknowledged: "ssh_keepalives_acknowledged_total"
    case .keepalivesTimedOut: "ssh_keepalives_timed_out_total"
    }
  }

  static func name(_ gauge: SSHMetricGauge) -> String {
    switch gauge {
    case .openDirectChannels: "ssh_open_direct_channels"
    case .openExecChannels: "ssh_open_exec_channels"
    case .pendingChannelOpens: "ssh_pending_channel_opens"
    case .pendingReads: "ssh_pending_reads"
    case .pendingWrites: "ssh_pending_writes"
    case .queuedWriteBytes: "ssh_queued_write_bytes"
    case .bufferedReadBytes: "ssh_buffered_read_bytes"
    case .remainingReceiveWindowBytes: "ssh_remaining_receive_window_bytes"
    case .activeKeyExchange: "ssh_active_key_exchange"
    case .consecutiveKeepaliveMisses: "ssh_consecutive_keepalive_misses"
    case .lastKeepaliveRTTNanoseconds: "ssh_last_keepalive_rtt_nanoseconds"
    }
  }

  static func transitionCounter(_ state: TunnelLifecycleState) -> String {
    "coordinator_transition_\(state.metricToken)_total"
  }

  static func transitionTimeGauge(_ state: TunnelLifecycleState) -> String {
    "coordinator_transition_\(state.metricToken)_uptime_milliseconds"
  }

  static func healthGauge(_ component: RuntimeDiagnosticComponent) -> String {
    switch component {
    case .coordinator: "component_coordinator_health_code"
    case .packetBridge: "component_packet_bridge_health_code"
    case .hev: "component_hev_health_code"
    case .ssh: "component_ssh_health_code"
    case .tcp: "component_tcp_health_code"
    case .dns: "component_dns_health_code"
    case .route: "component_route_health_code"
    }
  }

  static func dropCounter(_ reason: RuntimeQueueDropReason) -> String {
    switch reason {
    case .packetForwardMalformed: "packet_bridge_forward_drop_malformed_total"
    case .packetForwardWouldBlock: "packet_bridge_forward_drop_would_block_total"
    case .packetForwardNoBuffer: "packet_bridge_forward_drop_no_buffer_total"
    case .packetReverseMalformed: "packet_bridge_reverse_drop_malformed_total"
    case .packetReverseWriteRejected:
      "packet_bridge_reverse_drop_write_rejected_packets_total"
    case .tcpAdmissionLimit: "tcp_drop_admission_limit_total"
    case .tcpQueuedByteLimit: "tcp_drop_queued_byte_limit_total"
    case .dnsQueueFull: "dns_drop_queue_full_total"
    }
  }

  static func dnsResultCounter(_ result: RuntimeDNSResultClass) -> String {
    switch result {
    case .success: "dns_result_success_total"
    case .noData: "dns_result_no_data_total"
    case .nameError: "dns_result_name_error_total"
    case .serverFailure: "dns_result_server_failure_total"
    case .refused: "dns_result_refused_total"
    case .timeout: "dns_result_timeout_total"
    case .malformed: "dns_result_malformed_total"
    case .otherFailure: "dns_result_other_failure_total"
    }
  }
}

extension TunnelLifecycleState {
  fileprivate var metricToken: String {
    switch self {
    case .disconnected: "disconnected"
    case .connecting: "connecting"
    case .connectedFull: "connected_full"
    case .connectedDegraded: "connected_degraded"
    case .reasserting: "reasserting"
    case .failed: "failed"
    case .disconnecting: "disconnecting"
    case .unknown: "unknown"
    }
  }
}

extension UInt64 {
  fileprivate func saturatingAdding(_ other: UInt64) -> UInt64 {
    let (sum, overflow) = addingReportingOverflow(other)
    return overflow ? UInt64.max : sum
  }
}
