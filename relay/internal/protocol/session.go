package protocol

import (
	"bytes"
	"encoding/binary"
	"fmt"
)

type SessionPeer string

const (
	SessionPeerClient SessionPeer = "client"
	SessionPeerRelay  SessionPeer = "relay"
)

func (p SessionPeer) inboundDirection() EnvelopeDirection {
	if p == SessionPeerClient {
		return EnvelopeRelayToClient
	}
	return EnvelopeClientToRelay
}

func (p SessionPeer) outboundDirection() EnvelopeDirection {
	if p == SessionPeerClient {
		return EnvelopeClientToRelay
	}
	return EnvelopeRelayToClient
}

type SessionResponsePolicy string

const (
	SessionResponseNone                SessionResponsePolicy = "none"
	SessionResponseGeneratedUDPError   SessionResponsePolicy = "generatedUDPErrorOnFailure"
	SessionResponseEchoPong            SessionResponsePolicy = "echoPong"
	SessionResponseCloseAssociationAck SessionResponsePolicy = "closeAssociationAcknowledgement"
	SessionResponseCloseSessionAck     SessionResponsePolicy = "closeSessionAcknowledgement"
)

type SessionCloseEffect string

const (
	SessionCloseEffectNone                         SessionCloseEffect = "none"
	SessionCloseEffectMalformedDatagramAssociation SessionCloseEffect = "closeAssociationOnMalformedDatagram"
	SessionCloseEffectRecordAssociationError       SessionCloseEffect = "recordAssociationError"
	SessionCloseEffectAssociation                  SessionCloseEffect = "closeAssociation"
	SessionCloseEffectSession                      SessionCloseEffect = "closeSession"
)

type SessionTransition struct {
	Type                MessageType
	Direction           MessageDirection
	AssociationID       AssociationIDRule
	MinimumPayloadBytes int
	MaximumPayloadBytes int
	Response            SessionResponsePolicy
	CloseEffect         SessionCloseEffect
}

var sessionTransitionsV1 = buildSessionTransitionsV1()

// SessionTransitionTableV1 returns a copy of the executable v1 transition
// table. Generated metadata owns direction, association ID, and fixed widths.
func SessionTransitionTableV1() []SessionTransition {
	result := make([]SessionTransition, len(sessionTransitionsV1))
	copy(result, sessionTransitionsV1)
	return result
}

func buildSessionTransitionsV1() []SessionTransition {
	result := make([]SessionTransition, 0, len(MessageMetadataTable))
	for _, metadata := range MessageMetadataTable {
		minimumPayload := 0
		maximumPayload := MaxHEVRecordWidth
		if metadata.PayloadShape == PayloadShapeFixed {
			minimumPayload = metadata.FixedPayloadWidth
			maximumPayload = metadata.FixedPayloadWidth
		}
		response := SessionResponseNone
		closeEffect := SessionCloseEffectNone
		switch metadata.Type {
		case MessageTypeUDPDatagram:
			response = SessionResponseGeneratedUDPError
			closeEffect = SessionCloseEffectMalformedDatagramAssociation
		case MessageTypeUDPError:
			closeEffect = SessionCloseEffectRecordAssociationError
		case MessageTypePing:
			response = SessionResponseEchoPong
		case MessageTypePong:
		case MessageTypeCloseAssociation:
			response = SessionResponseCloseAssociationAck
			closeEffect = SessionCloseEffectAssociation
		case MessageTypeCloseSession:
			response = SessionResponseCloseSessionAck
			closeEffect = SessionCloseEffectSession
		}
		result = append(result, SessionTransition{
			Type:                metadata.Type,
			Direction:           metadata.Direction,
			AssociationID:       metadata.AssociationID,
			MinimumPayloadBytes: minimumPayload,
			MaximumPayloadBytes: maximumPayload,
			Response:            response,
			CloseEffect:         closeEffect,
		})
	}
	return result
}

func sessionTransition(messageType MessageType) (SessionTransition, bool) {
	for _, transition := range sessionTransitionsV1 {
		if transition.Type == messageType {
			return transition, true
		}
	}
	return SessionTransition{}, false
}

type SessionState string

const (
	SessionActive SessionState = "active"
	SessionClosed SessionState = "closed"
)

type SessionErrorCode string

const (
	SessionLengthBelowMinimum   SessionErrorCode = "frameLengthBelowMinimum"
	SessionLengthExceedsMaximum SessionErrorCode = "frameLengthExceedsMaximum"
	SessionArithmeticOverflow   SessionErrorCode = "arithmeticOverflow"
	SessionUnknownMessageType   SessionErrorCode = "unknownMessageType"
	SessionReservedFlags        SessionErrorCode = "reservedFlags"
	SessionInvalidFlags         SessionErrorCode = "invalidFlags"
	SessionInvalidDirection     SessionErrorCode = "invalidDirection"
	SessionInvalidAssociationID SessionErrorCode = "invalidAssociationID"
	SessionInvalidPayloadLength SessionErrorCode = "invalidPayloadLength"
	SessionMetadataRejected     SessionErrorCode = "metadataRejected"
	SessionUnexpectedEOF        SessionErrorCode = "unexpectedEOF"
	SessionCancelled            SessionErrorCode = "cancelled"
	SessionMalformedState       SessionErrorCode = "malformedState"
	SessionTransportFailure     SessionErrorCode = "transportFailure"
	SessionPostHandshakeHello   SessionErrorCode = "postHandshakeHello"
)

type SessionErrorPhase string

const (
	SessionPhaseEnvelope  SessionErrorPhase = "envelope"
	SessionPhaseLifecycle SessionErrorPhase = "lifecycle"
)

type SessionError struct {
	Code        SessionErrorCode
	Phase       SessionErrorPhase
	Scope       string
	Disposition string
}

func (e *SessionError) Error() string {
	if e == nil {
		return ""
	}
	return fmt.Sprintf(
		"relaySession code=%s phase=%s scope=%s disposition=%s",
		e.Code, e.Phase, e.Scope, e.Disposition,
	)
}

func sessionFailure(code SessionErrorCode, phase SessionErrorPhase) *SessionError {
	return &SessionError{
		Code:        code,
		Phase:       phase,
		Scope:       "session",
		Disposition: "closeSession",
	}
}

type SessionTerminationReason string

const (
	SessionTerminationLocalClose         SessionTerminationReason = "localClose"
	SessionTerminationPeerClose          SessionTerminationReason = "peerClose"
	SessionTerminationEndOfStream        SessionTerminationReason = "endOfStream"
	SessionTerminationCancelled          SessionTerminationReason = "cancelled"
	SessionTerminationTransportFailure   SessionTerminationReason = "transportFailure"
	SessionTerminationProtocolViolation  SessionTerminationReason = "protocolViolation"
	SessionTerminationPostHandshakeHello SessionTerminationReason = "postHandshakeHello"
)

type RemoteAssociationError struct {
	Code              UDPErrorCode
	UnknownRelayError bool
}

type SessionEventKind string

const (
	SessionEventDatagram SessionEventKind = "datagram"
	SessionEventUDPError SessionEventKind = "udpError"
	SessionEventPong     SessionEventKind = "pong"
)

type SessionEvent struct {
	Kind          SessionEventKind
	AssociationID uint32
	Datagram      Datagram
	RemoteError   RemoteAssociationError
	HealthPayload []byte
}

type SessionMetrics struct {
	ReceivedFrames            uint64
	SentFrames                uint64
	DatagramsAccepted         uint64
	DatagramsRejected         uint64
	PingsReceived             uint64
	PongsReceived             uint64
	UDPErrorsReceived         uint64
	UDPErrorsSent             uint64
	AssociationClosesReceived uint64
	AssociationClosesSent     uint64
	SessionClosesReceived     uint64
	SessionClosesSent         uint64
	AssociationCleanups       uint64
	SessionCleanups           uint64
	StaleCallbacks            uint64
	LateCallbacks             uint64
	SessionFailures           uint64
}

type SessionStep struct {
	State                SessionState
	Outbound             []Envelope
	Events               []SessionEvent
	Failure              *SessionError
	StaleCallbackIgnored bool
}

type AssociationCleanup func(generation uint64, associationID uint32)
type GenerationCleanup func(generation uint64, reason SessionTerminationReason)

type sessionAssociation struct {
	active                  bool
	localCloseSent          bool
	peerCloseReceived       bool
	cleanupInvoked          bool
	queueSaturationReported bool
}

type associationAdmission uint8

const (
	associationAdmitted associationAdmission = iota
	associationUnknownOrClosed
	associationLimitExceeded
)

func newSessionAssociation() sessionAssociation {
	return sessionAssociation{active: true}
}

func (a sessionAssociation) retired() bool {
	return !a.active && a.localCloseSent && a.peerCloseReceived
}

type Session struct {
	generation                   uint64
	peer                         SessionPeer
	state                        SessionState
	decoder                      *EnvelopeDecoder
	datagramCodec                *DatagramCodec
	postHandshakePrefix          []byte
	negotiatedFeatures           FeatureSet
	maximumAssociations          int
	queueSaturationRecoveryBytes uint32
	associations                 map[uint32]sessionAssociation
	sessionCloseSent             bool
	sessionCleanupInvoked        bool
	associationCleanup           AssociationCleanup
	generationCleanup            GenerationCleanup
	metrics                      SessionMetrics
}

func NewSession(
	generation uint64,
	peer SessionPeer,
	limits EffectiveLimits,
	negotiatedFeatures FeatureSet,
	associationCleanup AssociationCleanup,
	generationCleanup GenerationCleanup,
) (*Session, *SessionError) {
	if peer != SessionPeerClient && peer != SessionPeerRelay {
		return nil, sessionFailure(SessionMalformedState, SessionPhaseLifecycle)
	}
	maximumAssociationLimit := MaxAssociationsRelayHardCeiling
	if peer == SessionPeerClient {
		maximumAssociationLimit = MaxAssociationsClientHardCeiling
	}
	if limits.MaxAssociations < MaxAssociationsFloor || limits.MaxAssociations > maximumAssociationLimit {
		return nil, sessionFailure(SessionMalformedState, SessionPhaseLifecycle)
	}
	decoder, codecFailure := NewEnvelopeDecoder(
		limits.EffectiveMaxFrame,
		peer.inboundDirection(),
		negotiatedFeatures,
		nil,
	)
	if codecFailure != nil {
		return nil, sessionFailure(mapCodecError(codecFailure.Code), SessionPhaseEnvelope)
	}
	datagramCodec, datagramFailure := NewDatagramCodec(limits.MaxUDPPayload)
	if datagramFailure != nil {
		return nil, sessionFailure(SessionMalformedState, SessionPhaseLifecycle)
	}
	return &Session{
		generation:                   generation,
		peer:                         peer,
		state:                        SessionActive,
		decoder:                      decoder,
		datagramCodec:                datagramCodec,
		maximumAssociations:          int(limits.MaxAssociations),
		queueSaturationRecoveryBytes: limits.PerAssociationQueuedBytes / 2,
		negotiatedFeatures:           negotiatedFeatures,
		associations:                 make(map[uint32]sessionAssociation),
		associationCleanup:           associationCleanup,
		generationCleanup:            generationCleanup,
	}, nil
}

func (s *Session) Generation() uint64      { return s.generation }
func (s *Session) Peer() SessionPeer       { return s.peer }
func (s *Session) State() SessionState     { return s.state }
func (s *Session) Metrics() SessionMetrics { return s.metrics }

func (s *Session) Consume(generation uint64, input []byte) SessionStep {
	if generation != s.generation {
		return s.staleStep()
	}
	if s.state != SessionActive {
		return s.lateStep(true)
	}
	inspected, detected := s.inspectPostHandshakePrefix(input)
	if detected {
		return s.fail(SessionPostHandshakeHello, SessionPhaseEnvelope, SessionTerminationPostHandshakeHello)
	}
	if inspected == nil {
		return SessionStep{State: s.state}
	}
	frames, failure := s.decoder.Consume(inspected)
	if failure != nil {
		return s.fail(mapCodecError(failure.Code), SessionPhaseEnvelope, SessionTerminationProtocolViolation)
	}
	step := SessionStep{State: s.state}
	for _, frame := range frames {
		frameStep := s.receiveDecoded(frame)
		step.Outbound = append(step.Outbound, frameStep.Outbound...)
		step.Events = append(step.Events, frameStep.Events...)
		if step.Failure == nil {
			step.Failure = frameStep.Failure
		}
	}
	step.State = s.state
	return step
}

// Receive handles an already-decoded frame and repeats transition-table checks
// so callers cannot bypass policy by bypassing the stream decoder.
func (s *Session) Receive(generation uint64, frame Envelope) SessionStep {
	if generation != s.generation {
		return s.staleStep()
	}
	if s.state != SessionActive {
		s.recordLateFrame(frame)
		return s.lateStep(false)
	}
	if code := s.validate(frame, s.peer.inboundDirection()); code != "" {
		return s.fail(code, SessionPhaseEnvelope, SessionTerminationProtocolViolation)
	}
	return s.receiveDecoded(frame)
}

// Send admits a locally produced frame and updates lifecycle state before the
// caller encodes it.
func (s *Session) Send(generation uint64, frame Envelope) SessionStep {
	if generation != s.generation {
		return s.staleStep()
	}
	if s.state != SessionActive {
		return s.lateStep(true)
	}
	if code := s.validate(frame, s.peer.outboundDirection()); code != "" {
		return s.fail(code, SessionPhaseEnvelope, SessionTerminationProtocolViolation)
	}
	step := SessionStep{State: s.state}
	switch frame.Type {
	case MessageTypeUDPDatagram:
		if _, failure := s.datagramCodec.Decode(frame.Payload); failure != nil {
			s.metrics.DatagramsRejected++
			return step
		}
		canSend := false
		if s.peer == SessionPeerClient {
			canSend = s.admitClientOwnedAssociation(frame.AssociationID) == associationAdmitted
		} else {
			association, ok := s.associations[frame.AssociationID]
			canSend = ok && association.active
		}
		if !canSend {
			s.metrics.DatagramsRejected++
			return step
		}
		s.emit(frame, &step.Outbound)
	case MessageTypeCloseAssociation:
		s.initiateAssociationClose(frame.AssociationID, &step.Outbound)
	case MessageTypeCloseSession:
		s.initiateSessionClose(&step.Outbound)
	case MessageTypeUDPError, MessageTypePong:
		// These are response-only. UDP errors must pass through the generated
		// code API, and PONG must be created only by the bounded PING echo path.
		return s.fail(SessionMetadataRejected, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	case MessageTypePing:
		s.emit(frame, &step.Outbound)
	}
	step.State = s.state
	return step
}

// ReportAssociationFailure emits only a schema-generated finite error code.
// There is deliberately no parameter for remote or OS diagnostic text.
func (s *Session) ReportAssociationFailure(
	generation uint64,
	associationID uint32,
	code UDPErrorCode,
	closeAssociation bool,
) SessionStep {
	if generation != s.generation {
		return s.staleStep()
	}
	if s.state != SessionActive {
		return s.lateStep(true)
	}
	if s.peer != SessionPeerRelay {
		return s.fail(SessionInvalidDirection, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	if associationID == 0 {
		return s.fail(SessionInvalidAssociationID, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	if !knownUDPErrorCode(code) {
		return s.fail(SessionMetadataRejected, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	if code == UDPErrorCodeQueueSaturated || code == UDPErrorCodeIdleExpiry {
		return s.fail(SessionMetadataRejected, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	association, ok := s.associations[associationID]
	if !ok || !association.active {
		return SessionStep{State: s.state}
	}
	step := SessionStep{State: s.state}
	s.emitUDPError(code, associationID, &step.Outbound)
	if closeAssociation {
		s.initiateAssociationClose(associationID, &step.Outbound)
	}
	return step
}

// ReportQueueSaturation records every dropped datagram and emits one bounded
// error per saturation episode.
func (s *Session) ReportQueueSaturation(generation uint64, associationID uint32) SessionStep {
	if generation != s.generation {
		return s.staleStep()
	}
	if s.state != SessionActive {
		return s.lateStep(true)
	}
	if s.peer != SessionPeerRelay {
		return s.fail(SessionInvalidDirection, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	if associationID == 0 {
		return s.fail(SessionInvalidAssociationID, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	s.metrics.DatagramsRejected++
	association, ok := s.associations[associationID]
	if !ok || !association.active || association.queueSaturationReported {
		return SessionStep{State: s.state}
	}
	association.queueSaturationReported = true
	s.associations[associationID] = association
	step := SessionStep{State: s.state}
	s.emitUDPError(UDPErrorCodeQueueSaturated, associationID, &step.Outbound)
	return step
}

// RecordAssociationQueueDepth rearms the saturation edge only at or below
// half of the configured per-association byte cap.
func (s *Session) RecordAssociationQueueDepth(
	generation uint64,
	associationID uint32,
	queuedBytes uint32,
) SessionStep {
	if generation != s.generation {
		return s.staleStep()
	}
	if s.state != SessionActive {
		return s.lateStep(true)
	}
	if s.peer != SessionPeerRelay {
		return s.fail(SessionInvalidDirection, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	if associationID == 0 {
		return s.fail(SessionInvalidAssociationID, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	association, ok := s.associations[associationID]
	if queuedBytes <= s.queueSaturationRecoveryBytes && ok && association.active {
		association.queueSaturationReported = false
		s.associations[associationID] = association
	}
	return SessionStep{State: s.state}
}

// ReportIdleExpiry applies the fixed error-retire-close ordering once.
func (s *Session) ReportIdleExpiry(generation uint64, associationID uint32) SessionStep {
	if generation != s.generation {
		return s.staleStep()
	}
	if s.state != SessionActive {
		return s.lateStep(true)
	}
	if s.peer != SessionPeerRelay {
		return s.fail(SessionInvalidDirection, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	if associationID == 0 {
		return s.fail(SessionInvalidAssociationID, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	association, ok := s.associations[associationID]
	if !ok || !association.active {
		return SessionStep{State: s.state}
	}
	step := SessionStep{State: s.state}
	s.emitUDPError(UDPErrorCodeIdleExpiry, associationID, &step.Outbound)
	s.initiateAssociationClose(associationID, &step.Outbound)
	return step
}

func (s *Session) CloseAssociation(generation uint64, associationID uint32) SessionStep {
	if generation != s.generation {
		return s.staleStep()
	}
	if s.state != SessionActive {
		return s.lateStep(true)
	}
	if associationID == 0 {
		return s.fail(SessionInvalidAssociationID, SessionPhaseLifecycle, SessionTerminationProtocolViolation)
	}
	step := SessionStep{State: s.state}
	s.initiateAssociationClose(associationID, &step.Outbound)
	return step
}

func (s *Session) Close(generation uint64) SessionStep {
	if generation != s.generation {
		return s.staleStep()
	}
	if s.state != SessionActive {
		return s.lateStep(true)
	}
	step := SessionStep{State: s.state}
	s.initiateSessionClose(&step.Outbound)
	step.State = s.state
	return step
}

func (s *Session) EndOfStream(generation uint64) SessionStep {
	return s.terminalEvent(generation, SessionUnexpectedEOF, SessionTerminationEndOfStream)
}

func (s *Session) Cancel(generation uint64) SessionStep {
	return s.terminalEvent(generation, SessionCancelled, SessionTerminationCancelled)
}

func (s *Session) TransportFailed(generation uint64) SessionStep {
	return s.terminalEvent(generation, SessionTransportFailure, SessionTerminationTransportFailure)
}

func (s *Session) receiveDecoded(frame Envelope) SessionStep {
	if s.state != SessionActive {
		s.recordLateFrame(frame)
		return s.lateStep(false)
	}
	s.metrics.ReceivedFrames++
	step := SessionStep{State: s.state}
	switch frame.Type {
	case MessageTypeUDPDatagram:
		s.handleDatagram(frame, &step.Outbound, &step.Events)
	case MessageTypeUDPError:
		s.metrics.UDPErrorsReceived++
		association, ok := s.associations[frame.AssociationID]
		if !ok || !association.active {
			s.closeRejectedAssociation(frame.AssociationID, &step.Outbound)
			break
		}
		raw := UDPErrorCode(binary.BigEndian.Uint16(frame.Payload))
		remoteError := RemoteAssociationError{Code: raw}
		if !knownUDPErrorCode(raw) {
			remoteError = RemoteAssociationError{UnknownRelayError: true}
		}
		step.Events = append(step.Events, SessionEvent{
			Kind:          SessionEventUDPError,
			AssociationID: frame.AssociationID,
			RemoteError:   remoteError,
		})
	case MessageTypePing:
		s.metrics.PingsReceived++
		payload := append([]byte(nil), frame.Payload...)
		s.emit(Envelope{Type: MessageTypePong, Payload: payload}, &step.Outbound)
	case MessageTypePong:
		s.metrics.PongsReceived++
		step.Events = append(step.Events, SessionEvent{
			Kind:          SessionEventPong,
			HealthPayload: append([]byte(nil), frame.Payload...),
		})
	case MessageTypeCloseAssociation:
		s.metrics.AssociationClosesReceived++
		s.receiveAssociationClose(frame.AssociationID, &step.Outbound)
	case MessageTypeCloseSession:
		s.metrics.SessionClosesReceived++
		if !s.sessionCloseSent {
			s.sessionCloseSent = true
			s.metrics.SessionClosesSent++
			s.emit(Envelope{Type: MessageTypeCloseSession}, &step.Outbound)
		}
		s.terminate(SessionTerminationPeerClose)
	}
	step.State = s.state
	return step
}

func (s *Session) handleDatagram(frame Envelope, outbound *[]Envelope, events *[]SessionEvent) {
	if s.peer == SessionPeerRelay {
		switch s.preflightClientOwnedAssociation(frame.AssociationID) {
		case associationAdmitted:
		case associationUnknownOrClosed:
			s.metrics.DatagramsRejected++
			s.emitUDPError(UDPErrorCodeUnknownOrClosedAssociation, frame.AssociationID, outbound)
			s.closeRejectedAssociation(frame.AssociationID, outbound)
			return
		case associationLimitExceeded:
			s.metrics.DatagramsRejected++
			s.emitUDPError(UDPErrorCodeAssociationLimit, frame.AssociationID, outbound)
			s.closeRejectedAssociation(frame.AssociationID, outbound)
			return
		}
	}

	datagram, failure := s.datagramCodec.Decode(frame.Payload)
	if failure != nil {
		s.metrics.DatagramsRejected++
		if s.peer == SessionPeerRelay {
			s.emitUDPError(udpErrorCodeForDatagramFailure(failure), frame.AssociationID, outbound)
		}
		if failure.Disposition == "closeAssociation" {
			s.closeRejectedAssociation(frame.AssociationID, outbound)
		}
		return
	}

	if s.peer == SessionPeerClient {
		association, ok := s.associations[frame.AssociationID]
		if !ok || !association.active {
			s.metrics.DatagramsRejected++
			s.closeRejectedAssociation(frame.AssociationID, outbound)
			return
		}
	} else {
		switch s.admitClientOwnedAssociation(frame.AssociationID) {
		case associationAdmitted:
		case associationUnknownOrClosed:
			s.metrics.DatagramsRejected++
			s.emitUDPError(UDPErrorCodeUnknownOrClosedAssociation, frame.AssociationID, outbound)
			s.closeRejectedAssociation(frame.AssociationID, outbound)
			return
		case associationLimitExceeded:
			s.metrics.DatagramsRejected++
			s.emitUDPError(UDPErrorCodeAssociationLimit, frame.AssociationID, outbound)
			s.closeRejectedAssociation(frame.AssociationID, outbound)
			return
		}
	}

	s.metrics.DatagramsAccepted++
	*events = append(*events, SessionEvent{
		Kind:          SessionEventDatagram,
		AssociationID: frame.AssociationID,
		Datagram:      datagram,
	})
}

// preflightClientOwnedAssociation applies association identity and capacity
// before HEV payload inspection without materializing new state. The later
// admission is synchronous in the same session owner and therefore cannot
// race this result.
func (s *Session) preflightClientOwnedAssociation(associationID uint32) associationAdmission {
	if associationID == 0 {
		return associationUnknownOrClosed
	}
	if association, ok := s.associations[associationID]; ok {
		if association.active || association.retired() {
			return associationAdmitted
		}
		return associationUnknownOrClosed
	}
	liveAssociations := 0
	for _, association := range s.associations {
		if !association.retired() {
			liveAssociations++
		}
	}
	if liveAssociations >= s.maximumAssociations {
		return associationLimitExceeded
	}
	return associationAdmitted
}

func udpErrorCodeForDatagramFailure(failure *DatagramError) UDPErrorCode {
	switch failure.Code {
	case DatagramMessageLengthExceedsProtocolLimit, DatagramMessageLengthExceedsLocalLimit:
		return UDPErrorCodeDatagramTooLarge
	case DatagramUnknownAddressType:
		return UDPErrorCodeUnsupportedAddress
	default:
		return UDPErrorCodeInvalidDatagram
	}
}

func (s *Session) closeRejectedAssociation(associationID uint32, outbound *[]Envelope) {
	if _, ok := s.associations[associationID]; ok {
		s.initiateAssociationClose(associationID, outbound)
		return
	}
	s.metrics.AssociationClosesSent++
	s.emit(Envelope{Type: MessageTypeCloseAssociation, AssociationID: associationID}, outbound)
}

func (s *Session) admitClientOwnedAssociation(associationID uint32) associationAdmission {
	if associationID == 0 {
		return associationUnknownOrClosed
	}
	if association, ok := s.associations[associationID]; ok {
		if association.active {
			return associationAdmitted
		}
		if association.retired() {
			s.associations[associationID] = newSessionAssociation()
			return associationAdmitted
		}
		return associationUnknownOrClosed
	}

	for identifier, association := range s.associations {
		if association.retired() {
			delete(s.associations, identifier)
		}
	}
	if len(s.associations) >= s.maximumAssociations {
		return associationLimitExceeded
	}
	s.associations[associationID] = newSessionAssociation()
	return associationAdmitted
}

func (s *Session) validate(frame Envelope, direction EnvelopeDirection) SessionErrorCode {
	transition, ok := sessionTransition(frame.Type)
	if !ok {
		return SessionUnknownMessageType
	}
	if frame.Flags&EnvelopeFlagsReservedMask != 0 {
		return SessionReservedFlags
	}
	if frame.Flags != 0 && (frame.Flags != EnvelopeFlagDNSPriority ||
		frame.Type != MessageTypeUDPDatagram || direction != EnvelopeClientToRelay ||
		s.negotiatedFeatures&FeatureSetDNSPriorityHint == 0) {
		return SessionInvalidFlags
	}
	if transition.Direction == MessageDirectionClientToRelay && direction != EnvelopeClientToRelay ||
		transition.Direction == MessageDirectionRelayToClient && direction != EnvelopeRelayToClient {
		return SessionInvalidDirection
	}
	if transition.AssociationID == AssociationIDRuleZero && frame.AssociationID != 0 ||
		transition.AssociationID == AssociationIDRuleNonzero && frame.AssociationID == 0 {
		return SessionInvalidAssociationID
	}
	if len(frame.Payload) < transition.MinimumPayloadBytes || len(frame.Payload) > transition.MaximumPayloadBytes {
		return SessionInvalidPayloadLength
	}
	return ""
}

func (s *Session) inspectPostHandshakePrefix(input []byte) ([]byte, bool) {
	if len(input) == 0 {
		return input, false
	}
	if len(s.postHandshakePrefix) == 0 && !s.decoder.AtFrameBoundary() {
		return input, false
	}
	if len(s.postHandshakePrefix) == 0 && input[0] != Magic[0] {
		return input, false
	}
	candidate := make([]byte, 0, len(s.postHandshakePrefix)+len(input))
	candidate = append(candidate, s.postHandshakePrefix...)
	candidate = append(candidate, input...)
	comparedCount := len(candidate)
	if comparedCount > len(Magic) {
		comparedCount = len(Magic)
	}
	if !bytes.Equal(candidate[:comparedCount], Magic[:comparedCount]) {
		s.postHandshakePrefix = nil
		return candidate, false
	}
	if len(candidate) >= len(Magic) {
		s.postHandshakePrefix = nil
		return nil, true
	}
	s.postHandshakePrefix = append(s.postHandshakePrefix[:0], candidate...)
	return nil, false
}

func (s *Session) initiateAssociationClose(associationID uint32, outbound *[]Envelope) {
	association, ok := s.associations[associationID]
	if !ok {
		return
	}
	s.cleanupAssociationIfNeeded(associationID, &association)
	association.active = false
	if association.localCloseSent {
		s.associations[associationID] = association
		return
	}
	association.localCloseSent = true
	s.associations[associationID] = association
	s.metrics.AssociationClosesSent++
	s.emit(Envelope{Type: MessageTypeCloseAssociation, AssociationID: associationID}, outbound)
}

func (s *Session) receiveAssociationClose(associationID uint32, outbound *[]Envelope) {
	association, ok := s.associations[associationID]
	if !ok {
		return
	}
	s.cleanupAssociationIfNeeded(associationID, &association)
	association.active = false
	association.peerCloseReceived = true
	if !association.localCloseSent {
		association.localCloseSent = true
		s.metrics.AssociationClosesSent++
		s.emit(Envelope{Type: MessageTypeCloseAssociation, AssociationID: associationID}, outbound)
	}
	s.associations[associationID] = association
}

func (s *Session) cleanupAssociationIfNeeded(associationID uint32, association *sessionAssociation) {
	if !association.active || association.cleanupInvoked {
		return
	}
	association.cleanupInvoked = true
	s.metrics.AssociationCleanups++
	if s.associationCleanup != nil {
		s.associationCleanup(s.generation, associationID)
	}
}

func (s *Session) initiateSessionClose(outbound *[]Envelope) {
	if !s.sessionCloseSent {
		s.sessionCloseSent = true
		s.metrics.SessionClosesSent++
		s.emit(Envelope{Type: MessageTypeCloseSession}, outbound)
	}
	s.terminate(SessionTerminationLocalClose)
}

func (s *Session) emitUDPError(code UDPErrorCode, associationID uint32, outbound *[]Envelope) {
	payload := make([]byte, 2)
	binary.BigEndian.PutUint16(payload, uint16(code))
	s.metrics.UDPErrorsSent++
	s.emit(Envelope{Type: MessageTypeUDPError, AssociationID: associationID, Payload: payload}, outbound)
}

func (s *Session) emit(frame Envelope, outbound *[]Envelope) {
	s.metrics.SentFrames++
	*outbound = append(*outbound, frame)
}

func (s *Session) terminalEvent(
	generation uint64,
	code SessionErrorCode,
	reason SessionTerminationReason,
) SessionStep {
	if generation != s.generation {
		return s.staleStep()
	}
	if s.state != SessionActive {
		return s.lateStep(true)
	}
	return s.fail(code, SessionPhaseLifecycle, reason)
}

func (s *Session) fail(
	code SessionErrorCode,
	phase SessionErrorPhase,
	reason SessionTerminationReason,
) SessionStep {
	failure := sessionFailure(code, phase)
	s.metrics.SessionFailures++
	s.terminate(reason)
	return SessionStep{State: s.state, Failure: failure}
}

func (s *Session) terminate(reason SessionTerminationReason) {
	if s.state != SessionActive {
		return
	}
	s.postHandshakePrefix = nil
	for associationID, association := range s.associations {
		s.cleanupAssociationIfNeeded(associationID, &association)
		association.active = false
		s.associations[associationID] = association
	}
	s.state = SessionClosed
	if s.sessionCleanupInvoked {
		return
	}
	s.sessionCleanupInvoked = true
	s.metrics.SessionCleanups++
	if s.generationCleanup != nil {
		s.generationCleanup(s.generation, reason)
	}
}

func (s *Session) staleStep() SessionStep {
	s.metrics.StaleCallbacks++
	return SessionStep{State: s.state, StaleCallbackIgnored: true}
}

func (s *Session) lateStep(count bool) SessionStep {
	if count {
		s.metrics.LateCallbacks++
	}
	return SessionStep{State: s.state}
}

func (s *Session) recordLateFrame(frame Envelope) {
	s.metrics.ReceivedFrames++
	s.metrics.LateCallbacks++
	switch frame.Type {
	case MessageTypeCloseAssociation:
		s.metrics.AssociationClosesReceived++
	case MessageTypeCloseSession:
		s.metrics.SessionClosesReceived++
	}
}

func mapCodecError(code CodecErrorCode) SessionErrorCode {
	switch code {
	case CodecLengthBelowMinimum:
		return SessionLengthBelowMinimum
	case CodecLengthExceedsMaximum:
		return SessionLengthExceedsMaximum
	case CodecArithmeticOverflow:
		return SessionArithmeticOverflow
	case CodecUnknownMessageType:
		return SessionUnknownMessageType
	case CodecReservedFlags:
		return SessionReservedFlags
	case CodecInvalidFlags:
		return SessionInvalidFlags
	case CodecInvalidDirection:
		return SessionInvalidDirection
	case CodecInvalidAssociationID:
		return SessionInvalidAssociationID
	case CodecInvalidPayloadLength:
		return SessionInvalidPayloadLength
	case CodecMetadataRejected:
		return SessionMetadataRejected
	case CodecUnexpectedEOF:
		return SessionUnexpectedEOF
	case CodecCancelled:
		return SessionCancelled
	default:
		return SessionMalformedState
	}
}

func knownUDPErrorCode(code UDPErrorCode) bool {
	for _, named := range UDPErrorCodeNames {
		if uint64(code) == named.Value {
			return true
		}
	}
	return false
}
