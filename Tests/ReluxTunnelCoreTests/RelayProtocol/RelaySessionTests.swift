import Foundation
import Testing

@testable import ReluxTunnelCore

@Suite("RelayProtocol v1 session semantics")
struct RelayProtocolSessionTests {
  typealias P = RelayProtocolV1

  @Test("transition table covers every generated v1 message")
  func transitionTable() {
    let table = RelaySessionTransitions.v1
    #expect(table.count == P.MessageType.allCases.count)
    #expect(Set(table.map(\.type)) == Set(P.MessageType.allCases))

    for metadata in P.messageMetadata {
      let transition = table.first { $0.type == metadata.type }
      #expect(transition?.direction == metadata.direction)
      #expect(transition?.associationID == metadata.associationID)
      if metadata.payloadShape == .fixed {
        #expect(transition?.minimumPayloadBytes == metadata.fixedPayloadWidth)
        #expect(transition?.maximumPayloadBytes == metadata.fixedPayloadWidth)
      } else {
        #expect(transition?.minimumPayloadBytes == 0)
        #expect(transition?.maximumPayloadBytes == P.maxHEVRecordWidth)
      }
    }

    #expect(transition(.udpDatagram)?.response == .generatedUDPErrorOnFailure)
    #expect(
      transition(.udpDatagram)?.closeEffect == .closeAssociationOnMalformedDatagram
    )
    #expect(transition(.udpError)?.closeEffect == .recordAssociationError)
    #expect(transition(.ping)?.response == .echoPong)
    #expect(transition(.closeAssociation)?.response == .closeAssociationAcknowledgement)
    #expect(transition(.closeSession)?.response == .closeSessionAcknowledgement)
  }

  @Test("paired peers exchange datagrams PING PONG and finite UDP errors")
  func pairedNominalFlow() throws {
    var client = try makeSession(peer: .client, generation: 10)
    var relay = try makeSession(peer: .relay, generation: 10)
    let token = Data([0, 1, 2, 3, 4, 5, 6, 7])

    let ping = client.send(
      RelayEnvelope(type: .ping, associationID: 0, payload: token),
      generation: 10
    )
    #expect(ping.outbound.count == 1)
    let pong = relay.receive(ping.outbound[0], generation: 10)
    #expect(pong.outbound == [RelayEnvelope(type: .pong, associationID: 0, payload: token)])
    let observedPong = client.receive(pong.outbound[0], generation: 10)
    #expect(observedPong.events == [.pong(token)])

    let payload = try validDatagramPayload(data: Data([0xCA, 0xFE]))
    let request = client.send(
      RelayEnvelope(type: .udpDatagram, associationID: 7, payload: payload),
      generation: 10
    )
    let relayRequest = relay.receive(request.outbound[0], generation: 10)
    #expect(relayRequest.events.count == 1)
    let response = relay.send(
      RelayEnvelope(type: .udpDatagram, associationID: 7, payload: payload),
      generation: 10
    )
    let clientResponse = client.receive(response.outbound[0], generation: 10)
    #expect(clientResponse.events.count == 1)

    let relayError = relay.reportAssociationFailure(
      associationID: 7,
      code: .socketFailure,
      closeAssociation: false,
      generation: 10
    )
    #expect(relayError.outbound[0].payload == Data([0, 8]))
    let clientError = client.receive(relayError.outbound[0], generation: 10)
    #expect(
      clientError.events == [
        .udpError(associationID: 7, .generated(.socketFailure))
      ]
    )

    let unknown = client.receive(
      RelayEnvelope(
        type: .udpError,
        associationID: 7,
        payload: Data([0xFF, 0xFF])
      ),
      generation: 10
    )
    #expect(
      unknown.events == [
        .udpError(associationID: 7, .unknownRelayError)
      ]
    )
    #expect(client.metrics.udpErrorsReceived == 2)
    #expect(relay.metrics.udpErrorsSent == 1)
    #expect(client.metrics.datagramsAccepted == relay.metrics.datagramsAccepted)
  }

  @Test("invalid first datagrams do not admit association state")
  func malformedDatagramScope() throws {
    let clientCleanup = CleanupRecorder()
    let relayCleanup = CleanupRecorder()
    var client = try makeSession(
      peer: .client,
      generation: 20,
      associationCleanup: clientCleanup.associationCallback
    )
    var relay = try makeSession(
      peer: .relay,
      generation: 20,
      associationCleanup: relayCleanup.associationCallback
    )
    let malformed = Data([0x00, 0x00, 0x07, 0x03, 0x00])
    _ = client.send(
      RelayEnvelope(
        type: .udpDatagram,
        associationID: 9,
        payload: try validDatagramPayload(data: Data())
      ),
      generation: 20
    )
    let rejection = relay.receive(
      RelayEnvelope(type: .udpDatagram, associationID: 9, payload: malformed),
      generation: 20
    )

    #expect(rejection.state == .active)
    #expect(rejection.outbound.map(\.type) == [.udpError, .closeAssociation])
    #expect(rejection.outbound[0].payload == Data([0, 1]))
    #expect(rejection.outbound[0].payload.count == 2)
    #expect(relayCleanup.associations.isEmpty)

    let error = client.receive(rejection.outbound[0], generation: 20)
    #expect(error.events == [.udpError(associationID: 9, .generated(.invalidDatagram))])
    let closeAck = client.receive(rejection.outbound[1], generation: 20)
    #expect(closeAck.outbound.map(\.type) == [.closeAssociation])
    #expect(clientCleanup.associations == [(20 << 32) | 9])
    let retired = relay.receive(closeAck.outbound[0], generation: 20)
    #expect(retired.outbound.isEmpty)
    #expect(relay.receive(closeAck.outbound[0], generation: 20).outbound.isEmpty)
    #expect(relayCleanup.associations.isEmpty)

    let protocolCleanup = CleanupRecorder()
    var protocolRelay = try makeSession(
      peer: .relay,
      generation: 22,
      associationCleanup: protocolCleanup.associationCallback
    )
    let protocolOversized = protocolRelay.receive(
      RelayEnvelope(
        type: .udpDatagram,
        associationID: 12,
        payload: oversizedDatagramPayload(
          dataLength: Int(P.maxUDPPayloadClientHardCeiling) + 1
        )
      ),
      generation: 22
    )
    #expect(protocolOversized.events.isEmpty)
    #expect(protocolOversized.outbound.map(\.type) == [.udpError, .closeAssociation])
    #expect(protocolOversized.outbound.first?.payload == Data([0, 5]))
    #expect(protocolCleanup.associations.isEmpty)

    var dropClient = try makeSession(peer: .client, generation: 21)
    var dropRelay = try makeSession(
      peer: .relay,
      generation: 21,
      maximumUDPPayload: P.maxUDPPayloadFloor
    )
    let oversizedLocalPayload = try validDatagramPayload(
      data: Data(repeating: 0xA5, count: Int(P.maxUDPPayloadFloor) + 1)
    )
    let oversized = dropClient.send(
      RelayEnvelope(
        type: .udpDatagram,
        associationID: 10,
        payload: oversizedLocalPayload
      ),
      generation: 21
    )
    let drop = dropRelay.receive(oversized.outbound[0], generation: 21)
    #expect(drop.outbound.map(\.type) == [.udpError])
    #expect(drop.outbound[0].payload == Data([0, 5]))
    #expect(dropRelay.metrics.associationCleanups == 0)
    _ = dropRelay.closeSession(generation: 21)
    _ = protocolRelay.closeSession(generation: 22)
    #expect(dropRelay.metrics.associationCleanups == 0)
    #expect(protocolCleanup.associations.isEmpty)
  }

  @Test("outbound datagrams are structurally and locally bounded for both peers")
  func outboundDatagramValidation() throws {
    let malformed = Data()
    let protocolOversized = oversizedDatagramPayload(
      dataLength: Int(P.maxUDPPayloadClientHardCeiling) + 1
    )
    let localCapOversized = try validDatagramPayload(
      data: Data(repeating: 0xA5, count: Int(P.maxUDPPayloadFloor) + 1)
    )

    for (peerIndex, peer) in [RelaySessionPeer.client, .relay].enumerated() {
      for (caseIndex, test) in [
        (malformed, P.maxUDPPayloadClientDefault),
        (protocolOversized, P.maxUDPPayloadClientDefault),
        (localCapOversized, P.maxUDPPayloadFloor),
      ].enumerated() {
        let generation = UInt64(100 + peerIndex * 10 + caseIndex)
        var session = try makeSession(
          peer: peer,
          generation: generation,
          maximumUDPPayload: test.1
        )
        let valid = try validDatagramPayload(data: Data())
        if peer == .client {
          #expect(
            session.send(
              RelayEnvelope(type: .udpDatagram, associationID: 99, payload: valid),
              generation: generation
            ).outbound.count == 1
          )
        } else {
          #expect(
            session.receive(
              RelayEnvelope(type: .udpDatagram, associationID: 99, payload: valid),
              generation: generation
            ).events.count == 1
          )
        }
        let before = session.metrics

        let rejected = session.send(
          RelayEnvelope(type: .udpDatagram, associationID: 99, payload: test.0),
          generation: generation
        )
        #expect(rejected.state == .active)
        #expect(rejected.failure == nil)
        #expect(rejected.outbound.isEmpty)
        #expect(session.metrics.datagramsRejected == before.datagramsRejected + 1)
        #expect(session.metrics.sentFrames == before.sentFrames)
      }
    }
  }

  @Test("association ownership rejects unsolicited and unknown relay replies")
  func associationOwnership() throws {
    let clientCleanup = CleanupRecorder()
    let relayCleanup = CleanupRecorder()
    var client = try makeSession(
      peer: .client,
      generation: 105,
      associationCleanup: clientCleanup.associationCallback
    )
    var relay = try makeSession(
      peer: .relay,
      generation: 105,
      associationCleanup: relayCleanup.associationCallback
    )
    let payload = try validDatagramPayload(data: Data())

    let localUnknownReply = relay.send(
      RelayEnvelope(type: .udpDatagram, associationID: 44, payload: payload),
      generation: 105
    )
    #expect(localUnknownReply.outbound.isEmpty)
    #expect(
      relay.reportAssociationFailure(
        associationID: 44,
        code: .socketFailure,
        closeAssociation: true,
        generation: 105
      ).outbound.isEmpty
    )

    let unsolicited = client.receive(
      RelayEnvelope(type: .udpDatagram, associationID: 44, payload: payload),
      generation: 105
    )
    #expect(unsolicited.events.isEmpty)
    #expect(unsolicited.outbound.map(\.type) == [.closeAssociation])
    #expect(clientCleanup.associations.isEmpty)
    #expect(relay.receive(unsolicited.outbound[0], generation: 105).outbound.isEmpty)
    #expect(relayCleanup.associations.isEmpty)

    let request = client.send(
      RelayEnvelope(type: .udpDatagram, associationID: 44, payload: payload),
      generation: 105
    )
    #expect(request.outbound.count == 1)
    #expect(relay.receive(request.outbound[0], generation: 105).events.count == 1)
    let response = relay.send(
      RelayEnvelope(type: .udpDatagram, associationID: 44, payload: payload),
      generation: 105
    )
    #expect(response.outbound.count == 1)
    #expect(client.receive(response.outbound[0], generation: 105).events.count == 1)

    let relayClose = relay.closeAssociation(44, generation: 105)
    #expect(
      relay.send(
        RelayEnvelope(type: .udpDatagram, associationID: 44, payload: payload),
        generation: 105
      ).outbound.isEmpty
    )
    let clientAck = client.receive(relayClose.outbound[0], generation: 105)
    _ = relay.receive(clientAck.outbound[0], generation: 105)
    let lateReply = client.receive(
      RelayEnvelope(type: .udpDatagram, associationID: 44, payload: payload),
      generation: 105
    )
    #expect(lateReply.events.isEmpty)
    #expect(lateReply.outbound.isEmpty)

    #expect(client.metrics.datagramsRejected == 2)
    #expect(relay.metrics.datagramsRejected == 2)
    #expect(client.metrics.associationClosesSent == relay.metrics.associationClosesReceived)
    #expect(relay.metrics.associationClosesSent == client.metrics.associationClosesReceived)

    let close = client.closeSession(generation: 105)
    let acknowledgement = relay.receive(close.outbound[0], generation: 105)
    _ = client.receive(acknowledgement.outbound[0], generation: 105)
    #expect(clientCleanup.associations == [(105 << 32) | 44])
    #expect(relayCleanup.associations == [(105 << 32) | 44])
  }

  @Test("max association credit bounds unique IDs and permits retired reuse")
  func maximumAssociationAdmission() throws {
    let clientCleanup = CleanupRecorder()
    let relayCleanup = CleanupRecorder()
    var client = try makeSession(
      peer: .client,
      generation: 106,
      associationCleanup: clientCleanup.associationCallback
    )
    var relay = try makeSession(
      peer: .relay,
      generation: 106,
      maximumAssociations: 2,
      associationCleanup: relayCleanup.associationCallback
    )
    let payload = try validDatagramPayload(data: Data())

    for associationID: UInt32 in 1...2 {
      let request = client.send(
        RelayEnvelope(
          type: .udpDatagram,
          associationID: associationID,
          payload: payload
        ),
        generation: 106
      )
      #expect(relay.receive(request.outbound[0], generation: 106).events.count == 1)
    }

    let floodedIDs: ClosedRange<UInt32> = 3...8
    for associationID in floodedIDs {
      let request = client.send(
        RelayEnvelope(
          type: .udpDatagram,
          associationID: associationID,
          payload: payload
        ),
        generation: 106
      )
      let rejection = relay.receive(request.outbound[0], generation: 106)
      #expect(rejection.events.isEmpty)
      #expect(rejection.outbound.map(\.type) == [.udpError, .closeAssociation])
      #expect(rejection.outbound[0].payload == Data([0, 4]))
      #expect(
        client.receive(rejection.outbound[0], generation: 106).events == [
          .udpError(associationID: associationID, .generated(.associationLimit))
        ]
      )
      let acknowledgement = client.receive(rejection.outbound[1], generation: 106)
      #expect(acknowledgement.outbound.map(\.type) == [.closeAssociation])
      #expect(relay.receive(acknowledgement.outbound[0], generation: 106).outbound.isEmpty)
    }
    #expect(relayCleanup.associations.isEmpty)

    let clientClose = client.closeAssociation(1, generation: 106)
    let relayAck = relay.receive(clientClose.outbound[0], generation: 106)
    _ = client.receive(relayAck.outbound[0], generation: 106)
    #expect(relayCleanup.associations == [(106 << 32) | 1])

    let reused = client.send(
      RelayEnvelope(type: .udpDatagram, associationID: 3, payload: payload),
      generation: 106
    )
    #expect(reused.outbound.count == 1)
    #expect(relay.receive(reused.outbound[0], generation: 106).events.count == 1)

    let floodCount = UInt64(floodedIDs.count)
    #expect(relay.metrics.datagramsAccepted == 3)
    #expect(relay.metrics.datagramsRejected == floodCount)
    #expect(relay.metrics.udpErrorsSent == client.metrics.udpErrorsReceived)
    #expect(relay.metrics.udpErrorsSent == floodCount)
    #expect(
      relay.metrics.associationClosesSent == client.metrics.associationClosesReceived
    )
    #expect(
      client.metrics.associationClosesSent == relay.metrics.associationClosesReceived
    )

    let close = client.closeSession(generation: 106)
    let acknowledgement = relay.receive(close.outbound[0], generation: 106)
    _ = client.receive(acknowledgement.outbound[0], generation: 106)
    #expect(relayCleanup.associations.count == 3)
    #expect(
      Set(relayCleanup.associations) == Set([1, 2, 3].map { (106 << 32) | $0 })
    )
    #expect(clientCleanup.associations.count == floodedIDs.count + 3)

    var limitedClient = try makeSession(
      peer: .client,
      generation: 107,
      maximumAssociations: 1
    )
    #expect(
      limitedClient.send(
        RelayEnvelope(type: .udpDatagram, associationID: 1, payload: payload),
        generation: 107
      ).outbound.count == 1
    )
    #expect(
      limitedClient.send(
        RelayEnvelope(type: .udpDatagram, associationID: 2, payload: payload),
        generation: 107
      ).outbound.isEmpty
    )
  }

  @Test("queue saturation is edge-triggered and idle expiry is error retire close")
  func boundedFailurePolicies() throws {
    let payload = try validDatagramPayload(data: Data())
    var saturationRelay = try makeSession(peer: .relay, generation: 110)
    _ = saturationRelay.receive(
      RelayEnvelope(type: .udpDatagram, associationID: 7, payload: payload),
      generation: 110
    )

    let first = saturationRelay.reportQueueSaturation(associationID: 7, generation: 110)
    let duplicate = saturationRelay.reportQueueSaturation(associationID: 7, generation: 110)
    _ = saturationRelay.recordAssociationQueueDepth(
      associationID: 7,
      queuedBytes: (P.perAssociationQueuedBytesClientDefault / 2) + 1,
      generation: 110
    )
    let stillSaturated = saturationRelay.reportQueueSaturation(
      associationID: 7,
      generation: 110
    )
    _ = saturationRelay.recordAssociationQueueDepth(
      associationID: 7,
      queuedBytes: P.perAssociationQueuedBytesClientDefault / 2,
      generation: 110
    )
    let nextEpisode = saturationRelay.reportQueueSaturation(
      associationID: 7,
      generation: 110
    )
    #expect(first.outbound.map(\.payload) == [Data([0, 6])])
    #expect(duplicate.outbound.isEmpty)
    #expect(stillSaturated.outbound.isEmpty)
    #expect(nextEpisode.outbound.map(\.payload) == [Data([0, 6])])
    #expect(saturationRelay.metrics.datagramsRejected == 4)
    #expect(saturationRelay.metrics.udpErrorsSent == 2)

    for code in [P.UDPErrorCode.queueSaturated, .idleExpiry] {
      var generic = try makeSession(peer: .relay, generation: UInt64(111 + code.rawValue))
      let rejected = generic.reportAssociationFailure(
        associationID: 7,
        code: code,
        closeAssociation: false,
        generation: UInt64(111 + code.rawValue)
      )
      #expect(rejected.failure?.code == .metadataRejected)
      #expect(rejected.outbound.isEmpty)
    }

    let relayCleanup = CleanupRecorder()
    var client = try makeSession(peer: .client, generation: 120)
    var relay = try makeSession(
      peer: .relay,
      generation: 120,
      associationCleanup: relayCleanup.associationCallback
    )
    let opening = client.send(
      RelayEnvelope(type: .udpDatagram, associationID: 8, payload: payload),
      generation: 120
    )
    _ = relay.receive(opening.outbound[0], generation: 120)
    let expiry = relay.reportIdleExpiry(associationID: 8, generation: 120)
    #expect(expiry.outbound.map(\.type) == [.udpError, .closeAssociation])
    #expect(expiry.outbound[0].payload == Data([0, 9]))
    #expect(relayCleanup.associations == [(120 << 32) | 8])
    #expect(relay.reportIdleExpiry(associationID: 8, generation: 120).outbound.isEmpty)

    _ = client.receive(expiry.outbound[0], generation: 120)
    let acknowledgement = client.receive(expiry.outbound[1], generation: 120)
    _ = relay.receive(acknowledgement.outbound[0], generation: 120)
    #expect(relay.metrics.udpErrorsSent == client.metrics.udpErrorsReceived)
    #expect(relay.metrics.associationClosesSent == client.metrics.associationClosesReceived)
    #expect(client.metrics.associationClosesSent == relay.metrics.associationClosesReceived)
  }

  @Test("duplicate crossed association closes clean up once and permit ordered reuse")
  func crossedAssociationClose() throws {
    let clientCleanup = CleanupRecorder()
    let relayCleanup = CleanupRecorder()
    var client = try makeSession(
      peer: .client,
      generation: 30,
      associationCleanup: clientCleanup.associationCallback
    )
    var relay = try makeSession(
      peer: .relay,
      generation: 30,
      associationCleanup: relayCleanup.associationCallback
    )
    let payload = try validDatagramPayload(data: Data())
    let opening = client.send(
      RelayEnvelope(type: .udpDatagram, associationID: 11, payload: payload),
      generation: 30
    )
    _ = relay.receive(opening.outbound[0], generation: 30)

    let clientClose = client.closeAssociation(11, generation: 30)
    let relayClose = relay.closeAssociation(11, generation: 30)
    #expect(clientClose.outbound.count == 1)
    #expect(relayClose.outbound.count == 1)
    #expect(client.receive(relayClose.outbound[0], generation: 30).outbound.isEmpty)
    #expect(relay.receive(clientClose.outbound[0], generation: 30).outbound.isEmpty)
    #expect(client.receive(relayClose.outbound[0], generation: 30).outbound.isEmpty)
    #expect(relay.receive(clientClose.outbound[0], generation: 30).outbound.isEmpty)
    #expect(clientCleanup.associations.count == 1)
    #expect(relayCleanup.associations.count == 1)
    #expect(client.metrics.associationClosesSent == 1)
    #expect(relay.metrics.associationClosesSent == 1)
    #expect(client.metrics.associationClosesReceived == 2)
    #expect(relay.metrics.associationClosesReceived == 2)

    let reused = client.send(
      RelayEnvelope(type: .udpDatagram, associationID: 11, payload: payload),
      generation: 30
    )
    #expect(reused.outbound.count == 1)
    #expect(relay.receive(reused.outbound[0], generation: 30).events.count == 1)
    _ = client.closeSession(generation: 30)
    _ = relay.closeSession(generation: 30)
    #expect(clientCleanup.associations.count == 2)
    #expect(relayCleanup.associations.count == 2)
  }

  @Test("graceful abrupt duplicate and stale session termination is once per generation")
  func generationTermination() throws {
    let clientCleanup = CleanupRecorder()
    let relayCleanup = CleanupRecorder()
    var client = try makeSession(
      peer: .client,
      generation: 40,
      generationCleanup: clientCleanup.generationCallback
    )
    var relay = try makeSession(
      peer: .relay,
      generation: 40,
      generationCleanup: relayCleanup.generationCallback
    )

    let close = client.closeSession(generation: 40)
    #expect(close.state == .closed)
    let ack = relay.receive(close.outbound[0], generation: 40)
    #expect(ack.state == .closed)
    #expect(ack.outbound.map(\.type) == [.closeSession])
    #expect(client.receive(ack.outbound[0], generation: 40).outbound.isEmpty)
    #expect(client.receive(ack.outbound[0], generation: 40).outbound.isEmpty)
    _ = client.endOfStream(generation: 40)
    _ = client.cancel(generation: 40)
    _ = client.transportFailed(generation: 40)
    #expect(client.endOfStream(generation: 39).staleCallbackIgnored)
    #expect(clientCleanup.generations == [40])
    #expect(relayCleanup.generations == [40])
    #expect(client.metrics.sessionCleanups == 1)
    #expect(relay.metrics.sessionCleanups == 1)
    #expect(client.metrics.sessionClosesSent == 1)
    #expect(relay.metrics.sessionClosesSent == 1)
    #expect(client.metrics.sessionClosesReceived == 2)
    #expect(client.metrics.staleCallbacks == 1)
    #expect(client.metrics.lateCallbacks == 5)

    let abruptCleanup = CleanupRecorder()
    var abrupt = try makeSession(
      peer: .relay,
      generation: 41,
      generationCleanup: abruptCleanup.generationCallback
    )
    let eof = abrupt.endOfStream(generation: 41)
    #expect(eof.failure?.code == .unexpectedEOF)
    #expect(abrupt.cancel(generation: 41).failure == nil)
    #expect(abruptCleanup.generations == [41])
    #expect(abrupt.metrics.sessionCleanups == 1)
  }

  @Test("live associations clean up once for every abrupt session termination")
  func liveAssociationAbruptTermination() throws {
    let payload = try validDatagramPayload(data: Data())
    let expected: [(RelaySessionFailureCode, RelaySessionTerminationReason)] = [
      (.unexpectedEOF, .endOfStream),
      (.cancelled, .cancelled),
      (.transportFailure, .transportFailure),
    ]

    for (index, expectation) in expected.enumerated() {
      let generation = UInt64(130 + index)
      let clientCleanup = CleanupRecorder()
      let relayCleanup = CleanupRecorder()
      var client = try makeSession(
        peer: .client,
        generation: generation,
        associationCleanup: clientCleanup.associationCallback,
        generationCleanup: clientCleanup.generationCallback
      )
      var relay = try makeSession(
        peer: .relay,
        generation: generation,
        associationCleanup: relayCleanup.associationCallback,
        generationCleanup: relayCleanup.generationCallback
      )
      let request = client.send(
        RelayEnvelope(type: .udpDatagram, associationID: 15, payload: payload),
        generation: generation
      )
      _ = relay.receive(request.outbound[0], generation: generation)
      let response = relay.send(
        RelayEnvelope(type: .udpDatagram, associationID: 15, payload: payload),
        generation: generation
      )
      _ = client.receive(response.outbound[0], generation: generation)

      let clientTerminal = terminate(&client, kind: index, generation: generation)
      let relayTerminal = terminate(&relay, kind: index, generation: generation)
      #expect(clientTerminal.failure?.code == expectation.0)
      #expect(relayTerminal.failure?.code == expectation.0)

      for peerIndex in 0..<2 {
        if peerIndex == 0 {
          exerciseLateCallbacks(&client, generation: generation)
        } else {
          exerciseLateCallbacks(&relay, generation: generation)
        }
      }
      #expect(client.endOfStream(generation: generation - 1).staleCallbackIgnored)
      #expect(relay.endOfStream(generation: generation - 1).staleCallbackIgnored)
      #expect(clientCleanup.associations == [(generation << 32) | 15])
      #expect(relayCleanup.associations == [(generation << 32) | 15])
      #expect(clientCleanup.reasons == [expectation.1])
      #expect(relayCleanup.reasons == [expectation.1])
      #expect(client.metrics == relay.metrics)
      #expect(client.metrics.associationCleanups == 1)
      #expect(client.metrics.sessionCleanups == 1)
      #expect(client.metrics.sessionFailures == 1)
      #expect(client.metrics.associationClosesReceived == 1)
      #expect(client.metrics.sessionClosesReceived == 1)
      #expect(client.metrics.lateCallbacks == 5)
      #expect(client.metrics.staleCallbacks == 1)
    }
  }

  @Test("hostile metadata and exact-boundary post-handshake RLXR close both peers")
  func hostileSessionInput() throws {
    let hostile: [(RelaySessionPeer, Data, RelaySessionFailureCode)] = [
      (.relay, Data([0, 0, 0, 5]), .frameLengthBelowMinimum),
      (.relay, rawFrame(type: 0x7F), .unknownMessageType),
      (
        .relay,
        rawFrame(type: P.MessageType.udpDatagram.rawValue, flags: 0x80, associationID: 1),
        .reservedFlags
      ),
      (
        .client,
        rawFrame(type: P.MessageType.ping.rawValue, payload: Data(repeating: 0, count: 8)),
        .invalidDirection
      ),
      (
        .relay,
        rawFrame(
          type: P.MessageType.ping.rawValue,
          associationID: 1,
          payload: Data(repeating: 0, count: 8)
        ),
        .invalidAssociationID
      ),
      (
        .relay,
        rawFrame(type: P.MessageType.ping.rawValue, payload: Data(repeating: 0, count: 7)),
        .invalidPayloadLength
      ),
    ]

    for (index, test) in hostile.enumerated() {
      let cleanup = CleanupRecorder()
      var session = try makeSession(
        peer: test.0,
        generation: UInt64(50 + index),
        generationCleanup: cleanup.generationCallback
      )
      let result = session.receive(test.1, generation: UInt64(50 + index))
      #expect(result.state == .closed)
      #expect(result.failure?.code == test.2)
      #expect(result.failure?.scope == "session")
      #expect(result.failure?.disposition == "closeSession")
      #expect(cleanup.generations.count == 1)
    }

    for (peerIndex, peer) in [RelaySessionPeer.client, .relay].enumerated() {
      for splitMask in 0..<8 {
        let cleanup = CleanupRecorder()
        let generation = UInt64(160 + peerIndex * 10 + splitMask)
        var session = try makeSession(
          peer: peer,
          generation: generation,
          generationCleanup: cleanup.generationCallback
        )
        let chunks = magicChunks(splitMask: splitMask)
        for (chunkIndex, chunk) in chunks.enumerated() {
          // The hello completed at an exact read boundary; these are later reads.
          let result = session.receive(chunk, generation: generation)
          if chunkIndex == chunks.index(before: chunks.endIndex) {
            #expect(result.failure?.code == .postHandshakeHello)
          } else {
            #expect(result.state == .active)
            #expect(result.failure == nil)
          }
        }
        #expect(cleanup.reasons == [.postHandshakeHello])
        #expect(session.metrics.sessionCleanups == 1)
        #expect(session.endOfStream(generation: generation).failure == nil)
        #expect(session.endOfStream(generation: generation - 1).staleCallbackIgnored)
        #expect(cleanup.generations.count == 1)
      }
    }
  }

  @Test("diagnostics never reflect remote payloads or unknown error numbers")
  func privacySafeDiagnostics() throws {
    let attacker = "remote-secret-diagnostic"
    var session = try makeSession(peer: .relay, generation: 70)
    let failure = session.receive(
      rawFrame(
        type: P.MessageType.ping.rawValue,
        payload: Data(attacker.utf8)
      ),
      generation: 70
    ).failure
    let diagnostic = failure?.description ?? ""
    #expect(!diagnostic.contains(attacker))
    #expect(diagnostic.contains(RelaySessionFailureCode.invalidPayloadLength.rawValue))
    #expect(diagnostic.contains("scope=session"))
    #expect(diagnostic.contains("disposition=closeSession"))
  }

  @Test("PONG and UDP_ERROR are emitted only by bounded response APIs")
  func responseOnlyFrames() throws {
    let token = Data(repeating: 0xA5, count: 8)
    var arbitraryPong = try makeSession(peer: .relay, generation: 80)
    let pong = arbitraryPong.send(
      RelayEnvelope(type: .pong, associationID: 0, payload: token),
      generation: 80
    )
    #expect(pong.outbound.isEmpty)
    #expect(pong.failure?.code == .metadataRejected)

    var arbitraryError = try makeSession(peer: .relay, generation: 81)
    let error = arbitraryError.send(
      RelayEnvelope(type: .udpError, associationID: 1, payload: Data([0, 1])),
      generation: 81
    )
    #expect(error.outbound.isEmpty)
    #expect(error.failure?.code == .metadataRejected)

    var generatedError = try makeSession(peer: .relay, generation: 82)
    _ = generatedError.receive(
      RelayEnvelope(
        type: .udpDatagram,
        associationID: 1,
        payload: try validDatagramPayload(data: Data())
      ),
      generation: 82
    )
    let generated = generatedError.reportAssociationFailure(
      associationID: 1,
      code: .invalidDatagram,
      closeAssociation: false,
      generation: 82
    )
    #expect(generated.failure == nil)
    #expect(generated.outbound.map(\.payload) == [Data([0, 1])])
  }

  private func transition(
    _ type: P.MessageType
  ) -> RelaySessionTransition? {
    RelaySessionTransitions.v1.first { $0.type == type }
  }

  private func terminate(
    _ session: inout RelaySession,
    kind: Int,
    generation: UInt64
  ) -> RelaySessionStep {
    switch kind {
    case 0: session.endOfStream(generation: generation)
    case 1: session.cancel(generation: generation)
    default: session.transportFailed(generation: generation)
    }
  }

  private func exerciseLateCallbacks(
    _ session: inout RelaySession,
    generation: UInt64
  ) {
    _ = session.endOfStream(generation: generation)
    _ = session.cancel(generation: generation)
    _ = session.transportFailed(generation: generation)
    _ = session.receive(
      RelayEnvelope(type: .closeAssociation, associationID: 15),
      generation: generation
    )
    _ = session.receive(
      RelayEnvelope(type: .closeSession, associationID: 0),
      generation: generation
    )
  }

  private func magicChunks(splitMask: Int) -> [Data] {
    let magic = Data(P.magic)
    var chunks: [Data] = []
    var start = 0
    for boundary in 0..<(magic.count - 1) where splitMask & (1 << boundary) != 0 {
      chunks.append(Data(magic[start...boundary]))
      start = boundary + 1
    }
    chunks.append(Data(magic[start..<magic.count]))
    return chunks
  }
}

private final class CleanupRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var associationValues: [UInt64] = []
  private var generationValues: [UInt64] = []
  private var reasonValues: [RelaySessionTerminationReason] = []

  var associationCallback: RelayAssociationCleanup {
    { [weak self] generation, associationID in
      guard let self else { return }
      lock.withLock {
        associationValues.append((generation << 32) | UInt64(associationID))
      }
    }
  }

  var generationCallback: RelayGenerationCleanup {
    { [weak self] generation, reason in
      guard let self else { return }
      lock.withLock {
        generationValues.append(generation)
        reasonValues.append(reason)
      }
    }
  }

  var associations: [UInt64] { lock.withLock { associationValues } }
  var generations: [UInt64] { lock.withLock { generationValues } }
  var reasons: [RelaySessionTerminationReason] { lock.withLock { reasonValues } }
}

private func makeSession(
  peer: RelaySessionPeer,
  generation: UInt64,
  maximumUDPPayload: UInt16 = RelayProtocolV1.maxUDPPayloadClientDefault,
  maximumAssociations: UInt32 = RelayProtocolV1.maxAssociationsClientDefault,
  associationCleanup: RelayAssociationCleanup? = nil,
  generationCleanup: RelayGenerationCleanup? = nil
) throws -> RelaySession {
  try RelaySession(
    generation: generation,
    peer: peer,
    limits: RelayEffectiveLimits(
      effectiveMaxFrame: RelayProtocolV1.maxFrameDefault,
      maxUDPPayload: maximumUDPPayload,
      maxAssociations: maximumAssociations,
      perAssociationQueuedBytes: RelayProtocolV1.perAssociationQueuedBytesClientDefault,
      aggregateQueuedBytes: RelayProtocolV1.aggregateQueuedBytesClientDefault,
      controlReservedBytes: RelayProtocolV1.controlReservedBytesClientDefault,
      dnsPriorityWeight: RelayProtocolV1.dnsPriorityWeightClientDefault,
      idleTimeoutMilliseconds: RelayProtocolV1.idleTimeoutClientDefault
    ),
    negotiatedFeatures: [.dnsPriorityHint],
    associationCleanup: associationCleanup,
    generationCleanup: generationCleanup
  )
}

private func validDatagramPayload(data: Data) throws -> Data {
  var codec = try RelayDatagramCodec()
  return try codec.encode(
    RelayDatagram(
      endpoint: RelayDatagramEndpoint(
        address: .ipv4(Data([192, 0, 2, 1])),
        port: 53
      ),
      data: data
    )
  )
}

private func oversizedDatagramPayload(dataLength: Int) -> Data {
  var payload = Data([
    UInt8(truncatingIfNeeded: dataLength >> 8),
    UInt8(truncatingIfNeeded: dataLength),
    UInt8(RelayProtocolV1.hevHDRLENIPv4),
    RelayProtocolV1.AddressType.ipv4.rawValue,
    192, 0, 2, 1,
    0, 53,
  ])
  payload.append(Data(repeating: 0xA5, count: dataLength))
  return payload
}

private func rawFrame(
  type: UInt8,
  flags: UInt8 = 0,
  associationID: UInt32 = 0,
  payload: Data = Data()
) -> Data {
  let length = UInt32(RelayProtocolV1.envelopeHeaderWidth + payload.count)
  var result = Data([
    UInt8(truncatingIfNeeded: length >> 24),
    UInt8(truncatingIfNeeded: length >> 16),
    UInt8(truncatingIfNeeded: length >> 8),
    UInt8(truncatingIfNeeded: length),
    type,
    flags,
    UInt8(truncatingIfNeeded: associationID >> 24),
    UInt8(truncatingIfNeeded: associationID >> 16),
    UInt8(truncatingIfNeeded: associationID >> 8),
    UInt8(truncatingIfNeeded: associationID),
  ])
  result.append(payload)
  return result
}
