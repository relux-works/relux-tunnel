import Foundation

/// A platform-neutral network endpoint used by SSH and internal SOCKS contracts.
public struct TunnelEndpoint: Codable, Hashable, Sendable {
  public let host: String
  public let port: UInt16

  public init(host: String, port: UInt16) {
    self.host = host
    self.port = port
  }
}

/// The minimal configuration crossing from a provider into the shared runtime.
///
/// This value intentionally has no string dictionary or byte storage. The
/// provider resolves the UUID-backed reference through the bounded versioned
/// configuration snapshot codec before it retrieves any credentials.
public struct TunnelConfiguration: Equatable, Sendable {
  public let profileReference: TunnelConfigurationReference

  public init(profileReference: TunnelConfigurationReference) {
    self.profileReference = profileReference
  }
}

public enum TunnelLogLevel: Sendable {
  case debug
  case info
  case notice
  case warning
  case error
}

public enum TunnelLogPrivacy: Sendable {
  case `public`
  case sensitive
}

public struct TunnelLogField: Sendable {
  public let value: String
  public let privacy: TunnelLogPrivacy

  public init(_ value: String, privacy: TunnelLogPrivacy) {
    self.value = value
    self.privacy = privacy
  }
}

/// A logging sink whose implementation is injected by the composition root.
public protocol TunnelLogger: Sendable {
  func log(
    level: TunnelLogLevel,
    message: String,
    fields: [String: TunnelLogField]
  )
}

public struct TunnelMetricsSnapshot: Equatable, Sendable {
  public let schemaVersion: UInt16
  public let counters: [String: UInt64]
  public let gauges: [String: Int64]

  public init(
    schemaVersion: UInt16,
    counters: [String: UInt64],
    gauges: [String: Int64]
  ) {
    self.schemaVersion = schemaVersion
    self.counters = counters
    self.gauges = gauges
  }
}

/// A metrics sink/source shared by packet, SSH, lifecycle, and relay work.
public protocol TunnelMetrics: Sendable {
  func incrementCounter(named name: String, by amount: UInt64) async
  func setGauge(named name: String, to value: Int64) async
  func snapshot() async -> TunnelMetricsSnapshot
}

/// Monotonic time and sleeping, injectable for deterministic lifecycle tests.
public protocol TunnelClock: Sendable {
  func now() -> ContinuousClock.Instant
  func sleep(for duration: Duration) async throws
}

public struct ContinuousTunnelClock: TunnelClock {
  private let clock = ContinuousClock()

  public init() {}

  public func now() -> ContinuousClock.Instant {
    clock.now
  }

  public func sleep(for duration: Duration) async throws {
    try await clock.sleep(for: duration)
  }
}

/// Cancellation is injected so provider stops and harness signals share a seam.
public protocol TunnelCancellationChecking: Sendable {
  var isCancelled: Bool { get }
  func checkCancellation() throws
}

public struct TaskCancellationChecker: TunnelCancellationChecking {
  public init() {}

  public var isCancelled: Bool {
    Task<Never, Never>.isCancelled
  }

  public func checkCancellation() throws {
    try Task<Never, Never>.checkCancellation()
  }
}

public enum TunnelMemoryPressure: Sendable {
  case normal
  case soft
  case pressure
  case critical
}

/// Advisory pressure only; policy remains in shared runtime components.
public protocol TunnelMemoryPressureSource: Sendable {
  func currentPressure() async -> TunnelMemoryPressure
}

/// All environment dependencies used by a runtime generation.
public struct TunnelRuntimeDependencies: Sendable {
  public let clock: any TunnelClock
  public let logger: any TunnelLogger
  public let metrics: any TunnelMetrics
  public let cancellation: any TunnelCancellationChecking
  public let memoryPressure: any TunnelMemoryPressureSource

  public init(
    clock: any TunnelClock,
    logger: any TunnelLogger,
    metrics: any TunnelMetrics,
    cancellation: any TunnelCancellationChecking,
    memoryPressure: any TunnelMemoryPressureSource
  ) {
    self.clock = clock
    self.logger = logger
    self.metrics = metrics
    self.cancellation = cancellation
    self.memoryPressure = memoryPressure
  }
}
