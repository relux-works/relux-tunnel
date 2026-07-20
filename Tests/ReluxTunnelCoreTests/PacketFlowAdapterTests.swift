import Darwin
import Foundation
import ReluxTunnelCore
import ReluxTunnelIOSAdapter
import ReluxTunnelMacOSAdapter
import Testing

@Suite("PacketFlow adapter read lifecycle")
struct PacketFlowAdapterTests {
  @Test(
    "callback-first preserves callback order and packet boundaries",
    arguments: AdapterPlatform.allCases)
  func callbackFirst(platform: AdapterPlatform) async throws {
    let driver = CallbackPacketFlowDriver()
    let adapter = platform.makeAdapter(driver: driver)
    let ipv4 = Data([0x45, 0x01, 0x02])
    let ipv6 = Data([0x60, 0x03, 0x04, 0x05])

    let read = Task { try await adapter.readPackets() }
    await driver.waitForRegistrationCount(1)
    driver.deliver(packets: [ipv4, ipv6], protocols: [AF_INET, AF_INET6])

    let batch = try await read.value
    #expect(
      batch.results == [
        .packet(TunnelPacket(payload: ipv4, addressFamily: .ipv4)),
        .packet(TunnelPacket(payload: ipv6, addressFamily: .ipv6)),
      ]
    )
    #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 0))
  }

  @Test(
    "cancellation-first resumes once and ignores its late callback",
    arguments: AdapterPlatform.allCases)
  func cancellationFirst(platform: AdapterPlatform) async {
    let driver = CallbackPacketFlowDriver()
    let adapter = platform.makeAdapter(driver: driver)
    let read = Task { try await adapter.readPackets() }
    await driver.waitForRegistrationCount(1)

    read.cancel()
    await #expect(throws: CancellationError.self) {
      try await read.value
    }
    #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 1))

    // This batch would throw if inspected. It is only allowed to retire the
    // physical callback registration that NetworkExtension cannot cancel.
    driver.deliver(packets: [Data([0x45])], protocols: [])
    #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 0))

    // A replacement read is explicit, never scheduled by the late callback.
    let replacement = Task { try await adapter.readPackets() }
    await driver.waitForRegistrationCount(2)
    driver.deliver(packets: [Data([0x45])], protocols: [AF_INET])
    let replacementBatch = try? await replacement.value
    #expect(replacementBatch?.results.count == 1)
    #expect(driver.snapshot() == .init(registrationCount: 2, outstandingCount: 0))
  }

  @Test(
    "shutdown-first resumes once, retires a late callback, and prevents new reads",
    arguments: AdapterPlatform.allCases)
  func shutdownFirst(platform: AdapterPlatform) async {
    let driver = CallbackPacketFlowDriver()
    let adapter = platform.makeAdapter(driver: driver)
    let read = Task { try await adapter.readPackets() }
    await driver.waitForRegistrationCount(1)

    await adapter.shutdown()
    await #expect(throws: PacketFlowError.adapterShutDown) {
      try await read.value
    }
    #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 1))

    driver.deliver(packets: [Data()], protocols: [AF_INET])
    #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 0))

    await #expect(throws: PacketFlowError.adapterShutDown) {
      try await adapter.readPackets()
    }
    #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 0))
  }

  @Test(
    "callback/cancellation races resume exactly once and restore registration baseline",
    arguments: AdapterPlatform.allCases)
  func callbackCancellationRace(platform: AdapterPlatform) async {
    for _ in 0..<100 {
      let driver = CallbackPacketFlowDriver()
      let adapter = platform.makeAdapter(driver: driver)
      let read = Task { try await adapter.readPackets() }
      await driver.waitForRegistrationCount(1)

      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          read.cancel()
        }
        group.addTask {
          driver.deliver(packets: [Data([0x45])], protocols: [AF_INET])
        }
      }

      do {
        let batch = try await read.value
        #expect(batch.results.count == 1)
      } catch {
        #expect(error is CancellationError)
      }
      #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 0))
    }
  }

  @Test(
    "callback/shutdown races resume exactly once and restore registration baseline",
    arguments: AdapterPlatform.allCases)
  func callbackShutdownRace(platform: AdapterPlatform) async {
    for _ in 0..<100 {
      let driver = CallbackPacketFlowDriver()
      let adapter = platform.makeAdapter(driver: driver)
      let read = Task { try await adapter.readPackets() }
      await driver.waitForRegistrationCount(1)

      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          await adapter.shutdown()
        }
        group.addTask {
          driver.deliver(packets: [Data([0x45])], protocols: [AF_INET])
        }
      }

      do {
        let batch = try await read.value
        #expect(batch.results.count == 1)
      } catch {
        #expect(error as? PacketFlowError == .adapterShutDown)
      }
      #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 0))
    }
  }

  @Test("only one callback registration can be outstanding", arguments: AdapterPlatform.allCases)
  func singleFlight(platform: AdapterPlatform) async throws {
    let driver = CallbackPacketFlowDriver()
    let adapter = platform.makeAdapter(driver: driver)
    let first = Task { try await adapter.readPackets() }
    await driver.waitForRegistrationCount(1)

    await #expect(throws: PacketFlowError.readAlreadyPending) {
      try await adapter.readPackets()
    }
    #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 1))

    driver.deliver(packets: [Data([0x45])], protocols: [AF_INET])
    _ = try await first.value
    #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 0))
  }

  @Test(
    "packet/protocol cardinality mismatch is a typed batch anomaly",
    arguments: AdapterPlatform.allCases)
  func cardinalityMismatch(platform: AdapterPlatform) async {
    let driver = CallbackPacketFlowDriver()
    let adapter = platform.makeAdapter(driver: driver)
    let read = Task { try await adapter.readPackets() }
    await driver.waitForRegistrationCount(1)

    driver.deliver(
      packets: [Data([0x45]), Data([0x60])],
      protocols: [AF_INET]
    )

    await #expect(
      throws: PacketFlowError.packetProtocolCardinalityMismatch(
        packetCount: 2,
        protocolCount: 1
      )
    ) {
      try await read.value
    }
    #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 0))
  }

  @Test(
    "unsupported families are reported without retaining payload",
    arguments: AdapterPlatform.allCases)
  func unsupportedFamily(platform: AdapterPlatform) async throws {
    let batch = try await read(
      platform: platform,
      packets: [Data([0x45, 0xaa, 0xbb])],
      protocols: [Int32.max]
    )

    #expect(batch.results == [.malformed(.unsupportedAddressFamily(Int32.max))])
    #expect(
      batch.metricIncrements == [
        PacketFlowMetricIncrement(
          counterName: PacketFlowMetricName.forwardDropMalformed,
          amount: 1
        )
      ]
    )
  }

  @Test(
    "empty payloads and family/version mismatches are typed malformed packets",
    arguments: AdapterPlatform.allCases)
  func malformedPayloads(platform: AdapterPlatform) async throws {
    let batch = try await read(
      platform: platform,
      packets: [Data(), Data([0x60]), Data([0x45])],
      protocols: [AF_INET, AF_INET, AF_INET6]
    )

    #expect(
      batch.results == [
        .malformed(.emptyPayload(expectedFamily: .ipv4)),
        .malformed(.payloadVersionMismatch(expectedFamily: .ipv4, actualVersion: 6)),
        .malformed(.payloadVersionMismatch(expectedFamily: .ipv6, actualVersion: 4)),
      ]
    )
    #expect(batch.metricIncrements.first?.amount == 3)
  }

  @Test("AF_INET maps only an IPv4 payload", arguments: AdapterPlatform.allCases)
  func ipv4(platform: AdapterPlatform) async throws {
    let payload = Data([0x45, 0x10, 0x20])
    let batch = try await read(
      platform: platform,
      packets: [payload],
      protocols: [AF_INET]
    )

    #expect(
      batch.results == [
        .packet(TunnelPacket(payload: payload, addressFamily: .ipv4))
      ]
    )
  }

  @Test("AF_INET6 maps only an IPv6 payload", arguments: AdapterPlatform.allCases)
  func ipv6(platform: AdapterPlatform) async throws {
    let payload = Data([0x60, 0x10, 0x20])
    let batch = try await read(
      platform: platform,
      packets: [payload],
      protocols: [AF_INET6]
    )

    #expect(
      batch.results == [
        .packet(TunnelPacket(payload: payload, addressFamily: .ipv6))
      ]
    )
  }

  @Test(
    "writes preserve packet order and use public Darwin families",
    arguments: AdapterPlatform.allCases)
  func writeMapping(platform: AdapterPlatform) async throws {
    let driver = CallbackPacketFlowDriver()
    let adapter = platform.makeAdapter(driver: driver)
    let ipv4 = Data([0x45, 0x01])
    let ipv6 = Data([0x60, 0x02, 0x03])

    try await adapter.writePackets([
      TunnelPacket(payload: ipv4, addressFamily: .ipv4),
      TunnelPacket(payload: ipv6, addressFamily: .ipv6),
    ])

    #expect(
      driver.lastWrite()
        == .init(
          packets: [ipv4, ipv6],
          protocols: [AF_INET, AF_INET6]
        )
    )
  }

  @Test(
    "write rejection is the same typed error on both adapters", arguments: AdapterPlatform.allCases)
  func writeRejection(platform: AdapterPlatform) async {
    let driver = CallbackPacketFlowDriver(acceptWrites: false)
    let adapter = platform.makeAdapter(driver: driver)

    await #expect(throws: PacketFlowError.writeRejected) {
      try await adapter.writePackets([
        TunnelPacket(payload: Data([0x45]), addressFamily: .ipv4)
      ])
    }
  }

  @Test("cardinality metrics expose counts but no packet data")
  func cardinalityMetricsArePrivacySafe() {
    let error = PacketFlowError.packetProtocolCardinalityMismatch(
      packetCount: 2,
      protocolCount: 1
    )
    #expect(
      error.metricIncrements == [
        PacketFlowMetricIncrement(
          counterName: PacketFlowMetricName.forwardDropMalformed,
          amount: 2
        )
      ]
    )
  }

  private func read(
    platform: AdapterPlatform,
    packets: [Data],
    protocols: [Int32]
  ) async throws -> PacketReadBatch {
    let driver = CallbackPacketFlowDriver()
    let adapter = platform.makeAdapter(driver: driver)
    let read = Task { try await adapter.readPackets() }
    await driver.waitForRegistrationCount(1)
    driver.deliver(packets: packets, protocols: protocols)
    let batch = try await read.value
    #expect(driver.snapshot() == .init(registrationCount: 1, outstandingCount: 0))
    return batch
  }
}

enum AdapterPlatform: String, CaseIterable, Sendable, CustomTestStringConvertible {
  case iOS
  case macOS

  var testDescription: String { rawValue }

  func makeAdapter(driver: any PacketFlowPlatformDriver) -> any PacketFlow {
    switch self {
    case .iOS:
      IOSPacketFlowAdapter(driver: driver)
    case .macOS:
      MacOSPacketFlowAdapter(driver: driver)
    }
  }
}

private final class CallbackPacketFlowDriver: PacketFlowPlatformDriver, @unchecked Sendable {
  struct Write: Equatable {
    let packets: [Data]
    let protocols: [Int32]
  }

  struct Snapshot: Equatable {
    let registrationCount: Int
    let outstandingCount: Int
  }

  private struct RegistrationWaiter {
    let count: Int
    let continuation: CheckedContinuation<Void, Never>
  }

  private let lock = NSLock()
  private let acceptWrites: Bool
  private var callback: (@Sendable ([Data], [Int32]) -> Void)?
  private var recordedWrite: Write?
  private var registrationCount = 0
  private var registrationWaiters: [RegistrationWaiter] = []

  init(acceptWrites: Bool = true) {
    self.acceptWrites = acceptWrites
  }

  func registerRead(
    _ callback: @escaping @Sendable ([Data], [Int32]) -> Void
  ) {
    let readyWaiters: [RegistrationWaiter]

    lock.lock()
    precondition(self.callback == nil, "driver received overlapping registrations")
    self.callback = callback
    registrationCount += 1
    let partition = registrationWaiters.partitioned {
      $0.count <= registrationCount
    }
    readyWaiters = partition.matching
    registrationWaiters = partition.remaining
    lock.unlock()

    for waiter in readyWaiters {
      waiter.continuation.resume()
    }
  }

  func writePackets(_ packets: [Data], protocols: [Int32]) -> Bool {
    lock.lock()
    recordedWrite = Write(packets: packets, protocols: protocols)
    lock.unlock()
    return acceptWrites
  }

  func lastWrite() -> Write? {
    lock.lock()
    defer { lock.unlock() }
    return recordedWrite
  }

  func waitForRegistrationCount(_ expectedCount: Int) async {
    await withCheckedContinuation { continuation in
      lock.lock()
      if registrationCount >= expectedCount {
        lock.unlock()
        continuation.resume()
      } else {
        registrationWaiters.append(
          RegistrationWaiter(count: expectedCount, continuation: continuation)
        )
        lock.unlock()
      }
    }
  }

  func deliver(packets: [Data], protocols: [Int32]) {
    let callback: (@Sendable ([Data], [Int32]) -> Void)?

    lock.lock()
    callback = self.callback
    self.callback = nil
    lock.unlock()

    precondition(callback != nil, "driver has no callback to deliver")
    callback?(packets, protocols)
  }

  func snapshot() -> Snapshot {
    lock.lock()
    defer { lock.unlock() }
    return Snapshot(
      registrationCount: registrationCount,
      outstandingCount: callback == nil ? 0 : 1
    )
  }
}

extension Array {
  fileprivate func partitioned(
    matching predicate: (Element) -> Bool
  ) -> (matching: [Element], remaining: [Element]) {
    var matching: [Element] = []
    var remaining: [Element] = []
    for element in self {
      if predicate(element) {
        matching.append(element)
      } else {
        remaining.append(element)
      }
    }
    return (matching, remaining)
  }
}
