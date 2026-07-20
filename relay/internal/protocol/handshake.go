package protocol

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"time"
)

type FeatureSet uint32

const FeatureSetDNSPriorityHint FeatureSet = FeatureSet(FeatureDNSPriorityHint)

type EffectiveLimits struct {
	EffectiveMaxFrame         uint32
	MaxUDPPayload             uint16
	MaxAssociations           uint32
	PerAssociationQueuedBytes uint32
	AggregateQueuedBytes      uint32
	ControlReservedBytes      uint32
	DNSPriorityWeight         uint8
	IdleTimeoutMilliseconds   uint32
}

type ServerHandshakeConfig struct {
	MaximumFrameBytes         uint32
	MaximumUDPPayloadBytes    uint16
	MaximumAssociations       uint32
	PerAssociationQueuedBytes uint32
	AggregateQueuedBytes      uint32
	ControlReservedBytes      uint32
	DNSPriorityWeight         uint8
	IdleTimeoutMilliseconds   uint32
	SupportedFeatures         FeatureSet
}

func DefaultServerHandshakeConfig() ServerHandshakeConfig {
	return ServerHandshakeConfig{
		MaximumFrameBytes:         MaxFrameRelayDefault,
		MaximumUDPPayloadBytes:    MaxUDPPayloadRelayDefault,
		MaximumAssociations:       MaxAssociationsRelayDefault,
		PerAssociationQueuedBytes: PerAssociationQueuedBytesRelayDefault,
		AggregateQueuedBytes:      AggregateQueuedBytesRelayDefault,
		ControlReservedBytes:      ControlReservedBytesRelayDefault,
		DNSPriorityWeight:         DNSPriorityWeightRelayDefault,
		IdleTimeoutMilliseconds:   IdleTimeoutRelayDefault,
		SupportedFeatures:         FeatureSetDNSPriorityHint,
	}
}

type HandshakeConfigurationField string

const (
	HandshakeConfigMaximumFrame         HandshakeConfigurationField = "maximumFrameBytes"
	HandshakeConfigMaximumUDPPayload    HandshakeConfigurationField = "maximumUDPPayloadBytes"
	HandshakeConfigMaximumAssociations  HandshakeConfigurationField = "maximumAssociations"
	HandshakeConfigPerAssociationQueued HandshakeConfigurationField = "perAssociationQueuedBytes"
	HandshakeConfigAggregateQueued      HandshakeConfigurationField = "aggregateQueuedBytes"
	HandshakeConfigControlReserved      HandshakeConfigurationField = "controlReservedBytes"
	HandshakeConfigDNSPriorityWeight    HandshakeConfigurationField = "dnsPriorityWeight"
	HandshakeConfigIdleTimeout          HandshakeConfigurationField = "idleTimeoutMilliseconds"
	HandshakeConfigSupportedFeatures    HandshakeConfigurationField = "supportedFeatures"
	HandshakeConfigTimeout              HandshakeConfigurationField = "timeout"
)

type HandshakeErrorCode string

const (
	HandshakeInvalidConfiguration   HandshakeErrorCode = "invalidConfiguration"
	HandshakeUnknownMagic           HandshakeErrorCode = "unknownMagic"
	HandshakeUnsupportedVersion     HandshakeErrorCode = "unsupportedVersion"
	HandshakeInvalidClientHello     HandshakeErrorCode = "invalidClientHello"
	HandshakeResourcePolicyRejected HandshakeErrorCode = "resourcePolicyRejected"
	HandshakeRelayUnavailable       HandshakeErrorCode = "relayUnavailable"
	HandshakeRelayRejected          HandshakeErrorCode = "relayRejected"
	HandshakeReservedClientFlags    HandshakeErrorCode = "reservedClientFlags"
	HandshakeImpossibleFeature      HandshakeErrorCode = "impossibleFeatureSelection"
	HandshakeUnreasonableMaxFrame   HandshakeErrorCode = "unreasonableMaxFrame"
	HandshakeTruncatedHello         HandshakeErrorCode = "truncatedHello"
	HandshakeExtendedHello          HandshakeErrorCode = "extendedHello"
	HandshakeDuplicateHello         HandshakeErrorCode = "duplicateHello"
	HandshakeTrailingHelloBytes     HandshakeErrorCode = "trailingHelloBytes"
	HandshakeTimedOut               HandshakeErrorCode = "timedOut"
	HandshakeUnexpectedEOF          HandshakeErrorCode = "unexpectedEOF"
	HandshakeCancelled              HandshakeErrorCode = "cancelled"
	HandshakeTransportFailure       HandshakeErrorCode = "transportFailure"
)

type HandshakePhase string

const (
	HandshakePhaseConfiguration       HandshakePhase = "configuration"
	HandshakePhaseClientHelloRead     HandshakePhase = "clientHelloRead"
	HandshakePhaseClientHelloValidate HandshakePhase = "clientHelloValidation"
	HandshakePhaseServerHelloWrite    HandshakePhase = "serverHelloWrite"
	HandshakePhaseTerminal            HandshakePhase = "terminal"
)

type HandshakeError struct {
	Code               HandshakeErrorCode
	Phase              HandshakePhase
	Scope              string
	Disposition        string
	ConfigurationField HandshakeConfigurationField
}

func (e *HandshakeError) Error() string {
	if e == nil {
		return ""
	}
	if e.ConfigurationField != "" {
		return fmt.Sprintf(
			"relayHandshake code=%s phase=%s field=%s scope=%s disposition=%s",
			e.Code, e.Phase, e.ConfigurationField, e.Scope, e.Disposition,
		)
	}
	return fmt.Sprintf(
		"relayHandshake code=%s phase=%s scope=%s disposition=%s",
		e.Code, e.Phase, e.Scope, e.Disposition,
	)
}

func handshakeFailure(code HandshakeErrorCode, phase HandshakePhase) *HandshakeError {
	return &HandshakeError{
		Code:        code,
		Phase:       phase,
		Scope:       "session",
		Disposition: "closeSession",
	}
}

func invalidHandshakeConfiguration(field HandshakeConfigurationField) *HandshakeError {
	failure := handshakeFailure(HandshakeInvalidConfiguration, HandshakePhaseConfiguration)
	failure.ConfigurationField = field
	return failure
}

func (c ServerHandshakeConfig) Validate() *HandshakeError {
	if c.MaximumFrameBytes < MaxFrameFloor || c.MaximumFrameBytes > MaxFrameRelayHardCeiling {
		return invalidHandshakeConfiguration(HandshakeConfigMaximumFrame)
	}
	if c.MaximumUDPPayloadBytes < MaxUDPPayloadFloor || c.MaximumUDPPayloadBytes > MaxUDPPayloadRelayHardCeiling {
		return invalidHandshakeConfiguration(HandshakeConfigMaximumUDPPayload)
	}
	if c.MaximumAssociations < MaxAssociationsFloor || c.MaximumAssociations > MaxAssociationsRelayHardCeiling {
		return invalidHandshakeConfiguration(HandshakeConfigMaximumAssociations)
	}
	if c.PerAssociationQueuedBytes < PerAssociationQueuedBytesFloor || c.PerAssociationQueuedBytes > PerAssociationQueuedBytesRelayHardCeiling {
		return invalidHandshakeConfiguration(HandshakeConfigPerAssociationQueued)
	}
	if c.AggregateQueuedBytes < AggregateQueuedBytesFloor || c.AggregateQueuedBytes > AggregateQueuedBytesRelayHardCeiling {
		return invalidHandshakeConfiguration(HandshakeConfigAggregateQueued)
	}
	if c.ControlReservedBytes < ControlReservedBytesFloor || c.ControlReservedBytes > ControlReservedBytesRelayHardCeiling || c.ControlReservedBytes > c.AggregateQueuedBytes {
		return invalidHandshakeConfiguration(HandshakeConfigControlReserved)
	}
	if c.DNSPriorityWeight < DNSPriorityWeightFloor || c.DNSPriorityWeight > DNSPriorityWeightRelayHardCeiling {
		return invalidHandshakeConfiguration(HandshakeConfigDNSPriorityWeight)
	}
	if c.IdleTimeoutMilliseconds < IdleTimeoutFloor || c.IdleTimeoutMilliseconds > IdleTimeoutRelayHardCeiling {
		return invalidHandshakeConfiguration(HandshakeConfigIdleTimeout)
	}
	if uint32(c.SupportedFeatures)&FeaturesReservedMask != 0 {
		return invalidHandshakeConfiguration(HandshakeConfigSupportedFeatures)
	}
	return nil
}

type ClientHello struct {
	Version  uint16
	Flags    uint16
	MaxFrame uint32
}

type HandshakeSummary struct {
	ProtocolVersion    uint16
	NegotiatedFeatures FeatureSet
	EffectiveLimits    EffectiveLimits
}

type ServerHandshakeResult struct {
	Summary HandshakeSummary
}

type ServerHandshakeState string

const (
	ServerHandshakeAwaitingClientHello ServerHandshakeState = "awaitingClientHello"
	ServerHandshakeCompleted           ServerHandshakeState = "completed"
	ServerHandshakeFailed              ServerHandshakeState = "failed"
)

type ServerHandshakeStep struct {
	State                ServerHandshakeState
	NeededBytes          int
	Reply                []byte
	Result               *ServerHandshakeResult
	Remaining            []byte
	Failure              *HandshakeError
	Close                bool
	StaleCallbackIgnored bool
}

type ServerHandshake struct {
	generation uint64
	config     ServerHandshakeConfig
	deadline   time.Time
	state      ServerHandshakeState
	hello      [ClientHelloWidth]byte
	buffered   int
	result     *ServerHandshakeResult
	failure    *HandshakeError
}

func NewServerHandshake(
	generation uint64,
	config ServerHandshakeConfig,
	now time.Time,
	timeout time.Duration,
) (*ServerHandshake, *HandshakeError) {
	if failure := config.Validate(); failure != nil {
		return nil, failure
	}
	if timeout <= 0 {
		return nil, invalidHandshakeConfiguration(HandshakeConfigTimeout)
	}
	return &ServerHandshake{
		generation: generation,
		config:     config,
		deadline:   now.Add(timeout),
		state:      ServerHandshakeAwaitingClientHello,
	}, nil
}

func (h *ServerHandshake) Consume(generation uint64, now time.Time, input []byte) ServerHandshakeStep {
	if generation != h.generation {
		return ServerHandshakeStep{State: h.state, StaleCallbackIgnored: true}
	}
	if h.state == ServerHandshakeFailed {
		return ServerHandshakeStep{State: h.state, Failure: h.failure, Close: true}
	}
	if h.state == ServerHandshakeCompleted {
		if len(input) == 0 {
			return ServerHandshakeStep{State: h.state, Result: h.result}
		}
		code := HandshakeTrailingHelloBytes
		if beginsWithHelloMagic(input) {
			code = HandshakeDuplicateHello
		}
		return h.fail(handshakeFailure(code, HandshakePhaseTerminal), nil)
	}
	if !now.Before(h.deadline) {
		return h.fail(handshakeFailure(HandshakeTimedOut, HandshakePhaseClientHelloRead), nil)
	}

	needed := ClientHelloWidth - h.buffered
	consumed := min(needed, len(input))
	copy(h.hello[h.buffered:], input[:consumed])
	h.buffered += consumed
	if h.buffered != ClientHelloWidth {
		return ServerHandshakeStep{
			State:       h.state,
			NeededBytes: ClientHelloWidth - h.buffered,
		}
	}

	hello, failure := DecodeClientHelloExact(h.hello[:], h.config)
	if failure != nil {
		status := HelloStatusInvalidClientHello
		if failure.Code == HandshakeUnsupportedVersion {
			status = HelloStatusUnsupportedVersion
		}
		reply := EncodeServerHello(WireVersion, status, 0, 0)
		return h.fail(failure, reply[:])
	}

	requested := FeatureSet(0)
	if hello.Flags&HelloFlagDNSPriorityHint != 0 {
		requested |= FeatureSetDNSPriorityHint
	}
	negotiated := requested & h.config.SupportedFeatures
	effectiveMaxFrame := min(hello.MaxFrame, h.config.MaximumFrameBytes)
	remaining := input[consumed:]
	if beginsWithHelloMagic(remaining) {
		return h.fail(handshakeFailure(HandshakeDuplicateHello, HandshakePhaseTerminal), nil)
	}
	result := &ServerHandshakeResult{Summary: HandshakeSummary{
		ProtocolVersion:    WireVersion,
		NegotiatedFeatures: negotiated,
		EffectiveLimits: EffectiveLimits{
			EffectiveMaxFrame:         effectiveMaxFrame,
			MaxUDPPayload:             min(h.config.MaximumUDPPayloadBytes, MaxUDPPayloadRelayDefault),
			MaxAssociations:           min(h.config.MaximumAssociations, MaxAssociationsRelayDefault),
			PerAssociationQueuedBytes: min(h.config.PerAssociationQueuedBytes, PerAssociationQueuedBytesRelayDefault),
			AggregateQueuedBytes:      min(h.config.AggregateQueuedBytes, AggregateQueuedBytesRelayDefault),
			ControlReservedBytes:      min(h.config.ControlReservedBytes, ControlReservedBytesRelayDefault),
			DNSPriorityWeight:         min(h.config.DNSPriorityWeight, DNSPriorityWeightRelayDefault),
			IdleTimeoutMilliseconds:   min(h.config.IdleTimeoutMilliseconds, IdleTimeoutRelayDefault),
		},
	}}
	reply := EncodeServerHello(WireVersion, HelloStatusAccepted, negotiated, effectiveMaxFrame)
	h.state = ServerHandshakeCompleted
	h.result = result
	h.clearBuffer()
	return ServerHandshakeStep{
		State:     h.state,
		Reply:     append([]byte(nil), reply[:]...),
		Result:    result,
		Remaining: append([]byte(nil), remaining...),
	}
}

func beginsWithHelloMagic(input []byte) bool {
	if len(input) == 0 {
		return false
	}
	prefixLength := min(len(input), len(Magic))
	return bytes.Equal(input[:prefixLength], Magic[:prefixLength])
}

func (h *ServerHandshake) EndOfStream(generation uint64) ServerHandshakeStep {
	return h.terminalEvent(generation, HandshakeUnexpectedEOF, HandshakePhaseClientHelloRead)
}

func (h *ServerHandshake) Timeout(generation uint64) ServerHandshakeStep {
	return h.terminalEvent(generation, HandshakeTimedOut, HandshakePhaseClientHelloRead)
}

func (h *ServerHandshake) Cancel(generation uint64) ServerHandshakeStep {
	return h.terminalEvent(generation, HandshakeCancelled, HandshakePhaseTerminal)
}

func (h *ServerHandshake) terminalEvent(
	generation uint64,
	code HandshakeErrorCode,
	phase HandshakePhase,
) ServerHandshakeStep {
	if generation != h.generation {
		return ServerHandshakeStep{State: h.state, StaleCallbackIgnored: true}
	}
	if h.state == ServerHandshakeCompleted {
		return ServerHandshakeStep{State: h.state, Result: h.result}
	}
	if h.state == ServerHandshakeFailed {
		return ServerHandshakeStep{State: h.state, Failure: h.failure, Close: true}
	}
	return h.fail(handshakeFailure(code, phase), nil)
}

func (h *ServerHandshake) fail(failure *HandshakeError, reply []byte) ServerHandshakeStep {
	h.state = ServerHandshakeFailed
	h.failure = failure
	h.clearBuffer()
	return ServerHandshakeStep{
		State:   h.state,
		Reply:   append([]byte(nil), reply...),
		Failure: failure,
		Close:   true,
	}
}

func (h *ServerHandshake) clearBuffer() {
	h.hello = [ClientHelloWidth]byte{}
	h.buffered = 0
}

func DecodeClientHelloExact(input []byte, config ServerHandshakeConfig) (ClientHello, *HandshakeError) {
	if len(input) < ClientHelloWidth {
		return ClientHello{}, handshakeFailure(HandshakeTruncatedHello, HandshakePhaseClientHelloValidate)
	}
	if len(input) > ClientHelloWidth {
		return ClientHello{}, handshakeFailure(HandshakeExtendedHello, HandshakePhaseClientHelloValidate)
	}
	if !bytes.Equal(fieldBytes(input, ClientHelloLayout, "magic"), Magic[:]) {
		return ClientHello{}, handshakeFailure(HandshakeUnknownMagic, HandshakePhaseClientHelloValidate)
	}
	hello := ClientHello{
		Version:  binary.BigEndian.Uint16(fieldBytes(input, ClientHelloLayout, "version")),
		Flags:    binary.BigEndian.Uint16(fieldBytes(input, ClientHelloLayout, "flags")),
		MaxFrame: binary.BigEndian.Uint32(fieldBytes(input, ClientHelloLayout, "maxFrame")),
	}
	if hello.Version != WireVersion {
		return ClientHello{}, handshakeFailure(HandshakeUnsupportedVersion, HandshakePhaseClientHelloValidate)
	}
	if hello.Flags&HelloFlagsReservedMask != 0 {
		return ClientHello{}, handshakeFailure(HandshakeReservedClientFlags, HandshakePhaseClientHelloValidate)
	}
	if hello.MaxFrame < MaxFrameFloor || hello.MaxFrame > MaxFrameHardCeiling || hello.MaxFrame > MaxFrameClientHardCeiling {
		return ClientHello{}, handshakeFailure(HandshakeUnreasonableMaxFrame, HandshakePhaseClientHelloValidate)
	}
	if failure := config.Validate(); failure != nil {
		return ClientHello{}, failure
	}
	return hello, nil
}

func EncodeServerHello(
	version uint16,
	status HelloStatus,
	features FeatureSet,
	maximumFrameBytes uint32,
) [ServerHelloWidth]byte {
	var reply [ServerHelloWidth]byte
	copy(fieldBytes(reply[:], ServerHelloLayout, "magic"), Magic[:])
	binary.BigEndian.PutUint16(fieldBytes(reply[:], ServerHelloLayout, "version"), version)
	binary.BigEndian.PutUint16(fieldBytes(reply[:], ServerHelloLayout, "status"), uint16(status))
	binary.BigEndian.PutUint32(fieldBytes(reply[:], ServerHelloLayout, "features"), uint32(features))
	binary.BigEndian.PutUint32(fieldBytes(reply[:], ServerHelloLayout, "maxFrame"), maximumFrameBytes)
	return reply
}

func fieldBytes(input []byte, layout []WireField, name string) []byte {
	for _, field := range layout {
		if field.Name == name {
			return input[field.ByteOffset : field.ByteOffset+field.ByteWidth]
		}
	}
	panic("generated relay hello layout is missing a required field")
}
