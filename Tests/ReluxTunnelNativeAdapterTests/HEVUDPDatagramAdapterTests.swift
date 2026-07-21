import Darwin
import Foundation
import ReluxTunnelCore
import Synchronization
import Testing

@testable import ReluxTunnelNativeAdapter

@Suite("Private HEV UDP datagram adapter")
struct HEVUDPDatagramAdapterTests {
  @Test("configuration rejects invalid time and queue limits")
  func configurationValidation() throws {
    let limits = testLimits()
    #expect(throws: HEVUDPDatagramAdapterConfigurationError.invalidIOTimeout) {
      try HEVUDPDatagramAdapterConfiguration(
        limits: limits,
        ioTimeoutMilliseconds: 0,
        admissionTimeoutMilliseconds: 1
      )
    }
    #expect(throws: HEVUDPDatagramAdapterConfigurationError.invalidAdmissionTimeout) {
      try HEVUDPDatagramAdapterConfiguration(
        limits: limits,
        ioTimeoutMilliseconds: 1,
        admissionTimeoutMilliseconds: 0
      )
    }
    #expect(throws: HEVUDPDatagramAdapterConfigurationError.invalidLimits) {
      try HEVUDPDatagramAdapterConfiguration(
        limits: testLimits(perAssociationQueuedBytes: 1),
        ioTimeoutMilliseconds: 1,
        admissionTimeoutMilliseconds: 1
      )
    }
  }

  @Test("split and coalesced records preserve families, domains, bytes, and association identity")
  func splitCoalescedBidirectionalAndMultipleAssociations() async throws {
    let relay = RecordingUDPRelay()
    let adapter = try makeAdapter(relay: relay, maximumAssociations: 4)
    let first = try await openHEVAssociation(adapter: adapter, requestFragments: [1, 2, 3, 4])
    defer { Darwin.close(first) }

    let ipv4 = try record(
      address: .ipv4(Data([192, 0, 2, 10])),
      port: 53,
      payload: Data([0, 1, 2, 3, 4])
    )
    for byte in ipv4 {
      try sendAll(Data([byte]), to: first)
    }
    let firstSubmission = await relay.next()
    #expect(firstSubmission.envelope.payload == ipv4)
    #expect(firstSubmission.envelope.associationID != 0)

    let domain = try record(
      address: .domain(Data("service.example".utf8)),
      port: 4_433,
      payload: Data("opaque-domain".utf8)
    )
    let ipv6 = try record(
      address: .ipv6(Data((0..<16).map(UInt8.init))),
      port: 9_999,
      payload: Data([0xff, 0x00, 0x7f])
    )
    var coalesced = domain
    coalesced.append(ipv6)
    try sendAll(coalesced, to: first)
    let domainSubmission = await relay.next()
    let ipv6Submission = await relay.next()
    #expect(domainSubmission.envelope.payload == domain)
    #expect(ipv6Submission.envelope.payload == ipv6)
    #expect(domainSubmission.envelope.associationID == firstSubmission.envelope.associationID)
    #expect(ipv6Submission.envelope.associationID == firstSubmission.envelope.associationID)

    let second = try await openHEVAssociation(adapter: adapter)
    defer { Darwin.close(second) }
    try sendAll(ipv6, to: second)
    let secondSubmission = await relay.next()
    #expect(secondSubmission.envelope.payload == ipv6)
    #expect(secondSubmission.envelope.associationID != firstSubmission.envelope.associationID)

    let response = RelayDatagram(
      endpoint: RelayDatagramEndpoint(
        address: .domain(Data("reply.example".utf8)),
        port: 8_443
      ),
      data: Data([9, 8, 7, 6])
    )
    #expect(
      await adapter.receiveRelayDatagram(
        associationID: firstSubmission.envelope.associationID,
        generation: 41,
        datagram: response
      ) == .delivered
    )
    let expectedResponse = try encoded(response)
    #expect(try await receiveExactly(expectedResponse.count, from: first) == expectedResponse)

    await adapter.cancel(generation: 41)
    #expect(try await receiveEOF(from: first))
    #expect(try await receiveEOF(from: second))
    let snapshot = await adapter.snapshot()
    #expect(snapshot.activeConnections == 0)
    #expect(snapshot.inboundQueuedBytes == 0)
    #expect(snapshot.outboundQueuedBytes == 0)
    #expect(snapshot.registry.associationCount == 0)
    #expect(snapshot.metrics.inputRecords == 4)
    #expect(snapshot.metrics.datagramsSubmitted == 4)
    #expect(snapshot.metrics.repliesDelivered == 1)
    #expect(snapshot.metrics.repliesDropped == 0)
  }

  @Test("reply local-cap drops survive while wire-oversize and invalid endpoints retire")
  func replyValidationConsequences() async throws {
    let relay = RecordingUDPRelay()
    let adapter = try makeAdapter(relay: relay, maximumPayload: 512)
    let peer = try await openHEVAssociation(adapter: adapter)
    defer { Darwin.close(peer) }
    let request = try record(
      address: .ipv4(Data([192, 0, 2, 20])),
      port: 53,
      payload: Data([1]),
      maximumPayload: 512
    )
    try sendAll(request, to: peer)
    let associationID = await relay.next().envelope.associationID
    let endpoint = RelayDatagramEndpoint(
      address: .ipv6(Data((0..<16).map(UInt8.init))),
      port: 8_443
    )

    #expect(
      await adapter.receiveRelayDatagram(
        associationID: associationID,
        generation: 41,
        datagram: RelayDatagram(
          endpoint: endpoint,
          data: Data(repeating: 0x11, count: 513)
        )
      ) == .oversized
    )
    let validReply = RelayDatagram(endpoint: endpoint, data: Data([9, 8, 7]))
    #expect(
      await adapter.receiveRelayDatagram(
        associationID: associationID,
        generation: 41,
        datagram: validReply
      ) == .delivered
    )
    let encodedReply = try encoded(validReply)
    #expect(try await receiveExactly(encodedReply.count, from: peer) == encodedReply)

    #expect(
      await adapter.receiveRelayDatagram(
        associationID: associationID,
        generation: 41,
        datagram: RelayDatagram(
          endpoint: endpoint,
          data: Data(repeating: 0x22, count: 1_473)
        )
      ) == .oversized
    )
    #expect(try await receiveEOF(from: peer))
    let close = await relay.next()
    #expect(close.envelope.type == .closeAssociation)
    #expect(close.envelope.associationID == associationID)

    let retiring = await adapter.snapshot()
    #expect(retiring.metrics.oversizedReplyDropped == 2)
    #expect(retiring.metrics.repliesDropped == 2)
    #expect(retiring.registry.closingAssociations == 1)
    _ = await adapter.receiveRelayClose(associationID: associationID, generation: 41)

    let invalidPeer = try await openHEVAssociation(adapter: adapter)
    defer { Darwin.close(invalidPeer) }
    try sendAll(request, to: invalidPeer)
    let invalidAssociationID = await relay.next().envelope.associationID
    #expect(
      await adapter.receiveRelayDatagram(
        associationID: invalidAssociationID,
        generation: 41,
        datagram: RelayDatagram(
          endpoint: RelayDatagramEndpoint(address: .ipv4(Data([192, 0, 2, 21])), port: 0),
          data: Data()
        )
      ) == .invalidDatagram
    )
    #expect(try await receiveEOF(from: invalidPeer))
    let invalidClose = await relay.next()
    #expect(invalidClose.envelope.type == .closeAssociation)
    #expect(invalidClose.envelope.associationID == invalidAssociationID)
    _ = await adapter.receiveRelayClose(
      associationID: invalidAssociationID,
      generation: 41
    )
    let baseline = await adapter.snapshot()
    #expect(baseline.activeConnections == 0)
    #expect(baseline.registry.associationCount == 0)
  }

  @Test("structural validation precedes bounded oversize skip and malformed input retires once")
  func oversizeLocalPolicyAndMalformedClose() async throws {
    let relay = RecordingUDPRelay()
    let adapter = try makeAdapter(relay: relay, maximumPayload: 512)
    let peer = try await openHEVAssociation(adapter: adapter)
    defer { Darwin.close(peer) }

    try sendAll(rawIPv4Record(payloadLength: 1_473, port: 53), to: peer)
    try sendAll(rawIPv4Record(payloadLength: 513, port: 53), to: peer)
    let valid = try record(
      address: .ipv4(Data([198, 51, 100, 7])),
      port: 53,
      payload: Data(repeating: 0x5a, count: 512),
      maximumPayload: 512
    )
    try sendAll(valid, to: peer)
    let submitted = await relay.next()
    #expect(submitted.envelope.payload == valid)

    let malformed = Data([0, 0, 10, 1, 192, 0, 2, 1, 0, 0])
    try sendAll(malformed, to: peer)
    let close = await relay.next()
    #expect(close.envelope.type == .closeAssociation)
    #expect(close.envelope.associationID == submitted.envelope.associationID)
    #expect(try await receiveEOF(from: peer))

    let beforeAck = await adapter.snapshot()
    #expect(beforeAck.metrics.hevOversizedInbound == 1)
    #expect(beforeAck.metrics.localPolicyInboundDropped == 1)
    #expect(beforeAck.metrics.malformedInbound == 1)
    #expect(beforeAck.registry.closingAssociations == 1)
    _ = await adapter.receiveRelayClose(
      associationID: submitted.envelope.associationID,
      generation: 41
    )
    let afterAck = await adapter.snapshot()
    #expect(afterAck.registry.associationCount == 0)
    #expect(afterAck.activeConnections == 0)
  }

  @Test("invalid HEV address types, header lengths, and ports never admit an association")
  func invalidRecordsDoNotAdmit() async throws {
    let invalidRecords = [
      Data([0, 0, 10, 0xff, 192, 0, 2, 1, 0, 53]),
      Data([0, 0, 9, 1, 192, 0, 2, 1, 0]),
      Data([0, 0, 10, 1, 192, 0, 2, 1, 0, 0]),
    ]

    for invalid in invalidRecords {
      let relay = RecordingUDPRelay()
      let adapter = try makeAdapter(relay: relay)
      let peer = try await openHEVAssociation(adapter: adapter)
      try sendAll(invalid, to: peer)
      #expect(try await receiveEOF(from: peer))
      Darwin.close(peer)

      let snapshot = await adapter.snapshot()
      #expect(snapshot.activeConnections == 0)
      #expect(snapshot.registry.associationCount == 0)
      #expect(snapshot.registry.metrics.admitted == 0)
      #expect(snapshot.metrics.malformedInbound == 1)
      #expect(relay.snapshot().isEmpty)
    }
  }

  @Test("relay errors, close, expiry, session loss, and stale callbacks close only their owner")
  func relayLifecycleOutcomes() async throws {
    let relay = RecordingUDPRelay()
    let clock = ManualUDPAdapterClock()
    let adapter = try makeAdapter(relay: relay, maximumAssociations: 4, clock: clock)

    let errorPeer = try await openHEVAssociation(adapter: adapter)
    defer { Darwin.close(errorPeer) }
    let request = try record(
      address: .ipv4(Data([203, 0, 113, 1])),
      port: 443,
      payload: Data([1])
    )
    try sendAll(request, to: errorPeer)
    let errorAssociation = await relay.next().envelope.associationID
    _ = await adapter.receiveRelayError(
      associationID: errorAssociation,
      generation: 41,
      error: .generated(.socketFailure)
    )
    #expect(try await receiveEOF(from: errorPeer))
    let errorClose = await relay.next()
    #expect(errorClose.envelope.type == .closeAssociation)
    _ = await adapter.receiveRelayClose(associationID: errorAssociation, generation: 41)

    let closePeer = try await openHEVAssociation(adapter: adapter)
    defer { Darwin.close(closePeer) }
    try sendAll(request, to: closePeer)
    let closeAssociation = await relay.next().envelope.associationID
    _ = await adapter.receiveRelayClose(associationID: closeAssociation, generation: 41)
    #expect(try await receiveEOF(from: closePeer))
    let closeAck = await relay.next()
    #expect(closeAck.envelope.type == .closeAssociation)
    #expect(closeAck.envelope.associationID == closeAssociation)

    let expiryPeer = try await openHEVAssociation(adapter: adapter)
    defer { Darwin.close(expiryPeer) }
    try sendAll(request, to: expiryPeer)
    let expiryAssociation = await relay.next().envelope.associationID
    await waitUntil { clock.pendingSleeps == 1 }
    clock.advance(by: .milliseconds(10_000))
    #expect(try await receiveEOF(from: expiryPeer))
    let expiryClose = await relay.next()
    #expect(expiryClose.envelope.associationID == expiryAssociation)
    _ = await adapter.receiveRelayClose(associationID: expiryAssociation, generation: 41)

    let sessionPeer = try await openHEVAssociation(adapter: adapter)
    defer { Darwin.close(sessionPeer) }
    try sendAll(request, to: sessionPeer)
    _ = await relay.next()
    await adapter.sessionLost(generation: 41)
    #expect(try await receiveEOF(from: sessionPeer))
    #expect(
      await adapter.receiveRelayDatagram(
        associationID: expiryAssociation,
        generation: 40,
        datagram: RelayDatagram(
          endpoint: RelayDatagramEndpoint(
            address: .ipv4(Data([192, 0, 2, 2])),
            port: 1
          ),
          data: Data()
        )
      ) == .staleGeneration
    )
    let snapshot = await adapter.snapshot()
    #expect(snapshot.activeConnections == 0)
    #expect(snapshot.registry.associationCount == 0)
    #expect(snapshot.metrics.remoteErrors == 1)
    #expect(snapshot.metrics.remoteCloses == 3)
    #expect(snapshot.metrics.lateCallbacks == 1)
  }

  @Test("relay pressure and lowered-cap errors preserve same-ID bidirectional traffic")
  func nonterminalRelayErrorsPreserveAssociation() async throws {
    for code in [
      RelayProtocolV1.UDPErrorCode.queueSaturated,
      .datagramTooLarge,
    ] {
      let relay = RecordingUDPRelay()
      let adapter = try makeAdapter(relay: relay)
      let peer = try await openHEVAssociation(adapter: adapter)
      let request = try record(
        address: .domain(Data("pressure.example".utf8)),
        port: 443,
        payload: Data([1, 2, 3])
      )
      try sendAll(request, to: peer)
      let first = await relay.next()

      let result = await adapter.receiveRelayError(
        associationID: first.envelope.associationID,
        generation: 41,
        error: .generated(code)
      )
      guard case .applied(let key, from: .active, to: .active) = result else {
        Issue.record("nonterminal relay error did not preserve active state")
        Darwin.close(peer)
        continue
      }
      #expect(key.associationID == first.envelope.associationID)
      #expect(relay.snapshot().isEmpty)

      try sendAll(request, to: peer)
      let continued = await relay.next()
      #expect(continued.envelope.associationID == first.envelope.associationID)
      #expect(continued.envelope.payload == request)

      let response = RelayDatagram(
        endpoint: RelayDatagramEndpoint(
          address: .ipv6(Data((0..<16).map(UInt8.init))),
          port: 8_443
        ),
        data: Data([9, 8, 7])
      )
      #expect(
        await adapter.receiveRelayDatagram(
          associationID: first.envelope.associationID,
          generation: 41,
          datagram: response
        ) == .delivered
      )
      let encodedResponse = try encoded(response)
      #expect(try await receiveExactly(encodedResponse.count, from: peer) == encodedResponse)

      let active = await adapter.snapshot()
      #expect(active.registry.activeAssociations == 1)
      #expect(active.metrics.remoteErrors == 1)
      #expect(
        active.metrics.remoteQueueSaturatedDropped
          == (code == .queueSaturated ? 1 : 0)
      )
      #expect(
        active.metrics.remoteDatagramTooLargeDropped
          == (code == .datagramTooLarge ? 1 : 0)
      )

      _ = await adapter.receiveRelayClose(
        associationID: first.envelope.associationID,
        generation: 41
      )
      #expect(try await receiveEOF(from: peer))
      Darwin.close(peer)
      let acknowledgement = await relay.next()
      #expect(acknowledgement.envelope.type == .closeAssociation)
      #expect(acknowledgement.envelope.associationID == first.envelope.associationID)
      let baseline = await adapter.snapshot()
      #expect(baseline.activeConnections == 0)
      #expect(baseline.registry.associationCount == 0)
      #expect(baseline.metrics.remoteCloses == 1)
      #expect(baseline.inboundQueuedBytes == 0)
      #expect(baseline.outboundQueuedBytes == 0)
    }
  }

  @Test(
    "nonterminal relay errors preserve the original idle deadline",
    arguments: [
      RelayProtocolV1.UDPErrorCode.queueSaturated,
      .datagramTooLarge,
    ]
  )
  func nonterminalRelayErrorsDoNotRefreshIdleActivity(
    code: RelayProtocolV1.UDPErrorCode
  ) async throws {
    let relay = RecordingUDPRelay()
    let clock = ManualUDPAdapterClock()
    let adapter = try makeAdapter(relay: relay, clock: clock)
    let peer = try await openHEVAssociation(adapter: adapter)
    defer { Darwin.close(peer) }
    let request = try record(
      address: .domain(Data("idle.example".utf8)),
      port: 443,
      payload: Data([1])
    )
    try sendAll(request, to: peer)
    let submission = await relay.next()
    await waitUntil { clock.pendingSleeps == 1 }

    let admitted = await adapter.snapshot()
    let originalDeadline = try #require(clock.onlyPendingDeadline)
    let originalTimerArms = clock.timerArms
    #expect(admitted.registry.metrics.activityUpdates == 1)
    #expect(admitted.registry.scheduledTimers == 1)

    clock.advance(by: .milliseconds(9_999))
    let result = await adapter.receiveRelayError(
      associationID: submission.envelope.associationID,
      generation: 41,
      error: .generated(code)
    )
    guard case .applied(let key, from: .active, to: .active) = result else {
      Issue.record("nonterminal relay error did not preserve active state")
      return
    }
    #expect(key.associationID == submission.envelope.associationID)

    let observed = await adapter.snapshot()
    #expect(observed.registry.metrics.activityUpdates == admitted.registry.metrics.activityUpdates)
    #expect(observed.registry.scheduledTimers == 1)
    #expect(clock.pendingSleeps == 1)
    #expect(clock.onlyPendingDeadline == originalDeadline)
    #expect(clock.timerArms == originalTimerArms)
    #expect(observed.metrics.remoteErrors == 1)
    #expect(
      observed.metrics.remoteQueueSaturatedDropped
        == (code == .queueSaturated ? 1 : 0)
    )
    #expect(
      observed.metrics.remoteDatagramTooLargeDropped
        == (code == .datagramTooLarge ? 1 : 0)
    )
    #expect(relay.snapshot().isEmpty)

    clock.advance(by: .milliseconds(1))
    #expect(try await receiveEOF(from: peer))
    let expiryClose = await relay.next()
    #expect(expiryClose.envelope.type == .closeAssociation)
    #expect(expiryClose.envelope.associationID == submission.envelope.associationID)
    _ = await adapter.receiveRelayClose(
      associationID: submission.envelope.associationID,
      generation: 41
    )

    let baseline = await adapter.snapshot()
    #expect(baseline.activeConnections == 0)
    #expect(baseline.registry.associationCount == 0)
    #expect(baseline.registry.metrics.activityUpdates == admitted.registry.metrics.activityUpdates)
    #expect(baseline.registry.metrics.idleExpired == 1)
    #expect(baseline.registry.metrics.terminalCleanups == 1)
    #expect(baseline.inboundQueuedBytes == 0)
    #expect(baseline.outboundQueuedBytes == 0)
    #expect(clock.pendingSleeps == 0)
  }

  @Test("terminal relay errors and close orderings clean each association exactly once")
  func terminalRelayErrorCloseOrderings() async throws {
    let relay = RecordingUDPRelay()
    let adapter = try makeAdapter(relay: relay, maximumAssociations: 4)
    let request = try record(
      address: .ipv4(Data([198, 51, 100, 25])),
      port: 53,
      payload: Data([1])
    )

    for error in [
      RelayRemoteAssociationError.generated(.socketFailure),
      .unknownRelayError,
    ] {
      let peer = try await openHEVAssociation(adapter: adapter)
      try sendAll(request, to: peer)
      let associationID = await relay.next().envelope.associationID
      _ = await adapter.receiveRelayError(
        associationID: associationID,
        generation: 41,
        error: error
      )
      #expect(try await receiveEOF(from: peer))
      Darwin.close(peer)
      let close = await relay.next()
      #expect(close.envelope.type == .closeAssociation)
      #expect(close.envelope.associationID == associationID)
      _ = await adapter.receiveRelayClose(associationID: associationID, generation: 41)
      #expect(relay.snapshot().isEmpty)
    }

    let closeFirstPeer = try await openHEVAssociation(adapter: adapter)
    try sendAll(request, to: closeFirstPeer)
    let closeFirstID = await relay.next().envelope.associationID
    _ = await adapter.receiveRelayClose(associationID: closeFirstID, generation: 41)
    #expect(try await receiveEOF(from: closeFirstPeer))
    Darwin.close(closeFirstPeer)
    let acknowledgement = await relay.next()
    #expect(acknowledgement.envelope.type == .closeAssociation)
    #expect(acknowledgement.envelope.associationID == closeFirstID)
    _ = await adapter.receiveRelayError(
      associationID: closeFirstID,
      generation: 41,
      error: .generated(.invalidDatagram)
    )

    let baseline = await adapter.snapshot()
    #expect(baseline.activeConnections == 0)
    #expect(baseline.registry.associationCount == 0)
    #expect(baseline.registry.metrics.hevCleanupCallbacks == 3)
    #expect(baseline.registry.metrics.relayCleanupCallbacks == 3)
    #expect(baseline.metrics.remoteErrors == 2)
    #expect(baseline.metrics.remoteCloses == 3)
    #expect(baseline.metrics.lateCallbacks == 1)
    #expect(baseline.inboundQueuedBytes == 0)
    #expect(baseline.outboundQueuedBytes == 0)
    #expect(relay.snapshot().isEmpty)
  }

  @Test("SOCKS admission rejects CONNECT and stalled pre-admission channels time out or cancel")
  func privateAdmissionTimeoutAndCancellation() async throws {
    let relay = RecordingUDPRelay()
    let adapter = try makeAdapter(
      relay: relay,
      ioTimeoutMilliseconds: 5,
      admissionTimeoutMilliseconds: 25
    )

    let rejected = try makeSocketPair()
    adapter.acceptAuthenticatedConnection(HEVSOCKSChannel(descriptor: rejected.adapter))
    try sendAll(Data([5, 1, 0, 1, 0, 0, 0, 0, 0, 0]), to: rejected.peer)
    #expect(try await receiveExactly(10, from: rejected.peer)[1] == 7)
    #expect(try await receiveEOF(from: rejected.peer))
    Darwin.close(rejected.peer)

    let timedOut = try makeSocketPair()
    adapter.acceptAuthenticatedConnection(HEVSOCKSChannel(descriptor: timedOut.adapter))
    #expect(try await receiveEOF(from: timedOut.peer))
    Darwin.close(timedOut.peer)

    let cancelled = try makeSocketPair()
    adapter.acceptAuthenticatedConnection(HEVSOCKSChannel(descriptor: cancelled.adapter))
    await adapter.cancel(generation: 41)
    #expect(try await receiveEOF(from: cancelled.peer))
    Darwin.close(cancelled.peer)

    let snapshot = await adapter.snapshot()
    #expect(snapshot.activeConnections == 0)
    #expect(snapshot.registry.associationCount == 0)
    #expect(snapshot.metrics.socksRequestsRejected == 1)
    #expect(snapshot.metrics.admissionTimeouts == 1)
    #expect(snapshot.metrics.cancellations == 1)
    #expect(relay.snapshot().isEmpty)

    let limitedRelay = RecordingUDPRelay()
    let limited = try makeAdapter(relay: limitedRelay, maximumAssociations: 1)
    let owner = try await openHEVAssociation(adapter: limited)
    defer { Darwin.close(owner) }
    let excess = try makeSocketPair()
    limited.acceptAuthenticatedConnection(HEVSOCKSChannel(descriptor: excess.adapter))
    #expect(try await receiveEOF(from: excess.peer))
    Darwin.close(excess.peer)
    await limited.cancel(generation: 41)
    #expect(try await receiveEOF(from: owner))
    #expect(await limited.snapshot().metrics.connectionAdmissionRejected == 1)
  }

  @Test("stale generation loss and cancellation cannot close current admitted or pending owners")
  func staleGenerationTerminalCallbacks() async throws {
    let relay = RecordingUDPRelay()
    let adapter = try makeAdapter(relay: relay, maximumAssociations: 2)
    let admitted = try await openHEVAssociation(adapter: adapter)
    defer { Darwin.close(admitted) }
    let request = try record(
      address: .domain(Data("stale.example".utf8)),
      port: 53,
      payload: Data([1])
    )
    try sendAll(request, to: admitted)
    let first = await relay.next()

    let pending = try makeSocketPair()
    defer { Darwin.close(pending.peer) }
    adapter.acceptAuthenticatedConnection(HEVSOCKSChannel(descriptor: pending.adapter))
    await adapter.sessionLost(generation: 40)
    await adapter.cancel(generation: 40)

    try sendAll(Data([5, 5, 0, 1, 0, 0, 0, 0, 0, 0]), to: pending.peer)
    #expect(
      try await receiveExactly(10, from: pending.peer)
        == Data([5, 0, 0, 1, 0, 0, 0, 0, 0, 0])
    )
    try sendAll(request, to: pending.peer)
    let pendingSubmission = await relay.next()
    #expect(pendingSubmission.envelope.associationID != first.envelope.associationID)

    try sendAll(request, to: admitted)
    let second = await relay.next()
    #expect(second.envelope.associationID == first.envelope.associationID)

    await adapter.cancel(generation: 41)
    #expect(try await receiveEOF(from: admitted))
    #expect(try await receiveEOF(from: pending.peer))
    let snapshot = await adapter.snapshot()
    #expect(snapshot.activeConnections == 0)
    #expect(snapshot.registry.associationCount == 0)
    #expect(snapshot.metrics.lateCallbacks == 2)
    #expect(snapshot.metrics.cancellations == 1)
  }

  @Test("relay and stalled HEV backpressure drop newest within both byte ceilings")
  func boundedBackpressure() async throws {
    let relay = RecordingUDPRelay()
    let adapter = try makeAdapter(
      relay: relay,
      perAssociationQueuedBytes: 4_096,
      aggregateQueuedBytes: 65_536,
      ioTimeoutMilliseconds: 5
    )
    let pair = try makeSocketPair(sendBufferBytes: 1_024)
    let peer = try await openHEVAssociation(adapter: adapter, pair: pair)
    defer { Darwin.close(peer) }
    let request = try record(
      address: .ipv4(Data([192, 0, 2, 8])),
      port: 53,
      payload: Data([1])
    )

    relay.setNextResult(.queueSaturated)
    try sendAll(request, to: peer)
    let associationID = await relay.next().envelope.associationID
    await waitUntil {
      await adapter.snapshot().metrics.relayQueueSaturatedDropped == 1
    }
    try sendAll(request, to: peer)
    _ = await relay.next()

    let response = RelayDatagram(
      endpoint: RelayDatagramEndpoint(
        address: .ipv6(Data(repeating: 0x20, count: 16)),
        port: 53
      ),
      data: Data(repeating: 0x44, count: 1_472)
    )
    var observedSaturation = false
    for _ in 0..<2_000 {
      if await adapter.receiveRelayDatagram(
        associationID: associationID,
        generation: 41,
        datagram: response
      ) == .outputQueueSaturated {
        observedSaturation = true
        break
      }
    }
    #expect(observedSaturation)
    let pressure = await adapter.snapshot()
    #expect(pressure.inboundQueuedBytes <= 65_536)
    #expect(pressure.outboundQueuedBytes <= 65_536)
    #expect(pressure.metrics.outputQueueSaturatedDropped > 0)

    await adapter.cancel(generation: 41)
    #expect(try await receiveEOF(from: peer))
    let baseline = await adapter.snapshot()
    #expect(baseline.activeConnections == 0)
    #expect(baseline.inboundQueuedBytes == 0)
    #expect(baseline.outboundQueuedBytes == 0)
  }
}

private struct RecordedUDPSubmission: Sendable {
  let envelope: RelayEnvelope
  let generation: UInt64
}

private final class RecordingUDPRelay: HEVUDPRelaySink, @unchecked Sendable {
  private struct State {
    var submissions: [RecordedUDPSubmission] = []
    var waiters: [CheckedContinuation<RecordedUDPSubmission, Never>] = []
    var nextResult = HEVUDPRelaySubmissionResult.accepted
  }

  private let state = Mutex(State())

  func submit(
    _ envelope: RelayEnvelope,
    generation: UInt64
  ) -> HEVUDPRelaySubmissionResult {
    let submission = RecordedUDPSubmission(envelope: envelope, generation: generation)
    let effect = state.withLock {
      state -> (
        HEVUDPRelaySubmissionResult,
        CheckedContinuation<RecordedUDPSubmission, Never>?
      ) in
      let result = state.nextResult
      state.nextResult = .accepted
      if state.waiters.isEmpty {
        state.submissions.append(submission)
        return (result, nil)
      }
      return (result, state.waiters.removeFirst())
    }
    effect.1?.resume(returning: submission)
    return effect.0
  }

  func next() async -> RecordedUDPSubmission {
    await withCheckedContinuation { continuation in
      let immediate = state.withLock { state -> RecordedUDPSubmission? in
        guard !state.submissions.isEmpty else {
          state.waiters.append(continuation)
          return nil
        }
        return state.submissions.removeFirst()
      }
      if let immediate { continuation.resume(returning: immediate) }
    }
  }

  func setNextResult(_ result: HEVUDPRelaySubmissionResult) {
    state.withLock { $0.nextResult = result }
  }

  func snapshot() -> [RecordedUDPSubmission] {
    state.withLock(\.submissions)
  }
}

private final class ManualUDPAdapterClock: TunnelClock, @unchecked Sendable {
  private struct Sleep {
    let deadline: ContinuousClock.Instant
    let continuation: CheckedContinuation<Void, any Error>
  }

  private struct State {
    var instant = ContinuousClock().now
    var sleeps: [UUID: Sleep] = [:]
    var timerArms: UInt64 = 0
  }

  private let state = Mutex(State())

  var pendingSleeps: Int { state.withLock { $0.sleeps.count } }
  var onlyPendingDeadline: ContinuousClock.Instant? {
    state.withLock { state in
      guard state.sleeps.count == 1 else { return nil }
      return state.sleeps.values.first?.deadline
    }
  }
  var timerArms: UInt64 { state.withLock(\.timerArms) }

  func now() -> ContinuousClock.Instant {
    state.withLock(\.instant)
  }

  func sleep(for duration: Duration) async throws {
    let identifier = UUID()
    try Task<Never, Never>.checkCancellation()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let cancelled = state.withLock { state in
          if Task<Never, Never>.isCancelled { return true }
          state.sleeps[identifier] = Sleep(
            deadline: state.instant.advanced(by: duration),
            continuation: continuation
          )
          state.timerArms += 1
          return false
        }
        if cancelled { continuation.resume(throwing: CancellationError()) }
      }
    } onCancel: {
      let continuation = self.state.withLock {
        $0.sleeps.removeValue(forKey: identifier)?.continuation
      }
      continuation?.resume(throwing: CancellationError())
    }
  }

  func advance(by duration: Duration) {
    let continuations = state.withLock { state -> [CheckedContinuation<Void, any Error>] in
      state.instant = state.instant.advanced(by: duration)
      let ready = state.sleeps.filter { $0.value.deadline <= state.instant }
      for identifier in ready.keys { state.sleeps.removeValue(forKey: identifier) }
      return ready.values.map(\.continuation)
    }
    for continuation in continuations { continuation.resume() }
  }
}

private func makeAdapter(
  relay: RecordingUDPRelay,
  maximumPayload: UInt16 = 1_472,
  maximumAssociations: UInt32 = 8,
  perAssociationQueuedBytes: UInt32 = 32_768,
  aggregateQueuedBytes: UInt32 = 65_536,
  ioTimeoutMilliseconds: UInt32 = 25,
  admissionTimeoutMilliseconds: UInt32 = 250,
  clock: any TunnelClock = ContinuousTunnelClock()
) throws -> HEVUDPDatagramAdapter {
  let limits = testLimits(
    maximumPayload: maximumPayload,
    maximumAssociations: maximumAssociations,
    perAssociationQueuedBytes: perAssociationQueuedBytes,
    aggregateQueuedBytes: aggregateQueuedBytes
  )
  return try HEVUDPDatagramAdapter(
    generation: 41,
    configuration: HEVUDPDatagramAdapterConfiguration(
      limits: limits,
      ioTimeoutMilliseconds: ioTimeoutMilliseconds,
      admissionTimeoutMilliseconds: admissionTimeoutMilliseconds
    ),
    relay: relay,
    clock: clock
  )
}

private func testLimits(
  maximumPayload: UInt16 = 1_472,
  maximumAssociations: UInt32 = 8,
  perAssociationQueuedBytes: UInt32 = 32_768,
  aggregateQueuedBytes: UInt32 = 65_536
) -> RelayEffectiveLimits {
  RelayEffectiveLimits(
    effectiveMaxFrame: 4_096,
    maxUDPPayload: maximumPayload,
    maxAssociations: maximumAssociations,
    perAssociationQueuedBytes: perAssociationQueuedBytes,
    aggregateQueuedBytes: aggregateQueuedBytes,
    controlReservedBytes: 4_096,
    dnsPriorityWeight: 4,
    idleTimeoutMilliseconds: 10_000
  )
}

private struct TestSocketPair {
  let adapter: Int32
  let peer: Int32
}

private func makeSocketPair(sendBufferBytes: Int32? = nil) throws -> TestSocketPair {
  var descriptors = [Int32](repeating: -1, count: 2)
  guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else {
    throw UDPAdapterTestError.systemCall(errno)
  }
  if var sendBufferBytes {
    guard
      setsockopt(
        descriptors[0],
        SOL_SOCKET,
        SO_SNDBUF,
        &sendBufferBytes,
        socklen_t(MemoryLayout.size(ofValue: sendBufferBytes))
      ) == 0
    else {
      Darwin.close(descriptors[0])
      Darwin.close(descriptors[1])
      throw UDPAdapterTestError.systemCall(errno)
    }
  }
  return TestSocketPair(adapter: descriptors[0], peer: descriptors[1])
}

private func openHEVAssociation(
  adapter: HEVUDPDatagramAdapter,
  requestFragments: [Int] = [10],
  pair: TestSocketPair? = nil
) async throws -> Int32 {
  let pair = try pair ?? makeSocketPair()
  adapter.acceptAuthenticatedConnection(HEVSOCKSChannel(descriptor: pair.adapter))
  let request = Data([5, 5, 0, 1, 0, 0, 0, 0, 0, 0])
  var offset = 0
  for size in requestFragments where offset < request.count {
    let end = min(offset + size, request.count)
    try sendAll(Data(request[offset..<end]), to: pair.peer)
    offset = end
  }
  if offset < request.count {
    try sendAll(Data(request[offset...]), to: pair.peer)
  }
  #expect(try await receiveExactly(10, from: pair.peer) == Data([5, 0, 0, 1, 0, 0, 0, 0, 0, 0]))
  return pair.peer
}

private func record(
  address: RelayDatagramAddress,
  port: UInt16,
  payload: Data,
  maximumPayload: UInt16 = 1_472
) throws -> Data {
  var codec = try RelayDatagramCodec(maximumPayloadLength: maximumPayload)
  return try codec.encode(
    RelayDatagram(
      endpoint: RelayDatagramEndpoint(address: address, port: port),
      data: payload
    )
  )
}

private func encoded(_ datagram: RelayDatagram) throws -> Data {
  var codec = try RelayDatagramCodec()
  return try codec.encode(datagram)
}

private func rawIPv4Record(payloadLength: Int, port: UInt16) -> Data {
  var data = Data([
    UInt8(truncatingIfNeeded: payloadLength >> 8),
    UInt8(truncatingIfNeeded: payloadLength),
    10,
    1,
    192,
    0,
    2,
    1,
    UInt8(truncatingIfNeeded: port >> 8),
    UInt8(truncatingIfNeeded: port),
  ])
  data.append(Data(repeating: 0x78, count: payloadLength))
  return data
}

private func sendAll(_ data: Data, to descriptor: Int32) throws {
  var offset = 0
  while offset < data.count {
    let sent = data.withUnsafeBytes { buffer in
      Darwin.send(descriptor, buffer.baseAddress! + offset, data.count - offset, 0)
    }
    if sent > 0 {
      offset += sent
    } else if sent < 0, errno == EINTR {
      continue
    } else {
      throw UDPAdapterTestError.systemCall(sent == 0 ? EPIPE : errno)
    }
  }
}

private func receiveExactly(_ count: Int, from descriptor: Int32) async throws -> Data {
  try await blockingIO {
    var data = Data(repeating: 0, count: count)
    var offset = 0
    while offset < count {
      let received = data.withUnsafeMutableBytes { buffer in
        Darwin.recv(descriptor, buffer.baseAddress! + offset, count - offset, 0)
      }
      if received > 0 {
        offset += received
      } else if received < 0, errno == EINTR {
        continue
      } else {
        throw UDPAdapterTestError.systemCall(received == 0 ? ECONNRESET : errno)
      }
    }
    return data
  }
}

private func receiveEOF(from descriptor: Int32) async throws -> Bool {
  try await blockingIO {
    var byte: UInt8 = 0
    while true {
      let received = Darwin.recv(descriptor, &byte, 1, 0)
      if received == 0 { return true }
      if received > 0 { continue }
      if received < 0, errno == EINTR { continue }
      if received < 0, errno == ECONNRESET { return true }
      if received < 0 { throw UDPAdapterTestError.systemCall(errno) }
    }
  }
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

private func waitUntil(
  _ predicate: @escaping @Sendable () async -> Bool
) async {
  for _ in 0..<10_000 {
    if await predicate() { return }
    await Task.yield()
  }
  Issue.record("condition did not become true")
}

private enum UDPAdapterTestError: Error {
  case systemCall(Int32)
}
