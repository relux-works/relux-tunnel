package protocol

import (
	"bytes"
	"encoding/binary"
	"strings"
	"testing"
)

func TestSessionTransitionTableCoversEveryV1Message(t *testing.T) {
	table := SessionTransitionTableV1()
	if len(table) != len(MessageMetadataTable) {
		t.Fatalf("transition count %d, want %d", len(table), len(MessageMetadataTable))
	}
	seen := make(map[MessageType]bool)
	for _, metadata := range MessageMetadataTable {
		transition, ok := findSessionTransition(table, metadata.Type)
		if !ok {
			t.Fatalf("missing transition for %s", metadata.Name)
		}
		if seen[metadata.Type] {
			t.Fatalf("duplicate transition for %s", metadata.Name)
		}
		seen[metadata.Type] = true
		if transition.Direction != metadata.Direction || transition.AssociationID != metadata.AssociationID {
			t.Fatalf("generated metadata diverged for %s: %#v", metadata.Name, transition)
		}
		if metadata.PayloadShape == PayloadShapeFixed {
			if transition.MinimumPayloadBytes != metadata.FixedPayloadWidth ||
				transition.MaximumPayloadBytes != metadata.FixedPayloadWidth {
				t.Fatalf("fixed payload bounds diverged for %s: %#v", metadata.Name, transition)
			}
		} else if transition.MinimumPayloadBytes != 0 || transition.MaximumPayloadBytes != MaxHEVRecordWidth {
			t.Fatalf("datagram payload bounds diverged: %#v", transition)
		}
	}

	datagram, _ := findSessionTransition(table, MessageTypeUDPDatagram)
	if datagram.Response != SessionResponseGeneratedUDPError ||
		datagram.CloseEffect != SessionCloseEffectMalformedDatagramAssociation {
		t.Fatalf("datagram policy = %#v", datagram)
	}
	ping, _ := findSessionTransition(table, MessageTypePing)
	if ping.Response != SessionResponseEchoPong {
		t.Fatalf("ping policy = %#v", ping)
	}
	associationClose, _ := findSessionTransition(table, MessageTypeCloseAssociation)
	if associationClose.Response != SessionResponseCloseAssociationAck {
		t.Fatalf("association close policy = %#v", associationClose)
	}
	sessionClose, _ := findSessionTransition(table, MessageTypeCloseSession)
	if sessionClose.Response != SessionResponseCloseSessionAck {
		t.Fatalf("session close policy = %#v", sessionClose)
	}
}

func TestSessionPairedNominalDatagramHealthAndFiniteErrors(t *testing.T) {
	client := mustSession(t, 10, SessionPeerClient, MaxUDPPayloadClientDefault, nil, nil)
	relay := mustSession(t, 10, SessionPeerRelay, MaxUDPPayloadRelayDefault, nil, nil)
	token := []byte{0, 1, 2, 3, 4, 5, 6, 7}

	ping := client.Send(10, Envelope{Type: MessageTypePing, Payload: token})
	if len(ping.Outbound) != 1 {
		t.Fatalf("ping outbound = %#v", ping)
	}
	pong := relay.Receive(10, ping.Outbound[0])
	if len(pong.Outbound) != 1 || pong.Outbound[0].Type != MessageTypePong ||
		!bytes.Equal(pong.Outbound[0].Payload, token) {
		t.Fatalf("pong = %#v", pong)
	}
	observedPong := client.Receive(10, pong.Outbound[0])
	if len(observedPong.Events) != 1 || observedPong.Events[0].Kind != SessionEventPong ||
		!bytes.Equal(observedPong.Events[0].HealthPayload, token) {
		t.Fatalf("observed pong = %#v", observedPong)
	}

	payload := validSessionDatagramPayload(t, []byte{0xCA, 0xFE})
	request := client.Send(10, Envelope{Type: MessageTypeUDPDatagram, AssociationID: 7, Payload: payload})
	relayRequest := relay.Receive(10, request.Outbound[0])
	if len(relayRequest.Events) != 1 || relayRequest.Events[0].Kind != SessionEventDatagram {
		t.Fatalf("relay request = %#v", relayRequest)
	}
	response := relay.Send(10, Envelope{Type: MessageTypeUDPDatagram, AssociationID: 7, Payload: payload})
	clientResponse := client.Receive(10, response.Outbound[0])
	if len(clientResponse.Events) != 1 || clientResponse.Events[0].Kind != SessionEventDatagram {
		t.Fatalf("client response = %#v", clientResponse)
	}

	relayError := relay.ReportAssociationFailure(10, 7, UDPErrorCodeSocketFailure, false)
	if len(relayError.Outbound) != 1 || !bytes.Equal(relayError.Outbound[0].Payload, []byte{0, 8}) {
		t.Fatalf("relay error = %#v", relayError)
	}
	clientError := client.Receive(10, relayError.Outbound[0])
	if len(clientError.Events) != 1 || clientError.Events[0].RemoteError.Code != UDPErrorCodeSocketFailure ||
		clientError.Events[0].RemoteError.UnknownRelayError {
		t.Fatalf("client error = %#v", clientError)
	}
	unknown := client.Receive(10, Envelope{Type: MessageTypeUDPError, AssociationID: 7, Payload: []byte{0xff, 0xff}})
	if len(unknown.Events) != 1 || !unknown.Events[0].RemoteError.UnknownRelayError || unknown.Events[0].RemoteError.Code != 0 {
		t.Fatalf("unknown remote error leaked raw code: %#v", unknown)
	}
	if client.Metrics().UDPErrorsReceived != 2 || relay.Metrics().UDPErrorsSent != 1 ||
		client.Metrics().DatagramsAccepted != relay.Metrics().DatagramsAccepted {
		t.Fatalf("nominal counters did not reconcile client=%#v relay=%#v", client.Metrics(), relay.Metrics())
	}
}

func TestSessionInvalidFirstDatagramsDoNotAdmitAssociationState(t *testing.T) {
	clientRecorder := &sessionCleanupRecorder{}
	relayRecorder := &sessionCleanupRecorder{}
	client := mustSession(t, 20, SessionPeerClient, MaxUDPPayloadClientDefault, clientRecorder.association, nil)
	relay := mustSession(t, 20, SessionPeerRelay, MaxUDPPayloadRelayDefault, relayRecorder.association, nil)
	malformed := []byte{0x00, 0x00, 0x07, 0x03, 0x00}
	client.Send(20, Envelope{
		Type: MessageTypeUDPDatagram, AssociationID: 9, Payload: validSessionDatagramPayload(t, nil),
	})
	rejection := relay.Receive(20, Envelope{Type: MessageTypeUDPDatagram, AssociationID: 9, Payload: malformed})
	if rejection.State != SessionActive || len(rejection.Outbound) != 2 ||
		rejection.Outbound[0].Type != MessageTypeUDPError ||
		rejection.Outbound[1].Type != MessageTypeCloseAssociation ||
		!bytes.Equal(rejection.Outbound[0].Payload, []byte{0, 1}) {
		t.Fatalf("malformed rejection = %#v", rejection)
	}
	if len(relayRecorder.associations) != 0 {
		t.Fatalf("relay cleanup = %#v", relayRecorder)
	}
	errorStep := client.Receive(20, rejection.Outbound[0])
	if len(errorStep.Events) != 1 || errorStep.Events[0].RemoteError.Code != UDPErrorCodeInvalidDatagram {
		t.Fatalf("client error = %#v", errorStep)
	}
	closeAck := client.Receive(20, rejection.Outbound[1])
	if len(closeAck.Outbound) != 1 || closeAck.Outbound[0].Type != MessageTypeCloseAssociation {
		t.Fatalf("close ack = %#v", closeAck)
	}
	if len(clientRecorder.associations) != 1 {
		t.Fatalf("client cleanup = %#v", clientRecorder)
	}
	if retired := relay.Receive(20, closeAck.Outbound[0]); len(retired.Outbound) != 0 {
		t.Fatalf("crossed close emitted another ack: %#v", retired)
	}
	if duplicate := relay.Receive(20, closeAck.Outbound[0]); len(duplicate.Outbound) != 0 || len(relayRecorder.associations) != 0 {
		t.Fatalf("duplicate close was not idempotent: %#v", duplicate)
	}

	protocolRecorder := &sessionCleanupRecorder{}
	protocolRelay := mustSession(t, 22, SessionPeerRelay, MaxUDPPayloadRelayDefault, protocolRecorder.association, nil)
	protocolOversized := protocolRelay.Receive(22, Envelope{
		Type:          MessageTypeUDPDatagram,
		AssociationID: 12,
		Payload:       oversizedSessionDatagramPayload(int(MaxUDPPayloadClientHardCeiling) + 1),
	})
	if len(protocolOversized.Events) != 0 || len(protocolOversized.Outbound) != 2 ||
		protocolOversized.Outbound[0].Type != MessageTypeUDPError ||
		protocolOversized.Outbound[1].Type != MessageTypeCloseAssociation ||
		!bytes.Equal(protocolOversized.Outbound[0].Payload, []byte{0, 5}) ||
		len(protocolRecorder.associations) != 0 {
		t.Fatalf("protocol oversized first datagram = %#v recorder=%#v", protocolOversized, protocolRecorder)
	}

	dropClient := mustSession(t, 21, SessionPeerClient, MaxUDPPayloadClientDefault, nil, nil)
	dropRecorder := &sessionCleanupRecorder{}
	dropRelay := mustSession(t, 21, SessionPeerRelay, MaxUDPPayloadFloor, dropRecorder.association, nil)
	oversized := validSessionDatagramPayload(t, bytes.Repeat([]byte{0xa5}, int(MaxUDPPayloadFloor)+1))
	dropRequest := dropClient.Send(21, Envelope{Type: MessageTypeUDPDatagram, AssociationID: 10, Payload: oversized})
	drop := dropRelay.Receive(21, dropRequest.Outbound[0])
	if len(drop.Outbound) != 1 || drop.Outbound[0].Type != MessageTypeUDPError ||
		!bytes.Equal(drop.Outbound[0].Payload, []byte{0, 5}) || dropRelay.Metrics().AssociationCleanups != 0 {
		t.Fatalf("local-cap disposition = %#v metrics=%#v", drop, dropRelay.Metrics())
	}
	dropRelay.Close(21)
	protocolRelay.Close(22)
	if len(dropRecorder.associations) != 0 || len(protocolRecorder.associations) != 0 {
		t.Fatalf("invalid first datagram admitted state drop=%#v protocol=%#v", dropRecorder, protocolRecorder)
	}
}

func TestSessionOutboundDatagramsAreStructurallyAndLocallyBoundedForBothPeers(t *testing.T) {
	malformed := []byte{}
	protocolOversized := oversizedSessionDatagramPayload(int(MaxUDPPayloadClientHardCeiling) + 1)
	localCapOversized := validSessionDatagramPayload(t, bytes.Repeat([]byte{0xa5}, int(MaxUDPPayloadFloor)+1))
	tests := []struct {
		name       string
		payload    []byte
		maximumUDP uint16
	}{
		{"malformed", malformed, MaxUDPPayloadClientDefault},
		{"protocol ceiling", protocolOversized, MaxUDPPayloadClientDefault},
		{"local cap", localCapOversized, MaxUDPPayloadFloor},
	}

	for peerIndex, peer := range []SessionPeer{SessionPeerClient, SessionPeerRelay} {
		for caseIndex, test := range tests {
			t.Run(string(peer)+"/"+test.name, func(t *testing.T) {
				generation := uint64(100 + peerIndex*10 + caseIndex)
				session := mustSession(t, generation, peer, test.maximumUDP, nil, nil)
				valid := validSessionDatagramPayload(t, nil)
				if peer == SessionPeerClient {
					if opening := session.Send(generation, Envelope{
						Type: MessageTypeUDPDatagram, AssociationID: 99, Payload: valid,
					}); len(opening.Outbound) != 1 {
						t.Fatalf("client opening = %#v", opening)
					}
				} else {
					if opening := session.Receive(generation, Envelope{
						Type: MessageTypeUDPDatagram, AssociationID: 99, Payload: valid,
					}); len(opening.Events) != 1 {
						t.Fatalf("relay opening = %#v", opening)
					}
				}
				before := session.Metrics()

				rejected := session.Send(generation, Envelope{
					Type: MessageTypeUDPDatagram, AssociationID: 99, Payload: test.payload,
				})
				if rejected.State != SessionActive || rejected.Failure != nil || len(rejected.Outbound) != 0 ||
					session.Metrics().DatagramsRejected != before.DatagramsRejected+1 ||
					session.Metrics().SentFrames != before.SentFrames {
					t.Fatalf("rejected = %#v metrics=%#v", rejected, session.Metrics())
				}
			})
		}
	}
}

func TestSessionAssociationOwnershipRejectsUnsolicitedAndUnknownRelayReplies(t *testing.T) {
	clientRecorder := &sessionCleanupRecorder{}
	relayRecorder := &sessionCleanupRecorder{}
	client := mustSession(t, 105, SessionPeerClient, MaxUDPPayloadClientDefault, clientRecorder.association, nil)
	relay := mustSession(t, 105, SessionPeerRelay, MaxUDPPayloadRelayDefault, relayRecorder.association, nil)
	payload := validSessionDatagramPayload(t, nil)

	localUnknownReply := relay.Send(105, Envelope{
		Type: MessageTypeUDPDatagram, AssociationID: 44, Payload: payload,
	})
	if len(localUnknownReply.Outbound) != 0 ||
		len(relay.ReportAssociationFailure(105, 44, UDPErrorCodeSocketFailure, true).Outbound) != 0 {
		t.Fatalf("unknown relay reply escaped local ownership check reply=%#v", localUnknownReply)
	}

	unsolicited := client.Receive(105, Envelope{
		Type: MessageTypeUDPDatagram, AssociationID: 44, Payload: payload,
	})
	if len(unsolicited.Events) != 0 || len(unsolicited.Outbound) != 1 ||
		unsolicited.Outbound[0].Type != MessageTypeCloseAssociation || len(clientRecorder.associations) != 0 {
		t.Fatalf("unsolicited reply = %#v recorder=%#v", unsolicited, clientRecorder)
	}
	if acknowledgment := relay.Receive(105, unsolicited.Outbound[0]); len(acknowledgment.Outbound) != 0 ||
		len(relayRecorder.associations) != 0 {
		t.Fatalf("unknown close acknowledgment admitted relay state = %#v", acknowledgment)
	}

	request := client.Send(105, Envelope{
		Type: MessageTypeUDPDatagram, AssociationID: 44, Payload: payload,
	})
	if len(request.Outbound) != 1 || len(relay.Receive(105, request.Outbound[0]).Events) != 1 {
		t.Fatalf("valid client-owned opening was rejected request=%#v", request)
	}
	response := relay.Send(105, Envelope{
		Type: MessageTypeUDPDatagram, AssociationID: 44, Payload: payload,
	})
	if len(response.Outbound) != 1 || len(client.Receive(105, response.Outbound[0]).Events) != 1 {
		t.Fatalf("active relay reply was rejected response=%#v", response)
	}

	relayClose := relay.CloseAssociation(105, 44)
	if len(relay.Send(105, Envelope{
		Type: MessageTypeUDPDatagram, AssociationID: 44, Payload: payload,
	}).Outbound) != 0 {
		t.Fatal("relay emitted a reply for a closed association")
	}
	clientAck := client.Receive(105, relayClose.Outbound[0])
	relay.Receive(105, clientAck.Outbound[0])
	lateReply := client.Receive(105, Envelope{
		Type: MessageTypeUDPDatagram, AssociationID: 44, Payload: payload,
	})
	if len(lateReply.Events) != 0 || len(lateReply.Outbound) != 0 {
		t.Fatalf("client delivered a reply for a closed association: %#v", lateReply)
	}

	if client.Metrics().DatagramsRejected != 2 || relay.Metrics().DatagramsRejected != 2 ||
		client.Metrics().AssociationClosesSent != relay.Metrics().AssociationClosesReceived ||
		relay.Metrics().AssociationClosesSent != client.Metrics().AssociationClosesReceived {
		t.Fatalf("ownership counters client=%#v relay=%#v", client.Metrics(), relay.Metrics())
	}

	closeStep := client.Close(105)
	acknowledgment := relay.Receive(105, closeStep.Outbound[0])
	client.Receive(105, acknowledgment.Outbound[0])
	if len(clientRecorder.associations) != 1 || len(relayRecorder.associations) != 1 ||
		clientRecorder.associations[0] != 105<<32|44 || relayRecorder.associations[0] != 105<<32|44 {
		t.Fatalf("owned cleanup client=%#v relay=%#v", clientRecorder, relayRecorder)
	}
}

func TestSessionMaximumAssociationCreditBoundsUniqueIDsAndPermitsRetiredReuse(t *testing.T) {
	clientRecorder := &sessionCleanupRecorder{}
	relayRecorder := &sessionCleanupRecorder{}
	client := mustSession(t, 106, SessionPeerClient, MaxUDPPayloadClientDefault, clientRecorder.association, nil)
	relay := mustSessionWithMaximumAssociations(
		t, 106, SessionPeerRelay, MaxUDPPayloadRelayDefault, 2, relayRecorder.association, nil,
	)
	payload := validSessionDatagramPayload(t, nil)

	for associationID := uint32(1); associationID <= 2; associationID++ {
		request := client.Send(106, Envelope{
			Type: MessageTypeUDPDatagram, AssociationID: associationID, Payload: payload,
		})
		if len(request.Outbound) != 1 || len(relay.Receive(106, request.Outbound[0]).Events) != 1 {
			t.Fatalf("opening %d was rejected request=%#v", associationID, request)
		}
	}

	const firstFloodID uint32 = 3
	const lastFloodID uint32 = 8
	for associationID := firstFloodID; associationID <= lastFloodID; associationID++ {
		request := client.Send(106, Envelope{
			Type: MessageTypeUDPDatagram, AssociationID: associationID, Payload: payload,
		})
		rejection := relay.Receive(106, request.Outbound[0])
		if len(rejection.Events) != 0 || len(rejection.Outbound) != 2 ||
			rejection.Outbound[0].Type != MessageTypeUDPError ||
			rejection.Outbound[1].Type != MessageTypeCloseAssociation ||
			!bytes.Equal(rejection.Outbound[0].Payload, []byte{0, 4}) {
			t.Fatalf("flood rejection %d = %#v", associationID, rejection)
		}
		errorStep := client.Receive(106, rejection.Outbound[0])
		if len(errorStep.Events) != 1 || errorStep.Events[0].RemoteError.Code != UDPErrorCodeAssociationLimit {
			t.Fatalf("association limit error %d = %#v", associationID, errorStep)
		}
		acknowledgment := client.Receive(106, rejection.Outbound[1])
		if len(acknowledgment.Outbound) != 1 ||
			acknowledgment.Outbound[0].Type != MessageTypeCloseAssociation ||
			len(relay.Receive(106, acknowledgment.Outbound[0]).Outbound) != 0 {
			t.Fatalf("association limit close %d = %#v", associationID, acknowledgment)
		}
	}
	if len(relayRecorder.associations) != 0 {
		t.Fatalf("unique-ID flood admitted cleanup state: %#v", relayRecorder)
	}

	clientClose := client.CloseAssociation(106, 1)
	relayAck := relay.Receive(106, clientClose.Outbound[0])
	client.Receive(106, relayAck.Outbound[0])
	if len(relayRecorder.associations) != 1 || relayRecorder.associations[0] != 106<<32|1 {
		t.Fatalf("retired association cleanup = %#v", relayRecorder)
	}

	reused := client.Send(106, Envelope{
		Type: MessageTypeUDPDatagram, AssociationID: 3, Payload: payload,
	})
	if len(reused.Outbound) != 1 || len(relay.Receive(106, reused.Outbound[0]).Events) != 1 {
		t.Fatalf("retired credit reuse = %#v", reused)
	}

	floodCount := uint64(lastFloodID - firstFloodID + 1)
	clientMetrics := client.Metrics()
	relayMetrics := relay.Metrics()
	if relayMetrics.DatagramsAccepted != 3 || relayMetrics.DatagramsRejected != floodCount ||
		relayMetrics.UDPErrorsSent != floodCount || relayMetrics.UDPErrorsSent != clientMetrics.UDPErrorsReceived ||
		relayMetrics.AssociationClosesSent != clientMetrics.AssociationClosesReceived ||
		clientMetrics.AssociationClosesSent != relayMetrics.AssociationClosesReceived {
		t.Fatalf("limit counters client=%#v relay=%#v", clientMetrics, relayMetrics)
	}

	closeStep := client.Close(106)
	acknowledgment := relay.Receive(106, closeStep.Outbound[0])
	client.Receive(106, acknowledgment.Outbound[0])
	if len(relayRecorder.associations) != 3 || len(clientRecorder.associations) != int(floodCount)+3 {
		t.Fatalf("bounded cleanup client=%#v relay=%#v", clientRecorder, relayRecorder)
	}
	wantRelayCleanup := map[uint64]bool{106<<32 | 1: true, 106<<32 | 2: true, 106<<32 | 3: true}
	for _, association := range relayRecorder.associations {
		delete(wantRelayCleanup, association)
	}
	if len(wantRelayCleanup) != 0 {
		t.Fatalf("relay cleanup missing associations: %#v", wantRelayCleanup)
	}

	limitedClient := mustSessionWithMaximumAssociations(
		t, 107, SessionPeerClient, MaxUDPPayloadClientDefault, 1, nil, nil,
	)
	if len(limitedClient.Send(107, Envelope{
		Type: MessageTypeUDPDatagram, AssociationID: 1, Payload: payload,
	}).Outbound) != 1 || len(limitedClient.Send(107, Envelope{
		Type: MessageTypeUDPDatagram, AssociationID: 2, Payload: payload,
	}).Outbound) != 0 {
		t.Fatal("client association credit was not enforced")
	}
}

func TestSessionQueueSaturationEdgeAndIdleExpiryOrdering(t *testing.T) {
	payload := validSessionDatagramPayload(t, nil)
	saturationRelay := mustSession(t, 110, SessionPeerRelay, MaxUDPPayloadRelayDefault, nil, nil)
	saturationRelay.Receive(110, Envelope{Type: MessageTypeUDPDatagram, AssociationID: 7, Payload: payload})

	first := saturationRelay.ReportQueueSaturation(110, 7)
	duplicate := saturationRelay.ReportQueueSaturation(110, 7)
	saturationRelay.RecordAssociationQueueDepth(110, 7, PerAssociationQueuedBytesRelayDefault/2+1)
	stillSaturated := saturationRelay.ReportQueueSaturation(110, 7)
	saturationRelay.RecordAssociationQueueDepth(110, 7, PerAssociationQueuedBytesRelayDefault/2)
	nextEpisode := saturationRelay.ReportQueueSaturation(110, 7)
	if len(first.Outbound) != 1 || !bytes.Equal(first.Outbound[0].Payload, []byte{0, 6}) ||
		len(duplicate.Outbound) != 0 || len(stillSaturated.Outbound) != 0 ||
		len(nextEpisode.Outbound) != 1 || !bytes.Equal(nextEpisode.Outbound[0].Payload, []byte{0, 6}) ||
		saturationRelay.Metrics().DatagramsRejected != 4 || saturationRelay.Metrics().UDPErrorsSent != 2 {
		t.Fatalf("saturation first=%#v duplicate=%#v still=%#v next=%#v metrics=%#v",
			first, duplicate, stillSaturated, nextEpisode, saturationRelay.Metrics())
	}

	for _, code := range []UDPErrorCode{UDPErrorCodeQueueSaturated, UDPErrorCodeIdleExpiry} {
		generation := uint64(111 + code)
		generic := mustSession(t, generation, SessionPeerRelay, MaxUDPPayloadRelayDefault, nil, nil)
		rejected := generic.ReportAssociationFailure(generation, 7, code, false)
		if rejected.Failure == nil || rejected.Failure.Code != SessionMetadataRejected || len(rejected.Outbound) != 0 {
			t.Fatalf("generic special code %d = %#v", code, rejected)
		}
	}

	relayRecorder := &sessionCleanupRecorder{}
	client := mustSession(t, 120, SessionPeerClient, MaxUDPPayloadClientDefault, nil, nil)
	relay := mustSession(t, 120, SessionPeerRelay, MaxUDPPayloadRelayDefault, relayRecorder.association, nil)
	opening := client.Send(120, Envelope{Type: MessageTypeUDPDatagram, AssociationID: 8, Payload: payload})
	relay.Receive(120, opening.Outbound[0])
	expiry := relay.ReportIdleExpiry(120, 8)
	if len(expiry.Outbound) != 2 || expiry.Outbound[0].Type != MessageTypeUDPError ||
		expiry.Outbound[1].Type != MessageTypeCloseAssociation ||
		!bytes.Equal(expiry.Outbound[0].Payload, []byte{0, 9}) || len(relayRecorder.associations) != 1 {
		t.Fatalf("expiry = %#v recorder=%#v", expiry, relayRecorder)
	}
	if duplicate := relay.ReportIdleExpiry(120, 8); len(duplicate.Outbound) != 0 {
		t.Fatalf("duplicate expiry = %#v", duplicate)
	}
	client.Receive(120, expiry.Outbound[0])
	ack := client.Receive(120, expiry.Outbound[1])
	relay.Receive(120, ack.Outbound[0])
	if relay.Metrics().UDPErrorsSent != client.Metrics().UDPErrorsReceived ||
		relay.Metrics().AssociationClosesSent != client.Metrics().AssociationClosesReceived ||
		client.Metrics().AssociationClosesSent != relay.Metrics().AssociationClosesReceived {
		t.Fatalf("idle counters client=%#v relay=%#v", client.Metrics(), relay.Metrics())
	}
}

func TestSessionCrossedDuplicateAssociationCloseAndOrderedReuse(t *testing.T) {
	clientRecorder := &sessionCleanupRecorder{}
	relayRecorder := &sessionCleanupRecorder{}
	client := mustSession(t, 30, SessionPeerClient, MaxUDPPayloadClientDefault, clientRecorder.association, nil)
	relay := mustSession(t, 30, SessionPeerRelay, MaxUDPPayloadRelayDefault, relayRecorder.association, nil)
	payload := validSessionDatagramPayload(t, nil)
	opening := client.Send(30, Envelope{Type: MessageTypeUDPDatagram, AssociationID: 11, Payload: payload})
	relay.Receive(30, opening.Outbound[0])

	clientClose := client.CloseAssociation(30, 11)
	relayClose := relay.CloseAssociation(30, 11)
	if len(client.Receive(30, relayClose.Outbound[0]).Outbound) != 0 ||
		len(relay.Receive(30, clientClose.Outbound[0]).Outbound) != 0 ||
		len(client.Receive(30, relayClose.Outbound[0]).Outbound) != 0 ||
		len(relay.Receive(30, clientClose.Outbound[0]).Outbound) != 0 {
		t.Fatal("crossed or duplicate close emitted an extra acknowledgement")
	}
	if len(clientRecorder.associations) != 1 || len(relayRecorder.associations) != 1 {
		t.Fatalf("cleanup was not once client=%#v relay=%#v", clientRecorder, relayRecorder)
	}
	if client.Metrics().AssociationClosesSent != 1 || relay.Metrics().AssociationClosesSent != 1 ||
		client.Metrics().AssociationClosesReceived != 2 || relay.Metrics().AssociationClosesReceived != 2 {
		t.Fatalf("close counters client=%#v relay=%#v", client.Metrics(), relay.Metrics())
	}

	reused := client.Send(30, Envelope{Type: MessageTypeUDPDatagram, AssociationID: 11, Payload: payload})
	if len(reused.Outbound) != 1 || len(relay.Receive(30, reused.Outbound[0]).Events) != 1 {
		t.Fatal("ordered association reuse was rejected")
	}
	client.Close(30)
	relay.Close(30)
	if len(clientRecorder.associations) != 2 || len(relayRecorder.associations) != 2 {
		t.Fatalf("reused lifecycle cleanup missing client=%#v relay=%#v", clientRecorder, relayRecorder)
	}
}

func TestSessionGracefulAbruptDuplicateAndStaleTerminationOnce(t *testing.T) {
	clientRecorder := &sessionCleanupRecorder{}
	relayRecorder := &sessionCleanupRecorder{}
	client := mustSession(t, 40, SessionPeerClient, MaxUDPPayloadClientDefault, nil, clientRecorder.generation)
	relay := mustSession(t, 40, SessionPeerRelay, MaxUDPPayloadRelayDefault, nil, relayRecorder.generation)

	closeStep := client.Close(40)
	if closeStep.State != SessionClosed || len(closeStep.Outbound) != 1 {
		t.Fatalf("client close = %#v", closeStep)
	}
	ack := relay.Receive(40, closeStep.Outbound[0])
	if ack.State != SessionClosed || len(ack.Outbound) != 1 || ack.Outbound[0].Type != MessageTypeCloseSession {
		t.Fatalf("relay ack = %#v", ack)
	}
	client.Receive(40, ack.Outbound[0])
	client.Receive(40, ack.Outbound[0])
	client.EndOfStream(40)
	client.Cancel(40)
	client.TransportFailed(40)
	if !client.EndOfStream(39).StaleCallbackIgnored {
		t.Fatal("stale callback was not ignored")
	}
	if len(clientRecorder.generations) != 1 || len(relayRecorder.generations) != 1 ||
		client.Metrics().SessionCleanups != 1 || relay.Metrics().SessionCleanups != 1 ||
		client.Metrics().SessionClosesSent != 1 || relay.Metrics().SessionClosesSent != 1 ||
		client.Metrics().SessionClosesReceived != 2 || client.Metrics().StaleCallbacks != 1 ||
		client.Metrics().LateCallbacks != 5 {
		t.Fatalf("termination counters client=%#v relay=%#v", client.Metrics(), relay.Metrics())
	}

	abruptRecorder := &sessionCleanupRecorder{}
	abrupt := mustSession(t, 41, SessionPeerRelay, MaxUDPPayloadRelayDefault, nil, abruptRecorder.generation)
	eof := abrupt.EndOfStream(41)
	if eof.Failure == nil || eof.Failure.Code != SessionUnexpectedEOF {
		t.Fatalf("EOF = %#v", eof)
	}
	if abrupt.Cancel(41).Failure != nil || len(abruptRecorder.generations) != 1 || abrupt.Metrics().SessionCleanups != 1 {
		t.Fatalf("abrupt duplicate termination = %#v metrics=%#v", abruptRecorder, abrupt.Metrics())
	}
}

func TestSessionLiveAssociationsCleanUpOnceForEveryAbruptTermination(t *testing.T) {
	tests := []struct {
		name   string
		code   SessionErrorCode
		reason SessionTerminationReason
		end    func(*Session, uint64) SessionStep
	}{
		{"EOF", SessionUnexpectedEOF, SessionTerminationEndOfStream, (*Session).EndOfStream},
		{"cancellation", SessionCancelled, SessionTerminationCancelled, (*Session).Cancel},
		{"transport failure", SessionTransportFailure, SessionTerminationTransportFailure, (*Session).TransportFailed},
	}
	payload := validSessionDatagramPayload(t, nil)

	for index, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			generation := uint64(130 + index)
			clientRecorder := &sessionCleanupRecorder{}
			relayRecorder := &sessionCleanupRecorder{}
			client := mustSession(t, generation, SessionPeerClient, MaxUDPPayloadClientDefault,
				clientRecorder.association, clientRecorder.generation)
			relay := mustSession(t, generation, SessionPeerRelay, MaxUDPPayloadRelayDefault,
				relayRecorder.association, relayRecorder.generation)
			request := client.Send(generation, Envelope{Type: MessageTypeUDPDatagram, AssociationID: 15, Payload: payload})
			relay.Receive(generation, request.Outbound[0])
			response := relay.Send(generation, Envelope{Type: MessageTypeUDPDatagram, AssociationID: 15, Payload: payload})
			client.Receive(generation, response.Outbound[0])

			clientTerminal := test.end(client, generation)
			relayTerminal := test.end(relay, generation)
			if clientTerminal.Failure == nil || clientTerminal.Failure.Code != test.code ||
				relayTerminal.Failure == nil || relayTerminal.Failure.Code != test.code {
				t.Fatalf("terminal client=%#v relay=%#v", clientTerminal, relayTerminal)
			}
			for _, session := range []*Session{client, relay} {
				session.EndOfStream(generation)
				session.Cancel(generation)
				session.TransportFailed(generation)
				session.Receive(generation, Envelope{Type: MessageTypeCloseAssociation, AssociationID: 15})
				session.Receive(generation, Envelope{Type: MessageTypeCloseSession})
				if !session.EndOfStream(generation - 1).StaleCallbackIgnored {
					t.Fatal("stale callback was not ignored")
				}
			}
			if len(clientRecorder.associations) != 1 || len(relayRecorder.associations) != 1 ||
				len(clientRecorder.reasons) != 1 || clientRecorder.reasons[0] != test.reason ||
				len(relayRecorder.reasons) != 1 || relayRecorder.reasons[0] != test.reason ||
				client.Metrics() != relay.Metrics() {
				t.Fatalf("cleanup/counters client=%#v relay=%#v clientRecorder=%#v relayRecorder=%#v",
					client.Metrics(), relay.Metrics(), clientRecorder, relayRecorder)
			}
			metrics := client.Metrics()
			if metrics.AssociationCleanups != 1 || metrics.SessionCleanups != 1 || metrics.SessionFailures != 1 ||
				metrics.AssociationClosesReceived != 1 || metrics.SessionClosesReceived != 1 ||
				metrics.LateCallbacks != 5 || metrics.StaleCallbacks != 1 {
				t.Fatalf("metrics = %#v", metrics)
			}
		})
	}
}

func TestSessionHostileMetadataAndExactBoundaryRLXRCloseBothPeers(t *testing.T) {
	hostile := []struct {
		peer  SessionPeer
		input []byte
		code  SessionErrorCode
	}{
		{SessionPeerRelay, []byte{0, 0, 0, 5}, SessionLengthBelowMinimum},
		{SessionPeerRelay, rawSessionFrame(0x7f, 0, 0, nil), SessionUnknownMessageType},
		{SessionPeerRelay, rawSessionFrame(byte(MessageTypeUDPDatagram), 0x80, 1, nil), SessionReservedFlags},
		{SessionPeerClient, rawSessionFrame(byte(MessageTypePing), 0, 0, make([]byte, 8)), SessionInvalidDirection},
		{SessionPeerRelay, rawSessionFrame(byte(MessageTypePing), 0, 1, make([]byte, 8)), SessionInvalidAssociationID},
		{SessionPeerRelay, rawSessionFrame(byte(MessageTypePing), 0, 0, make([]byte, 7)), SessionInvalidPayloadLength},
	}
	for index, test := range hostile {
		recorder := &sessionCleanupRecorder{}
		generation := uint64(50 + index)
		session := mustSession(t, generation, test.peer, MaxUDPPayloadRelayDefault, nil, recorder.generation)
		result := session.Consume(generation, test.input)
		if result.State != SessionClosed || result.Failure == nil || result.Failure.Code != test.code ||
			result.Failure.Scope != "session" || result.Failure.Disposition != "closeSession" || len(recorder.generations) != 1 {
			t.Fatalf("hostile case %d = %#v recorder=%#v", index, result, recorder)
		}
	}

	for peerIndex, peer := range []SessionPeer{SessionPeerClient, SessionPeerRelay} {
		for splitMask := 0; splitMask < 8; splitMask++ {
			recorder := &sessionCleanupRecorder{}
			generation := uint64(160 + peerIndex*10 + splitMask)
			session := mustSession(t, generation, peer, MaxUDPPayloadRelayDefault, nil, recorder.generation)
			chunks := magicSessionChunks(splitMask)
			for chunkIndex, chunk := range chunks {
				// The hello completed at an exact read boundary; these are later reads.
				result := session.Consume(generation, chunk)
				if chunkIndex == len(chunks)-1 {
					if result.Failure == nil || result.Failure.Code != SessionPostHandshakeHello {
						t.Fatalf("peer %s mask %d RLXR = %#v", peer, splitMask, result)
					}
				} else if result.State != SessionActive || result.Failure != nil {
					t.Fatalf("peer %s mask %d prefix chunk %d = %#v", peer, splitMask, chunkIndex, result)
				}
			}
			if len(recorder.reasons) != 1 || recorder.reasons[0] != SessionTerminationPostHandshakeHello ||
				session.Metrics().SessionCleanups != 1 {
				t.Fatalf("peer %s mask %d recorder=%#v metrics=%#v", peer, splitMask, recorder, session.Metrics())
			}
			if duplicate := session.EndOfStream(generation); duplicate.Failure != nil || len(recorder.generations) != 1 {
				t.Fatalf("peer %s mask %d duplicate = %#v", peer, splitMask, duplicate)
			}
			if !session.EndOfStream(generation-1).StaleCallbackIgnored || len(recorder.generations) != 1 {
				t.Fatalf("peer %s mask %d stale callback was not idempotent", peer, splitMask)
			}
		}
	}
}

func TestSessionDiagnosticsNeverReflectRemotePayloadOrUnknownCode(t *testing.T) {
	attacker := "remote-secret-diagnostic"
	session := mustSession(t, 70, SessionPeerRelay, MaxUDPPayloadRelayDefault, nil, nil)
	result := session.Consume(70, rawSessionFrame(byte(MessageTypePing), 0, 0, []byte(attacker)))
	if result.Failure == nil {
		t.Fatal("hostile payload unexpectedly succeeded")
	}
	diagnostic := result.Failure.Error()
	if strings.Contains(diagnostic, attacker) || !strings.Contains(diagnostic, string(SessionInvalidPayloadLength)) ||
		!strings.Contains(diagnostic, "scope=session") || !strings.Contains(diagnostic, "disposition=closeSession") {
		t.Fatalf("unsafe or incomplete diagnostic: %q", diagnostic)
	}
}

func TestSessionPongAndUDPErrorUseOnlyBoundedResponseAPIs(t *testing.T) {
	token := bytes.Repeat([]byte{0xa5}, 8)
	arbitraryPong := mustSession(t, 80, SessionPeerRelay, MaxUDPPayloadRelayDefault, nil, nil)
	pong := arbitraryPong.Send(80, Envelope{Type: MessageTypePong, Payload: token})
	if len(pong.Outbound) != 0 || pong.Failure == nil || pong.Failure.Code != SessionMetadataRejected {
		t.Fatalf("arbitrary pong = %#v", pong)
	}

	arbitraryError := mustSession(t, 81, SessionPeerRelay, MaxUDPPayloadRelayDefault, nil, nil)
	errorStep := arbitraryError.Send(81, Envelope{Type: MessageTypeUDPError, AssociationID: 1, Payload: []byte{0, 1}})
	if len(errorStep.Outbound) != 0 || errorStep.Failure == nil || errorStep.Failure.Code != SessionMetadataRejected {
		t.Fatalf("arbitrary UDP error = %#v", errorStep)
	}

	unknownCode := mustSession(t, 82, SessionPeerRelay, MaxUDPPayloadRelayDefault, nil, nil)
	unknown := unknownCode.ReportAssociationFailure(82, 1, UDPErrorCode(0xffff), false)
	if len(unknown.Outbound) != 0 || unknown.Failure == nil || unknown.Failure.Code != SessionMetadataRejected {
		t.Fatalf("unknown generated error code = %#v", unknown)
	}

	generatedError := mustSession(t, 83, SessionPeerRelay, MaxUDPPayloadRelayDefault, nil, nil)
	generatedError.Receive(83, Envelope{
		Type:          MessageTypeUDPDatagram,
		AssociationID: 1,
		Payload:       validSessionDatagramPayload(t, nil),
	})
	generated := generatedError.ReportAssociationFailure(83, 1, UDPErrorCodeInvalidDatagram, false)
	if generated.Failure != nil || len(generated.Outbound) != 1 || !bytes.Equal(generated.Outbound[0].Payload, []byte{0, 1}) {
		t.Fatalf("generated UDP error = %#v", generated)
	}
}

type sessionCleanupRecorder struct {
	associations []uint64
	generations  []uint64
	reasons      []SessionTerminationReason
}

func (r *sessionCleanupRecorder) association(generation uint64, associationID uint32) {
	r.associations = append(r.associations, generation<<32|uint64(associationID))
}

func (r *sessionCleanupRecorder) generation(generation uint64, reason SessionTerminationReason) {
	r.generations = append(r.generations, generation)
	r.reasons = append(r.reasons, reason)
}

func mustSession(
	t testing.TB,
	generation uint64,
	peer SessionPeer,
	maximumUDPPayload uint16,
	associationCleanup AssociationCleanup,
	generationCleanup GenerationCleanup,
) *Session {
	return mustSessionWithMaximumAssociations(
		t,
		generation,
		peer,
		maximumUDPPayload,
		MaxAssociationsRelayDefault,
		associationCleanup,
		generationCleanup,
	)
}

func mustSessionWithMaximumAssociations(
	t testing.TB,
	generation uint64,
	peer SessionPeer,
	maximumUDPPayload uint16,
	maximumAssociations uint32,
	associationCleanup AssociationCleanup,
	generationCleanup GenerationCleanup,
) *Session {
	t.Helper()
	session, failure := NewSession(
		generation,
		peer,
		EffectiveLimits{
			EffectiveMaxFrame:         MaxFrameDefault,
			MaxUDPPayload:             maximumUDPPayload,
			MaxAssociations:           maximumAssociations,
			PerAssociationQueuedBytes: PerAssociationQueuedBytesRelayDefault,
			AggregateQueuedBytes:      AggregateQueuedBytesRelayDefault,
			ControlReservedBytes:      ControlReservedBytesRelayDefault,
			DNSPriorityWeight:         DNSPriorityWeightRelayDefault,
			IdleTimeoutMilliseconds:   IdleTimeoutRelayDefault,
		},
		FeatureSetDNSPriorityHint,
		associationCleanup,
		generationCleanup,
	)
	if failure != nil {
		t.Fatalf("NewSession failed: %v", failure)
	}
	return session
}

func validSessionDatagramPayload(t testing.TB, data []byte) []byte {
	t.Helper()
	codec := mustDatagramCodec(t, MaxUDPPayloadRelayDefault)
	payload, failure := codec.Encode(Datagram{
		Endpoint: DatagramEndpoint{
			Address: DatagramAddress{Type: AddressTypeIPv4, Bytes: []byte{192, 0, 2, 1}},
			Port:    53,
		},
		Data: data,
	})
	if failure != nil {
		t.Fatalf("datagram encode failed: %v", failure)
	}
	return payload
}

func rawSessionFrame(messageType byte, flags byte, associationID uint32, payload []byte) []byte {
	result := make([]byte, FramePrefixWidth+EnvelopeHeaderWidth+len(payload))
	binary.BigEndian.PutUint32(result[0:4], uint32(EnvelopeHeaderWidth+len(payload)))
	result[4] = messageType
	result[5] = flags
	binary.BigEndian.PutUint32(result[6:10], associationID)
	copy(result[10:], payload)
	return result
}

func oversizedSessionDatagramPayload(dataLength int) []byte {
	payload := make([]byte, 10+dataLength)
	binary.BigEndian.PutUint16(payload[0:2], uint16(dataLength))
	payload[2] = byte(HEVHDRLENIPv4)
	payload[3] = byte(AddressTypeIPv4)
	copy(payload[4:8], []byte{192, 0, 2, 1})
	binary.BigEndian.PutUint16(payload[8:10], 53)
	for index := 10; index < len(payload); index++ {
		payload[index] = 0xa5
	}
	return payload
}

func magicSessionChunks(splitMask int) [][]byte {
	chunks := make([][]byte, 0, 4)
	start := 0
	for boundary := 0; boundary < len(Magic)-1; boundary++ {
		if splitMask&(1<<boundary) != 0 {
			chunks = append(chunks, append([]byte(nil), Magic[start:boundary+1]...))
			start = boundary + 1
		}
	}
	chunks = append(chunks, append([]byte(nil), Magic[start:]...))
	return chunks
}

func findSessionTransition(table []SessionTransition, messageType MessageType) (SessionTransition, bool) {
	for _, transition := range table {
		if transition.Type == messageType {
			return transition, true
		}
	}
	return SessionTransition{}, false
}
