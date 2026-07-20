package protocol

import (
	"bytes"
	"encoding/binary"
	"strings"
	"testing"
	"time"
)

func TestServerHandshakeEverySplitAndCoalescedFrame(t *testing.T) {
	now := time.Unix(1, 0)
	config := DefaultServerHandshakeConfig()
	hello := encodeClientHello(WireVersion, HelloFlagDNSPriorityHint, MaxFrameClientHardCeiling)
	frame := makeFramePrefix(MinFrameLength)

	for split := 0; split <= ClientHelloWidth; split++ {
		handshake := mustServerHandshake(t, 7, config, now)
		first := handshake.Consume(7, now, hello[:split])
		if split == ClientHelloWidth {
			assertSuccessfulServerStep(t, first, config.MaximumFrameBytes)
			if len(first.Remaining) != 0 {
				t.Fatalf("split %d retained %d bytes at exact boundary", split, len(first.Remaining))
			}
			continue
		}
		if first.State != ServerHandshakeAwaitingClientHello || first.NeededBytes != ClientHelloWidth-split {
			t.Fatalf("split %d first step = %#v", split, first)
		}

		secondInput := append(append([]byte(nil), hello[split:]...), frame...)
		second := handshake.Consume(7, now, secondInput)
		assertSuccessfulServerStep(t, second, config.MaximumFrameBytes)
		if !bytes.Equal(second.Remaining, frame) {
			t.Fatalf("split %d remainder %x, want %x", split, second.Remaining, frame)
		}
	}
}

func TestServerHandshakeDuplicateHelloOwnershipAtEverySplit(t *testing.T) {
	now := time.Unix(1, 0)
	config := DefaultServerHandshakeConfig()
	hello := encodeClientHello(WireVersion, HelloFlagDNSPriorityHint, MaxFrameDefault)
	duplicated := append(append([]byte(nil), hello...), hello...)

	for split := 0; split <= len(duplicated); split++ {
		handshake := mustServerHandshake(t, 70, config, now)
		first := handshake.Consume(70, now, duplicated[:split])
		switch {
		case split < ClientHelloWidth:
			if first.State != ServerHandshakeAwaitingClientHello || first.NeededBytes != ClientHelloWidth-split {
				t.Fatalf("split %d first step = %#v", split, first)
			}
			second := handshake.Consume(70, now, duplicated[split:])
			assertFailedServerStep(t, second, HandshakeDuplicateHello)
		case split == ClientHelloWidth:
			assertSuccessfulServerStep(t, first, MaxFrameDefault)
			if len(first.Remaining) != 0 {
				t.Fatalf("exact-boundary hello retained %d bytes", len(first.Remaining))
			}
		default:
			assertFailedServerStep(t, first, HandshakeDuplicateHello)
		}
	}
}

func TestServerHandshakeExactWireAndFeatureIntersection(t *testing.T) {
	now := time.Unix(2, 0)
	config := DefaultServerHandshakeConfig()
	handshake := mustServerHandshake(t, 8, config, now)
	hello := encodeClientHello(WireVersion, HelloFlagDNSPriorityHint, MaxFrameFloor)

	if got := hello; !bytes.Equal(got, []byte{
		0x52, 0x4C, 0x58, 0x52,
		0x00, 0x01,
		0x00, 0x01,
		0x00, 0x00, 0x08, 0x00,
	}) {
		t.Fatalf("client hello bytes %x do not match frozen layout", got)
	}
	step := handshake.Consume(8, now, hello)
	assertSuccessfulServerStep(t, step, MaxFrameFloor)
	if step.Result.Summary.NegotiatedFeatures != FeatureSetDNSPriorityHint {
		t.Fatalf("features %x, want DNS priority", step.Result.Summary.NegotiatedFeatures)
	}
	if len(step.Reply) != ServerHelloWidth {
		t.Fatalf("reply width %d, want %d", len(step.Reply), ServerHelloWidth)
	}
	if got := binary.BigEndian.Uint16(fieldBytes(step.Reply, ServerHelloLayout, "status")); got != uint16(HelloStatusAccepted) {
		t.Fatalf("status %d, want accepted", got)
	}
	if got := binary.BigEndian.Uint32(fieldBytes(step.Reply, ServerHelloLayout, "features")); got != FeatureDNSPriorityHint {
		t.Fatalf("features %x, want %x", got, FeatureDNSPriorityHint)
	}

	withoutSupport := config
	withoutSupport.SupportedFeatures = 0
	noFeatureHandshake := mustServerHandshake(t, 9, withoutSupport, now)
	noFeature := noFeatureHandshake.Consume(9, now, hello)
	assertSuccessfulServerStep(t, noFeature, MaxFrameFloor)
	if noFeature.Result.Summary.NegotiatedFeatures != 0 {
		t.Fatalf("unsupported feature was selected: %x", noFeature.Result.Summary.NegotiatedFeatures)
	}
}

func TestServerHandshakeRejectsEveryClientHelloViolation(t *testing.T) {
	now := time.Unix(3, 0)
	config := DefaultServerHandshakeConfig()
	base := encodeClientHello(WireVersion, HelloFlagDNSPriorityHint, MaxFrameDefault)
	reservedFlag := HelloFlagsReservedMask & (^HelloFlagsReservedMask + 1)

	cases := []struct {
		name   string
		mutate func([]byte)
		code   HandshakeErrorCode
		status HelloStatus
	}{
		{
			name:   "magic",
			mutate: func(input []byte) { input[0] ^= 0xff },
			code:   HandshakeUnknownMagic,
			status: HelloStatusInvalidClientHello,
		},
		{
			name: "version",
			mutate: func(input []byte) {
				binary.BigEndian.PutUint16(fieldBytes(input, ClientHelloLayout, "version"), WireVersion+1)
			},
			code:   HandshakeUnsupportedVersion,
			status: HelloStatusUnsupportedVersion,
		},
		{
			name: "reserved flags",
			mutate: func(input []byte) {
				binary.BigEndian.PutUint16(fieldBytes(input, ClientHelloLayout, "flags"), reservedFlag)
			},
			code:   HandshakeReservedClientFlags,
			status: HelloStatusInvalidClientHello,
		},
		{
			name: "below max frame floor",
			mutate: func(input []byte) {
				binary.BigEndian.PutUint32(fieldBytes(input, ClientHelloLayout, "maxFrame"), MaxFrameFloor-1)
			},
			code:   HandshakeUnreasonableMaxFrame,
			status: HelloStatusInvalidClientHello,
		},
		{
			name: "above max frame ceiling",
			mutate: func(input []byte) {
				binary.BigEndian.PutUint32(fieldBytes(input, ClientHelloLayout, "maxFrame"), MaxFrameHardCeiling+1)
			},
			code:   HandshakeUnreasonableMaxFrame,
			status: HelloStatusInvalidClientHello,
		},
	}

	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			input := append([]byte(nil), base...)
			test.mutate(input)
			handshake := mustServerHandshake(t, 10, config, now)
			step := handshake.Consume(10, now, input)
			assertFailedServerStep(t, step, test.code)
			if len(step.Reply) != ServerHelloWidth {
				t.Fatalf("rejection reply width %d, want %d", len(step.Reply), ServerHelloWidth)
			}
			status := HelloStatus(binary.BigEndian.Uint16(fieldBytes(step.Reply, ServerHelloLayout, "status")))
			if status != test.status {
				t.Fatalf("status %d, want %d", status, test.status)
			}
			if binary.BigEndian.Uint32(fieldBytes(step.Reply, ServerHelloLayout, "features")) != 0 ||
				binary.BigEndian.Uint32(fieldBytes(step.Reply, ServerHelloLayout, "maxFrame")) != 0 {
				t.Fatal("rejection reply exposed negotiated values")
			}
		})
	}
}

func TestDecodeClientHelloExactRejectsTruncatedAndExtended(t *testing.T) {
	config := DefaultServerHandshakeConfig()
	hello := encodeClientHello(WireVersion, 0, MaxFrameDefault)

	if _, failure := DecodeClientHelloExact(hello[:len(hello)-1], config); failure == nil || failure.Code != HandshakeTruncatedHello {
		t.Fatalf("truncated failure = %#v", failure)
	}
	extended := append(append([]byte(nil), hello...), 0)
	if _, failure := DecodeClientHelloExact(extended, config); failure == nil || failure.Code != HandshakeExtendedHello {
		t.Fatalf("extended failure = %#v", failure)
	}
}

func TestServerHandshakeEffectiveLocalLimits(t *testing.T) {
	now := time.Unix(4, 0)

	t.Run("lower injected caps take effect", func(t *testing.T) {
		config := DefaultServerHandshakeConfig()
		config.MaximumFrameBytes = MaxFrameFloor
		config.MaximumUDPPayloadBytes = MaxUDPPayloadFloor
		config.MaximumAssociations = MaxAssociationsFloor
		config.PerAssociationQueuedBytes = PerAssociationQueuedBytesFloor
		config.AggregateQueuedBytes = AggregateQueuedBytesFloor
		config.ControlReservedBytes = ControlReservedBytesFloor
		config.DNSPriorityWeight = DNSPriorityWeightFloor
		config.IdleTimeoutMilliseconds = IdleTimeoutFloor
		handshake := mustServerHandshake(t, 11, config, now)
		hello := encodeClientHello(WireVersion, HelloFlagDNSPriorityHint, MaxFrameHardCeiling)
		step := handshake.Consume(11, now, hello)
		assertSuccessfulServerStep(t, step, MaxFrameFloor)
		limits := step.Result.Summary.EffectiveLimits
		if limits.MaxUDPPayload != MaxUDPPayloadFloor ||
			limits.MaxAssociations != MaxAssociationsFloor ||
			limits.PerAssociationQueuedBytes != PerAssociationQueuedBytesFloor ||
			limits.AggregateQueuedBytes != AggregateQueuedBytesFloor ||
			limits.ControlReservedBytes != ControlReservedBytesFloor ||
			limits.DNSPriorityWeight != DNSPriorityWeightFloor ||
			limits.IdleTimeoutMilliseconds != IdleTimeoutFloor {
			t.Fatalf("lower local caps did not take effect: %#v", limits)
		}
	})

	t.Run("injected values cannot raise schema baselines", func(t *testing.T) {
		config := DefaultServerHandshakeConfig()
		config.MaximumFrameBytes = MaxFrameRelayHardCeiling
		config.MaximumUDPPayloadBytes = MaxUDPPayloadRelayHardCeiling
		config.MaximumAssociations = MaxAssociationsRelayHardCeiling
		config.PerAssociationQueuedBytes = PerAssociationQueuedBytesRelayHardCeiling
		config.AggregateQueuedBytes = AggregateQueuedBytesRelayHardCeiling
		config.ControlReservedBytes = ControlReservedBytesRelayHardCeiling
		config.DNSPriorityWeight = DNSPriorityWeightRelayHardCeiling
		config.IdleTimeoutMilliseconds = IdleTimeoutRelayHardCeiling
		handshake := mustServerHandshake(t, 12, config, now)
		hello := encodeClientHello(WireVersion, HelloFlagDNSPriorityHint, MaxFrameClientHardCeiling)
		step := handshake.Consume(12, now, hello)
		assertSuccessfulServerStep(t, step, MaxFrameClientHardCeiling)
		limits := step.Result.Summary.EffectiveLimits
		if limits.MaxUDPPayload != MaxUDPPayloadRelayDefault ||
			limits.MaxAssociations != MaxAssociationsRelayDefault ||
			limits.PerAssociationQueuedBytes != PerAssociationQueuedBytesRelayDefault ||
			limits.AggregateQueuedBytes != AggregateQueuedBytesRelayDefault ||
			limits.ControlReservedBytes != ControlReservedBytesRelayDefault ||
			limits.DNSPriorityWeight != DNSPriorityWeightRelayDefault ||
			limits.IdleTimeoutMilliseconds != IdleTimeoutRelayDefault {
			t.Fatalf("effective limits exceeded schema baselines: %#v", limits)
		}
	})
}

func TestServerHandshakeTerminalAndStaleEvents(t *testing.T) {
	now := time.Unix(5, 0)
	config := DefaultServerHandshakeConfig()

	stale := mustServerHandshake(t, 20, config, now)
	if step := stale.Consume(19, now.Add(time.Hour), []byte{1}); !step.StaleCallbackIgnored {
		t.Fatalf("stale consume was not ignored: %#v", step)
	}
	if step := stale.Timeout(19); !step.StaleCallbackIgnored {
		t.Fatalf("stale timeout was not ignored: %#v", step)
	}
	if step := stale.Consume(20, now, nil); step.NeededBytes != ClientHelloWidth {
		t.Fatalf("stale callbacks mutated state: %#v", step)
	}

	timedOut := mustServerHandshake(t, 21, config, now)
	assertFailedServerStep(t, timedOut.Consume(21, now.Add(time.Second), nil), HandshakeTimedOut)

	explicitTimeout := mustServerHandshake(t, 22, config, now)
	assertFailedServerStep(t, explicitTimeout.Timeout(22), HandshakeTimedOut)

	eof := mustServerHandshake(t, 23, config, now)
	_ = eof.Consume(23, now, []byte{1})
	assertFailedServerStep(t, eof.EndOfStream(23), HandshakeUnexpectedEOF)

	cancelled := mustServerHandshake(t, 24, config, now)
	assertFailedServerStep(t, cancelled.Cancel(24), HandshakeCancelled)

	duplicate := completedServerHandshake(t, 25, config, now)
	assertFailedServerStep(
		t,
		duplicate.Consume(25, now, encodeClientHello(WireVersion, 0, MaxFrameDefault)),
		HandshakeDuplicateHello,
	)

	trailing := completedServerHandshake(t, 26, config, now)
	assertFailedServerStep(t, trailing.Consume(26, now, []byte{1}), HandshakeTrailingHelloBytes)
}

func TestServerHandshakeConfigurationValidation(t *testing.T) {
	valid := DefaultServerHandshakeConfig()
	cases := []struct {
		field  HandshakeConfigurationField
		mutate func(*ServerHandshakeConfig)
	}{
		{HandshakeConfigMaximumFrame, func(c *ServerHandshakeConfig) { c.MaximumFrameBytes = MaxFrameFloor - 1 }},
		{HandshakeConfigMaximumUDPPayload, func(c *ServerHandshakeConfig) { c.MaximumUDPPayloadBytes = MaxUDPPayloadFloor - 1 }},
		{HandshakeConfigMaximumAssociations, func(c *ServerHandshakeConfig) { c.MaximumAssociations = 0 }},
		{HandshakeConfigPerAssociationQueued, func(c *ServerHandshakeConfig) { c.PerAssociationQueuedBytes = PerAssociationQueuedBytesFloor - 1 }},
		{HandshakeConfigAggregateQueued, func(c *ServerHandshakeConfig) { c.AggregateQueuedBytes = AggregateQueuedBytesRelayHardCeiling + 1 }},
		{HandshakeConfigControlReserved, func(c *ServerHandshakeConfig) {
			c.AggregateQueuedBytes = AggregateQueuedBytesFloor
			c.ControlReservedBytes = ControlReservedBytesRelayHardCeiling
		}},
		{HandshakeConfigDNSPriorityWeight, func(c *ServerHandshakeConfig) { c.DNSPriorityWeight = 0 }},
		{HandshakeConfigIdleTimeout, func(c *ServerHandshakeConfig) { c.IdleTimeoutMilliseconds = IdleTimeoutRelayHardCeiling + 1 }},
		{HandshakeConfigSupportedFeatures, func(c *ServerHandshakeConfig) { c.SupportedFeatures = FeatureSet(FeaturesReservedMask) }},
	}

	for _, test := range cases {
		config := valid
		test.mutate(&config)
		failure := config.Validate()
		if failure == nil || failure.Code != HandshakeInvalidConfiguration || failure.ConfigurationField != test.field {
			t.Errorf("field %s failure = %#v", test.field, failure)
		}
	}
	if _, failure := NewServerHandshake(1, valid, time.Unix(0, 0), 0); failure == nil || failure.ConfigurationField != HandshakeConfigTimeout {
		t.Fatalf("timeout failure = %#v", failure)
	}
}

func TestServerHandshakeDiagnosticsArePrivacySafe(t *testing.T) {
	config := DefaultServerHandshakeConfig()
	input := make([]byte, ClientHelloWidth)
	attacker := "evil-secret"
	copy(input, []byte(attacker))
	_, failure := DecodeClientHelloExact(input, config)
	if failure == nil {
		t.Fatal("attacker input unexpectedly decoded")
	}
	diagnostic := failure.Error()
	if strings.Contains(diagnostic, attacker) || strings.Contains(diagnostic, string(input)) {
		t.Fatalf("diagnostic reflected attacker input: %q", diagnostic)
	}
	if !strings.Contains(diagnostic, string(HandshakeUnknownMagic)) ||
		!strings.Contains(diagnostic, "scope=session") ||
		!strings.Contains(diagnostic, "disposition=closeSession") {
		t.Fatalf("diagnostic missing stable local fields: %q", diagnostic)
	}
}

func encodeClientHello(version uint16, flags uint16, maxFrame uint32) []byte {
	hello := make([]byte, ClientHelloWidth)
	copy(fieldBytes(hello, ClientHelloLayout, "magic"), Magic[:])
	binary.BigEndian.PutUint16(fieldBytes(hello, ClientHelloLayout, "version"), version)
	binary.BigEndian.PutUint16(fieldBytes(hello, ClientHelloLayout, "flags"), flags)
	binary.BigEndian.PutUint32(fieldBytes(hello, ClientHelloLayout, "maxFrame"), maxFrame)
	return hello
}

func makeFramePrefix(length uint32) []byte {
	frame := make([]byte, FramePrefixWidth)
	binary.BigEndian.PutUint32(frame, length)
	return frame
}

func mustServerHandshake(
	t *testing.T,
	generation uint64,
	config ServerHandshakeConfig,
	now time.Time,
) *ServerHandshake {
	t.Helper()
	handshake, failure := NewServerHandshake(generation, config, now, time.Second)
	if failure != nil {
		t.Fatalf("NewServerHandshake failed: %v", failure)
	}
	return handshake
}

func completedServerHandshake(
	t *testing.T,
	generation uint64,
	config ServerHandshakeConfig,
	now time.Time,
) *ServerHandshake {
	t.Helper()
	handshake := mustServerHandshake(t, generation, config, now)
	step := handshake.Consume(
		generation,
		now,
		encodeClientHello(WireVersion, HelloFlagDNSPriorityHint, MaxFrameDefault),
	)
	assertSuccessfulServerStep(t, step, min(MaxFrameDefault, config.MaximumFrameBytes))
	return handshake
}

func assertSuccessfulServerStep(t *testing.T, step ServerHandshakeStep, maxFrame uint32) {
	t.Helper()
	if step.State != ServerHandshakeCompleted || step.Result == nil || step.Failure != nil || step.Close {
		t.Fatalf("step did not succeed: %#v", step)
	}
	if step.Result.Summary.ProtocolVersion != WireVersion {
		t.Fatalf("version %d, want %d", step.Result.Summary.ProtocolVersion, WireVersion)
	}
	if step.Result.Summary.EffectiveLimits.EffectiveMaxFrame != maxFrame {
		t.Fatalf("maxFrame %d, want %d", step.Result.Summary.EffectiveLimits.EffectiveMaxFrame, maxFrame)
	}
}

func assertFailedServerStep(t *testing.T, step ServerHandshakeStep, code HandshakeErrorCode) {
	t.Helper()
	if step.State != ServerHandshakeFailed || step.Failure == nil || !step.Close {
		t.Fatalf("step did not fail closed: %#v", step)
	}
	if step.Failure.Code != code {
		t.Fatalf("failure code %s, want %s", step.Failure.Code, code)
	}
	if step.Failure.Scope != "session" || step.Failure.Disposition != "closeSession" {
		t.Fatalf("failure is not session-closing: %#v", step.Failure)
	}
}
