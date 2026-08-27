import Darwin
import Foundation

public enum MTUMatrixSchema {
  public static let currentVersion: UInt16 = 1
}

public enum MTUMatrixError: Error, Equatable, CustomStringConvertible {
  case missingOutputPath
  case unsafeOutputPath
  case invalidPacketCount
  case socketFailure(operation: String, code: Int32)
  case nominalLoss(row: String, count: Int)
  case pressureDidNotDrop(row: String)
  case unboundedPressureLoss(row: String)
  case invalidDropAccounting(row: String)
  case invalidDropReason(row: String)
  case recoveryFailed(row: String)
  case outputWriteFailure(operation: String, code: Int32)

  public var description: String {
    switch self {
    case .missingOutputPath: "output_path is required"
    case .unsafeOutputPath: "output_path must resolve below .temp or /tmp"
    case .invalidPacketCount: "packets_per_row must be in 64...2048"
    case .socketFailure(let operation, let code): "\(operation) failed with errno \(code)"
    case .nominalLoss(let row, let count): "\(row) had \(count) unexplained nominal drops"
    case .pressureDidNotDrop(let row): "\(row) did not induce the required bounded drop"
    case .unboundedPressureLoss(let row): "\(row) lost every attempted packet"
    case .invalidDropAccounting(let row): "\(row) has inconsistent packet/drop counters"
    case .invalidDropReason(let row): "\(row) has a missing or incorrect drop reason"
    case .recoveryFailed(let row): "\(row) failed its post-pressure recovery probe"
    case .outputWriteFailure(let operation, let code):
      "\(operation) failed with errno \(code)"
    }
  }
}

public enum MTUMatrixPressure: String, Codable, CaseIterable, Sendable {
  case nominal
  case constrainedBuffer = "constrained-buffer"
  case receiverStall = "receiver-stall"
  case mixed
}

public enum MTUMatrixFamily: String, Codable, CaseIterable, Sendable {
  case ipv4
  case ipv6
  case dualStack = "dual-stack"
}

public struct MTUMatrixRunConfiguration: Sendable {
  public let outputURL: URL
  public let packetsPerRow: Int
  let outputTarget: MTUMatrixOutputTarget

  public static func parse(_ document: HarnessConfigurationDocument) throws -> Self {
    guard let rawPath = document.parameters["output_path"]?.value, !rawPath.isEmpty else {
      throw MTUMatrixError.missingOutputPath
    }
    let packetCount: Int
    if let rawCount = document.parameters["packets_per_row"]?.value {
      guard let parsed = Int(rawCount), (64...2_048).contains(parsed) else {
        throw MTUMatrixError.invalidPacketCount
      }
      packetCount = parsed
    } else {
      packetCount = 512
    }

    let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let unresolved =
      rawPath.hasPrefix("/")
      ? URL(fileURLWithPath: rawPath)
      : workingDirectory.appendingPathComponent(rawPath)
    let candidate = unresolved.standardizedFileURL
    let projectTemp = workingDirectory.appendingPathComponent(".temp", isDirectory: true)
      .standardizedFileURL.path
    let systemTemp = URL(fileURLWithPath: "/tmp", isDirectory: true).standardizedFileURL.path
    let target: MTUMatrixOutputTarget
    if let components = relativeComponents(candidate.path, below: projectTemp) {
      target = try MTUMatrixOutputTarget.open(rootPath: projectTemp, components: components)
    } else if let components = relativeComponents(candidate.path, below: systemTemp) {
      target = try MTUMatrixOutputTarget.open(
        rootPath: try canonicalSystemTempPath(systemTemp),
        components: components
      )
    } else {
      throw MTUMatrixError.unsafeOutputPath
    }
    return Self(outputURL: candidate, packetsPerRow: packetCount, outputTarget: target)
  }

  private static func relativeComponents(_ path: String, below root: String) -> [String]? {
    let prefix = root.hasSuffix("/") ? root : root + "/"
    guard path.hasPrefix(prefix) else { return nil }
    let components = path.dropFirst(prefix.count).split(separator: "/").map(String.init)
    guard !components.isEmpty,
      components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
    else { return nil }
    return components
  }

  private static func canonicalSystemTempPath(_ path: String) throws -> String {
    var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
    guard Darwin.realpath(path, &buffer) != nil else {
      throw MTUMatrixError.unsafeOutputPath
    }
    return String(
      decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
      as: UTF8.self
    )
  }
}

struct MTUMatrixDirectoryIdentity: Equatable {
  let device: dev_t
  let inode: ino_t
}

final class MTUMatrixOutputTarget: @unchecked Sendable {
  let directoryComponents: [String]
  fileprivate let directoryIdentities: [MTUMatrixDirectoryIdentity]
  let fileName: String
  private var descriptors: [Int32]
  private let lock = NSLock()

  private init(
    directoryComponents: [String],
    directoryIdentities: [MTUMatrixDirectoryIdentity],
    fileName: String,
    descriptors: [Int32]
  ) {
    self.directoryComponents = directoryComponents
    self.directoryIdentities = directoryIdentities
    self.fileName = fileName
    self.descriptors = descriptors
  }

  deinit {
    close()
  }

  static func open(rootPath: String, components: [String]) throws -> MTUMatrixOutputTarget {
    guard rootPath.hasPrefix("/"), let fileName = components.last else {
      throw MTUMatrixError.unsafeOutputPath
    }
    let rootComponents = rootPath.split(separator: "/").map(String.init)
    let outputParentComponents = Array(components.dropLast())
    let directoryComponents = rootComponents + outputParentComponents
    var descriptors: [Int32] = []
    do {
      let filesystemRoot = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
      guard filesystemRoot >= 0 else { throw MTUMatrixError.unsafeOutputPath }
      descriptors.append(filesystemRoot)
      var identities = [try identity(of: filesystemRoot)]

      for (index, component) in directoryComponents.enumerated() {
        let parent = descriptors[descriptors.count - 1]
        if index >= rootComponents.count,
          Darwin.mkdirat(parent, component, S_IRWXU) != 0, errno != EEXIST
        {
          throw MTUMatrixError.outputWriteFailure(
            operation: "mkdirat output directory", code: errno
          )
        }
        let descriptor = Darwin.openat(
          parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard descriptor >= 0 else { throw MTUMatrixError.unsafeOutputPath }
        descriptors.append(descriptor)
        identities.append(try identity(of: descriptor))
      }
      return MTUMatrixOutputTarget(
        directoryComponents: directoryComponents,
        directoryIdentities: identities,
        fileName: fileName,
        descriptors: descriptors
      )
    } catch {
      for descriptor in descriptors.reversed() {
        _ = Darwin.close(descriptor)
      }
      throw error
    }
  }

  func withParentDescriptor<T>(_ body: (Int32) throws -> T) throws -> T {
    lock.lock()
    defer { lock.unlock() }
    guard let descriptor = descriptors.last else { throw MTUMatrixError.unsafeOutputPath }
    return try body(descriptor)
  }

  func close() {
    lock.lock()
    let ownedDescriptors = descriptors
    descriptors.removeAll()
    lock.unlock()
    for descriptor in ownedDescriptors.reversed() {
      _ = Darwin.close(descriptor)
    }
  }

  fileprivate static func identity(of descriptor: Int32) throws -> MTUMatrixDirectoryIdentity {
    var metadata = stat()
    guard Darwin.fstat(descriptor, &metadata) == 0 else {
      throw MTUMatrixError.outputWriteFailure(operation: "fstat output directory", code: errno)
    }
    return MTUMatrixDirectoryIdentity(device: metadata.st_dev, inode: metadata.st_ino)
  }
}

public struct MTUMatrixRow: Codable, Equatable, Sendable {
  public let id: String
  public let family: MTUMatrixFamily
  public let mtu: Int
  public let pressure: MTUMatrixPressure
  public let trafficGenerator: String
  public let durationNanoseconds: UInt64
  public let requestedSendBufferBytes: Int
  public let effectiveSendBufferBytes: Int
  public let requestedReceiveBufferBytes: Int
  public let effectiveReceiveBufferBytes: Int
  public let packetsAttempted: Int
  public let packetsSent: Int
  public let packetsReceived: Int
  public let bytesSent: UInt64
  public let bytesReceived: UInt64
  public let logicalBatchGroups: Int
  public let drops: Int
  public let sendFailures: Int
  public let receiveQueueDrops: Int
  public let sendFailureErrnos: [String: Int]
  public let dropReason: String?
  public let latencyP50Nanoseconds: UInt64
  public let latencyP95Nanoseconds: UInt64
  public let packetsPerSecond: UInt64
  public let throughputBitsPerSecond: UInt64
  public let cpuUserNanoseconds: UInt64
  public let cpuSystemNanoseconds: UInt64
  public let sendSyscalls: Int
  public let receiveSyscalls: Int
  public let fragmentationObservation: String
  public let configuredMaximumDatagramBytes: Int
  public let maximumDatagramBytes: Int
  public let recoveryProbeSucceeded: Bool
  public let ownedDescriptorDelta: Int
  public let descriptorLifecycleMethod: String
  public let taskDelta: Int?
  public let taskLifecycleAvailability: String
}

public struct MTUMatrixGap: Codable, Equatable, Sendable {
  public let row: String
  public let status: String
  public let reason: String
}

public struct MTUMatrixRecommendation: Codable, Equatable, Sendable {
  public let mtuRange: String
  public let requestedSocketBufferRangeBytes: String
  public let rationale: String
}

public struct MTUMatrixReport: Codable, Equatable, Sendable {
  public let schemaVersion: UInt16
  public let taskID: String
  public let generatedAtUTC: String
  public let device: String
  public let platform: HarnessPlatformMetadata
  public let sourceRevision: String
  public let dependencyRevisions: [String: String]
  public let exactConfiguration: [String: String]
  public let rows: [MTUMatrixRow]
  public let gaps: [MTUMatrixGap]
  public let energyAvailability: String
  public let recommendation: MTUMatrixRecommendation
}

public enum MTUMatrixAnalysis {
  public static func validate(_ rows: [MTUMatrixRow]) throws {
    for row in rows {
      guard
        row.packetsAttempted >= 0,
        row.packetsSent >= 0,
        row.packetsReceived >= 0,
        row.packetsAttempted >= row.packetsSent,
        row.packetsSent >= row.packetsReceived,
        row.sendFailures == row.packetsAttempted - row.packetsSent,
        row.receiveQueueDrops == row.packetsSent - row.packetsReceived,
        row.drops == row.sendFailures + row.receiveQueueDrops
      else {
        throw MTUMatrixError.invalidDropAccounting(row: row.id)
      }
      if [.nominal, .mixed].contains(row.pressure), row.drops != 0 {
        throw MTUMatrixError.nominalLoss(row: row.id, count: row.drops)
      }
      if [.constrainedBuffer, .receiverStall].contains(row.pressure) {
        if row.drops == 0 {
          throw MTUMatrixError.pressureDidNotDrop(row: row.id)
        }
        if row.drops == row.packetsAttempted {
          throw MTUMatrixError.unboundedPressureLoss(row: row.id)
        }
      }
      let expectedReasons = [
        row.sendFailures > 0 ? "sender_socket_refusal" : nil,
        row.receiveQueueDrops > 0 ? "socket_receive_queue_overflow" : nil,
      ].compactMap { $0 }.joined(separator: "+")
      if row.dropReason != (expectedReasons.isEmpty ? nil : expectedReasons) {
        throw MTUMatrixError.invalidDropReason(row: row.id)
      }
      if !row.recoveryProbeSucceeded || row.ownedDescriptorDelta != 0
        || (row.taskDelta != nil && row.taskDelta != 0)
      {
        throw MTUMatrixError.recoveryFailed(row: row.id)
      }
    }
  }

  public static func recommendation(rows: [MTUMatrixRow]) -> MTUMatrixRecommendation {
    let nominal = rows.filter { $0.pressure == .nominal }
    let mtu4096Clean = nominal.filter { $0.mtu == 4_096 }.allSatisfy { $0.drops == 0 }
    return MTUMatrixRecommendation(
      mtuRange: mtu4096Clean ? "1500...4096" : "1500",
      requestedSocketBufferRangeBytes: "32768...262144",
      rationale:
        "All candidates were measured locally; 1500 is the portable baseline and 4096 is an injectable local candidate when the end-to-end path is proven. 8500 is not selected because loopback throughput cannot establish external path MTU or fragmentation safety. The buffer range spans the measured stalled and nominal settings; constrained 4096-byte queues are fault-injection only."
    )
  }
}

public struct MTUMatrixHarnessCommand: HarnessCommand {
  public let name = "mtu-matrix"
  private let afterConfigurationParsed: @Sendable () async -> Void

  public init() {
    self.afterConfigurationParsed = {}
  }

  init(afterConfigurationParsed: @escaping @Sendable () async -> Void) {
    self.afterConfigurationParsed = afterConfigurationParsed
  }

  public func run(context: HarnessCommandContext) async throws {
    // Production gate: all filesystem and run ceilings are validated here,
    // before any socket is created or artifact is written.
    let runConfiguration = try MTUMatrixRunConfiguration.parse(context.configuration)
    defer { runConfiguration.outputTarget.close() }
    await afterConfigurationParsed()
    var rows: [MTUMatrixRow] = []
    for mtu in [1_500, 4_096, 8_500] {
      for family in MTUMatrixFamily.allCases {
        for pressure in MTUMatrixPressure.allCases {
          try Task.checkCancellation()
          rows.append(
            try LocalUDPMatrixRunner.run(
              mtu: mtu,
              family: family,
              pressure: pressure,
              packetCount: runConfiguration.packetsPerRow
            )
          )
        }
      }
    }
    try MTUMatrixAnalysis.validate(rows)

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let report = MTUMatrixReport(
      schemaVersion: MTUMatrixSchema.currentVersion,
      taskID: "TASK-260715-gyg51r",
      generatedAtUTC: formatter.string(from: Date()),
      device: currentDeviceDescription(),
      platform: .current(),
      sourceRevision: context.configuration.sourceRevision,
      dependencyRevisions: context.configuration.dependencyRevisions,
      exactConfiguration: [
        "address_scope": "loopback-only",
        "mtus": "1500,4096,8500",
        "packets_per_row": String(runConfiguration.packetsPerRow),
        "pressures": MTUMatrixPressure.allCases.map(\.rawValue).joined(separator: ","),
        "families": MTUMatrixFamily.allCases.map(\.rawValue).joined(separator: ","),
      ],
      rows: rows,
      gaps: [
        MTUMatrixGap(
          row: "iPhone physical matrix",
          status: "deferred-unavailable",
          reason: "Deferred with iOS under ADR-024; not counted as a pass or failure."
        ),
        MTUMatrixGap(
          row: "NAT64",
          status: "unavailable",
          reason:
            "No authorized deterministic local NAT64 environment is present; Internet and route mutation are prohibited by the execution brief."
        ),
      ],
      energyAvailability:
        "unavailable: bounded SwiftPM harness has no unprivileged per-process energy counter; powermetrics/sudo were not invoked",
      recommendation: MTUMatrixAnalysis.recommendation(rows: rows)
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    try MTUMatrixOutputWriter.write(data, to: runConfiguration.outputTarget)

    await context.dependencies.runtime.metrics.incrementCounter(
      named: "harness.mtu_matrix.rows", by: UInt64(rows.count)
    )
    await context.dependencies.runtime.metrics.incrementCounter(
      named: "harness.mtu_matrix.packets_sent",
      by: rows.reduce(0) { $0 + UInt64($1.packetsSent) }
    )
    await context.dependencies.runtime.metrics.incrementCounter(
      named: "harness.mtu_matrix.packets_dropped",
      by: rows.reduce(0) { $0 + UInt64($1.drops) }
    )
  }
}

private enum MTUMatrixOutputWriter {
  static func write(_ data: Data, to target: MTUMatrixOutputTarget) throws {
    try validateAnchoredChain(target)
    try target.withParentDescriptor { directoryDescriptor in
      try write(data, fileName: target.fileName, directoryDescriptor: directoryDescriptor)
    }
  }

  private static func write(_ data: Data, fileName: String, directoryDescriptor: Int32) throws {
    var existing = stat()
    if Darwin.fstatat(directoryDescriptor, fileName, &existing, AT_SYMLINK_NOFOLLOW) == 0 {
      guard existing.st_mode & S_IFMT != S_IFLNK else {
        throw MTUMatrixError.unsafeOutputPath
      }
    } else if errno != ENOENT {
      throw MTUMatrixError.outputWriteFailure(operation: "fstatat output file", code: errno)
    }

    let temporaryName = ".\(fileName).\(UUID().uuidString).tmp"
    let fileDescriptor = Darwin.openat(
      directoryDescriptor,
      temporaryName,
      O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
      S_IRUSR | S_IWUSR
    )
    guard fileDescriptor >= 0 else {
      throw MTUMatrixError.outputWriteFailure(operation: "openat temporary output", code: errno)
    }
    var temporaryExists = true
    defer {
      _ = Darwin.close(fileDescriptor)
      if temporaryExists {
        _ = Darwin.unlinkat(directoryDescriptor, temporaryName, 0)
      }
    }

    try data.withUnsafeBytes { bytes in
      var offset = 0
      while offset < bytes.count {
        guard let baseAddress = bytes.baseAddress else { break }
        let count = Darwin.write(
          fileDescriptor, baseAddress.advanced(by: offset), bytes.count - offset
        )
        guard count > 0 else {
          throw MTUMatrixError.outputWriteFailure(operation: "write output", code: errno)
        }
        offset += count
      }
    }
    guard Darwin.fsync(fileDescriptor) == 0 else {
      throw MTUMatrixError.outputWriteFailure(operation: "fsync output", code: errno)
    }
    guard Darwin.renameat(directoryDescriptor, temporaryName, directoryDescriptor, fileName) == 0
    else {
      throw MTUMatrixError.outputWriteFailure(operation: "renameat output", code: errno)
    }
    temporaryExists = false
  }

  private static func validateAnchoredChain(_ target: MTUMatrixOutputTarget) throws {
    var descriptors: [Int32] = []
    defer {
      for descriptor in descriptors.reversed() {
        _ = Darwin.close(descriptor)
      }
    }
    let filesystemRoot = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard filesystemRoot >= 0 else { throw MTUMatrixError.unsafeOutputPath }
    descriptors.append(filesystemRoot)
    guard try MTUMatrixOutputTarget.identity(of: filesystemRoot) == target.directoryIdentities[0]
    else { throw MTUMatrixError.unsafeOutputPath }

    for (index, component) in target.directoryComponents.enumerated() {
      let descriptor = Darwin.openat(
        descriptors[descriptors.count - 1],
        component,
        O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
      )
      guard descriptor >= 0 else { throw MTUMatrixError.unsafeOutputPath }
      descriptors.append(descriptor)
      guard
        try MTUMatrixOutputTarget.identity(of: descriptor)
          == target.directoryIdentities[index + 1]
      else { throw MTUMatrixError.unsafeOutputPath }
    }
  }
}

private final class OwnedDescriptorLedger: @unchecked Sendable {
  private let lock = NSLock()
  private var activeCount = 0

  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return activeCount
  }

  func openSocket(domain: Int32) -> Int32 {
    let descriptor = Darwin.socket(domain, SOCK_DGRAM, 0)
    if descriptor >= 0 {
      lock.lock()
      activeCount += 1
      lock.unlock()
    }
    return descriptor
  }

  func closeSocket(_ descriptor: Int32) -> Int32 {
    let result = Darwin.close(descriptor)
    if result == 0 {
      lock.lock()
      activeCount -= 1
      lock.unlock()
    }
    return result
  }
}

private let ownedDescriptorLedger = OwnedDescriptorLedger()

private enum LocalUDPMatrixRunner {
  private struct Sample {
    let requestedBuffer: Int
    let effectiveSendBuffer: Int
    let effectiveReceiveBuffer: Int
    let packetsAttempted: Int
    let packetsSent: Int
    let packetsReceived: Int
    let bytesSent: UInt64
    let bytesReceived: UInt64
    let durationNanoseconds: UInt64
    let latencies: [UInt64]
    let cpuUserNanoseconds: UInt64
    let cpuSystemNanoseconds: UInt64
    let sendSyscalls: Int
    let receiveSyscalls: Int
    let sendFailureErrnos: [Int32: Int]
    let configuredMaximumDatagramBytes: Int
    let maximumDatagramBytes: Int
    let recovery: Bool
    let descriptorDelta: Int
  }

  static func run(
    mtu: Int,
    family: MTUMatrixFamily,
    pressure: MTUMatrixPressure,
    packetCount: Int
  ) throws -> MTUMatrixRow {
    let samples: [Sample]
    switch family {
    case .ipv4:
      samples = [try sample(mtu: mtu, ipv6: false, pressure: pressure, packetCount: packetCount)]
    case .ipv6:
      samples = [try sample(mtu: mtu, ipv6: true, pressure: pressure, packetCount: packetCount)]
    case .dualStack:
      let firstCount = packetCount / 2
      samples = [
        try sample(mtu: mtu, ipv6: false, pressure: pressure, packetCount: firstCount),
        try sample(mtu: mtu, ipv6: true, pressure: pressure, packetCount: packetCount - firstCount),
      ]
    }
    let latencies = samples.flatMap(\.latencies).sorted()
    let attempted = samples.reduce(0) { $0 + $1.packetsAttempted }
    let sent = samples.reduce(0) { $0 + $1.packetsSent }
    let received = samples.reduce(0) { $0 + $1.packetsReceived }
    let bytesSent = samples.reduce(0) { $0 + $1.bytesSent }
    let bytesReceived = samples.reduce(0) { $0 + $1.bytesReceived }
    let duration = samples.reduce(0) { $0 + $1.durationNanoseconds }
    let sendFailures = attempted - sent
    let receiveDrops = sent - received
    let dropped = attempted - received
    var failureErrnos: [String: Int] = [:]
    for sample in samples {
      for (code, count) in sample.sendFailureErrnos {
        let description = String(cString: strerror(code))
        failureErrnos["\(code):\(description)", default: 0] += count
      }
    }
    let reasons = [
      sendFailures > 0 ? "sender_socket_refusal" : nil,
      receiveDrops > 0 ? "socket_receive_queue_overflow" : nil,
    ].compactMap { $0 }
    let traffic: String =
      switch pressure {
      case .nominal: "dns+short-web+large-upload/download"
      case .constrainedBuffer: "bounded-datagram-burst"
      case .receiverStall: "25ms-stalled-large-download"
      case .mixed: "mixed-bidirectional-local"
      }
    return MTUMatrixRow(
      id: "\(family.rawValue)-mtu\(mtu)-\(pressure.rawValue)",
      family: family,
      mtu: mtu,
      pressure: pressure,
      trafficGenerator: traffic,
      durationNanoseconds: duration,
      requestedSendBufferBytes: samples.map(\.requestedBuffer).min() ?? 0,
      effectiveSendBufferBytes: samples.map(\.effectiveSendBuffer).min() ?? 0,
      requestedReceiveBufferBytes: samples.map(\.requestedBuffer).min() ?? 0,
      effectiveReceiveBufferBytes: samples.map(\.effectiveReceiveBuffer).min() ?? 0,
      packetsAttempted: attempted,
      packetsSent: sent,
      packetsReceived: received,
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
      logicalBatchGroups: (sent + 31) / 32,
      drops: dropped,
      sendFailures: sendFailures,
      receiveQueueDrops: receiveDrops,
      sendFailureErrnos: failureErrnos,
      dropReason: reasons.isEmpty ? nil : reasons.joined(separator: "+"),
      latencyP50Nanoseconds: percentile(latencies, 0.50),
      latencyP95Nanoseconds: percentile(latencies, 0.95),
      packetsPerSecond: duration == 0 ? 0 : UInt64(received) * 1_000_000_000 / duration,
      throughputBitsPerSecond: duration == 0 ? 0 : bytesReceived * 8 * 1_000_000_000 / duration,
      cpuUserNanoseconds: samples.reduce(0) { $0 + $1.cpuUserNanoseconds },
      cpuSystemNanoseconds: samples.reduce(0) { $0 + $1.cpuSystemNanoseconds },
      sendSyscalls: samples.reduce(0) { $0 + $1.sendSyscalls },
      receiveSyscalls: samples.reduce(0) { $0 + $1.receiveSyscalls },
      fragmentationObservation:
        "not directly observable at UDP API; payload capped to MTU minus IP/UDP headers",
      configuredMaximumDatagramBytes: samples.map(\.configuredMaximumDatagramBytes).max() ?? 0,
      maximumDatagramBytes: samples.map(\.maximumDatagramBytes).max() ?? 0,
      recoveryProbeSucceeded: samples.allSatisfy(\.recovery),
      ownedDescriptorDelta: samples.reduce(0) { $0 + $1.descriptorDelta },
      descriptorLifecycleMethod:
        "production-owned socket ledger; register after Darwin.socket and release after successful Darwin.close",
      taskDelta: nil,
      taskLifecycleAvailability:
        "unavailable: synchronous socket runner creates no owned Swift tasks; process threads are not a valid proxy"
    )
  }

  private static func sample(
    mtu: Int,
    ipv6: Bool,
    pressure: MTUMatrixPressure,
    packetCount: Int
  ) throws -> Sample {
    let descriptorsBefore = ownedDescriptorLedger.count
    let domain = ipv6 ? AF_INET6 : AF_INET
    let receiver = ownedDescriptorLedger.openSocket(domain: domain)
    guard receiver >= 0 else { throw socketError("receiver socket") }
    let sender = ownedDescriptorLedger.openSocket(domain: domain)
    guard sender >= 0 else {
      _ = ownedDescriptorLedger.closeSocket(receiver)
      throw socketError("sender socket")
    }
    var closed = false
    defer {
      if !closed {
        _ = ownedDescriptorLedger.closeSocket(sender)
        _ = ownedDescriptorLedger.closeSocket(receiver)
      }
    }

    let requestedBuffer =
      switch pressure {
      case .constrainedBuffer: 4_096
      case .receiverStall:
        // A 64-packet dual-stack row is split into two 32-packet samples. Keep
        // that advertised lower bound under genuine queue pressure instead of
        // accepting a no-drop row that happens to fit in a 32 KiB queue.
        packetCount <= 32 ? 4_096 : 32_768
      case .nominal, .mixed: 262_144
      }
    try setBuffer(sender, SO_SNDBUF, requestedBuffer)
    try setBuffer(receiver, SO_RCVBUF, requestedBuffer)
    let effectiveSend = try getBuffer(sender, SO_SNDBUF)
    let effectiveReceive = try getBuffer(receiver, SO_RCVBUF)
    try bindLoopback(receiver, ipv6: ipv6)
    try connectToReceiver(sender, receiver: receiver, ipv6: ipv6)
    if pressure == .mixed {
      try connectToReceiver(receiver, receiver: sender, ipv6: ipv6)
    }
    let currentFlags = Darwin.fcntl(receiver, F_GETFL)
    guard currentFlags >= 0, Darwin.fcntl(receiver, F_SETFL, currentFlags | O_NONBLOCK) == 0 else {
      throw socketError("fcntl nonblocking")
    }
    if pressure == .mixed {
      let senderFlags = Darwin.fcntl(sender, F_GETFL)
      guard senderFlags >= 0,
        Darwin.fcntl(sender, F_SETFL, senderFlags | O_NONBLOCK) == 0
      else {
        throw socketError("fcntl mixed sender nonblocking")
      }
    }

    let maximum = max(64, mtu - (ipv6 ? 48 : 28))
    var sendTimes: [UInt64: UInt64] = [:]
    var latencies: [UInt64] = []
    var packetsSent = 0
    var packetsReceived = 0
    var bytesSent: UInt64 = 0
    var bytesReceived: UInt64 = 0
    var sendSyscalls = 0
    var receiveSyscalls = 0
    var sendFailureErrnos: [Int32: Int] = [:]
    var maximumSuccessfulDatagramBytes = 0
    var usageBefore = rusage()
    _ = getrusage(RUSAGE_SELF, &usageBefore)
    let started = DispatchTime.now().uptimeNanoseconds

    func drain(_ descriptor: Int32) {
      var buffer = [UInt8](repeating: 0, count: maximum)
      while true {
        receiveSyscalls += 1
        let count = buffer.withUnsafeMutableBytes {
          Darwin.recv(descriptor, $0.baseAddress, $0.count, 0)
        }
        if count < 0 {
          if errno == EAGAIN || errno == EWOULDBLOCK { break }
          break
        }
        packetsReceived += 1
        bytesReceived += UInt64(count)
        if count >= 8 {
          let sequence = buffer.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
          if let sentAt = sendTimes.removeValue(forKey: sequence) {
            latencies.append(DispatchTime.now().uptimeNanoseconds - sentAt)
          }
        }
      }
    }

    for index in 0..<packetCount {
      let pattern = [128, min(768, maximum), max(64, maximum / 2), maximum]
      let size = pattern[index % pattern.count]
      var payload = [UInt8](repeating: UInt8(truncatingIfNeeded: index), count: size)
      var sequence = UInt64(index).bigEndian
      withUnsafeBytes(of: &sequence) { payload.replaceSubrange(0..<8, with: $0) }
      sendTimes[UInt64(index)] = DispatchTime.now().uptimeNanoseconds
      let sendDescriptor = pressure == .mixed && index.isMultiple(of: 2) ? receiver : sender
      let receiveDescriptor = sendDescriptor == sender ? receiver : sender
      sendSyscalls += 1
      let count = payload.withUnsafeBytes {
        Darwin.send(sendDescriptor, $0.baseAddress, $0.count, 0)
      }
      if count >= 0 {
        packetsSent += 1
        bytesSent += UInt64(count)
        maximumSuccessfulDatagramBytes = max(maximumSuccessfulDatagramBytes, count)
      } else {
        sendFailureErrnos[errno, default: 0] += 1
      }
      if pressure == .nominal || pressure == .mixed {
        drain(receiveDescriptor)
      }
    }
    if pressure == .receiverStall {
      usleep(25_000)
    }
    let drainDeadline = DispatchTime.now().uptimeNanoseconds + 250_000_000
    var pressureIdleRounds = 0
    while DispatchTime.now().uptimeNanoseconds < drainDeadline {
      let previous = packetsReceived
      drain(receiver)
      if pressure == .mixed {
        drain(sender)
      }
      if packetsReceived == packetsSent { break }
      if [.constrainedBuffer, .receiverStall].contains(pressure) {
        pressureIdleRounds = packetsReceived == previous ? pressureIdleRounds + 1 : 0
        if pressureIdleRounds >= 4 { break }
      }
      usleep(1_000)
    }

    // Recovery is a real post-pressure datagram on the same descriptors.
    let recoveryPayload = [UInt8](repeating: 0x5a, count: 64)
    sendSyscalls += 1
    let recoverySent =
      recoveryPayload.withUnsafeBytes {
        Darwin.send(sender, $0.baseAddress, $0.count, 0)
      } == recoveryPayload.count
    var recoveryReceived = false
    let recoveryDeadline = DispatchTime.now().uptimeNanoseconds + 1_000_000_000
    while !recoveryReceived && DispatchTime.now().uptimeNanoseconds < recoveryDeadline {
      var recoveryBuffer = [UInt8](repeating: 0, count: 64)
      receiveSyscalls += 1
      let count = recoveryBuffer.withUnsafeMutableBytes {
        Darwin.recv(receiver, $0.baseAddress, $0.count, 0)
      }
      recoveryReceived = count == recoveryPayload.count && recoveryBuffer == recoveryPayload
      if !recoveryReceived { usleep(1_000) }
    }

    let finished = DispatchTime.now().uptimeNanoseconds
    var usageAfter = rusage()
    _ = getrusage(RUSAGE_SELF, &usageAfter)
    let senderCloseResult = ownedDescriptorLedger.closeSocket(sender)
    let receiverCloseResult = ownedDescriptorLedger.closeSocket(receiver)
    closed = true
    guard senderCloseResult == 0, receiverCloseResult == 0 else {
      throw socketError("close owned socket")
    }
    let descriptorDelta = ownedDescriptorLedger.count - descriptorsBefore
    return Sample(
      requestedBuffer: requestedBuffer,
      effectiveSendBuffer: effectiveSend,
      effectiveReceiveBuffer: effectiveReceive,
      packetsAttempted: packetCount,
      packetsSent: packetsSent,
      packetsReceived: packetsReceived,
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
      durationNanoseconds: finished - started,
      latencies: latencies,
      cpuUserNanoseconds: timevalNanoseconds(usageAfter.ru_utime)
        - timevalNanoseconds(usageBefore.ru_utime),
      cpuSystemNanoseconds: timevalNanoseconds(usageAfter.ru_stime)
        - timevalNanoseconds(usageBefore.ru_stime),
      sendSyscalls: sendSyscalls,
      receiveSyscalls: receiveSyscalls,
      sendFailureErrnos: sendFailureErrnos,
      configuredMaximumDatagramBytes: maximum,
      maximumDatagramBytes: maximumSuccessfulDatagramBytes,
      recovery: recoverySent && recoveryReceived,
      descriptorDelta: descriptorDelta
    )
  }

  private static func bindLoopback(_ descriptor: Int32, ipv6: Bool) throws {
    if ipv6 {
      var address = sockaddr_in6()
      address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
      address.sin6_family = sa_family_t(AF_INET6)
      address.sin6_addr = in6addr_loopback
      let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in6>.size))
        }
      }
      guard result == 0 else { throw socketError("bind IPv6 loopback") }
    } else {
      var address = sockaddr_in()
      address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
      address.sin_family = sa_family_t(AF_INET)
      address.sin_addr.s_addr = inet_addr("127.0.0.1")
      let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
      }
      guard result == 0 else { throw socketError("bind IPv4 loopback") }
    }
  }

  private static func connectToReceiver(_ sender: Int32, receiver: Int32, ipv6: Bool) throws {
    if ipv6 {
      var address = sockaddr_in6()
      var length = socklen_t(MemoryLayout<sockaddr_in6>.size)
      let got = withUnsafeMutablePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.getsockname(receiver, $0, &length)
        }
      }
      guard got == 0 else { throw socketError("getsockname IPv6") }
      let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.connect(sender, $0, length)
        }
      }
      guard result == 0 else { throw socketError("connect IPv6 loopback") }
    } else {
      var address = sockaddr_in()
      var length = socklen_t(MemoryLayout<sockaddr_in>.size)
      let got = withUnsafeMutablePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.getsockname(receiver, $0, &length)
        }
      }
      guard got == 0 else { throw socketError("getsockname IPv4") }
      let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.connect(sender, $0, length)
        }
      }
      guard result == 0 else { throw socketError("connect IPv4 loopback") }
    }
  }

  private static func setBuffer(_ descriptor: Int32, _ option: Int32, _ value: Int) throws {
    var value = Int32(value)
    guard
      Darwin.setsockopt(descriptor, SOL_SOCKET, option, &value, socklen_t(MemoryLayout<Int32>.size))
        == 0
    else {
      throw socketError("setsockopt")
    }
  }

  private static func getBuffer(_ descriptor: Int32, _ option: Int32) throws -> Int {
    var value: Int32 = 0
    var length = socklen_t(MemoryLayout<Int32>.size)
    guard Darwin.getsockopt(descriptor, SOL_SOCKET, option, &value, &length) == 0 else {
      throw socketError("getsockopt")
    }
    return Int(value)
  }

  private static func timevalNanoseconds(_ value: timeval) -> UInt64 {
    UInt64(max(0, value.tv_sec)) * 1_000_000_000 + UInt64(max(0, value.tv_usec)) * 1_000
  }

  private static func percentile(_ values: [UInt64], _ fraction: Double) -> UInt64 {
    guard !values.isEmpty else { return 0 }
    let index = min(values.count - 1, Int(Double(values.count - 1) * fraction))
    return values[index]
  }

  private static func socketError(_ operation: String) -> MTUMatrixError {
    MTUMatrixError.socketFailure(operation: operation, code: errno)
  }
}

private func currentDeviceDescription() -> String {
  func value(named name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
    var bytes = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
    return String(
      decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
      as: UTF8.self
    )
  }
  let processor = value(named: "machdep.cpu.brand_string") ?? "Apple silicon"
  let model = value(named: "hw.model") ?? "unknown model"
  return "Physical \(processor) Mac (\(model); stable identifiers omitted)"
}
